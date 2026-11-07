#!/usr/bin/env bash
# The adapter seam (lib/adapter.sh) and t_scale (lib/run_guarded.sh): E1.S2 part (a), scenarios A2-A5 and A7, ceilings, refusals; the signal and process rules are tests/test_adapter_signals.sh.
# Every test body is a function t_<guarantee>; each runs in its own subshell and writes only below $R9700_TEST_ROOT.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"

t_wslc_run_starts_a_detached_process_that_outlives_its_caller() {
  setup_case "$FUNCNAME"
  local pid ticks
  ( wslc_run r9700tune-a img sleep > "$CASE/run.out" )
  assert_exit 0 "the pid file exists after the caller's subshell ended" -- test -f "$STUB/containers/r9700tune-a.pid"
  read -r pid ticks < "$STUB/containers/r9700tune-a.pid"
  assert_exit 0 "the process is alive" -- kill -0 "$pid"
  if [ "$(pgrp_of "$pid")" != "$(pgrp_of $$)" ]; then assert_eq ok ok "its process group is not the test's"; else assert_eq "another group" "the test's group" "its process group is not the test's"; fi
  assert_eq "$pid" "$(sid_of "$pid")" "it leads its own session (setsid): no group kill of its caller can reach it"
  assert_eq "$pid" "$(pgrp_of "$pid")" "and its own process group"
  assert_eq "$ticks" "$(_start_ticks "$pid")" "the record holds the REAL start ticks (amendment A4)"
  assert_eq "r9700tune-a" "$(wslc_list)" "wslc_list prints the container"
  assert_exit 0 "wslc_stop returns 0" -- wslc_stop r9700tune-a
  assert_exit 0 "the process is gone" -- gone "$pid"
  assert_missing "$STUB/containers/r9700tune-a.pid" "the pid file is removed"
  assert_eq "" "$(wslc_list)" "wslc_list prints nothing"
  assert_eq "run -d --rm --name r9700tune-a img sleep" "$(sed -n 1p "$STUB/calls.log" | cut -d' ' -f3- | sed 's/^wslc //')" "the run line is run -d --rm --name <name> <args>"
}

# The step logs what a failed stop of the operator's server printed (2026-11-03: a stop returned 1 and nothing said why, because the output was discarded).
t_wslc_stop_keeps_what_wslc_printed_stdout_and_stderr_without_carriage_returns() {
  setup_case "$FUNCNAME"
  wslc_run r9700tune-a img > /dev/null
  assert_exit 0 "wslc_stop of a running container" -- wslc_stop r9700tune-a
  assert_eq "r9700tune-a" "$OUT" "it prints the stub's answer (the container's name) and keeps nothing back"
  assert_not_contains "$OUT" "$CR" "without the carriage return of the Windows executable"
  wslc_run r9700tune-b img > /dev/null
  printf '1\n' > "$STUB/stop-fail-r9700tune-b"
  assert_exit 1 "a stop that fails returns wslc's own code" -- wslc_stop r9700tune-b
  assert_contains "$OUT" "stub: stop failed (scripted): r9700tune-b" "and prints the error text of wslc (its stderr is merged into the output)"
  assert_exit 1 "stopping an unknown container" -- wslc_stop r9700tune-zzz
  assert_contains "$OUT" "stub: no such running container: r9700tune-zzz" "the error text is kept for this failure too"
  kill_recorded_pids "$CASE"
}

t_wslc_stop_keeps_only_the_last_twenty_lines_of_a_verbose_answer() {
  setup_case "$FUNCNAME"
  wslc_run r9700tune-a img > /dev/null
  printf '100\n' > "$STUB/stop-lines-r9700tune-a"
  assert_exit 0 "a verbose stop" -- wslc_stop r9700tune-a
  assert_eq "20" "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "twenty lines, not a hundred and one"
  assert_contains "$OUT" "stub stop noise 100" "the last noise line is kept"
  assert_not_contains "$OUT" "stub stop noise 80" "an early one is not"
  kill_recorded_pids "$CASE"
}

# The descriptor that carries the text of a stop must not reach the child: a process the stop leaves running (the operator starts a server by hand, a helper
# of wslc) would hold the pipe open and the function would wait for it (found by tests/test_run.sh R18b: the stub's hook starts a container during the stop).
t_wslc_stop_does_not_wait_for_a_process_that_the_stop_leaves_running_with_the_pipe() {
  setup_case "$FUNCNAME"
  local i
  wslc_run r9700tune-a img > /dev/null
  printf 'wslc run -d --rm --name r9700tune-b img > /dev/null\n' > "$STUB/on-stop-r9700tune-a" # a container starts while the stop runs, and lives on
  ( wslc_stop r9700tune-a > "$CASE/stop.out" 2>&1; echo "$?" > "$CASE/stop.rc" ) &
  disown
  for i in $(seq 1 100); do [ -f "$CASE/stop.rc" ] && break; sleep 0.1; done # bounded: a leaked descriptor would hold the call for the life of the container
  if [ -f "$CASE/stop.rc" ]; then assert_eq "0" "$(cat "$CASE/stop.rc")" "the stop returned, and returned 0"; else assert_eq "returned" "(still waiting after 10 s)" "the stop returned: it does not wait for the container that started during it"; fi
  assert_eq "r9700tune-a" "$(cat "$CASE/stop.out" 2> /dev/null)" "and kept its text"
  assert_eq "r9700tune-b" "$(wslc_list)" "the container that the hook started is running"
  kill_recorded_pids "$CASE"
}

t_wslc_run_prints_the_last_two_lines_without_carriage_returns() {
  setup_case "$FUNCNAME"
  assert_exit 0 "wslc_run returns 0" -- wslc_run r9700tune-a img
  assert_eq 2 "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "two lines of the stub's three"
  assert_not_contains "$OUT" "$CR" "no carriage return"
  assert_not_contains "$OUT" "stub-line-1" "the first line is cut"
  assert_contains "$OUT" "stub-line-3" "the last line is kept"
  kill_recorded_pids "$CASE"
}

t_carriage_returns_are_removed_by_every_adapter_function() {
  setup_case "$FUNCNAME"
  printf 'one\r\ntwo\r\n' > "$STUB/answers/logs"
  wslc_run r9700tune-a img > /dev/null
  assert_contains "$(wslc logs r9700tune-a)" "$CR" "the stub prints the CRs a Windows executable prints (so the test can fail)"
  assert_exit 0 "wslc_logs" -- wslc_logs r9700tune-a
  assert_eq "one|two" "$(echo "$OUT" | tr '\n' '|' | sed 's/|$//')" "the log lines"
  assert_not_contains "$OUT" "$CR" "wslc_logs: no CR"
  assert_exit 0 "wslc_list" -- wslc_list
  assert_not_contains "$OUT" "$CR" "wslc_list: no CR"
  assert_eq "r9700tune-a" "$OUT" "wslc_list: the name is clean"
  assert_exit 0 "win_ram_mb" -- win_ram_mb
  assert_not_contains "$OUT" "$CR" "win_ram_mb: no CR"
  assert_exit 0 "win_disk_newest" -- win_disk_newest
  assert_not_contains "$OUT" "$CR" "win_disk_newest: no CR"
  assert_exit 0 "wslc_exec" -- wslc_exec 60 r9700tune-a vllm bench serve --max-concurrency 1 --seed 1
  assert_not_contains "$OUT" "$CR" "wslc_exec: no CR"
  mkdir -p "$STUB/stopped"
  : > "$STUB/stopped/old"
  assert_exit 0 "wslc_remove" -- wslc_remove old
  assert_not_contains "$OUT" "$CR" "wslc_remove: no CR"
  assert_exit 0 "wslc_inspect" -- wslc_inspect img:x
  assert_contains "$(wslc inspect img:x)" "$CR" "the stub prints the CRs for inspect too (so the test can fail)"
  assert_not_contains "$OUT" "$CR" "wslc_inspect: no CR"
  printf 'ok\n' > "$STUB/answers/comfy_ready"
  assert_exit 0 "comfy_probe" -- comfy_probe r9700tune-a
  assert_not_contains "$OUT" "$CR" "comfy_probe: no CR"
  assert_exit 0 "restore_start" -- restore_start
  assert_not_contains "$OUT" "$CR" "restore_start: no CR"
  assert_contains "$(wslc build -t x .)" "$CR" "the stub prints the CRs of a Windows executable for build (so the test can fail)"
  assert_exit 0 "wslc_build" -- wslc_build 60 -t x .
  assert_not_contains "$OUT" "$CR" "wslc_build: no CR"
  assert_exit 0 "wslc_volume_create" -- wslc_volume_create vol-a
  assert_not_contains "$OUT" "$CR" "wslc_volume_create: no CR"
  assert_exit 0 "wslc_volume_list" -- wslc_volume_list
  assert_eq "vol-a" "$OUT" "wslc_volume_list: the name is clean"
  assert_not_contains "$OUT" "$CR" "wslc_volume_list: no CR"
  kill_recorded_pids "$CASE"
}

t_win_ram_mb_prints_nothing_and_returns_1_on_garbage_and_the_integer_otherwise() {
  setup_case "$FUNCNAME"
  printf 'garbage\n' > "$STUB/answers/ram"
  assert_exit 1 "garbage: rc 1" -- win_ram_mb
  assert_eq "" "$OUT" "garbage: no output"
  printf ' 8000 \n' > "$STUB/answers/ram"
  assert_exit 0 "spaces and a CR around the integer: rc 0" -- win_ram_mb
  assert_eq "8000" "$OUT" "the integer, cleaned"
  printf '12x\n' > "$STUB/answers/ram"
  assert_exit 1 "an integer with a suffix is garbage" -- win_ram_mb
  printf '\n' > "$STUB/answers/ram"
  assert_exit 1 "an empty answer is garbage" -- win_ram_mb
  assert_eq "" "$OUT" "empty: no output"
  rm "$STUB/answers/ram"
  assert_exit 1 "no scripted answer: the stub fails, the adapter returns 1" -- win_ram_mb
}

t_win_ram_mb_asks_powershell_for_available_mbytes_as_one_argument() {
  setup_case "$FUNCNAME"
  win_ram_mb > /dev/null
  argv_of powershell.exe
  assert_eq "3" "${#ARGV[@]}" "three arguments: -NoProfile -Command <string>"
  assert_eq "-NoProfile" "${ARGV[0]}" "first"
  assert_eq "-Command" "${ARGV[1]}" "second"
  assert_eq '[int](Get-Counter "\Memory\Available MBytes").CounterSamples[0].CookedValue' "${ARGV[2]}" "the command of ram_guard_all.sh line 8, one element"
}

t_win_disk_newest_prints_the_record_id_and_nothing_on_a_non_integer() {
  setup_case "$FUNCNAME"
  assert_exit 0 "an id" -- win_disk_newest
  assert_eq "100" "$OUT" "the id"
  printf '\n' > "$STUB/answers/disk"
  assert_exit 1 "an empty answer" -- win_disk_newest
  assert_eq "" "$OUT" "no output"
  printf 'x1\n' > "$STUB/answers/disk"
  assert_exit 1 "text" -- win_disk_newest
  win_disk_newest > /dev/null
  argv_of powershell.exe
  assert_eq '$e = Get-WinEvent -FilterHashtable @{LogName="System"; ProviderName="disk","stornvme"} -MaxEvents 1 -ErrorAction Stop; $e.RecordId' "${ARGV[2]}" "the command of disk_gate.sh line 7"
}

t_restore_start_passes_the_configured_script_and_arguments_as_argv() {
  setup_case "$FUNCNAME"
  local -a want=(-NoProfile -File 'C:\r9700\start-vllm.ps1' -Model /root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ -ServedName qwen3.6-35b-a3b -MaxModelLen 131072 -MaxNumSeqs 4 -Detach)
  assert_exit 0 "restore_start returns 0" -- restore_start
  argv_of pwsh.exe
  assert_eq "$(printf '%s\n' "${want[@]}")" "$(printf '%s\n' "${ARGV[@]}")" "the argv array, one element per word"
  assert_eq "${want[*]}" "$(log_args pwsh.exe)" "the call log line"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "-Detach once (the fixture's RESTORE_ARGS already holds it)"
  assert_exit 0 "the restore created the operator's server" -- test -f "$STUB/containers/vllm.pid"
  assert_eq "vllm" "$(wslc_list)" "wslc_list shows it"
  kill_recorded_pids "$CASE"
}

t_restore_start_adds_detach_when_the_arguments_lack_it() {
  setup_case "$FUNCNAME"
  sed 's/ -Detach"$/"/' "$CASE/machine.env" > "$CASE/machine2.env"
  config_load "$CASE/machine2.env" "$MODEL_35B" || exit 2
  assert_not_contains "$R9700_RESTORE_ARGS" "Detach" "the variant has no -Detach"
  restore_start > /dev/null
  argv_of pwsh.exe
  assert_eq "-Detach" "${ARGV[-1]}" "-Detach is the last argument"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "and only one"
  kill_recorded_pids "$CASE"
}

t_restore_start_prints_the_last_five_lines() {
  setup_case "$FUNCNAME"
  assert_exit 0 "restore_start" -- restore_start
  assert_eq 5 "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "five lines of the stub's seven"
  assert_contains "$OUT" "stub-restore-7" "the last line is kept"
  assert_not_contains "$OUT" "stub-restore-2" "an early line is cut"
  kill_recorded_pids "$CASE"
}

t_a_bare_command_resolves_on_PATH_and_an_absolute_path_is_used_as_given() {
  setup_case "$FUNCNAME"
  wslc_list > /dev/null
  argv_of wslc
  assert_contains "$HDR" " $STUBS/wslc" "WSLC=wslc: the stub on PATH ran"
  mkdir -p "$CASE/bin"
  ln -s "$STUBS/wslc" "$CASE/bin/wslc"
  R9700_WSLC="$CASE/bin/wslc"
  wslc_list > /dev/null
  argv_of wslc
  assert_contains "$HDR" " $CASE/bin/wslc" "an absolute WSLC: that path ran"
  assert_eq "2" "$(grep -c ' wslc ' "$STUB/calls.log")" "two calls in all"
}

t_an_executable_that_cannot_be_found_is_one_line_and_return_10_and_no_call() {
  setup_case "$FUNCNAME"
  R9700_WSLC=nonesuch-wslc
  assert_exit 10 "a bare name that is not on PATH" -- wslc_list
  assert_eq "adapter: nonesuch-wslc not found on PATH" "$ERR" "the one line"
  R9700_WSLC=/nonexistent/wslc
  assert_exit 10 "an absolute path that is not there" -- wslc_stop r9700tune-a
  assert_eq "adapter: /nonexistent/wslc is not an executable file" "$ERR" "the one line"
  R9700_POWERSHELL=nonesuch.exe
  assert_exit 10 "win_ram_mb with a missing PowerShell" -- win_ram_mb
  R9700_RESTORE_SHELL=nonesuch.exe
  assert_exit 10 "restore_start with a missing shell" -- restore_start
  assert_missing "$STUB/calls.log" "no stub was called"
}

# stub_world: one line "<pid> <name>" for every live process whose environment names THIS test's stub folder (R9700_STUB_DIR=$STUB): the stubs, their sleepers and whatever they
# started, wherever they were put (a `setsid` is no escape: the environment is inherited). bash builtins only, `$(< file)`, so the scan itself starts no process to be found; a
# process whose environment cannot be read (not ours, gone meanwhile) is skipped. The test shell does not match: its environment was fixed at its exec, before setup_case exported
# the variable (the companion test asserts that, it is not assumed). Environment words are glued together once the NULs are dropped, hence the substring match.
stub_world() {
  local file pid env
  for file in /proc/[0-9]*/environ; do
    pid="${file#/proc/}"
    pid="${pid%/environ}"
    { env="$(< "$file")"; } 2> /dev/null || continue
    [[ $env == *"R9700_STUB_DIR=$STUB"* ]] || continue
    { echo "$pid $(< "/proc/$pid/comm")"; } 2> /dev/null
  done
}

# stub_world_gone: 0 when stub_world is empty, polled for at most 5 s (a killed process takes a moment to be reaped)
stub_world_gone() {
  local i
  for i in $(seq 1 50); do [ -z "$(stub_world)" ] && return 0; sleep 0.1; done
  return 1
}

t_a_hung_adapter_call_is_killed_at_its_ceiling_and_leaves_no_process() {
  setup_case "$FUNCNAME"
  printf 'hang\n' > "$STUB/mode"
  # Scale 30: a 60 s call has 2 s, the 30 s one 1 s. Scale 100 gave 0.6 s and 0.3 s, and under load the ceiling fired before the stub had written its pid file: "nine hung stubs were
  # recorded" found 8 (2026-11-04; scale 30 still found 7 and 8 at 2 burners, hence the count below). The nine calls take about 25 s at scale 30 (the ceilings add up to 600 s / 30 = 20 s) against about 8 s at scale 100.
  R9700_CEILING_SCALE=30
  local t0 t1 name file pid rc
  for name in "wslc_list" "wslc_stop r9700tune-a" "wslc_logs r9700tune-a" "wslc_run r9700tune-a img" "wslc_exec 70 vllm true" "restore_probe vllm" "win_ram_mb" "win_disk_newest" "restore_start"; do
    t0="$(date +%s.%N)"
    $name > /dev/null 2>&1
    rc=$?
    t1="$(date +%s.%N)"
    if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then assert_eq ok ok "$name: the ceiling ended it (rc $rc)"; else assert_eq "124 or 137" "$rc" "$name: the ceiling ended it"; fi
    # The bound does not depend on the load: the shortest REAL ceiling of these calls is 30 s (win_ram_mb), the others 60 and 120 s, so a call that ran at its unscaled ceiling fails here
    # and one that merely waited for a busy CPU does not.
    assert_exit 0 "$name: it ended well below its real ceiling (under 30 s; the scaled ceiling is 1..4 s)" -- awk -v a="$t0" -v b="$t1" 'BEGIN { exit !(b - a < 30) }'
  done
  local n=0
  for file in "$STUB"/hung/containers/*.pid; do
    [ -e "$file" ] || continue # nothing was recorded: the count below says so, the loop must not crash
    n=$((n + 1))
    read -r pid _ < "$file"
    assert_exit 0 "the hung stub's sleep (pid file $n) is gone" -- gone "$pid"
  done
  # At least one, not nine: with a ceiling of 1..4 s a busy CPU lets the ceiling fire before the stub has written its pid file (2026-11-05 at 2 burners: 7, 8 and 8 of 9 were recorded), so the
  # count says only that the scan is alive (a loop over no file proves nothing). That every one of the NINE calls was ended by its ceiling is asserted above, by the return code 124 or 137 of
  # each; and every stub that WAS recorded is asserted gone, so no process is left.
  if [ "$n" -ge 1 ]; then assert_eq ok ok "at least one hung stub was recorded ($n of 9), so the scan of the pid files is alive"; else assert_eq ">= 1" "$n" "at least one hung stub was recorded"; fi
  # The nine back again: a stub that was killed before it wrote its pid file is not in the loop above, but its process is still one with this test's stub folder in its environment.
  stub_world_gone
  assert_eq "" "$(stub_world)" "after the nine calls no process of this test's stub world is alive, recorded or not"
}

t_the_stub_world_scan_finds_a_live_hung_stub_and_not_the_test_shell() {
  setup_case "$FUNCNAME"
  printf 'hang\n' > "$STUB/mode"
  R9700_CEILING_SCALE=1 # the real 60 s ceiling: only the end below ends the call
  ( wslc_list > /dev/null 2>&1 ) &
  local call=$! i
  guard_pid "$call" "hung-call-$call"
  for i in $(seq 1 100); do [ -f "$STUB/hung/containers/1.pid" ] && break; sleep 0.1; done
  assert_exit 0 "the hung stub recorded itself (bounded wait)" -- test -f "$STUB/hung/containers/1.pid"
  assert_contains "$(stub_world)" "sleep" "the scan finds the hung stub's sleeper (a scan that matches nothing would pass for ever)"
  assert_exit 0 "the stub's own bash is in it too" -- test "$(stub_world | wc -l)" -ge 2
  assert_eq "no" "$([[ "$(< "/proc/$$/environ")" == *"R9700_STUB_DIR=$STUB"* ]] 2> /dev/null && echo yes || echo no)" "the test shell's environment does not name the stub folder (fixed before the export)"
  assert_eq "no" "$([[ "$(stub_world | cut -d' ' -f1)" == *"$BASHPID"* ]] && echo yes || echo no)" "and the scan does not list the test shell itself"
  kill_recorded_pids "$CASE" # the recorded sleeper: the stub's wait ends, then timeout and the call
  wait "$call" 2> /dev/null
  stub_world_gone
  assert_eq "" "$(stub_world)" "after the call ended the scan finds nothing again"
}

t_an_adapter_call_never_reads_the_standard_input_of_its_caller() {
  setup_case "$FUNCNAME"
  printf 'eat-stdin\n' > "$STUB/mode"
  local seen="" line
  while IFS= read -r line; do
    wslc_list > /dev/null
    win_ram_mb > /dev/null
    wslc_stop nosuch > /dev/null 2>&1
    seen+="$line "
  done < <(printf 'one\ntwo\nthree\n')
  assert_eq "one two three " "$seen" "a loop that calls the adapter still sees every input line"
}

t_the_ceiling_is_the_documented_one_for_each_function() {
  setup_case "$FUNCNAME"
  # t_ceiling is the only source of the adapter's numbers (t_scale is for sleeps); the adapter must ask it for these, in seconds
  t_ceiling() { echo "$1" >> "$CASE/ceilings"; echo 1; }
  t_scale() { echo "$1" >> "$CASE/sleeps"; echo 1; }
  wslc_run r9700tune-a img > /dev/null
  wslc_exec 33 r9700tune-a true > /dev/null
  wslc_list > /dev/null
  wslc_logs r9700tune-a > /dev/null
  wslc_stop r9700tune-a > /dev/null
  win_ram_mb > /dev/null
  win_disk_newest > /dev/null
  restore_start > /dev/null
  restore_probe vllm > /dev/null
  wslc_build 77 -t a > /dev/null
  wslc_volume_list > /dev/null
  wslc_volume_create v > /dev/null
  wslc_remove a > /dev/null
  wslc_inspect a > /dev/null
  comfy_probe a > /dev/null
  assert_missing "$CASE/sleeps" "t_scale (the sleeps' scale) was never asked for a ceiling"
  # every call asks for the kill-after grace (5) and then its ceiling
  assert_eq "5 120 5 33 5 60 5 60 5 60 5 30 5 60 5 120 5 70 5 77 5 60 5 60 5 60 5 60 5 20" "$(tr '\n' ' ' < "$CASE/ceilings" | sed 's/ $//')" "run 120, exec the argument, list 60, stop 60, logs 60, ram 30, disk 60, restore_start 120, probe 70 through exec, build the argument, volume list 60, volume create 60, remove 60, inspect 60, the ComfyUI probe through exec 20"
  kill_recorded_pids "$CASE"
}

t_a_container_name_that_could_be_an_option_is_refused_before_any_call() {
  setup_case "$FUNCNAME"
  assert_exit 2 "stop --all" -- wslc_stop --all
  assert_contains "$ERR" "wslc_stop" "names the function"
  assert_exit 2 "an empty name" -- wslc_stop ""
  assert_exit 2 "no name" -- wslc_logs
  assert_exit 2 "run with an empty name" -- wslc_run "" img
  assert_exit 2 "run with no argument" -- wslc_run
  assert_exit 2 "a name with a space" -- wslc_stop "a b"
  assert_exit 2 "a name with a slash" -- wslc_stop "a/b"
  assert_exit 2 "exec with a ceiling that is not an integer" -- wslc_exec abc vllm true
  assert_exit 2 "exec with no command" -- wslc_exec 5 vllm
  assert_exit 2 "restore_probe with an option for a name" -- restore_probe -x
  assert_missing "$STUB/calls.log" "no stub was called"
}

t_restore_probe_prints_models_and_completion_or_the_failing_check() {
  setup_case "$FUNCNAME"
  printf 'ok\n' > "$STUB/answers/ready"
  wslc_run vllm img > /dev/null
  assert_exit 0 "ok" -- restore_probe vllm
  assert_eq "models|completion" "$(echo "$OUT" | tr '\n' '|' | sed 's/|$//')" "both checks named"
  printf 'models-only\n' > "$STUB/answers/ready"
  assert_exit 1 "models-only" -- restore_probe vllm
  assert_eq "models|completion: HTTP 500" "$(echo "$OUT" | tr '\n' '|' | sed 's/|$//')" "the failing check and its status"
  printf 'fail\n' > "$STUB/answers/ready"
  assert_exit 1 "fail" -- restore_probe vllm
  assert_contains "$OUT" "models: " "the first check failed"
  argv_of wslc
  assert_eq "exec|vllm|python3|-c" "$(IFS='|'; echo "${ARGV[*]:0:4}")" "it runs the program through wslc exec <name> python3 -c"
  assert_contains "${ARGV[4]}" "/v1/completions" "the program names both checks"
  assert_contains "${ARGV[4]}" "/v1/models" "and the models route"
}

# adapter_probe_run <mode>: runs the adapter's probe program under python with urllib.request.urlopen replaced by a fake that
# answers by <mode>; prints what the program printed; the request bodies it sent go to stderr as JSON.
adapter_probe_run() {
  python3 -I -c '
import json, sys, urllib.error, urllib.request
mode, seen = sys.argv[2], []
class Reply:
    def __init__(self, status, body): self.status, self.body = status, body
    def __enter__(self): return self
    def __exit__(self, *a): return False
    def read(self): return self.body
def fake(req, timeout=None):
    url = req.full_url
    seen.append([url, timeout, json.loads(req.data) if req.data else None])
    if mode == "down": raise urllib.error.URLError("refused")
    if url.endswith("/v1/models"):
        if mode == "models500": raise urllib.error.HTTPError(url, 500, "x", {}, None)
        if mode == "models204": return Reply(204, b"")
        if mode == "badjson": return Reply(200, b"nope")
        if mode == "empty": return Reply(200, b"{\"data\": []}")
        return Reply(200, json.dumps({"data": [{"id": "served-x"}]}).encode())
    if mode == "completion500": raise urllib.error.HTTPError(url, 500, "x", {}, None)
    return Reply(200, b"{}")
urllib.request.urlopen = fake
try:
    exec(compile(sys.argv[1], "probe", "exec"))
finally:
    print(json.dumps(seen), file=sys.stderr)
' "$(adapter_probe_program)" "$1"
}

t_the_probe_program_runs_and_names_the_failing_check_with_its_status() {
  setup_case "$FUNCNAME"
  assert_exit 0 "both checks answer" -- adapter_probe_run ok
  assert_eq "models|completion" "$(echo "$OUT" | tr '\n' '|' | sed 's/|$//')" "models then completion"
  assert_contains "$ERR" '["http://127.0.0.1:8000/v1/models", 5, null]' "check 1: GET /v1/models, 5 s"
  assert_contains "$ERR" '"http://127.0.0.1:8000/v1/completions", 60, {"model": "served-x", "prompt": "Hi", "max_tokens": 1}' "check 2: POST with the first model id, one token, 60 s"
  assert_exit 1 "completion HTTP 500" -- adapter_probe_run completion500
  assert_eq "models|completion: HTTP 500" "$(echo "$OUT" | tr '\n' '|' | sed 's/|$//')" "the status is named"
  assert_exit 1 "models HTTP 500" -- adapter_probe_run models500
  assert_eq "models: HTTP 500" "$OUT" "check 1 failed with its status"
  assert_exit 1 "models answers 204" -- adapter_probe_run models204
  assert_eq "models: HTTP 204" "$OUT" "a status other than 200 is a failure"
  assert_exit 1 "the server is down" -- adapter_probe_run down
  assert_eq "models: URLError" "$OUT" "the exception class"
  assert_exit 1 "models is not JSON" -- adapter_probe_run badjson
  assert_eq "models: JSONDecodeError" "$OUT" "the exception class"
  assert_exit 1 "no model listed" -- adapter_probe_run empty
  assert_eq "models: IndexError" "$OUT" "the exception class"
}

t_t_scale_divides_by_the_time_scale_with_two_decimals() {
  assert_eq "15.00" "$(R9700_TIME_SCALE=1 t_scale 15)" "scale 1"
  assert_eq "15.00" "$(env -u R9700_TIME_SCALE bash -c 'source "$1"; t_scale 15' _ "$REPO/lib/run_guarded.sh")" "the default scale is 1"
  assert_eq "0.15" "$(R9700_TIME_SCALE=100 t_scale 15)" "scale 100"
  assert_eq "12.00" "$(R9700_TIME_SCALE=100 t_scale 1200)" "1200 s becomes 12 s"
  assert_eq "0.33" "$(R9700_TIME_SCALE=3 t_scale 1)" "rounded to two decimals"
  assert_eq "0.01" "$(R9700_TIME_SCALE=1000 t_scale 1)" "never below 0.01: timeout 0 would mean no ceiling"
  assert_eq "0.50" "$(R9700_TIME_SCALE=2 t_scale 1)" "a decimal result"
  assert_eq "0.25" "$(R9700_TIME_SCALE=2 t_scale 0.5)" "a decimal argument"
}

t_t_scale_refuses_a_scale_that_is_not_a_positive_integer() {
  local bad
  for bad in 0 -1 1.5 abc "" 010 "1 2"; do
    R9700_TIME_SCALE="$bad"
    assert_exit 1 "scale [$bad]" -- t_scale 15
    assert_contains "$ERR" "R9700_TIME_SCALE" "[$bad]: the line names the variable"
    assert_eq "" "$OUT" "[$bad]: nothing is printed"
  done
  unset R9700_TIME_SCALE
  assert_exit 2 "no seconds" -- t_scale
  assert_exit 2 "seconds that are not a number" -- t_scale abc
  assert_exit 2 "negative seconds" -- t_scale -5
}

t_the_adapter_refuses_to_run_when_the_ceiling_scale_is_invalid_or_t_ceiling_is_missing() {
  setup_case "$FUNCNAME"
  R9700_CEILING_SCALE=abc
  assert_exit 10 "an invalid ceiling scale" -- wslc_list
  assert_contains "$ERR" "R9700_CEILING_SCALE" "the line names it"
  unset R9700_CEILING_SCALE
  R9700_TIME_SCALE=abc
  assert_exit 10 "no ceiling scale: the time scale decides, and it is invalid" -- wslc_list
  assert_contains "$ERR" "R9700_TIME_SCALE" "the line names it"
  R9700_TIME_SCALE=100
  unset -f t_ceiling
  assert_exit 10 "t_ceiling not loaded" -- wslc_list
  assert_contains "$ERR" "t_ceiling" "the line names it"
  assert_missing "$STUB/calls.log" "no stub was called"
}

t_t_ceiling_follows_the_ceiling_scale_and_defaults_to_the_time_scale() {
  assert_eq "60.00" "$(env -u R9700_TIME_SCALE -u R9700_CEILING_SCALE bash -c 'source "$1"; t_ceiling 60' _ "$REPO/lib/run_guarded.sh")" "no scale at all: 1"
  assert_eq "0.60" "$(R9700_TIME_SCALE=100 t_ceiling 60)" "no ceiling scale: the time scale"
  assert_eq "60.00" "$(R9700_TIME_SCALE=100 R9700_CEILING_SCALE=1 t_ceiling 60)" "the ceiling scale wins; the sleeps keep their own"
  assert_eq "0.60" "$(R9700_TIME_SCALE=1 R9700_CEILING_SCALE=100 t_ceiling 60)" "the other way round"
  assert_eq "0.01" "$(R9700_CEILING_SCALE=100000 t_ceiling 1)" "never below 0.01"
  assert_eq "1.00" "$(R9700_TIME_SCALE=100 R9700_CEILING_SCALE=1 t_scale 100)" "t_scale ignores the ceiling scale"
  local bad
  for bad in 0 -1 1.5 abc "" 010; do
    R9700_CEILING_SCALE="$bad"
    assert_exit 1 "ceiling scale [$bad]" -- t_ceiling 15
    assert_contains "$ERR" "R9700_CEILING_SCALE" "[$bad]: names the variable"
  done
}

# ---- the supervisor's T_STOP cuts every adapter wait (amendment A9) ------------------------------------------------------------------

t_the_ceiling_becomes_the_time_left_before_T_STOP_when_that_is_less() {
  setup_case "$FUNCNAME"
  t_ceiling() { if [ "$1" = 5 ]; then echo 5.00; else echo 60.00; fi; }
  timeout() { echo "$*" >> "$CASE/timeout.args"; command timeout "$@"; }
  R9700_T_STOP="$(( $(date +%s) + 3 ))"
  wslc_list > /dev/null
  local ceiling
  ceiling="$(sed -E 's/^--kill-after=[0-9.]+ ([0-9.]+) .*/\1/' "$CASE/timeout.args")"
  assert_exit 0 "the ceiling [$ceiling] is under 3.01 s and over 1 s, not 60" -- awk -v c="$ceiling" 'BEGIN { exit !(c < 3.01 && c > 1) }'
}

t_a_call_is_cut_at_T_STOP_when_that_is_sooner_than_its_ceiling() {
  setup_case "$FUNCNAME"
  printf 'hang\n' > "$STUB/mode"
  local started ended rc
  R9700_T_STOP="$(( $(date +%s) + 2 ))"
  started="$(date +%s.%N)"
  wslc_list > /dev/null 2>&1
  rc=$?
  ended="$(date +%s.%N)"
  if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then assert_eq ok ok "ended by the cut (rc $rc)"; else assert_eq "124 or 137" "$rc" "ended by the cut"; fi
  assert_exit 0 "after about 2 s, not the 6 s of the ceiling" -- awk -v a="$started" -v b="$ended" 'BEGIN { exit !(b - a < 4.5) }'
  kill_recorded_pids "$CASE"
}

t_a_T_STOP_that_is_later_than_the_ceiling_changes_nothing() {
  setup_case "$FUNCNAME"
  t_ceiling() { if [ "$1" = 5 ]; then echo 5.00; else echo 7.00; fi; }
  timeout() { echo "$*" >> "$CASE/timeout.args"; command timeout "$@"; }
  R9700_T_STOP="$(( $(date +%s) + 100000 ))"
  wslc_list > /dev/null
  assert_contains "$(cat "$CASE/timeout.args")" "--kill-after=5.00 7.00 " "the ceiling is the function's own, 7.00"
}

t_a_call_after_T_STOP_is_refused_before_any_call() {
  setup_case "$FUNCNAME"
  R9700_T_STOP="$(( $(date +%s) - 5 ))"
  assert_exit 10 "wslc_list" -- wslc_list
  assert_contains "$ERR" "adapter: " "an adapter: line"
  assert_contains "$ERR" "T_STOP" "it names the stop time"
  assert_exit 10 "win_ram_mb" -- win_ram_mb
  assert_exit 10 "restore_start" -- restore_start
  R9700_T_STOP="$(date +%s)"
  assert_exit 10 "exactly now is refused too (nothing is left)" -- wslc_list
  assert_missing "$STUB/calls.log" "no stub was called"
}

t_a_T_STOP_that_is_not_an_epoch_second_is_refused() {
  setup_case "$FUNCNAME"
  local bad
  for bad in abc 12.5 -3 "1 2"; do
    R9700_T_STOP="$bad"
    assert_exit 10 "T_STOP [$bad]" -- wslc_list
    assert_contains "$ERR" "R9700_T_STOP \"$bad\" is not an epoch second" "[$bad]: the line says what is wrong"
  done
  R9700_T_STOP=""
  assert_exit 0 "an empty T_STOP means none" -- wslc_list
}

# ---- details of the answers the adapter trusts --------------------------------------------------------------------------------------------

# script_exe <name> <printf format>: an executable under $CASE/bin that prints the format and exits 0
script_exe() {
  mkdir -p "$CASE/bin"
  printf '#!/usr/bin/env bash\nprintf %s\n' "'$2'" > "$CASE/bin/$1"
  chmod +x "$CASE/bin/$1"
  echo "$CASE/bin/$1"
}

t_an_integer_answer_must_be_exactly_one_non_empty_line() {
  setup_case "$FUNCNAME"
  R9700_POWERSHELL="$(script_exe ps-two '100\r\n0\r\n')"
  assert_exit 1 "two lines 100 and 0 are not 1000" -- win_ram_mb
  assert_eq "" "$OUT" "nothing is printed"
  assert_exit 1 "the disk query too" -- win_disk_newest
  R9700_POWERSHELL="$(script_exe ps-inner '1 0\r\n')"
  assert_exit 1 "spaces inside the value" -- win_ram_mb
  R9700_POWERSHELL="$(script_exe ps-blank '\r\n  100 \r\n\r\n')"
  assert_exit 0 "blank lines around one value are fine" -- win_ram_mb
  assert_eq "100" "$OUT" "the value, trimmed around"
  R9700_POWERSHELL="$(script_exe ps-none '\r\n\r\n')"
  assert_exit 1 "no value at all" -- win_ram_mb
}

t_wslc_list_ignores_blank_lines() {
  setup_case "$FUNCNAME"
  R9700_WSLC="$(script_exe wslc-blank 'ID NAME\r\n\r\n0123  a\r\n   \r\n0124  b\r\n\r\n')"
  assert_exit 0 "wslc_list" -- wslc_list
  assert_eq "a|b" "$(echo "$OUT" | tr '\n' '|' | sed 's/|$//')" "two names, no empty line"
}

t_adapter_marker_words_hands_the_two_executables_to_the_recovery_marker() {
  setup_case "$FUNCNAME"
  assert_exit 0 "adapter_marker_words" -- adapter_marker_words
  assert_eq $'WSLC=wslc\nRESTORE_SHELL=pwsh.exe' "$OUT" "the configured values, as KEY=VALUE words"
  R9700_WSLC=/abs/path/wslc
  assert_eq $'WSLC=/abs/path/wslc\nRESTORE_SHELL=pwsh.exe' "$(adapter_marker_words)" "an absolute path as given"
}

t_restore_start_matches_detach_in_any_case() {
  setup_case "$FUNCNAME"
  sed 's/ -Detach"$/ -detach"/' "$CASE/machine.env" > "$CASE/machine2.env"
  config_load "$CASE/machine2.env" "$MODEL_35B" || exit 2
  assert_contains "$R9700_RESTORE_ARGS" "-detach" "the variant has a lower-case switch"
  restore_start > /dev/null
  argv_of pwsh.exe
  assert_eq "-detach" "${ARGV[-1]}" "the operator's spelling is the last argument"
  assert_eq "0" "$(printf '%s\n' "${ARGV[@]}" | grep -cx -- '-Detach')" "no second -Detach was added"
  kill_recorded_pids "$CASE"
}

# ---- E1.S3: wslc_run_once and wslc_argv_text -------------------------------------------------------------------------------------------------------

t_wslc_run_once_runs_in_the_foreground_with_rm_and_hands_every_word_on_as_one_argument() {
  setup_case "$FUNCNAME"
  printf 'a 1\n' > "$STUB/answers/find"
  printf 'g %s\n' "$(printf 'a%.0s' $(seq 1 64))" > "$STUB/answers/genconfig"
  assert_exit 0 "wslc_run_once" -- wslc_run_once 120 --name r9700tune-fp-1 -v 'hf-cache:/root/.cache/huggingface' img sh -c 'echo "$1"; id' sh '/m; touch /tmp/x; #'
  argv_of wslc
  assert_eq 'run|--rm|--name|r9700tune-fp-1|-v|hf-cache:/root/.cache/huggingface|img|sh|-c|echo "$1"; id|sh|/m; touch /tmp/x; #' "$(IFS='|'; echo "${ARGV[*]}")" "run --rm, then the words: the path with its ; and # is ONE element, apart from the program"
  assert_not_contains "$(log_args wslc)" " -d " "not detached"
  assert_not_contains "$OUT" "$CR" "no carriage return in the answer"
  assert_eq "0" "$(wslc_list | wc -l | tr -d ' ')" "no container was started (the stub treats run --rm as a foreground run)"
}

t_wslc_run_once_refuses_a_ceiling_that_is_not_a_positive_integer_and_a_call_without_words() {
  setup_case "$FUNCNAME"
  assert_exit 2 "a ceiling that is not a number" -- wslc_run_once abc img
  assert_contains "$ERR" "wslc_run_once" "names the function"
  assert_exit 2 "a zero ceiling" -- wslc_run_once 0 img
  assert_exit 2 "no ceiling" -- wslc_run_once
  assert_exit 2 "a ceiling and no word" -- wslc_run_once 5
  assert_missing "$STUB/calls.log" "no stub was called"
}

t_wslc_run_once_is_killed_at_its_ceiling_and_leaves_no_process() {
  setup_case "$FUNCNAME"
  printf 'hang\n' > "$STUB/mode"
  R9700_CEILING_SCALE=100
  wslc_run_once 120 img > /dev/null 2>&1
  local rc=$?
  if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then assert_eq ok ok "the ceiling ended it (rc $rc)"; else assert_eq "124 or 137" "$rc" "the ceiling ended it"; fi
  local pid
  read -r pid _ < "$STUB/hung/containers/1.pid"
  assert_exit 0 "the hung stub's sleep is gone" -- gone "$pid"
}

t_wslc_run_once_is_cut_at_T_STOP_like_every_other_call_and_asks_for_its_ceiling_in_seconds() {
  setup_case "$FUNCNAME"
  t_ceiling() { echo "$1" >> "$CASE/ceilings"; echo 1; }
  wslc_run_once 120 img > /dev/null
  assert_eq "5 120" "$(tr '\n' ' ' < "$CASE/ceilings" | sed 's/ $//')" "the grace, then the ceiling the caller gave"
  unset -f t_ceiling
  source "$REPO/lib/run_guarded.sh"
  R9700_T_STOP=$(( $(date +%s) - 5 ))
  assert_exit 10 "a call after T_STOP is refused" -- wslc_run_once 120 img
  assert_contains "$ERR" "adapter:" "by the adapter's own line"
}

t_wslc_argv_text_prints_the_wslc_command_line_a_call_would_run_for_the_dry_run() {
  setup_case "$FUNCNAME"
  assert_eq "wslc run -d --rm --name n img --a b" "$(wslc_argv_text run -d --rm --name n img --a b)" "the program name, then the words joined by single spaces"
  assert_missing "$STUB/calls.log" "nothing was called"
}


# ---- E1.S1: wslc_build, wslc_volume_list, wslc_volume_create (AD1-AD6) -------------------------------------------------------

t_wslc_build_hands_every_word_on_as_one_argument_and_prints_every_line() {
  setup_case "$FUNCNAME"
  local i
  for i in $(seq 1 60); do printf 'build line %s\r\n' "$i"; done > "$STUB/answers/build.log"
  assert_exit 0 "wslc_build returns 0" -- wslc_build 100 -t img:x -f 'X:\a b\Containerfile' --build-arg BASE=b:1 'X:\a b'
  argv_of wslc
  assert_eq "8" "${#ARGV[@]}" "eight words: build, -t, img:x, -f, the file, --build-arg, BASE=b:1, the context"
  assert_eq 'build|-t|img:x|-f|X:\a b\Containerfile|--build-arg|BASE=b:1|X:\a b' "$(IFS='|'; echo "${ARGV[*]}")" "every word is one argument, a space stays inside it"
  assert_eq "60" "$(wc -l <<< "$OUT" | tr -d ' ')" "all 60 lines are printed"
  assert_not_contains "$OUT" "$CR" "no carriage return"
  assert_contains "$OUT" "build line 1" "the first line is there"
  assert_contains "$OUT" "build line 60" "and the last"
}

t_a_failing_build_returns_its_own_code_and_still_prints() {
  setup_case "$FUNCNAME"
  printf '3\n' > "$STUB/answers/build_rc"
  assert_exit 3 "wslc_build returns the code of the build" -- wslc_build 100 -t img:x .
  assert_contains "$OUT" "stub build line 1" "and prints the log"
}

t_wslc_build_refuses_a_bad_ceiling_or_no_words_before_any_call() {
  setup_case "$FUNCNAME"
  assert_exit 2 "a ceiling that is not a number" -- wslc_build x -t a
  assert_eq "1" "$(grep -c '^wslc_build:' <<< "$ERR")" "one wslc_build: line"
  assert_exit 2 "a zero ceiling" -- wslc_build 0 -t a
  assert_eq "1" "$(grep -c '^wslc_build:' <<< "$ERR")" "one wslc_build: line"
  assert_exit 2 "a ceiling and no word" -- wslc_build 100
  assert_eq "1" "$(grep -c '^wslc_build:' <<< "$ERR")" "one wslc_build: line"
  assert_exit 2 "nothing" -- wslc_build
  assert_missing "$STUB/calls.log" "no stub was called, so calls.log holds no build line"
}

t_a_hung_build_is_killed_at_its_ceiling_and_leaves_no_process() {
  setup_case "$FUNCNAME"
  printf 'hang\n' > "$STUB/mode"
  R9700_CEILING_SCALE=100
  wslc_build 120 -t img:x . > /dev/null 2>&1
  local rc=$?
  if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then assert_eq ok ok "the ceiling ended it (rc $rc)"; else assert_eq "124 or 137" "$rc" "the ceiling ended it"; fi
  local pid
  read -r pid _ < "$STUB/hung/containers/1.pid"
  assert_exit 0 "the hung stub's sleep is gone" -- gone "$pid"
}

t_wslc_volume_list_prints_the_names_one_per_line() {
  setup_case "$FUNCNAME"
  mkdir -p "$STUB/volumes"
  assert_exit 0 "no volume" -- wslc_volume_list
  assert_eq "" "$OUT" "prints nothing"
  : > "$STUB/volumes/comfy-models"
  : > "$STUB/volumes/comfy-data"
  assert_exit 0 "two volumes" -- wslc_volume_list
  assert_eq "comfy-data|comfy-models" "$(tr '\n' '|' <<< "$OUT" | sed 's/|$//')" "their names, in the stub's order, without the header"
  assert_not_contains "$OUT" "$CR" "no carriage return"
  printf '1\n' > "$STUB/fail-volume-list"
  assert_exit 1 "a failing list returns non-zero" -- wslc_volume_list
  assert_eq "" "$OUT" "and prints nothing on stdout"
}

t_wslc_volume_create_creates_exactly_the_named_volume() {
  setup_case "$FUNCNAME"
  assert_exit 2 "an option for a name" -- wslc_volume_create -x
  assert_contains "$ERR" "wslc_volume_create" "names the function"
  assert_contains "$ERR" "volume name" "and the kind of name"
  assert_eq "1" "$(grep -c . <<< "$ERR")" "in one line"
  assert_exit 2 "an empty name" -- wslc_volume_create ''
  assert_contains "$ERR" "volume name" "says volume name"
  assert_exit 2 "a name with a space" -- wslc_volume_create 'a b'
  assert_contains "$ERR" "volume name" "says volume name"
  assert_exit 2 "no name" -- wslc_volume_create
  assert_missing "$STUB/calls.log" "no call was made"
  assert_exit 0 "create comfy-cache" -- wslc_volume_create comfy-cache
  argv_of wslc
  assert_eq "volume|create|comfy-cache" "$(IFS='|'; echo "${ARGV[*]}")" "the call is volume create <name>"
  assert_eq "comfy-cache" "$(wslc_volume_list)" "and the list holds it"
  printf '1\n' > "$STUB/answers/volume_create_rc"
  assert_exit 1 "a failing create returns the code" -- wslc_volume_create other
  assert_contains "$OUT" "stub: volume create failed (scripted)" "and prints the line of the stub"
}

run_all_tests
