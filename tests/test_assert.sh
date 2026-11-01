#!/usr/bin/env bash
# tests/lib/assert.sh must fail a test function that dies early, exits early or asserts nothing. Each case is a tiny test file
# written below $R9700_TEST_ROOT and run as a child with its own R9700_TEST_ROOT; a case that passed by accident would be the
# defect itself, so every case also has its positive companion.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"

# child <name> <body>: runs a test file whose functions are <body>; sets CHILD_CODE and CHILD_OUT
child() {
  local dir="$R9700_TEST_ROOT/case-$1"
  mkdir -p "$dir/root"
  printf '%s\n' 'set -u' "source \"$HERE/lib/assert.sh\"" "$2" 'run_all_tests' > "$dir/case.sh"
  CHILD_OUT="$(R9700_TEST_ROOT="$dir/root" bash "$dir/case.sh" 2>&1)"
  CHILD_CODE=$?
}

t_a_function_that_passes_all_its_assertions_passes_the_file() {
  child good 't_a() { assert_eq 1 1 one; }
t_b() { assert_contains abc b two; }'
  assert_eq "0" "$CHILD_CODE" "a good file exits 0"
  assert_contains "$CHILD_OUT" "2 passed, 0 failed" "two assertions counted"
}

t_a_function_killed_early_by_an_unset_variable_fails_the_file() {
  child unset 't_a() { assert_eq 1 1 one; }
t_b() { echo "$UNSET_VARIABLE"; assert_eq 1 1 never_reached; }'
  assert_eq "1" "$CHILD_CODE" "the file fails although every recorded assertion passed"
  assert_contains "$CHILD_OUT" "t_b" "names the function"
}

t_a_function_that_exits_after_an_assertion_fails_the_file() {
  child exit3 't_a() { assert_eq 1 1 one; exit 3; }'
  assert_eq "1" "$CHILD_CODE" "exit 3 inside a function fails the file"
  child exit0 't_a() { assert_eq 1 1 one; exit 0; }'
  assert_eq "1" "$CHILD_CODE" "even exit 0 fails it: the function never reached its end"
}

t_a_function_that_asserts_nothing_fails_the_file() {
  child empty 't_a() { assert_eq 1 1 one; }
t_b() { :; }'
  assert_eq "1" "$CHILD_CODE" "a function with no assertion fails the file"
  assert_contains "$CHILD_OUT" "t_b" "names the function"
}

# ---- the pid killer (E1.S2 amendment A4): kill only the same process, in every containers/ folder below the root ----

# live_pid <root> <name>: a background process in its own session, recorded; sets PID
live_pid() {
  local root="$1"
  mkdir -p "$root/containers"
  setsid sleep 30 > /dev/null 2>&1 &
  PID=$!
  guard_pid "$PID" "p$PID" # a safety net outside every root a killer under test is given
}

t_the_killer_ends_a_recorded_process_in_a_nested_containers_folder() {
  local root="$R9700_TEST_ROOT/killer-nested/sub/deeper"
  live_pid "$root"
  record_pid "$root/containers/stub.pid" "$PID"
  kill_recorded_pids "$R9700_TEST_ROOT/killer-nested"
  gone "$PID"
  assert_eq "0" "$?" "the recorded process is dead (a containers folder two levels down was searched)"
}

t_the_killer_leaves_a_process_whose_start_ticks_differ() {
  local root="$R9700_TEST_ROOT/killer-ticks"
  live_pid "$root"
  printf '%s %s\n' "$PID" "1" > "$root/containers/foreign.pid"
  kill_recorded_pids "$root"
  sleep 0.5 # long enough for a wrong kill to have landed and been reaped
  kill -0 "$PID" 2> /dev/null
  assert_eq "0" "$?" "a pid with other start ticks is another process and is not killed"
  local first="$PID"
  live_pid "$root"
  printf '%s\n' "$PID" > "$root/containers/legacy.pid"
  kill_recorded_pids "$root"
  sleep 0.5 # long enough for a wrong kill to have landed and been reaped
  kill -0 "$PID" 2> /dev/null
  assert_eq "0" "$?" "a record without start ticks is not trusted"
  kill -KILL "$first" "$PID" 2> /dev/null
}

run_all_tests
