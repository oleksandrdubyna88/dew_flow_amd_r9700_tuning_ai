#!/usr/bin/env bash
# `bin/r9700 verdict <outdir>` (E1.S3): the ship test read back from the records. Scenarios S15-S18 of the story: a partial series gets no full
# verdict, an in-flight or rejected attempt never reaches it, the recorded verdict of 2026-10-31 is reproduced from records, an unsupported arm is
# reported and left out, a one-round series says so. Every test body is a function t_<guarantee>; each runs in its own subshell.
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

# ---- S15: a partial series gets no full verdict --------------------------------------------------------------------------------------------------

t_s15_a_base_with_no_final_record_is_refused_and_an_in_flight_attempt_never_reaches_the_verdict() {
  series_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  grep -v '^prefill32768 r=2 ' "$STUB/answers/bench" > "$STUB/answers/bench.new" && mv "$STUB/answers/bench.new" "$STUB/answers/bench"
  local out
  out="$(outdir)"
  sr fbase fcombo --out s --rounds 1 > /dev/null 2>&1 # fbase-1 is rejected: nothing is final
  mkdir -p "$out/rounds/fcombo-1.part-x"
  sed -n 175,210p "$BENCH_FIXTURE" | sed 's/^fcombo-2/fcombo-1/' > "$out/rounds/fcombo-1.part-x/bench.txt"
  assert_exit 2 "verdict on an outdir whose base has no final record" -- r9700 verdict "$out"
  assert_contains "$ERR" 'base arm "fbase" has no complete arm-round in the inputs' "the verdict says so"
  assert_not_contains "$OUT$ERR" ".part-x" "no in-flight directory is named"
  assert_not_contains "$OUT$ERR" "rejected/" "and no rejected attempt"
}

t_s15_a_missing_round_gives_incomplete_and_no_pass_or_fail_line() {
  series_setup "$FUNCNAME"
  local out
  out="$(outdir)"
  build_fixture_outdir "$out"
  mkdir -p "$out/rejected/by-test"
  mv "$out/rounds/fcombo-3" "$out/rejected/by-test/fcombo-3"
  assert_exit 1 "verdict with fcombo-3 moved away" -- r9700 verdict "$out"
  assert_contains "$OUT" "verdict fcombo: INCOMPLETE (missing complete arm-rounds: fcombo-3)" "the arm is incomplete, naming the round"
  assert_contains "$OUT" "verdict fb1: " "the other arm is judged on its own"
  assert_not_contains "$(grep '^verdict fcombo' <<< "$OUT")" "PASS" "no PASS for fcombo"
  assert_not_contains "$(grep '^verdict fcombo' <<< "$OUT")" "FAIL" "and no FAIL"
  assert_not_contains "$OUT" "rejected" "the rejected copy never reached the verdict"
}

# ---- S16: the records reproduce the recorded verdict -----------------------------------------------------------------------------------------------

t_s16_the_stopped_and_fragment_blocks_are_ignored_and_the_records_reproduce_the_recorded_verdict() {
  series_setup "$FUNCNAME"
  local out
  out="$(outdir)"
  build_fixture_outdir "$out"
  assert_exit 0 "verdict over the fixture outdir" -- r9700 verdict "$out"
  assert_contains "$OUT" "ignored incomplete block: fcombo-2, 30 lines from bench.txt:1" "the stopped fcombo-2 block is named"
  assert_contains "$OUT" "ignored incomplete block: fb1-2, 3 lines from bench.txt:1" "and the fb1-2 fragment"
  assert_contains "$OUT" "verdict fcombo: PASS" "fcombo passes"
  assert_contains "$OUT" "verdict fb1: FAIL (no decode median is higher than the base spread)" "fb1 fails"
  assert_contains "$OUT" "median 84.47 vs 76.08" "the c=1 numbers of the S1 table"
  assert_contains "$OUT" "base spread 9.84" "the base spread"
  assert_contains "$OUT" "202.44 vs 178.39" "the c=4 numbers"
  assert_eq "series $out: base fbase, 3 rounds, fingerprint ffffffffffff" "$(sed -n 1p <<< "$OUT")" "the header line"
  assert_not_contains "$OUT" "note: 1 round" "no one-round note for three rounds"
  assert_exit 1 "the companion: check-block on a record that holds two blocks" -- python3 "$REPO/lib/verdict.py" check-block --tag fcombo-2 --prefill-lens "8192 32768" "$out/rounds/fcombo-2/bench.txt"
  assert_contains "$OUT" "expected 36 lines, found 66" "it says why the toolkit's own records never hold two blocks"
  assert_contains "$(r9700 verdict "$out" 2> /dev/null | grep '^invoking:')" "--bench $out/rounds/fbase-1/bench.txt" "the invoking line shows the argv, in arm and round order"
}

t_verdict_options_choose_the_base_skip_the_quality_and_write_json() {
  series_setup "$FUNCNAME"
  local out
  out="$(outdir)"
  build_fixture_outdir "$out"
  rm -rf "$out/quality"
  assert_exit 1 "no quality files and no --no-quality: the arms are incomplete, never judged" -- r9700 verdict "$out"
  assert_contains "$OUT" "verdict fcombo: INCOMPLETE (no gsm8k_fcombo.json; no gsm8k_fbase.json)" "naming the missing quality files"
  assert_exit 0 "--no-quality" -- r9700 verdict "$out" --no-quality --json "$CASE/v.json"
  assert_eq "2" "$(python3 -c 'import json, sys; print(len(json.load(open(sys.argv[1]))))' "$CASE/v.json")" "--json: one entry per judged arm"
  assert_exit 0 "--base names another base" -- r9700 verdict "$out" --no-quality --base fcombo
  assert_contains "$OUT" "base fcombo, 3 rounds" "the header says which base"
  assert_exit 2 "an unknown option" -- r9700 verdict "$out" --nosuch
  assert_contains "$ERR" "legal: " "the legal options"
  assert_exit 2 "an outdir with no fingerprint" -- r9700 verdict "$CASE"
  assert_contains "$ERR" "fingerprint.json" "names the missing file"
}

# ---- S17: an unsupported arm ------------------------------------------------------------------------------------------------------------------------

t_s17_an_unsupported_arm_is_reported_and_left_out_and_an_unsupported_base_is_refused() {
  series_setup "$FUNCNAME"
  step_cfg READY_TIMEOUT_S=60
  printf 'fail\n' > "$STUB/answers/ready.r9700tune-sp-fcombo-1"
  printf 'fail\n' > "$STUB/answers/ready.r9700tune-sp-fcombo-1-r2"
  local out
  out="$(outdir)"
  assert_exit 0 "a series where fcombo never starts" -- sr fbase fcombo --out s --rounds 1
  assert_exit 0 "verdict" -- r9700 verdict "$out"
  if [[ $OUT =~ verdict\ fcombo:\ UNSUPPORTED\ \(did\ not\ start\ twice,\ [0-9]{8}T[0-9]{6}Z\) ]]; then assert_eq ok ok "verdict fcombo: UNSUPPORTED (did not start twice, <stamp>)"; else assert_eq "verdict fcombo: UNSUPPORTED (did not start twice, <stamp>)" "$OUT" "the line"; fi
  assert_not_contains "$OUT" "--arm" "verdict.py is not called with an arm to judge: only the base is left"
  # the other shape: the base is the arm that never starts
  printf 'fail\n' > "$STUB/answers/ready.r9700tune-sp-fbase-1"
  printf 'fail\n' > "$STUB/answers/ready.r9700tune-sp-fbase-1-r2"
  printf 'ok\n' > "$STUB/answers/ready.r9700tune-sp-fcombo-1"
  rm "$STUB/answers/ready.r9700tune-sp-fcombo-1-r2"
  assert_exit 0 "a series where the base never starts" -- sr fbase fcombo --out s2 --rounds 1
  assert_exit 2 "verdict" -- r9700 verdict "$(outdir s2)"
  assert_contains "$ERR" "verdict: base arm fbase is unsupported" "an unsupported base is refused, naming it"
}

# ---- S18: a one-round series ------------------------------------------------------------------------------------------------------------------------

t_s18_a_one_round_series_gets_a_verdict_with_its_condition_named() {
  series_setup "$FUNCNAME"
  local out
  out="$(outdir)"
  assert_exit 0 "a one-round stub series" -- sr fbase fcombo --out s --rounds 1
  assert_exit 0 "verdict" -- r9700 verdict "$out"
  assert_contains "$OUT" "note: 1 round, 3 values per concurrency; the recorded ship test used 3 rounds (9)" "the condition is named"
  assert_contains "$OUT" "verdict fcombo: FAIL (no decode median is higher than the base spread)" "both arms have the same block: delta 0, FAIL"
  assert_not_contains "$OUT" "PASS" "and no PASS"
  assert_eq "series $out: base fbase, 1 rounds, fingerprint $(json_get "$out/fingerprint.json" 'd["sha256"][:12]')" "$(sed -n 1p <<< "$OUT")" "the header line"
  assert_contains "$(grep '^invoking:' <<< "$OUT")" "python3 $REPO/lib/verdict.py ship --base fbase --arm fcombo " "the invoking line"
  assert_contains "$(grep '^invoking:' <<< "$OUT")" "--rounds 1" "with the round count of the fingerprint"
  assert_contains "$(grep '^invoking:' <<< "$OUT")" "--prefill-lens 8192 32768" "and the prefill lengths of the fingerprint"
}

run_all_tests
