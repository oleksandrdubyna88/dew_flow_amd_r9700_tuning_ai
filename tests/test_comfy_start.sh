#!/usr/bin/env bash
# `bin/r9700 comfy start` (E1.S2, scenarios CS1-CS18): the grammar, the lock held through the readiness wait, the operator's server beside it, the volumes, the stopped container,
# the failed start that reconciles against the container list (never against what the launch call returned), the signals. The other modes and the owner check are tests/test_comfy.sh.
# Every test body is a function t_<guarantee>; each runs in its own subshell and writes only below $R9700_TEST_ROOT. Waits are bounded polls on a call-log line or a file.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"
# shellcheck source=tests/lib/lifecycle.sh
source "$HERE/lib/lifecycle.sh"
# shellcheck source=tests/lib/comfycase.sh
source "$HERE/lib/comfycase.sh"

WORKER="$STUBS/worker.sh"
RUN_RE=' wslc run -d --rm --name comfyui '
CS4_LINE="r9700: comfy: start: the operator's server vllm is listed and holds the card; pass --stop-vllm, or stop it by hand"

# slow_ready: a readiness that fails thirty times before it says ok, and a window that outlasts them (the cleanup budget must cover the window: lib/config.sh)
slow_ready() {
  step_cfg READY_TIMEOUT_S=3235 CLEANUP_BUDGET_S=3600
  { for _ in $(seq 1 30); do echo fail; done; echo ok; } > "$STUB/answers/comfy_ready"
}

# logs_250: 250 lines of a container's log, each numbered
logs_250() { seq 1 250 | sed 's/^/log line /' > "$STUB/answers/logs"; }

# tail_files: the tail files of failed starts below the state directory
tail_files() { ls "$R9700_STATE_DIR"/comfy-start-*.tail.log 2> /dev/null; }

# the legal modes: the functions of lib/comfy.sh and of lib/comfy_bench_verb.sh (the mode `bench`, E2.S3), read from the files
file_modes() { grep -hoE '^comfy_mode_[a-z]+\(\)' "$REPO/lib/comfy.sh" "$REPO/lib/comfy_bench_verb.sh" | sed -e 's/^comfy_mode_//' -e 's/()$//' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//'; }

# CS1
t_the_grammar_is_refused_before_the_lock_and_the_modes_are_derived() {
  comfy_setup "$FUNCNAME"
  local modes args
  modes="$(comfy_modes | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "$(file_modes)" "$modes" "the legal modes are the comfy_mode_* functions of lib/comfy.sh and lib/comfy_bench_verb.sh"
  assert_contains " $modes " " start " "and hold start"
  assert_exit 2 "no mode" -- comfy
  assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "one line"
  assert_exit 2 "comfy nosuch" -- comfy nosuch
  assert_eq "r9700: comfy: unknown mode \"nosuch\"; legal: $modes" "$ERR" "the mode line, the legal list derived"
  for args in "start --frob" "start extra" "stop extra" "status --x"; do
    assert_exit 2 "comfy $args" -- comfy $args
    assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "[$args] one line"
  done
  assert_missing "$R9700_STATE_DIR/lock" "no lock file"
  assert_missing "$STUB/calls.log" "no call"
  assert_exit 0 "comfy start -- --reserve-vram 2 is legal" -- comfy start -- --reserve-vram 2
  comfy_run_argv
  assert_eq "--shm-size|8g|comfyui-r9700:local|--reserve-vram|2" "$(IFS='|'; echo "${ARGV[*]: -5}")" "the words after -- are ComfyUI's, after the image"
  kill_recorded_pids "$CASE"
}

# CS2
t_a_start_holds_the_lock_through_the_readiness_wait_runs_the_hand_made_argv_and_prints_the_device() {
  comfy_setup "$FUNCNAME"
  assert_exit 0 "comfy start" -- comfy start
  comfy_run_argv
  assert_eq "run|-d|--rm|--name|comfyui|--gpus|all|-p|8188:8188|-v|comfy-models:/models|-v|comfy-data:/data|-v|comfy-cache:/cache|--shm-size|8g|comfyui-r9700:local" "$(IFS='|'; echo "${ARGV[*]}")" "the run argv"
  _argv_of_call exec comfyui
  assert_eq "exec|comfyui|python3|-c" "$(IFS='|'; echo "${ARGV[*]:0:4}")" "one exec of the probe"
  assert_contains "${ARGV[4]}" "/system_stats" "whose program names the route"
  assert_eq 1 "$(log_count wslc exec)" "and only one"
  [[ $OUT =~ comfy:\ start:\ comfyui\ ready\ after\ [0-9]+\ s ]] && assert_eq ok ok "comfy: start: comfyui ready after <n> s" || assert_eq "comfy: start: comfyui ready after <n> s" "$OUT" "the ready line"
  assert_contains "$OUT" "comfy: start: device cuda:0 AMD Radeon AI PRO R9700 : native" "the device line"
  assert_contains "$OUT" "comfy: start: open http://127.0.0.1:8188" "and the address"
  assert_exit 0 "the lock is free" -- lock_free
  assert_missing "$MARKER_FILE" "no marker"
  assert_eq 0 "$(log_count pwsh.exe -Detach)" "no start of the server"
  assert_exit 0 "comfyui is listed" -- alive comfyui
  assert_eq 0 "$(log_count wslc create)" "no volume create: all present"
  assert_eq 0 "$(stop_lines)" "no stop"
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-out"
  step_cfg 'COMFY_OUTPUT_WIN=X:\comfy-out'
  assert_exit 0 "with COMFY_OUTPUT_WIN" -- comfy start
  comfy_run_argv
  assert_eq '-v|comfy-cache:/cache|-v|X:\comfy-out:/data/output|--shm-size' "$(IFS='|'; echo "${ARGV[*]:13:5}")" "the output mount comes right after the cache volume"
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-port"
  step_cfg COMFY_PORT=8288
  assert_exit 0 "with COMFY_PORT" -- comfy start
  comfy_run_argv
  assert_contains "$(IFS='|'; echo "${ARGV[*]}")" "|-p|8288:8188|" "the port is published"
  assert_contains "$OUT" "comfy: start: open http://127.0.0.1:8288" "and the address names it"
  kill_recorded_pids "$CASE"
  step_setup "$FUNCNAME-lock"
  mkdir -p "$STUB/volumes"
  slow_ready
  printf 'ok\n' > "$STUB/answers/ready"
  comfy_bg start
  wait_call ' wslc exec comfyui ' 100
  assert_exit 4 "a step while the start waits for readiness" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  assert_contains "$ERR" "pid $SUP, comfy, since" "the holder line names comfy"
  comfy_end 30
  assert_eq 0 "$SRC" "the start itself ends 0"
  kill_recorded_pids "$CASE"
}

# CS3
t_a_start_is_refused_under_a_held_lock() {
  step_setup "$FUNCNAME"
  step_bg --model "$MODEL_35B" t -- "$WORKER" child
  wait_for "$STUB/child.pid" 100
  local step_pid="$SUP" calls
  calls="$(wslc_calls)"
  assert_exit 4 "comfy start under a held lock" -- comfy start
  assert_contains "$ERR" "pid $step_pid, step, since" "the holder line"
  assert_eq "$calls" "$(wslc_calls)" "no engine call was made by the start (the held step's guards log pwsh calls, not engine calls)"
  assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "one line"
  kill -TERM "$step_pid"
  SUP="$step_pid"
  step_end
  kill_recorded_pids "$CASE"
}

# CS4
t_beside_the_operators_server_a_start_is_refused_unless_stop_vllm_which_stops_it_once_marker_first() {
  comfy_setup "$FUNCNAME"
  prod_running
  assert_exit 2 "comfy start beside the server" -- comfy start
  assert_eq "$CS4_LINE" "$ERR" "one stderr line"
  assert_eq 0 "$(stop_lines)" "no stop"
  assert_eq 1 "$(log_count wslc run)" "no run (the one is the test's own)"
  assert_missing "$MARKER_FILE" "no marker"
  printf '%s\n' '#!/usr/bin/env bash' "cp '$MARKER_FILE' '$CASE/marker.at-stop'" > "$STUB/on-stop-vllm"
  assert_exit 0 "comfy start --stop-vllm" -- comfy start --stop-vllm
  assert_eq 1 "$(grep -c ' wslc stop vllm$' "$STUB/calls.log")" "exactly one stop of vllm"
  assert_contains "$OUT" "comfy: start: stopped the operator's server vllm" "logged"
  assert_contains "$OUT" "comfy: start: vllm stays down; start it by hand when ComfyUI is done" "and says what is left"
  assert_exit 0 "the marker was there at the moment of the stop" -- test -f "$CASE/marker.at-stop"
  marker_read "$CASE/marker.at-stop"
  assert_eq yes "${MARKER[PROD_WAS_RUNNING]}" "PROD_WAS_RUNNING=yes"
  assert_contains "${MARKER[RUN_ID]}" "comfy-" "RUN_ID starts with comfy-"
  assert_eq "comfyui" "${MARKER[COMFY_CONTAINER]:-}" "COMFY_CONTAINER=comfyui"
  assert_eq "$R9700_STATE_DIR/restore-${MARKER[RUN_ID]}" "${MARKER[RUN_DIR]}" "RUN_DIR is the restore folder of the run id"
  assert_missing "$MARKER_FILE" "at the end no marker"
  assert_exit 1 "vllm is not listed" -- alive vllm
  assert_exit 0 "comfyui is listed" -- alive comfyui
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-gone"
  prod_running
  printf '1\n' > "$STUB/stop-gone-vllm"
  assert_exit 0 "a stop that returns 1 while the server is gone" -- comfy start --stop-vllm
  assert_contains "$OUT" "comfy: start: the stop returned 1 but vllm is gone: counted as stopped" "is counted as stopped"
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-fail"
  prod_running
  printf '1\n' > "$STUB/stop-fail-vllm"
  assert_exit 1 "a stop that fails and leaves it listed" -- comfy start --stop-vllm
  assert_eq "r9700: comfy: start: stopping the operator's server vllm failed (code 1): stub: stop failed (scripted): vllm" "$ERR" "one line with the engine's text"
  assert_eq 1 "$(log_count wslc run)" "no run"
  assert_missing "$MARKER_FILE" "no marker left: the server is up and nothing is owed"
  assert_exit 0 "vllm is still listed" -- alive vllm
  kill_recorded_pids "$CASE"
}

# CS5
t_a_start_finds_comfyui_already_running_and_does_nothing() {
  comfy_setup "$FUNCNAME"
  comfy_listed
  assert_exit 0 "comfy start" -- comfy start
  assert_eq "comfy: start: comfyui is already running, nothing to do" "$OUT" "stdout"
  assert_exit 0 "with arguments after --" -- comfy start -- --x
  assert_eq "comfy: start: comfyui is already running, nothing to do (the arguments after -- were not applied)" "$OUT" "the line says they were not applied"
  assert_eq 1 "$(log_count wslc run)" "no run (the one is the test's own)"
  assert_eq 0 "$(log_count wslc remove)" "no remove"
  assert_eq 0 "$(stop_lines)" "no stop"
  kill_recorded_pids "$CASE"
}

# CS6
t_missing_volumes_are_created_by_list_then_create_and_only_the_missing_ones() {
  comfy_setup "$FUNCNAME"
  rm -f "$STUB/volumes"/*
  assert_exit 0 "comfy start with no volume" -- comfy start
  assert_eq 3 "$(log_count wslc create)" "three creates"
  call_order ' wslc volume create comfy-models$' ' wslc volume create comfy-data$' ' wslc volume create comfy-cache$' "$RUN_RE" && assert_eq ok ok "in that order, every one before the run" || assert_eq "models < data < cache < run" "$(cat "$STUB/calls.log")" "the order"
  local volume
  for volume in comfy-models comfy-data comfy-cache; do assert_contains "$OUT" "comfy: start: created volume $volume" "stdout names $volume"; done
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-one"
  rm -f "$STUB/volumes"/*
  : > "$STUB/volumes/comfy-data"
  assert_exit 0 "only comfy-data present" -- comfy start
  assert_eq 2 "$(log_count wslc create)" "two creates"
  assert_eq 0 "$(grep -c ' wslc volume create comfy-data$' "$STUB/calls.log")" "not that one"
  kill_recorded_pids "$CASE"
  local variant
  for variant in list create; do
    comfy_setup "$FUNCNAME-$variant"
    prod_running
    if [ "$variant" = list ]; then printf '3\n' > "$STUB/fail-volume-list"; else rm -f "$STUB/volumes"/*; printf '1\n' > "$STUB/answers/volume_create_rc"; fi
    assert_exit 1 "[$variant] a failing volume step" -- comfy start --stop-vllm
    if [ "$variant" = list ]; then assert_contains "$ERR" "the volume list failed (code 1)" "[$variant] the line names the volume list"
    else assert_contains "$ERR" "volume create comfy-models failed (code 1)" "[$variant] the line names the volume and the code"; fi
    assert_eq 0 "$(grep -c "$RUN_RE" "$STUB/calls.log")" "[$variant] no run"
    assert_eq 1 "$(log_count pwsh.exe -Detach)" "[$variant] the restore ran afterwards"
    assert_exit 0 "[$variant] vllm is listed" -- alive vllm
    assert_missing "$MARKER_FILE" "[$variant] no marker"
    kill_recorded_pids "$CASE"
  done
}

# CS7
t_a_stopped_container_of_the_name_is_removed_before_the_run() {
  comfy_setup "$FUNCNAME"
  mkdir -p "$STUB/stopped"
  : > "$STUB/stopped/comfyui"
  assert_exit 0 "comfy start beside a stopped container of the name" -- comfy start
  call_order ' wslc remove comfyui$' "$RUN_RE" && assert_eq ok ok "the remove precedes the run" || assert_eq "remove < run" "$(cat "$STUB/calls.log")" "the order"
  assert_contains "$OUT" "comfy: start: removed the stopped container comfyui" "stdout says so"
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-none"
  assert_exit 0 "without a stopped container" -- comfy start
  assert_eq 1 "$(grep -c ' wslc remove comfyui$' "$STUB/calls.log")" "the remove is still called before the run"
  assert_not_contains "$OUT" "removed the stopped" "and its failure prints nothing"
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-rc"
  mkdir -p "$STUB/stopped"
  : > "$STUB/stopped/comfyui"
  printf '1\n' > "$STUB/answers/remove_rc"
  assert_exit 1 "a remove that fails beside a stopped container" -- comfy start
  assert_eq "r9700: comfy: start: the run of comfyui failed (code 1): stub: container name in use (a stopped container): comfyui" "$ERR" "one stderr line"
  assert_eq 0 "$(grep -c ' wslc stop comfyui$' "$STUB/calls.log")" "no stop: a stopped record is not a listed container"
  assert_contains "$OUT" "comfy: start: comfyui is not listed after the failed start; nothing to stop" "stdout says so"
  assert_exit 0 "the lock is free" -- lock_free
}

# CS8
t_a_start_that_does_not_become_ready_saves_the_tail_stops_the_container_restores_and_exits_5() {
  comfy_setup "$FUNCNAME"
  step_cfg READY_TIMEOUT_S=60
  printf 'fail\n' > "$STUB/answers/comfy_ready"
  logs_250
  assert_exit 5 "a readiness that fails" -- comfy start
  local out="$OUT" err="$ERR" file
  assert_eq 1 "$(printf '%s\n' "$err" | wc -l | tr -d ' ')" "one stderr line"
  file="$(tail_files)"
  [[ $err == "r9700: comfy: start: comfyui not ready after "*" s ("*"); its last 200 log lines are in $file" ]] && assert_eq ok ok "the line names the not-ready reason and the saved log" || assert_eq "<line naming $file>" "$err" "the line"
  [[ $file =~ /comfy-start-[0-9]{8}T[0-9]{6}Z-[0-9]+\.tail\.log$ ]] && assert_eq ok ok "<state dir>/comfy-start-<stamp>-<pid>.tail.log" || assert_eq "<state dir>/comfy-start-<stamp>-<pid>.tail.log" "$file" "the file name"
  assert_eq 200 "$(wc -l < "$file" | tr -d ' ')" "200 lines"
  assert_eq "log line 250" "$(tail -n 1 "$file")" "ending with line 250"
  call_order ' wslc logs comfyui$' ' wslc stop comfyui$' && assert_eq ok ok "logs < stop" || assert_eq "logs < stop" "$(cat "$STUB/calls.log")" "the order"
  assert_eq "yes" "$([ "$(grep -n ' wslc list' "$STUB/calls.log" | tail -n 1 | cut -d: -f1)" -gt "$(grep -n ' wslc stop comfyui$' "$STUB/calls.log" | cut -d: -f1)" ] && echo yes || echo no)" "the last list comes after the stop"
  assert_exit 1 "comfyui is not alive" -- alive comfyui
  assert_exit 0 "the lock is free" -- lock_free
  assert_contains "$out" "saved the last 200 log lines" "stdout says it saved the tail"
  assert_contains "$out" "stopped comfyui" "and that it stopped"
  assert_eq 0 "$(log_count pwsh.exe -Detach)" "no start of the server: it was not ours to restore"
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-vllm"
  step_cfg READY_TIMEOUT_S=60
  printf 'fail\n' > "$STUB/answers/comfy_ready"
  prod_running
  logs_250
  assert_exit 5 "the same with --stop-vllm" -- comfy start --stop-vllm
  call_order ' wslc stop vllm$' ' wslc stop comfyui$' ' pwsh.exe ' && assert_eq ok ok "the server is restored AFTER the stop of comfyui" || assert_eq "stop vllm < stop comfyui < pwsh" "$(cat "$STUB/calls.log")" "the order"
  assert_eq 1 "$(log_count pwsh.exe -Detach)" "one start"
  assert_exit 0 "vllm is listed again" -- alive vllm
  assert_missing "$MARKER_FILE" "no marker"
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-both"
  step_cfg READY_TIMEOUT_S=60
  printf 'fail\n' > "$STUB/answers/comfy_ready"
  printf 'fail\n' > "$STUB/answers/ready"
  prod_running
  logs_250
  assert_exit 5 "vLLM's own restore fails too" -- comfy start --stop-vllm
  assert_contains "$ERR" "vllm not ready after" "the restore's line is there too"
  assert_exit 0 "the marker stays" -- test -f "$MARKER_FILE"
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-prune"
  step_cfg READY_TIMEOUT_S=60
  printf 'fail\n' > "$STUB/answers/comfy_ready"
  logs_250
  local n
  for n in $(seq 1 11); do
    printf 'planted %s\n' "$n" > "$R9700_STATE_DIR/$(printf 'comfy-start-20261101T0000%02dZ-1.tail.log' "$n")"
    touch -d "2026-11-01 00:00:$(printf '%02d' "$n")" "$R9700_STATE_DIR/$(printf 'comfy-start-20261101T0000%02dZ-1.tail.log' "$n")"
  done
  mkdir "$R9700_STATE_DIR/comfy-start-notours"
  : > "$R9700_STATE_DIR/other.tail.log"
  assert_exit 5 "a start with eleven tail files planted" -- comfy start
  assert_eq 10 "$(tail_files | wc -l | tr -d ' ')" "only ten comfy-start-*.tail.log exist"
  assert_missing "$R9700_STATE_DIR/comfy-start-20261101T000001Z-1.tail.log" "the oldest is gone"
  assert_exit 0 "a folder of a similar name is untouched" -- test -d "$R9700_STATE_DIR/comfy-start-notours"
  assert_exit 0 "and so is another tail file" -- test -f "$R9700_STATE_DIR/other.tail.log"
  kill_recorded_pids "$CASE"
}

# CS9
t_a_container_that_exits_during_the_wait_is_reported_at_once_not_at_the_window() {
  comfy_setup "$FUNCNAME"
  step_cfg READY_TIMEOUT_S=3235 CLEANUP_BUDGET_S=3600
  printf 'fail\n' > "$STUB/answers/comfy_ready"
  comfy_bg start
  wait_call ' wslc exec comfyui ' 100
  kill -KILL "$(pid_of comfyui)"
  comfy_end 10
  assert_eq 5 "$SRC" "exit 5 within those seconds"
  assert_contains "$SERR" "comfyui not listed 3 times in a row" "the reason"
  assert_eq 1 "$(tail_files | wc -l | tr -d ' ')" "the tail file exists (empty: the engine has no log of a gone container)"
  assert_contains "$SERR" "$(tail_files)" "and the line names it"
  kill_recorded_pids "$CASE"
}

# CS10
t_a_probe_that_hangs_is_cut_by_the_window_and_leaves_no_process() {
  comfy_setup "$FUNCNAME"
  step_cfg READY_TIMEOUT_S=60
  export R9700_CEILING_SCALE=10 # a probe may take 2 s, a list 6 s: the window must cut them
  printf 'hang\n' > "$STUB/answers/comfy_ready"
  local started ended pidfile pid
  started="$(date +%s.%N)"
  assert_exit 5 "a probe that never answers" -- comfy start
  ended="$(date +%s.%N)"
  local err="$ERR"
  assert_exit 0 "within a few seconds" -- awk -v a="$started" -v b="$ended" 'BEGIN { exit !(b - a < 12) }'
  if [[ $err == *"the probe timed out"* || $err == *"the readiness window ended"* ]]; then assert_eq ok ok "the reason names the timeout or the window"; else assert_eq "the probe timed out | the readiness window ended" "$err" "the reason"; fi
  for pidfile in "$STUB"/hung/containers/*.pid; do
    [ -e "$pidfile" ] || continue
    read -r pid _ < "$pidfile"
    assert_exit 0 "the hung process $pid is gone" -- gone "$pid"
  done
  assert_exit 0 "at least one hung process was recorded (the scan is alive)" -- test -e "$STUB/hung/containers/1.pid"
  kill_recorded_pids "$CASE"
}

# CS11
t_a_signal_during_a_start_runs_the_same_failure_path() {
  comfy_setup "$FUNCNAME"
  prod_running
  slow_ready
  comfy_bg start --stop-vllm
  wait_call ' wslc exec comfyui ' 100
  kill -TERM "$SUP"
  comfy_end 30
  assert_eq 143 "$SRC" "exit 143"
  assert_contains "$SERR" "r9700: comfy: start: interrupted by TERM" "the line"
  assert_exit 1 "comfyui is not alive" -- alive comfyui
  assert_eq 1 "$(log_count pwsh.exe -Detach)" "one start of the server"
  assert_exit 0 "vllm is listed" -- alive vllm
  assert_missing "$MARKER_FILE" "no marker"
  assert_exit 0 "the lock is free" -- lock_free
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-int"
  slow_ready
  comfy_bg start
  wait_call ' wslc exec comfyui ' 100
  kill -INT "$SUP"
  comfy_end 30
  assert_eq 130 "$SRC" "INT ends 130"
  assert_exit 1 "comfyui is not alive" -- alive comfyui
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-stop"
  prod_running
  printf '3\n' > "$STUB/stop-delay-vllm"
  comfy_bg start --stop-vllm
  wait_call ' wslc stop vllm$' 100
  kill -TERM "$SUP"
  comfy_end 30
  assert_eq 143 "$SRC" "a TERM during the stop of the server: exit 143"
  assert_eq 0 "$(grep -c "$RUN_RE" "$STUB/calls.log")" "no run of comfyui"
  assert_missing "$MARKER_FILE" "the restore ran: no marker"
  assert_exit 0 "and the server is listed" -- alive vllm
  kill_recorded_pids "$CASE"
}

# CS12
t_a_bad_comfy_container_is_refused_at_config_load_before_any_call() {
  comfy_setup "$FUNCNAME"
  step_cfg COMFY_CONTAINER=r9700tune-comfy
  local mode
  for mode in start stop status; do
    assert_exit 2 "comfy $mode" -- comfy "$mode"
    assert_contains "$ERR" "COMFY_CONTAINER: \"r9700tune-comfy\" starts with the container prefix" "[$mode] the name rule's line"
    assert_missing "$STUB/calls.log" "[$mode] no call at all"
  done
}

# CS13
t_a_start_needs_no_model_file() {
  comfy_setup "$FUNCNAME"
  assert_exit 0 "the scan is alive: two model files" -- test "$(ls "$REPO"/models/*.env | wc -l | tr -d ' ')" -ge 2
  assert_exit 0 "comfy start with no --model" -- comfy start
  kill_recorded_pids "$CASE"
}

# CS14
t_a_start_after_a_hard_killed_run_restores_first_then_does_what_it_was_asked() {
  comfy_setup "$FUNCNAME"
  write_marker
  assert_exit 2 "comfy start without --stop-vllm" -- comfy start
  local err="$ERR"
  assert_eq 1 "$(log_count pwsh.exe -Detach)" "the restore ran"
  assert_exit 0 "vllm is listed" -- alive vllm
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_eq "$CS4_LINE" "$err" "then the refusal of CS4"
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-stop"
  write_marker
  assert_exit 0 "comfy start --stop-vllm" -- comfy start --stop-vllm
  assert_eq 1 "$(log_count pwsh.exe -Detach)" "the restore ran"
  assert_eq 1 "$(grep -c ' wslc stop vllm$' "$STUB/calls.log")" "then one stop of vllm"
  assert_exit 0 "and ComfyUI runs" -- alive comfyui
  kill_recorded_pids "$CASE"
}

# CS15
t_a_run_call_that_fails_after_the_engine_created_the_container_leaves_nothing_running() {
  comfy_setup "$FUNCNAME"
  printf '1\n' > "$STUB/run-fail-comfyui"
  logs_250
  assert_exit 1 "comfy start" -- comfy start
  local file
  file="$(tail_files)"
  assert_eq "r9700: comfy: start: the run of comfyui failed (code 1): stub: run: the client failed after the container started (scripted): comfyui; comfyui was listed after the failed launch and was stopped; its last 200 log lines are in $file" "$ERR" "one stderr line"
  call_order "$RUN_RE" ' wslc logs comfyui$' ' wslc stop comfyui$' && assert_eq ok ok "run < logs < stop" || assert_eq "run < logs < stop" "$(cat "$STUB/calls.log")" "the order"
  assert_eq "yes" "$([ "$(grep -n ' wslc list' "$STUB/calls.log" | tail -n 1 | cut -d: -f1)" -gt "$(grep -n ' wslc stop comfyui$' "$STUB/calls.log" | cut -d: -f1)" ] && echo yes || echo no)" "and the last list comes after the stop"
  assert_contains "$OUT" "saved the last 200 log lines" "stdout says it saved"
  assert_contains "$OUT" "stopped comfyui" "and stopped"
  assert_exit 1 "comfyui is not alive" -- alive comfyui
  assert_missing "$MARKER_FILE" "no marker"
  assert_eq 0 "$(log_count pwsh.exe -Detach)" "no start of the server"
  assert_exit 0 "the lock is free" -- lock_free
  kill_recorded_pids "$CASE"
}

# CS16
t_the_same_with_stop_vllm_restores_the_server_only_after_comfyui_is_gone() {
  comfy_setup "$FUNCNAME"
  prod_running
  printf '1\n' > "$STUB/run-fail-comfyui"
  logs_250
  assert_exit 1 "comfy start --stop-vllm" -- comfy start --stop-vllm
  assert_contains "$ERR" "the run of comfyui failed (code 1): stub: run: the client failed after the container started (scripted): comfyui; comfyui was listed after the failed launch and was stopped" "the CS15 line"
  assert_eq 1 "$(grep -c ' wslc stop vllm$' "$STUB/calls.log")" "exactly one stop of vllm"
  call_order ' wslc stop vllm$' ' wslc stop comfyui$' ' pwsh.exe ' && assert_eq ok ok "stop vllm < stop comfyui < pwsh" || assert_eq "stop vllm < stop comfyui < pwsh" "$(cat "$STUB/calls.log")" "the order"
  assert_eq 1 "$(log_count pwsh.exe -Detach)" "one start of the server"
  assert_exit 0 "vllm is listed" -- alive vllm
  assert_exit 1 "comfyui is not alive" -- alive comfyui
  assert_missing "$MARKER_FILE" "no marker"
  assert_exit 0 "the lock is free" -- lock_free
  kill_recorded_pids "$CASE"
}

# CS17
t_a_run_call_cut_by_term_after_the_engine_created_the_container_is_reconciled_the_same_way() {
  comfy_setup "$FUNCNAME"
  printf '30\n' > "$STUB/run-delay-comfyui"
  comfy_bg start
  wait_for "$STUB/containers/comfyui.pid" 100
  kill -TERM "$SUP"
  comfy_end 15
  assert_eq 143 "$SRC" "exit 143"
  assert_contains "$SERR" "r9700: comfy: start: interrupted by TERM" "the line"
  call_order "$RUN_RE" ' wslc stop comfyui$' && assert_eq ok ok "a stop of comfyui follows the run" || assert_eq "run < stop" "$(cat "$STUB/calls.log")" "the order"
  assert_exit 1 "comfyui is not alive" -- alive comfyui
  assert_missing "$MARKER_FILE" "no marker"
  assert_exit 0 "the lock is free" -- lock_free
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-vllm"
  prod_running
  printf '30\n' > "$STUB/run-delay-comfyui"
  comfy_bg start --stop-vllm
  wait_for "$STUB/containers/comfyui.pid" 100
  kill -TERM "$SUP"
  comfy_end 15
  assert_eq 143 "$SRC" "with --stop-vllm: exit 143"
  call_order ' wslc stop comfyui$' ' pwsh.exe ' && assert_eq ok ok "one start of the server after the stop of comfyui" || assert_eq "stop comfyui < pwsh" "$(cat "$STUB/calls.log")" "the order"
  assert_eq 1 "$(log_count pwsh.exe -Detach)" "exactly one"
  assert_exit 0 "vllm is listed" -- alive vllm
  assert_missing "$MARKER_FILE" "no marker"
  kill_recorded_pids "$CASE"
}

# CS18
t_a_listing_that_cannot_be_read_during_the_cleanup_stops_nothing_and_names_both_commands() {
  # the lists the start makes before the run call are counted from the log of a run that fails the CS16 way, never typed
  local skip skip_plain
  comfy_setup "$FUNCNAME"
  prod_running
  printf '1\n' > "$STUB/run-fail-comfyui"
  assert_exit 1 "the CS16 run, to count the lists before the launch" -- comfy start --stop-vllm
  skip="$(awk '/ wslc run -d --rm --name comfyui / { exit } / wslc list/ { n++ } END { print n + 0 }' "$STUB/calls.log")"
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-count"
  printf '1\n' > "$STUB/run-fail-comfyui"
  assert_exit 1 "the CS15 run, to count them without --stop-vllm" -- comfy start
  skip_plain="$(awk '/ wslc run -d --rm --name comfyui / { exit } / wslc list/ { n++ } END { print n + 0 }' "$STUB/calls.log")"
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-fail"
  prod_running
  printf '1\n' > "$STUB/run-fail-comfyui"
  printf '%s 3\n' "$skip" > "$STUB/fail-list"
  assert_exit 5 "the three lists after the launch fail" -- comfy start --stop-vllm
  assert_eq "r9700: comfy: start: the run of comfyui failed (code 1): stub: run: the client failed after the container started (scripted): comfyui; the container list failed 3 times (code 1) after the launch: whether comfyui runs is not known; run bin/r9700 comfy stop, then bin/r9700 init (the marker stays)" "$ERR" "exactly one line naming both commands"
  assert_eq 0 "$(grep -c ' wslc stop comfyui$' "$STUB/calls.log")" "no stop of comfyui"
  assert_eq 0 "$(log_count wslc logs)" "no logs call"
  assert_eq 0 "$(log_count pwsh.exe -Detach)" "no start of the server"
  assert_exit 0 "the marker exists" -- test -f "$MARKER_FILE"
  marker_read "$MARKER_FILE"
  assert_eq comfyui "${MARKER[COMFY_CONTAINER]:-}" "with COMFY_CONTAINER"
  assert_eq yes "${MARKER[PROD_WAS_RUNNING]}" "and PROD_WAS_RUNNING=yes"
  assert_exit 0 "comfyui is still alive" -- alive comfyui
  assert_exit 0 "the lock is free" -- lock_free
  assert_exit 0 "comfy stop" -- comfy stop
  assert_exit 0 "init" -- r9700 init --model "$MODEL_35B"
  assert_exit 0 "vllm is back" -- alive vllm
  assert_missing "$MARKER_FILE" "the marker is gone"
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-nomarker"
  printf '1\n' > "$STUB/run-fail-comfyui"
  printf '%s 3\n' "$skip_plain" > "$STUB/fail-list"
  assert_exit 5 "without --stop-vllm" -- comfy start
  assert_eq "r9700: comfy: start: the run of comfyui failed (code 1): stub: run: the client failed after the container started (scripted): comfyui; the container list failed 3 times (code 1) after the launch: whether comfyui runs is not known; run bin/r9700 comfy stop, then bin/r9700 init" "$ERR" "the same line without the marker words"
  assert_missing "$MARKER_FILE" "no marker"
  kill_recorded_pids "$CASE"
}

run_all_tests
