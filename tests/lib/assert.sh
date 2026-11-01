#!/usr/bin/env bash
# Bash assertions for the plain-bash tests (tests/test_*.sh). Sourced, never run.
#
#   assert_eq <expected> <actual> <name>
#   assert_contains <haystack> <needle> <name>          (a literal substring)
#   assert_not_contains <haystack> <needle> <name>
#   assert_missing <path> <name>                        (the path does not exist)
#   assert_exit <code> <name> -- <command...>           (runs in THIS shell; stdout -> $OUT, stderr -> $ERR)
#   run_all_tests                                       (runs every function named t_*, each in its own subshell, then t_finish)
#   t_finish                                            (prints "<n> passed, <m> failed"; exits 1 on any failure)
#   record_pid <file> <pid>                             (writes "<pid> <start ticks>" for the killer below)
#   gone <pid>                                          (polls up to 3 s until the process is gone)
#   guard_pid <pid> <name>                              (records a process for the EXIT trap in a folder no killer under test is given)
#   kill_recorded_pids [<root>]                         (kills every process recorded in a containers/*.pid below the root while its start ticks still match; the EXIT trap of run_all_tests)
#
# The test body is a function `t_<guarantee>`; its name says what must be true. Tests write only below $R9700_TEST_ROOT,
# the folder tests/run.mjs claims, creates and removes (common/test-leftovers.md); nothing here makes a path of its own.
# Results go to a file in that folder, so a subshell's counts reach t_finish.

OUT=""
ERR=""

_assert_root() {
  if [ -z "${R9700_TEST_ROOT:-}" ] || [ ! -d "$R9700_TEST_ROOT" ]; then
    echo "assert: R9700_TEST_ROOT is not a directory; run this file with: node tests/run.mjs <file>" >&2
    exit 2
  fi
}

_assert_record() { # <P|F> <name>
  _assert_root
  printf '%s %s\n' "$1" "$2" >> "$R9700_TEST_ROOT/.results"
}

_assert_pass() {
  _assert_record P "$1"
  echo "ok - $1"
}

_assert_fail() { # <name> <detail...>
  local name="$1"
  shift
  _assert_record F "$name"
  echo "FAIL - $name" >&2
  printf '       %s\n' "$@" >&2
}

assert_eq() {
  if [ "$1" = "$2" ]; then _assert_pass "$3"; else _assert_fail "$3" "expected: [$1]" "actual:   [$2]"; fi
}

assert_contains() {
  case "$1" in
    *"$2"*) _assert_pass "$3" ;;
    *) _assert_fail "$3" "missing:  [$2]" "in:       [$1]" ;;
  esac
}

assert_not_contains() {
  case "$1" in
    *"$2"*) _assert_fail "$3" "unexpected: [$2]" "in:         [$1]" ;;
    *) _assert_pass "$3" ;;
  esac
}

assert_missing() {
  if [ ! -e "$1" ] && [ ! -L "$1" ]; then _assert_pass "$2"; else _assert_fail "$2" "exists: [$1]"; fi
}

assert_exit() { # <code> <name> -- <command...>
  local want="$1" name="$2"
  shift 2
  if [ "${1:-}" != "--" ]; then _assert_fail "$name" "assert_exit: the command must follow --"; return; fi
  shift
  _assert_root
  local out_file="$R9700_TEST_ROOT/.out" err_file="$R9700_TEST_ROOT/.err" got
  "$@" > "$out_file" 2> "$err_file"
  got=$?
  OUT="$(cat "$out_file")"
  ERR="$(cat "$err_file")"
  if [ "$got" = "$want" ]; then _assert_pass "$name"; else _assert_fail "$name" "expected exit $want, got $got" "stdout: [$OUT]" "stderr: [$ERR]"; fi
}

# _start_ticks <pid>: field 22 of /proc/<pid>/stat, read after the LAST ")" (the command name may hold one); empty when the pid is gone
_start_ticks() {
  local stat
  stat="$(cat "/proc/$1/stat" 2> /dev/null)" || return 0
  stat="${stat##*) }"
  set -- $stat
  echo "${20:-}"
}

# record_pid <file> <pid>: writes "<pid> <start ticks>", the only record kill_recorded_pids trusts
record_pid() {
  mkdir -p "$(dirname "$1")"
  printf '%s %s\n' "$2" "$(_start_ticks "$2")" > "$1"
}

# kill_recorded_pids [<root>]: kills every process recorded in a containers/*.pid file anywhere below the root (default
# $R9700_TEST_ROOT), but only while the pid still has the recorded start ticks: it is then the same process, never a reused pid.
kill_recorded_pids() {
  local root="${1:-${R9700_TEST_ROOT:-}}" file pid ticks extra
  [ -n "$root" ] && [ -d "$root" ] || return 0
  while IFS= read -r file; do
    read -r pid ticks extra < "$file" || true
    case $pid in '' | *[!0-9]* | 0 | 1) continue ;; esac
    case $ticks in '' | *[!0-9]*) continue ;; esac
    [ -z "${extra:-}" ] || continue
    [ "$(_start_ticks "$pid")" = "$ticks" ] && kill -KILL "$pid" 2> /dev/null
  done < <(find "$root" -type f -path '*/containers/*.pid' 2> /dev/null)
  return 0
}

# gone <pid>: waits up to 3 s for the process to be gone (a killed child is reaped within moments; a zombie still answers kill -0)
gone() {
  local i
  for i in $(seq 1 30); do kill -0 "$1" 2> /dev/null || return 0; sleep 0.1; done
  return 1
}

# guard_pid <pid> <name>: records a process with its REAL start ticks in $R9700_TEST_ROOT/guard/containers, a folder no killer under
# test is handed, so the EXIT trap of run_all_tests and the runner end it on every path, including a test that dies early.
guard_pid() {
  record_pid "$R9700_TEST_ROOT/guard/containers/$2.pid" "$1"
}

t_finish() {
  _assert_root
  local passed=0 failed=0 kind
  if [ -f "$R9700_TEST_ROOT/.results" ]; then
    while read -r kind _; do
      case $kind in
        P) passed=$((passed + 1)) ;;
        F) failed=$((failed + 1)) ;;
      esac
    done < "$R9700_TEST_ROOT/.results"
  fi
  echo "$passed passed, $failed failed"
  if [ "$failed" -gt 0 ] || [ "$passed" -eq 0 ]; then exit 1; fi
  exit 0
}

# _results_count: the number of P and F lines recorded so far
_results_count() {
  local n=0 kind
  if [ -f "$R9700_TEST_ROOT/.results" ]; then
    while read -r kind _; do
      case $kind in P | F) n=$((n + 1)) ;; esac
    done < "$R9700_TEST_ROOT/.results"
  fi
  echo "$n"
}

# _run_one <function>: its own subshell; a function that dies, exits early or asserts nothing is a failure of its own.
_run_one() {
  local fn="$1" before after status last
  before="$(_results_count)"
  ( "$fn"; _assert_record E "$fn" )
  status=$?
  after="$(_results_count)"
  last="$(tail -n 1 "$R9700_TEST_ROOT/.results" 2>/dev/null)"
  if [ "$status" -ne 0 ]; then
    _assert_fail "$fn" "the function exited with status $status before its end"
  elif [ "$last" != "E $fn" ]; then
    _assert_fail "$fn" "the function exited before its end"
  elif [ "$after" -eq "$before" ]; then
    _assert_fail "$fn" "the function recorded no assertion"
  fi
}

run_all_tests() {
  local fn
  trap kill_recorded_pids EXIT
  for fn in $(declare -F | awk '{print $3}' | grep '^t_' | grep -vx 't_finish'); do
    _run_one "$fn"
  done
  t_finish
}
