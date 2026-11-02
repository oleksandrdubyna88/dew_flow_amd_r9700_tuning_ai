#!/usr/bin/env bash
# `bin/r9700 series` (E1.S3): the arm-round records, in the stub world. Scenarios S1-S6 and S11-S14 of the story, and the rules the reviews of S2
# established, applied to the series (a signal leaves no final record, a stale part directory is not trusted). The identity rules (fingerprint,
# resume, dry run) are tests/test_series_identity.sh; the verdict is tests/test_series_verdict.sh. Every test body is a function t_<guarantee>;
# each runs in its own subshell and writes only below $R9700_TEST_ROOT. "A stub series" is `series fbase fcombo --out s --rounds <n>` with the stubs
# answering as tests/lib/seriescase.sh sets them.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"
# shellcheck source=tests/lib/lifecycle.sh
source "$HERE/lib/lifecycle.sh"
# shellcheck source=tests/lib/seriescase.sh
source "$HERE/lib/seriescase.sh"

# ---- S1-S4: the records ------------------------------------------------------------------------------------------------------------------------

t_s1_a_one_round_two_arm_series_writes_two_final_records_and_a_fingerprint_in_alternating_order() {
  series_setup "$FUNCNAME"
  local out tag file
  out="$(outdir)"
  assert_exit 0 "a stub series with one round" -- sr fbase fcombo --out s --rounds 1
  for tag in fbase-1 fcombo-1; do
    for file in bench.txt spec_metrics.txt server.log server_config.txt record.env "prompts_${tag%-1}.json" "gsm8k_${tag%-1}.json"; do
      assert_exit 0 "rounds/$tag/$file exists" -- test -s "$out/rounds/$tag/$file"
    done
  done
  assert_eq "0" "$(find "$out/rounds" -name '*.part-*' | wc -l | tr -d ' ')" "no .part- directory remains"
  assert_eq "True" "$(python3 -c 'import json, hashlib, sys
d = json.load(open(sys.argv[1]))
text = json.dumps(d["components"], sort_keys=True, separators=(",", ":"), ensure_ascii=True)
print(d["sha256"] == hashlib.sha256(text.encode()).hexdigest())' "$out/fingerprint.json")" "fingerprint.json: its sha256 is the sha256 of the canonical form the test computes"
  assert_eq "r9700tune-sp-fbase-1 r9700tune-sp-fcombo-1" "$(starts | tr '\n' ' ' | sed 's/ $//')" "the containers started in alternating order: fbase, then fcombo"
  assert_eq "1" "$(prod_stops)" "the operator's server was stopped once"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "and restored once"
  assert_exit 0 "quality/gsm8k_fbase.json equals the record's file byte for byte" -- cmp "$out/quality/gsm8k_fbase.json" "$out/rounds/fbase-1/gsm8k_fbase.json"
  assert_exit 0 "and so does fcombo's" -- cmp "$out/quality/gsm8k_fcombo.json" "$out/rounds/fcombo-1/gsm8k_fcombo.json"
  assert_eq "done" "$(cat "$(run_dir_of)/status")" "the run's status is done"
}

t_s2_three_rounds_alternate_the_arms_inside_a_round() {
  series_setup "$FUNCNAME"
  local out
  out="$(outdir)"
  assert_exit 0 "a stub series with three rounds" -- sr fbase fcombo --out s --rounds 3
  assert_eq "r9700tune-sp-fbase-1 r9700tune-sp-fcombo-1 r9700tune-sp-fbase-2 r9700tune-sp-fcombo-2 r9700tune-sp-fbase-3 r9700tune-sp-fcombo-3" "$(starts | tr '\n' ' ' | sed 's/ $//')" "fbase, fcombo in every round"
  assert_eq "fbase-1 fbase-2 fbase-3 fcombo-1 fcombo-2 fcombo-3" "$(ls "$out/rounds" | tr '\n' ' ' | sed 's/ $//')" "six records"
  assert_eq "0" "$(ls "$out/rounds"/*/ -d | wc -l | awk '{ print $1 - 6 }')" "and nothing else in rounds/"
  assert_missing "$out/rounds/fbase-2/gsm8k_fbase.json" "round 2 has no quality file: only round 1 runs the quality step"
  assert_eq "1" "$(prod_stops)" "one stop of the operator's server for the whole series"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
}

t_s3_every_records_bench_file_is_one_complete_block_that_check_block_accepts() {
  series_setup "$FUNCNAME"
  local out dir tag n=0
  out="$(outdir)"
  sr fbase fcombo --out s --rounds 1 > /dev/null 2>&1
  for dir in "$out"/rounds/*/; do
    tag="$(basename "$dir")"
    n=$((n + 1))
    assert_exit 0 "check-block of $tag" -- python3 "$REPO/lib/verdict.py" check-block --tag "$tag" --prefill-lens "8192 32768" "$dir/bench.txt"
    assert_eq "36" "$(wc -l < "$dir/bench.txt" | tr -d ' ')" "$tag: 36 lines"
  done
  assert_eq "2" "$n" "the loop derived two records from rounds/*/"
  assert_eq "$(sed -n 175,210p "$BENCH_FIXTURE" | sed -E 's/^fcombo-2 //' | tr -d ' ')" "$(sed -E 's/^fbase-1 //' "$out/rounds/fbase-1/bench.txt" | tr -d ' ')" "fbase-1's lines are the stub's answers with the tag the series gave them"
}

t_s4_record_env_carries_the_run_identity() {
  series_setup "$FUNCNAME"
  local out env run
  out="$(outdir)"
  sr fbase fcombo --out s --rounds 1 > /dev/null 2>&1
  env="$out/rounds/fbase-1/record.env"
  run="$(basename "$(run_dir_of)")"
  assert_eq "ARM=fbase" "$(grep '^ARM=' "$env")" "ARM"
  assert_eq "ROUND=1" "$(grep '^ROUND=' "$env")" "ROUND"
  assert_eq "CONTAINER=r9700tune-sp-fbase-1" "$(grep '^CONTAINER=' "$env")" "CONTAINER"
  assert_eq "FINGERPRINT=$(json_get "$out/fingerprint.json" 'd["sha256"]')" "$(grep '^FINGERPRINT=' "$env")" "FINGERPRINT equals fingerprint.json's sha256"
  assert_eq "RUN_ID=$run" "$(grep '^RUN_ID=' "$env")" "RUN_ID is the name of the run directory"
  assert_eq "SERIES_SH=$(json_get "$out/fingerprint.json" 'd["components"]["tools"]["series_sh"]')" "$(grep '^SERIES_SH=' "$env")" "SERIES_SH is the fingerprint's hash of lib/series.sh"
  local started finished
  started="$(sed -n 's/^STARTED_AT=//p' "$env")"
  finished="$(sed -n 's/^FINISHED_AT=//p' "$env")"
  if [[ $started =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ && $finished =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then assert_eq ok ok "both times are ISO UTC"; else assert_eq "ISO UTC" "$started $finished" "both times are ISO UTC"; fi
  if [[ ! $started > $finished ]]; then assert_eq ok ok "STARTED_AT <= FINISHED_AT"; else assert_eq "<=" "$started > $finished" "STARTED_AT <= FINISHED_AT"; fi
  assert_contains "$(cat "$out/rounds/fbase-1/server_config.txt")" "Using configuration from /work/moe/tune/merged" "server_config.txt keeps the configuration evidence of the log"
  assert_eq "2" "$(wc -l < "$out/rounds/fbase-1/spec_metrics.txt" | tr -d ' ')" "spec_metrics.txt: the two spec-decode lines"
  assert_contains "$(sed -n 1p "$out/rounds/fbase-1/spec_metrics.txt")" "fbase-1 vllm:spec_decode_" "prefixed with the tag"
}

# ---- S5, S6: a record is written only when it is complete ---------------------------------------------------------------------------------------

t_s5_a_server_lost_mid_bench_leaves_no_final_record_and_a_rejected_attempt_with_its_reason() {
  series_setup "$FUNCNAME"
  export R9700_STUB_DELAY_S=0.3
  step_cfg MAX_FAILED_TRIES=1
  local out rej
  out="$(outdir)"
  lose_server_after r9700tune-sp-fbase-1 3
  series_bg fbase fcombo --out s --rounds 1
  step_end
  assert_eq "7" "$SRC" "the series exits non-zero: the step failed MAX_FAILED_TRIES=1 times"
  assert_missing "$out/rounds/fbase-1" "no final record: the false done_o7ref-1 of 2026-10-31 cannot happen"
  rej="$(ls -d "$out"/rejected/fbase-1-* 2> /dev/null | head -n 1)"
  assert_exit 0 "rejected/fbase-1-<stamp>/ exists" -- test -d "$rej"
  assert_eq "LOST: server alive 0" "$(sed -n 1p "$rej/reason" | cut -c1-20)" "its reason starts LOST: server alive 0"
  if [ "$(wc -l < "$rej/bench.txt")" -lt 36 ]; then assert_eq ok ok "its bench.txt has fewer than 36 lines"; else assert_eq "< 36" "$(wc -l < "$rej/bench.txt")" "its bench.txt has fewer than 36 lines"; fi
  assert_exit 0 "and the evidence of the attempt is all there (server.log)" -- test -s "$rej/server.log"
  outcome_read "$(run_dir_of)/steps/1.outcome"
  assert_eq "worker 1" "$O_KIND $O_RC" "the supervisor's outcome is KIND=worker RC=1"
  assert_eq "failed" "$(cat "$(run_dir_of)/status")" "the status is failed"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the restore ran once"
  assert_eq "1" "$(prod_stops)" "and the server was stopped once"
  assert_contains "$SERR" "r9700: step failed 1 times, last: worker 1" "the supervisor says why"
  assert_missing "$out/rounds/fcombo-1" "the series did not go on to fcombo"
}

t_s6_missing_bench_lines_make_no_record_even_when_the_server_is_alive() {
  series_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  grep -v '^prefill32768 r=2 ' "$STUB/answers/bench" > "$STUB/answers/bench.new" && mv "$STUB/answers/bench.new" "$STUB/answers/bench"
  local out rej
  out="$(outdir)"
  assert_exit 7 "the series fails its one try" -- sr fbase fcombo --out s --rounds 1
  assert_missing "$out/rounds/fbase-1" "no final record"
  rej="$(ls -d "$out"/rejected/fbase-1-* | head -n 1)"
  assert_contains "$(cat "$rej/reason")" "check-block: missing prefill32768 r=2 Output token throughput (tok/s)" "the reason names the missing line"
  assert_not_contains "$(sed -n 1p "$rej/reason")" "LOST" "the server was alive: not a LOST"
  assert_contains "$(sed -n 1p "$rej/reason")" "server alive 1" "and the first line says so"
  assert_eq "33" "$(wc -l < "$rej/bench.txt" | tr -d ' ')" "the whole bench.txt of the attempt is kept"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the restore ran once"
}

t_a_round_one_attempt_whose_quality_file_is_short_is_rejected_with_the_reason() {
  series_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  printf '19\n' > "$STUB/answers/prompts_n" # the stub harness writes 19 results instead of 20: the record check (c) must refuse the record
  local out rej
  out="$(outdir)"
  assert_exit 7 "the series fails its one try" -- sr fbase --out s --rounds 1
  assert_missing "$out/rounds/fbase-1" "no final record"
  rej="$(ls -d "$out"/rejected/fbase-1-* | head -n 1)"
  assert_contains "$(cat "$rej/reason")" "quality: prompts has 19 results, expected 20" "the reason says what is short"
  assert_exit 0 "the attempt's files are kept" -- test -s "$rej/prompts_fbase.json"
}

# ---- S11: an arm that does not start ---------------------------------------------------------------------------------------------------------------

t_s11_a_container_that_never_becomes_ready_is_retried_once_then_the_arm_is_unsupported_and_the_series_goes_on() {
  series_setup "$FUNCNAME"
  step_cfg READY_TIMEOUT_S=60
  printf 'fail\n' > "$STUB/answers/ready.r9700tune-sp-fbase-1"
  printf 'fail\n' > "$STUB/answers/ready.r9700tune-sp-fbase-1-r2"
  # the Error lines come last in the log, as in a failing start
  { cat "$STUB/answers/logs"; for i in 1 2 3 4; do echo "RuntimeError: Error $i: out of memory"; done; } > "$STUB/answers/logs.new" && mv "$STUB/answers/logs.new" "$STUB/answers/logs"
  local out file
  out="$(outdir)"
  assert_exit 0 "the series ends well" -- sr fbase fcombo --out s --rounds 1
  file="$(ls "$out"/unsupported/fbase-*.txt)"
  assert_eq "1" "$(ls "$out"/unsupported | wc -l | tr -d ' ')" "one unsupported file: unsupported/fbase-<stamp>.txt"
  assert_eq "2" "$(grep -c 'rejected/fbase-1-' "$file")" "it names the two rejected directories"
  assert_eq "2" "$(ls -d "$out"/rejected/fbase-1-* | wc -l | tr -d ' ')" "rejected/ holds fbase-1-* twice"
  assert_eq "2" "$(ls "$out"/rejected/fbase-1-*/server.log | wc -l | tr -d ' ')" "with the server.log of each"
  assert_not_contains "$(cat "$file")" "Error 1:" "the last three Error lines of the log: the first of four is not there"
  assert_contains "$(cat "$file")" "Error 4: out of memory" "the last one is"
  assert_eq "3" "$(grep -c 'RuntimeError' "$file")" "three of them"
  assert_exit 0 "fcombo-1 is recorded" -- test -d "$out/rounds/fcombo-1"
  assert_missing "$out/rounds/fbase-1" "and fbase-1 is not"
  assert_eq "r9700tune-sp-fbase-1 r9700tune-sp-fbase-1-r2 r9700tune-sp-fcombo-1" "$(starts | tr '\n' ' ' | sed 's/ $//')" "the second start of the arm has a new container name; then fcombo"
  local stop run2
  stop="$(stamp_of ' wslc stop r9700tune-sp-fbase-1$')"
  run2="$(stamp_of ' wslc run -d --rm --name r9700tune-sp-fbase-1-r2 ')"
  assert_exit 0 "the first container was stopped before the second start" -- awk -v a="$stop" -v b="$run2" 'BEGIN { exit !(a != "" && b > a) }'
  assert_exit 0 "60 s apart at 100 times speed: at least half a second" -- awk -v a="$stop" -v b="$run2" 'BEGIN { exit !(b - a >= 0.5) }'
  local n
  n="$(wc -l < "$STUB/calls.log")"
  assert_exit 0 "a second invocation" -- sr fbase fcombo --out s --rounds 1
  assert_eq "0" "$(calls_since "$n" | grep -c 'r9700tune-sp-fbase')" "does not start fbase again"
  assert_contains "$OUT" "nothing to do" "it has nothing to do"
  [ -n "$file" ] || true
}

# ---- S12: the quiet check -----------------------------------------------------------------------------------------------------------------------

t_s12_a_busy_pc_is_never_admitted_and_the_short_variant_ends_at_the_deadline() {
  series_setup "$FUNCNAME"
  short_variant
  set_load 9.0
  assert_exit 8 "a busy PC from the start" -- sr fbase fcombo --out s --rounds 1
  assert_eq "0" "$(starts | wc -l | tr -d ' ')" "no container was started"
  assert_eq "0" "$(prod_stops)" "the operator's server was never stopped"
  assert_eq "not-quiet" "$(cat "$(run_dir_of)/status")" "the status is not-quiet"
}

t_s12_the_quiet_check_runs_before_every_arm_round_and_exits_3_and_the_series_resumes_in_one_stop() {
  series_setup "$FUNCNAME"
  local out run i
  out="$(outdir)"
  # the load turns busy when the first arm-round's container is stopped, that is right before its record is final, and quiet again once the
  # supervisor says it is waiting
  printf 'printf "9.0 0.40 0.30 1/100 1\\n" > "%s/loadavg"\n' "$CASE" > "$STUB/on-stop-r9700tune-sp-fbase-1"
  ( for i in $(seq 1 300); do
      run="$(ls -d "$R9700_RESULTS_DIR"/runs/*/ 2> /dev/null | head -n 1)"
      if [ -n "$run" ] && grep -q 'not quiet at a unit start, waiting' "$run/supervisor.log" 2> /dev/null; then set_load 0.5; break; fi
      sleep 0.1
    done ) &
  guard_pid "$!" flipper
  assert_exit 0 "the series ends well" -- sr fbase fcombo --out s --rounds 1
  run="$(run_dir_of)"
  assert_contains "$(cat "$run/supervisor.log")" "not quiet at a unit start, waiting" "the supervisor log has the line"
  assert_exit 0 "fbase-1 is recorded" -- test -d "$out/rounds/fbase-1"
  assert_exit 0 "and fcombo-1, once the PC was quiet again" -- test -d "$out/rounds/fcombo-1"
  assert_eq "1" "$(prod_stops)" "one stop of the operator's server in total"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
  assert_contains "$(cat "$run/steps/1.worker.log")" "NOT QUIET: fcombo round 1" "the worker said which arm-round it would not start"
}

# ---- S13: the fit check -------------------------------------------------------------------------------------------------------------------------

t_s13_the_fit_check_ends_the_series_cleanly_before_the_deadline() {
  series_setup "$FUNCNAME"
  short_variant
  # T_STOP is 8.6..9.6 s after the start (the stop is rounded down to a whole second); an arm-round is allowed 4 s (100 s at scale 25) and takes
  # about 5 s (twelve bench calls of 0.3 s and the rest): the first starts at t1 (a second or two in: the fingerprint's python calls come first)
  # and fits while t1 + 4 < 8.6, that is for every t1 below 4.6 s; the second starts at about t1 + 5.5 and cannot (t1 + 5.5 + 4 > 9.6 for any
  # t1 above 0.1 s) while the first still ends before T_STOP (t1 + 5 < 8.6)
  export R9700_ARM_SECONDS=100 R9700_STUB_DELAY_S=0.3
  local out run
  out="$(outdir)"
  assert_exit 6 "the supervisor exits 6: the deadline" -- sr fbase fcombo --out s --rounds 1
  run="$(run_dir_of)"
  assert_exit 0 "fbase-1 is recorded" -- test -d "$out/rounds/fbase-1"
  assert_missing "$out/rounds/fcombo-1" "nothing for fcombo"
  assert_contains "$(cat "$run/steps/1.worker.log")" "series: 1 arm-rounds no longer fit before the deadline" "the worker says why it stops"
  assert_not_contains "$(cat "$run/supervisor.log")" "failed try" "no failed try: a clean end is not a failure"
  assert_eq "deadline" "$(cat "$run/status")" "the status is deadline"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the server was restored"
  assert_eq "0" "$(ls "$out/rejected" 2> /dev/null | wc -l | tr -d ' ')" "nothing was rejected"
}

# ---- S14: the disk gate -------------------------------------------------------------------------------------------------------------------------

t_s14_the_disk_gate_stops_the_series_between_arm_rounds_and_never_inside_one() {
  series_setup "$FUNCNAME"
  # call 1: the supervisor's baseline; call 2: the check before fbase-1; call 3: the check before fcombo-1 sees a new event
  printf '100\n100\n101\n' > "$STUB/answers/disk"
  local out run
  out="$(outdir)"
  assert_exit 9 "the supervisor exits 9: the disk gate" -- sr fbase fcombo --out s --rounds 1
  run="$(run_dir_of)"
  outcome_read "$run/steps/1.outcome"
  assert_eq "disk_gate" "$O_KIND" "KIND=disk_gate in the worker's outcome"
  assert_eq "1" "$O_RC" "RC=1"
  assert_exit 0 "fbase-1 is final: the gate is checked before a unit, not inside one" -- test -f "$out/rounds/fbase-1/record.env"
  assert_missing "$out/rounds/fcombo-1" "no fcombo"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the server was restored"
}

# ---- what S2's reviews established, applied to the series -------------------------------------------------------------------------------------

t_a_stale_part_directory_is_moved_to_rejected_at_the_next_start_and_never_trusted() {
  series_setup "$FUNCNAME"
  local out rej
  out="$(outdir)"
  sr fcombo --out s --rounds 1 > /dev/null 2>&1 # the series exists (it has its fingerprint); a worker then dies in the middle of the next arm-round
  mkdir -p "$out/rounds/fbase-1.part-old-run"
  sed -n 175,190p "$BENCH_FIXTURE" | sed 's/^fcombo-2/fbase-1/' > "$out/rounds/fbase-1.part-old-run/bench.txt"
  assert_exit 0 "a series over a folder that holds a part directory of a killed worker" -- sr fcombo fbase --out s --rounds 1
  assert_missing "$out/rounds/fbase-1.part-old-run" "the part directory is gone from rounds/"
  rej="$(ls -d "$out"/rejected/fbase-1-* | head -n 1)"
  assert_eq "INTERRUPTED" "$(sed -n 1p "$rej/reason" | cut -c1-11)" "it is in rejected/ with an INTERRUPTED reason"
  assert_contains "$(cat "$rej/reason")" "fbase-1.part-old-run" "naming what was left"
  assert_eq "16" "$(wc -l < "$rej/bench.txt" | tr -d ' ')" "its content is kept as evidence"
  assert_exit 0 "and the record that was made is complete" -- python3 "$REPO/lib/verdict.py" check-block --tag fbase-1 --prefill-lens "8192 32768" "$out/rounds/fbase-1/bench.txt"
}

t_a_signal_during_an_arm_round_leaves_no_final_record_and_the_next_run_completes_it() {
  series_setup "$FUNCNAME"
  export R9700_STUB_DELAY_S=0.3
  local out i
  out="$(outdir)"
  series_bg fbase --out s --rounds 1
  for i in $(seq 1 300); do ls "$out"/rounds/*.part-* > /dev/null 2>&1 && [ "$(grep -c ' wslc exec .* vllm bench serve ' "$STUB/calls.log" 2> /dev/null)" -ge 1 ] && break; sleep 0.1; done
  kill -TERM "$SUP"
  step_end
  assert_eq "143" "$SRC" "the supervisor exits 143"
  assert_missing "$out/rounds/fbase-1" "no final record"
  assert_eq "1" "$(ls -d "$out"/rounds/fbase-1.part-* | wc -l | tr -d ' ')" "the part directory of the killed worker is still there"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the operator's server was restored once"
  unset R9700_STUB_DELAY_S
  assert_exit 0 "the same command again" -- sr fbase --out s --rounds 1
  assert_exit 0 "fbase-1 is now recorded" -- test -f "$out/rounds/fbase-1/record.env"
  assert_eq "1" "$(ls -d "$out"/rejected/fbase-1-* | wc -l | tr -d ' ')" "and the interrupted attempt is in rejected/"
}

t_a_series_that_cannot_find_its_quality_copy_restores_it_from_the_record() {
  series_setup "$FUNCNAME"
  local out
  out="$(outdir)"
  sr fbase --out s --rounds 1 > /dev/null 2>&1
  rm "$out/quality/gsm8k_fbase.json"
  assert_exit 0 "the same command again" -- sr fbase --out s --rounds 1
  assert_contains "$OUT" "nothing to do" "there is nothing to run"
  assert_exit 0 "quality/gsm8k_fbase.json is back, equal to the record's file" -- cmp "$out/quality/gsm8k_fbase.json" "$out/rounds/fbase-1/gsm8k_fbase.json"
}

t_the_disk_gate_is_checked_once_more_at_the_end_and_a_stop_there_keeps_the_final_records() {
  series_setup "$FUNCNAME"
  # call 1: the baseline; call 2: the check before fbase-1; call 3: the check at the end of the series sees a new event
  printf '100\n100\n101\n' > "$STUB/answers/disk"
  local out
  out="$(outdir)"
  assert_exit 9 "the supervisor exits 9" -- sr fbase --out s --rounds 1
  assert_exit 0 "the record made before the event is final" -- test -f "$out/rounds/fbase-1/record.env"
  outcome_read "$(run_dir_of)/steps/1.outcome"
  assert_eq "disk_gate" "$O_KIND" "KIND=disk_gate"
}

t_a_start_that_fails_because_the_deadline_came_is_not_an_unsupported_arm_and_is_not_retried() {
  series_setup "$FUNCNAME"
  source "$REPO/lib/series.sh"
  local out="$CASE/results/x" part rc
  mkdir -p "$out/rounds"
  arms_load "$REPO/config/arms.conf"
  part="$out/rounds/fbase-1.part-t"
  mkdir "$part"
  R9700_T_STOP=$(($(date +%s) - 5)) # the stop time has passed: the adapter refuses every call, as it does in the minutes before the watcher acts
  _series_start_server "$out" fbase 1 "$part" > /dev/null 2>&1
  rc=$?
  assert_eq "4" "$rc" "the start reports the deadline (exit 4: the supervisor reads it as the deadline, not as a failed try)"
  assert_missing "$out/unsupported" "no unsupported mark: the arm was not given a chance"
  assert_eq "1" "$(ls -d "$out"/rejected/fbase-1-* | wc -l | tr -d ' ')" "one attempt in rejected/, not two: no second try"
  assert_contains "$(cat "$out"/rejected/fbase-1-*/reason)" "INTERRUPTED: the deadline" "its reason says why"
  assert_eq "0" "$(starts | wc -l | tr -d ' ')" "and nothing was started"
}

# ---- the identity is re-checked at the start of every arm-round, in the worker ----------------------------------------------------------------

t_a_patch_file_changed_between_two_arm_rounds_makes_the_second_refuse_and_leave_no_record() {
  series_setup "$FUNCNAME"
  printf 'printf x >> "%s/patches/C/auto_gptq.py"\n' "$CASE" > "$STUB/on-stop-r9700tune-sp-fbase-1"
  local out run
  out="$(outdir)"
  assert_exit 2 "the operator edits a patch file while the first arm-round runs" -- sr fbase fcombo --out s --rounds 1
  local err="$ERR" # the next assertions overwrite $ERR
  assert_exit 0 "fbase-1 (started before the edit) is recorded" -- test -f "$out/rounds/fbase-1/record.env"
  assert_missing "$out/rounds/fcombo-1" "fcombo-1 is not"
  assert_eq "0" "$(ls "$out/rejected" 2> /dev/null | wc -l | tr -d ' ')" "and no attempt of it exists: it was refused before its server started"
  assert_eq "r9700tune-sp-fbase-1" "$(starts | tr '\n' ' ' | sed 's/ $//')" "no server was started for it"
  assert_contains "$err" "fingerprint differs: patches.C/auto_gptq.py: " "the supervisor names the file on stderr"
  run="$(run_dir_of)"
  outcome_read "$run/steps/1.outcome"
  assert_eq "refused 2" "$O_KIND $O_RC" "the outcome is the typed KIND=refused, RC=2"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the operator's server was restored"
  assert_eq "1" "$(prod_stops)" "after one stop: a refusal is not a failed try, nothing was retried"
}

t_an_arm_table_changed_between_two_arm_rounds_makes_the_second_refuse() {
  series_setup "$FUNCNAME"
  cp "$REPO/config/arms.conf" "$CASE/arms.conf"
  export R9700_ARMS_CONF="$CASE/arms.conf"
  printf 'sed -i "s/^fcombo  | --speculative-config.method mtp --speculative-config.num_speculative_tokens 3/fcombo  | --speculative-config.method mtp --speculative-config.num_speculative_tokens 4/" "%s/arms.conf"\n' "$CASE" > "$STUB/on-stop-r9700tune-sp-fbase-1"
  local out
  out="$(outdir)"
  assert_exit 2 "the arm table of the second arm is edited during the first arm-round" -- sr fbase fcombo --out s --rounds 1
  assert_contains "$ERR" "fingerprint differs: arms.fcombo.args: " "the line names the arm's arguments"
  assert_missing "$out/rounds/fcombo-1" "no record for fcombo"
  assert_eq "r9700tune-sp-fbase-1" "$(starts | tr '\n' ' ' | sed 's/ $//')" "and no server was started for it"
}

t_a_worker_that_is_started_again_after_an_exit_3_checks_the_identity_again() {
  series_setup "$FUNCNAME"
  # the first arm-round ends, the PC turns busy, the edit is made while the worker is gone, the PC turns quiet: the NEW worker must refuse
  printf 'printf "9.0 0.40 0.30 1/100 1\\n" > "%s/loadavg"; printf x >> "%s/patches/C/auto_gptq.py"\n' "$CASE" "$CASE" > "$STUB/on-stop-r9700tune-sp-fbase-1"
  local i run
  ( for i in $(seq 1 300); do
      run="$(ls -d "$R9700_RESULTS_DIR"/runs/*/ 2> /dev/null | head -n 1)"
      if [ -n "$run" ] && grep -q 'not quiet at a unit start, waiting' "$run/supervisor.log" 2> /dev/null; then set_load 0.5; break; fi
      sleep 0.1
    done ) &
  guard_pid "$!" flipper
  assert_exit 2 "a patch edited between two worker starts" -- sr fbase fcombo --out s --rounds 1
  assert_contains "$ERR" "fingerprint differs: patches.C/auto_gptq.py" "refused by the second worker"
  assert_missing "$(outdir)/rounds/fcombo-1" "no record"
}

t_a_patch_file_changed_between_the_first_and_the_second_start_try_makes_the_second_refuse() {
  series_setup "$FUNCNAME"
  step_cfg READY_TIMEOUT_S=60
  printf 'fail\n' > "$STUB/answers/ready.r9700tune-sp-fbase-1"
  printf 'printf x >> "%s/patches/C/auto_gptq.py"\n' "$CASE" > "$STUB/on-stop-r9700tune-sp-fbase-1"
  local out err
  out="$(outdir)"
  assert_exit 2 "a patch edited while the first start try is stopped" -- sr fbase --out s --rounds 1
  err="$ERR"
  assert_contains "$err" "fingerprint differs: patches.C/auto_gptq.py: " "named"
  assert_eq "r9700tune-sp-fbase-1" "$(starts | tr '\n' ' ' | sed 's/ $//')" "the second start try never started its container"
  assert_missing "$out/unsupported" "the arm is not marked unsupported"
  assert_eq "1" "$(ls -d "$out"/rejected/fbase-1-* | wc -l | tr -d ' ')" "the first try is in rejected/"
  assert_eq "0" "$(find "$out/rounds" -mindepth 1 | wc -l | tr -d ' ')" "and nothing is left in rounds/ (no empty part directory)"
  outcome_read "$(run_dir_of)/steps/1.outcome"
  assert_eq "refused 2" "$O_KIND $O_RC" "the typed refusal"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
}

run_all_tests
