#!/usr/bin/env bash
# The adapter seam (lib/adapter.sh) and t_scale (lib/run_guarded.sh): E1.S2 part (a), scenarios A2-A5 and A7, ceilings, refusals.
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
  assert_exit 0 "restore_start" -- restore_start
  assert_not_contains "$OUT" "$CR" "restore_start: no CR"
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

t_a_hung_adapter_call_is_killed_at_its_ceiling_and_leaves_no_process() {
  setup_case "$FUNCNAME"
  printf 'hang\n' > "$STUB/mode"
  R9700_CEILING_SCALE=100 # every call must end at its ceiling: the shortest is the point here
  local started ended name file pid rc
  started="$(date +%s.%N)"
  for name in "wslc_list" "wslc_stop r9700tune-a" "wslc_logs r9700tune-a" "wslc_run r9700tune-a img" "wslc_exec 70 vllm true" "restore_probe vllm" "win_ram_mb" "win_disk_newest" "restore_start"; do
    $name > /dev/null 2>&1
    rc=$?
    if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then assert_eq ok ok "$name: the ceiling ended it (rc $rc)"; else assert_eq "124 or 137" "$rc" "$name: the ceiling ended it"; fi
  done
  ended="$(date +%s.%N)"
  assert_exit 0 "the nine calls took under 8 s (a ceiling scale of 100 turns 60..120 s into under 2 s each)" -- awk -v a="$started" -v b="$ended" 'BEGIN { exit !(b - a < 8) }'
  local n=0
  for file in "$STUB"/hung/containers/*.pid; do
    [ -e "$file" ] || continue # nothing was recorded: the count below says so, the loop must not crash
    n=$((n + 1))
    read -r pid _ < "$file"
    assert_exit 0 "the hung stub's sleep (pid file $n) is gone" -- gone "$pid"
  done
  assert_eq "9" "$n" "nine hung stubs were recorded"
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
  wslc_stop r9700tune-a
  win_ram_mb > /dev/null
  win_disk_newest > /dev/null
  restore_start > /dev/null
  restore_probe vllm > /dev/null
  assert_missing "$CASE/sleeps" "t_scale (the sleeps' scale) was never asked for a ceiling"
  # every call asks for the kill-after grace (5) and then its ceiling
  assert_eq "5 120 5 33 5 60 5 60 5 60 5 30 5 60 5 120 5 70" "$(tr '\n' ' ' < "$CASE/ceilings" | sed 's/ $//')" "run 120, exec the argument, list 60, stop 60, logs 60, ram 30, disk 60, restore_start 120, probe 70 through exec"
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
  # (INT cannot be trapped here: a shell started as a background job has it ignored from the start, and keeps it ignored through both calls)
  nested_supervisor "trap 'echo hup' HUP; trap 'rm -f \"$STUB/mode\"; wslc_stop r9700tune-b; echo nested-done > \"$CASE/nested\"' TERM; wslc_stop r9700tune-a; trap -p HUP INT TERM > \"$CASE/traps\"; : > \"$CASE/end\""
  for i in $(seq 1 100); do [ -f "$STUB/hung/containers/1.pid" ] && break; sleep 0.1; done
  kill -TERM "$SUP" # the handler removes the hang mode, so its own call returns at once; then the handler returns and the script goes on
  for i in $(seq 1 100); do [ -f "$CASE/end" ] && break; sleep 0.1; done
  assert_exit 0 "the handler's nested call returned and the script went on" -- test -f "$CASE/nested"
  assert_eq "trap -- 'echo hup' SIGHUP
trap -- '' SIGINT
trap -- 'rm -f \"$STUB/mode\"; wslc_stop r9700tune-b; echo nested-done > \"$CASE/nested\"' SIGTERM" "$(cat "$CASE/traps" 2> /dev/null)" "the traps are the caller's own, none is a hook of the adapter"
  kill -KILL "$SUP" 2> /dev/null
  kill_recorded_pids "$CASE"
}

t_a_nested_call_in_a_handler_leaves_an_ignored_signal_ignored() {
  setup_case "$FUNCNAME"
  export R9700_STATE_DIR="$CASE/state" R9700_CEILING_SCALE=1
  printf 'hang\n' > "$STUB/mode"
  local i
  nested_supervisor "trap '' INT; trap 'rm -f \"$STUB/mode\"; wslc_stop r9700tune-b' TERM; wslc_stop r9700tune-a; trap -p INT > \"$CASE/traps\"; : > \"$CASE/end\""
  for i in $(seq 1 100); do [ -f "$STUB/hung/containers/1.pid" ] && break; sleep 0.1; done
  kill -TERM "$SUP"
  for i in $(seq 1 100); do [ -f "$CASE/end" ] && break; sleep 0.1; done
  assert_eq "trap -- '' SIGINT" "$(cat "$CASE/traps" 2> /dev/null)" "INT is still ignored after both calls"
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
    wslc_stop r9700tune-a )
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

run_all_tests
