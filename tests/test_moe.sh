#!/usr/bin/env bash
# The MoE units as workers under the E1 supervisor (E2.S2): the chunk unit and the kernel A/B unit of lib/moe.sh, their records, the Triton cache clear
# before every unit and in the exit path (the hook of lib/run_guarded.sh), the identity check of every placed asset. Scenarios T1-T17, T19 and T20 of the
# story (T18, the new fields and the moved budget rule, is in tests/test_config.sh with the rules it changes). Every test body is a function t_<guarantee>;
# each runs in its own subshell and writes only below $R9700_TEST_ROOT. "A stub chunk" is `step moe-chunk -- bash lib/moe.sh chunk <outdir> <model>
# int4-24 experts full 24`; "a stub A/B" is `step moe-ab -- bash lib/moe.sh ab <outdir> <model> draft each "1 4" 3 "1 2 3 4 6 8 12 16"` with the merged
# fixture of the b1 draft layer in the exchange folder (tests/lib/moecase.sh).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"
# shellcheck source=tests/lib/lifecycle.sh
source "$HERE/lib/lifecycle.sh"
# shellcheck source=tests/lib/moecase.sh
source "$HERE/lib/moecase.sh"

FIX_B2_NAME="$(basename "$(ls "$HERE"/fixtures/moe/b2/E=*.json)")"
FIX_B1_NAME="$(basename "$(ls "$HERE"/fixtures/moe/b1/E=*.json)")"
# the A/B of the story: the draft layer, rule `each` over 1 and 4, three reps, the eight batch sizes of the B1 night
AB_ARGS=(draft each "1 4" 3 "1 2 3 4 6 8 12 16")

# ---- T1-T4: the chunk record, its argv, its two modes, the cache clear -------------------------------------------------------------------------

t_t1_a_chunk_is_recorded_only_when_its_json_passes_check_and_the_record_carries_the_identity() {
  moe_setup "$FUNCNAME"
  local rec="$RECS/chunks/int4-24" env started finished
  assert_exit 0 "a stub chunk" -- moe_chunk int4-24 experts full 24
  assert_exit 0 "the record has the JSON under the name vLLM gave it (listed from the fixture, not typed)" -- test -s "$rec/$FIX_B2_NAME"
  assert_eq "1" "$(ls "$rec"/E=*.json | wc -l | tr -d ' ')" "and exactly one E=*.json"
  assert_exit 0 "chunk.log" -- test -s "$rec/chunk.log"
  assert_exit 0 "chunk.summary" -- test -s "$rec/chunk.summary"
  env="$rec/chunk.env"
  assert_eq "24" "$(env_get "$env" KEYS)" "KEYS"
  assert_eq "experts" "$(env_get "$env" LAYER)" "LAYER"
  assert_eq "full" "$(env_get "$env" SEARCH)" "SEARCH"
  assert_eq "int4_w4a16" "$(env_get "$env" DTYPE)" "DTYPE"
  assert_eq "$(sha256sum "$REPO/vendor/benchmark_moe.py" | cut -d' ' -f1)" "$(env_get "$env" BENCHMARK_SHA256)" "BENCHMARK_SHA256 is the hash of vendor/benchmark_moe.py"
  assert_eq "$R9700_IMAGE" "$(env_get "$env" IMAGE)" "IMAGE is the config's"
  assert_eq "$R9700_MODEL_DIR" "$(env_get "$env" MODEL_DIR)" "MODEL_DIR is the config's"
  assert_eq "0" "$(env_get "$env" RC)" "RC=0"
  assert_eq "${R9700_CONTAINER_PREFIX}moe-tune-int4-24" "$(env_get "$env" CONTAINER)" "CONTAINER"
  assert_eq "$(basename "$(last_run_dir)")" "$(env_get "$env" RUN_ID)" "RUN_ID is the run folder's name"
  started="$(env_get "$env" STARTED_AT)"
  finished="$(env_get "$env" FINISHED_AT)"
  if [[ $started =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ && ! $started > $finished ]]; then assert_eq ok ok "STARTED_AT <= FINISHED_AT, both UTC"; else assert_eq "UTC, ordered" "$started $finished" "STARTED_AT <= FINISHED_AT"; fi
  assert_eq "0" "$(find "$RECS/chunks" -name '*.part-*' | wc -l | tr -d ' ')" "no .part- directory remains"
  assert_exit 0 "check accepts the recorded JSON" -- python3 "$REPO/lib/merge_moe.py" check --keys 24 "$rec/$FIX_B2_NAME"
  assert_eq "1" "$(prod_stops)" "the operator's server was stopped once"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "and restored once"
  assert_eq "done" "$(cat "$(last_run_dir)/status")" "the run's status is done"
}

t_t2_the_container_argv_is_the_measured_one() {
  moe_setup "$FUNCNAME"
  moe_chunk int4-24 experts full 24 > /dev/null 2>&1
  run_argv moe-tune-int4-24
  local got expect
  got="$(IFS='|'; echo "${ARGV[*]}")"
  expect="run|--rm|--name|r9700tune-moe-tune-int4-24|--gpus|all|--shm-size|16g|-e|HIP_VISIBLE_DEVICES=0|-e|TRITON_CACHE_DIR=/root/.cache/vllm/triton-moe-tune"
  expect+="|-v|hf-cache:/root/.cache/huggingface|-v|vllm-cache:/root/.cache/vllm|-v|C:\\r9700\\work:/work|-w|/work/r9700|$R9700_IMAGE|python3|benchmark_moe.py"
  expect+="|--model|/root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ|--tp-size|1|--dtype|int4_w4a16|--tune|--batch-size|24"
  expect+="|--save-dir|/work/r9700/moe/qwen3.6-35b-a3b-gptq/tune/int4-24|--trust-remote-code"
  assert_eq "$expect" "$got" "the argv of tune_chunk.sh lines 14-17 through the adapter, as an array"
  assert_not_contains "$got" "MOE_TUNE_" "and no MOE_TUNE_ word for the experts layer with the full search"
}

t_t3_the_draft_layer_and_the_coarse_search_set_exactly_their_two_environment_words() {
  moe_setup "$FUNCNAME"
  chunk_json_for b1 256 1024 2048
  assert_exit 0 "a draft coarse chunk" -- moe_chunk draft-c draft coarse 256 1024 2048
  run_argv moe-tune-draft-c
  local got
  got="$(IFS='|'; echo "${ARGV[*]}")"
  assert_contains "$got" "|-e|MOE_TUNE_ACT_DTYPE=bfloat16|" "the activation hook of the draft layer"
  assert_contains "$got" "|-e|MOE_TUNE_CANDIDATES=/work/r9700/coarse_candidates.json|" "the candidates of the coarse search"
  assert_contains "$got" "|--dtype|auto|" "the draft layer's dtype"
  assert_contains "$got" "|--batch-size|256|1024|2048|" "the keys, one word each"
  assert_exit 0 "the record's JSON has the draft layer's file name" -- test -s "$RECS/chunks/draft-c/$FIX_B1_NAME"
  assert_eq "$(sha256sum "$REPO/config/coarse_candidates.json" | cut -d' ' -f1)" "$(env_get "$RECS/chunks/draft-c/chunk.env" CANDIDATES_SHA256)" "CANDIDATES_SHA256 is the file's hash"
  assert_eq "bfloat16" "$(env_get "$RECS/chunks/draft-c/chunk.env" ACT_DTYPE)" "ACT_DTYPE"
  assert_eq "auto" "$(env_get "$RECS/chunks/draft-c/chunk.env" DTYPE)" "DTYPE"
  moe_chunk exp-f experts full 256 > /dev/null 2>&1
  run_argv moe-tune-exp-f
  assert_not_contains "$(IFS='|'; echo "${ARGV[*]}")" "MOE_TUNE_" "with experts and the full search neither word appears (the same fixture, the negative)"
}

t_t4_the_cache_is_cleared_before_the_unit_by_a_prefixed_container_with_only_the_cache_volume() {
  moe_setup "$FUNCNAME"
  moe_chunk int4-24 experts full 24 > /dev/null 2>&1
  local clear tune
  clear="$(run_lines moe-clear | head -n 1)"
  tune="$(run_lines moe-tune-int4-24 | head -n 1)"
  assert_exit 0 "a moe-clear run line exists" -- test -n "$clear"
  assert_exit 0 "and it precedes the chunk's run line" -- test "${clear:-999}" -lt "${tune:-0}"
  run_argv moe-clear
  local got
  got="$(IFS='|'; echo "${ARGV[*]}")"
  assert_contains "$got" "run|--rm|--name|r9700tune-moe-clear|-v|vllm-cache:/root/.cache/vllm|$R9700_IMAGE|sh|-c|" "the clear: a prefixed name, ONLY the cache volume, the image, sh -c"
  assert_not_contains "$got" "--gpus" "no GPU"
  assert_contains "$got" "rm -rf /root/.cache/vllm/triton-moe-tune /root/.cache/vllm/triton-moe-ab" "the program removes both cache folders"
  assert_contains "$(worker_log 1)" "cache before clear: 1.3G" "the worker log keeps what the cache held"
  assert_eq "1" "$([ "$(worker_log 1 | grep -n '^cache clear: running (ceiling 90 s)' | head -n 1 | cut -d: -f1)" -lt "$(worker_log 1 | grep -n '^cache before clear' | head -n 1 | cut -d: -f1)" ] && echo 1 || echo 0)" "a start line names the ceiling BEFORE the clear container ends"
}

# ---- T5-T8: what is not recorded, and what is not run again ------------------------------------------------------------------------------------

t_t5_a_half_written_chunk_is_deleted_before_the_run_and_the_record_is_rejected_with_its_log() {
  moe_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  rm -rf "$STUB/answers/moe_json"
  mkdir -p "$EX/tune/int4-24"
  cp "$HERE/fixtures/moe/b2/$FIX_B2_NAME" "$EX/tune/int4-24/E=stale.json" # what a half-written chunk of an earlier run left: a file that would pass check
  assert_exit 7 "a stub chunk whose container wrote nothing" -- moe_chunk int4-24 experts full 24
  local rej
  rej="$(ls -d "$RECS"/rejected/int4-24-* 2> /dev/null | head -n 1)"
  assert_exit 0 "rejected/int4-24-<stamp>/ exists" -- test -d "$rej"
  assert_exit 0 "with the chunk's log" -- test -e "$rej/chunk.log"
  if [[ "$(cat "$rej/reason")" == "no E=*.json"* || "$(cat "$rej/reason")" == "check: "* ]]; then assert_eq ok ok "its reason starts 'no E=*.json' or 'check: '"; else assert_eq "no E=*.json" "$(cat "$rej/reason")" "its reason"; fi
  assert_missing "$RECS/chunks/int4-24" "no record"
  assert_eq "0" "$(ls -A "$EX/tune/int4-24" | wc -l | tr -d ' ')" "the exchange folder is empty: the stale file was deleted before the run, so it was never taken for a result"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the server was restored once"
  chunk_json_for b2 24
  assert_exit 0 "the same command with the answer present" -- moe_chunk int4-24 experts full 24
  assert_exit 0 "now the record exists" -- test -s "$RECS/chunks/int4-24/$FIX_B2_NAME"
  assert_exit 0 "and the rejected entry is still there" -- test -d "$rej"
  assert_eq "2" "$(run_lines moe-tune-int4-24 | wc -l | tr -d ' ')" "the container ran twice (once per command): the same run line"
}

t_t6_a_chunk_that_delivered_fewer_keys_than_promised_is_rejected_by_check_naming_the_sets() {
  moe_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  chunk_json_for b2 24
  assert_exit 7 "a chunk of keys 24 32 whose file holds key 24 only" -- moe_chunk int4-24-32 experts full 24 32
  local rej
  rej="$(ls -d "$RECS"/rejected/int4-24-32-* | head -n 1)"
  assert_contains "$(cat "$rej/reason")" "keys [24] != expected [24, 32]" "the reason names both sets"
  assert_missing "$RECS/chunks/int4-24-32" "no record"
}

t_t7_a_non_zero_container_exit_is_a_rejected_chunk_never_a_record() {
  moe_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  printf '1\n' > "$STUB/answers/moe_tune_rc"
  assert_exit 7 "a good file but rc 1" -- moe_chunk int4-24 experts full 24
  local rej
  rej="$(ls -d "$RECS"/rejected/int4-24-* | head -n 1)"
  if [[ "$(cat "$rej/reason")" == "rc=1"* ]]; then assert_eq ok ok "the reason starts rc=1"; else assert_eq "rc=1..." "$(cat "$rej/reason")" "the reason starts rc=1"; fi
  assert_eq "1" "$(env_get "$rej/chunk.env" RC)" "chunk.env in the rejected folder has RC=1"
  assert_missing "$RECS/chunks/int4-24" "no record"
}

t_t8_a_recorded_chunk_is_not_run_again() {
  moe_setup "$FUNCNAME"
  moe_chunk int4-24 experts full 24 > /dev/null 2>&1
  local before after
  before="$(stat -c %Y "$RECS/chunks/int4-24")"
  assert_exit 0 "the same stub chunk again" -- moe_chunk int4-24 experts full 24
  assert_contains "$(worker_log 1)" "chunk int4-24: recorded, nothing to do" "the worker says so"
  assert_eq "1" "$(run_lines moe-tune-int4-24 | wc -l | tr -d ' ')" "the call log has no second moe-tune run"
  after="$(stat -c %Y "$RECS/chunks/int4-24")"
  assert_eq "$before" "$after" "the record's mtime is unchanged"
}

# ---- T14-T16: the kernel A/B -------------------------------------------------------------------------------------------------------------------

# ab_variant: the 35B model with an empty TUNED_CONFIG_DIR (B1's shape: the default arm is vLLM's own config)
ab_variant() {
  grep -v '^TUNED_CONFIG_DIR=' "$MODEL_35B" > "$CASE/model.env"
  MODEL="$CASE/model.env"
}

t_t14_the_ab_records_six_logs_the_table_and_the_decision_and_the_arms_get_the_measured_folders() {
  moe_setup "$FUNCNAME"
  ab_variant
  moe_merged_place b1
  moe_ab_answers "/work/r9700/moe/$MOE_MODEL/merged" "$FIX_B1_NAME"
  assert_exit 0 "a stub A/B" -- moe_ab "${AB_ARGS[@]}"
  local ab bline names rep arm
  ab="$(ls -d "$RECS"/ab/*/ | head -n 1)"
  ab="${ab%/}"
  assert_exit 0 "ab/<stamp>/ exists" -- test -d "$ab"
  for rep in 1 2 3; do
    for arm in default tuned; do
      assert_eq "22" "$(wc -l < "$ab/$arm-$rep.log" | tr -d ' ')" "$arm-$rep.log: 22 lines (a log of its own, never appended to)"
      assert_eq "1" "$(grep -c '^Batch size: 1,' "$ab/$arm-$rep.log")" "$arm-$rep.log: the key 1 once"
    done
  done
  assert_eq "0" "$(grep -c $'\r' "$ab"/*.log | awk -F: '{ n += $2 } END { print n + 0 }')" "CRs are removed from every log"
  assert_eq "$(cat "$HERE/fixtures/moe/b1_ab/expected.txt")" "$(grep -v -E '^(default|tuned) bs (2|3|6|8|12|16) config: ' "$ab/summary.txt")" "summary.txt is the recorded table of the B1 night (its config lines for bs 1 and 4, and one more per other size)"
  assert_eq "KERNEL: faster (each of 1 4 is faster by more than 3 %)" "$(cat "$ab/decision.txt")" "decision.txt is the last line"
  assert_eq "/work/r9700/moe/$MOE_MODEL/merged" "$(env_get "$ab/ab.env" B_FOLDER)" "B_FOLDER"
  assert_eq "" "$(env_get "$ab/ab.env" A_FOLDER)" "A_FOLDER is empty"
  assert_eq "$FIX_B1_NAME" "$(env_get "$ab/ab.env" B_FILE)" "B_FILE is the file found in merged/ (listed, not typed)"
  assert_eq "$(sha256sum "$HERE/fixtures/moe/b1/$FIX_B1_NAME" | cut -d' ' -f1)" "$(env_get "$ab/ab.env" B_SHA256)" "B_SHA256 is the merged fixture's"
  bline="Using configuration from /work/r9700/moe/$MOE_MODEL/merged/$FIX_B1_NAME for MoE layer"
  assert_contains "$(env_get "$ab/ab.env" B_CONFIG_LINE)" "$bline" "B_CONFIG_LINE is the line the tuned arm printed"
  assert_contains "$(env_get "$ab/ab.env" A_CONFIG_LINE)" "Using default MoE config" "A_CONFIG_LINE is the default log's line"
  assert_eq "absent" "$(env_get "$ab/ab.env" HARNESS_SHA256)" "HARNESS_SHA256=absent"
  assert_eq "each" "$(env_get "$ab/ab.env" RULE)" "RULE"
  assert_eq "1 4" "$(env_get "$ab/ab.env" RULE_KEYS)" "RULE_KEYS"
  assert_eq "3" "$(env_get "$ab/ab.env" REPS)" "REPS"
  names="$(for rep in 1 2 3; do printf '%s ' "default-$rep" "tuned-$rep"; done)"
  assert_eq "$names" "$(run_lines_ab | tr '\n' ' ')" "six containers, rep by rep, default then tuned"
  run_argv moe-ab-tuned-1
  local got
  got="$(IFS='|'; echo "${ARGV[*]}")"
  assert_contains "$got" "|-e|TRITON_CACHE_DIR=/root/.cache/vllm/triton-moe-ab|" "the A/B cache folder"
  assert_contains "$got" "|--dtype|auto|" "the draft layer's dtype"
  assert_contains "$got" "|-e|MOE_TUNE_ACT_DTYPE=bfloat16|" "the draft layer's activation hook"
  assert_not_contains "$got" "|--tune|" "no --tune"
  assert_not_contains "$got" "--save-dir" "no --save-dir"
  assert_contains "$got" "|-e|VLLM_TUNED_CONFIG_FOLDER=/work/r9700/moe/$MOE_MODEL/merged|" "the tuned arm reads the activated folder"
  run_argv moe-ab-default-1
  assert_not_contains "$(IFS='|'; echo "${ARGV[*]}")" "VLLM_TUNED_CONFIG_FOLDER" "the default arm sets no folder (vLLM's own config)"
  assert_eq "7" "$(grep -c Get-WinEvent "$STUB/calls.log")" "the disk gate was read before each of the six containers, after the admission's baseline"
  assert_eq "done" "$(cat "$(last_run_dir)/status")" "the run is done"
}

# run_lines_ab: the <arm>-<rep> words of every moe-ab run line, in order
run_lines_ab() { sed -n "s/.* wslc run --rm --name ${R9700_CONTAINER_PREFIX}moe-ab-\([a-z]*-[0-9]*\) .*/\1/p" "$STUB/calls.log"; }

t_t14b_with_a_production_folder_set_the_default_arm_reads_it() {
  moe_setup "$FUNCNAME"
  moe_merged_place b1
  moe_ab_answers "/work/r9700/moe/$MOE_MODEL/merged" "$FIX_B1_NAME"
  assert_exit 0 "a stub A/B with the unedited 35B model (TUNED_CONFIG_DIR=/work/moe/tune/merged)" -- moe_ab "${AB_ARGS[@]}"
  run_argv moe-ab-default-1
  assert_contains "$(IFS='|'; echo "${ARGV[*]}")" "|-e|VLLM_TUNED_CONFIG_FOLDER=/work/moe/tune/merged|" "the default arm gets the production folder (B2's shape)"
  assert_eq "/work/moe/tune/merged" "$(env_get "$(ls -d "$RECS"/ab/*/ | head -n 1)ab.env" A_FOLDER)" "A_FOLDER in ab.env"
}

t_t15_a_short_log_or_a_tuned_arm_that_did_not_load_the_activated_file_makes_no_ab_record() {
  moe_setup "$FUNCNAME"
  ab_variant
  step_cfg MAX_FAILED_TRIES=1
  moe_merged_place b1
  moe_ab_answers "/work/r9700/moe/$MOE_MODEL/merged" "$FIX_B1_NAME"
  rm -f "$STUB"/answers/moe_ab.tuned.*
  head -n 20 "$HERE/fixtures/moe/b1_ab/tuned-1.log" | sed "s|Using configuration from [^ ]* for MoE layer|Using configuration from /work/r9700/moe/$MOE_MODEL/merged/$FIX_B1_NAME for MoE layer|" > "$STUB/answers/moe_ab.tuned"
  assert_exit 7 "a tuned log without its last two lines (7 kernel times)" -- moe_ab "${AB_ARGS[@]}"
  local rej
  rej="$(ls -d "$RECS"/rejected/ab-* | head -n 1)"
  assert_eq "tuned-1.log: 7 kernel times, expected 8" "$(cat "$rej/reason")" "the reason names the log and both counts"
  assert_eq "" "$(ls -A "$RECS/ab")" "no A/B record: ab/ holds nothing"
  assert_exit 0 "the three default logs are in the rejected folder" -- test -s "$rej/default-1.log" -a -s "$rej/default-2.log" -a -s "$rej/default-3.log"
  assert_exit 0 "and so is the short tuned log" -- test -s "$rej/tuned-1.log"
  # the second half: a complete tuned log that says it loaded ANOTHER file
  rm -rf "$RECS" "$STUB/calls.log" "$STUB/calls.argv"
  cp "$HERE/fixtures/moe/b1_ab/tuned-1.log" "$STUB/answers/moe_ab.tuned" # its line still names the 2026-10-31 path /moe/tune/merged_b1/...
  assert_exit 7 "a tuned log whose Using configuration line is not the activated file's" -- moe_ab "${AB_ARGS[@]}"
  rej="$(ls -d "$RECS"/rejected/ab-* | head -n 1)"
  assert_eq "tuned-1.log: no \"Using configuration from /work/r9700/moe/$MOE_MODEL/merged/$FIX_B1_NAME\" line (found: Using configuration from /moe/tune/merged_b1/$FIX_B1_NAME for MoE layer)" "$(cat "$rej/reason")" "the reason names the wanted and the found line"
  assert_eq "" "$(ls -A "$RECS/ab")" "no A/B record: ab/ holds nothing"
}

t_t16_an_ab_without_a_merged_file_is_refused_before_any_container_and_step_stops_at_once() {
  moe_setup "$FUNCNAME"
  ab_variant
  mkdir -p "$EX/merged"
  assert_exit 2 "a stub A/B with an empty merged folder" -- moe_ab "${AB_ARGS[@]}"
  local run
  run="$(last_run_dir)"
  outcome_read "$run/steps/1.outcome"
  assert_eq "refused" "$O_KIND" "the worker's outcome is KIND=refused"
  assert_contains "$O_DETAIL" "merged/ holds no activate.env" "its detail"
  assert_eq "0" "$(run_lines_ab | wc -l | tr -d ' ')" "no moe-ab container ran"
  assert_eq "0" "$(run_lines moe-clear | wc -l | tr -d ' ')" "and no container of any kind (the identity check comes before the cache clear)"
  assert_eq "1" "$(prod_stops)" "one admission: the server was stopped once, no retry"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "and restored once"
}

# ---- T17: the identity check covers every placed asset, whatever the mode ----------------------------------------------------------------------

# assets_of: `<placed name> <repository source> <required|optional>` per line, from the table the product iterates
assets_of() { moe_assets; }

t_t17_every_placed_asset_is_checked_on_every_unit_whatever_the_mode() {
  moe_setup "$FUNCNAME"
  ab_variant
  step_cfg MAX_FAILED_TRIES=1
  local name source need n=0 placed hash run line
  local -a assets=()
  mapfile -t assets < <(assets_of)
  for line in "${assets[@]}"; do
    read -r name source need _ <<< "$line"
    n=$((n + 1))
    placed="$WORK/$name"
    [ -f "$placed" ] || cp "$REPO/$source" "$placed"
    printf 'x' >> "$placed"
    assert_exit 2 "$name differs: a stub chunk (experts, full: a mode that uses none of the optional files) is refused" -- moe_chunk "id-$n" experts full 24
    run="$(last_run_dir)"
    outcome_read "$run/steps/1.outcome"
    assert_eq "refused" "$O_KIND" "$name: KIND=refused"
    assert_contains "$O_DETAIL" "$name in the work folder differs from $source" "$name: the detail names the asset and its source"
    assert_eq "0" "$(run_lines "moe-tune-id-$n" | wc -l | tr -d ' ')" "$name: no chunk container ran"
    moe_merged_place b1
    moe_ab_answers "/work/r9700/moe/$MOE_MODEL/merged" "$FIX_B1_NAME"
    assert_exit 2 "$name differs: a stub A/B is refused too" -- moe_ab "${AB_ARGS[@]}"
    assert_eq "0" "$(run_lines_ab | wc -l | tr -d ' ')" "$name: no A/B container ran"
    cp "$REPO/$source" "$placed"
    hash="$(sha256sum "$REPO/$source" | cut -d' ' -f1)"
    assert_exit 0 "$name exact again: a stub chunk is recorded" -- moe_chunk "ok-$n" experts full 24
    if [ "$need" = optional ]; then
      assert_eq "$hash" "$(env_get "$RECS/chunks/ok-$n/chunk.env" HARNESS_SHA256)" "$name (optional): its hash is recorded when the file is there"
      rm -f "$placed"
      assert_exit 0 "$name absent: a stub chunk is recorded" -- moe_chunk "gone-$n" experts full 24
      assert_eq "absent" "$(env_get "$RECS/chunks/gone-$n/chunk.env" HARNESS_SHA256)" "$name (optional): absent is recorded as absent"
    else
      mv "$placed" "$placed.away"
      assert_exit 2 "$name (required) missing: refused" -- moe_chunk "miss-$n" experts full 24
      outcome_read "$(last_run_dir)/steps/1.outcome"
      assert_contains "$O_DETAIL" "$name" "$name (required): the detail names it"
      mv "$placed.away" "$placed"
    fi
  done
  if [ "$n" -ge 3 ]; then assert_eq ok ok "the loop derived the assets from the table ($n of them: the benchmark, the candidates, the harness)"; else assert_eq ">= 3" "$n" "the table lists the three assets"; fi
}

# ---- T9-T13, T19, T20: the guards and the exit path (the cache clear hook) ----------------------------------------------------------------------

# session_of_run: the worker's session id from the supervisor log of the newest run
session_of_run() { sup_log | sed -n 's/.*worker started: session \([0-9]*\),.*/\1/p' | head -n 1; }

t_t9_a_ram_stop_during_a_chunk_leaves_no_prefixed_container_no_worker_process_and_clears_the_cache_in_the_exit_path() {
  moe_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  ram_stop_run
  local run sid stop clear pwsh
  run="$(last_run_dir)"
  assert_eq "7" "$SRC" "the supervisor exits 7 (MAX_FAILED_TRIES=1)"
  outcome_read "$run/steps/1.outcome"
  assert_eq "ram_guard" "$O_KIND" "the outcome is KIND=ram_guard"
  assert_eq "0" "$(wslc list | grep -c "^${R9700_CONTAINER_PREFIX}")" "after the exit the stub's wslc list shows no ${R9700_CONTAINER_PREFIX} name"
  assert_missing "$STUB/containers/${R9700_CONTAINER_PREFIX}moe-tune-int4-24.pid" "and the chunk container's record is gone"
  sid="$(session_of_run)"
  assert_exit 0 "the log names the worker's session" -- test -n "$sid"
  assert_eq "0" "$(session_pids "$sid" | wc -l | tr -d ' ')" "no process of the worker's session is left"
  stop="$(line_of " wslc stop ${R9700_CONTAINER_PREFIX}moe-tune-int4-24")"
  clear="$(last_line_of " wslc run --rm --name ${R9700_CONTAINER_PREFIX}moe-clear ")"
  pwsh="$(line_of " pwsh.exe ")"
  if [ -n "$stop" ] && [ "$stop" -lt "$clear" ] && [ "$clear" -lt "$pwsh" ]; then assert_eq ok ok "in the call log: the stop (line $stop), then the exit-path clear (line $clear), then the restore (line $pwsh)"; else assert_eq "stop < clear < restore" "$stop $clear $pwsh" "the order in the call log"; fi
  assert_contains "$(sup_log)" "cleanup hook: moe_cache_clear rc=0" "the supervisor log says the hook ended with rc=0"
  # The guard stops the chunk container and the worker's session. A worker still alive after the container stop rejects its part into
  # rejected/; one the session kill reaches first leaves it in chunks/ for the next start's sweep. Both keep the attempt and make no record
  # (CI failed on "stays in chunks/" alone on 2026-11-03), so the guarantee is: exactly one kept attempt, and no final record.
  local parts rejected
  parts="$(find "$RECS/chunks" -maxdepth 1 -name '*.part-*' | wc -l | tr -d ' ')"
  rejected="$(find "$RECS/rejected" -maxdepth 1 -mindepth 1 -name 'int4-24*' 2> /dev/null | wc -l | tr -d ' ')"
  assert_eq "1" "$((parts + rejected))" "the attempt is kept once: a part in chunks/ ($parts) or a record in rejected/ ($rejected)"
  assert_missing "$RECS/chunks/int4-24" "and no final chunk record"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the server was restored once"
}

t_t10_a_stale_part_directory_is_evidence_not_a_record() {
  moe_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  ram_stop_run
  local part
  part="$(ls -d "$RECS"/chunks/*.part-* | head -n 1)"
  part="${part##*/}"
  printf '0\n' > "$STUB/answers/moe_tune_seconds"
  printf '8000\n' > "$STUB/answers/ram"
  assert_exit 0 "a stub chunk after the stop" -- moe_chunk int4-24 experts full 24
  assert_contains "$(worker_log 1 | head -n 3)" "moe: $part moved to rejected/int4-24-" "its first stdout lines say the old part moved to rejected/"
  assert_exit 0 "the old chunk.log is inside" -- test -e "$(ls -d "$RECS"/rejected/int4-24-* | head -n 1)/chunk.log"
  assert_contains "$(cat "$(ls -d "$RECS"/rejected/int4-24-* | head -n 1)/reason")" "INTERRUPTED: " "with an INTERRUPTED reason"
  assert_exit 0 "and the chunk ran and is recorded" -- test -s "$RECS/chunks/int4-24/$FIX_B2_NAME"
}

t_t11_an_interrupt_clears_the_cache_once_and_the_second_signal_does_not_run_it_again() {
  moe_setup "$FUNCNAME"
  printf '100\n' > "$STUB/answers/moe_tune_seconds"
  body_args int4-24 experts full 24
  moe_sup_bg body_chunk
  wait_for "$STUB/containers/${R9700_CONTAINER_PREFIX}moe-tune-int4-24.pid" 100
  kill -TERM "$SUP"
  sleep 0.2
  kill -TERM "$SUP" 2> /dev/null
  step_end
  local started clear_lines
  assert_eq "143" "$SRC" "exit 143"
  started="$(run_lines moe-tune-int4-24 | head -n 1)"
  clear_lines="$(run_lines moe-clear | awk -v s="$started" '$1 > s' | wc -l | tr -d ' ')"
  assert_eq "1" "$clear_lines" "exactly one moe-clear run after the chunk container started (the session kill ended it: no stop call is needed)"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the server was restored once"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_eq "1" "$(sup_log | grep -c 'cleanup hook:')" "one cleanup hook line"
}

# hung_hook_run <mode>: the RAM stop of T9 with a cache-clear container that hangs once the chunk container has started (the on-stop script of
# the chunk container sets the stub's moe_clear_mode, so the clear before the unit and the restore's own calls are not touched)
hung_hook_run() {
  step_cfg MAX_FAILED_TRIES=1
  export R9700_CEILING_SCALE=100
  printf 'printf "%%s\\n" "%s" > "%s/moe_clear_mode"\n' "$1" "$STUB" > "$STUB/on-start-${R9700_CONTAINER_PREFIX}moe-tune-int4-24"
  ram_stop_run
}

assert_hung_hook_killed() {
  local clear pwsh pid
  assert_eq "7" "$SRC" "exit 7"
  assert_contains "$(sup_log)" "cleanup hook: moe_cache_clear timeout after 1 s, killed" "the supervisor log says the hook was killed at its ceiling (60 s / 100, rounded up)"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the restore still ran, once"
  clear="$(last_stamp_of " wslc run --rm --name ${R9700_CONTAINER_PREFIX}moe-clear ")"
  pwsh="$(last_stamp_of " pwsh.exe ")"
  if awk -v c="$clear" -v p="$pwsh" 'BEGIN { exit !(p - c < 2 && p - c > 0.4) }'; then assert_eq ok ok "the restore's call is $(awk -v c="$clear" -v p="$pwsh" 'BEGIN { printf "%.2f", p - c }') s after the clear (the hook window, then at once; under 2 s)"; else assert_eq "0.4 < delta < 2" "$(awk -v c="$clear" -v p="$pwsh" 'BEGIN { print p - c }')" "the restore's call follows the clear within 2 s"; fi
  assert_eq "" "$(hung_alive | tr '\n' ' ')" "no process of the hook's tree is alive afterwards (every pid recorded in hung/containers)"
  assert_exit 0 "at least one hung process was recorded (the case really hung)" -- test -n "$(ls "$STUB"/hung/containers/*.pid 2> /dev/null)"
  assert_missing "$MARKER_FILE" "the marker is gone"
}

t_t12_a_hung_hook_that_ignores_term_is_killed_at_its_ceiling_and_the_restore_still_runs() {
  moe_setup "$FUNCNAME"
  hung_hook_run hang-ignore-term
  assert_hung_hook_killed
  unhang_all
}

t_t12b_a_hung_hook_that_obeys_term_is_killed_at_its_ceiling_too() {
  moe_setup "$FUNCNAME"
  hung_hook_run hang
  assert_hung_hook_killed
  unhang_all
}

# short_deadline: T_END 26.4 s and T_STOP 9.4 s after the start (time scale 25, like E1's short_variant): the new rule 60 + 365 holds with
# CLEANUP_BUDGET_S=425. T_STOP is rounded down to a whole second, and the admission, the worker start, the hashes, the gate, the clear and the chunk
# start must all fit before it: at scale 100 it came 0.75-1.75 s after the start and the test was flaky. The ceilings keep their own scale (T19 sets it).
short_deadline() { step_cfg MAX_RUN_MINUTES=11 CLEANUP_BUDGET_S=425 READY_TIMEOUT_S=60; export R9700_TIME_SCALE=25; }

t_t13_the_deadline_ends_a_chunk_and_the_part_becomes_evidence() {
  moe_setup "$FUNCNAME"
  short_deadline
  printf '100\n' > "$STUB/answers/moe_tune_seconds"
  body_args int4-24 experts full 24
  moe_sup_bg body_chunk
  step_end
  local run
  run="$(last_run_dir)"
  assert_eq "6" "$SRC" "exit 6"
  outcome_read "$run/steps/1.outcome"
  assert_eq "deadline" "$O_KIND" "KIND=deadline"
  for _w in $(seq 1 30); do [ -e "$STUB/containers/${R9700_CONTAINER_PREFIX}moe-tune-int4-24.pid" ] || break; sleep 0.1; done # the stub removes its record on its own TERM trap: a loaded machine may be a moment late
  assert_missing "$STUB/containers/${R9700_CONTAINER_PREFIX}moe-tune-int4-24.pid" "the chunk container is stopped (its record is gone)"
  assert_eq "2" "$(run_lines moe-clear | wc -l | tr -d ' ')" "the exit-path clear ran: the one before the unit and one more"
  assert_eq "1" "$(find "$RECS/chunks" -maxdepth 1 -name '*.part-*' | wc -l | tr -d ' ')" "the part stays"
  printf '0\n' > "$STUB/answers/moe_tune_seconds"
  sed -i '/^MAX_RUN_MINUTES=/d; /^CLEANUP_BUDGET_S=/d; /^READY_TIMEOUT_S=/d' "$CASE/machine.env" # a whole invocation does not fit the short variant
  assert_exit 0 "the next stub chunk (with the default deadline)" -- moe_chunk int4-24 experts full 24
  assert_contains "$(cat "$(ls -d "$RECS"/rejected/int4-24-* | head -n 1)/reason")" "INTERRUPTED: " "its start moved the part to rejected/ with an INTERRUPTED reason"
}

t_t19_a_run_that_reaches_the_cleanup_at_its_deadline_cuts_the_hook_and_still_completes_the_restore_before_t_end() {
  moe_setup "$FUNCNAME"
  short_deadline
  export R9700_CEILING_SCALE=100
  printf 'printf "%%s\\n" "hang-ignore-term" > "%s/moe_clear_mode"\n' "$STUB" > "$STUB/on-start-${R9700_CONTAINER_PREFIX}moe-tune-int4-24"
  printf '100\n' > "$STUB/answers/moe_tune_seconds"
  body_args int4-24 experts full 24
  local before after run log n_deadline n_hook n_restored
  before="$(date +%s.%N)"
  moe_sup_bg body_chunk
  step_end
  after="$(date +%s.%N)"
  run="$(last_run_dir)"
  log="$(sup_log)"
  assert_eq "6" "$SRC" "exit 6"
  n_deadline="$(grep -n 'deadline' <<< "$log" | head -n 1 | cut -d: -f1)"
  n_hook="$(grep -n 'cleanup hook: moe_cache_clear timeout after 1 s, killed' <<< "$log" | head -n 1 | cut -d: -f1)"
  n_restored="$(grep -n ' restored$' <<< "$log" | tail -n 1 | cut -d: -f1)"
  if [ -n "$n_deadline" ] && [ -n "$n_hook" ] && [ -n "$n_restored" ] && [ "$n_deadline" -lt "$n_hook" ] && [ "$n_hook" -lt "$n_restored" ]; then assert_eq ok ok "the supervisor log has, in order: deadline (line $n_deadline), the hook killed (line $n_hook), restored (line $n_restored)"; else assert_eq "deadline < hook killed < restored" "$n_deadline $n_hook $n_restored" "the order in the supervisor log"; fi
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
  assert_eq "" "$(hung_alive | tr '\n' ' ')" "no process of the hook's tree is alive"
  assert_missing "$MARKER_FILE" "the marker is gone"
  # the arithmetic: T_END is 26.4 s after the start, T_STOP 9.4 s; the hook takes 0.6 + 0.05 s, the restore a start and one readiness round
  if awk -v b="$before" -v a="$after" 'BEGIN { exit !(a - b < 26.4) }'; then assert_eq ok ok "the whole invocation ended $(awk -v b="$before" -v a="$after" 'BEGIN { printf "%.2f", a - b }') s after its start, before T_END (26.4 s)"; else assert_eq "< 26.4 s" "$(awk -v b="$before" -v a="$after" 'BEGIN { print a - b }')" "the invocation ended before T_END"; fi
  unhang_all
}

t_t20_the_hook_runs_once_per_invocation_and_never_when_no_unit_was_admitted() {
  moe_setup "$FUNCNAME"
  moe_sup_bg body_nothing
  step_end
  assert_eq "0" "$SRC" "a body that returns before step_run: exit 0"
  assert_eq "0" "$(run_lines moe-clear | wc -l | tr -d ' ')" "no moe-clear run in the call log"
  assert_eq "0" "$(sup_log | grep -c 'cleanup hook:')" "and no cleanup hook line"
  moe_sup_bg body_two_chunks
  step_end
  local second last_clear pwsh
  assert_eq "0" "$SRC" "a body of two step_run calls: exit 0"
  assert_eq "1" "$(sup_log | grep -c 'cleanup hook:')" "one cleanup hook line"
  assert_eq "3" "$(run_lines moe-clear | wc -l | tr -d ' ')" "three clears in all: one before each unit and one in the exit path"
  second="$(last_line_of " wslc run --rm --name ${R9700_CONTAINER_PREFIX}moe-tune-b24 ")"
  last_clear="$(last_line_of " wslc run --rm --name ${R9700_CONTAINER_PREFIX}moe-clear ")"
  pwsh="$(last_line_of " pwsh.exe ")"
  if [ "$second" -lt "$last_clear" ] && [ "$last_clear" -lt "$pwsh" ]; then assert_eq ok ok "the last clear is after the second unit's container and before the restore"; else assert_eq "second unit < clear < restore" "$second $last_clear $pwsh" "the order in the call log"; fi
}

# ---- the worker's own argument checks and the dtype `none` ----------------------------------------------------------------------------------------

# worker_direct <args...>: lib/moe.sh as the supervisor would start it, but by hand: an environment that names a run folder and an outcome file
worker_direct() {
  mkdir -p "$CASE/run/steps"
  R9700_RUN_DIR="$CASE/run" R9700_OUTCOME_FILE="$CASE/run/steps/1.outcome" bash "$REPO/lib/moe.sh" "$@"
}

t_a_bad_argument_ends_the_worker_with_one_moe_line_and_no_container_and_no_outcome() {
  moe_setup "$FUNCNAME"
  local -a bad=(
    "chunk $RECS $MOE_MODEL Bad-Name experts full 24"
    "chunk $RECS $MOE_MODEL ok-name gpu full 24"
    "chunk $RECS $MOE_MODEL ok-name experts partial 24"
    "chunk $RECS $MOE_MODEL ok-name experts full 24 24"
    "chunk $RECS $MOE_MODEL ok-name experts full 65537"
    "chunk $RECS $MOE_MODEL ok-name experts full 0"
    "chunk $RECS $MOE_MODEL ok-name experts full $(seq -s ' ' 1 21)"
    "chunk $RECS $MOE_MODEL ok-name experts full"
    "ab $RECS $MOE_MODEL draft each 1 0 1"
    "ab $RECS $MOE_MODEL draft each 1 10 1"
    "ab $RECS $MOE_MODEL draft sum 1 3 1"
    "ab $RECS $MOE_MODEL draft each 5 3 1"
    "ab $RECS $MOE_MODEL draft each 1 3"
    "nosuch $RECS"
  )
  local line
  for line in "${bad[@]}"; do
    # shellcheck disable=SC2086
    assert_exit 2 "bad arguments ($line)" -- worker_direct $line
    assert_eq "1" "$(printf '%s\n' "$ERR" | grep -c '^moe: ')" "one moe: line on stderr"
  done
  assert_missing "$CASE/run/steps/1.outcome" "no outcome was written: a plain exit 2 stays a failed try for the supervisor"
  assert_eq "0" "$(grep -c ' wslc run --rm ' "$STUB/calls.log" 2> /dev/null || true)" "no container ran"
}

t_a_model_without_moe_layers_refuses_the_experts_layer_by_name_and_still_allows_the_draft() {
  moe_setup "$FUNCNAME"
  { cat "$MODEL_35B"; echo "MOE_DTYPE=none"; } > "$CASE/model.env"
  MODEL="$CASE/model.env"
  assert_exit 2 "an experts chunk of a model with MOE_DTYPE=none" -- moe_chunk int4-24 experts full 24
  outcome_read "$(last_run_dir)/steps/1.outcome"
  assert_eq "refused" "$O_KIND" "KIND=refused"
  assert_contains "$O_DETAIL" "MOE_DTYPE is none" "the detail says why"
  assert_eq "0" "$(run_lines moe-tune-int4-24 | wc -l | tr -d ' ')" "no chunk container ran"
  chunk_json_for b1 256
  assert_exit 0 "a draft chunk of the same model (its dtype is auto)" -- moe_chunk draft-1 draft full 256
}

# ---- the S2 review findings: the identity of a record, the stop time at the gate, an exchange folder that cannot be cleared, a hook that is not ours ----

# edit_during <container name> <file>: when that container starts, a script of the test appends a byte to the file (an edit during a long unit)
edit_during() { printf 'printf x >> "%s"\n' "$2" > "$STUB/on-start-${R9700_CONTAINER_PREFIX}$1"; }

t_t21_an_asset_edited_during_a_chunk_gives_a_rejected_record_never_one_that_names_hashes_the_container_did_not_run_with() {
  moe_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  edit_during moe-tune-int4-24 "$WORK/benchmark_moe.py"
  assert_exit 7 "a stub chunk whose placed benchmark is edited while it runs" -- moe_chunk int4-24 experts full 24
  local rej
  rej="$(ls -d "$RECS"/rejected/int4-24-* 2> /dev/null | head -n 1)"
  assert_exit 0 "rejected/int4-24-<stamp>/ exists" -- test -d "$rej"
  assert_contains "$(cat "$rej/reason")" "benchmark_moe.py changed during the run" "the reason names the asset"
  assert_eq "$(sha256sum "$REPO/vendor/benchmark_moe.py" | cut -d' ' -f1)" "$(env_get "$rej/chunk.env" BENCHMARK_SHA256)" "chunk.env names the hash the container STARTED with"
  assert_missing "$RECS/chunks/int4-24" "no record"
}

t_t22_a_merged_file_edited_during_an_ab_gives_a_rejected_record() {
  moe_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  moe_merged_place b1
  moe_ab_answers "/work/r9700/moe/$MOE_MODEL/merged" "$FIX_B1_NAME"
  edit_during moe-ab-tuned-2 "$EX/merged/$FIX_B1_NAME"
  assert_exit 7 "a stub A/B whose merged file is edited while it runs" -- moe_ab "${AB_ARGS[@]}"
  local rej
  rej="$(ls -d "$RECS"/rejected/ab-* 2> /dev/null | head -n 1)"
  assert_exit 0 "rejected/ab-<stamp>/ exists" -- test -d "$rej"
  assert_contains "$(cat "$rej/reason")" "$FIX_B1_NAME changed during the run" "the reason names the file"
  assert_eq "$(sha256sum "$HERE/fixtures/moe/b1/$FIX_B1_NAME" | cut -d' ' -f1)" "$(env_get "$rej/ab.env" B_SHA256)" "ab.env names the hash the A/B STARTED with"
  assert_eq "0" "$(ls "$RECS/ab" | wc -l | tr -d ' ')" "no A/B record"
}

t_t22b_a_placed_benchmark_edited_during_an_ab_gives_a_rejected_record_too() {
  moe_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  moe_merged_place b1
  moe_ab_answers "/work/r9700/moe/$MOE_MODEL/merged" "$FIX_B1_NAME"
  edit_during moe-ab-default-1 "$WORK/benchmark_moe.py"
  assert_exit 7 "a stub A/B whose placed benchmark is edited while it runs" -- moe_ab "${AB_ARGS[@]}"
  local rej
  rej="$(ls -d "$RECS"/rejected/ab-* 2> /dev/null | head -n 1)"
  assert_exit 0 "rejected/ab-<stamp>/ exists" -- test -d "$rej"
  assert_contains "$(cat "$rej/reason")" "benchmark_moe.py changed during the run" "the reason names the asset"
  assert_eq "$(sha256sum "$REPO/vendor/benchmark_moe.py" | cut -d' ' -f1)" "$(env_get "$rej/ab.env" BENCHMARK_SHA256)" "ab.env names the hash the A/B STARTED with"
}

t_t23_a_unit_at_the_stop_time_writes_kind_deadline_not_a_false_disk_alarm() {
  moe_setup "$FUNCNAME"
  local rc
  R9700_T_STOP="$(($(date +%s) - 5))" worker_direct chunk "$RECS" "$MOE_MODEL" int4-24 experts full 24 > "$CASE/w.out" 2>&1
  rc=$?
  assert_eq "1" "$rc" "the worker exits 1"
  outcome_read "$CASE/run/steps/1.outcome"
  assert_eq "deadline" "$O_KIND" "the outcome is KIND=deadline (the adapter refuses every call after T_STOP, so the gate could only say 'query failed')"
  assert_eq "0" "$(run_lines moe-tune-int4-24 | wc -l | tr -d ' ')" "no chunk container ran"
}

t_t24_an_exchange_folder_that_cannot_be_cleared_refuses_the_unit() {
  moe_setup "$FUNCNAME"
  if [ "$(id -u)" = 0 ]; then assert_eq ok ok "skipped: running as root (chmod a-w does not stop root, so the folder could be emptied)"; return; fi
  mkdir -p "$EX/tune/int4-24/sub"
  printf 'stale\n' > "$EX/tune/int4-24/sub/E=stale.json"
  chmod a-w "$EX/tune/int4-24/sub" # rm -rf cannot delete the file inside
  assert_exit 2 "a stub chunk over a folder that cannot be emptied" -- moe_chunk int4-24 experts full 24
  chmod u+w "$EX/tune/int4-24/sub"
  outcome_read "$(last_run_dir)/steps/1.outcome"
  assert_eq "refused" "$O_KIND" "KIND=refused: a retry would meet the same folder"
  assert_contains "$O_DETAIL" "cannot be cleared" "the detail says why"
  assert_eq "0" "$(run_lines moe-tune-int4-24 | wc -l | tr -d ' ')" "no chunk container ran"
  assert_missing "$RECS/chunks/int4-24" "no record"
}

t_t25_a_hook_registered_for_an_invocation_that_returned_early_is_not_run_by_the_next_one() {
  moe_setup "$FUNCNAME"
  local -a drop=()
  local word
  while read -r word; do drop+=(-u "R9700_$word"); done < <(config_keys | awk '{ print $2 }')
  body_args int4-24 experts full 24
  env "${drop[@]}" MOE_OUT="$RECS" MOE_MODEL_NAME="$MOE_MODEL" MOE_BODY_ARGS="$MOE_BODY_ARGS" bash -c "
    source \"$REPO/bin/r9700\"; source \"$REPO/lib/moe.sh\"
    REPO=\"$REPO\"
    $(declare -f body_chunk)
    prepare_refuses() { return 2; }
    _R9700_MODEL_ARG=\"$MODEL\"
    cleanup_hook_set moe_cache_clear
    supervise moe prepare_refuses body_chunk; echo first=\$?
    supervise moe prepare_run body_chunk; echo second=\$?" > "$CASE/two.out" 2> "$CASE/two.err"
  assert_eq "first=2 second=0" "$(grep -E '^(first|second)=' "$CASE/two.out" | tr '\n' ' ' | sed 's/ $//')" "the first invocation is refused at prepare, the second runs its chunk"
  assert_eq "0" "$(sup_log | grep -c 'cleanup hook:')" "the second invocation registered no hook and ran none"
  assert_eq "1" "$(run_lines moe-clear | wc -l | tr -d ' ')" "one clear in all: the worker's, before its unit"
}

# ---- the E2 code gate: the decision line, the progress lines, one hashing pass, the clear before a unit, the heartbeat ----------------------------------

# decide_shim <tail|none|two>: a python3 in front of PATH that changes ONLY the stdout of `moe_kernel_ab.py decide`: `tail` adds a trailing line, `none`
# drops the KERNEL line, `two` adds a second one
decide_shim() {
  local real
  # The real python3, never an earlier shim: on a second call the shim is first on PATH, and a shim that execs itself forks without end
  # (2026-11-02: about 15,900 processes). Look it up with the shim directory removed, and refuse anything inside it.
  real="$(PATH="${PATH//"$CASE/shim:"/}" command -v python3)"
  case $real in "$CASE/shim/"* | "") echo "decide_shim: no real python3 outside $CASE/shim (got \"$real\")" >&2; return 1 ;; esac
  mkdir -p "$CASE/shim"
  {
    echo '#!/usr/bin/env bash'
    echo "case \" \$* \" in *moe_kernel_ab.py*decide*) ;; *) exec \"$real\" \"\$@\" ;; esac"
    echo "out=\"\$(\"$real\" \"\$@\")\"; rc=\$?"
    case $1 in
      tail) echo "printf '%s\\n' \"\$out\" 'note: a trailing line that is not the decision'" ;;
      none) echo "printf '%s\\n' \"\$out\" | grep -v '^KERNEL:'" ;;
      two) echo "printf '%s\\n' \"\$out\" 'KERNEL: not faster (a second decision line)'" ;;
    esac
    echo 'exit $rc'
  } > "$CASE/shim/python3"
  chmod +x "$CASE/shim/python3"
  case :$PATH: in *":$CASE/shim:"*) ;; *) PATH="$CASE/shim:$PATH" ;; esac # once on PATH, however often the shim is rewritten
  export PATH
}

t_t26_decision_txt_is_the_kernel_line_even_when_decide_prints_more_and_zero_or_two_kernel_lines_are_rejected() {
  moe_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  moe_merged_place b1
  moe_ab_answers "/work/r9700/moe/$MOE_MODEL/merged" "$FIX_B1_NAME"
  decide_shim tail
  assert_exit 0 "an A/B whose decide prints a trailing line" -- moe_ab "${AB_ARGS[@]}"
  local ab
  ab="$(ls -d "$RECS"/ab/*/ | head -n 1)"
  ab="${ab%/}"
  assert_eq "KERNEL: faster (each of 1 4 is faster by more than 3 %)" "$(cat "$ab/decision.txt")" "decision.txt is the KERNEL line, not the last line"
  assert_contains "$(cat "$ab/summary.txt")" "note: a trailing line" "summary.txt keeps everything decide printed"
  rm -rf "$RECS/ab"
  decide_shim none
  assert_exit 7 "decide prints no KERNEL line" -- moe_ab "${AB_ARGS[@]}"
  assert_contains "$(cat "$(ls -d "$RECS"/rejected/ab-* | head -n 1)/reason")" "exactly one KERNEL: line, got 0" "rejected, and the reason says why"
  assert_eq "0" "$(ls "$RECS/ab" | wc -l | tr -d ' ')" "no A/B record"
  rm -rf "$RECS/rejected"
  decide_shim two
  assert_exit 7 "decide prints two KERNEL lines" -- moe_ab "${AB_ARGS[@]}"
  assert_contains "$(cat "$(ls -d "$RECS"/rejected/ab-* | head -n 1)/reason")" "exactly one KERNEL: line, got 2" "rejected, and the reason says why"
}

t_t27_the_ab_prints_one_progress_line_before_each_container() {
  moe_setup "$FUNCNAME"
  moe_merged_place b1
  moe_ab_answers "/work/r9700/moe/$MOE_MODEL/merged" "$FIX_B1_NAME"
  assert_exit 0 "a stub A/B" -- moe_ab "${AB_ARGS[@]}"
  assert_eq "  ab rep 1/3: default|  ab rep 1/3: tuned|  ab rep 2/3: default|  ab rep 2/3: tuned|  ab rep 3/3: default|  ab rep 3/3: tuned" \
    "$(worker_log 1 | grep '^  ab rep ' | paste -sd'|')" "six progress lines, rep by rep, default then tuned"
}

t_t28_the_current_hashes_are_computed_once_not_once_per_asset() {
  moe_setup "$FUNCNAME"
  local placed=0 name source need
  while read -r name source need _; do [ -f "$R9700_WORK_DIR/r9700/$name" ] && placed=$((placed + 1)); done < <(moe_assets)
  _MOE_HASHES="$(moe_asset_hashes)"
  : > "$CASE/sha.count"
  sha256sum() { echo x >> "$CASE/sha.count"; command sha256sum "$@"; }
  _moe_assets_unchanged
  unset -f sha256sum
  assert_eq "$placed" "$(wc -l < "$CASE/sha.count" | tr -d ' ')" "one sha256sum per placed asset ($placed), not one pass per asset row"
}

t_t29_a_failed_cache_clear_before_a_unit_refuses_the_unit_for_a_chunk_and_for_an_ab() {
  moe_setup "$FUNCNAME"
  printf '1\n' > "$STUB/answers/moe_clear_rc"
  assert_exit 2 "a stub chunk whose clear fails" -- moe_chunk int4-24 experts full 24
  outcome_read "$(last_run_dir)/steps/1.outcome"
  assert_eq "refused" "$O_KIND" "KIND=refused: no stale cache is ever measured"
  assert_contains "$O_DETAIL" "cache could not be cleared" "the detail says why"
  assert_eq "0" "$(run_lines moe-tune-int4-24 | wc -l | tr -d ' ')" "no chunk container ran"
  assert_missing "$RECS/chunks/int4-24" "no record"
  moe_merged_place b1
  moe_ab_answers "/work/r9700/moe/$MOE_MODEL/merged" "$FIX_B1_NAME"
  assert_exit 2 "a stub A/B whose clear fails" -- moe_ab "${AB_ARGS[@]}"
  outcome_read "$(last_run_dir)/steps/1.outcome"
  assert_eq "refused" "$O_KIND" "KIND=refused"
  assert_eq "0" "$(run_lines_ab | wc -l | tr -d ' ')" "no A/B container ran"
  assert_missing "$RECS/ab" "no A/B record"
}

t_t30_a_failed_clear_in_the_exit_path_stays_best_effort() {
  moe_setup "$FUNCNAME"
  printf 'printf "1\\n" > "%s/answers/moe_clear_rc"\n' "$STUB" > "$STUB/on-start-${R9700_CONTAINER_PREFIX}moe-tune-int4-24"
  body_args int4-24 experts full 24
  moe_sup_bg body_chunk
  step_end
  assert_eq "0" "$SRC" "the invocation still ends 0: the unit was good"
  assert_contains "$(sup_log)" "cleanup hook: moe_cache_clear rc=1" "the hook's failed clear is logged"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "and the restore still ran"
  assert_exit 0 "the record exists" -- test -s "$RECS/chunks/int4-24/$FIX_B2_NAME"
}

t_t31_a_long_chunk_prints_a_heartbeat_and_the_log_and_argv_are_untouched() {
  moe_setup "$FUNCNAME"
  printf '7\n' > "$STUB/answers/moe_tune_seconds" # the time scale is 100: a "5 min" beat is 3 s
  assert_exit 0 "a stub chunk that runs 7 s" -- moe_chunk int4-24 experts full 24
  assert_contains "$(worker_log 1)" "  chunk int4-24: running 5 min" "the first heartbeat"
  assert_contains "$(worker_log 1)" "  chunk int4-24: running 10 min" "the second"
  assert_not_contains "$(cat "$RECS/chunks/int4-24/chunk.log")" "running 5 min" "chunk.log does not hold it"
  run_argv moe-tune-int4-24
  assert_not_contains "${ARGV[*]}" "heartbeat" "and nor does the argv"
}

t_t32_a_chunk_container_left_running_by_a_cut_call_is_stopped_before_a_retry_starts() {
  moe_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=2
  printf '124\n' > "$STUB/answers/fault.${R9700_CONTAINER_PREFIX}moe-tune-int4-24" # cut at the ceiling, the container stays listed (once)
  assert_exit 0 "a stub chunk whose first call is cut (124); the retry runs clean under the same container name" -- moe_chunk int4-24 experts full 24
  local stop second
  stop="$(line_of " wslc stop ${R9700_CONTAINER_PREFIX}moe-tune-int4-24")"
  second="$(run_lines moe-tune-int4-24 | tail -n 1)"
  if [ -n "$stop" ] && [ -n "$second" ] && [ "$stop" -lt "$second" ] && [ "$(run_lines moe-tune-int4-24 | wc -l | tr -d ' ')" = 2 ]; then assert_eq ok ok "the cut call's container was stopped by name (line $stop) before the second run (line $second)"; else assert_eq "stop < the second run" "$stop $second" "the order"; fi
  assert_exit 0 "the second try recorded" -- test -s "$RECS/chunks/int4-24/$FIX_B2_NAME"
}

run_all_tests
