#!/usr/bin/env bash
# The adapter's signal and process rules (lib/adapter.sh): --kill-after and the grandchild, the interrupt chain as the supervisor meets it (the caller's
# traps, a handler that makes a nested call, a signal the caller ignores), the group kill, and descriptor 9 (the supervisor's lock). Split from
# tests/test_adapter.sh, which keeps the calls, the ceilings and the answers. Every test body is a function t_<guarantee>; each runs in its own
# subshell and writes only below $R9700_TEST_ROOT.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"
# ---- --kill-after: a child that ignores TERM is killed ----------------------------------------------------------------------------------

t_a_child_that_ignores_term_is_killed_after_the_grace_and_so_is_its_grandchild() {
  setup_case "$FUNCNAME"
  printf 'hang-ignore-term\n' > "$STUB/mode"
  R9700_CEILING_SCALE=100
  local i file pid
  ( wslc_list > /dev/null 2>&1; echo "$?" > "$CASE/rc" ) &
  disown
  for i in $(seq 1 100); do [ -f "$CASE/rc" ] && break; sleep 0.1; done # bounded: without --kill-after the call would never end
  if [ -f "$CASE/rc" ]; then assert_eq "137" "$(cat "$CASE/rc")" "KILL after the grace: rc 137"; else assert_eq "137" "(still running after 10 s)" "KILL after the grace: rc 137"; fi
  assert_exit 0 "the stub's record 1 exists" -- test -f "$STUB/hung/containers/1.pid"
  read -r pid _ < "$STUB/hung/containers/1.pid"
  assert_exit 0 "the stub itself (it ignored TERM) is gone" -- gone "$pid"
  assert_exit 0 "its grandchild's record 2 exists" -- test -f "$STUB/hung/containers/2.pid"
  read -r pid _ < "$STUB/hung/containers/2.pid"
  assert_exit 0 "the grandchild that ignored TERM is gone too (amendment A12: the whole group of the call gets the KILL)" -- gone "$pid"
  kill_recorded_pids "$CASE"
}

t_a_call_whose_wait_is_interrupted_by_a_trapped_signal_is_ended_with_its_group() {
  setup_case "$FUNCNAME"
  printf 'hang-ignore-term\n' > "$STUB/mode"
  R9700_CEILING_SCALE=1 # a real ceiling of 60 s: only the signal can end this call in time
  export R9700_STATE_DIR="$CASE/state" # the subshells below take the lock: the process that holds it owns its own traps
  local i pid sub
  ( lock_take step; trap ':' TERM; wslc_stop r9700tune-a > /dev/null 2>&1; echo "$?" > "$CASE/rc" ) & # no pipeline: the call runs in this subshell itself
  sub=$!
  disown
  for i in $(seq 1 100); do [ -f "$STUB/hung/containers/2.pid" ] && break; sleep 0.1; done
  kill -TERM "$sub"
  for i in $(seq 1 100); do [ -f "$CASE/rc" ] && break; sleep 0.1; done
  if [ -f "$CASE/rc" ]; then assert_eq "143" "$(cat "$CASE/rc")" "the interrupted wait returns 128 + the signal"; else assert_eq "143" "(the call went on)" "the interrupted wait returns 128 + the signal"; fi
  read -r pid _ < "$STUB/hung/containers/1.pid"
  assert_exit 0 "the call's stub is gone" -- gone "$pid"
  read -r pid _ < "$STUB/hung/containers/2.pid"
  assert_exit 0 "and its grandchild" -- gone "$pid"
  kill_recorded_pids "$CASE"
}

wait_for_file() { local i; for i in $(seq 1 100); do [ -e "$1" ] && return 0; sleep 0.1; done; return 1; }

t_an_interrupted_wait_kills_the_calls_group_before_the_callers_handler_can_exit() {
  setup_case "$FUNCNAME"
  printf 'hang-ignore-term\n' > "$STUB/mode"
  R9700_CEILING_SCALE=1 # a real ceiling of 60 s: only the signal can end this call in time
  export R9700_STATE_DIR="$CASE/state"
  local i pid sub
  # the caller's handler EXITS at once: the code after `wait` would never run, so the group KILL must come first (amendment A14)
  ( lock_take step; trap 'echo handler > "$CASE/handler"; exit 0' TERM; wslc_stop r9700tune-a > /dev/null 2>&1 ) &
  sub=$!
  disown
  for i in $(seq 1 100); do [ -f "$STUB/hung/containers/2.pid" ] && break; sleep 0.1; done
  kill -TERM "$sub"
  assert_exit 0 "the caller's own handler ran (the subshell exited)" -- gone "$sub"
  assert_eq "handler" "$(cat "$CASE/handler")" "and it ran exactly where the caller put it"
  read -r pid _ < "$STUB/hung/containers/1.pid"
  assert_exit 0 "the call's stub is gone" -- gone "$pid"
  read -r pid _ < "$STUB/hung/containers/2.pid"
  assert_exit 0 "and its grandchild that ignored TERM" -- gone "$pid"
  kill_recorded_pids "$CASE"
}

t_the_callers_trap_is_back_after_a_call_and_an_unhandled_signal_still_ends_the_caller() {
  setup_case "$FUNCNAME"
  export R9700_STATE_DIR="$CASE/state"
  ( lock_take step; trap 'echo mine' TERM; wslc_stop r9700tune-a > /dev/null 2>&1; trap -p TERM > "$CASE/trap.after" )
  assert_contains "$(cat "$CASE/trap.after")" "echo mine" "the caller's TERM trap is restored after the call"
  ( lock_take step; wslc_stop r9700tune-a > /dev/null 2>&1; trap -p TERM INT HUP > "$CASE/trap.none" )
  assert_eq "" "$(cat "$CASE/trap.none")" "no trap is left behind when the caller had none"
  printf 'hang\n' > "$STUB/mode"
  R9700_CEILING_SCALE=1
  ( lock_take step; wslc_stop r9700tune-a > /dev/null 2>&1; echo survived > "$CASE/survived" ) &
  local sub=$! i
  disown
  for i in $(seq 1 100); do [ -f "$STUB/hung/containers/1.pid" ] && break; sleep 0.1; done
  kill -TERM "$sub"
  assert_exit 0 "a caller without a handler dies of the signal as it always did" -- gone "$sub"
  assert_missing "$CASE/survived" "and does not go on"
  kill_recorded_pids "$CASE"
}

# ---- the interrupt chain, as the supervisor of part (c) will meet it ------------------------------------------------------------------------------

# supervisor_script <body>: writes $CASE/sup.sh, a script that takes the lock (so it owns its traps), runs <body>, and is started under
# `setsid` so that it, its forks and nothing else are in its process group (a signal sent to the group reaches them all, as a terminal's does)
supervisor_script() {
  {
    printf '%s\n' "source \"$REPO/lib/config.sh\"" "source \"$REPO/lib/run_guarded.sh\"" "source \"$REPO/lib/adapter.sh\"" 'lock_take step' "$1"
  } > "$CASE/sup.sh"
}

t_a_signal_to_the_group_runs_the_supervisors_handler_exactly_once_though_the_call_is_in_a_fork() {
  setup_case "$FUNCNAME"
  export R9700_STATE_DIR="$CASE/state" R9700_CEILING_SCALE=1 COUNT="$CASE/count"
  local sig sup i
  for sig in HUP TERM; do
    : > "$COUNT"
    rm -f "$CASE/done" "$STUB/hung/containers/1.pid" "$STUB/counters/hung"
    printf 'hang\n' > "$STUB/mode"
    supervisor_script "trap 'echo run >> \"\$COUNT\"' $sig; out=\"\$(wslc_list)\"; : > \"$CASE/done\""
    setsid bash "$CASE/sup.sh" > /dev/null 2>&1 &
    sup=$!
    disown
    guard_pid "$sup" "sup-$sup"
    for i in $(seq 1 100); do [ -f "$STUB/hung/containers/1.pid" ] && break; sleep 0.1; done
    kill "-$sig" -- "-$sup" # the group of the supervisor: the supervisor and its command-substitution fork
    for i in $(seq 1 100); do [ -f "$CASE/done" ] && break; sleep 0.1; done
    assert_exit 0 "[$sig] the supervisor went on after its handler" -- test -f "$CASE/done"
    assert_eq "1" "$(wc -l < "$COUNT" | tr -d ' ')" "[$sig] the handler ran exactly once (the fork never runs the parent's handler)"
    kill_recorded_pids "$CASE"
    gone "$sup"
  done
}

t_a_handler_that_exits_gives_the_exit_status_of_the_signal_and_never_sees_the_adapters_variables() {
  setup_case "$FUNCNAME"
  export R9700_STATE_DIR="$CASE/state" R9700_CEILING_SCALE=1
  printf 'hang\n' > "$STUB/mode"
  local sub i
  # (a) `exit` alone in the handler: the status of the interrupted command is the signal's, 128 + 15
  ( ( lock_take step; trap 'exit' TERM; wslc_stop r9700tune-a > /dev/null 2>&1 ); echo "$?" > "$CASE/rc" ) &
  sub=$!
  disown
  for i in $(seq 1 100); do [ -f "$STUB/hung/containers/1.pid" ] && break; sleep 0.1; done
  kill -TERM "$(pgrep -P "$sub" -o)"
  for i in $(seq 1 100); do [ -f "$CASE/rc" ] && break; sleep 0.1; done
  assert_eq "143" "$(cat "$CASE/rc" 2> /dev/null)" "(a) the subshell exits 143"
  kill_recorded_pids "$CASE"
  # (b) a handler that reads variables of the same names the adapter used to have as locals sees the CALLER's values
  rm -f "$STUB/hung/containers/1.pid" "$STUB/counters/hung" "$CASE/rc"
  ( rc=caller-rc; tpid=caller-tpid; mode=caller-mode; ceiling=caller-ceiling; grace=caller-grace; exe=caller-exe; name=caller-name
    lock_take step; trap 'echo "[$rc][$tpid][$mode][$ceiling][$grace][$exe][$name]" > "$CASE/seen"; exit 0' TERM
    wslc_stop r9700tune-a > /dev/null 2>&1 ) &
  sub=$!
  disown
  for i in $(seq 1 100); do [ -f "$STUB/hung/containers/1.pid" ] && break; sleep 0.1; done
  kill -TERM "$sub"
  gone "$sub"
  assert_eq "[caller-rc][caller-tpid][caller-mode][caller-ceiling][caller-grace][caller-exe][caller-name]" "$(cat "$CASE/seen" 2> /dev/null)" "(b) the handler reads its own variables"
  kill_recorded_pids "$CASE"
}

# nested_supervisor <body>: the supervisor script of a nesting test, started in the background as `( bash sup.sh; echo $? > rc )`; sets SUP (the
# pid of the bash that runs the script) and WRAP
nested_supervisor() {
  local i
  supervisor_script "$1"
  ( bash "$CASE/sup.sh" > /dev/null 2>&1; echo "$?" > "$CASE/rc" ) 2> /dev/null &
  WRAP=$!
  disown
  for i in $(seq 1 100); do SUP="$(pgrep -P "$WRAP" -f sup.sh | head -n 1)"; [ -n "$SUP" ] && break; sleep 0.1; done
  guard_pid "$SUP" "sup-$SUP"
}

t_a_second_signal_during_a_nested_call_in_a_handler_runs_the_callers_handler_once_and_does_not_recurse() {
  setup_case "$FUNCNAME"
  export R9700_STATE_DIR="$CASE/state" R9700_CEILING_SCALE=1
  printf 'hang\n' > "$STUB/mode"
  local i
  # the plan's own path: a TERM handler (cleanup) makes an adapter call of its own; a HUP during that call must reach the caller's HUP handler
  nested_supervisor "trap 'echo cleanup > \"$CASE/cleanup\"; wslc_stop r9700tune-b' TERM; trap 'echo hup >> \"$CASE/hup\"; exit 9' HUP; wslc_stop r9700tune-a; echo end > \"$CASE/end\""
  for i in $(seq 1 100); do [ -f "$STUB/hung/containers/1.pid" ] && break; sleep 0.1; done
  kill -TERM "$SUP"
  for i in $(seq 1 100); do [ -f "$STUB/hung/containers/2.pid" ] && break; sleep 0.1; done
  assert_exit 0 "the cleanup (the TERM handler) made its own call" -- test -f "$CASE/cleanup"
  kill -HUP "$SUP"
  for i in $(seq 1 100); do [ -f "$CASE/rc" ] && break; sleep 0.1; done # a runaway recursion would never end: the loop is bounded
  assert_eq "9" "$(cat "$CASE/rc" 2> /dev/null)" "the caller's HUP handler ran and its status is the exit status"
  assert_eq "1" "$(wc -l < "$CASE/hup" 2> /dev/null | tr -d ' ')" "it ran exactly once"
  assert_missing "$CASE/end" "and the script did not go on"
  kill -KILL "$SUP" 2> /dev/null
  kill_recorded_pids "$CASE"
}

t_after_a_handler_that_made_a_nested_call_returns_the_callers_original_traps_are_back() {
  setup_case "$FUNCNAME"
  export R9700_STATE_DIR="$CASE/state" R9700_CEILING_SCALE=1
  printf 'hang\n' > "$STUB/mode"
  local i
  # The traps are compared BEFORE and AFTER the call, not with a literal listing: whether `trap -p` lists a signal that was ignored when the shell
  # started (INT in a background job, or under CI) depends on how the shell was started and on the bash version.
  nested_supervisor "trap 'echo hup' HUP; trap 'rm -f \"$STUB/mode\"; wslc_stop r9700tune-b; echo nested-done > \"$CASE/nested\"' TERM; trap -p HUP INT TERM > \"$CASE/traps.before\"; wslc_stop r9700tune-a; trap -p HUP INT TERM > \"$CASE/traps\"; : > \"$CASE/end\""
  for i in $(seq 1 100); do [ -f "$STUB/hung/containers/1.pid" ] && break; sleep 0.1; done
  kill -TERM "$SUP" # the handler removes the hang mode, so its own call returns at once; then the handler returns and the script goes on
  for i in $(seq 1 100); do [ -f "$CASE/end" ] && break; sleep 0.1; done
  assert_exit 0 "the handler's nested call returned and the script went on" -- test -f "$CASE/nested"
  assert_eq "$(cat "$CASE/traps.before")" "$(cat "$CASE/traps" 2> /dev/null)" "the traps after the call equal the traps before it"
  assert_contains "$(cat "$CASE/traps" 2> /dev/null)" "echo hup" "the caller's HUP trap is there"
  assert_contains "$(cat "$CASE/traps" 2> /dev/null)" "nested-done" "and its TERM trap"
  assert_not_contains "$(cat "$CASE/traps" 2> /dev/null)" "_adapter_on_signal" "none of the traps is a hook of the adapter"
  kill -KILL "$SUP" 2> /dev/null
  kill_recorded_pids "$CASE"
}

t_a_nested_call_in_a_handler_leaves_an_ignored_signal_ignored() {
  setup_case "$FUNCNAME"
  export R9700_STATE_DIR="$CASE/state" R9700_CEILING_SCALE=1
  printf 'hang\n' > "$STUB/mode"
  local i
  nested_supervisor "trap '' INT; trap -p INT > \"$CASE/traps.before\"; trap 'rm -f \"$STUB/mode\"; wslc_stop r9700tune-b' TERM; wslc_stop r9700tune-a; trap -p INT > \"$CASE/traps\"; : > \"$CASE/end\""
  for i in $(seq 1 100); do [ -f "$STUB/hung/containers/1.pid" ] && break; sleep 0.1; done
  kill -TERM "$SUP"
  for i in $(seq 1 100); do [ -f "$CASE/end" ] && break; sleep 0.1; done
  assert_eq "$(cat "$CASE/traps.before")" "$(cat "$CASE/traps" 2> /dev/null)" "INT is as it was before both calls (still ignored): the listing is compared, never spelled out"
  assert_not_contains "$(cat "$CASE/traps" 2> /dev/null)" "_adapter_on_signal" "and no hook of the adapter took it"
  kill -KILL "$SUP" 2> /dev/null
  kill_recorded_pids "$CASE"
}

t_a_lock_held_in_a_subshell_stays_held_through_a_direct_adapter_call() {
  setup_case "$FUNCNAME"
  export R9700_STATE_DIR="$CASE/state"
  ( lock_take step; wslc_stop r9700tune-a > /dev/null 2>&1; wslc_run r9700tune-a img > /dev/null 2>&1
    flock -n "$R9700_STATE_DIR/lock" true; echo "$?" > "$CASE/second" )
  assert_eq "1" "$(cat "$CASE/second")" "a second taker is still refused after the holder's own adapter calls (the holder is a subshell)"
  kill_recorded_pids "$CASE"
}

t_a_signal_the_caller_ignores_does_not_end_the_call() {
  setup_case "$FUNCNAME"
  export R9700_STATE_DIR="$CASE/state" R9700_CEILING_SCALE=100 # the call ends by itself at 0.6 s (rc 124)
  printf 'hang\n' > "$STUB/mode"
  local sub i started ended
  started="$(date +%s.%N)"
  ( lock_take step; trap '' TERM; wslc_stop r9700tune-a > /dev/null 2>&1; echo "$?" > "$CASE/rc" ) &
  sub=$!
  disown
  for i in $(seq 1 100); do [ -f "$STUB/hung/containers/1.pid" ] && break; sleep 0.05; done
  kill -TERM "$sub" # ignored by the caller
  for i in $(seq 1 100); do [ -f "$CASE/rc" ] && break; sleep 0.1; done
  ended="$(date +%s.%N)"
  case "$(cat "$CASE/rc" 2> /dev/null)" in 124 | 137) assert_eq ok ok "the call returned its own status (the ceiling: 124, or 137 because the call inherits the ignored TERM), not the signal's" ;; *) assert_eq "124 or 137" "$(cat "$CASE/rc" 2> /dev/null)" "the call returned its own status, not the signal's" ;; esac
  assert_exit 0 "and it ran to its ceiling (0.6 s), it was not cut short" -- awk -v a="$started" -v b="$ended" 'BEGIN { exit !(b - a >= 0.5) }'
  kill_recorded_pids "$CASE"
}

t_the_group_kill_is_one_kill_of_the_group_not_a_list_of_pids() {
  setup_case "$FUNCNAME"
  local mine
  bash -c 'set -m; sleep 1000 & echo $! > "$1"; wait' _ "$CASE/mine.pid" > /dev/null 2>&1 &
  disown
  wait_for_file "$CASE/mine.pid"
  mine="$(cat "$CASE/mine.pid")"
  guard_pid "$mine" "mine-$mine"
  kill() { echo "$*" >> "$CASE/kill.args"; command kill "$@"; }
  _adapter_group_kill "$mine"
  unset -f kill
  assert_eq "-KILL -- -$mine" "$(cat "$CASE/kill.args")" "one kill, of the group: a member that forks meanwhile is in it too"
  assert_exit 0 "and the member is gone" -- gone "$mine"
}

# ---- every command on the right of a pipe closes descriptor 9 itself (it is exec'd from a fork of the lock holder) -------------------------------

t_the_commands_on_the_right_of_a_pipe_do_not_hold_the_lock_descriptor() {
  setup_case "$FUNCNAME"
  export R9700_STATE_DIR="$CASE/state"
  mkdir -p "$CASE/shim"
  local tool real
  for tool in tr tail awk grep sed; do
    real="$(command -v "$tool")"
    printf '#!/usr/bin/env bash\nif [ -e "/proc/$$/fd/9" ]; then echo "%s open" >> "%s/fd9"; else echo "%s closed" >> "%s/fd9"; fi\nexec "%s" "$@"\n' "$tool" "$CASE" "$tool" "$CASE" "$real" > "$CASE/shim/$tool"
    chmod +x "$CASE/shim/$tool"
  done
  PATH="$CASE/shim:$PATH"
  printf 'bench line\n' > "$STUB/answers/bench"
  # the lock holder calls each pipeline function DIRECTLY (no fork of its own): the right-hand commands are the only forks
  ( lock_take step
    wslc_run r9700tune-a img > /dev/null
    wslc_exec 60 r9700tune-a true > /dev/null
    wslc_list > /dev/null
    wslc_logs r9700tune-a > /dev/null
    restore_start > /dev/null
    bench_run r9700tune-a t > /dev/null
    wslc_stop r9700tune-a > /dev/null )
  assert_exit 0 "every shim ran" -- test -f "$CASE/fd9"
  assert_eq "" "$(grep ' open$' "$CASE/fd9" | sort | uniq -c | tr '\n' ';')" "no right-hand command held descriptor 9"
  assert_exit 0 "tr, tail, awk, grep and sed were all seen" -- test "$(awk '{ print $1 }' "$CASE/fd9" | sort -u | tr '\n' ' ')" = "awk grep sed tail tr "
  kill_recorded_pids "$CASE"
}

t_the_group_kill_after_a_ceiling_touches_only_a_group_of_this_session() {
  setup_case "$FUNCNAME"
  local mine foreign
  # a process in this session with a process group of its own (job control gives a background job one)
  bash -c 'set -m; sleep 1000 & echo $! > "$1"; wait' _ "$CASE/mine.pid" > /dev/null 2>&1 &
  disown
  wait_for_file "$CASE/mine.pid"
  mine="$(cat "$CASE/mine.pid")"
  guard_pid "$mine" "mine-$mine"
  assert_eq "$mine" "$(pgrp_of "$mine")" "the premise: its process group id is its pid"
  # a process that is its own session leader: a group of the same shape, but not ours (what a reused pid could be)
  setsid sleep 1000 < /dev/null > /dev/null 2>&1 &
  foreign=$!
  disown
  guard_pid "$foreign" "foreign-$foreign"
  _adapter_group_kill "$foreign"
  assert_exit 0 "a group of another session is left alone" -- kill -0 "$foreign"
  _adapter_group_kill "$mine"
  assert_exit 0 "a group of this session is killed" -- gone "$mine"
  _adapter_group_kill 999999
  assert_eq "0" "$?" "a group that is not there: nothing, quietly"
  kill -KILL "$foreign"
}

t_a_call_never_holds_the_supervisors_lock_descriptor() {
  setup_case "$FUNCNAME"
  printf 'hang\n' > "$STUB/mode"
  R9700_CEILING_SCALE=1
  local i pid
  exec 9> "$CASE/a-lock" # the supervisor's lock descriptor; a child that inherited it would keep the lock after a SIGKILL (amendment A1)
  ( wslc_list > /dev/null 2>&1 ) &
  disown
  for i in $(seq 1 100); do [ -f "$STUB/hung/containers/1.pid" ] && break; sleep 0.1; done
  read -r pid _ < "$STUB/hung/containers/1.pid"
  assert_exit 0 "the call's stub is running" -- kill -0 "$pid"
  assert_exit 0 "the test holds descriptor 9" -- test -e /proc/$BASHPID/fd/9
  assert_exit 1 "the hung child has no descriptor 9" -- test -e "/proc/$pid/fd/9"
  exec 9>&-
  kill_recorded_pids "$CASE"
}

run_all_tests
