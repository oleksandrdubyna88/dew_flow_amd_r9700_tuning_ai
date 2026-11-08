#!/usr/bin/env bash
# `bin/r9700 verdict <folder>` over a ComfyUI bench folder (E2.S3): the comfy ship test of lib/verdict.py through the dispatch of the verb. VD1 (a bench folder gets the comfy ship test: PASS, NOT DECIDED
# inside the spread, INCOMPLETE), VD2 (a series folder is read exactly as before), VD3 (the options), VD4 (an untrusted fingerprint is never judged as a bench), VD5 (a one-round bench says so), VD6
# (an arm reported inert on the workflow, with its evidence: open point N8 of the stories). The folders are built by the test from S1's grammar with the identity written through the verb's own calls
# (vd_fold, tests/lib/benchverbcase.sh), or made by a stub run of the verb (VD5, VD6). The verb's own cases are tests/test_comfy_bench_verb*.sh. Every test body is a function t_<guarantee>; each runs in its
# own subshell and writes only below $R9700_TEST_ROOT.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"
# shellcheck source=tests/lib/lifecycle.sh
source "$HERE/lib/lifecycle.sh"
# shellcheck source=tests/lib/benchverbcase.sh
source "$HERE/lib/benchverbcase.sh"

# fold2 <dir> <fp16acc total of run 1>: two arms, two rounds; the base's totals are 12.0, 12.1, 12.2 in both rounds (its spread is 0.2, its median 12.1)
fold2() {
  local dir="$1" arm round
  vd_fold "$dir" zimage 2 base fp16acc || return 1
  for round in 1 2; do
    vd_round "$dir" base "$round" 12.0
    vd_round "$dir" fp16acc "$round" "$2"
  done
}

# VD1
t_a_bench_folder_gets_the_comfy_ship_test() {
  bv_setup "$FUNCNAME"
  local dir="$OUTD" sha
  fold2 "$dir" 10.0 || return 1
  sha="$(python3 "$REPO/lib/fingerprint.py" show "$dir/fingerprint.json" sha256)"
  assert_exit 0 "verdict over a bench folder with fp16acc below the base spread" -- r9700 verdict "$dir"
  assert_eq "comfy bench $dir: workflow zimage, base base, 2 rounds, fingerprint ${sha:0:12}" "$(sed -n 1p <<< "$OUT")" "the head line"
  assert_contains "$OUT" "invoking: python3 " "the invoking line"
  assert_contains "$OUT" "verdict.py comfy --workflow zimage --metrics \"total_s sampler_s vae_s\" --decide total_s --direction lower --base base --arm fp16acc " "names the mode, the metrics, the deciding one and the direction"
  assert_contains "$OUT" "--bench $dir/rounds/base-1/bench.txt --bench $dir/rounds/base-2/bench.txt --bench $dir/rounds/fp16acc-1/bench.txt --bench $dir/rounds/fp16acc-2/bench.txt" "and the four record files, arm by arm and round by round"
  assert_contains "$OUT" "--rounds 2" "and the rounds"
  assert_contains "$OUT" "verdict fp16acc: PASS" "PASS: beyond the base spread, lower"
  assert_contains "$OUT" "total_s: median 10.100 vs 12.100, delta -2.000, base spread 0.200 -> lower" "with the exact numbers"
  vd_round "$dir" fp16acc 1 12.0
  vd_round "$dir" fp16acc 2 12.0
  assert_exit 0 "the same timings as the base" -- r9700 verdict "$dir"
  assert_contains "$OUT" "verdict fp16acc: NOT DECIDED (inside the base spread)" "NOT DECIDED, exit 0"
  vd_round "$dir" fp16acc 1 14.0
  vd_round "$dir" fp16acc 2 14.0
  assert_exit 0 "slower than the base spread" -- r9700 verdict "$dir"
  assert_contains "$OUT" "verdict fp16acc: FAIL (total_s higher than the base by more than its spread)" "FAIL"
  rm -rf "$dir/rounds/fp16acc-2"
  assert_exit 1 "a folder with fp16acc-2 missing" -- r9700 verdict "$dir"
  assert_contains "$OUT" "verdict fp16acc: INCOMPLETE (missing complete arm-rounds: fp16acc-2)" "INCOMPLETE, naming the round"
  kill_recorded_pids "$CASE"
}

# VD2
t_a_series_folder_is_read_exactly_as_before() {
  bv_setup "$FUNCNAME"
  local out="$R9700_RESULTS_DIR/series-s"
  build_fixture_outdir "$out"
  assert_exit 2 "a series fingerprint has no kind leaf" -- python3 "$REPO/lib/fingerprint.py" show "$out/fingerprint.json" kind
  assert_exit 0 "verdict over a series folder" -- r9700 verdict "$out"
  assert_eq "series $out: base fbase, 3 rounds, fingerprint $(json_get "$out/fingerprint.json" 'd["sha256"][:12]')" "$(sed -n 1p <<< "$OUT")" "the series head line, not the bench one"
  assert_contains "$OUT" "verdict.py ship --base fbase" "the vLLM ship test"
  assert_not_contains "$OUT" "comfy bench" "no comfy line"
  assert_contains "$OUT" "verdict fcombo: PASS" "and the recorded verdicts"
  kill_recorded_pids "$CASE"
}

# VD3
t_the_options_are_the_series_options_except_the_quality_gate_a_bench_does_not_have() {
  bv_setup "$FUNCNAME"
  local dir="$OUTD" json="$CASE/out.json"
  fold2 "$dir" 10.0 || return 1
  assert_exit 0 "--base fp16acc judges the base against fp16acc" -- r9700 verdict "$dir" --base fp16acc
  assert_contains "$OUT" "base fp16acc, 2 rounds" "the head line names the other base"
  assert_contains "$OUT" "--base fp16acc --arm base " "the invoking line"
  assert_contains "$OUT" "arm base vs fp16acc: 2 rounds" "and the report says which arm is judged"
  assert_exit 0 "--json <file> before the folder" -- r9700 verdict --json "$json" "$dir"
  assert_eq "fp16acc PASS" "$(json_get "$json" '" ".join([d[0]["arm"], d[0]["verdict"]])')" "S1's JSON was written"
  assert_eq "total_s" "$(json_get "$json" 'd[0]["decide"]["metric"]')" "with the deciding metric"
  assert_exit 2 "--no-quality on a bench folder" -- r9700 verdict "$dir" --no-quality
  assert_eq "r9700: verdict: --no-quality is for a series of vLLM arms; a comfy bench has no quality gate (its drift numbers are in each record)" "$ERR" "the one line"
  assert_not_contains "$OUT" "invoking:" "verdict.py was not called"
  assert_exit 2 "an unknown option" -- r9700 verdict "$dir" --frob
  assert_contains "$ERR" "unknown option \"--frob\"; legal: --base <arm>, --json <file>" "names the legal options"
  assert_exit 2 "--base with no value" -- r9700 verdict "$dir" --base
  assert_contains "$ERR" "--base needs a value" "is named"
  assert_exit 2 "a base that has no record" -- r9700 verdict "$dir" --base nosuch
  assert_contains "$ERR" "base arm \"nosuch\" has no complete arm-round in the inputs" "is named"
  kill_recorded_pids "$CASE"
}

# VD4
t_an_untrusted_bench_fingerprint_is_never_judged_as_a_bench() {
  bv_setup "$FUNCNAME"
  local dir="$OUTD"
  fold2 "$dir" 10.0 || return 1
  sed -i 's/"rounds": *2/"rounds": 3/' "$dir/fingerprint.json"
  assert_exit 1 "the edit has teeth: the file now says three rounds" -- test "$(grep -c '"rounds": *3' "$dir/fingerprint.json")" -eq 0
  assert_exit 2 "verdict over an edited fingerprint" -- r9700 verdict "$dir"
  assert_contains "$ERR" "the stored digest does not match" "the fingerprint's own line"
  assert_not_contains "$OUT" "invoking:" "verdict.py was not called"
  assert_not_contains "$OUT" "comfy bench" "and no bench head line was printed"
  kill_recorded_pids "$CASE"
}

# VD5
t_a_one_round_bench_says_so_and_a_lone_base_has_nothing_to_judge() {
  bv_setup "$FUNCNAME"
  assert_exit 0 "bench zimage base --rounds 1" -- bv zimage base --rounds 1
  assert_exit 0 "verdict over it" -- r9700 verdict "$OUTD"
  assert_contains "$OUT" "note: 1 round, 3 values per arm; the ship test of a series uses 3 rounds" "the one-round note"
  assert_contains "$OUT" "verdict: no arm besides the base to judge" "and the base alone has nothing to judge"
  assert_not_contains "$OUT" "invoking:" "verdict.py was not called"
  assert_not_contains "$OUT" "inert on" "and no arm is called inert"
  kill_recorded_pids "$CASE"
}

# VD6
t_an_arm_whose_record_says_inert_is_reported_as_inert_with_its_evidence_before_the_verdict() {
  bv_setup "$FUNCNAME"
  local first text
  printf 'Enabled fp16 accumulation.\nmodel weight dtype torch.bfloat16, manual cast: None\nVAE load device: cuda:0, offload device: cpu, dtype: torch.bfloat16\n' > "$STUB/answers/comfy_evidence.fp16acc"
  assert_exit 0 "bench zimage base fp16acc --rounds 1 with the bf16 evidence" -- bv zimage base fp16acc --rounds 1
  assert_exit 0 "verdict over it" -- r9700 verdict "$OUTD"
  text="$OUT" # assert_exit replaces OUT with the output of the command it runs
  assert_contains "$text" "note: fp16acc inert on zimage (" "the note names the arm and the workflow"
  assert_contains "$(grep '^note: fp16acc inert' <<< "$text")" "model weight dtype torch.bfloat16" "and holds the evidence the record kept (the model's line)"
  assert_contains "$(grep '^note: fp16acc inert' <<< "$text")" "dtype: torch.bfloat16" "and the VAE's"
  assert_not_contains "$text" "note: base inert" "the base is never inert"
  first="$(grep -n '^note: fp16acc inert' <<< "$text" | head -n 1 | cut -d: -f1)"
  assert_exit 0 "the note comes before the invoking line" -- test "$first" -lt "$(grep -n '^invoking:' <<< "$text" | head -n 1 | cut -d: -f1)"
  assert_eq "1" "$(grep -c '^note: fp16acc inert' <<< "$text")" "once"
  assert_contains "$text" "verdict fp16acc: NOT DECIDED" "the verdict follows"
  assert_not_contains "$text" "no gain" "no word of gain"
  kill_recorded_pids "$CASE"
}

run_all_tests
