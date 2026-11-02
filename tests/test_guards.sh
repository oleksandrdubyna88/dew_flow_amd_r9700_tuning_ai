#!/usr/bin/env bash
# The guards of E1.S2 part (c), scenarios G1-G14 of the story, through `bin/r9700 step` and the stub worker. G13 (a hung adapter call is
# killed) is tests/test_lifecycle.sh's init test and tests/test_adapter.sh's ceiling tests; G14 is here. Every test body is a function
# t_<guarantee>; each runs in its own subshell and writes only below $R9700_TEST_ROOT. Faults are triggered AFTER the stub worker wrote
# <run dir>/steps/<n>.ready (amendment A3), never after a fixed time.
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

WORKER="$STUBS/worker.sh"

# short_variant: the short variant of G5. The story's scale 100 (T_END 6 s, T_STOP 2.4 s) leaves a loaded machine no room for the admission's
# dozen stub calls, so the sleeps and deadlines run at scale 25 here: T_END 26.4 s, T_STOP 9.4 s after the start, the cleanup budget 17 s (E2.S2 decision 6: the budget rule is READY_TIMEOUT_S + 365, so 425 and 11 minutes; E1 had 360 and 10).
short_variant() { step_cfg MAX_RUN_MINUTES=11 CLEANUP_BUDGET_S=425 READY_TIMEOUT_S=60; export R9700_TIME_SCALE=25; }

# ---- G14: wait_ready through the serve worker -----------------------------------------------------------------------------------------------------

# serve_worker: the stub worker in mode serve, as the supervisor would start it (its environment), in the background; sets WPID
serve_worker() {
  export R9700_RUN_DIR="$CASE/run" R9700_STEP_N=1 R9700_STEP_LABEL=t R9700_OUTCOME_FILE="$CASE/run/steps/1.outcome"
  mkdir -p "$R9700_RUN_DIR/steps" "$R9700_RUN_DIR/guard"
  disk_gate_baseline "$R9700_RUN_DIR/disk_gate.state" > /dev/null # what the supervisor does at admission
  "$STUBS/worker.sh" serve > "$CASE/worker.out" 2>&1 &
  WPID=$!
  guard_pid "$WPID" "worker-$WPID"
}

t_g14_a_ready_server_makes_serve_start_return_0_and_the_log_is_what_wslc_logs_printed() {
  step_setup "$FUNCNAME"
  printf 'one\ntwo\nthree\n' > "$STUB/answers/logs"
  serve_worker
  wait_for "$CASE/run/steps/1.server.log" 100
  assert_eq "$(cat "$STUB/answers/logs")" "$(cat "$CASE/run/steps/1.server.log")" "the saved server.log equals answers/logs"
  assert_exit 0 "the container r9700tune-t-1 runs" -- test -f "$STUB/containers/r9700tune-t-1.pid"
  assert_contains "$(cat "$CASE/worker.out")" "READY (waited " "serve_start waited until ready"
  kill_recorded_pids "$CASE"
}

t_g14_a_server_that_exits_after_the_first_probe_is_reported_within_three_probes() {
  step_setup "$FUNCNAME"
  printf 'fail\n' > "$STUB/answers/ready"
  ( wait_for "$STUB/counters/answer-ready"; kill -KILL "$(pid_of r9700tune-t-1)" ) &
  guard_pid "$!" killer
  serve_worker
  wait "$WPID"
  assert_eq "1" "$?" "the worker (serve_start) returned 1"
  assert_contains "$(cat "$CASE/run/steps/1.server.log")" "SERVER EXITED" "SERVER EXITED is in the log"
  if [ "$(cat "$STUB/counters/answer-ready")" -le 3 ]; then assert_eq ok ok "within three probes"; else assert_eq "<= 3" "$(cat "$STUB/counters/answer-ready")" "within three probes"; fi
  kill_recorded_pids "$CASE"
}

# ---- G1: a RAM stop leaves no process of the worker group (RESULTS § 13.4, 2026-10-31 21:43) -----------------------------------------------------------

t_g1_a_ram_stop_leaves_no_process_of_the_worker_group() {
  step_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  prod_running
  step_bg --model "$MODEL_35B" t -- "$WORKER" child
  local run worker child
  run="$(run_dir_of)"
  wait_for "$STUB/child.pid" 100
  worker="$(sed 's/ .*//' "$STUB/workers/containers/"worker-*.pid | head -n 1)"
  child="$(cat "$STUB/child.pid")"
  append_answer ram 100 # the worker is up: the next read is low
  step_end
  assert_eq "7" "$SRC" "the supervisor exits 7 after MAX_FAILED_TRIES=1"
  assert_exit 1 "kill -0 \$(cat child.pid) fails: the child $child is dead" -- kill -0 "$child"
  assert_exit 1 "the worker's own pid $worker is dead" -- kill -0 "$worker"
  assert_eq "" "$(session_pids "$worker" | tr -d '\n')" "no process of the worker's session is left"
  outcome_read "$run/steps/1.outcome"
  assert_eq "ram_guard" "$O_KIND" "KIND=ram_guard"
  assert_eq "available 100 MB < 2048 MB" "$O_DETAIL" "DETAIL=available 100 MB < 2048 MB"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "pwsh.exe once"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_contains "$SERR" "r9700: step failed 1 times, last: ram_guard available 100 MB < 2048 MB" "the stderr line"
  kill_recorded_pids "$CASE"
}

t_g1_a_ram_stop_while_the_worker_sits_in_a_hung_adapter_call_leaves_no_process_of_the_session() {
  step_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  prod_running
  step_bg --model "$MODEL_35B" t -- "$WORKER" adapter-hang
  local run worker
  run="$(run_dir_of)"
  wait_for "$run/steps/1.ready" 100
  worker="$(sed 's/ .*//' "$STUB/workers/containers/"worker-*.pid | head -n 1)"
  printf 'hang-ignore-term\n' > "$STUB/mode" # the worker's next adapter call hangs, and its stub ignores TERM
  wait_for "$STUB/hung/containers/1.pid" 100
  wait_for "$STUB/hung/containers/2.pid" 100
  rm -f "$STUB/mode" # the guard's and the cleanup's own calls must work
  assert_exit 0 "a member of the worker's session is in the hung call" -- test "$(session_pids "$worker" | wc -l)" -ge 3
  append_answer ram 100
  step_end
  assert_eq "7" "$SRC" "exit 7"
  assert_eq "" "$(session_pids "$worker" | tr -d '\n')" "no process of the worker's session is left (amendment A8)"
  local f pid dead=0 total=0
  for f in "$STUB"/hung/containers/*.pid; do
    read -r pid _ < "$f"
    total=$((total + 1))
    kill -0 "$pid" 2> /dev/null || dead=$((dead + 1))
  done
  assert_eq "$total" "$dead" "every hung process (the stub, its sleeper that ignore TERM) is dead"
  assert_missing "$MARKER_FILE" "and the restore ran: the marker is gone"
  kill_recorded_pids "$CASE"
}

# ---- G2: a RAM stop stops every prefixed container and saves its log tail first ---------------------------------------------------------------------

t_g2_a_ram_stop_stops_every_prefixed_container_and_saves_its_log_tail_first() {
  step_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  prod_running
  seq 1 300 > "$STUB/answers/logs"
  step_bg --model "$MODEL_35B" t -- "$WORKER" serve
  local run
  run="$(run_dir_of)"
  wait_for "$run/steps/1.server.log" 100 # the container is up and ready
  local cpid
  cpid="$(pid_of r9700tune-t-1)"
  append_answer ram 100
  step_end
  assert_eq "7" "$SRC" "exit 7"
  assert_missing "$STUB/containers/r9700tune-t-1.pid" "the container's pid file is gone"
  assert_exit 1 "and its process is dead" -- kill -0 "$cpid"
  assert_eq "1" "$(ls "$run/guard" | grep -c 'r9700tune-t-1\.tail\.log$')" "guard/ holds one *-r9700tune-t-1.tail.log"
  local tail_file
  tail_file="$(ls "$run"/guard/*r9700tune-t-1.tail.log | head -n 1)"
  assert_eq "200" "$(wc -l < "$tail_file" | tr -d ' ')" "with exactly 200 lines"
  assert_eq "300" "$(tail -n 1 "$tail_file")" "the last is line 300"
  assert_exit 0 "in the call log logs precedes stop" -- awk '$3 == "wslc" && $4 == "logs" && $5 == "r9700tune-t-1" { l = NR } $3 == "wslc" && $4 == "stop" && $5 == "r9700tune-t-1" && !s { s = NR } END { exit !(l && s && l < s) }' "$STUB/calls.log"
  assert_exit 0 "the operator's server is back" -- test -f "$STUB/containers/vllm.pid"
  kill_recorded_pids "$CASE"
}

# ---- G3: unreadable telemetry -------------------------------------------------------------------------------------------------------------------------

t_g3_unreadable_telemetry_is_unsafe_after_three_misses_and_one_miss_is_not() {
  step_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  export R9700_TIME_SCALE=30 # a RAM read every 0.5 s: the worker is up long before the sixth read
  prod_running
  printf '8000\ngarbage\n8000\ngarbage\ngarbage\ngarbage\n' > "$STUB/answers/ram"
  step_bg --model "$MODEL_35B" t -- "$WORKER" child
  local run worker alive_at_first_miss=no hb_age
  run="$(run_dir_of)"
  for _ in $(seq 1 100); do grep -q 'telemetry unreadable (1 of 3)' "$run/steps/1.ram_guard.log" 2> /dev/null && break; sleep 0.05; done
  worker="$(sed 's/ .*//' "$STUB/workers/containers/"worker-*.pid | head -n 1)"
  kill -0 "$worker" 2> /dev/null && alive_at_first_miss=yes
  hb_age="$(awk -v n="$(date +%s.%N)" -v m="$(stat -c %.9Y "$STUB/heartbeat" 2> /dev/null || echo 0)" 'BEGIN { printf "%d", (n - m) < 1 }')"
  assert_eq "yes" "$alive_at_first_miss" "the worker was still alive after the first miss"
  assert_eq "1" "$hb_age" "and its heartbeat was fresh (written within the last second)"
  step_end
  assert_eq "7" "$SRC" "the step is stopped (exit 7 after MAX_FAILED_TRIES=1)"
  outcome_read "$run/steps/1.outcome"
  assert_eq "ram_guard" "$O_KIND" "KIND=ram_guard"
  assert_eq "telemetry unreadable 3 times" "$O_DETAIL" "DETAIL=telemetry unreadable 3 times"
  assert_eq "6" "$(cat "$STUB/counters/answer-ram")" "on the sixth read"
  assert_eq "(1 of 3)
(1 of 3)
(2 of 3)
(3 of 3)" "$(grep -o '([0-9] of 3)' "$run/steps/1.ram_guard.log")" "the guard log counts the misses"
  kill_recorded_pids "$CASE"
}

# ---- G4: the limit itself is fine, one below is not ----------------------------------------------------------------------------------------------------

t_g4_a_reading_exactly_at_the_limit_is_fine_and_one_below_is_not() {
  step_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  prod_running
  printf '2048\n' > "$STUB/answers/ram"
  assert_exit 0 "answers/ram = 2048 forever, worker ok" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  rm -f "$STUB/worker.done" "$STUB/worker.calls"
  printf '2047\n' > "$STUB/answers/ram"
  assert_exit 7 "answers/ram = 2047" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" child
  local run
  run="$(ls -d "$R9700_RESULTS_DIR"/runs/*/ | tail -n 1)"
  outcome_read "${run%/}/steps/1.outcome"
  assert_eq "ram_guard" "$O_KIND" "KIND=ram_guard"
  kill_recorded_pids "$CASE"
}

# ---- G5-G8: the deadline ---------------------------------------------------------------------------------------------------------------------------------

t_g5_the_deadline_stops_the_step_and_keeps_the_cleanup_budget() {
  step_setup "$FUNCNAME"
  short_variant
  prod_running
  local start end worker
  start="$(date +%s.%N)"
  step_bg --model "$MODEL_35B" t -- "$WORKER" child
  wait_for "$STUB/child.pid" 100
  worker="$(sed 's/ .*//' "$STUB/workers/containers/"worker-*.pid | head -n 1)"
  step_end
  end="$(date +%s.%N)"
  assert_eq "6" "$SRC" "exit 6"
  assert_contains "$SERR" "r9700: deadline: step stopped at " "the stderr line"
  assert_exit 1 "the worker is dead" -- kill -0 "$worker"
  assert_eq "" "$(session_pids "$worker" | tr -d '\n')" "and so is everything in its session"
  local run
  run="$(run_dir_of)"
  outcome_read "$run/steps/1.outcome"
  assert_eq "deadline" "$O_KIND" "KIND=deadline"
  # The supervisor's 60 s net also writes KIND=deadline; only the watcher writes this detail.
  assert_contains "$O_DETAIL" "deadline reached" "the deadline watcher fired, not the supervisor's net"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the restore ran (pwsh.exe once)"
  if awk -v a="$start" -v b="$end" 'BEGIN { exit !(b - a < 26.4) }'; then assert_eq ok ok "the whole invocation ended before T_END (26.4 s): $(awk -v a="$start" -v b="$end" 'BEGIN { printf "%.2f s", b - a }')"; else assert_eq "< 24 s" "$(awk -v a="$start" -v b="$end" 'BEGIN { print b - a }')" "ended before T_END"; fi
  kill_recorded_pids "$CASE"
}

t_g6_a_deadline_that_leaves_no_room_is_refused_before_anything_is_stopped() {
  step_setup "$FUNCNAME"
  step_cfg MAX_RUN_MINUTES=10 CLEANUP_BUDGET_S=3600
  prod_running
  assert_exit 2 "MAX_RUN_MINUTES=10 with a 3600 s budget" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  assert_contains "$ERR" "deadline: only -3000 s remain before the cleanup budget" "the stderr line"
  assert_eq "0" "$(stop_lines)" "no stop in the call log"
  assert_exit 0 "the server still runs" -- test -f "$STUB/containers/vllm.pid"
  assert_missing "$MARKER_FILE" "and there is no marker"
}

t_g7_a_clock_time_deadline_is_the_next_occurrence() {
  step_setup "$FUNCNAME"
  export R9700_TIME_SCALE=1
  local now soon past t_end
  now="$(date +%s)"
  soon="$(date -d "@$((now + 120))" +%H:%M)"
  past="$(date -d "@$((now - 120))" +%H:%M)"
  step_cfg "DEADLINE=$soon" MAX_RUN_MINUTES=2880
  assert_exit 0 "step --show-deadline with a clock time two minutes ahead" -- r9700 step --show-deadline --model "$MODEL_35B" t
  assert_contains "$OUT" "START=refused (deadline: only " "it says that this run would be refused (two minutes cannot hold a 1500 s budget)"
  t_end="$(sed -n 's/^T_END=//p' <<< "$OUT")"
  if [ -n "$t_end" ] && [ "$t_end" -gt "$((now + 40))" ] && [ "$t_end" -le "$((now + 125))" ]; then assert_eq ok ok "T_END is within 120 s of now ($((t_end - now)) s)"; else assert_eq "within 120 s" "$((${t_end:-0} - now))" "T_END"; fi
  assert_contains "$OUT" "T_STOP=" "T_STOP is printed too"
  assert_eq "0" "$(stop_lines)" "--show-deadline stops nothing"
  assert_missing "$STUB/calls.log" "and calls nothing"
  assert_missing "$R9700_STATE_DIR/lock" "and takes no lock"
  : > "$CASE/machine.env.tmp"
  sed '/^DEADLINE=/d' "$CASE/machine.env" > "$CASE/machine.env.tmp" && mv "$CASE/machine.env.tmp" "$CASE/machine.env"
  step_cfg "DEADLINE=$past"
  assert_exit 0 "a clock time two minutes ago" -- r9700 step --show-deadline --model "$MODEL_35B" t
  t_end="$(sed -n 's/^T_END=//p' <<< "$OUT")"
  if [ -n "$t_end" ] && [ "$t_end" -gt "$((now + 80000))" ] && [ "$t_end" -le "$((now + 86400 - 60))" ]; then assert_eq ok ok "T_END is tomorrow's (within 24 h - 120 s, give or take the minute)"; else assert_eq "about 86280" "$((${t_end:-0} - now))" "T_END is tomorrow's"; fi
}

t_g8_the_quiet_wait_is_bounded_by_the_deadline_not_by_its_own_loop() {
  step_setup "$FUNCNAME"
  short_variant
  prod_running
  set_load 9.0
  local start end
  start="$(date +%s.%N)"
  assert_exit 8 "a busy PC and the short variant" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  end="$(date +%s.%N)"
  if awk -v a="$start" -v b="$end" 'BEGIN { exit !(b - a < 11.5) }'; then assert_eq ok ok "exit 8 within T_STOP (9.4 s) and a margin, before an uncut 12 s tick would end ($(awk -v a="$start" -v b="$end" 'BEGIN { printf "%.2f", b - a }') s)"; else assert_eq "< 11.5 s" "$(awk -v a="$start" -v b="$end" 'BEGIN { print b - a }')" "the quiet wait ended at T_STOP"; fi
  assert_eq "r9700: not quiet before the deadline" "$ERR" "the stderr line"
  assert_eq "0" "$(stop_lines)" "no stop vllm: never admitted"
  assert_eq "0" "$(log_count pwsh.exe -Detach)" "pwsh.exe never called: the server was never stopped"
  assert_eq "not-quiet" "$(cat "$(run_dir_of)/status")" "the status is not-quiet"
}

# ---- G9-G11: the quiet check ------------------------------------------------------------------------------------------------------------------------

t_g9_the_quiet_check_needs_the_asked_number_of_quiet_reads_in_a_row() {
  step_setup "$FUNCNAME"
  export R9700_TIME_SCALE=150 R9700_QUIET_CHECKS=3 # a tick is 2 s: the helper that feeds the loads has time under load
  prod_running
  set_load 0.5
  step_bg --model "$MODEL_35B" t -- "$WORKER" ok
  local run
  run="$(run_dir_of)"
  local values=(0.5 9.0 0.5 0.5 0.5) v n=0
  for v in "${values[@]}"; do
    for _ in $(seq 1 300); do [ "$(grep -c 'quiet-checks=' "$run/supervisor.log" 2> /dev/null || echo 0)" -ge "$((n + 1))" ] && break; sleep 0.02; done
    n=$((n + 1))
    set_load "$v"
  done
  step_end
  assert_eq "0" "$SRC" "exit 0"
  assert_eq "quiet-checks=1/3 quiet-checks=2/3 quiet-checks=0/3 quiet-checks=1/3 quiet-checks=2/3 quiet-checks=3/3" "$(grep -o 'quiet-checks=[0-9]/3' "$run/supervisor.log" | tr '\n' ' ' | sed 's/ $//')" "the supervisor log shows 2/3, then 0/3, then 3/3"
  assert_eq "6" "$(awk '/ admitted$/ { exit } /quiet-checks=/ { n++ } END { print n }' "$run/supervisor.log")" "admission came after the sixth read, not the third"
  kill_recorded_pids "$CASE"
}

t_g10_a_busy_process_blocks_admission() {
  step_setup "$FUNCNAME"
  short_variant
  step_cfg QUIET_BUSY_PATTERN=r9700-busy-marker QUIET_BUSY_IGNORE=keep-awake
  prod_running
  ( exec -a r9700-busy-marker sleep 1000 ) < /dev/null > /dev/null 2>&1 &
  local busy=$!
  guard_pid "$busy" "busy-$busy"
  assert_exit 8 "a process named r9700-busy-marker" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  assert_eq "r9700: not quiet before the deadline" "$ERR" "exit 8 at T_STOP"
  assert_contains "$(cat "$(run_dir_of)/supervisor.log")" "processes=1" "the supervisor log counts the process"
  assert_eq "0" "$(stop_lines)" "nothing stopped"
  kill -KILL "$busy"
  kill_recorded_pids "$CASE"
}

t_g10_the_ignore_pattern_excludes_a_busy_process() {
  step_setup "$FUNCNAME"
  step_cfg QUIET_BUSY_PATTERN=r9700-busy-marker QUIET_BUSY_IGNORE=keep-awake
  prod_running
  ( exec -a "r9700-busy-marker keep-awake" sleep 1000 ) < /dev/null > /dev/null 2>&1 &
  local busy=$!
  guard_pid "$busy" "busy-$busy"
  assert_exit 0 "the same name with keep-awake in its command line" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  assert_contains "$OUT" "processes=0" "it is not counted"
  kill -KILL "$busy"
  kill_recorded_pids "$CASE"
}

t_g11_an_unreadable_load_is_not_quiet() {
  step_setup "$FUNCNAME"
  short_variant
  prod_running
  export R9700_LOADAVG_FILE="$CASE/no-such-file"
  assert_exit 8 "a load file that is missing" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  assert_contains "$(cat "$(run_dir_of)/supervisor.log")" "load unreadable: not quiet" "the supervisor log says so"
  assert_eq "0" "$(stop_lines)" "no stop vllm"
}

# ---- G12: the disk gate -----------------------------------------------------------------------------------------------------------------------------------

t_g12_the_disk_gate_stops_the_run_on_a_new_event_or_a_failed_query_and_passes_on_none() {
  step_setup "$FUNCNAME"
  prod_running
  printf '100\n101\n' > "$STUB/answers/disk"
  assert_exit 9 "a new record after the baseline" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" serve
  assert_eq "r9700: disk gate: STOP: new disk event (record 101 > baseline 100)" "$ERR" "the stderr line"
  local run
  run="$(ls -d "$R9700_RESULTS_DIR"/runs/*/ | tail -n 1)"
  run="${run%/}"
  outcome_read "$run/steps/1.outcome"
  assert_eq "disk_gate" "$O_KIND" "KIND=disk_gate"
  assert_eq "disk-gate" "$(cat "$run/status")" "the status is disk-gate"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the server was restored"
  rm -rf "$STUB/counters/answer-disk" "$STUB/worker.calls"
  printf '100\n\n' > "$STUB/answers/disk"
  assert_exit 9 "a failed query" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" serve
  assert_eq "r9700: disk gate: STOP: query failed" "$ERR" "the stderr line"
  rm -rf "$STUB/counters/answer-disk" "$STUB/worker.calls"
  printf '100\n100\n' > "$STUB/answers/disk"
  R9700_STUB_SERVE_HOLD=0.3 assert_exit 0 "no new event" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" serve
  kill_recorded_pids "$CASE"
}

t_g12_with_the_gate_off_no_disk_query_is_made() {
  step_setup "$FUNCNAME"
  step_cfg DISK_GATE=off
  prod_running
  R9700_STUB_SERVE_HOLD=0.3 assert_exit 0 "DISK_GATE=off" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" serve
  assert_eq "0" "$(grep -c 'Get-WinEvent' "$STUB/calls.log")" "no Get-WinEvent in the call log"
  kill_recorded_pids "$CASE"
}

t_a_baseline_that_cannot_be_read_stops_the_run_before_the_server_is_stopped() {
  step_setup "$FUNCNAME"
  prod_running
  printf 'garbage\n' > "$STUB/answers/disk"
  assert_exit 9 "an unreadable baseline" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  assert_eq "r9700: disk gate: STOP: query failed" "$ERR" "the stderr line"
  assert_eq "0" "$(stop_lines)" "no server was stopped"
  assert_missing "$STUB/worker.calls" "and no worker ran"
}

t_a_deadline_watcher_that_is_gone_does_not_leave_the_worker_running_past_the_deadline() {
  step_setup "$FUNCNAME"
  short_variant # T_STOP 9.4 s after the start; the supervisor's own net acts a minute (2.4 s at scale 25) later
  prod_running
  local start end worker pid
  start="$(date +%s.%N)"
  step_bg --model "$MODEL_35B" t -- "$WORKER" child
  wait_for "$STUB/child.pid" 100
  worker="$(sed 's/ .*//' "$STUB/workers/containers/"worker-*.pid | head -n 1)"
  for pid in $(pgrep -P "$SUP"); do [ "$pid" = "$worker" ] || kill -KILL "$pid" 2> /dev/null; done # the RAM guard and the deadline watcher
  step_end
  end="$(date +%s.%N)"
  assert_eq "6" "$SRC" "exit 6: the deadline stopped the step all the same"
  assert_exit 1 "the worker is dead" -- kill -0 "$worker"
  assert_eq "" "$(session_pids "$worker" | tr -d '\n')" "and its session"
  outcome_read "$(run_dir_of)/steps/1.outcome"
  assert_eq "deadline" "$O_KIND" "KIND=deadline"
  assert_contains "$O_DETAIL" "did not stop the worker" "the detail says the watcher was not the one"
  if awk -v a="$start" -v b="$end" 'BEGIN { exit !(b - a < 26.4) }'; then assert_eq ok ok "the call ended before T_END ($(awk -v a="$start" -v b="$end" 'BEGIN { printf "%.2f s", b - a }'))"; else assert_eq "< 24 s" "$(awk -v a="$start" -v b="$end" 'BEGIN { print b - a }')" "ended before T_END"; fi
  kill_recorded_pids "$CASE"
}

t_a_guard_that_sits_in_a_hung_adapter_call_does_not_hold_the_supervisor_after_the_worker_ended() {
  step_setup "$FUNCNAME"
  prod_running
  export R9700_CEILING_SCALE=1 # the guard's hung read has its real ceiling (30 s): only a kill of the guard can end it before the test does
  R9700_STUB_OK_HOLD=2 step_bg --model "$MODEL_35B" t -- "$WORKER" ok
  local run hung start end
  run="$(run_dir_of)"
  wait_for "$run/steps/1.ready" 100
  printf 'hang\n' > "$STUB/mode" # the RAM guard's next read hangs (its call ceiling is 30 s)
  wait_for "$STUB/hung/containers/1.pid" 100
  rm -f "$STUB/mode"
  read -r hung _ < "$STUB/hung/containers/1.pid"
  wait_for "$STUB/worker.done" 100
  start="$(date +%s.%N)"
  step_end
  end="$(date +%s.%N)"
  assert_eq "0" "$SRC" "the step is done"
  if awk -v a="$start" -v b="$end" 'BEGIN { exit !(b - a < 2) }'; then assert_eq ok ok "the supervisor ended within two seconds of the worker, not at the guard's 30 s ceiling ($(awk -v a="$start" -v b="$end" 'BEGIN { printf "%.2f s", b - a }'))"; else assert_eq "< 2 s" "$(awk -v a="$start" -v b="$end" 'BEGIN { print b - a }')" "the supervisor waited for the guard's call"; fi
  assert_exit 0 "the hung call of the guard is dead (its process group was killed)" -- gone "$hung"
  kill_recorded_pids "$CASE"
}

# A guard that is killed while it stops the SECOND container: the worker follows its first container and ends at once, the supervisor
# kills the guard, and the second container would be left running into the retry. The supervisor stops the containers again after a guard
# or the deadline stopped the step.
t_a_guard_killed_while_it_stops_the_second_container_leaves_no_container_to_the_retry() {
  step_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=2
  prod_running
  printf '1\n' > "$STUB/stop-delay-r9700tune-b-1" # stopping b-1 takes a second: the guard is inside that stop when the worker ends
  step_bg --model "$MODEL_35B" t -- "$WORKER" container-bound
  local run
  run="$(run_dir_of)"
  wait_for "$STUB/containers/r9700tune-b-1.pid" 100
  append_answer ram 100
  wait_for "$run/steps/1.outcome" 100
  printf '8000\n' > "$STUB/answers/ram" # the retry is not stopped by the RAM guard
  wait_for "$STUB/containers/r9700tune-a-2.pid" 200 # the worker writes running.2 completely BEFORE it starts a-2
  assert_exit 0 "the retry's worker started and wrote its list" -- test -f "$STUB/running.2"
  assert_eq "0" "$(grep -c 'r9700tune-b-1' "$STUB/running.2")" "when the retry's worker starts, the container b-1 of the first try is not listed"
  assert_eq "0" "$(grep -c 'r9700tune-a-1' "$STUB/running.2")" "nor a-1"
  wslc stop r9700tune-a-2 > /dev/null # the second worker follows this container and ends
  step_end
  assert_eq "7" "$SRC" "exit 7 after two tries"
  outcome_read "$run/steps/1.outcome"
  assert_eq "ram_guard" "$O_KIND" "the first try was stopped by the RAM guard"
  assert_missing "$STUB/containers/r9700tune-b-1.pid" "b-1 is stopped"
  kill_recorded_pids "$CASE"
}

run_all_tests
