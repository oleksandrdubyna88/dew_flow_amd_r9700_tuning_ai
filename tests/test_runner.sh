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

# session_of <pid>: field 6 of /proc/<pid>/stat, read after the last ")"
session_of() {
  local stat
  stat="$(cat "/proc/$1/stat" 2> /dev/null)" || return 0
  stat="${stat##*) }"
  set -- $stat
  echo "$4"
}

# term_case <name> <test file body>: SIGTERM to the runner while the nested file is running its hung child; sets DIR and CHILD
term_case() {
  DIR="$R9700_TEST_ROOT/term-$1"
  mkdir -p "$DIR/tests"
  printf '%s\n' "$2" > "$DIR/tests/test_hung.sh"
  OUTER="$DIR" REPO="$REPO" R9700_RUNNER_TESTS_DIR="$DIR/tests" node "$REPO/tests/run.mjs" "$DIR/tests/test_hung.sh" > "$DIR/runner.out" 2>&1 &
  RUNNER=$!
  wait_for "$DIR/hung.ready" || { _assert_fail "$1" "the nested test never got to its hung call: $(cat "$DIR/runner.out")"; kill -KILL "$RUNNER" 2> /dev/null; return 1; }
  CHILD="$(cat "$DIR/child.pid")"
  guard_pid "$CHILD" "child-$1"
}

# term_checks <name>: after the SIGTERM, nothing of the nested run is left (checked after the runner ended, and again 1.5 s later)
term_checks() {
  kill -TERM "$RUNNER"
  wait "$RUNNER"
  assert_eq "143" "$?" "$1: SIGTERM ends the runner with exit 143"
  assert_eq "" "$(ps -s "$CHILD" -o pid= 2> /dev/null | tr -d ' \n')" "$1: no process of the test file's session is left"
  assert_missing "$(cat "$DIR/root.path")" "$1: the run folder is removed"
  sleep 1.5 # a survivor that wakes late would re-create the folder or start a container by now
  assert_eq "" "$(ps -s "$CHILD" -o pid= 2> /dev/null | tr -d ' \n')" "$1: still no process of that session"
  assert_missing "$(cat "$DIR/root.path")" "$1: and the folder is still removed"
}

t_a_sigterm_ends_a_process_that_shares_only_the_session_of_the_test_file() {
  # A child started by `timeout` has its own process group (GNU timeout calls setpgid) but the test file's session, and the stubs'
  # calls are such children: a kill of the test file's group does not reach them. Nothing records this one, so only the session kill can.
  term_case session 'echo "$R9700_TEST_ROOT" > "$OUTER/root.path"
echo "$$" > "$OUTER/child.pid"
timeout 1000 bash -c "echo \$\$ > \"\$1\"; exec sleep 1000" _ "$OUTER/hung.pid" &
for i in $(seq 1 50); do [ -s "$OUTER/hung.pid" ] && break; sleep 0.1; done
touch "$OUTER/hung.ready"
wait' || return
  guard_pid "$(cat "$DIR/hung.pid")" session-hung # a safety net: the EXIT trap ends it whichever way this test ends
  assert_eq "$CHILD" "$(session_of "$(cat "$DIR/hung.pid")")" "the hung process is in the test file's session"
  assert_exit 0 "and in a group of its own" -- test "$(cat "$DIR/hung.pid")" != "$CHILD"
  term_checks session
  gone "$(cat "$DIR/hung.pid")"
  assert_eq "0" "$?" "the hung process is gone"
}

t_a_file_that_reaches_its_ceiling_leaves_no_process_of_its_session() {
  local dir="$R9700_TEST_ROOT/ceiling" child hung
  mkdir -p "$dir/tests"
  printf '%s\n' 'echo "$R9700_TEST_ROOT" > "$OUTER/root.path"' 'echo "$$" > "$OUTER/child.pid"' \
    'timeout 1000 bash -c "echo \$\$ > \"\$1\"; exec sleep 1000" _ "$OUTER/hung.pid" &' 'sleep 1000' > "$dir/tests/test_hung.sh"
  OUTER="$dir" R9700_RUNNER_CEILING_MS=1500 R9700_RUNNER_TESTS_DIR="$dir/tests" node "$REPO/tests/run.mjs" "$dir/tests/test_hung.sh" > "$dir/runner.out" 2>&1
  assert_eq "1" "$?" "the file past its ceiling fails the run"
  assert_contains "$(cat "$dir/runner.out")" "ceiling of 1.5 s reached" "the runner says so"
  child="$(cat "$dir/child.pid")"
  hung="$(cat "$dir/hung.pid")"
  if kill -0 "$hung" 2> /dev/null; then guard_pid "$hung" ceiling-hung; fi # a survivor would be ended by the EXIT trap
  assert_exit 0 "the process of the timeout group is gone" -- gone "$hung"
  assert_eq "" "$(ps -s "$child" -o pid= 2> /dev/null | tr -d ' \n')" "no process of the file's session is left"
  assert_missing "$(cat "$dir/root.path")" "the run folder is removed"
}

t_a_file_that_passes_leaves_no_process_of_its_session() {
  # a passing file may leave something behind (a disowned subshell, a `timeout` child): the runner ends the session after every file
  local dir="$R9700_TEST_ROOT/passing" child hung
  mkdir -p "$dir/tests"
  printf '%s\n' 'echo "$R9700_TEST_ROOT" > "$OUTER/root.path"' 'echo "$$" > "$OUTER/child.pid"' \
    'timeout 1000 bash -c "echo \$\$ > \"\$1\"; exec sleep 1000" _ "$OUTER/hung.pid" &' \
    'for i in $(seq 1 50); do [ -s "$OUTER/hung.pid" ] && break; sleep 0.1; done' > "$dir/tests/test_leaves.sh"
  OUTER="$dir" R9700_RUNNER_TESTS_DIR="$dir/tests" node "$REPO/tests/run.mjs" "$dir/tests/test_leaves.sh" > "$dir/runner.out" 2>&1
  assert_eq "0" "$?" "the file itself passes"
  child="$(cat "$dir/child.pid")"
  hung="$(cat "$dir/hung.pid")"
  if kill -0 "$hung" 2> /dev/null; then guard_pid "$hung" passing-hung; fi # a survivor would be ended by the EXIT trap
  assert_exit 0 "what the file left behind is gone" -- gone "$hung"
  assert_eq "" "$(ps -s "$child" -o pid= 2> /dev/null | tr -d ' \n')" "no process of the file's session is left"
}

# session_case <ticks argument>: a session leader P with a member Q (a sleep), then killSession(P, KILL, <ticks>) from the runner's module
SESSION_DIR=""
session_case() {
  SESSION_DIR="$R9700_TEST_ROOT/ticks-$1"
  mkdir -p "$SESSION_DIR"
  setsid bash -c 'sleep 1000 & echo $! > "$1"; wait' _ "$SESSION_DIR/q.pid" > /dev/null 2>&1 &
  SESSION_LEADER=$!
  disown "$SESSION_LEADER"
  guard_pid "$SESSION_LEADER" "leader-$1"
  wait_for "$SESSION_DIR/q.pid" || { _assert_fail "$1" "the member never started"; return 1; }
  SESSION_MEMBER="$(cat "$SESSION_DIR/q.pid")"
  guard_pid "$SESSION_MEMBER" "member-$1"
}

kill_session_from_runner() { # <sid> <ticks or "undefined">
  node -e 'import(process.argv[1]).then((m) => m.killSession(Number(process.argv[2]), "SIGKILL", process.argv[3] === "undefined" ? undefined : process.argv[3]))' "$REPO/tests/run.mjs" "$1" "$2"
}

t_the_session_kill_skips_a_session_whose_leader_pid_belongs_to_another_process() {
  session_case other || return
  assert_eq "$SESSION_LEADER" "$(session_of "$SESSION_MEMBER")" "the premise: the member is in the leader's session"
  kill_session_from_runner "$SESSION_LEADER" 1
  assert_exit 0 "other start ticks: a pid reused by somebody else, nothing is killed" -- kill -0 "$SESSION_MEMBER"
  assert_exit 0 "the leader is alive too" -- kill -0 "$SESSION_LEADER"
  kill_session_from_runner "$SESSION_LEADER" undefined
  assert_exit 0 "no ticks recorded and a live leader: unknown, nothing is killed" -- kill -0 "$SESSION_MEMBER"
  kill_session_from_runner "$SESSION_LEADER" "$(_start_ticks "$SESSION_LEADER")"
  assert_exit 0 "the recorded ticks: the session is ended" -- gone "$SESSION_MEMBER"
  assert_exit 0 "the leader too" -- gone "$SESSION_LEADER"
}

t_a_sigterm_during_a_hung_adapter_call_leaves_no_process_and_no_folder() {
  # the real adapter, the real stub in `hang` mode: wslc_run waits in the stub; the runner is ended at that moment
  term_case adapter 'echo "$R9700_TEST_ROOT" > "$OUTER/root.path"
echo "$$" > "$OUTER/child.pid"
export R9700_WSLC=wslc R9700_STUB_DIR="$R9700_TEST_ROOT/stub" R9700_TIME_SCALE=1 R9700_CEILING_SCALE=1
PATH="$REPO/tests/stubs:$PATH"
mkdir -p "$R9700_STUB_DIR"
printf "hang\n" > "$R9700_STUB_DIR/mode"
source "$REPO/lib/run_guarded.sh"
source "$REPO/lib/adapter.sh"
( for i in $(seq 1 50); do [ -e "$R9700_STUB_DIR/hung/containers/1.pid" ] && break; sleep 0.1; done; touch "$OUTER/hung.ready" ) &
wslc_run r9700tune-x img' || return
  term_checks adapter
}

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
