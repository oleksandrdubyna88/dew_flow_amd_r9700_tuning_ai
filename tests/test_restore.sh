#!/usr/bin/env bash
# Ownership and recovery, as functions (E1.S2 part (b)): the lock, the recovery marker, the worker gate, the session stop, the restore and
# its readiness wait. Scenarios of the story that need part (c)'s `step` are driven here by tests/lib/fake_supervisor.sh or by a marker
# written by hand. Every test body is a function t_<guarantee>; each runs in its own subshell and writes only below $R9700_TEST_ROOT.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"
# shellcheck source=tests/lib/lifecycle.sh
source "$HERE/lib/lifecycle.sh"

wait_file() { local i; for i in $(seq 1 100); do [ -e "$1" ] && return 0; sleep 0.1; done; return 1; }
boot_id() { cat /proc/sys/kernel/random/boot_id; }

# holder <verb> [<raw holder text>]: a process that holds the lock (exec'd sleep, so its pid is the holder's); sets HOLDER
holder() {
  if [ -n "${2:-}" ]; then
    ( exec 9> "$R9700_STATE_DIR/lock"; flock -n 9; printf '%s\n' "$2" >&9; : > "$CASE/held"; exec sleep 30 ) &
  else
    ( lock_take "$1" || exit 1; : > "$CASE/held"; exec sleep 30 ) &
  fi
  HOLDER=$!
  disown "$HOLDER"
  guard_pid "$HOLDER" "holder-$HOLDER" # the pid in the name: the guard folder is shared by every test of the file, a name of the test would be overwritten
  wait_file "$CASE/held"
}

# ---- the lock (decision 2, amendment A1) ---------------------------------------------------------------------------------------------

t_lock_take_writes_the_holder_line_and_a_second_taker_is_refused_naming_the_holder() {
  lc_setup "$FUNCNAME"
  holder step
  local line
  read -r line < "$R9700_STATE_DIR/lock"
  if [[ $line =~ ^$HOLDER\ step\ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$ ]]; then assert_eq ok ok "the holder line is <pid> <verb> <UTC time>"; else assert_eq "$HOLDER step <time>" "$line" "the holder line is <pid> <verb> <UTC time>"; fi
  assert_exit 4 "a second taker is refused with exit 4" -- lock_take init
  if [[ $ERR =~ ^r9700:\ another\ run\ holds\ $R9700_STATE_DIR/lock:\ pid\ $HOLDER,\ step,\ since\ [0-9T:Z-]+$ ]]; then assert_eq ok ok "the refusal names the file, the pid, the verb and the time"; else assert_eq "r9700: another run holds <state>/lock: pid $HOLDER, step, since <time>" "$ERR" "the refusal names the file, the pid, the verb and the time"; fi
  read -r line < "$R9700_STATE_DIR/lock"
  assert_contains "$line" "$HOLDER step" "the refused taker did not touch the holder's line"
  kill -KILL "$HOLDER"
}

t_a_sigkill_of_the_holder_releases_the_lock() {
  lc_setup "$FUNCNAME"
  holder step
  kill -KILL "$HOLDER"
  gone "$HOLDER"
  assert_exit 0 "the next taker gets the lock" -- lock_take init
  assert_contains "$(cat "$R9700_STATE_DIR/lock")" " init " "and writes its own holder line"
}

t_lock_release_lets_the_next_taker_in() {
  lc_setup "$FUNCNAME"
  lock_take step
  lock_release
  holder verdict
  assert_contains "$(cat "$R9700_STATE_DIR/lock")" "$HOLDER verdict" "another process took it"
  kill -KILL "$HOLDER"
}

t_a_holder_line_that_cannot_be_read_is_reported_as_unknown_not_guessed() {
  lc_setup "$FUNCNAME"
  holder step "junk"
  assert_exit 4 "refused" -- lock_take init
  assert_eq "r9700: another run holds $R9700_STATE_DIR/lock: holder unknown" "$ERR" "the line says unknown"
  kill -KILL "$HOLDER"
}

t_the_state_directory_is_made_and_has_a_default_under_xdg_state_home_or_home() {
  lc_setup "$FUNCNAME"
  assert_eq "/x/y/r9700" "$(env -u R9700_STATE_DIR XDG_STATE_HOME=/x/y HOME=/h bash -c 'source "$1"; state_dir' _ "$REPO/lib/run_guarded.sh")" "XDG_STATE_HOME wins"
  assert_eq "/h/.local/state/r9700" "$(env -u R9700_STATE_DIR -u XDG_STATE_HOME HOME=/h bash -c 'source "$1"; state_dir' _ "$REPO/lib/run_guarded.sh")" "else HOME/.local/state"
  assert_eq "$R9700_STATE_DIR" "$(state_dir)" "R9700_STATE_DIR overrides both"
  rmdir "$R9700_STATE_DIR"
  assert_exit 0 "lock_take makes the state directory" -- lock_take step
  assert_eq "700" "$(stat -c %a "$R9700_STATE_DIR")" "private to the user"
}

t_lock_take_refuses_a_state_directory_it_cannot_make() {
  lc_setup "$FUNCNAME"
  : > "$CASE/afile"
  R9700_STATE_DIR="$CASE/afile/sub"
  assert_exit 2 "a state directory below a file" -- lock_take step
  assert_contains "$ERR" "state directory" "the line says what failed"
}

# supervisor_in_a_call <command...>: a process that holds the lock and waits inside <command> (a command substitution) on a hung stub;
# sets SUB; returns when the stub of the call is up
supervisor_in_a_call() {
  local i
  printf 'hang\n' > "$STUB/mode"
  export R9700_CEILING_SCALE=1 # real ceilings: the call outlives the supervisor by a minute
  ( lock_take step || exit 1; : > "$CASE/held"; out="$("$@")" ) > /dev/null 2>&1 &
  SUB=$!
  disown "$SUB"
  guard_pid "$SUB" "supervisor-$SUB"
  wait_file "$CASE/held"
  for i in $(seq 1 100); do [ -f "$STUB/hung/containers/1.pid" ] && break; sleep 0.1; done
}

t_a_sigkill_of_the_supervisor_inside_a_command_substitution_frees_the_lock_at_once() {
  local command n=0
  for command in "wslc_list" "restore_probe vllm" "win_ram_mb" "wslc_logs r9700tune-a"; do
    n=$((n + 1))
    lc_setup "$FUNCNAME-$n"
    supervisor_in_a_call $command
    assert_exit 1 "[$command] the lock is held while the supervisor waits in the call" -- flock -n "$R9700_STATE_DIR/lock" true
    kill -KILL "$SUB"
    gone "$SUB"
    assert_exit 0 "[$command] after the SIGKILL the lock is free at once (the forks of the call do not hold it: amendment A1)" -- flock -n "$R9700_STATE_DIR/lock" true
    kill_recorded_pids "$CASE"
  done
}

t_a_sigkill_of_the_supervisor_during_the_readiness_sleep_frees_the_lock_at_once() {
  lc_setup "$FUNCNAME"
  wslc_run vllm img > /dev/null
  printf 'fail\n' > "$STUB/answers/ready"
  export R9700_TIME_SCALE=1 # the 10 s interval between probes is real: a long sleep
  ( lock_take step; : > "$CASE/held"; ready_wait vllm 3300 ) > /dev/null 2>&1 &
  local sub=$! i sleeper=""
  disown "$sub"
  guard_pid "$sub" "supervisor-$sub"
  for i in $(seq 1 100); do sleeper="$(pgrep -P "$sub" -x sleep | head -n 1)"; [ -n "$sleeper" ] && break; sleep 0.1; done
  assert_exit 0 "the supervisor sleeps between two probes" -- test -n "$sleeper"
  guard_pid "$sleeper" "sleeper-$sleeper"
  kill -KILL "$sub"
  gone "$sub"
  assert_exit 0 "the lock is free although the sleep goes on" -- flock -n "$R9700_STATE_DIR/lock" true
  kill -KILL "$sleeper" 2> /dev/null
  kill_recorded_pids "$CASE"
}

# ---- readiness ends at its own deadline (amendment A13) -----------------------------------------------------------------------------------------

t_a_probe_that_hangs_at_the_limit_ends_the_wait_within_one_grace() {
  lc_setup "$FUNCNAME"
  wslc_run vllm img > /dev/null
  printf 'hang\n' > "$STUB/mode"
  export R9700_CEILING_SCALE=10 # a probe may take 7 s, a list 6 s: the deadline must cut them
  local started ended
  started="$(date +%s.%N)"
  assert_exit 5 "ready_wait over a hung wslc" -- ready_wait vllm 60
  ended="$(date +%s.%N)"
  assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "one stderr line"
  assert_contains "$ERR" "r9700: restore: vllm not ready after " "its shape"
  # the window is 0.6 s (60 s / 100), its end rounded up to a whole second, plus one grace of 0.5 s (5 s / 10)
  assert_exit 0 "the wait ended within the window and one grace, not after a full probe ceiling" -- awk -v a="$started" -v b="$ended" 'BEGIN { exit !(b - a < 3.2) }'
  kill_recorded_pids "$CASE"
}

t_ready_wait_leaves_the_callers_stop_time_as_it_was() {
  lc_setup "$FUNCNAME"
  wslc_run vllm img > /dev/null
  R9700_T_STOP=4102444800 # far in the future
  assert_exit 0 "ready_wait" -- ready_wait vllm 60
  assert_eq "4102444800" "$R9700_T_STOP" "the local stop time did not leak out"
  kill_recorded_pids "$CASE"
}

# ---- worker_start checks that it made a session leader (amendment A14) -------------------------------------------------------------------------

t_worker_start_refuses_a_worker_that_is_not_its_own_session_leader() {
  lc_setup "$FUNCNAME"
  local rc gate="$CASE/steps/9.gate" i
  mkdir -p "$CASE/steps"
  # with job control on, a background job leads a process group, so setsid forks and $! is a process that is not the worker
  ( set -m; worker_start "$gate" "$CASE/worker.log" "$STUBS/worker.sh" ok; echo "$?" > "$CASE/rc" ) > "$CASE/out" 2>&1
  rc="$(cat "$CASE/rc")"
  assert_eq "1" "$rc" "refused"
  assert_contains "$(cat "$CASE/out")" "worker_start: " "one line says why"
  assert_contains "$(cat "$CASE/out")" "session" "naming the session"
  # the worker that did start sits at the gate and gives up by itself (30 s at ceiling scale 10 = 3 s); nothing is left
  R9700_CEILING_SCALE=100
  for i in $(seq 1 100); do pgrep -f "worker_gate.sh $gate" > /dev/null || break; sleep 0.1; done
  assert_exit 1 "no gated worker is left" -- pgrep -f "worker_gate.sh $gate"
  assert_missing "$STUB/worker.calls" "and it never ran its command"
}

# ---- the recovery marker (decision 3) -----------------------------------------------------------------------------------------------------

t_marker_write_stores_values_in_the_config_grammar_atomically_and_marker_read_returns_them() {
  lc_setup "$FUNCNAME"
  local f="$CASE/m.env"
  assert_exit 0 "marker_write" -- marker_write "$f" MARKER_VERSION=1 RUN_ID=r-1 RESTORE_ARGS="-Model x -Detach" PROD_CONTAINER=vllm
  assert_eq $'MARKER_VERSION=1\nRUN_ID=r-1\nRESTORE_ARGS="-Model x -Detach"\nPROD_CONTAINER=vllm' "$(cat "$f")" "bare values bare, a value with spaces in one pair of double quotes"
  assert_missing "$f.part" "no .part file is left"
  assert_missing "$CASE/m.env.part" "(same, by the other spelling)"
  write_marker
  marker_read "$MARKER_FILE"
  assert_eq "-Model /root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ -ServedName qwen3.6-35b-a3b -MaxModelLen 131072 -MaxNumSeqs 4 -Detach" "${MARKER[RESTORE_ARGS]}" "a quoted value is read back whole"
  assert_eq "vllm" "${MARKER[PROD_CONTAINER]}" "a bare one too"
}

t_marker_write_goes_through_a_part_file_and_a_rename() {
  lc_setup "$FUNCNAME"
  local f="$CASE/m.env"
  write_marker
  cp "$MARKER_FILE" "$f"
  mv() { echo "$*" >> "$CASE/mv.args"; command mv "$@"; }
  marker_write "$f" MARKER_VERSION=1 RUN_ID=r-2
  assert_eq "$f.part $f" "$(cat "$CASE/mv.args")" "mv <file>.part <file>"
}

t_marker_write_refuses_a_value_it_cannot_store_and_leaves_the_old_marker_alone() {
  lc_setup "$FUNCNAME"
  write_marker
  local before bad
  before="$(cat "$MARKER_FILE")"
  for bad in 'a"b' 'a$b' 'a`b' $'a\nb' $'a\rb'; do
    assert_exit 2 "[$bad] is refused" -- marker_write "$MARKER_FILE" RUN_ID="$bad"
    assert_contains "$ERR" "RUN_ID" "the line names the key"
  done
  assert_exit 2 "a key that is not UPPER_CASE" -- marker_write "$MARKER_FILE" run_id=x
  assert_exit 2 "a word that is not KEY=VALUE" -- marker_write "$MARKER_FILE" RUN_ID
  assert_eq "$before" "$(cat "$MARKER_FILE")" "the old marker is untouched"
  assert_missing "$MARKER_FILE.part" "and no .part file is left"
}

t_marker_read_refuses_what_it_cannot_trust_naming_the_file_and_the_line() {
  lc_setup "$FUNCNAME"
  local bad n=0 override
  # <override>: one marker line changed or added to a good marker
  for override in 'EXTRA=1' 'RUN_ID=a$b' 'RUN_ID=a`b' 'PROD_WAS_RUNNING=maybe' 'MARKER_VERSION=2' 'READY_TIMEOUT_S=5' 'WORKER_START_TICKS=abc' 'BOOT_ID=nonsense' 'RUN_DIR=relative/dir' 'PROD_CONTAINER=-x' 'WSLC=a b' 'CONTAINER_PREFIX=x'; do
    n=$((n + 1))
    write_marker "$override"
    assert_exit 2 "[$override]" -- marker_read "$MARKER_FILE"
    if [[ $ERR =~ ^marker:\ $MARKER_FILE:[0-9]+:\  ]]; then assert_eq ok ok "[$override]: marker: <file>:<line>: ..."; else assert_eq "marker: <file>:<line>: ..." "$ERR" "[$override]: marker: <file>:<line>: ..."; fi
  done
  write_marker; printf 'not a key line\n' >> "$MARKER_FILE"
  assert_exit 2 "a line that is no KEY=VALUE" -- marker_read "$MARKER_FILE"
  write_marker; printf 'RUN_ID=again\n' >> "$MARKER_FILE"
  assert_exit 2 "a key twice" -- marker_read "$MARKER_FILE"
  assert_contains "$ERR" "twice" "the line says so"
  write_marker; printf 'DISK=1\r\n' >> "$MARKER_FILE"
  assert_exit 2 "a CRLF line end" -- marker_read "$MARKER_FILE"
  write_marker -RUN_ID
  assert_exit 2 "a missing required key" -- marker_read "$MARKER_FILE"
  assert_contains "$ERR" "missing RUN_ID" "named"
  write_marker WORKER_PGID=123
  assert_exit 2 "worker keys must come all together" -- marker_read "$MARKER_FILE"
  assert_contains "$ERR" "WORKER" "the line names them"
  assert_exit 2 "a file that is not there" -- marker_read "$CASE/nosuch.env"
  assert_contains "$ERR" "nosuch.env" "named"
}

t_marker_read_accepts_the_worker_keys_the_boot_id_and_the_run_dir() {
  lc_setup "$FUNCNAME"
  write_marker WORKER_PGID=4242 WORKER_START_TICKS=1234567890123 BOOT_ID="$(boot_id)" RUN_DIR="\"$CASE/some run\""
  assert_exit 0 "a full marker" -- marker_read "$MARKER_FILE"
  assert_eq "4242" "${MARKER[WORKER_PGID]}" "pgid"
  assert_eq "1234567890123" "${MARKER[WORKER_START_TICKS]}" "ticks: more than 9 digits after a long uptime"
  assert_eq "$(boot_id)" "${MARKER[BOOT_ID]}" "boot id"
}

t_marker_write_base_records_what_the_restore_needs_from_the_config_and_the_boot_id() {
  lc_setup "$FUNCNAME"
  assert_exit 0 "marker_write_base" -- marker_write_base "$MARKER_FILE" run-9 yes "$CASE/run"
  marker_read "$MARKER_FILE"
  assert_eq "run-9" "${MARKER[RUN_ID]}" "run id"
  assert_eq "yes" "${MARKER[PROD_WAS_RUNNING]}" "pre-run state"
  assert_eq "vllm" "${MARKER[PROD_CONTAINER]}" "prod container"
  assert_eq 'C:\r9700\start-vllm.ps1' "${MARKER[RESTORE_SCRIPT_WIN]}" "restore script"
  assert_eq "$R9700_RESTORE_ARGS" "${MARKER[RESTORE_ARGS]}" "restore args"
  assert_eq "wslc" "${MARKER[WSLC]}" "wslc"
  assert_eq "pwsh.exe" "${MARKER[RESTORE_SHELL]}" "restore shell"
  assert_eq "r9700tune-" "${MARKER[CONTAINER_PREFIX]}" "prefix"
  assert_eq "1200" "${MARKER[READY_TIMEOUT_S]}" "ready timeout"
  assert_eq "" "${MARKER[BOOT_ID]:-}" "no boot id yet: it comes with the worker keys"
  assert_eq "$CASE/run" "${MARKER[RUN_DIR]}" "run dir"
  assert_eq "" "${MARKER[WORKER_PGID]:-}" "no worker keys yet"
  [[ ${MARKER[WRITTEN_AT]} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$ ]] && assert_eq ok ok "WRITTEN_AT is UTC" || assert_eq "<UTC time>" "${MARKER[WRITTEN_AT]}" "WRITTEN_AT is UTC"
  assert_exit 2 "an invalid pre-run state is refused" -- marker_write_base "$MARKER_FILE" run-9 perhaps "$CASE/run"
  assert_exit 2 "an invalid run id is refused" -- marker_write_base "$MARKER_FILE" 'a b' yes "$CASE/run"
}

t_marker_add_worker_keeps_every_key_and_adds_the_three_worker_keys() {
  lc_setup "$FUNCNAME"
  marker_write_base "$MARKER_FILE" run-9 yes "$CASE/run"
  assert_exit 0 "marker_add_worker" -- marker_add_worker "$MARKER_FILE" 4242 98765
  marker_read "$MARKER_FILE"
  assert_eq "4242" "${MARKER[WORKER_PGID]}" "pgid"
  assert_eq "98765" "${MARKER[WORKER_START_TICKS]}" "ticks"
  assert_eq "$(boot_id)" "${MARKER[BOOT_ID]}" "the boot id comes with them"
  assert_eq "run-9" "${MARKER[RUN_ID]}" "the run id is kept"
  assert_eq "$R9700_RESTORE_ARGS" "${MARKER[RESTORE_ARGS]}" "so is the quoted value"
  assert_missing "$MARKER_FILE.part" "no .part file is left"
  assert_exit 2 "a pgid that is not a number" -- marker_add_worker "$MARKER_FILE" x 1
  assert_exit 2 "ticks that are not a number" -- marker_add_worker "$MARKER_FILE" 1 ""
  assert_exit 2 "a marker that is not there" -- marker_add_worker "$CASE/nosuch.env" 1 1
}

t_marker_remove_removes_the_file_and_says_nothing() {
  lc_setup "$FUNCNAME"
  write_marker
  assert_exit 0 "marker_remove" -- marker_remove "$MARKER_FILE"
  assert_missing "$MARKER_FILE" "gone"
  assert_exit 0 "removing a marker that is not there is fine" -- marker_remove "$MARKER_FILE"
}

# ---- the worker gate (amendment A2, decision 3) --------------------------------------------------------------------------------------------

t_the_worker_gate_runs_the_command_in_its_own_process_after_the_gate_file_appears() {
  lc_setup "$FUNCNAME"
  local gate="$CASE/gate" pid
  "$REPO/lib/worker_gate.sh" "$gate" bash -c 'echo $$ > "$1"; printf "%s\n" "${@:2}" > "$2"' _ "$CASE/pid" "$CASE/args" a "b c" &
  pid=$!
  disown "$pid"
  guard_pid "$pid" "gate-$pid"
  sleep 0.3
  assert_missing "$CASE/pid" "nothing runs before the gate file exists"
  gate_open "$gate"
  wait_file "$CASE/args"
  assert_eq "$pid" "$(cat "$CASE/pid")" "the command is exec'd: same process"
  assert_eq $'a\nb c' "$(sed -n '2,3p' "$CASE/args")" "its arguments arrive whole"
}

t_the_worker_gate_without_a_gate_file_exits_4_by_itself_and_runs_nothing() {
  lc_setup "$FUNCNAME"
  local started ended
  export R9700_CEILING_SCALE=100 # 30 s of the gate wait become 0.3 s
  started="$(date +%s.%N)"
  assert_exit 4 "no gate file: exit 4" -- "$REPO/lib/worker_gate.sh" "$CASE/never" touch "$CASE/ran"
  ended="$(date +%s.%N)"
  assert_missing "$CASE/ran" "the command never ran"
  assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "one stderr line"
  assert_contains "$ERR" "gate" "it names the gate"
  assert_exit 0 "bounded: 30 s at ceiling scale 100 is 0.3 s" -- awk -v a="$started" -v b="$ended" 'BEGIN { exit !(b - a < 5 && b - a >= 0.25) }'
}

t_the_worker_gate_refuses_bad_arguments_and_an_invalid_time_scale() {
  lc_setup "$FUNCNAME"
  assert_exit 2 "no argument" -- "$REPO/lib/worker_gate.sh"
  assert_exit 2 "a gate and no command" -- "$REPO/lib/worker_gate.sh" "$CASE/g"
  assert_exit 2 "an empty gate path" -- "$REPO/lib/worker_gate.sh" "" true
  R9700_CEILING_SCALE=abc assert_exit 2 "an invalid ceiling scale" -- "$REPO/lib/worker_gate.sh" "$CASE/g" true
  assert_contains "$ERR" "R9700_CEILING_SCALE" "names it"
}

t_worker_start_makes_a_session_leader_that_waits_at_the_gate_without_the_lock_descriptor() {
  lc_setup "$FUNCNAME"
  exec 9> "$CASE/a-lock"
  assert_exit 0 "worker_start" -- worker_start "$CASE/gate" "$CASE/worker.log" "$STUBS/worker.sh" ok
  disown "$WORKER_PID" # no "Killed" job notice when the test ends it
  guard_pid "$WORKER_PID" "worker-$WORKER_PID"
  assert_eq "$WORKER_PID" "$(pgrp_of "$WORKER_PID")" "its pid is its process group id"
  assert_eq "$WORKER_PID" "$(sid_of "$WORKER_PID")" "and its session id"
  assert_eq "$(_start_ticks "$WORKER_PID")" "$WORKER_TICKS" "the start ticks are the real ones"
  assert_exit 1 "no descriptor 9: the lock stays with the supervisor (amendment A1)" -- test -e "/proc/$WORKER_PID/fd/9"
  sleep 0.3
  assert_missing "$STUB/worker.calls" "the worker has done nothing: the gate is shut"
  gate_open "$CASE/gate"
  wait_file "$STUB/worker.done"
  assert_exit 0 "after the gate the worker ran" -- test -f "$STUB/worker.calls"
  assert_contains "$(cat "$CASE/worker.log" 2> /dev/null; echo)" "" "its output goes to the log"
  exec 9>&-
}

# ---- stopping a session (amendment A8) ------------------------------------------------------------------------------------------------------

# session_with_stubborn_member <name>: a leader and a member that both ignore TERM; sets LEADER and MEMBER
session_with_stubborn_member() {
  mkdir -p "$CASE/s"
  setsid bash -c 'trap "" TERM; sleep 1000 & echo $! > "$1"; wait' _ "$CASE/s/$1.member" > /dev/null 2>&1 &
  LEADER=$!
  disown "$LEADER"
  guard_pid "$LEADER" "leader-$LEADER"
  wait_file "$CASE/s/$1.member"
  MEMBER="$(cat "$CASE/s/$1.member")"
  guard_pid "$MEMBER" "member-$MEMBER"
}

t_session_pids_lists_the_leader_and_the_members_of_one_session_only() {
  lc_setup "$FUNCNAME"
  session_with_stubborn_member a
  session_with_stubborn_member b
  assert_eq "$(printf '%s\n' "$LEADER" "$MEMBER" | sort -n | tr '\n' ' ')" "$(session_pids "$LEADER" | sort -n | tr '\n' ' ')" "session b: its leader and its member, not session a's"
  assert_eq "" "$(session_pids 999999)" "an unknown session has no member"
  assert_exit 2 "a session id that is not a number" -- session_pids x
}

t_session_stop_ends_members_that_ignore_term_after_the_grace_and_never_signals_its_caller() {
  lc_setup "$FUNCNAME"
  session_with_stubborn_member a
  assert_exit 0 "session_stop" -- session_stop "$LEADER"
  assert_exit 0 "the leader is gone" -- gone "$LEADER"
  assert_exit 0 "the member that ignored TERM is gone" -- gone "$MEMBER"
  # the caller inside the session it stops survives (setsid: the subshell leads a session of its own)
  setsid bash -c 'source "$1"; source "$2"; session_stop "$(awk "{ print \$6 }" /proc/self/stat)"; echo survived > "$3"' _ "$REPO/lib/run_guarded.sh" "$REPO/lib/restore.sh" "$CASE/survived" > /dev/null 2>&1
  assert_exit 0 "a caller in the stopped session is not signalled" -- test -f "$CASE/survived"
}

t_proc_ticks_is_field_22_of_the_stat_file_and_empty_for_a_gone_process() {
  lc_setup "$FUNCNAME"
  assert_eq "$(_start_ticks $$)" "$(proc_ticks $$)" "the same value as the helper of the tests"
  assert_eq "" "$(proc_ticks 999999)" "nothing for a pid that does not exist"
}

# ---- the container stop with log tails ----------------------------------------------------------------------------------------------------------

t_container_stop_all_saves_a_200_line_tail_before_each_stop_and_touches_only_the_prefix() {
  lc_setup "$FUNCNAME"
  seq 1 300 > "$STUB/answers/logs"
  wslc_run r9700tune-a img > /dev/null
  wslc_run other-x img > /dev/null
  local run="$CASE/run" tail_file
  assert_exit 0 "container_stop_all" -- container_stop_all "$run"
  tail_file="$(ls "$run"/guard/*-r9700tune-a.tail.log)"
  assert_eq "200" "$(wc -l < "$tail_file" | tr -d ' ')" "exactly 200 lines"
  assert_eq "300" "$(tail -n 1 "$tail_file")" "the last one is line 300"
  assert_eq "1" "$(ls "$run"/guard | wc -l | tr -d ' ')" "one tail: the foreign container has none"
  [[ $(basename "$tail_file") =~ ^[0-9]{8}T[0-9]{6}Z-r9700tune-a\.tail\.log$ ]] && assert_eq ok ok "<UTC stamp>-<name>.tail.log" || assert_eq "<stamp>-r9700tune-a.tail.log" "$(basename "$tail_file")" "<UTC stamp>-<name>.tail.log"
  assert_eq "other-x" "$(wslc_list)" "only the prefixed container was stopped"
  local logs_line stop_line
  logs_line="$(grep -n ' wslc logs r9700tune-a' "$STUB/calls.log" | cut -d: -f1)"
  stop_line="$(grep -n ' wslc stop r9700tune-a' "$STUB/calls.log" | cut -d: -f1)"
  assert_exit 0 "the logs call precedes the stop call (--rm removes the log with the container)" -- test "$logs_line" -lt "$stop_line"
  kill_recorded_pids "$CASE"
}

t_container_stop_all_reports_a_container_that_would_not_stop() {
  lc_setup "$FUNCNAME"
  wslc_run r9700tune-a img > /dev/null
  mkdir -p "$CASE/bin"
  printf '#!/usr/bin/env bash\n[ "$1" = stop ] && exit 1\nexec "%s/wslc" "$@"\n' "$STUBS" > "$CASE/bin/wslc"
  chmod +x "$CASE/bin/wslc"
  R9700_WSLC="$CASE/bin/wslc"
  assert_exit 1 "a stop that fails is a failure" -- container_stop_all "$CASE/run"
  assert_contains "$ERR" "r9700tune-a" "the line names the container"
  kill_recorded_pids "$CASE"
}

# ---- the restore from a marker (decisions 3, 4, 5; brief 6) --------------------------------------------------------------------------------------

t_a_restore_starts_the_operators_server_once_waits_until_it_is_ready_and_removes_the_marker() {
  lc_setup "$FUNCNAME"
  write_marker
  assert_exit 0 "restore_from_marker" -- restore_from_marker "$MARKER_FILE" "$CASE/run"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the start script ran once"
  assert_eq "vllm" "$(wslc_list)" "the server runs"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_exit 0 "at least one probe went through wslc exec" -- test "$(grep -c ' wslc exec vllm python3 ' "$STUB/calls.log")" -ge 1
  assert_eq "" "$ERR" "nothing on stderr"
  kill_recorded_pids "$CASE"
}

t_a_restore_of_a_server_that_already_runs_starts_nothing_and_still_waits_for_readiness() {
  lc_setup "$FUNCNAME"
  write_marker
  wslc_run vllm img > /dev/null
  assert_exit 0 "restore_from_marker" -- restore_from_marker "$MARKER_FILE" "$CASE/run"
  assert_contains "$OUT" "restore: vllm already running" "says so"
  assert_eq "0" "$(log_count pwsh.exe -Detach)" "no start"
  assert_exit 0 "readiness was probed" -- test "$(grep -c ' wslc exec vllm python3 ' "$STUB/calls.log")" -ge 1
  assert_missing "$MARKER_FILE" "the marker is gone"
  kill_recorded_pids "$CASE"
}

t_a_server_that_was_not_running_is_not_started_and_the_prefixed_containers_are_stopped() {
  lc_setup "$FUNCNAME"
  write_marker PROD_WAS_RUNNING=no
  wslc_run r9700tune-old img > /dev/null
  assert_exit 0 "restore_from_marker" -- restore_from_marker "$MARKER_FILE" "$CASE/run"
  assert_eq "" "$(wslc_list)" "nothing runs: the leftover container is stopped, the server was never started"
  assert_eq "0" "$(grep -c ' pwsh.exe ' "$STUB/calls.log")" "no start script call"
  assert_eq "0" "$(grep -c ' wslc stop vllm' "$STUB/calls.log")" "no stop of the operator's server"
  assert_eq "0" "$(grep -c ' wslc exec ' "$STUB/calls.log")" "no readiness probe: there is nothing to wait for"
  assert_missing "$MARKER_FILE" "the marker is gone once every prefixed container is stopped"
  assert_exit 0 "the tail of the stopped container was saved" -- test "$(ls "$CASE"/run/guard/*-r9700tune-old.tail.log | wc -l)" -eq 1
}

t_a_marker_stays_when_a_prefixed_container_cannot_be_stopped() {
  lc_setup "$FUNCNAME"
  write_marker PROD_WAS_RUNNING=no
  wslc_run r9700tune-old img > /dev/null
  mkdir -p "$CASE/bin"
  printf '#!/usr/bin/env bash\n[ "$1" = stop ] && exit 1\nexec "%s/wslc" "$@"\n' "$STUBS" > "$CASE/bin/wslc"
  chmod +x "$CASE/bin/wslc"
  write_marker PROD_WAS_RUNNING=no "WSLC=$CASE/bin/wslc"
  assert_exit 5 "the restore fails" -- restore_from_marker "$MARKER_FILE" "$CASE/run"
  assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "one stderr line"
  assert_contains "$ERR" "r9700tune-old" "naming the container"
  assert_exit 0 "the marker is kept" -- test -f "$MARKER_FILE"
  kill_recorded_pids "$CASE"
}

t_a_restore_that_never_becomes_ready_exits_5_with_one_line_and_keeps_the_marker() {
  lc_setup "$FUNCNAME"
  write_marker
  printf 'fail\n' > "$STUB/answers/ready"
  assert_exit 5 "not ready" -- restore_from_marker "$MARKER_FILE" "$CASE/run"
  assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "exactly one stderr line"
  if [[ $ERR =~ ^r9700:\ restore:\ vllm\ not\ ready\ after\ [0-9]+\ s\ \( ]]; then assert_eq ok ok "its shape: r9700: restore: vllm not ready after <n> s (<last probe result>)"; else assert_eq "r9700: restore: vllm not ready after <n> s (...)" "$ERR" "its shape"; fi
  assert_exit 0 "the marker is kept" -- test -f "$MARKER_FILE"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "no second start on top of a loading server"
  kill_recorded_pids "$CASE"
}

t_a_server_that_answers_models_but_not_a_completion_is_not_ready() {
  lc_setup "$FUNCNAME"
  write_marker
  printf 'models-only\n' > "$STUB/answers/ready"
  assert_exit 5 "not ready" -- restore_from_marker "$MARKER_FILE" "$CASE/run"
  assert_contains "$ERR" "completion: HTTP 500)" "the line ends with the failing check and its status (a last call cut by the window only adds a note before it)"
  assert_exit 0 "the marker is kept" -- test -f "$MARKER_FILE"
  kill_recorded_pids "$CASE"
}

t_a_probe_cut_by_the_window_keeps_the_last_real_reason_and_adds_the_window() {
  lc_setup "$FUNCNAME"
  write_marker
  # the first probe answers HTTP 500, the second never answers: the window (0.6 s, its end rounded up to a whole second) cuts that last
  # call, deterministically, without any load
  printf 'models-only\nhang\n' > "$STUB/answers/ready"
  assert_exit 5 "not ready" -- restore_from_marker "$MARKER_FILE" "$CASE/run"
  assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "one stderr line"
  assert_contains "$ERR" "completion: HTTP 500)" "the line still ends with the last real failing check and its status"
  assert_contains "$ERR" "the probe timed out" "and it says the last call was cut"
  assert_exit 0 "the marker is kept" -- test -f "$MARKER_FILE"
  kill_recorded_pids "$CASE"
}

t_a_window_that_ended_before_the_first_answer_says_only_that() {
  lc_setup "$FUNCNAME"
  write_marker
  printf 'hang\n' > "$STUB/answers/ready"
  assert_exit 5 "not ready" -- restore_from_marker "$MARKER_FILE" "$CASE/run"
  assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "one stderr line"
  assert_contains "$ERR" "(the probe timed out)" "no earlier answer: only the timeout is named"
  kill_recorded_pids "$CASE"
}

t_a_server_that_is_not_listed_three_times_in_a_row_is_reported_at_once() {
  lc_setup "$FUNCNAME"
  write_marker READY_TIMEOUT_S=3300
  export R9700_STUB_PROD=other-server # the start script starts a container that is not the operator's name: vllm is never listed
  printf 'fail\n' > "$STUB/answers/ready"
  local started ended
  started="$(date +%s.%N)"
  assert_exit 5 "not ready" -- restore_from_marker "$MARKER_FILE" "$CASE/run"
  ended="$(date +%s.%N)"
  assert_contains "$ERR" "vllm not listed 3 times in a row" "the reason"
  assert_exit 0 "three misses end the wait long before the timeout (34.8 s at scale 100)" -- awk -v a="$started" -v b="$ended" 'BEGIN { exit !(b - a < 15) }'
  kill_recorded_pids "$CASE"
}

t_a_start_script_that_cannot_run_is_one_stderr_line_and_the_marker_stays() {
  lc_setup "$FUNCNAME"
  write_marker RESTORE_SHELL=nonesuch.exe
  assert_exit 5 "restore start failed" -- restore_from_marker "$MARKER_FILE" "$CASE/run"
  assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "one stderr line"
  assert_contains "$ERR" "nonesuch.exe" "naming the shell"
  assert_exit 0 "the marker is kept" -- test -f "$MARKER_FILE"
}

t_a_malformed_marker_is_refused_with_exit_2_and_kept() {
  lc_setup "$FUNCNAME"
  write_marker 'EXTRA=1'
  assert_exit 2 "refused" -- restore_from_marker "$MARKER_FILE" "$CASE/run"
  assert_contains "$ERR" "marker: $MARKER_FILE:" "named"
  assert_exit 0 "kept" -- test -f "$MARKER_FILE"
  assert_missing "$STUB/calls.log" "nothing was called"
}

t_the_restore_uses_the_markers_values_not_the_config_and_ignores_the_run_deadline() {
  lc_setup "$FUNCNAME"
  write_marker
  R9700_WSLC=nonesuch-wslc # a config that would break every call: the marker's own WSLC=wslc is what counts
  R9700_T_STOP=1           # an expired deadline: the cleanup phase runs without one (decision 8, amendment A9)
  assert_exit 0 "restore_from_marker" -- restore_from_marker "$MARKER_FILE" "$CASE/run"
  assert_eq "nonesuch-wslc" "$R9700_WSLC" "the caller's variables are as they were"
  assert_eq "1" "$R9700_T_STOP" "(T_STOP too)"
  kill_recorded_pids "$CASE"
}

# a recorded worker: a real stub worker behind its gate, in its own session; sets WORKER_PID, WORKER_TICKS and CHILD
recorded_worker() {
  mkdir -p "$CASE/run/steps"
  R9700_RUN_DIR="$CASE/run" R9700_STEP_N=1 worker_start "$CASE/gate" "$CASE/worker.log" "$STUBS/worker.sh" child
  disown "$WORKER_PID"
  guard_pid "$WORKER_PID" "worker-$WORKER_PID"
  gate_open "$CASE/gate"
  wait_file "$STUB/child.pid"
  CHILD="$(cat "$STUB/child.pid")"
  guard_pid "$CHILD" "workerchild-$CHILD"
}

t_a_recorded_worker_is_stopped_when_pid_boot_id_and_start_ticks_all_match() {
  lc_setup "$FUNCNAME"
  recorded_worker
  write_marker "WORKER_PGID=$WORKER_PID" "WORKER_START_TICKS=$WORKER_TICKS" "BOOT_ID=$(boot_id)" PROD_WAS_RUNNING=no
  assert_exit 0 "restore_from_marker" -- restore_from_marker "$MARKER_FILE" "$CASE/run"
  local said="$OUT"
  assert_exit 0 "the worker is gone" -- gone "$WORKER_PID"
  assert_exit 0 "and its child (the whole session)" -- gone "$CHILD"
  assert_contains "$said" "stopped worker session $WORKER_PID" "the restore says so"
}

t_a_recorded_worker_whose_pid_was_reused_or_whose_boot_differs_is_not_touched() {
  lc_setup "$FUNCNAME"
  recorded_worker
  write_marker "WORKER_PGID=$WORKER_PID" "WORKER_START_TICKS=1" "BOOT_ID=$(boot_id)" PROD_WAS_RUNNING=no
  assert_exit 0 "other start ticks: the restore still completes" -- restore_from_marker "$MARKER_FILE" "$CASE/run"
  local said="$OUT"
  assert_exit 0 "the process with that pid is alive (reused pid: not ours)" -- kill -0 "$WORKER_PID"
  assert_exit 0 "and its child" -- kill -0 "$CHILD"
  assert_contains "$said" "not stopped" "the restore says it left the process"
  write_marker "WORKER_PGID=$WORKER_PID" "WORKER_START_TICKS=$WORKER_TICKS" "BOOT_ID=00000000-0000-0000-0000-000000000000" PROD_WAS_RUNNING=no
  assert_exit 0 "another boot id" -- restore_from_marker "$MARKER_FILE" "$CASE/run"
  assert_exit 0 "right ticks but another boot: the pid is not trusted" -- kill -0 "$WORKER_PID"
  kill -KILL -- "-$WORKER_PID" 2> /dev/null
}

t_a_recorded_workers_orphaned_members_are_stopped_when_its_leader_is_already_gone() {
  lc_setup "$FUNCNAME"
  recorded_worker
  write_marker "WORKER_PGID=$WORKER_PID" "WORKER_START_TICKS=$WORKER_TICKS" "BOOT_ID=$(boot_id)" PROD_WAS_RUNNING=no
  kill -KILL "$WORKER_PID"
  gone "$WORKER_PID"
  assert_exit 0 "the child outlives its leader" -- kill -0 "$CHILD"
  assert_exit 0 "restore_from_marker" -- restore_from_marker "$MARKER_FILE" "$CASE/run"
  assert_exit 0 "the member of the dead leader's session is stopped" -- gone "$CHILD"
}

t_a_marker_without_worker_keys_stops_no_process() {
  lc_setup "$FUNCNAME"
  recorded_worker
  write_marker PROD_WAS_RUNNING=no
  assert_exit 0 "restore_from_marker" -- restore_from_marker "$MARKER_FILE" "$CASE/run"
  assert_exit 0 "the worker is untouched" -- kill -0 "$WORKER_PID"
  kill -KILL -- "-$WORKER_PID" 2> /dev/null
}

t_restore_now_restores_from_the_state_directorys_marker_into_the_run_directory() {
  lc_setup "$FUNCNAME"
  write_marker
  RUN_DIR="$CASE/run"
  assert_exit 0 "restore_now" -- restore_now
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_eq "vllm" "$(wslc_list)" "the server runs"
  kill_recorded_pids "$CASE"
}

t_ready_wait_returns_0_at_the_first_good_probe_and_prints_nothing() {
  lc_setup "$FUNCNAME"
  wslc_run vllm img > /dev/null
  assert_exit 0 "ready_wait" -- ready_wait vllm 60
  assert_eq "" "$OUT$ERR" "silent"
  assert_eq "1" "$(grep -c ' wslc exec vllm python3 ' "$STUB/calls.log")" "one probe"
  assert_exit 2 "a timeout that is not a number" -- ready_wait vllm x
  assert_exit 2 "a name that could be an option" -- ready_wait -x 60
  kill_recorded_pids "$CASE"
}

run_all_tests
