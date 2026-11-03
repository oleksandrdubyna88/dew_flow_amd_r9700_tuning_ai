#!/usr/bin/env bash
# The functions of the supervisor's step engine (E1.S2 part (c)) one by one, through the libraries and not through bin/r9700: the outcome
# file, the deadline arithmetic, the supervisor log, the run folder, the quiet check, the disk gate, the guards. The scenarios of the story
# that drive the whole `step` verb are in tests/test_lifecycle.sh and tests/test_guards.sh. Every test body is a function t_<guarantee>; each
# runs in its own subshell and writes only below $R9700_TEST_ROOT.
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

# ---- the outcome file: the first writer wins ---------------------------------------------------------------------------------------------------

t_outcome_write_creates_the_file_with_the_four_lines_and_a_utc_end_time() {
  lc_setup "$FUNCNAME"
  local f="$CASE/o1"
  assert_exit 0 "the first writer" -- outcome_write "$f" KIND=worker RC=0 DETAIL=0
  assert_eq "KIND=worker" "$(sed -n 1p "$f")" "line 1 is the kind"
  assert_eq "RC=0" "$(sed -n 2p "$f")" "line 2 is the code"
  assert_eq "DETAIL=0" "$(sed -n 3p "$f")" "line 3 is the detail"
  if [[ "$(sed -n 4p "$f")" =~ ^ENDED_AT=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then assert_eq ok ok "line 4 is ENDED_AT in UTC"; else assert_eq "ENDED_AT=<UTC>" "$(sed -n 4p "$f")" "line 4 is ENDED_AT in UTC"; fi
  assert_eq "4" "$(wc -l < "$f" | tr -d ' ')" "and nothing else"
}

t_outcome_write_leaves_a_file_that_already_exists_as_it_is_and_says_so() {
  lc_setup "$FUNCNAME"
  local f="$CASE/o2"
  outcome_write "$f" KIND=ram_guard "DETAIL=available 100 MB < 2048 MB"
  assert_exit 1 "the second writer" -- outcome_write "$f" KIND=worker RC=143 DETAIL=143
  assert_eq "KIND=ram_guard" "$(sed -n 1p "$f")" "the first writer's kind stays"
  assert_eq "RC=" "$(sed -n 2p "$f")" "an RC that was not given is empty"
  assert_eq "DETAIL=available 100 MB < 2048 MB" "$(sed -n 3p "$f")" "and its detail"
  assert_eq "o2" "$(ls "$CASE" | grep '^o2')" "no part file is left beside it"
}

t_outcome_write_refuses_a_kind_a_key_or_a_value_it_cannot_store() {
  lc_setup "$FUNCNAME"
  local f="$CASE/o3"
  assert_exit 2 "an unknown kind" -- outcome_write "$f" KIND=nosuch
  assert_contains "$ERR" "outcome:" "one outcome: line"
  assert_contains "$ERR" "worker" "naming the legal kinds"
  assert_exit 2 "an unknown key" -- outcome_write "$f" KIND=worker EXTRA=1
  assert_exit 2 "no kind at all" -- outcome_write "$f" RC=1
  assert_exit 2 "a code that is not a number" -- outcome_write "$f" KIND=worker RC=x
  assert_missing "$f" "nothing was written"
  assert_exit 0 "a detail with a line break is one line" -- outcome_write "$f" KIND=worker RC=1 $'DETAIL=a\nb'
  assert_eq "DETAIL=a b" "$(sed -n 3p "$f")" "the break became a space"
}

t_outcome_read_sets_the_four_variables_and_refuses_a_file_it_cannot_trust() {
  lc_setup "$FUNCNAME"
  local f="$CASE/o4"
  outcome_write "$f" KIND=disk_gate RC=1 "DETAIL=STOP: query failed"
  outcome_read "$f"
  assert_eq "disk_gate" "$O_KIND" "O_KIND"
  assert_eq "1" "$O_RC" "O_RC"
  assert_eq "STOP: query failed" "$O_DETAIL" "O_DETAIL"
  assert_contains "$O_ENDED_AT" "Z" "O_ENDED_AT"
  assert_exit 2 "a missing file" -- outcome_read "$CASE/nofile"
  assert_contains "$ERR" "outcome: $CASE/nofile" "named"
  printf 'KIND=bogus\n' > "$CASE/o5"
  assert_exit 2 "an unknown kind" -- outcome_read "$CASE/o5"
  assert_contains "$ERR" "outcome: $CASE/o5:1:" "naming the line"
  printf 'KIND=worker\nWHAT=1\n' > "$CASE/o6"
  assert_exit 2 "an unknown key" -- outcome_read "$CASE/o6"
  : > "$CASE/o7"
  assert_exit 2 "an empty file (a writer that is not done)" -- outcome_read "$CASE/o7"
}

# ---- the deadline arithmetic (decision 8) as pure functions --------------------------------------------------------------------------------------

t_deadline_calc_without_a_clock_time_is_now_plus_the_run_minutes_and_the_stop_keeps_the_budget() {
  lc_setup "$FUNCNAME"
  export R9700_TIME_SCALE=1
  assert_eq "1000.00 760.00" "$(deadline_calc 400 "" 10 240)" "T_END = now + 600, T_STOP = T_END - 240"
}

t_deadline_calc_divides_the_durations_by_the_time_scale() {
  lc_setup "$FUNCNAME"
  export R9700_TIME_SCALE=100
  assert_eq "406.00 402.40" "$(deadline_calc 400 "" 10 360)" "600 s / 100 = 6 s; 360 s / 100 = 3.6 s"
}

t_deadline_calc_takes_the_sooner_of_the_clock_time_and_the_run_minutes() {
  lc_setup "$FUNCNAME"
  export R9700_TIME_SCALE=1
  local now soon out
  now="$(date +%s)"
  soon="$(date -d "@$((now + 120))" +%H:%M)"
  out="$(deadline_calc "$now" "$soon" 2880 900)"
  set -- $out
  # the clock time has no seconds: it is the start of that minute, 0 to 60 s before now + 120
  if awk -v e="$1" -v n="$now" 'BEGIN { exit !(e - n > 55 && e - n <= 120) }'; then assert_eq ok ok "T_END is the next occurrence of the clock time (within 120 s)"; else assert_eq "within 55..120 s of now" "$(awk -v e="$1" -v n="$now" 'BEGIN { print e - n }')" "T_END is the next occurrence of the clock time"; fi
  out="$(deadline_calc "$now" "$soon" 1 0)"
  set -- $out
  assert_eq "$((now + 60)).00" "$1" "with MAX_RUN_MINUTES=1 the sooner term wins"
}

t_deadline_calc_for_a_clock_time_that_has_passed_is_the_next_day() {
  lc_setup "$FUNCNAME"
  export R9700_TIME_SCALE=1
  local now past out
  now="$(date +%s)"
  past="$(date -d "@$((now - 120))" +%H:%M)"
  out="$(deadline_calc "$now" "$past" 2880 900)"
  set -- $out
  if awk -v e="$1" -v n="$now" 'BEGIN { exit !(e - n > 86400 - 180 - 60 && e - n <= 86400) }'; then assert_eq ok ok "T_END is tomorrow's occurrence (24 h - 2 min, give or take the minute)"; else assert_eq "about 86280 s" "$(awk -v e="$1" -v n="$now" 'BEGIN { print e - n }')" "T_END is tomorrow's occurrence"; fi
}

t_deadline_compute_sets_whole_second_stop_times_and_exports_the_adapters_stop_time() {
  lc_setup "$FUNCNAME"
  export R9700_TIME_SCALE=1
  unset R9700_T_STOP
  local before
  before="$(date +%s)"
  assert_exit 0 "deadline_compute with the fixture's defaults" -- deadline_compute
  deadline_compute
  assert_eq "$((T_END - T_STOP))" "1565" "T_END - T_STOP is CLEANUP_BUDGET_S (1565: E2.S2 decision 6)"
  if [[ $T_END =~ ^[0-9]+$ && $T_STOP =~ ^[0-9]+$ ]]; then assert_eq ok ok "both are whole seconds"; else assert_eq "digits" "$T_END $T_STOP" "both are whole seconds"; fi
  assert_eq "$T_STOP" "$R9700_T_STOP" "R9700_T_STOP is T_STOP, for the adapter"
  assert_exit 0 "and it is exported" -- bash -c 'test -n "$R9700_T_STOP"'
  if [ "$T_END" -ge $((before + 720 * 60 - 2)) ] && [ "$T_END" -le $((before + 720 * 60 + 2)) ]; then assert_eq ok ok "T_END is about MAX_RUN_MINUTES (720) from now"; else assert_eq "$((before + 43200))" "$T_END" "T_END is about MAX_RUN_MINUTES from now"; fi
}

t_deadline_compute_refuses_a_run_that_leaves_less_than_a_minute_before_the_budget() {
  lc_setup "$FUNCNAME"
  export R9700_TIME_SCALE=1
  R9700_MAX_RUN_MINUTES=10 R9700_CLEANUP_BUDGET_S=3600
  assert_exit 2 "10 minutes with a 3600 s budget" -- deadline_compute
  assert_eq "deadline: only -3000 s remain before the cleanup budget" "$ERR" "one line, with the computed number"
  R9700_MAX_RUN_MINUTES=10 R9700_CLEANUP_BUDGET_S=545
  assert_exit 2 "55 s before the budget is under the 60 s floor" -- deadline_compute
  assert_contains "$ERR" "deadline: only 55 s remain before the cleanup budget" "the number is the computed one"
  R9700_MAX_RUN_MINUTES=10 R9700_CLEANUP_BUDGET_S=540
  assert_exit 0 "exactly 60 s is enough" -- deadline_compute
}

t_deadline_compute_reports_the_remaining_seconds_in_production_seconds_under_a_scale() {
  lc_setup "$FUNCNAME"
  export R9700_TIME_SCALE=100
  R9700_MAX_RUN_MINUTES=10 R9700_CLEANUP_BUDGET_S=3600
  assert_exit 2 "10 minutes, 3600 s budget, scale 100" -- deadline_compute
  assert_eq "deadline: only -3000 s remain before the cleanup budget" "$ERR" "the same number as without the scale"
}

# ---- the supervisor log and the run folder -----------------------------------------------------------------------------------------------------------

t_rg_log_goes_to_stdout_and_to_the_supervisor_log_and_rg_err_to_stderr_and_the_log() {
  lc_setup "$FUNCNAME"
  RUN_DIR="$CASE/run"
  mkdir -p "$RUN_DIR"
  assert_exit 0 "rg_log" -- rg_log "admitted"
  assert_contains "$OUT" " admitted" "stdout has the line"
  assert_exit 0 "rg_err" -- rg_err "r9700: something"
  assert_eq "r9700: something" "$ERR" "stderr has exactly the text"
  assert_eq "2" "$(wc -l < "$RUN_DIR/supervisor.log" | tr -d ' ')" "the log holds both"
  assert_contains "$(sed -n 1p "$RUN_DIR/supervisor.log")" " admitted" "in order, the first"
  assert_contains "$(sed -n 2p "$RUN_DIR/supervisor.log")" "r9700: something" "and the second"
  RUN_DIR=""
  assert_exit 0 "without a run folder rg_log still prints" -- rg_log "early"
  assert_contains "$OUT" "early" "to stdout"
}

t_run_dir_new_makes_the_folder_with_its_subfolders_the_log_and_the_running_status() {
  lc_setup "$FUNCNAME"
  run_dir_new
  if [[ $RUN_ID =~ ^[0-9]{8}T[0-9]{6}Z-[0-9]+$ ]]; then assert_eq ok ok "RUN_ID is <UTC stamp>-<pid>"; else assert_eq "<yyyymmddThhmmssZ>-<pid>" "$RUN_ID" "RUN_ID is <UTC stamp>-<pid>"; fi
  assert_eq "$R9700_RESULTS_DIR/runs/$RUN_ID" "$RUN_DIR" "RUN_DIR is RESULTS_DIR/runs/<run id>"
  assert_exit 0 "steps/" -- test -d "$RUN_DIR/steps"
  assert_exit 0 "guard/" -- test -d "$RUN_DIR/guard"
  assert_exit 0 "supervisor.log" -- test -f "$RUN_DIR/supervisor.log"
  assert_eq "running" "$(cat "$RUN_DIR/status")" "the status is running until the run ends"
  assert_eq "$R9700_STATE_DIR/recovery.env" "$MARKER_FILE" "MARKER_FILE is the state directory's marker"
}

t_run_dir_new_never_reuses_a_folder() {
  lc_setup "$FUNCNAME"
  local first
  run_dir_new
  first="$RUN_DIR"
  run_dir_new
  if [ "$first" != "$RUN_DIR" ]; then assert_eq ok ok "two calls in one second make two folders"; else assert_eq "different" "$RUN_DIR" "two calls in one second make two folders"; fi
  assert_exit 0 "and the first is intact" -- test -f "$first/status"
}

t_run_dir_new_refuses_a_results_folder_it_cannot_write() {
  lc_setup "$FUNCNAME"
  : > "$CASE/afile"
  R9700_RESULTS_DIR="$CASE/afile"
  assert_exit 2 "RESULTS_DIR is a file" -- run_dir_new
  assert_contains "$ERR" "r9700: the run folder cannot be made under $CASE/afile" "one line, naming it"
}

# ---- the quiet check and the quiet wait (decision 7, A3) -------------------------------------------------------------------------------------------

# busy <name> [<command line words>]: a process whose command line is the given words (exec -a); sets BUSY
busy() {
  ( exec -a "$1" sleep 1000 ) < /dev/null > /dev/null 2>&1 &
  BUSY=$!
  disown "$BUSY"
  guard_pid "$BUSY" "busy-$BUSY"
}

t_quiet_check_prints_the_counts_and_returns_0_when_the_load_is_low_and_no_busy_process_runs() {
  step_setup "$FUNCNAME"
  assert_exit 0 "a low load and no pattern" -- quiet_check
  assert_eq "coai-exp processes=0 load=0.50" "$OUT" "the line is the old wait_quiet.sh line"
  set_load 3.99
  assert_exit 0 "a load just under the limit (QUIET_LOAD_MAX is 4)" -- quiet_check
  set_load 4.00
  assert_exit 1 "a load at the limit is not quiet" -- quiet_check
  assert_eq "coai-exp processes=0 load=4.00" "$OUT" "and the line says so"
}

t_quiet_check_counts_a_busy_process_by_the_configured_pattern_and_skips_an_ignored_one() {
  step_setup "$FUNCNAME"
  R9700_QUIET_BUSY_PATTERN=r9700-busy-marker
  assert_exit 0 "the pattern matches nothing" -- quiet_check
  busy r9700-busy-marker
  assert_exit 1 "a process with the pattern in its command line" -- quiet_check
  assert_eq "coai-exp processes=1 load=0.50" "$OUT" "is counted"
  R9700_QUIET_BUSY_IGNORE=keep-awake
  assert_exit 1 "the ignore text is not in its command line" -- quiet_check
  kill -KILL "$BUSY"
  gone "$BUSY"
  busy "r9700-busy-marker keep-awake"
  assert_exit 0 "a match whose command line holds the ignore text is not counted" -- quiet_check
  assert_eq "coai-exp processes=0 load=0.50" "$OUT" "processes=0"
  kill -KILL "$BUSY"
}

t_quiet_check_fails_closed_on_an_unreadable_load_or_a_missing_pgrep() {
  step_setup "$FUNCNAME"
  R9700_LOADAVG_FILE="$CASE/nofile"
  assert_exit 1 "a load file that is not there" -- quiet_check
  assert_eq "load unreadable: not quiet" "$OUT" "says so"
  printf 'garbage\n' > "$CASE/loadavg"
  R9700_LOADAVG_FILE="$CASE/loadavg"
  assert_exit 1 "a load that is not a number" -- quiet_check
  assert_eq "load unreadable: not quiet" "$OUT" "the same line"
  set_load 0.1
  R9700_QUIET_BUSY_PATTERN=x
  mkdir "$CASE/nopgrep"
  ln -s "$(command -v awk)" "$CASE/nopgrep/awk"
  local out rc
  out="$(PATH="$CASE/nopgrep" quiet_check)"
  rc=$?
  assert_eq "1" "$rc" "a pattern is set and pgrep is not on PATH: not quiet"
  assert_eq "load unreadable: not quiet" "$out" "the same line again"
}

t_quiet_wait_returns_0_at_the_first_quiet_check_when_one_is_asked_for() {
  step_setup "$FUNCNAME"
  assert_exit 0 "quiet_wait 900 with R9700_QUIET_CHECKS=1" -- quiet_wait 900
  assert_contains "$OUT" "quiet-checks=1/1" "the check line"
  assert_not_contains "$OUT" "next check" "a quiet verdict has no next check"
  assert_contains "$OUT" "QUIET" "and the verdict"
}

t_quiet_wait_ends_at_its_ceiling_when_the_pc_never_gets_quiet() {
  step_setup "$FUNCNAME"
  export R9700_TIME_SCALE=1000 # a tick is 0.3 s, the ceiling 0.9 s
  set_load 9.0
  local start end
  start="$(date +%s.%N)"
  assert_exit 1 "quiet_wait 900 on a busy PC" -- quiet_wait 900
  end="$(date +%s.%N)"
  if awk -v a="$start" -v b="$end" 'BEGIN { exit !(b - a >= 0.85 && b - a < 3) }'; then assert_eq ok ok "it took the ceiling (0.9 s), not more"; else assert_eq "0.85..3 s" "$(awk -v a="$start" -v b="$end" 'BEGIN { print b - a }')" "it took the ceiling"; fi
  assert_contains "$OUT" "quiet-checks=0/1" "the checks were made and counted as 0"
  assert_contains "$(sed -n 1p <<< "$OUT")" "quiet-checks=0/1 next check in 300 s" "the check line says when the next check is (production seconds, whatever the scale)"
  assert_not_contains "$(tail -n 1 <<< "$OUT")" "next check" "the last check, at the ceiling, has no next one"
  assert_not_contains "$OUT" "QUIET" "no quiet verdict"
}

t_quiet_wait_needs_the_asked_number_of_quiet_reads_in_a_row() {
  step_setup "$FUNCNAME"
  export R9700_TIME_SCALE=150 R9700_QUIET_CHECKS=3 # a tick is 2 s
  RUN_DIR="$CASE/run"
  mkdir -p "$RUN_DIR"
  : > "$RUN_DIR/supervisor.log"
  set_load 0.5
  # the helper writes the next load after each check line of the log, a second before the next check
  (
    local values=(0.5 9.0 0.5 0.5 0.5) v
    for v in "${values[@]}"; do
      for _ in $(seq 1 200); do [ "$(grep -c 'quiet-checks=' "$RUN_DIR/supervisor.log")" -ge "$((${n:-0} + 1))" ] && break; sleep 0.02; done
      n=$((${n:-0} + 1))
      set_load "$v"
    done
  ) &
  guard_pid "$!" helper
  assert_exit 0 "quiet_wait 4500 (30 s)" -- quiet_wait 4500
  local counts
  counts="$(grep -o 'quiet-checks=[0-9]/3' "$RUN_DIR/supervisor.log" | tr '\n' ' ')"
  assert_eq "quiet-checks=1/3 quiet-checks=2/3 quiet-checks=0/3 quiet-checks=1/3 quiet-checks=2/3 quiet-checks=3/3 " "$counts" "1, 2, then the busy read resets to 0, then 1, 2, 3"
}

t_quiet_wait_refuses_a_check_count_or_a_ceiling_it_cannot_use() {
  step_setup "$FUNCNAME"
  R9700_QUIET_CHECKS=0
  assert_exit 2 "R9700_QUIET_CHECKS=0" -- quiet_wait 900
  assert_contains "$ERR" "R9700_QUIET_CHECKS" "naming the knob"
  R9700_QUIET_CHECKS=abc
  assert_exit 2 "R9700_QUIET_CHECKS=abc" -- quiet_wait 900
  R9700_QUIET_CHECKS=1
  assert_exit 2 "a ceiling that is not a number" -- quiet_wait x
  assert_contains "$ERR" "quiet_wait" "named"
}

# ---- the disk gate (decision 13 of the old script, lib/disk_gate.sh) -----------------------------------------------------------------------------

t_disk_gate_decide_has_the_four_cases_with_their_exact_strings() {
  lc_setup "$FUNCNAME"
  assert_exit 1 "a newer record" -- disk_gate_decide 100 101
  assert_eq "STOP: new disk event (record 101 > baseline 100)" "$OUT" "the new-event line"
  assert_exit 0 "the same record" -- disk_gate_decide 100 100
  assert_eq "OK: no new disk event (newest 100)" "$OUT" "the ok line"
  assert_exit 2 "an empty answer" -- disk_gate_decide 100 ""
  assert_eq "STOP: query failed" "$OUT" "the failed-query line"
  assert_exit 2 "an older record (the log was reset)" -- disk_gate_decide 100 99
  assert_eq "STOP: log reset (newest 99 < baseline 100)" "$OUT" "the reset line"
  assert_exit 2 "an answer that is not a number" -- disk_gate_decide 100 abc
  assert_eq "STOP: query failed" "$OUT" "is a failed query"
}

t_disk_gate_baseline_records_the_newest_record_in_the_given_state_file() {
  lc_setup "$FUNCNAME"
  printf '4711\n' > "$STUB/answers/disk"
  assert_exit 0 "baseline" -- disk_gate_baseline "$CASE/disk.state"
  assert_eq "baseline 4711" "$OUT" "prints what it recorded"
  assert_eq "4711" "$(cat "$CASE/disk.state")" "the state file holds the record"
  assert_eq "1" "$(log_count powershell.exe -Command)" "one PowerShell call"
}

t_disk_gate_baseline_that_cannot_read_the_log_stops_and_writes_no_state() {
  lc_setup "$FUNCNAME"
  printf 'garbage\n' > "$STUB/answers/disk"
  assert_exit 2 "baseline on an unreadable answer" -- disk_gate_baseline "$CASE/disk.state"
  assert_eq "STOP: query failed" "$OUT" "the line"
  assert_missing "$CASE/disk.state" "no state file"
}

t_disk_gate_check_compares_the_newest_record_with_the_baseline() {
  lc_setup "$FUNCNAME"
  printf '100\n100\n101\n\n' > "$STUB/answers/disk"
  disk_gate_baseline "$CASE/disk.state" > /dev/null
  assert_exit 0 "no new event" -- disk_gate_check "$CASE/disk.state"
  assert_eq "OK: no new disk event (newest 100)" "$OUT" "ok"
  assert_exit 1 "a new event" -- disk_gate_check "$CASE/disk.state"
  assert_eq "STOP: new disk event (record 101 > baseline 100)" "$OUT" "the line"
  assert_exit 2 "an empty answer: the query failed" -- disk_gate_check "$CASE/disk.state"
  assert_eq "STOP: query failed" "$OUT" "the line"
}

t_disk_gate_check_without_a_baseline_stops_and_says_so() {
  lc_setup "$FUNCNAME"
  assert_exit 2 "check with no state file" -- disk_gate_check "$CASE/none.state"
  assert_eq "STOP: baseline missing ($CASE/none.state)" "$OUT" "the line names the file"
  assert_missing "$STUB/calls.log" "and no call was made"
  printf 'abc\n' > "$CASE/bad.state"
  assert_exit 2 "a state file that is not a number" -- disk_gate_check "$CASE/bad.state"
  assert_contains "$OUT" "STOP: baseline missing" "is a missing baseline too"
}

t_disk_gate_off_prints_one_line_and_makes_no_call() {
  lc_setup "$FUNCNAME"
  R9700_DISK_GATE=off
  assert_exit 0 "baseline with the gate off" -- disk_gate_baseline "$CASE/disk.state"
  assert_eq "disk gate off" "$OUT" "the line"
  assert_exit 0 "check with the gate off" -- disk_gate_check "$CASE/disk.state"
  assert_eq "disk gate off" "$OUT" "the same line"
  assert_missing "$STUB/calls.log" "no PowerShell call was made"
  assert_missing "$CASE/disk.state" "and no state file"
}

# ---- the RAM guard (decision 7, A8) ---------------------------------------------------------------------------------------------------------------------

# guard_start <min mb>: guard_ram in the background for the fixture session; sets GUARD
guard_start() {
  guard_ram "$SID" "$1" "$OUTCOME" "$GLOG" &
  GUARD=$!
  guard_pid "$GUARD" "guard-$GUARD"
}

t_guard_ram_below_the_limit_writes_the_outcome_stops_the_containers_then_the_whole_session() {
  step_setup "$FUNCNAME"
  guard_dirs
  session_fixture
  stub_container r9700tune-a
  printf '100\n' > "$STUB/answers/ram"
  local members
  members="$(session_pids "$SID" | tr '\n' ' ')"
  guard_start 2048
  wait "$GUARD"
  assert_eq "1" "$?" "the guard ends with 1 after it fired"
  outcome_read "$OUTCOME"
  assert_eq "ram_guard" "$O_KIND" "KIND=ram_guard"
  assert_eq "available 100 MB < 2048 MB" "$O_DETAIL" "the detail names both numbers"
  assert_eq "" "$(session_pids "$SID" | tr -d '\n')" "no process of the worker session is left (A8)"
  assert_missing "$STUB/containers/r9700tune-a.pid" "the prefixed container is stopped"
  assert_eq "1" "$(ls "$RUN_DIR/guard" | grep -c 'r9700tune-a.tail.log$')" "its log tail was saved"
  assert_contains "$(cat "$GLOG")" "ram_guard" "the guard log says why"
}

t_guard_ram_stops_the_containers_before_it_sends_term() {
  step_setup "$FUNCNAME"
  guard_dirs
  session_fixture
  stub_container r9700tune-a
  printf '100\n' > "$STUB/answers/ram"
  guard_start 2048
  wait "$GUARD"
  local stop_at gone_at
  stop_at="$(awk '$3 == "wslc" && $4 == "stop" { print $1 }' "$STUB/calls.log" | head -n 1)"
  assert_exit 0 "the stop call is in the call log" -- test -n "$stop_at"
  assert_eq "1" "$(grep -c 'wslc logs r9700tune-a' "$STUB/calls.log")" "the log was read"
  assert_exit 0 "and read BEFORE the stop" -- awk '$3 == "wslc" && $4 == "logs" { l = NR } $3 == "wslc" && $4 == "stop" { s = NR } END { exit !(l && s && l < s) }' "$STUB/calls.log"
}

t_guard_ram_at_the_limit_is_fine_and_it_ends_by_itself_when_the_worker_is_gone() {
  step_setup "$FUNCNAME"
  guard_dirs
  session_fixture
  printf '2048\n' > "$STUB/answers/ram"
  guard_start 2048
  sleep 0.6
  assert_exit 0 "the guard is still reading at exactly the limit" -- kill -0 "$GUARD"
  assert_missing "$OUTCOME" "no outcome"
  assert_eq "1" "$(session_pids "$SID" | wc -l | awk '{ print ($1 >= 2) }')" "the session is untouched"
  kill -KILL "$SID"
  session_stop "$SID"
  wait "$GUARD"
  assert_eq "0" "$?" "when the worker's leader is gone the guard ends with 0"
  assert_missing "$OUTCOME" "and wrote no outcome"
}

t_guard_ram_one_unreadable_read_is_a_miss_and_three_in_a_row_are_unsafe() {
  step_setup "$FUNCNAME"
  guard_dirs
  session_fixture
  printf '8000\ngarbage\n8000\ngarbage\ngarbage\ngarbage\n' > "$STUB/answers/ram"
  guard_start 2048
  wait "$GUARD"
  assert_eq "1" "$?" "it fired"
  outcome_read "$OUTCOME"
  assert_eq "ram_guard" "$O_KIND" "KIND=ram_guard"
  assert_eq "telemetry unreadable 3 times" "$O_DETAIL" "the detail"
  assert_eq "6" "$(cat "$STUB/counters/answer-ram")" "the sixth read was the last"
  assert_eq "telemetry unreadable (1 of 3)
telemetry unreadable (1 of 3)
telemetry unreadable (2 of 3)
telemetry unreadable (3 of 3)" "$(grep -o 'telemetry unreadable ([0-9] of 3)' "$GLOG")" "one miss, a good read resets it, then three in a row"
}

t_guard_ram_logs_the_first_read_and_every_twentieth() {
  step_setup "$FUNCNAME"
  guard_dirs
  session_fixture
  printf '8000\n' > "$STUB/answers/ram"
  export R9700_TIME_SCALE=3000 # a tick is 5 ms
  guard_start 2048
  for _ in $(seq 1 100); do [ "$(cat "$STUB/counters/answer-ram" 2> /dev/null || echo 0)" -ge 45 ] && break; sleep 0.1; done
  kill "$GUARD"
  wait "$GUARD" 2> /dev/null
  local reads lines
  reads="$(cat "$STUB/counters/answer-ram")"
  lines="$(grep -c 'available RAM 8000 MB' "$GLOG")"
  assert_eq "available RAM 8000 MB" "$(sed -n 1p "$GLOG" | sed 's/^[^ ]* //')" "read 1 is logged"
  # one line for read 1, 21, 41, ...: ceil(reads / 20) lines, or one fewer when the kill came between a read and its log line
  if [ "$lines" -ge 3 ] && [ "$lines" -ge $(((reads + 19) / 20 - 1)) ] && [ "$lines" -le $(((reads + 19) / 20)) ]; then assert_eq ok ok "every 20th read is logged ($lines lines for $reads reads)"; else assert_eq "ceil($reads/20) lines, at least 3" "$lines" "every 20th read is logged"; fi
  session_stop "$SID"
}

t_guard_ram_does_not_depend_on_the_callers_stop_time() {
  step_setup "$FUNCNAME"
  guard_dirs
  session_fixture
  printf '100\n' > "$STUB/answers/ram"
  export R9700_T_STOP=1 # long gone: an adapter call would be refused
  guard_start 2048
  wait "$GUARD"
  outcome_read "$OUTCOME"
  assert_eq "available 100 MB < 2048 MB" "$O_DETAIL" "it read the RAM and fired all the same"
  assert_eq "" "$(session_pids "$SID" | tr -d '\n')" "and stopped the session (the cleanup phase has no deadline, decision 8)"
}

t_guard_ram_still_stops_the_session_when_another_writer_was_first() {
  step_setup "$FUNCNAME"
  guard_dirs
  session_fixture
  outcome_write "$OUTCOME" KIND=deadline "DETAIL=first"
  printf '100\n' > "$STUB/answers/ram"
  guard_start 2048
  wait "$GUARD"
  outcome_read "$OUTCOME"
  assert_eq "deadline" "$O_KIND" "the first writer's outcome is kept"
  assert_eq "" "$(session_pids "$SID" | tr -d '\n')" "the session is stopped all the same"
}

t_guard_ram_refuses_bad_arguments() {
  step_setup "$FUNCNAME"
  guard_dirs
  assert_exit 2 "a session id that is not a number" -- guard_ram abc 2048 "$OUTCOME" "$GLOG"
  assert_exit 2 "a limit that is not a number" -- guard_ram 123 x "$OUTCOME" "$GLOG"
  RUN_DIR=""
  assert_exit 2 "no run folder" -- guard_ram 123 2048 "$OUTCOME" "$GLOG"
}

# ---- the deadline watcher (decision 8) ------------------------------------------------------------------------------------------------------------------

t_deadline_watch_fires_at_t_stop_not_before_and_stops_containers_and_the_session() {
  step_setup "$FUNCNAME"
  guard_dirs
  session_fixture
  stub_container r9700tune-a
  local start
  start="$(date +%s.%N)"
  T_STOP="$(stop_in 2)" # 2 to 3 s away: the floor of the start second would leave only 1 to 2 s, and the check at 1 s could find it fired
  deadline_watch "$SID" "$OUTCOME" "$GLOG" &
  local watcher=$!
  guard_pid "$watcher" "watcher-$watcher"
  sleep 1
  assert_missing "$OUTCOME" "nothing at 1 s: T_STOP is not there yet"
  wait "$watcher"
  assert_eq "0" "$?" "the watcher ends with 0"
  local end
  end="$(date +%s.%N)"
  if awk -v a="$start" -v b="$end" -v t="$T_STOP" 'BEGIN { exit !(b >= t && b < t + 2) }'; then assert_eq ok ok "it fired at T_STOP (not before, and within two seconds)"; else assert_eq "T_STOP..T_STOP+2" "$(awk -v b="$end" -v t="$T_STOP" 'BEGIN { print b - t }')" "it fired at T_STOP"; fi
  outcome_read "$OUTCOME"
  assert_eq "deadline" "$O_KIND" "KIND=deadline"
  assert_eq "" "$(session_pids "$SID" | tr -d '\n')" "the session is stopped"
  assert_missing "$STUB/containers/r9700tune-a.pid" "and the container"
}

t_deadline_watch_ends_by_itself_when_the_worker_is_gone() {
  step_setup "$FUNCNAME"
  guard_dirs
  session_fixture
  T_STOP="$(stop_in 30)"
  deadline_watch "$SID" "$OUTCOME" "$GLOG" &
  local watcher=$!
  guard_pid "$watcher" "watcher-$watcher"
  sleep 0.4
  kill -KILL "$SID"
  session_stop "$SID"
  wait "$watcher"
  assert_eq "0" "$?" "it ends with 0"
  assert_missing "$OUTCOME" "without an outcome"
}

# ---- wait_ready (decision 5's first check, the worker's side; lib/wait_ready.sh) -----------------------------------------------------------------------

# probe_run <mode>: the wait_ready probe program under python with urlopen replaced by a fake; the exit code is the program's
probe_run() {
  python3 -I -c '
import sys, urllib.error, urllib.request
mode, seen = sys.argv[2], []
class Reply:
    def __init__(self, status): self.status = status
    def __enter__(self): return self
    def __exit__(self, *a): return False
def fake(req, timeout=None):
    url = req if isinstance(req, str) else req.full_url
    print(url, timeout)
    if mode == "down": raise urllib.error.URLError("refused")
    if mode == "500": raise urllib.error.HTTPError(url, 500, "x", {}, None)
    return Reply(204 if mode == "204" else 200)
urllib.request.urlopen = fake
exec(compile(sys.argv[1], "probe", "exec"))
' "$(wait_ready_probe_program)" "$1"
}

t_the_wait_ready_probe_program_asks_models_for_200_within_5_s_and_exits_0_only_for_that() {
  lc_setup "$FUNCNAME"
  assert_exit 0 "the server answers 200" -- probe_run ok
  assert_eq "http://127.0.0.1:8000/v1/models 5" "$OUT" "GET /v1/models, 5 s, loopback port 8000 inside the container"
  assert_exit 1 "a 204" -- probe_run 204
  assert_exit 1 "an HTTP 500" -- probe_run 500
  assert_exit 1 "the server is down" -- probe_run down
  assert_not_contains "$(wait_ready_probe_program)" "/v1/completions" "it is the first check only (the stub tells the probes apart by that route)"
  assert_contains "$(wait_ready_probe_program)" "urlopen" "and it is a urlopen program (the stub's other marker)"
}

t_wait_ready_returns_0_at_the_first_good_probe_and_saves_the_log_as_it_is() {
  step_setup "$FUNCNAME"
  stub_container r9700tune-w
  printf 'line a\nline b\n' > "$STUB/answers/logs"
  assert_exit 0 "a server that answers" -- wait_ready r9700tune-w "$CASE/server.log"
  assert_contains "$OUT" "READY (waited " "the line says it is ready and for how long"
  assert_eq "$(cat "$STUB/answers/logs")" "$(cat "$CASE/server.log")" "the saved log equals what wslc logs printed"
  assert_eq "1" "$(cat "$STUB/counters/answer-ready")" "one probe"
}

t_wait_ready_reports_an_exited_server_after_three_missed_listings() {
  step_setup "$FUNCNAME"
  stub_container r9700tune-w
  printf 'fail\n' > "$STUB/answers/ready"
  ( wait_for "$STUB/counters/answer-ready"; kill -KILL "$(pid_of r9700tune-w)" ) &
  guard_pid "$!" killer
  assert_exit 1 "a container that dies after the first probe" -- wait_ready r9700tune-w "$CASE/server.log"
  assert_contains "$OUT" "SERVER EXITED" "the line"
  assert_contains "$(cat "$CASE/server.log")" "SERVER EXITED" "and the saved log says it too"
  if [ "$(cat "$STUB/counters/answer-ready")" -le 3 ]; then assert_eq ok ok "within three probes"; else assert_eq "<= 3" "$(cat "$STUB/counters/answer-ready")" "within three probes"; fi
}

t_wait_ready_ends_at_the_ready_timeout_with_a_line_and_the_log() {
  step_setup "$FUNCNAME"
  stub_container r9700tune-w
  printf 'fail\n' > "$STUB/answers/ready"
  printf 'x\n' > "$STUB/answers/logs"
  R9700_READY_TIMEOUT_S=60 # 0.6 s at scale 100
  local start end
  start="$(date +%s.%N)"
  assert_exit 1 "a server that never answers" -- wait_ready r9700tune-w "$CASE/server.log"
  end="$(date +%s.%N)"
  assert_contains "$OUT" "SERVER NOT READY after " "the line"
  assert_eq "x" "$(sed -n 1p "$CASE/server.log")" "the log was saved before the verdict line"
  if awk -v a="$start" -v b="$end" 'BEGIN { exit !(b - a < 5) }'; then assert_eq ok ok "it ended by its own limit"; else assert_eq "< 5 s" "$(awk -v a="$start" -v b="$end" 'BEGIN { print b - a }')" "it ended by its own limit"; fi
}

t_wait_ready_with_less_window_left_than_the_interval_does_not_sleep_a_full_interval() {
  step_setup "$FUNCNAME"
  stub_container r9700tune-w
  printf 'fail\n' > "$STUB/answers/ready"
  export R9700_TIME_SCALE=1 # a real 10 s interval against a 2 s window
  R9700_READY_TIMEOUT_S=2
  R9700_T_STOP=""
  local start end
  start="$(date +%s.%N)"
  assert_exit 1 "a server that never answers" -- wait_ready r9700tune-w "$CASE/server.log"
  end="$(date +%s.%N)"
  assert_contains "$OUT" "SERVER NOT READY after " "the line"
  assert_exit 0 "it returned within the window and a margin, not after the 10 s interval" -- awk -v a="$start" -v b="$end" 'BEGIN { exit !(b - a < 4.5) }'
  assert_exit 0 "and not before the window ended" -- awk -v a="$start" -v b="$end" 'BEGIN { exit !(b - a >= 1.9) }'
  kill_recorded_pids "$CASE"
}

t_wait_ready_is_cut_at_the_stop_time_and_a_hung_probe_does_not_hold_it() {
  step_setup "$FUNCNAME"
  stub_container r9700tune-w
  printf 'hang\n' > "$STUB/answers/ready"
  R9700_READY_TIMEOUT_S=3300 # 33 s at scale 100: the stop time is sooner
  R9700_T_STOP="$(stop_in 2)"
  local start end
  start="$(date +%s.%N)"
  assert_exit 1 "a probe that hangs, a stop time two seconds away" -- wait_ready r9700tune-w "$CASE/server.log"
  end="$(date +%s.%N)"
  if awk -v a="$start" -v b="$end" 'BEGIN { exit !(b - a < 5) }'; then assert_eq ok ok "it returned within the stop time and one grace"; else assert_eq "< 5 s" "$(awk -v a="$start" -v b="$end" 'BEGIN { print b - a }')" "it returned within the stop time"; fi
  assert_contains "$OUT" "SERVER NOT READY" "and says so"
  kill_recorded_pids "$CASE"
}

t_wait_ready_refuses_a_bad_name_or_no_log() {
  step_setup "$FUNCNAME"
  assert_exit 2 "a name that starts with a dash" -- wait_ready -x "$CASE/log"
  assert_exit 2 "no log path" -- wait_ready r9700tune-w
  assert_missing "$STUB/calls.log" "nothing was called"
}

t_wait_ready_saves_the_log_even_when_its_window_has_already_ended() {
  step_setup "$FUNCNAME"
  stub_container r9700tune-w
  printf 'x\ny\n' > "$STUB/answers/logs"
  R9700_T_STOP=$(( $(date +%s) - 5 )) # the stop time passed long ago: every list and probe of the loop is refused
  assert_exit 1 "wait_ready with a stop time in the past" -- wait_ready r9700tune-w "$CASE/server.log"
  assert_eq "x
y" "$(sed -n 1,2p "$CASE/server.log")" "the log of the container is saved first (a save is never cut by the window)"
  assert_contains "$(sed -n 3p "$CASE/server.log")" "SERVER NOT READY after " "then the verdict line"
}

# ---- _rg_tree_kill ---------------------------------------------------------------------------------------------------------------------------------

t_a_tree_kill_ends_a_direct_adapter_call_of_the_fork_with_its_whole_process_group() {
  step_setup "$FUNCNAME"
  printf 'hang-ignore-term\n' > "$STUB/mode" # the stub and its sleeper ignore TERM: `timeout` alone cannot end them
  ( wslc_stop r9700tune-x ) & # a DIRECT call in the fork (a guard's container_stop_all does the same), not a pipeline part
  local fork=$! f pid total=0 alive=0
  wait_for "$STUB/hung/containers/2.pid" 100
  rm -f "$STUB/mode"
  _rg_tree_kill "$fork"
  sleep 0.3
  for f in "$STUB"/hung/containers/*.pid; do
    read -r pid _ < "$f"
    total=$((total + 1))
    kill -0 "$pid" 2> /dev/null && alive=$((alive + 1))
  done
  assert_eq "2" "$total" "the stub and its sleeper were in the call (the scan is alive)"
  assert_eq "0" "$alive" "none of them is alive: the call's process group got the KILL (amendment A12)"
  kill_recorded_pids "$CASE"
}

run_all_tests
