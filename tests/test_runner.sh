#!/usr/bin/env bash
# tests/run.mjs: a signal ends the run cleanly (the child's process group, the recorded stub pids, the run folder) with the
# conventional exit code, and a recorded pid is killed only while it is still the same process. The nested runner discovers
# its test file in a folder of this test's own (R9700_RUNNER_TESTS_DIR), never in tests/.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"

# bounded wait for a file: wait_for <file>
wait_for() {
  local i
  for i in $(seq 1 100); do [ -f "$1" ] && return 0; sleep 0.1; done
  return 1
}

# sleeper <dir>: a test file that records where it runs and what it started, then sleeps
sleeper() {
  mkdir -p "$1/tests"
  cat > "$1/tests/test_sleep.sh" <<'BODY'
echo "$R9700_TEST_ROOT" > "$OUTER/root.path"
mkdir -p "$R9700_TEST_ROOT/containers"
setsid sleep 30 > /dev/null 2>&1 &
stub=$!
read -r -a stat < <(sed 's/.*) //' "/proc/$stub/stat")
echo "$stub ${stat[19]}" > "$R9700_TEST_ROOT/containers/stub.pid"
echo "$stub" > "$OUTER/stub.pid"
echo "$$" > "$OUTER/child.pid"
sleep 30
BODY
}

# signal_case <name> <signal> <exit code>
signal_case() {
  local dir="$R9700_TEST_ROOT/signal-$1" runner
  sleeper "$dir"
  OUTER="$dir" R9700_RUNNER_TESTS_DIR="$dir/tests" node "$REPO/tests/run.mjs" "$dir/tests/test_sleep.sh" > "$dir/runner.out" 2>&1 &
  runner=$!
  wait_for "$dir/child.pid" || { _assert_fail "$1" "the nested test never started: $(cat "$dir/runner.out")"; kill -KILL "$runner" 2> /dev/null; return; }
  guard_pid "$(cat "$dir/stub.pid")" "stub-$1"   # a safety net: the EXIT trap ends them whichever way this test ends
  guard_pid "$(cat "$dir/child.pid")" "child-$1"
  kill "-$2" "$runner"
  wait "$runner"
  assert_eq "$3" "$?" "$2 ends the runner with exit $3"
  gone "$(cat "$dir/child.pid")"
  assert_eq "0" "$?" "$2: the test process is gone"
  gone "$(cat "$dir/stub.pid")"
  assert_eq "0" "$?" "$2: the recorded stub process is gone"
  assert_missing "$(cat "$dir/root.path")" "$2: the run folder is removed"
  assert_contains "$(cat "$dir/runner.out")" "interrupted (SIG$2)" "$2: the runner says why it stopped"
  assert_not_contains "$(cat "$dir/runner.out")" "FAIL " "$2: no FAIL line after an interrupt"
  assert_not_contains "$(cat "$dir/runner.out")" "failed of" "$2: no summary after an interrupt"
}

t_sigint_ends_the_run_cleanly_with_exit_130() { signal_case int INT 130; }
t_sigterm_ends_the_run_cleanly_with_exit_143() { signal_case term TERM 143; }
t_sighup_ends_the_run_cleanly_with_exit_129() { signal_case hup HUP 129; }

t_a_recorded_pid_with_other_start_ticks_is_not_killed_by_the_runner() {
  local dir="$R9700_TEST_ROOT/foreign" pid
  mkdir -p "$dir/tests"
  cat > "$dir/tests/test_foreign.sh" <<'BODY'
mkdir -p "$R9700_TEST_ROOT/containers"
setsid sleep 30 > /dev/null 2>&1 &
echo "$! 1" > "$R9700_TEST_ROOT/containers/foreign.pid"
echo "$!" > "$OUTER/foreign.pid"
BODY
  OUTER="$dir" R9700_RUNNER_TESTS_DIR="$dir/tests" node "$REPO/tests/run.mjs" "$dir/tests/test_foreign.sh" > "$dir/runner.out" 2>&1
  assert_eq "0" "$?" "the nested run passes"
  pid="$(cat "$dir/foreign.pid")"
  guard_pid "$pid" foreign
  sleep 0.5
  kill -0 "$pid" 2> /dev/null
  assert_eq "0" "$?" "the process with other start ticks is still alive"
  kill -KILL "$pid" 2> /dev/null
}

t_a_recorded_pid_with_the_right_start_ticks_is_killed_after_a_normal_run() {
  local dir="$R9700_TEST_ROOT/normal" pid
  mkdir -p "$dir/tests"
  cat > "$dir/tests/test_normal.sh" <<'BODY'
mkdir -p "$R9700_TEST_ROOT/containers"
setsid sleep 30 > /dev/null 2>&1 &
stub=$!
read -r -a stat < <(sed 's/.*) //' "/proc/$stub/stat")
echo "$stub ${stat[19]}" > "$R9700_TEST_ROOT/containers/stub.pid"
echo "$stub" > "$OUTER/stub.pid"
BODY
  OUTER="$dir" R9700_RUNNER_TESTS_DIR="$dir/tests" node "$REPO/tests/run.mjs" "$dir/tests/test_normal.sh" > "$dir/runner.out" 2>&1
  assert_eq "0" "$?" "the nested run passes"
  pid="$(cat "$dir/stub.pid")"
  guard_pid "$pid" normal-stub
  gone "$pid"
  assert_eq "0" "$?" "the recorded process is dead"
  assert_contains "$(cat "$dir/runner.out")" "killed 1 recorded stub pid(s)" "the runner says so"
  kill -KILL "$pid" 2> /dev/null
}

t_a_closed_output_pipe_ends_the_run_cleanly() {
  # Two files: the first ends while the reader (head -1) is already gone, so the runner's next line is the first write to a closed
  # pipe; the second file is spawned in the same breath, and must not outlive the runner.
  local dir="$R9700_TEST_ROOT/epipe" code run_folder
  mkdir -p "$dir/tests"
  printf '%s\n' 'echo "$R9700_TEST_ROOT" > "$OUTER/root.path"' 'echo "first line"' 'sleep 1' > "$dir/tests/test_a_first.sh"
  cat > "$dir/tests/test_b_second.sh" <<'BODY'
mkdir -p "$R9700_TEST_ROOT/containers"
setsid sleep 30 > /dev/null 2>&1 &
stub=$!
read -r -a stat < <(sed 's/.*) //' "/proc/$stub/stat")
echo "$stub ${stat[19]}" > "$R9700_TEST_ROOT/containers/stub.pid"
echo "$stub" > "$OUTER/stub.pid"
echo "$$" > "$OUTER/child.pid"
sleep 30
BODY
  OUTER="$dir" R9700_RUNNER_TESTS_DIR="$dir/tests" node "$REPO/tests/run.mjs" 2> "$dir/runner.err" | head -1 > "$dir/head.out"
  code="${PIPESTATUS[0]}"
  sleep 1 # a leaked second file would have written its pid files by now
  [ -f "$dir/stub.pid" ] && guard_pid "$(cat "$dir/stub.pid")" epipe-stub
  [ -f "$dir/child.pid" ] && guard_pid "$(cat "$dir/child.pid")" epipe-child
  assert_eq "141" "$code" "a closed output pipe ends the runner with exit 141"
  assert_not_contains "$(cat "$dir/runner.err")" "Unhandled" "no unhandled error event"
  if [ -f "$dir/child.pid" ]; then
    gone "$(cat "$dir/child.pid")"
    assert_eq "0" "$?" "the second test file's process is gone"
    gone "$(cat "$dir/stub.pid")"
    assert_eq "0" "$?" "its recorded stub process is gone"
  else
    assert_eq "0" "0" "the second file never got far enough to leave anything"
  fi
  run_folder="$(cat "$dir/root.path")"
  run_folder="${run_folder%/sh/*}"
  assert_missing "$run_folder" "the run folder is removed"
}

t_a_child_ended_by_a_signal_is_reported_by_the_signal_name() {
  local dir="$R9700_TEST_ROOT/killed"
  mkdir -p "$dir/tests"
  printf '%s\n' 'kill -TERM $$' 'sleep 5' > "$dir/tests/test_killed.sh"
  R9700_RUNNER_TESTS_DIR="$dir/tests" node "$REPO/tests/run.mjs" "$dir/tests/test_killed.sh" > "$dir/runner.out" 2>&1
  assert_eq "1" "$?" "a failed file is exit 1"
  assert_contains "$(cat "$dir/runner.out")" "(signal SIGTERM)" "the file is reported by the signal name"
  assert_not_contains "$(cat "$dir/runner.out")" "(exit 128)" "not as exit 128"
}

run_all_tests
