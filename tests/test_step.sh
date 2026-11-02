#!/usr/bin/env bash
# `bin/r9700 step` as a user runs it (E1.S2 part (c)): scenarios L1-L3, L4/L19 (the step form), L6, L8 (the TERM half), L10-L14, L20 (the
# label), L21 (the real hook), L22, and the interrupt rules: INT and TERM, a second signal during the cleanup, a TERM during a quiet wait and
# during a hung adapter call, the lock descriptor in every child, the one cleanup. The guards through `step` are tests/test_guards.sh; the
# restore-first and `init` scenarios are tests/test_lifecycle.sh. Every test body is a function t_<guarantee>; each runs in its own subshell and
# writes only below $R9700_TEST_ROOT. Faults are triggered after the stub worker wrote <run dir>/steps/<n>.ready (amendment A3).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"
# shellcheck source=tests/lib/lifecycle.sh
source "$HERE/lib/lifecycle.sh"
# shellcheck source=tests/lib/stepcase.sh
source "$HERE/lib/stepcase.sh"

# ======================================================================================================================================================
# Part (c): the `step` verb. L1-L3, L8 (the TERM half), L11-L14, L19, L20 (the label), L21 (the real hook), L22, and the interrupt rules.
# ======================================================================================================================================================

WORKER="$STUBS/worker.sh"

# L1: the config is refused before any server is stopped
t_l1_step_refuses_an_invalid_config_before_any_server_is_stopped() {
  step_setup "$FUNCNAME"
  step_cfg DISK_GATE=maybe
  prod_running
  assert_exit 2 "step with DISK_GATE=maybe" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "one stderr line"
  assert_contains "$ERR" "config: " "a config: line"
  assert_contains "$ERR" "DISK_GATE" "naming the field"
  assert_eq "0" "$(stop_lines)" "the call log has no stop line"
  assert_exit 0 "the operator's server still runs" -- test -f "$STUB/containers/vllm.pid"
  assert_missing "$STUB/worker.calls" "and the worker never ran"
}

# L2: a step stops the server once, runs the worker, restores once; the marker is gone; the outcome is typed
t_l2_a_step_stops_the_server_once_runs_the_worker_restores_once_and_leaves_no_marker() {
  step_setup "$FUNCNAME"
  prod_running
  assert_exit 0 "step t -- worker.sh ok" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  assert_exit 0 "worker.done exists" -- test -f "$STUB/worker.done"
  assert_eq "1" "$(count_calls wslc stop)" "exactly one wslc stop"
  assert_eq "1" "$(grep -c ' wslc stop vllm$' "$STUB/calls.log")" "and it is vllm"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "exactly one start script call"
  assert_eq "pwsh.exe -NoProfile -File C:\\r9700\\start-vllm.ps1" "$(awk '$3 == "pwsh.exe" { print $3, $4, $5, $6 }' "$STUB/calls.log")" "the start script of the fixture"
  local stop_at start_at done_at
  stop_at="$(stamp_of ' wslc stop vllm$')"
  start_at="$(stamp_of ' pwsh.exe ')"
  done_at="$(stat -c %.9Y "$STUB/worker.done")"
  if awk -v a="$stop_at" -v b="$done_at" -v c="$start_at" 'BEGIN { exit !(a < b && b < c) }'; then assert_eq ok ok "stop vllm, then worker.done, then the start script"; else assert_eq "stop < worker.done < pwsh" "$stop_at $done_at $start_at" "the order"; fi
  assert_exit 0 "the server is back" -- test -f "$STUB/containers/vllm.pid"
  assert_missing "$MARKER_FILE" "the marker is gone"
  local run
  run="$(run_dir_of)"
  outcome_read "$run/steps/1.outcome"
  assert_eq "worker" "$O_KIND" "KIND=worker"
  assert_eq "0" "$O_RC" "RC=0"
  assert_eq "done" "$(cat "$run/status")" "the run's status is done"
  kill_recorded_pids "$CASE"
}

t_the_worker_gets_the_run_folder_the_step_number_the_label_the_stop_time_and_the_outcome_file() {
  step_setup "$FUNCNAME"
  prod_running
  assert_exit 0 "step probe -- worker.sh ok" -- r9700 step --model "$MODEL_35B" probe -- "$WORKER" ok
  local run
  run="$(run_dir_of)"
  assert_eq "RUN_DIR=$run" "$(sed -n 1p "$STUB/worker.env")" "R9700_RUN_DIR"
  assert_eq "STEP_N=1" "$(sed -n 2p "$STUB/worker.env")" "R9700_STEP_N"
  assert_eq "STEP_LABEL=probe" "$(sed -n 3p "$STUB/worker.env")" "R9700_STEP_LABEL"
  if [[ "$(sed -n 4p "$STUB/worker.env")" =~ ^T_STOP=[0-9]+$ ]]; then assert_eq ok ok "R9700_T_STOP is an epoch second"; else assert_eq "T_STOP=<digits>" "$(sed -n 4p "$STUB/worker.env")" "R9700_T_STOP"; fi
  assert_eq "OUTCOME_FILE=$run/steps/1.outcome" "$(sed -n 5p "$STUB/worker.env")" "R9700_OUTCOME_FILE"
  kill_recorded_pids "$CASE"
}

# L3: the marker is written before the stop and carries what the restore needs
t_l3_the_marker_is_written_before_the_stop_and_carries_what_the_restore_needs() {
  step_setup "$FUNCNAME"
  prod_running
  step_bg --model "$MODEL_35B" t -- "$WORKER" child
  local run
  run="$(run_dir_of)"
  wait_for "$run/steps/1.ready" 100
  append_answer ram 100 # not needed: the worker is stopped by the end of the test
  assert_exit 0 "the marker copy of step 1 exists" -- test -f "$run/steps/1.marker"
  marker_read "$run/steps/1.marker"
  assert_eq "yes" "${MARKER[PROD_WAS_RUNNING]}" "PROD_WAS_RUNNING=yes"
  assert_eq 'C:\r9700\start-vllm.ps1' "${MARKER[RESTORE_SCRIPT_WIN]}" "RESTORE_SCRIPT_WIN"
  assert_eq "-Model /root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ -ServedName qwen3.6-35b-a3b -MaxModelLen 131072 -MaxNumSeqs 4 -Detach" "${MARKER[RESTORE_ARGS]}" "RESTORE_ARGS is the fixture's"
  assert_eq "wslc" "${MARKER[WSLC]}" "WSLC"
  assert_eq "r9700tune-" "${MARKER[CONTAINER_PREFIX]}" "CONTAINER_PREFIX"
  local stop_at marker_at worker
  worker="$(sed 's/ .*//' "$STUB/workers/containers/"worker-*.pid | head -n 1)"
  assert_eq "$worker" "${MARKER[WORKER_PGID]}" "the evidence copy holds the worker's pgid (it is taken AFTER the worker keys)"
  assert_eq "$(proc_ticks "$worker")" "${MARKER[WORKER_START_TICKS]}" "and its start ticks (field 22 of the worker's stat)"
  assert_eq "$(cat /proc/sys/kernel/random/boot_id)" "${MARKER[BOOT_ID]}" "and the boot id"
  stop_at="$(stamp_of ' wslc stop vllm$')"
  marker_at="$(stat -c %.9Y "$run/steps/1.marker")"
  if awk -v a="$marker_at" -v b="$stop_at" 'BEGIN { exit !(a < b) }'; then assert_eq ok ok "yet the copy's mtime is the time of the first write, before the stop line's stamp"; else assert_eq "marker < stop" "$marker_at $stop_at" "the copy keeps the pre-stop time"; fi
  marker_read "$MARKER_FILE"
  assert_eq "$worker" "${MARKER[WORKER_PGID]}" "the live marker names the worker too"
  kill -TERM "$SUP"
  step_end
  kill_recorded_pids "$CASE"
}

# L8 (TERM half): a second invocation is refused while a step runs; TERM ends the supervisor with the cleanup done
t_l8_a_second_invocation_is_refused_while_a_step_runs_and_term_ends_it_with_everything_restored() {
  step_setup "$FUNCNAME"
  prod_running
  step_bg --model "$MODEL_35B" t -- "$WORKER" child
  local run before
  run="$(run_dir_of)"
  wait_for "$STUB/child.pid" 100
  before="$(stop_lines)"
  assert_exit 4 "init while the step runs" -- r9700 init --model "$MODEL_35B"
  if [[ $ERR =~ ^r9700:\ another\ run\ holds\ $R9700_STATE_DIR/lock:\ pid\ $SUP,\ step,\ since\ [0-9T:Z-]+$ ]]; then assert_eq ok ok "r9700: another run holds <state>/lock: pid <pid>, step, since <time>"; else assert_eq "r9700: another run holds <state>/lock: pid $SUP, step, since <time>" "$ERR" "the refusal"; fi
  assert_eq "$before" "$(stop_lines)" "the second invocation stopped nothing"
  local child
  child="$(cat "$STUB/child.pid")"
  kill -TERM "$SUP"
  step_end
  assert_eq "143" "$SRC" "the supervisor exits 143"
  assert_eq "r9700: interrupted, restored" "$SERR" "and says so on stderr"
  assert_exit 0 "the child is dead" -- gone "$child"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the start script ran once"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_eq "interrupted" "$(cat "$run/status")" "the status is interrupted"
  outcome_read "$run/steps/1.outcome"
  assert_eq "interrupted" "$O_KIND" "the signal handler wrote KIND=interrupted"
  kill_recorded_pids "$CASE"
}

t_an_int_ends_the_supervisor_with_130_and_the_same_cleanup() {
  step_setup "$FUNCNAME"
  prod_running
  local -a drop=()
  local key
  while read -r key; do drop+=("R9700_$key"); done < <(config_keys | awk '{ print $2 }')
  # a background job of a non-interactive shell ignores SIGINT, and an ignored signal cannot be trapped: start the supervisor with the default
  python3 -I -c 'import os, signal, sys
signal.signal(signal.SIGINT, signal.SIG_DFL)
for key in sys.argv[1].split(): os.environ.pop(key, None)
os.execv(sys.argv[2], sys.argv[2:])' "${drop[*]}" "$REPO/bin/r9700" step --model "$MODEL_35B" t -- "$WORKER" child > "$CASE/sup.out" 2> "$CASE/sup.err" &
  SUP=$!
  guard_pid "$SUP" "supervisor-$SUP"
  wait_for "$STUB/child.pid" 100
  local child
  child="$(cat "$STUB/child.pid")"
  kill -INT "$SUP"
  step_end
  assert_eq "130" "$SRC" "exit 130"
  assert_eq "r9700: interrupted, restored" "$SERR" "the stderr line"
  assert_exit 0 "the child is dead" -- gone "$child"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
  kill_recorded_pids "$CASE"
}

t_a_second_signal_during_the_cleanup_does_not_start_a_second_restore() {
  step_setup "$FUNCNAME"
  prod_running
  printf 'fail\nfail\nfail\nfail\nok\n' > "$STUB/answers/ready" # the restore needs several probes: a wide window
  step_bg --model "$MODEL_35B" t -- "$WORKER" child
  wait_for "$STUB/child.pid" 100
  kill -TERM "$SUP"
  local i
  for i in $(seq 1 100); do [ "$(log_count pwsh.exe -Detach)" -ge 1 ] && break; sleep 0.05; done
  kill -TERM "$SUP" 2> /dev/null
  kill -INT "$SUP" 2> /dev/null
  step_end
  assert_eq "143" "$SRC" "the exit is the first signal's"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the start script ran exactly once"
  assert_missing "$MARKER_FILE" "and the restore finished: the marker is gone"
  assert_exit 0 "the server is back" -- test -f "$STUB/containers/vllm.pid"
  kill_recorded_pids "$CASE"
}

t_a_term_during_a_quiet_wait_ends_the_wait_at_once_and_touches_nothing() {
  step_setup "$FUNCNAME"
  prod_running
  set_load 9.0
  export R9700_TIME_SCALE=2 # a quiet-check tick of 150 s: a foreground sleep would hold the trap that long
  step_bg --model "$MODEL_35B" t -- "$WORKER" ok
  local run start end
  run="$(run_dir_of)"
  for _ in $(seq 1 100); do grep -q 'quiet-checks=0/1' "$run/supervisor.log" 2> /dev/null && break; sleep 0.1; done
  start="$(date +%s.%N)"
  kill -TERM "$SUP"
  step_end
  end="$(date +%s.%N)"
  assert_eq "143" "$SRC" "exit 143"
  if awk -v a="$start" -v b="$end" 'BEGIN { exit !(b - a < 5) }'; then assert_eq ok ok "within five seconds, not a tick of 150 s"; else assert_eq "< 5 s" "$(awk -v a="$start" -v b="$end" 'BEGIN { print b - a }')" "the TERM was held"; fi
  assert_eq "0" "$(stop_lines)" "no server was stopped (never admitted)"
  assert_exit 0 "the server still runs" -- test -f "$STUB/containers/vllm.pid"
  assert_eq "0" "$(log_count pwsh.exe -Detach)" "and nothing was started"
  assert_eq "" "$(ps -o pid= --ppid "$SUP" 2> /dev/null | tr -d ' \n')" "no child of the supervisor is left (the sleeper was killed)"
}

# L11: the worker's exit 3 is waited out and the same step repeats; it is not a failed try
t_l11_a_worker_exit_3_is_waited_out_and_the_same_step_repeats_without_a_failed_try() {
  step_setup "$FUNCNAME"
  prod_running
  step_bg --model "$MODEL_35B" t -- "$WORKER" exit3-then-ok
  local run
  run="$(run_dir_of)"
  wait_for "$run/steps/1.outcome" 100
  set_load 9.0 # the server-stopped quiet wait: the first check is busy
  for _ in $(seq 1 100); do grep -q 'quiet-checks=0/1' "$run/supervisor.log" 2> /dev/null && break; sleep 0.05; done
  set_load 0.5
  step_end
  assert_eq "0" "$SRC" "exit 0"
  assert_eq "2" "$(wc -l < "$STUB/worker.calls" | tr -d ' ')" "worker.calls = 2"
  outcome_read "$run/steps/1.outcome"
  assert_eq "worker 3" "$O_KIND $O_RC" "steps/1.outcome has KIND=worker RC=3"
  outcome_read "$run/steps/2.outcome"
  assert_eq "worker 0" "$O_KIND $O_RC" "steps/2.outcome has RC=0"
  assert_contains "$SOUT" "not quiet at a unit start, waiting" "stdout says it is waiting"
  assert_not_contains "$SOUT" "failed try" "and counts no failed try"
  assert_eq "1" "$(count_calls wslc stop)" "the server was stopped once"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
  kill_recorded_pids "$CASE"
}

# L12: after an exit 3 the server is restored while a long wait goes on; the stops are bounded
t_l12_after_an_exit_3_the_server_is_restored_while_the_wait_goes_on_until_the_stop_time() {
  step_setup "$FUNCNAME"
  step_cfg MAX_RUN_MINUTES=50 CLEANUP_BUDGET_S=600 READY_TIMEOUT_S=60 # scale 100: T_END 30 s, T_STOP 24 s
  prod_running
  local start end
  start="$(date +%s.%N)"
  step_bg --model "$MODEL_35B" t -- "$WORKER" exit3
  local run
  run="$(run_dir_of)"
  wait_for "$run/steps/1.outcome" 100
  set_load 9.0
  step_end
  end="$(date +%s.%N)"
  assert_eq "8" "$SRC" "exit 8"
  assert_eq "r9700: not quiet before the deadline" "$SERR" "the stderr line"
  assert_exit 0 "the server is back" -- test -f "$STUB/containers/vllm.pid"
  assert_eq "1" "$(count_calls wslc stop)" "exactly one stop vllm"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "exactly one restore"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_contains "$(cat "$run/supervisor.log")" "restoring the operator's server while the PC is not quiet" "the restore came while waiting, not only at the end"
  if awk -v a="$start" -v b="$end" 'BEGIN { exit !(b - a < 30) }'; then assert_eq ok ok "the call ended before T_END"; else assert_eq "< 30 s" "$(awk -v a="$start" -v b="$end" 'BEGIN { print b - a }')" "the call ended before T_END"; fi
  assert_eq "not-quiet" "$(cat "$run/status")" "the status is not-quiet"
  kill_recorded_pids "$CASE"
}

t_l12_the_stops_per_invocation_are_bounded_by_max_server_stops() {
  step_setup "$FUNCNAME"
  step_cfg MAX_SERVER_STOPS=1
  prod_running
  assert_exit 8 "worker exit3 with MAX_SERVER_STOPS=1, the PC quiet throughout" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" exit3
  assert_eq "r9700: server stopped 1 times, limit MAX_SERVER_STOPS=1" "$ERR" "the stderr line"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "pwsh.exe once (the cleanup)"
  assert_eq "1" "$(count_calls wslc stop)" "and one stop"
  assert_exit 0 "the server is back" -- test -f "$STUB/containers/vllm.pid"
  kill_recorded_pids "$CASE"
}

# L13: a failing worker is retried up to MAX_FAILED_TRIES, then exit 7
t_l13_a_failing_worker_is_retried_up_to_max_failed_tries_then_exit_7() {
  step_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=2
  prod_running
  assert_exit 7 "worker fail with MAX_FAILED_TRIES=2" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" fail
  assert_eq "r9700: step failed 2 times, last: worker 1" "$ERR" "the stderr line"
  assert_contains "$OUT" "failed try 1 of 2: worker 1" "stdout counts the first try"
  local run
  run="$(run_dir_of)"
  assert_eq "2" "$(ls "$run/steps" | grep -c '\.outcome$')" "two outcome files"
  outcome_read "$run/steps/1.outcome"
  assert_eq "worker 1" "$O_KIND $O_RC" "the first is KIND=worker RC=1"
  outcome_read "$run/steps/2.outcome"
  assert_eq "worker 1" "$O_KIND $O_RC" "so is the second"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "pwsh.exe once"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_eq "failed" "$(cat "$run/status")" "the status is failed"
  kill_recorded_pids "$CASE"
}

# L14: worker exit 4 ends the step cleanly as a deadline
t_l14_a_worker_exit_4_ends_the_step_cleanly_as_a_deadline() {
  step_setup "$FUNCNAME"
  prod_running
  assert_exit 6 "worker exit4" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" exit4
  if [[ $ERR =~ ^r9700:\ deadline:\ step\ stopped ]]; then assert_eq ok ok "stderr begins r9700: deadline: step stopped"; else assert_eq "r9700: deadline: step stopped ..." "$ERR" "stderr begins"; fi
  local run
  run="$(run_dir_of)"
  assert_eq "1" "$(ls "$run/steps" | grep -c '\.outcome$')" "one outcome file"
  outcome_read "$run/steps/1.outcome"
  assert_eq "worker 4" "$O_KIND $O_RC" "KIND=worker RC=4"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "restore once"
  assert_missing "$MARKER_FILE" "marker gone"
  assert_eq "deadline" "$(cat "$run/status")" "the status is deadline"
  kill_recorded_pids "$CASE"
}

# L4 in its step form, and L19: the run folder is the durable status
t_l4_and_l19_a_restore_that_never_becomes_ready_exits_5_keeps_the_marker_and_says_restore_failed() {
  step_setup "$FUNCNAME"
  prod_running
  printf 'ok\n' > "$STUB/answers/ready"
  step_bg --model "$MODEL_35B" t -- "$WORKER" ok
  local run
  run="$(run_dir_of)"
  wait_for "$run/steps/1.ready" 100
  printf 'fail\n' > "$STUB/answers/ready" # the worker does not use it; the restore at the end does
  step_end
  assert_eq "5" "$SRC" "exit 5"
  assert_eq 1 "$(printf '%s\n' "$SERR" | wc -l | tr -d ' ')" "exactly one stderr line"
  if [[ $SERR =~ ^r9700:\ restore:\ vllm\ not\ ready\ after\ [0-9]+\ s\ \( ]]; then assert_eq ok ok "r9700: restore: vllm not ready after <n> s ("; else assert_eq "r9700: restore: vllm not ready after <n> s (" "$SERR" "the line"; fi
  assert_exit 0 "the marker is kept" -- test -f "$MARKER_FILE"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one start (no second start on a loading server)"
  assert_eq "restore-failed" "$(cat "$run/status")" "the status is restore-failed"
  kill_recorded_pids "$CASE"
}

t_l19_the_supervisor_log_holds_admitted_worker_ended_and_restored_in_order() {
  step_setup "$FUNCNAME"
  prod_running
  assert_exit 0 "step t -- worker.sh ok" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  local run
  run="$(run_dir_of)"
  assert_eq "admitted
worker ended rc=0
restored" "$(grep -E ' (admitted|worker ended rc=[0-9]+|restored)$' "$run/supervisor.log" | sed 's/^[^ ]* //')" "the three lines, in this order"
  assert_contains "$OUT" " admitted" "and the same lines went to stdout"
  kill_recorded_pids "$CASE"
}

# L20 (the label and the arguments), before the lock and the restore
t_l20_a_bad_label_or_a_bad_step_command_is_refused_before_anything_else() {
  step_setup "$FUNCNAME"
  write_marker
  assert_exit 2 "a label with a capital and a space" -- r9700 step --model "$MODEL_35B" 'Bad Label' -- true
  assert_contains "$ERR" '^[a-z0-9][a-z0-9-]{0,39}$' "the line names the rule"
  assert_exit 2 "a label that is too long" -- r9700 step --model "$MODEL_35B" "a$(printf 'b%.0s' $(seq 1 40))" -- true
  assert_exit 2 "no --" -- r9700 step --model "$MODEL_35B" t true
  assert_contains "$ERR" "step: usage" "a usage line"
  assert_exit 2 "no command after --" -- r9700 step --model "$MODEL_35B" t --
  assert_exit 2 "no label" -- r9700 step --model "$MODEL_35B"
  assert_exit 2 "an unknown option" -- r9700 step --frob t -- true
  assert_exit 0 "the marker is untouched: no restore for a syntax error" -- test -f "$MARKER_FILE"
  assert_missing "$STUB/calls.log" "nothing was called"
  assert_missing "$R9700_STATE_DIR/lock" "and no lock was taken"
}

# L21 (the real hook): the supervisor kills itself right after the worker start
t_l21_the_real_step_killed_before_the_gate_leaves_a_worker_that_only_waits_and_the_next_invocation_restores() {
  step_setup "$FUNCNAME"
  prod_running
  export R9700_TEST_KILL_BEFORE_GATE=1
  assert_exit 137 "step with the kill hook" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  unset R9700_TEST_KILL_BEFORE_GATE
  assert_exit 0 "the marker exists" -- test -f "$MARKER_FILE"
  marker_read "$MARKER_FILE"
  assert_eq "" "${MARKER[WORKER_PGID]:-}" "without worker keys"
  local run i
  run="$(run_dir_of)"
  for i in $(seq 1 100); do [ -s "$run/steps/1.worker.log" ] && break; sleep 0.1; done
  assert_contains "$(cat "$run/steps/1.worker.log")" "gate" "the worker gave up at the gate"
  assert_missing "$STUB/worker.calls" "the worker never ran its command"
  assert_missing "$run/steps/1.gate" "the gate file was never made"
  assert_exit 2 "the next invocation restores first" -- r9700 verdict "$CASE/nodir"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_exit 0 "and the server is back" -- test -f "$STUB/containers/vllm.pid"
  kill_recorded_pids "$CASE"
}

t_l6_a_sigkill_of_the_real_step_leaves_the_marker_and_the_next_verb_restores_first() {
  step_setup "$FUNCNAME"
  prod_running
  step_bg --model "$MODEL_35B" t -- "$WORKER" child
  wait_for "$STUB/child.pid" 100
  local worker child
  worker="$(sed 's/ .*//' "$STUB/workers/containers/"worker-*.pid | head -n 1)"
  child="$(cat "$STUB/child.pid")"
  marker_read "$MARKER_FILE"
  assert_eq "$worker" "${MARKER[WORKER_PGID]}" "the marker names the worker"
  assert_exit 1 "no descriptor 9 in the worker" -- test -e "/proc/$worker/fd/9"
  kill -KILL "$SUP"
  step_end
  assert_exit 0 "the worker outlives the supervisor" -- kill -0 "$worker"
  assert_exit 0 "the lock is free" -- flock -n "$R9700_STATE_DIR/lock" true
  assert_exit 2 "verdict on no outdir" -- r9700 verdict "$CASE/nodir"
  assert_exit 0 "the worker is gone" -- gone "$worker"
  assert_exit 0 "and its child" -- gone "$child"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
  kill_recorded_pids "$CASE"
}

# L10: a server that was not running is not started
t_l10_a_server_that_was_not_running_is_not_started_by_the_restore() {
  step_setup "$FUNCNAME"
  assert_exit 0 "step with no server running" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  assert_eq "0" "$(count_calls wslc stop)" "no stop vllm"
  assert_eq "0" "$(log_count pwsh.exe -Detach)" "no start script call"
  assert_missing "$MARKER_FILE" "the marker is gone at the end"
  local run
  run="$(run_dir_of)"
  marker_read "$run/steps/1.marker"
  assert_eq "no" "${MARKER[PROD_WAS_RUNNING]}" "the marker copy has PROD_WAS_RUNNING=no"
}

# L22: a body with two step_run calls restores once
t_l22_a_body_with_two_step_run_calls_restores_the_server_exactly_once() {
  step_setup "$FUNCNAME"
  prod_running
  two_steps() { step_run a -- "$WORKER" ok || return $?; step_run b -- "$WORKER" ok; }
  ( source "$REPO/bin/r9700"; _R9700_MODEL_ARG="$MODEL_35B"; supervise run prepare_run two_steps; exit $? ) > "$CASE/sup.out" 2> "$CASE/sup.err"
  assert_eq "0" "$?" "supervise returns 0"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the start script ran exactly once"
  assert_eq "1" "$(count_calls wslc stop)" "and the server was stopped once (the second step finds it down)"
  assert_eq "2" "$(wc -l < "$STUB/worker.calls" | tr -d ' ')" "both steps ran"
  local run
  run="$(run_dir_of)"
  assert_exit 0 "each step has its own gate file (A14)" -- test -f "$run/steps/1.gate" -a -f "$run/steps/2.gate"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_exit 0 "the server is back" -- test -f "$STUB/containers/vllm.pid"
  kill_recorded_pids "$CASE"
}

t_an_admission_that_cannot_list_the_containers_is_a_failed_try_and_stops_nothing() {
  step_setup "$FUNCNAME"
  prod_running
  sed -i 's|^WSLC=.*|WSLC=/nonexistent/wslc|' "$CASE/machine.env"
  step_cfg MAX_FAILED_TRIES=2
  assert_exit 7 "step with a wslc that is not there" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  assert_contains "$ERR" "r9700: step failed 2 times, last: admit " "the line names the admission"
  assert_missing "$STUB/worker.calls" "the worker never ran"
  assert_missing "$MARKER_FILE" "no marker (nothing was stopped)"
}

t_a_term_during_a_hung_adapter_call_of_the_supervisor_ends_the_call_and_the_run_with_143() {
  step_setup "$FUNCNAME"
  prod_running
  printf 'hang\n' > "$STUB/mode" # the supervisor's first adapter call (the container list of the admission) hangs
  step_bg --model "$MODEL_35B" t -- "$WORKER" ok
  wait_for "$STUB/hung/containers/1.pid" 100
  local hung start end
  read -r hung _ < "$STUB/hung/containers/1.pid"
  start="$(date +%s.%N)"
  kill -TERM "$SUP"
  step_end
  end="$(date +%s.%N)"
  assert_eq "143" "$SRC" "exit 143"
  assert_exit 0 "the hung stub call is dead (the call's group got the KILL before the handler ran)" -- gone "$hung"
  if awk -v a="$start" -v b="$end" 'BEGIN { exit !(b - a < 3) }'; then assert_eq ok ok "the run ended within three seconds, not at the call's ceiling"; else assert_eq "< 3 s" "$(awk -v a="$start" -v b="$end" 'BEGIN { print b - a }')" "the run ended at once"; fi
  assert_eq "0" "$(stop_lines)" "no server was stopped"
  assert_exit 0 "the operator's server still runs" -- test -f "$STUB/containers/vllm.pid"
  assert_missing "$STUB/worker.calls" "no worker ran"
  rm -f "$STUB/mode"
  kill_recorded_pids "$CASE"
}

t_no_child_of_the_supervisor_holds_the_lock_descriptor_and_none_outlives_the_step() {
  step_setup "$FUNCNAME"
  prod_running
  step_bg --model "$MODEL_35B" t -- "$WORKER" child
  wait_for "$STUB/child.pid" 100
  sleep 0.3
  local pid held="" all=""
  for pid in $(pgrep -P "$SUP"); do
    all+="$pid "
    for sub in "$pid" $(pgrep -P "$pid"); do
      all+="$sub "
      [ -e "/proc/$sub/fd/9" ] && held+="$sub "
    done
  done
  assert_exit 0 "the supervisor itself holds descriptor 9" -- test -e "/proc/$SUP/fd/9"
  assert_eq "" "$held" "no child or grandchild of the supervisor (the worker, the guards, their sleepers) holds descriptor 9"
  assert_exit 0 "there were children to look at (the scan is alive)" -- test "$(wc -w <<< "$all")" -ge 3
  kill -TERM "$SUP"
  step_end
  local alive=""
  for pid in $all; do kill -0 "$pid" 2> /dev/null && alive+="$pid "; done
  assert_eq "" "$alive" "none of them is alive after the step ended"
  kill_recorded_pids "$CASE"
}

t_an_exit_in_the_body_still_runs_the_one_cleanup_through_the_exit_trap() {
  step_setup "$FUNCNAME"
  prod_running
  leaving_body() { step_run a -- "$WORKER" ok; exit 4; }
  ( source "$REPO/bin/r9700"; _R9700_MODEL_ARG="$MODEL_35B"; supervise run prepare_run leaving_body ) > "$CASE/sup.out" 2> "$CASE/sup.err"
  assert_eq "4" "$?" "the body's own exit code"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the server was restored, once"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_eq "failed" "$(cat "$(run_dir_of)/status")" "the status says the run did not end well"
  assert_exit 0 "and the lock is free" -- flock -n "$R9700_STATE_DIR/lock" true
  kill_recorded_pids "$CASE"
}

t_cleanup_once_runs_once_whatever_calls_it() {
  step_setup "$FUNCNAME"
  prod_running
  twice_body() { step_run a -- "$WORKER" ok || return $?; cleanup_once done; cleanup_once failed; echo "second=$?"; }
  ( source "$REPO/bin/r9700"; _R9700_MODEL_ARG="$MODEL_35B"; supervise run prepare_run twice_body ) > "$CASE/sup.out" 2> "$CASE/sup.err"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "two calls, one restore"
  assert_contains "$(cat "$CASE/sup.out")" "second=0" "the second call returns the first one's result"
  assert_eq "done" "$(cat "$(run_dir_of)/status")" "and the first kind stays"
  kill_recorded_pids "$CASE"
}

# ---- item 2: a failed admission is not a stop of the server --------------------------------------------------------------------------------------

t_failed_admissions_that_never_stopped_the_server_do_not_use_up_max_server_stops() {
  step_setup "$FUNCNAME"
  prod_running
  sed -i 's|^WSLC=.*|WSLC=/nonexistent/wslc|' "$CASE/machine.env"
  assert_exit 7 "six failed container lists (MAX_FAILED_TRIES 6) with MAX_SERVER_STOPS 3" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  assert_contains "$ERR" "r9700: step failed 6 times, last: admit " "the tries ran out, not the stops"
  assert_not_contains "$ERR" "server stopped" "no stop budget line"
}

# ---- item 3: the signals are shut out BEFORE the once-flag is set --------------------------------------------------------------------------------

t_a_term_right_before_cleanup_once_shuts_the_signals_out_still_gets_a_real_cleanup() {
  step_setup "$FUNCNAME"
  prod_running
  # a DEBUG trap sends TERM to the supervisor just before the `trap ''` line of cleanup_once runs: the window between the two lines
  hit_body() {
    step_run a -- "$WORKER" ok || return $?
    _dbg_done=0
    set -T
    trap 'if [ "$_dbg_done" = 0 ] && [ "$BASH_COMMAND" = "trap '"''"' INT TERM HUP" ]; then _dbg_done=1; kill -TERM $BASHPID; fi' DEBUG
  }
  ( source "$REPO/bin/r9700"; _R9700_MODEL_ARG="$MODEL_35B"; supervise run prepare_run hit_body ) > "$CASE/sup.out" 2> "$CASE/sup.err"
  local rc=$?
  assert_missing "$MARKER_FILE" "the marker is gone: the cleanup really ran (no 'restored' printed over a cleanup that did nothing)"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the server was restored, once"
  assert_exit 0 "the server is back" -- test -f "$STUB/containers/vllm.pid"
  if [ "$rc" = 143 ] || [ "$rc" = 0 ]; then assert_eq ok ok "and the exit code is 0 or the signal's 143 ($rc)"; else assert_eq "0 or 143" "$rc" "the exit code"; fi
  kill_recorded_pids "$CASE"
}

# ---- item 6: HUP is an interrupt like INT and TERM -----------------------------------------------------------------------------------------------

t_a_hup_ends_the_supervisor_with_129_and_the_same_cleanup() {
  step_setup "$FUNCNAME"
  prod_running
  step_bg --model "$MODEL_35B" t -- "$WORKER" child
  local run child
  run="$(run_dir_of)"
  wait_for "$STUB/child.pid" 100
  child="$(cat "$STUB/child.pid")"
  kill -HUP "$SUP"
  step_end
  assert_eq "129" "$SRC" "exit 129"
  assert_eq "r9700: interrupted, restored" "$SERR" "the stderr line"
  assert_exit 0 "the child is dead" -- gone "$child"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
  assert_eq "interrupted" "$(cat "$run/status")" "the status is interrupted, not failed"
  outcome_read "$run/steps/1.outcome"
  assert_eq "interrupted" "$O_KIND" "the handler wrote KIND=interrupted"
  assert_contains "$O_DETAIL" "HUP" "naming the signal"
  kill_recorded_pids "$CASE"
}

run_all_tests
