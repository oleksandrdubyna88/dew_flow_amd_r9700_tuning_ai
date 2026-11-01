#!/usr/bin/env bash
# The CI stubs under tests/stubs (E1.S2 part (a): A1 and the guarantees the later parts rely on): the call log, the scripted answers, the
# containers, the stub worker. Every test body is a function t_<guarantee>; each runs in its own subshell.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"

t_a_stub_refuses_to_run_without_a_stub_directory() {
  setup_case "$FUNCNAME"
  local stub
  assert_exit 99 "wslc exits 99" -- env -u R9700_STUB_DIR wslc list
  assert_eq "stub: R9700_STUB_DIR unset" "$ERR" "wslc names the missing variable"
  for stub in powershell.exe pwsh.exe worker.sh; do
    assert_exit 99 "$stub exits 99" -- env -u R9700_STUB_DIR "$STUBS/$stub" ok
    assert_eq "stub: R9700_STUB_DIR unset" "$ERR" "$stub names the missing variable"
  done
  assert_exit 99 "an empty variable is unset too" -- env R9700_STUB_DIR= wslc list
  assert_missing "$STUB/calls.log" "the refused calls logged nothing"
}

t_every_stub_call_is_logged_append_only_with_a_number_a_stamp_and_its_argv() {
  setup_case "$FUNCNAME"
  local first
  wslc list > /dev/null
  first="$(head -n 1 "$STUB/calls.log")"
  pwsh.exe -NoProfile -File 'C:\x.ps1' > /dev/null
  powershell.exe -NoProfile -Command 'Available MBytes' > /dev/null
  wslc exec vllm python3 -c $'import x\nprint(1)' > /dev/null
  assert_eq "4" "$(wc -l < "$STUB/calls.log" | tr -d ' ')" "one line per call, a multi-line argument stays on one line"
  assert_eq "$first" "$(head -n 1 "$STUB/calls.log")" "the first line was never rewritten"
  if [[ $first =~ ^[0-9]+\.[0-9]+\ 1\ wslc\ list$ ]]; then assert_eq ok ok "line 1: stamp, number 1, stub name, argv"; else assert_eq "<stamp> 1 wslc list" "$first" "line 1: stamp, number 1, stub name, argv"; fi
  assert_eq "1 2 3 4" "$(awk '{ printf "%s%s", sep, $2; sep = " " }' "$STUB/calls.log")" "the numbers run across all stubs"
  assert_eq "pwsh.exe -NoProfile -File C:\\x.ps1" "$(sed -n 2p "$STUB/calls.log" | cut -d' ' -f3-)" "the argv is joined by single spaces"
  assert_contains "$(sed -n 4p "$STUB/calls.log")" "python3 -c import x<LF>print(1)" "a newline inside an argument is written as <LF>"
}

t_calls_argv_holds_one_block_per_call_with_one_line_per_argument() {
  setup_case "$FUNCNAME"
  wslc run -d --rm --name n1 'a b' c > /dev/null
  argv_of wslc
  assert_eq "run|-d|--rm|--name|n1|a b|c" "$(IFS='|'; echo "${ARGV[*]}")" "one element per argument; a space inside one stays inside it"
  assert_contains "$HDR" "@@ 1 wslc " "the header names the call number and the stub"
  assert_contains "$HDR" "/tests/stubs/wslc" "the header carries the path the stub was started by"
}

t_a_stopped_container_is_not_listed_and_stopping_an_unknown_one_fails() {
  setup_case "$FUNCNAME"
  wslc_run r9700tune-a img > /dev/null
  wslc_run r9700tune-b img > /dev/null
  assert_eq "r9700tune-a r9700tune-b" "$(wslc_list | sort | tr '\n' ' ' | sed 's/ $//')" "both listed"
  wslc_stop r9700tune-a
  assert_eq "r9700tune-b" "$(wslc_list)" "only the stopped one is gone"
  assert_exit 1 "stopping an unknown container fails" -- wslc_stop r9700tune-zzz
  kill_recorded_pids "$CASE"
}

t_a_dead_container_is_not_listed_even_when_its_pid_file_is_left() {
  setup_case "$FUNCNAME"
  local pid
  wslc_run r9700tune-a img > /dev/null
  pid="$(pid_of r9700tune-a)"
  kill -KILL "$pid"
  gone "$pid"
  assert_eq "" "$(wslc_list)" "a process that died is not a running container"
  assert_exit 0 "its stale pid file is still there" -- test -f "$STUB/containers/r9700tune-a.pid"
}

t_the_exit_trap_killer_ends_the_stub_containers_it_recorded() {
  setup_case "$FUNCNAME"
  local pid
  wslc_run r9700tune-a img > /dev/null
  pid="$(pid_of r9700tune-a)"
  kill_recorded_pids "$CASE"
  assert_exit 0 "kill_recorded_pids ended the container" -- gone "$pid"
}

t_the_stubs_print_the_carriage_returns_of_a_windows_executable() {
  setup_case "$FUNCNAME"
  printf '8000\n' > "$STUB/answers/ram"
  assert_contains "$(wslc list)" "$CR" "wslc list"
  assert_contains "$(wslc run -d --rm --name r9700tune-a img)" "$CR" "wslc run"
  assert_contains "$(powershell.exe -NoProfile -Command 'Available MBytes')" "$CR" "powershell.exe, the RAM answer"
  assert_contains "$(powershell.exe -NoProfile -Command 'Get-WinEvent')" "$CR" "powershell.exe, the disk answer"
  assert_contains "$(pwsh.exe -NoProfile -File x)" "$CR" "pwsh.exe"
  printf 'Mean TTFT (ms): 1\n' > "$STUB/answers/bench"
  assert_contains "$(wslc exec r9700tune-a vllm bench serve --max-concurrency 1 --seed 1)" "$CR" "wslc exec vllm bench serve"
  printf 'ok\n' > "$STUB/answers/ready"
  assert_contains "$(wslc exec vllm python3 -c 'urlopen /v1/completions')" "$CR" "wslc exec, the restore probe"
  kill_recorded_pids "$CASE"
}

t_the_stub_answers_files_hand_out_line_k_and_the_last_line_repeats() {
  setup_case "$FUNCNAME"
  printf '8000\n100\n' > "$STUB/answers/ram"
  assert_eq "8000 100 100" "$(win_ram_mb) $(win_ram_mb) $(win_ram_mb)" "call 1 takes line 1, call 2 line 2, call 3 repeats the last"
  printf '1\n2\n3' > "$STUB/answers/disk"
  assert_eq "1 2 3 3" "$(win_disk_newest) $(win_disk_newest) $(win_disk_newest) $(win_disk_newest)" "a last line without a newline counts"
}

t_the_stub_answers_the_wait_ready_probe_with_an_exit_code() {
  setup_case "$FUNCNAME"
  local program="import urllib.request;urllib.request.urlopen('http://127.0.0.1:8000/v1/models',timeout=5)"
  printf 'ok\nmodels-only\nfail\n' > "$STUB/answers/ready"
  wslc_run vllm img > /dev/null
  assert_exit 0 "ok: exit 0" -- wslc_exec 60 vllm python3 -c "$program"
  assert_exit 0 "models-only: /v1/models answers, so check 1 passes" -- wslc_exec 60 vllm python3 -c "$program"
  assert_exit 1 "fail: exit 1" -- wslc_exec 60 vllm python3 -c "$program"
  kill_recorded_pids "$CASE"
}

t_the_stub_pwsh_starts_the_server_named_by_R9700_STUB_PROD() {
  setup_case "$FUNCNAME"
  R9700_STUB_PROD=prod-x restore_start > /dev/null
  assert_exit 0 "the pid file carries that name" -- test -f "$STUB/containers/prod-x.pid"
  assert_missing "$STUB/containers/vllm.pid" "and no other"
  restore_start > /dev/null
  assert_exit 0 "the default name is vllm" -- test -f "$STUB/containers/vllm.pid"
  local pid; pid="$(pid_of vllm)"
  restore_start > /dev/null
  assert_eq "$pid" "$(pid_of vllm)" "a second start does not start a second server"
  kill_recorded_pids "$CASE"
}

t_the_stub_worker_modes_exit_with_their_codes_and_count_their_calls() {
  setup_case "$FUNCNAME"
  assert_exit 0 "ok" -- "$STUBS/worker.sh" ok
  assert_exit 0 "worker.done exists after ok" -- test -f "$STUB/worker.done"
  assert_exit 3 "exit3" -- "$STUBS/worker.sh" exit3
  assert_exit 4 "exit4" -- "$STUBS/worker.sh" exit4
  assert_exit 1 "fail" -- "$STUBS/worker.sh" fail
  assert_eq "ok exit3 exit4 fail" "$(tr '\n' ' ' < "$STUB/worker.calls" | sed 's/ $//')" "worker.calls holds one line per call, the mode"
  assert_exit 2 "an unknown mode" -- "$STUBS/worker.sh" nosuch
  assert_contains "$ERR" 'worker.sh: unknown mode "nosuch"; legal: ok child exit3-then-ok exit3 exit4 fail' "names the legal modes"
  assert_exit 2 "no mode" -- "$STUBS/worker.sh"
}

t_the_stub_worker_exit3_then_ok_exits_3_once_and_then_0() {
  setup_case "$FUNCNAME"
  assert_exit 3 "the first call" -- "$STUBS/worker.sh" exit3-then-ok
  assert_exit 0 "the second call" -- "$STUBS/worker.sh" exit3-then-ok
  assert_exit 0 "the third call" -- "$STUBS/worker.sh" exit3-then-ok
  assert_eq "3" "$(wc -l < "$STUB/worker.calls" | tr -d ' ')" "counted in worker.calls"
}

t_the_stub_worker_writes_the_ready_file_of_its_step() {
  setup_case "$FUNCNAME"
  local run="$CASE/run"
  mkdir "$run" # the supervisor's run directory exists; the stub makes only steps/ in it, never the run directory
  R9700_RUN_DIR="$run" R9700_STEP_N=2 "$STUBS/worker.sh" fail
  assert_exit 0 "<run dir>/steps/<n>.ready exists" -- test -f "$run/steps/2.ready"
  "$STUBS/worker.sh" fail
  assert_missing "$CASE/steps" "without R9700_RUN_DIR no folder is made"
}

t_the_stub_worker_child_mode_keeps_a_child_in_its_group_and_a_heartbeat_until_it_is_ended() {
  setup_case "$FUNCNAME"
  local worker child h1 h2 i
  mkdir "$CASE/run" # the supervisor's run directory exists; the stub makes only steps/ in it
  R9700_RUN_DIR="$CASE/run" R9700_STEP_N=1 setsid "$STUBS/worker.sh" child > /dev/null 2>&1 &
  worker=$!
  disown "$worker" # no "Killed" job notice when the test ends it
  guard_pid "$worker" "worker-$FUNCNAME"
  for i in $(seq 1 100); do [ -f "$CASE/run/steps/1.ready" ] && break; sleep 0.1; done
  assert_exit 0 "ready is written after child.pid" -- test -f "$STUB/child.pid"
  child="$(cat "$STUB/child.pid")"
  assert_exit 0 "the child is alive" -- kill -0 "$child"
  assert_eq "$worker" "$(pgrp_of "$worker")" "the worker leads its own group"
  assert_eq "$worker" "$(pgrp_of "$child")" "the child is in the worker's group"
  h1="$(date -r "$STUB/heartbeat" +%s%N)"
  sleep 0.35
  h2="$(date -r "$STUB/heartbeat" +%s%N)"
  assert_exit 0 "the heartbeat moves every 0.1 s" -- test "$h2" -gt "$h1"
  kill -TERM -- "-$worker"
  assert_exit 0 "TERM to the group ends the worker" -- gone "$worker"
  assert_exit 0 "and its child" -- gone "$child"
  kill_recorded_pids "$CASE"
}

t_a_stub_worker_and_its_child_are_recorded_for_the_killer_but_are_not_containers() {
  setup_case "$FUNCNAME"
  local worker child i
  setsid "$STUBS/worker.sh" child > /dev/null 2>&1 &
  worker=$!
  disown "$worker" # no "Killed" job notice when the test ends it
  guard_pid "$worker" "worker-$FUNCNAME"
  for i in $(seq 1 100); do [ -f "$STUB/child.pid" ] && break; sleep 0.1; done
  child="$(cat "$STUB/child.pid")"
  assert_eq "" "$(wslc_list)" "wslc list does not show the worker or its child"
  kill_recorded_pids "$CASE"
  assert_exit 0 "the recorded worker is killed by the EXIT-trap killer" -- gone "$worker"
  assert_exit 0 "and the recorded child" -- gone "$child"
}

# ---- the stubs are not more lenient than the real wslc ------------------------------------------------------------------------------------

t_exec_and_logs_refuse_a_container_that_is_not_running() {
  setup_case "$FUNCNAME"
  assert_exit 1 "exec in a container that never ran" -- wslc exec nosuch true
  assert_contains "$ERR" "not running: nosuch" "the error line names it"
  assert_exit 1 "logs of a container that never ran" -- wslc logs nosuch
  assert_contains "$ERR" "not running: nosuch" "the error line names it"
  wslc run -d --rm --name r9700tune-a img > /dev/null
  assert_exit 0 "exec in a running container" -- wslc exec r9700tune-a true
  assert_exit 0 "logs of a running container" -- wslc logs r9700tune-a
  wslc stop r9700tune-a > /dev/null
  assert_exit 1 "exec after the stop" -- wslc exec r9700tune-a true
  assert_exit 1 "logs after the stop" -- wslc logs r9700tune-a
  local pid
  wslc run -d --rm --name r9700tune-b img > /dev/null
  pid="$(pid_of r9700tune-b)"
  kill -KILL "$pid"
  gone "$pid"
  assert_exit 1 "exec in a container whose process died (its pid file is left)" -- wslc exec r9700tune-b true
  assert_exit 1 "logs of the same" -- wslc logs r9700tune-b
  kill_recorded_pids "$CASE"
}

t_run_refuses_a_name_that_is_in_use_and_keeps_the_live_record() {
  setup_case "$FUNCNAME"
  wslc run -d --rm --name r9700tune-a img > /dev/null
  local before
  before="$(cat "$STUB/containers/r9700tune-a.pid")"
  assert_exit 1 "a second run of the same name" -- wslc run -d --rm --name r9700tune-a img
  assert_contains "$ERR" "name in use: r9700tune-a" "the error line names it"
  assert_eq "$before" "$(cat "$STUB/containers/r9700tune-a.pid")" "the live record was not overwritten"
  assert_exit 0 "the first container is still alive" -- kill -0 "${before%% *}"
  local pid="${before%% *}"
  kill -KILL "$pid"
  gone "$pid"
  assert_exit 0 "a name whose process died is free again" -- wslc run -d --rm --name r9700tune-a img
  kill_recorded_pids "$CASE"
}

# ---- a stub never creates its own directory -----------------------------------------------------------------------------------------------

t_a_stub_does_not_create_a_missing_stub_directory_or_its_parents() {
  setup_case "$FUNCNAME"
  local gone_dir="$CASE/removed/deeper/stub" stub
  for stub in wslc powershell.exe pwsh.exe worker.sh; do
    assert_exit 99 "$stub with R9700_STUB_DIR pointing nowhere" -- env R9700_STUB_DIR="$gone_dir" "$STUBS/$stub" ok
    assert_contains "$ERR" "R9700_STUB_DIR" "$stub: the line names the variable"
    assert_missing "$CASE/removed" "$stub: nothing of the path was created"
  done
}

t_a_stub_whose_directory_vanishes_mid_run_does_not_bring_it_back() {
  setup_case "$FUNCNAME"
  printf 'hang\n' > "$STUB/mode"
  ( wslc run -d --rm --name r9700tune-x img > /dev/null 2>&1 ) &
  local i pid
  for i in $(seq 1 100); do [ -f "$STUB/hung/containers/1.pid" ] && break; sleep 0.1; done
  read -r pid _ < "$STUB/hung/containers/1.pid"
  rm -rf "$STUB" # what the runner does at its end; the stub is still in its call and wakes up afterwards
  kill -KILL "$pid"
  wait
  sleep 0.3
  assert_missing "$STUB" "the folder stays removed (the stub neither made it nor its parents again)"
  kill_recorded_pids "$CASE"
}

run_all_tests
