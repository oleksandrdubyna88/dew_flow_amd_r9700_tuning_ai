#!/usr/bin/env bash
# The verb `bin/r9700 moe-tune chunk|merge|activate|ab` (E2.S3): the argument grammar and its refusals before the lock, the placed files, the chunk and
# the A/B as steps of ONE supervisor, the merge as a reading verb that writes a versioned record only, `activate` as the one atomic, explicit step that
# changes what a server reads, the dry runs. Scenarios U1-U15 of the story (U13 and U14 are split into one function per case). Every test body is a
# function t_<guarantee>; each runs in its own subshell and writes only below $R9700_TEST_ROOT. "A verb chunk" is `bin/r9700 moe-tune chunk
# qwen3.6-35b-a3b-gptq --keys "24" --out m` and OUTD is its outdir (the assert library's OUT is the stdout of the last assert_exit).
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

# mv_setup <name>: the 35B model, the operator's server running, the stub answers of a chunk of key 24; the files are NOT placed (the verb does it)
mv_setup() {
  step_setup "$1"
  prod_running
  MOE_MODEL="$(basename "$MODEL_35B" .env)"
  OUTD="$R9700_RESULTS_DIR/m"
  WORK="$R9700_WORK_DIR/r9700"
  EX="$WORK/moe/$MOE_MODEL"
  chunk_json_for b2 24
}

mv_verb() { r9700 moe-tune "$@"; }

# mv_variant <KEY=VALUE>...: the 35B model file with these keys set (an existing line of the key is replaced), under its own name so the exchange folder
# is the same; sets MVM
mv_variant() {
  local line
  mkdir -p "$CASE/v"
  MVM="$CASE/v/$MOE_MODEL.env"
  cp "$MODEL_35B" "$MVM"
  for line in "$@"; do # a key may be given once per file: the variant replaces its line
    { grep -v "^${line%%=*}=" "$MVM" || true; } > "$MVM.new"
    printf '%s\n' "$line" >> "$MVM.new"
    mv "$MVM.new" "$MVM"
  done
}

# mv_chunks <keys>...: one verb chunk per key
mv_chunks() {
  local key
  for key in "$@"; do
    chunk_json_for b2 "$key"
    r9700 moe-tune chunk "$MOE_MODEL" --keys "$key" --out m > /dev/null 2>&1 || return 1
  done
}

# mv_record <stamp> <b1|b2>: a merge record made by hand (the file of that merged fixture), for the tests that start at `activate`
mv_record() {
  local layer=experts
  [ "$2" = b1 ] && layer=draft
  mkdir -p "$OUTD/merged/$1"
  cp "$HERE/fixtures/moe/$2"/E=*.json "$OUTD/merged/$1/"
  printf 'CHUNKS=hand\nLAYER=%s\nBASE=none\n' "$layer" > "$OUTD/merged/$1/merge.env" # what `merge` writes: the layer is read from it
}

# stamp_of_merge: the stamp the merge printed, from the last stdout
stamp_of_merge() { printf '%s\n' "$OUT" | sed -n 's/^merged: \([^ ]*\) (activate it with: .*/\1/p' | tail -n 1; }

keys_of() { python3 -c 'import json, sys; print(" ".join(k for k in json.load(open(sys.argv[1])) if k != "triton_version"))' "$1"; }

calls_since() { tail -n +"$(($1 + 1))" "$STUB/calls.log"; }

calls_n() { wc -l < "$STUB/calls.log" | tr -d ' '; }

# since_count <n> <stub> <word>: the call-log lines after line <n> that have the word as an argument of that stub
since_count() { calls_since "$1" | awk -v s="$2" -v w="$3" '$3 == s { for (i = 4; i <= NF; i++) if ($i == w) { n++; break } } END { print n + 0 }'; }

# wait_glob <pattern> [<n>]: waits (bounded: n * 0.1 s, default 100) for a path matching the glob
wait_glob() {
  local i
  for i in $(seq 1 "${2:-100}"); do compgen -G "$1" > /dev/null && return 0; sleep 0.1; done
  return 1
}

parts_under() { find "$@" -name '*.part-*' 2> /dev/null | wc -l | tr -d ' '; }

# ---- U1-U3: the chunk through the verb ---------------------------------------------------------------------------------------------------------

t_u1_a_verb_chunk_places_the_files_records_the_chunk_and_names_it() {
  mv_setup "$FUNCNAME"
  assert_missing "$WORK/benchmark_moe.py" "the benchmark is not placed before"
  assert_missing "$WORK/coarse_candidates.json" "nor the candidates"
  assert_exit 0 "a verb chunk" -- mv_verb chunk "$MOE_MODEL" --keys "24" --out m
  local chunk_out="$OUT"
  assert_exit 0 "benchmark_moe.py is placed, byte for byte" -- cmp "$REPO/vendor/benchmark_moe.py" "$WORK/benchmark_moe.py"
  assert_exit 0 "coarse_candidates.json is placed, byte for byte" -- cmp "$REPO/config/coarse_candidates.json" "$WORK/coarse_candidates.json"
  assert_exit 0 "the record has the default name <layer>-<full>-<keys>" -- test -s "$OUTD/chunks/experts-full-24/chunk.env"
  assert_eq "moe-tune: outdir $OUTD" "$(printf '%s\n' "$chunk_out" | head -n 1)" "the first stdout line names the outdir"
  assert_contains "$chunk_out" "recorded chunks/experts-full-24" "and the record is named later"
  assert_eq "1" "$(prod_stops)" "the operator's server was stopped once"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "and restored once"
}

t_u1b_a_placed_file_that_differs_is_replaced_and_one_that_cannot_be_placed_is_refused_before_any_stop() {
  mv_setup "$FUNCNAME"
  mkdir -p "$WORK"
  printf 'an older benchmark\n' > "$WORK/benchmark_moe.py"
  assert_exit 0 "a verb chunk over a stale placed file" -- mv_verb chunk "$MOE_MODEL" --keys "24" --out m
  assert_exit 0 "the stale file is replaced by the vendored one" -- cmp "$REPO/vendor/benchmark_moe.py" "$WORK/benchmark_moe.py"
  assert_eq "0" "$(parts_under "$WORK")" "no .part of a placement remains"
  if [ "$(id -u)" = 0 ]; then assert_eq ok ok "skipped: running as root (chmod a-w does not stop root)"; return; fi
  rm -rf "$WORK/benchmark_moe.py" "$WORK/coarse_candidates.json" "$OUTD"
  chmod a-w "$WORK"
  local before
  before="$(calls_n)"
  assert_exit 2 "an unwritable work folder: the placement fails" -- mv_verb chunk "$MOE_MODEL" --keys "24" --out m
  chmod u+w "$WORK"
  assert_contains "$ERR" "moe-tune: benchmark_moe.py cannot be placed in $WORK" "the line names the file and the folder"
  assert_eq "0" "$(since_count "$before" wslc stop)" "nothing was stopped"
  assert_eq "0" "$(since_count "$before" pwsh.exe -Detach)" "and nothing restored: no admission happened"
}

t_u2_coarse_layer_and_chunk_shape_the_name_and_the_worker_arguments() {
  mv_setup "$FUNCNAME"
  chunk_json_for b1 256 1024 2048
  assert_exit 0 "a draft coarse chunk of three keys" -- mv_verb chunk "$MOE_MODEL" --keys "256 1024 2048" --coarse --layer draft --out m
  assert_exit 0 "the record is named layer-search-keys" -- test -s "$OUTD/chunks/draft-coarse-256-1024-2048/chunk.env"
  assert_contains "$(worker_log 1)" "(draft, coarse, keys 256 1024 2048)" "the worker was started with the words: layer, search, keys"
  assert_eq "coarse" "$(env_get "$OUTD/chunks/draft-coarse-256-1024-2048/chunk.env" SEARCH)" "SEARCH in the record"
  assert_eq "draft" "$(env_get "$OUTD/chunks/draft-coarse-256-1024-2048/chunk.env" LAYER)" "LAYER in the record"
  chunk_json_for b2 24
  assert_exit 0 "--chunk names the record" -- mv_verb chunk "$MOE_MODEL" --keys "24" --chunk mine --out m
  assert_exit 0 "the record is chunks/mine" -- test -s "$OUTD/chunks/mine/chunk.env"
}

t_u3_a_recorded_chunk_is_counted_before_admission() {
  mv_setup "$FUNCNAME"
  assert_exit 0 "the first verb chunk" -- mv_verb chunk "$MOE_MODEL" --keys "24" --out m
  local before
  before="$(calls_n)"
  assert_exit 0 "the same command again" -- mv_verb chunk "$MOE_MODEL" --keys "24" --out m
  assert_contains "$OUT" "moe-tune: chunk experts-full-24 is recorded, nothing to do" "it says so"
  assert_eq "0" "$(since_count "$before" wslc stop)" "no stop"
  assert_eq "0" "$(since_count "$before" pwsh.exe -Detach)" "no restore"
  assert_eq "0" "$(since_count "$before" wslc run)" "no container of any kind"
  assert_eq "no step" "$(ls "$(last_run_dir)/steps" 2> /dev/null | grep . > /dev/null && echo steps || echo 'no step')" "the second invocation's run folder holds no step"
}

# no_container_since <n> <name>: the verb after call <n> neither stopped the operator's server, nor restored it, nor started a container
no_container_since() {
  assert_eq "0" "$(since_count "$1" wslc stop)" "$2: no stop"
  assert_eq "0" "$(since_count "$1" pwsh.exe -Detach)" "$2: no restore"
  assert_eq "0" "$(since_count "$1" wslc run)" "$2: no container of any kind"
}

t_u3b_a_recorded_chunk_of_another_activation_dtype_is_refused_before_admission_and_the_same_dtype_is_nothing_to_do() {
  mv_setup "$FUNCNAME"
  assert_exit 0 "the first verb chunk (the 35B file serves bfloat16)" -- mv_verb chunk "$MOE_MODEL" --keys "24" --out m
  assert_eq "bfloat16" "$(env_get "$OUTD/chunks/experts-full-24/chunk.env" ACT_DTYPE)" "the record says bfloat16"
  local before
  before="$(calls_n)"
  mv_variant "MOE_ACT_DTYPE=float16"
  assert_exit 2 "the same command under a model that serves float16" -- mv_verb chunk "$MVM" --keys "24" --out m
  assert_contains "$ERR" "moe-tune: chunk experts-full-24 is recorded with ACT_DTYPE bfloat16 but this run tunes for float16" "the line names the chunk, the recorded and the wanted dtype"
  assert_contains "$ERR" "use another --out" "and the remedy"
  no_container_since "$before" "float16 over a bfloat16 record"
  assert_exit 0 "the operator's server still runs" -- test -f "$STUB/containers/vllm.pid"
  assert_exit 0 "the record is still there" -- test -s "$OUTD/chunks/experts-full-24/chunk.env"
  before="$(calls_n)"
  assert_exit 0 "the same command with the same dtype" -- mv_verb chunk "$MOE_MODEL" --keys "24" --out m
  assert_contains "$OUT" "moe-tune: chunk experts-full-24 is recorded, nothing to do" "it says so"
  no_container_since "$before" "bfloat16 over a bfloat16 record"
}

t_u3c_an_old_record_with_an_empty_or_absent_activation_dtype_is_refused_for_both_wanted_dtypes_before_admission() {
  local dtype form before
  for dtype in bfloat16 float16; do
    for form in empty absent; do
      mv_setup "$FUNCNAME-$dtype-$form"
      assert_exit 0 "[$dtype, $form] the first verb chunk" -- mv_verb chunk "$MOE_MODEL" --keys "24" --out m
      grep -v '^ACT_DTYPE=' "$OUTD/chunks/experts-full-24/chunk.env" > "$CASE/chunk.env.new"
      [ "$form" = empty ] && echo "ACT_DTYPE=" >> "$CASE/chunk.env.new" # what an experts chunk of the older versions holds
      mv "$CASE/chunk.env.new" "$OUTD/chunks/experts-full-24/chunk.env"
      mv_variant "MOE_ACT_DTYPE=$dtype"
      before="$(calls_n)"
      assert_exit 2 "[$dtype, $form] the same command over an old record" -- mv_verb chunk "$MVM" --keys "24" --out m
      assert_contains "$ERR" "moe-tune: chunk experts-full-24 is recorded with no activation dtype" "[$dtype, $form] the line says the record names none"
      assert_contains "$ERR" "use another --out" "[$dtype, $form] and the remedy"
      no_container_since "$before" "[$dtype, $form] an old record"
    done
  done
}

# ---- U4: the arguments are refused before the lock ---------------------------------------------------------------------------------------------

# refused_before_lock <name> <expected stderr text> <args...>: exit 2, the text on stderr, no lock file, no call at all
refused_before_lock() {
  local name="$1" want="$2" before
  shift 2
  before="$(calls_n)"
  assert_exit 2 "$name" -- mv_verb "$@"
  assert_contains "$ERR" "$want" "$name: the line names the legal shape"
  assert_missing "$R9700_STATE_DIR/lock" "$name: no lock was taken"
  assert_eq "$before" "$(calls_n)" "$name: nothing was called"
}

t_u4_the_arguments_are_refused_before_the_lock_naming_the_legal_shape() {
  mv_setup "$FUNCNAME"
  local m="$MOE_MODEL"
  refused_before_lock "no mode" "usage: moe-tune chunk|merge|activate|ab <model> [options]"
  refused_before_lock "an unknown mode" 'unknown mode "frob"; legal: chunk merge activate ab' frob
  refused_before_lock "chunk without a model" "usage: moe-tune chunk|merge|activate|ab <model> [options]" chunk
  refused_before_lock "chunk without --keys" "moe-tune: chunk: --keys is required" chunk "$m"
  refused_before_lock "a key that is not a number" '--keys "a 2" is not a list of whitespace-separated batch sizes, e.g. "8 16 24"' chunk "$m" --keys "a 2"
  refused_before_lock "a key given twice" "2 is given twice" chunk "$m" --keys "2 2"
  refused_before_lock "a key too big" '--keys "65537" is not a list of whitespace-separated batch sizes' chunk "$m" --keys "65537"
  refused_before_lock "a layer that is none" "experts draft" chunk "$m" --keys 1 --layer heads
  refused_before_lock "a chunk name with a space" '^[a-z0-9][a-z0-9-]{0,30}$' chunk "$m" --keys 1 --chunk "Bad Name"
  refused_before_lock "a default name that is too long" "pass --chunk" chunk "$m" --keys "11111 22222 33333 44444 55555"
  refused_before_lock "an option the mode does not take" 'unknown option "--rule"; legal: --keys, --coarse, --layer, --chunk, --out, --dry-run' chunk "$m" --keys 1 --rule each
  refused_before_lock "an outdir that is a path" '--out "../x" is not a name' chunk "$m" --keys 1 --out ../x
  refused_before_lock "rule keys that are not numbers" '--rule-keys "x" is not a list of whitespace-separated batch sizes' ab "$m" --keys "1 4" --rule each --rule-keys "x"
  refused_before_lock "an option without its value" "--keys needs a value" chunk "$m" --keys
  refused_before_lock "ab with a rule that is none" "each median" ab "$m" --keys "1 4" --rule mean --rule-keys "1"
  refused_before_lock "ab without --rule" "moe-tune: ab: --rule is required" ab "$m" --keys "1 4" --rule-keys "1"
  refused_before_lock "ab without --rule-keys" "moe-tune: ab: --rule-keys is required" ab "$m" --keys "1 4" --rule each
  refused_before_lock "a rule key that is not a key" "rule key 5 is not in --keys" ab "$m" --keys "1 4" --rule each --rule-keys "5"
  refused_before_lock "reps out of range" '--reps "0" is not a whole number from 1 to 9' ab "$m" --keys "1 4" --rule each --rule-keys "1" --reps 0
  refused_before_lock "merge without a chunk" "moe-tune: merge: at least one chunk name is needed" merge "$m"
  refused_before_lock "merge with a chunk name that is a path" '^[a-z0-9][a-z0-9-]{0,30}$' merge "$m" ../x
  refused_before_lock "activate without a stamp" "moe-tune: activate: a stamp is needed" activate "$m"
  refused_before_lock "activate with a stamp that is a path" "is not a stamp" activate "$m" ../x
  assert_exit 0 "the operator's server is untouched" -- test -f "$STUB/containers/vllm.pid"
}

# ---- U5: MOE_DTYPE=none is refused after the restore-first and before any stop -----------------------------------------------------------------

t_u5_moe_dtype_none_is_refused_before_any_stop() {
  mv_setup "$FUNCNAME"
  mv_variant "MOE_DTYPE=none"
  local before
  before="$(calls_n)"
  assert_exit 2 "a chunk of a model without MoE layers" -- mv_verb chunk "$MVM" --keys 24 --out m
  assert_contains "$ERR" "moe-tune: $MOE_MODEL: MOE_DTYPE=none: no MoE layers to tune" "the line names the model and the field"
  assert_eq "0" "$(since_count "$before" wslc stop)" "no stop vllm"
  assert_exit 2 "an A/B of the experts layer too" -- mv_verb ab "$MVM" --keys "24" --rule median --rule-keys "24" --out m
  assert_eq "0" "$(since_count "$before" wslc stop)" "still no stop"
}

t_u5b_the_restore_comes_first_then_the_refusal() {
  mv_setup "$FUNCNAME"
  mv_variant "MOE_DTYPE=none"
  wslc stop vllm > /dev/null
  write_marker
  assert_exit 2 "a refused model with a marker present" -- mv_verb chunk "$MVM" --keys 24 --out m
  assert_eq "r9700: recovery marker found (run hand-1), restoring first" "$(printf '%s\n' "$OUT" | head -n 1)" "the first stdout line is the marker's"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the restore ran"
  assert_contains "$ERR" "MOE_DTYPE=none" "and then the refusal"
  assert_missing "$MARKER_FILE" "the marker is gone"
}

# ---- U6: --dry-run prints the container lines and starts nothing -------------------------------------------------------------------------------

t_u6_a_dry_run_prints_the_container_lines_and_starts_nothing() {
  mv_setup "$FUNCNAME"
  local before line
  before="$(calls_n)"
  assert_exit 0 "a chunk dry run" -- mv_verb chunk "$MOE_MODEL" --keys "24" --coarse --dry-run --out m
  local dry_out="$OUT"
  assert_eq "1" "$(printf '%s\n' "$dry_out" | grep -c '^dry-run: wslc run --rm --name r9700tune-moe-tune-experts-coarse-24 ')" "one chunk line"
  assert_contains "$dry_out" "-e MOE_TUNE_CANDIDATES=/work/r9700/coarse_candidates.json" "with the candidates word"
  assert_contains "$dry_out" "-e MOE_TUNE_ACT_DTYPE=bfloat16" "and the activation hook of the 35B file (MOE_ACT_DTYPE=bfloat16)"
  assert_contains "$dry_out" "--batch-size 24 " "and the keys"
  assert_eq "1" "$(printf '%s\n' "$dry_out" | grep -c '^dry-run: wslc run --rm --name r9700tune-moe-clear ')" "and the clear's line"
  assert_eq "0" "$(since_count "$before" wslc run)" "no container was started"
  assert_eq "0" "$(since_count "$before" wslc stop)" "nothing was stopped"
  assert_eq "0" "$(since_count "$before" pwsh.exe -Detach)" "nothing was restored"
  assert_missing "$OUTD/chunks" "no chunks folder"
  assert_eq "0" "$(parts_under "$OUTD")" "no part under the outdir"
  assert_exit 0 "a dry run places the files (a hash-checked copy, no record)" -- cmp "$REPO/vendor/benchmark_moe.py" "$WORK/benchmark_moe.py"
  # the line is what the worker runs: the same words as the real call, in the same order
  local dry_chunk dry_clear
  dry_chunk="$(printf '%s\n' "$dry_out" | grep '^dry-run: wslc run --rm --name r9700tune-moe-tune-')"
  dry_clear="$(printf '%s\n' "$dry_out" | grep '^dry-run: wslc run --rm --name r9700tune-moe-clear ')"
  assert_exit 0 "the same command for real" -- mv_verb chunk "$MOE_MODEL" --keys "24" --coarse --out m
  run_argv moe-tune-experts-coarse-24
  line="dry-run: wslc ${ARGV[*]}"
  assert_eq "$line" "$dry_chunk" "the chunk's dry-run line is the real call's words"
  run_argv moe-clear
  line="dry-run: wslc ${ARGV[*]}"
  assert_eq "$line" "$dry_clear" "the clear's dry-run line is the real call's words"
}

# ab_dry_equals_real <model arg>: the six dry-run lines of an A/B equal the words of the six real calls (the folders of both arms included)
ab_dry_equals_real() {
  local model="$1" line n arm rep before dry_out
  local -a dry=() ab_args=(ab "$1" --keys "1 2 3 4 6 8 12 16" --rule each --rule-keys "1 4" --layer draft --out m)
  before="$(calls_n)"
  assert_exit 0 "an A/B dry run (no activated file is needed to look)" -- mv_verb "${ab_args[@]}" --dry-run
  dry_out="$OUT"
  assert_eq "6" "$(printf '%s\n' "$dry_out" | grep -c '^dry-run: wslc run --rm --name r9700tune-moe-ab-')" "six A/B lines"
  assert_eq "0" "$(since_count "$before" wslc run)" "no container was started"
  assert_missing "$OUTD/ab" "no ab folder"
  mapfile -t dry < <(printf '%s\n' "$dry_out" | grep '^dry-run: wslc run --rm --name r9700tune-moe-ab-')
  moe_merged_place b1
  moe_ab_answers "/work/r9700/moe/$MOE_MODEL/merged" "$FIX_B1_NAME"
  assert_exit 0 "the same A/B for real" -- mv_verb "${ab_args[@]}"
  n=0
  for rep in 1 2 3; do
    for arm in default tuned; do
      run_argv "moe-ab-$arm-$rep"
      line="dry-run: wslc ${ARGV[*]}"
      assert_eq "$line" "${dry[$n]}" "the dry-run line of $arm-$rep is the real call's words"
      n=$((n + 1))
    done
  done
}

t_u6b_an_ab_dry_run_prints_six_container_lines_that_are_the_real_calls() {
  mv_setup "$FUNCNAME"
  ab_dry_equals_real "$MOE_MODEL"
  run_argv moe-ab-default-1
  assert_contains "${ARGV[*]}" "VLLM_TUNED_CONFIG_FOLDER=/work/moe/tune/merged" "the default arm reads the model's TUNED_CONFIG_DIR"
}

t_u6c_the_dry_run_of_a_model_without_a_tuned_folder_gives_the_default_arm_no_folder_word() {
  mv_setup "$FUNCNAME"
  mkdir -p "$CASE/v"
  MVM="$CASE/v/$MOE_MODEL.env"
  { grep -v '^TUNED_CONFIG_DIR=' "$MODEL_35B" || true; } > "$MVM"
  ab_dry_equals_real "$MVM"
  run_argv moe-ab-default-1
  assert_not_contains "${ARGV[*]}" "VLLM_TUNED_CONFIG_FOLDER" "the default arm reads vLLM's own config: no folder word"
  run_argv moe-ab-tuned-1
  assert_contains "${ARGV[*]}" "VLLM_TUNED_CONFIG_FOLDER=/work/r9700/moe/$MOE_MODEL/merged" "the tuned arm reads the activated folder"
}

# ---- U7-U10: merge ---------------------------------------------------------------------------------------------------------------------------

# base_place: the production file of 2026-10-27 where the 35B model's TUNED_CONFIG_DIR (/work/moe/tune/merged) points inside the work folder
base_place() {
  mkdir -p "$R9700_WORK_DIR/moe/tune/merged"
  cp "$HERE/fixtures/moe/b2_base"/E=*.json "$R9700_WORK_DIR/moe/tune/merged/"
}

t_u7_a_merge_writes_a_versioned_record_only_with_the_base_of_the_models_tuned_folder() {
  mv_setup "$FUNCNAME"
  mv_chunks 24 32 || return
  base_place
  local before stamp
  before="$(calls_n)"
  assert_exit 0 "merge of two chunks" -- mv_verb merge "$MOE_MODEL" --out m experts-full-24 experts-full-32
  local merge_out="$OUT"
  stamp="$(stamp_of_merge)"
  assert_exit 0 "the merged file is in merged/<stamp>/" -- test -s "$OUTD/merged/$stamp/$FIX_B2_NAME"
  assert_eq "1 2 4 8 12 16 24 32 256 1024 2048" "$(keys_of "$OUTD/merged/$stamp/$FIX_B2_NAME")" "the nine production keys and the two new ones"
  assert_eq "$R9700_WORK_DIR/moe/tune/merged/$FIX_B2_NAME" "$(env_get "$OUTD/merged/$stamp/merge.env" BASE)" "BASE is the model's tuned folder file"
  assert_eq "$(sha256sum "$HERE/fixtures/moe/b2_base/$FIX_B2_NAME" | cut -d' ' -f1)" "$(env_get "$OUTD/merged/$stamp/merge.env" BASE_SHA256)" "BASE_SHA256 is the production file's hash"
  assert_eq "$(sha256sum "$OUTD/merged/$stamp/$FIX_B2_NAME" | cut -d' ' -f1)" "$(env_get "$OUTD/merged/$stamp/merge.env" OUTPUT_SHA256)" "OUTPUT_SHA256 is the output's hash"
  assert_eq "experts-full-24 experts-full-32" "$(env_get "$OUTD/merged/$stamp/merge.env" CHUNKS)" "CHUNKS"
  assert_contains "$(env_get "$OUTD/merged/$stamp/merge.env" WRITTEN_AT)" "T" "WRITTEN_AT is a UTC time"
  assert_eq "merged: $stamp (activate it with: moe-tune activate $MOE_MODEL $stamp --out m)" "$(printf '%s\n' "$merge_out" | tail -n 1)" "the last stdout line says how to activate it"
  assert_contains "$merge_out" "base: $R9700_WORK_DIR/moe/tune/merged/$FIX_B2_NAME" "and the base is named"
  assert_missing "$EX/merged" "the exchange folder has no merged/ folder"
  assert_eq "0" "$(parts_under "$OUTD" "$EX")" "no .part- file anywhere"
  assert_eq "0" "$(since_count "$before" wslc stop)" "a reading verb: nothing was stopped"
  assert_eq "0" "$(since_count "$before" pwsh.exe -Detach)" "and nothing restored"
  assert_exit 0 "the merged file passes check for its keys" -- python3 "$REPO/lib/merge_moe.py" check --keys "1 2 4 8 12 16 24 32 256 1024 2048" "$OUTD/merged/$stamp/$FIX_B2_NAME"
}

t_u8_a_merge_over_a_tuned_folder_that_is_not_under_work_refuses_and_base_none_skips_it() {
  mv_setup "$FUNCNAME"
  mv_chunks 24 32 || return
  mv_variant "TUNED_CONFIG_DIR=/data/moe"
  assert_exit 2 "merge with a tuned folder outside /work" -- mv_verb merge "$MVM" --out m experts-full-24 experts-full-32
  assert_contains "$ERR" "TUNED_CONFIG_DIR /data/moe is not under /work, so the production file cannot be read from here: pass --base <file>, or --base none" "the refusal says why and what to do"
  assert_missing "$OUTD/merged" "nothing was written: a base that cannot be read is never silently no base"
  assert_exit 0 "the same merge with --base none" -- mv_verb merge "$MVM" --out m --base none experts-full-24 experts-full-32
  assert_eq "24 32" "$(keys_of "$OUTD/merged/$(stamp_of_merge)/$FIX_B2_NAME")" "the output holds the chunks' keys only"
  assert_exit 0 "--base none with the unedited model" -- mv_verb merge "$MOE_MODEL" --out m --base none experts-full-24 experts-full-32
  assert_not_contains "$OUT" "base:" "no base line at all"
  assert_eq "24 32" "$(keys_of "$OUTD/merged/$(stamp_of_merge)/$FIX_B2_NAME")" "the same two keys"
  assert_eq "none" "$(env_get "$OUTD/merged/$(stamp_of_merge)/merge.env" BASE)" "BASE=none in the record"
  base_place
  assert_exit 2 "--base with a file that is not there" -- mv_verb merge "$MOE_MODEL" --out m --base "$CASE/nosuch.json" experts-full-24
  assert_contains "$ERR" "moe-tune: merge: --base $CASE/nosuch.json is not a file" "named"
}

t_u8b_a_merge_names_the_layer_of_its_chunks() {
  mv_setup "$FUNCNAME"
  mv_chunks 24 || return
  assert_exit 2 "--layer draft over a chunk of the experts layer" -- mv_verb merge "$MOE_MODEL" --out m --base none --layer draft experts-full-24
  assert_contains "$ERR" "moe-tune: merge: chunk experts-full-24 is of the layer experts, not draft" "the refusal names the chunk and both layers"
  assert_missing "$OUTD/merged" "nothing was written"
  assert_exit 0 "--layer experts accepts it" -- mv_verb merge "$MOE_MODEL" --out m --base none --layer experts experts-full-24
}

t_u9_a_merge_refuses_a_missing_chunk_and_leaves_nothing_behind() {
  mv_setup "$FUNCNAME"
  mv_chunks 24 || return
  assert_exit 2 "merge with a chunk that is not there" -- mv_verb merge "$MOE_MODEL" --out m --base none experts-full-24 nosuch
  assert_contains "$ERR" "merge: missing chunk: $OUTD/chunks/nosuch" "the line of merge_moe.py names the chunk"
  assert_missing "$OUTD/merged" "no merged/<stamp>/"
  assert_eq "0" "$(parts_under "$OUTD" "$EX")" "no .part- anywhere"
}

t_u9b_a_merge_restores_the_server_first_when_a_marker_is_left() {
  mv_setup "$FUNCNAME"
  mv_chunks 24 || return
  wslc stop vllm > /dev/null
  write_marker
  local before
  before="$(calls_n)"
  assert_exit 0 "merge with a marker present" -- mv_verb merge "$MOE_MODEL" --out m --base none experts-full-24
  assert_eq "r9700: recovery marker found (run hand-1), restoring first" "$(printf '%s\n' "$OUT" | head -n 1)" "the first stdout line is the marker's"
  assert_eq "1" "$(since_count "$before" pwsh.exe -Detach)" "the restore ran, once"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_exit 0 "and the merge record was written after it" -- test -s "$OUTD/merged/$(stamp_of_merge)/$FIX_B2_NAME"
}

t_u10_a_second_merge_is_a_second_record_and_nothing_is_replaced() {
  mv_setup "$FUNCNAME"
  mv_chunks 24 32 || return
  base_place
  assert_exit 0 "the first merge" -- mv_verb merge "$MOE_MODEL" --out m experts-full-24 experts-full-32
  local first second sum_before time_before
  first="$(stamp_of_merge)"
  sum_before="$(sha256sum "$OUTD/merged/$first"/* | sort)"
  time_before="$(stat -c '%n %Y' "$OUTD/merged/$first"/* | sort)"
  assert_exit 0 "the same merge again" -- mv_verb merge "$MOE_MODEL" --out m experts-full-24 experts-full-32
  second="$(stamp_of_merge)"
  assert_eq "1" "$([ "$first" != "$second" ] && echo 1 || echo 0)" "the second stamp is another one"
  assert_eq "$sum_before" "$(sha256sum "$OUTD/merged/$first"/* | sort)" "the first record has the same bytes"
  assert_eq "$time_before" "$(stat -c '%n %Y' "$OUTD/merged/$first"/* | sort)" "and the same times"
  assert_eq "2" "$(ls "$OUTD"/merged/*/merge.env | wc -l | tr -d ' ')" "two merge.env files"
  assert_missing "$EX/merged" "the exchange folder is still untouched"
}

# old_chunk <chunk> <empty|absent|nolayer>: the chunk.env of a recorded chunk as an older version wrote it: ACT_DTYPE empty, or not there; `nolayer` drops the LAYER line
old_chunk() {
  local env="$OUTD/chunks/$1/chunk.env"
  case $2 in
    nolayer) grep -v '^LAYER=' "$env" > "$env.new" ;;
    *) grep -v '^ACT_DTYPE=' "$env" > "$env.new"; [ "$2" != empty ] || echo "ACT_DTYPE=" >> "$env.new" ;;
  esac
  mv "$env.new" "$env"
}

t_u10b_a_merge_says_and_records_a_base_of_unknown_dtype_and_still_merges() {
  mv_setup "$FUNCNAME"
  mv_chunks 24 32 || return
  base_place
  assert_exit 0 "the default merge: --base auto merges the production file, whose dtype nobody recorded" -- mv_verb merge "$MOE_MODEL" --out m experts-full-24 experts-full-32
  local env="$OUTD/merged/$(stamp_of_merge)/merge.env"
  assert_eq "bfloat16" "$(env_get "$env" ACT_DTYPE)" "merge.env: ACT_DTYPE is the chunks' common value"
  assert_eq "unknown" "$(env_get "$env" BASE_ACT_DTYPE)" "merge.env: BASE_ACT_DTYPE is unknown (a base file is not a record)"
  assert_eq "1" "$(printf '%s\n' "$OUT" | grep -c '^note: ')" "one note"
  assert_contains "$OUT" "note: the base $R9700_WORK_DIR/moe/tune/merged/$FIX_B2_NAME is merged and the activation dtype it was tuned for is unknown; pass --base none to keep it out" "it names the base and the way to keep it out"
  assert_eq "merged: $(stamp_of_merge) (activate it with: moe-tune activate $MOE_MODEL $(stamp_of_merge) --out m)" "$(printf '%s\n' "$OUT" | tail -n 1)" "the last line is still the merged line"
  assert_exit 0 "--base none: the same chunks" -- mv_verb merge "$MOE_MODEL" --out m --base none experts-full-24 experts-full-32
  env="$OUTD/merged/$(stamp_of_merge)/merge.env"
  assert_eq "none" "$(env_get "$env" BASE_ACT_DTYPE)" "BASE_ACT_DTYPE=none without a base"
  assert_eq "bfloat16" "$(env_get "$env" ACT_DTYPE)" "and the chunks' dtype is still there"
  assert_not_contains "$OUT" "note: " "no note at all when nothing is mixed in"
}

t_u10c_a_merge_of_chunks_that_name_no_dtype_says_unknown_and_still_merges() {
  mv_setup "$FUNCNAME"
  mv_chunks 24 32 || return
  old_chunk experts-full-24 empty
  old_chunk experts-full-32 empty
  assert_exit 0 "chunks of an older version (ACT_DTYPE empty, as they were written)" -- mv_verb merge "$MOE_MODEL" --out m --base none experts-full-24 experts-full-32
  assert_eq "unknown" "$(env_get "$OUTD/merged/$(stamp_of_merge)/merge.env" ACT_DTYPE)" "merge.env: ACT_DTYPE=unknown"
  assert_contains "$OUT" "note: the chunks name no activation dtype (records of an older version); what the merged file was tuned for is unknown" "the note says so"
  assert_not_contains "$OUT" "differs from" "and it is not also called a difference"
}

t_u10d_a_merge_of_chunks_tuned_for_another_dtype_than_the_models_says_so_for_experts_only() {
  mv_setup "$FUNCNAME"
  mv_chunks 24 || return
  mv_variant "MOE_ACT_DTYPE=float16"
  assert_exit 0 "experts chunks tuned for bfloat16, merged under a model that serves float16" -- mv_verb merge "$MVM" --out m --base none experts-full-24
  assert_eq "bfloat16" "$(env_get "$OUTD/merged/$(stamp_of_merge)/merge.env" ACT_DTYPE)" "merge.env: ACT_DTYPE is what the chunks say"
  assert_contains "$OUT" "note: the chunks were tuned for the activation dtype bfloat16, the model's MOE_ACT_DTYPE is float16" "the note names both"
  chunk_json_for b1 256
  assert_exit 0 "a draft chunk" -- mv_verb chunk "$MOE_MODEL" --keys 256 --layer draft --out m
  assert_exit 0 "merged under the same float16 model: the draft layer is always bfloat16" -- mv_verb merge "$MVM" --out m --base none draft-full-256
  assert_not_contains "$OUT" "note: " "no note for the draft layer"
  assert_eq "bfloat16" "$(env_get "$OUTD/merged/$(stamp_of_merge)/merge.env" ACT_DTYPE)" "its ACT_DTYPE is bfloat16"
}

# ---- U13-U15: activate -----------------------------------------------------------------------------------------------------------------------

# two_merges: two records that DIFFER (the first holds key 24, the second keys 24 and 32); sets S1 and S2 and NAME
two_merges() {
  mv_chunks 24 32 || return 1
  mv_verb merge "$MOE_MODEL" --out m --base none experts-full-24 > /dev/null 2>&1 || return 1
  S1="$(ls "$OUTD/merged" | sort | head -n 1)"
  mv_verb merge "$MOE_MODEL" --out m --base none experts-full-24 experts-full-32 > /dev/null 2>&1 || return 1
  S2="$(ls "$OUTD/merged" | sort | tail -n 1)"
  NAME="$FIX_B2_NAME"
}

t_u13_activate_swaps_atomically_keeps_the_previous_file_and_records_what_is_active() {
  mv_setup "$FUNCNAME"
  wslc stop vllm > /dev/null
  two_merges || return
  assert_exit 0 "activate the first record" -- mv_verb activate "$MOE_MODEL" "$S1" --out m
  local act_out="$OUT"
  assert_exit 0 "the exchange file equals the record, byte for byte" -- cmp "$OUTD/merged/$S1/$NAME" "$EX/merged/$NAME"
  assert_eq "$S1" "$(env_get "$EX/merged/activate.env" STAMP)" "activate.env: STAMP"
  assert_eq "$NAME" "$(env_get "$EX/merged/activate.env" NAME)" "activate.env: NAME"
  assert_eq "$(sha256sum "$EX/merged/$NAME" | cut -d' ' -f1)" "$(env_get "$EX/merged/activate.env" SHA256)" "activate.env: SHA256"
  assert_eq "none" "$(env_get "$EX/merged/activate.env" PREVIOUS)" "activate.env: PREVIOUS=none"
  assert_eq "no" "$(env_get "$EX/merged/activate.env" FORCED)" "activate.env: FORCED=no"
  assert_contains "$(env_get "$EX/merged/activate.env" ACTIVATED_AT)" "T" "activate.env: ACTIVATED_AT"
  assert_contains "$act_out" "activated: $EX/merged/$NAME ($S1, sha256 $(sha256sum "$EX/merged/$NAME" | cut -c1-12); previous kept as none)" "the printed line"
  assert_eq "0" "$(parts_under "$EX")" "no .part- remains"
  assert_exit 0 "activate the second record" -- mv_verb activate "$MOE_MODEL" "$S2" --out m
  assert_exit 0 "the exchange file equals the second record" -- cmp "$OUTD/merged/$S2/$NAME" "$EX/merged/$NAME"
  local kept
  kept="$(ls "$EX/merged/previous")"
  assert_eq "1" "$(printf '%s\n' "$kept" | grep -c .)" "one previous file"
  assert_contains "$kept" "-$NAME" "named <UTC stamp>-<NAME>"
  assert_exit 0 "and it holds the FIRST record's bytes" -- cmp "$OUTD/merged/$S1/$NAME" "$EX/merged/previous/$kept"
  assert_eq "$EX/merged/previous/$kept" "$(env_get "$EX/merged/activate.env" PREVIOUS)" "activate.env: PREVIOUS is that path"
  assert_eq "$S2" "$(env_get "$EX/merged/activate.env" STAMP)" "STAMP moved on"
  assert_exit 0 "activate the second record again" -- mv_verb activate "$MOE_MODEL" "$S2" --out m
  assert_contains "$OUT" "already active" "it says so"
  assert_eq "1" "$(ls "$EX/merged/previous" | wc -l | tr -d ' ')" "and keeps nothing twice"
}

# activate_hold_bg <KNOB=seconds> <args...>: `bin/r9700 moe-tune activate <args...>` with a test knob, in the background, as the leader of a session of its own (SUP is
# its pid and its group id): a test kills the verb AND its one sleeper with `kill -KILL -- -$SUP`
activate_hold_bg() {
  local knob="$1"
  local -a drop=()
  local key
  shift
  while read -r key; do drop+=(-u "R9700_$key"); done < <(config_keys | awk '{ print $2 }')
  ( exec setsid env "${drop[@]}" "$knob" "$REPO/bin/r9700" moe-tune activate "$@" ) > "$CASE/sup.out" 2> "$CASE/sup.err" &
  SUP=$!
  guard_pid "$SUP" "supervisor-$SUP"
}

# kill_verb: the verb of activate_hold_bg and everything in its group, reaped
kill_verb() {
  kill -KILL -- "-$SUP" 2> /dev/null
  wait "$SUP" 2> /dev/null
  return 0
}

t_u13b_a_verb_killed_between_the_part_write_and_the_swap_leaves_the_old_file_and_the_next_activation_sweeps_the_part() {
  mv_setup "$FUNCNAME"
  wslc stop vllm > /dev/null
  two_merges || return
  mv_verb activate "$MOE_MODEL" "$S1" --out m > /dev/null 2>&1 || return
  activate_hold_bg R9700_TEST_ACTIVATE_HOLD_S=30 "$MOE_MODEL" "$S2" --out m
  assert_exit 0 "the part file appears (bounded wait)" -- wait_glob "$EX/merged/$NAME.part-*"
  kill_verb
  assert_eq "0" "$(ps -o pid= -g "$SUP" 2> /dev/null | grep -c .)" "nothing of the verb's group is left (the hold is ONE sleep, ended with the group)"
  assert_eq "0" "$(sed -n '/^_moe_activate_hold()/,/^}/p' "$REPO/lib/moe_verb.sh" | grep -cE 'while|date')" "the hold has no polling loop (one sleep, descriptor 9 closed)"
  assert_exit 0 "the exchange file is still the OLD bytes, never a half file" -- cmp "$OUTD/merged/$S1/$NAME" "$EX/merged/$NAME"
  assert_exit 0 "a part file is left" -- wait_glob "$EX/merged/$NAME.part-*" 1
  assert_exit 0 "the next activation" -- mv_verb activate "$MOE_MODEL" "$S2" --out m
  assert_contains "$OUT" "removed stale $EX/merged/$NAME.part-$SUP-" "it removes the part of the dead owner and says so"
  assert_contains "$OUT" "(owner $SUP gone)" "naming the owner"
  assert_exit 0 "the exchange file equals the second record" -- cmp "$OUTD/merged/$S2/$NAME" "$EX/merged/$NAME"
  assert_eq "0" "$(parts_under "$EX")" "no .part- remains"
}

# killed_after_the_swap: S1 active, then S2 swapped in and the verb killed before activate.env is renamed (the test knob holds it there)
killed_after_the_swap() {
  wslc stop vllm > /dev/null
  two_merges || return 1
  mv_verb activate "$MOE_MODEL" "$S1" --out m > /dev/null 2>&1 || return 1
  activate_hold_bg R9700_TEST_ACTIVATE_HOLD_AFTER_S=30 "$MOE_MODEL" "$S2" --out m
  local i
  for i in $(seq 1 100); do cmp -s "$OUTD/merged/$S2/$NAME" "$EX/merged/$NAME" && break; sleep 0.1; done
  kill_verb
}

t_u13f_a_verb_killed_after_the_swap_is_finished_by_the_next_activate() {
  mv_setup "$FUNCNAME"
  killed_after_the_swap || return
  assert_exit 0 "the config is the new one" -- cmp "$OUTD/merged/$S2/$NAME" "$EX/merged/$NAME"
  assert_eq "$S1" "$(env_get "$EX/merged/activate.env" STAMP)" "and activate.env still names the OLD activation (the window of the kill)"
  assert_exit 0 "the next activate of the same record" -- mv_verb activate "$MOE_MODEL" "$S2" --out m
  assert_contains "$OUT" "recovered activate.env from $EX/merged/activate.env.part-$SUP-" "it finishes the rename and says so"
  assert_contains "$OUT" "already active" "then there is nothing left to do"
  assert_eq "$S2" "$(env_get "$EX/merged/activate.env" STAMP)" "activate.env names the new activation"
  assert_eq "0" "$(parts_under "$EX")" "no .part- remains"
}

t_u13g_the_start_of_an_ab_finishes_it_too_and_refuses_a_leftover_that_is_not_the_active_file() {
  mv_setup "$FUNCNAME"
  killed_after_the_swap || return
  moe_ab_answers "/work/r9700/moe/$MOE_MODEL/merged" "$NAME" b2
  local ab_args=(ab "$MOE_MODEL" --keys "8 16 20 24 32 48 64 96 128 192 256" --rule median --rule-keys "24" --layer experts --out m)
  assert_exit 0 "an A/B after the kill" -- mv_verb "${ab_args[@]}"
  assert_contains "$(worker_log 1)" "recovered activate.env from" "its worker finished the rename first"
  assert_eq "$S2" "$(env_get "$EX/merged/activate.env" STAMP)" "activate.env names the new activation"
  # a leftover of a dead owner whose file is NOT the active one: the A/B refuses, the next activate sweeps it
  printf 'STAMP=x\nNAME=%s\nLAYER=experts\nSHA256=%s\n' "$NAME" "deadbeef" > "$EX/merged/activate.env.part-4194303-1"
  assert_exit 2 "an A/B with such a leftover" -- mv_verb "${ab_args[@]}"
  assert_contains "$ERR" "run moe-tune activate for the record again" "it says what to do"
  assert_exit 0 "activate of another record" -- mv_verb activate "$MOE_MODEL" "$S1" --out m
  assert_contains "$OUT" "removed stale $EX/merged/activate.env.part-4194303-1" "the sweep removes the leftover"
  assert_eq "0" "$(parts_under "$EX")" "no .part- remains"
}

t_u15b_activate_needs_a_layer_from_merge_env_or_from_the_option_and_the_two_must_agree() {
  mv_setup "$FUNCNAME"
  wslc stop vllm > /dev/null
  mv_record rec1 b2 # merge.env says experts
  assert_exit 2 "--layer draft over a record of the layer experts" -- mv_verb activate "$MOE_MODEL" rec1 --layer draft --out m
  assert_contains "$ERR" "is a record of the layer experts, not draft" "named"
  rm "$OUTD/merged/rec1/merge.env" # a record made by hand: no layer
  assert_exit 2 "a record whose layer nobody says" -- mv_verb activate "$MOE_MODEL" rec1 --out m
  assert_contains "$ERR" "pass --layer experts|draft" "the remedy"
  assert_missing "$EX/merged" "nothing was written"
  assert_exit 0 "with --layer" -- mv_verb activate "$MOE_MODEL" rec1 --layer experts --out m
  assert_eq "experts" "$(env_get "$EX/merged/activate.env" LAYER)" "activate.env records the layer"
  assert_eq "$FIX_B2_NAME" "$(env_get "$EX/merged/activate.env" NAME)" "and the file name"
  assert_exit 2 "--layer heads" -- mv_verb activate "$MOE_MODEL" rec1 --layer heads --out m
  assert_contains "$ERR" "experts draft" "names the legal layers"
}

t_u16_an_ab_in_a_fresh_out_reads_the_layer_and_the_file_from_activate_env_even_when_merged_holds_two_layers() {
  mv_setup "$FUNCNAME"
  mv_record recd b1
  mv_record rece b2
  assert_exit 0 "activate the draft record (the server is listed: --force)" -- mv_verb activate "$MOE_MODEL" recd --out m --force
  assert_exit 0 "activate the experts record" -- mv_verb activate "$MOE_MODEL" rece --out m --force
  assert_eq "2" "$(ls "$EX/merged"/E=*.json | wc -l | tr -d ' ')" "merged/ holds the files of two layers"
  moe_ab_answers "/work/r9700/moe/$MOE_MODEL/merged" "$FIX_B2_NAME" b2
  # a fresh --out: no chunk record says anything about a layer
  assert_exit 0 "an experts A/B in another --out" -- mv_verb ab "$MOE_MODEL" --keys "8 16 20 24 32 48 64 96 128 192 256" --rule median --rule-keys "24" --layer experts --out fresh
  assert_eq "$FIX_B2_NAME" "$(env_get "$(ls -d "$R9700_RESULTS_DIR"/fresh/ab/*/ | head -n 1)ab.env" B_FILE)" "B_FILE is the file activate.env names"
  assert_exit 2 "a draft A/B: the file activated last is of another layer" -- mv_verb ab "$MOE_MODEL" --keys "1 4" --rule each --rule-keys "1" --layer draft --out fresh
  assert_contains "$ERR" "the file activated last is of the layer experts, not draft; run moe-tune activate for a record of the layer draft" "the message says what to do"
  rm "$EX/merged/activate.env"
  assert_exit 2 "an A/B without activate.env" -- mv_verb ab "$MOE_MODEL" --keys "1 4" --rule each --rule-keys "1" --layer draft --out fresh
  assert_contains "$ERR" "merged/ holds no activate.env" "missing: refused with the remedy"
}

t_u1c_a_harness_left_by_an_older_series_is_refreshed_and_an_absent_one_stays_absent() {
  mv_setup "$FUNCNAME"
  assert_exit 0 "a verb chunk with no harness.py in the work folder" -- mv_verb chunk "$MOE_MODEL" --keys "24" --out m
  assert_missing "$WORK/harness.py" "the optional asset is not placed (that is series's job)"
  rm -rf "$OUTD"
  printf 'a harness of an older series\n' > "$WORK/harness.py"
  assert_exit 0 "a verb chunk with an OLDER harness.py there (a refusal for ever before)" -- mv_verb chunk "$MOE_MODEL" --keys "24" --out m
  assert_exit 0 "it was refreshed, byte for byte" -- cmp "$REPO/lib/harness.py" "$WORK/harness.py"
  assert_eq "$(sha256sum "$REPO/lib/harness.py" | cut -d' ' -f1)" "$(env_get "$OUTD/chunks/experts-full-24/chunk.env" HARNESS_SHA256)" "and chunk.env names its hash"
}

t_u17_container_paths_have_one_translation_that_refuses_what_is_not_under_work() {
  mv_setup "$FUNCNAME"
  assert_eq "$R9700_WORK_DIR/moe/tune/merged" "$(container_host_path /work/moe/tune/merged)" "/work/<rest> is WORK_DIR/<rest>"
  assert_eq "$R9700_WORK_DIR/r9700/moe/$MOE_MODEL" "$(moe_exchange_dir "$MOE_MODEL")" "the exchange folder is the translation of its container path"
  local bad rc
  assert_eq "$R9700_WORK_DIR/r9700/model..json" "$(container_host_path /work/r9700/model..json)" "a name that holds two dots is a path (only a whole component .. is refused)"
  assert_eq "$R9700_WORK_DIR/a/..b/c.." "$(container_host_path /work/a/..b/c..)" "and so are ..b and c.. as components"
  for bad in /data/moe /work /workx/a "/work/../etc" "/work/a/.." "/work/a/../b" "/work/a/b/../../.." ""; do
    container_host_path "$bad" > /dev/null 2>&1
    rc=$?
    assert_eq "1" "$rc" "\"$bad\" does not translate (1, never an empty answer taken for a path)"
  done
}

t_u14a_activate_is_refused_while_the_operators_server_is_listed() {
  mv_setup "$FUNCNAME"
  mv_record rec1 b2
  local before
  before="$(calls_n)"
  assert_exit 2 "activate with the server listed" -- mv_verb activate "$MOE_MODEL" rec1 --out m
  assert_contains "$ERR" "moe-tune: activate: vllm is running and may read $EX/merged; stop it, or pass --force" "the refusal line"
  assert_missing "$EX/merged" "the exchange folder was not touched"
  assert_eq "1" "$(since_count "$before" wslc list)" "the list was read"
  assert_eq "0" "$(since_count "$before" wslc stop)" "the toolkit never stops the operator's server for this"
}

t_u14b_a_prefixed_container_counts_as_a_reader_too() {
  mv_setup "$FUNCNAME"
  mv_record rec1 b2
  wslc stop vllm > /dev/null
  stub_container r9700tune-sp-x-1
  assert_exit 2 "activate with a prefixed container listed" -- mv_verb activate "$MOE_MODEL" rec1 --out m
  assert_contains "$ERR" "moe-tune: activate: r9700tune-sp-x-1 is running and may read $EX/merged" "it names the container"
  assert_missing "$EX/merged" "nothing was written"
}

t_u14c_force_is_the_operators_word_and_is_logged() {
  mv_setup "$FUNCNAME"
  mv_record rec1 b2
  assert_exit 0 "activate --force with the server listed" -- mv_verb activate "$MOE_MODEL" rec1 --out m --force
  assert_exit 0 "the swap is done" -- cmp "$OUTD/merged/rec1/$FIX_B2_NAME" "$EX/merged/$FIX_B2_NAME"
  assert_eq "yes" "$(env_get "$EX/merged/activate.env" FORCED)" "FORCED=yes"
  assert_contains "$(sup_log)" "activate: forced while vllm running" "the supervisor log says it"
  assert_eq "0" "$(prod_stops)" "the server was not stopped"
}

t_u14d_a_marker_restores_the_server_first_and_the_restored_server_is_a_reader() {
  mv_setup "$FUNCNAME"
  mv_record rec1 b2
  wslc stop vllm > /dev/null
  write_marker
  assert_exit 2 "activate with a marker and the server absent" -- mv_verb activate "$MOE_MODEL" rec1 --out m
  assert_eq "r9700: recovery marker found (run hand-1), restoring first" "$(printf '%s\n' "$OUT" | head -n 1)" "the first stdout line is the marker's"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the restore ran"
  assert_contains "$ERR" "vllm is running and may read" "and the restored server is a reader: refused"
  assert_missing "$EX/merged" "nothing was written"
}

t_u14e_a_run_that_holds_the_lock_gives_exit_4() {
  mv_setup "$FUNCNAME"
  mv_record rec1 b2
  fake_supervisor run || return
  assert_exit 4 "activate while a run holds the lock" -- mv_verb activate "$MOE_MODEL" rec1 --out m --force
  assert_contains "$ERR" "r9700: another run holds $R9700_STATE_DIR/lock: pid $SUP, step" "the holder line"
  assert_missing "$EX/merged" "nothing was written"
  kill -KILL "$SUP"
  kill -KILL -- "-$(awk '{ print $1 }' "$STUB"/workers/containers/worker-*.pid | head -n 1)" 2> /dev/null
  kill_recorded_pids "$CASE"
}

t_u14f_a_container_list_that_cannot_be_read_refuses_too_and_force_goes_on() {
  mv_setup "$FUNCNAME"
  mv_record rec1 b2
  wslc stop vllm > /dev/null
  printf '0 2\n' > "$STUB/fail-list"
  assert_exit 2 "activate when the list fails" -- mv_verb activate "$MOE_MODEL" rec1 --out m
  assert_contains "$ERR" "the container list cannot be read" "the line says so"
  assert_missing "$EX/merged" "nothing was written"
  assert_exit 0 "with --force it goes on" -- mv_verb activate "$MOE_MODEL" rec1 --out m --force
  assert_eq "yes" "$(env_get "$EX/merged/activate.env" FORCED)" "FORCED=yes"
}

# activate_bg <args...>: `bin/r9700 moe-tune activate <args...>` in the background as a user runs it (SUP, then step_end)
activate_bg() {
  local -a drop=()
  local key
  while read -r key; do drop+=(-u "R9700_$key"); done < <(config_keys | awk '{ print $2 }')
  ( exec env "${drop[@]}" "$REPO/bin/r9700" moe-tune activate "$@" ) > "$CASE/sup.out" 2> "$CASE/sup.err" &
  SUP=$!
  guard_pid "$SUP" "supervisor-$SUP"
}

t_u14g_a_term_during_a_hanging_container_list_ends_the_verb_at_once() {
  mv_setup "$FUNCNAME"
  mv_record rec1 b2
  wslc stop vllm > /dev/null
  printf 'hang\n' > "$STUB/mode"
  export R9700_CEILING_SCALE=1 # the list's own ceiling is 60 s: only the signal can end it in a few seconds
  activate_bg "$MOE_MODEL" rec1 --out m
  assert_exit 0 "the list call is hung (a hung process is recorded, bounded wait)" -- wait_glob "$STUB/hung/containers/*.pid"
  local t0 t1
  t0="$(date +%s.%N)"
  kill -TERM "$SUP"
  step_end
  t1="$(date +%s.%N)"
  assert_eq "143" "$SRC" "exit 143"
  if awk -v a="$t0" -v b="$t1" 'BEGIN { exit !(b - a < 8) }'; then assert_eq ok ok "the verb ended $(awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%.2f", b - a }') s after the TERM, not after the call's 60 s ceiling"; else assert_eq "< 8 s" "$(awk -v a="$t0" -v b="$t1" 'BEGIN { print b - a }')" "the verb ended at once"; fi
  assert_missing "$EX/merged" "nothing was written"
  unhang_all
}

# ---- U13c-e: an activation that fails half way leaves the machine as it found it -----------------------------------------------------------------

# state_of_exchange: every file of the exchange folder with its bytes' hash (the part files included), for "nothing changed" checks
state_of_exchange() { (cd "$EX/merged" 2> /dev/null && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum); }

t_u13c_a_swap_that_fails_removes_its_parts_and_refuses_and_changes_nothing() {
  mv_setup "$FUNCNAME"
  wslc stop vllm > /dev/null
  two_merges || return
  mkdir -p "$EX/merged/$NAME" # the active file's name is a folder: the rename of the part cannot succeed
  local before
  before="$(state_of_exchange)"
  assert_exit 2 "activate when the swap fails" -- mv_verb activate "$MOE_MODEL" "$S1" --out m
  assert_contains "$ERR" "moe-tune: activate: cannot move" "the refusal says which step failed"
  assert_eq "0" "$(parts_under "$EX")" "no .part- file remains (the config part and the activate.env part are removed)"
  assert_missing "$EX/merged/activate.env" "activate.env was not written: it says nothing false"
  assert_eq "$before" "$(state_of_exchange)" "the exchange folder is as it was"
}

t_u13d_an_activate_env_that_cannot_be_written_puts_the_previous_file_back_and_refuses() {
  mv_setup "$FUNCNAME"
  wslc stop vllm > /dev/null
  two_merges || return
  mv_verb activate "$MOE_MODEL" "$S1" --out m > /dev/null 2>&1 || return
  rm -f "$EX/merged/activate.env"
  mkdir "$EX/merged/activate.env" # the rename of activate.env.part onto it cannot succeed, AFTER the config was swapped
  assert_exit 2 "activate whose activate.env step fails" -- mv_verb activate "$MOE_MODEL" "$S2" --out m
  assert_contains "$ERR" "activate.env" "the refusal names it"
  assert_exit 0 "the previous file is back: the active file has the FIRST record's bytes" -- cmp "$OUTD/merged/$S1/$NAME" "$EX/merged/$NAME"
  assert_eq "0" "$(parts_under "$EX")" "no .part- file remains"
  assert_eq "1" "$(ls "$EX/merged/previous" | wc -l | tr -d ' ')" "the kept copy is still there (never deleted)"
}

t_u13e_the_same_failure_with_nothing_active_before_leaves_nothing_active() {
  mv_setup "$FUNCNAME"
  wslc stop vllm > /dev/null
  two_merges || return
  mkdir -p "$EX/merged/activate.env"
  assert_exit 2 "a first activation whose activate.env step fails" -- mv_verb activate "$MOE_MODEL" "$S1" --out m
  assert_missing "$EX/merged/$NAME" "no file is active: the swap was undone (there was no previous file)"
  assert_eq "0" "$(parts_under "$EX")" "no .part- file remains"
}

t_u15_activate_refuses_a_stamp_that_is_not_a_record() {
  mv_setup "$FUNCNAME"
  wslc stop vllm > /dev/null
  assert_exit 2 "a stamp with no folder" -- mv_verb activate "$MOE_MODEL" nosuch --out m
  assert_contains "$ERR" "moe-tune: activate: $OUTD/merged/nosuch is not a merge record (no E=*.json)" "named"
  mkdir -p "$OUTD/merged/two"
  printf '{}\n' > "$OUTD/merged/two/E=a.json"
  printf '{}\n' > "$OUTD/merged/two/E=b.json"
  assert_exit 2 "a stamp folder with two JSON files" -- mv_verb activate "$MOE_MODEL" two --out m
  assert_contains "$ERR" "E=a.json" "the first file is named"
  assert_contains "$ERR" "E=b.json" "and the second"
  assert_missing "$EX/merged" "nothing was written"
}

# ---- U11: ab through the verb ----------------------------------------------------------------------------------------------------------------

t_u11_ab_through_the_verb_reads_the_activated_file_records_the_decision_and_registers_the_hook() {
  mv_setup "$FUNCNAME"
  mv_record rec1 b1
  assert_exit 0 "activate the b1 record (the server is listed: --force)" -- mv_verb activate "$MOE_MODEL" rec1 --out m --force
  moe_ab_answers "/work/r9700/moe/$MOE_MODEL/merged" "$FIX_B1_NAME"
  local ab
  assert_exit 0 "ab through the verb" -- mv_verb ab "$MOE_MODEL" --keys "1 2 3 4 6 8 12 16" --rule each --rule-keys "1 4" --layer draft --out m
  ab="$(ls -d "$OUTD"/ab/*/ | head -n 1)"
  ab="${ab%/}"
  assert_eq "KERNEL: faster (each of 1 4 is faster by more than 3 %)" "$(cat "$ab/decision.txt")" "decision.txt"
  assert_eq "$(env_get "$EX/merged/activate.env" SHA256)" "$(env_get "$ab/ab.env" B_SHA256)" "B_SHA256 is the activated file's"
  assert_contains "$(env_get "$ab/ab.env" B_CONFIG_LINE)" "/work/r9700/moe/$MOE_MODEL/merged/$FIX_B1_NAME" "B_CONFIG_LINE names the activated file"
  local hook restored
  hook="$(sup_log | grep -n 'cleanup hook: moe_cache_clear rc=0' | head -n 1 | cut -d: -f1)"
  restored="$(sup_log | grep -n ' restored$' | head -n 1 | cut -d: -f1)"
  assert_eq "1" "$([ -n "$hook" ] && [ -n "$restored" ] && [ "$hook" -lt "$restored" ] && echo 1 || echo 0)" "the cleanup hook ran before the restore (lines $hook and $restored)"
  assert_eq "1" "$(prod_stops)" "the server was stopped once"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "and restored once"
}

t_u11b_ab_without_an_activation_is_refused_with_the_hint() {
  mv_setup "$FUNCNAME"
  assert_exit 2 "ab over a fresh exchange folder" -- mv_verb ab "$MOE_MODEL" --keys "1 4" --rule each --rule-keys "1 4" --layer draft --out m
  assert_contains "$ERR" "merged/ holds no activate.env" "the worker's detail"
  assert_contains "$ERR" "run moe-tune activate first" "and the hint"
  assert_missing "$OUTD/ab" "no A/B record"
}

# ---- U12: the verb is listed and catalogued ----------------------------------------------------------------------------------------------------

t_u12_the_verb_is_listed_and_a_model_that_is_not_there_is_refused_by_the_shared_resolver() {
  mv_setup "$FUNCNAME"
  assert_exit 0 "commands" -- r9700 commands
  assert_contains "$(printf '%s\n' "$OUT")" "moe-tune" "moe-tune is listed"
  assert_eq "1" "$(printf '%s\n' "$OUT" | grep -cx 'moe-tune')" "once"
  local before
  before="$(calls_n)"
  assert_exit 2 "a model that is not there" -- mv_verb chunk nosuchmodel --keys 1
  assert_contains "$ERR" 'r9700: model "nosuchmodel" not found; legal: ' "E1's model_resolve line"
  assert_eq "0" "$(since_count "$before" wslc stop)" "nothing was stopped"
  assert_exit 2 "the underscore spelling is not a verb" -- r9700 moe_tune chunk "$MOE_MODEL" --keys 1
}

# ---- the dtype of a merged file travels with it: merge.env, activate.env, ab.env ----------------------------------------------------------------------

t_u13h_activate_copies_the_dtypes_of_the_record_and_says_unknown_for_a_record_that_has_none() {
  mv_setup "$FUNCNAME"
  wslc stop vllm > /dev/null
  mv_chunks 24 || return
  assert_exit 0 "a merge with no base" -- mv_verb merge "$MOE_MODEL" --out m --base none experts-full-24
  local stamp
  stamp="$(stamp_of_merge)"
  assert_exit 0 "activate it" -- mv_verb activate "$MOE_MODEL" "$stamp" --out m
  assert_eq "bfloat16" "$(env_get "$EX/merged/activate.env" ACT_DTYPE)" "activate.env: ACT_DTYPE is the record's"
  assert_eq "none" "$(env_get "$EX/merged/activate.env" BASE_ACT_DTYPE)" "activate.env: BASE_ACT_DTYPE is the record's"
  mv_record hand b2 # merge.env of a record made by hand, or by an older version: no dtype keys
  assert_exit 0 "activate a record whose merge.env names no dtype" -- mv_verb activate "$MOE_MODEL" hand --out m
  assert_eq "unknown" "$(env_get "$EX/merged/activate.env" ACT_DTYPE)" "activate.env: ACT_DTYPE=unknown"
  assert_eq "unknown" "$(env_get "$EX/merged/activate.env" BASE_ACT_DTYPE)" "activate.env: BASE_ACT_DTYPE=unknown"
}

# latest_merge: the newest stamp under merged/ (for a merge made by a call that is not an assert_exit)
latest_merge() { ls "$OUTD/merged" | LC_ALL=C sort | tail -n 1; }

# ab_of_record: the experts A/B through the verb over the activated record; sets AB (its folder)
ab_of_record() {
  moe_ab_answers "/work/r9700/moe/$MOE_MODEL/merged" "$FIX_B2_NAME" b2
  mv_verb ab "$MOE_MODEL" --keys "8 16 20 24 32 48 64 96 128 192 256" --rule median --rule-keys "24" --layer experts --out m > /dev/null 2>&1 || return 1
  AB="$(ls -d "$OUTD"/ab/*/ | tail -n 1)"
  AB="${AB%/}"
}

t_u11c_ab_records_the_dtypes_of_the_activated_file_and_notes_one_that_is_not_the_runs_kind() {
  mv_setup "$FUNCNAME"
  mv_chunks 24 || return
  base_place
  # 1: a record with no base, made from chunks of the run's dtype: recorded, no note
  mv_verb merge "$MOE_MODEL" --out m --base none experts-full-24 > /dev/null 2>&1 || return
  mv_verb activate "$MOE_MODEL" "$(latest_merge)" --out m --force > /dev/null 2>&1 || return
  ab_of_record || return
  assert_eq "bfloat16" "$(env_get "$AB/ab.env" ACT_DTYPE)" "[no base] ACT_DTYPE stays what the A/B ran with"
  assert_eq "bfloat16" "$(env_get "$AB/ab.env" FILE_ACT_DTYPE)" "[no base] FILE_ACT_DTYPE is the file's"
  assert_eq "none" "$(env_get "$AB/ab.env" FILE_BASE_ACT_DTYPE)" "[no base] FILE_BASE_ACT_DTYPE=none"
  assert_eq "0" "$(worker_log 1 | grep -c '^note: ')" "[no base] no note"
  # 2: a record with the production file as base: still measured, with one note and the base's dtype recorded as unknown
  mv_verb merge "$MOE_MODEL" --out m experts-full-24 > /dev/null 2>&1 || return
  mv_verb activate "$MOE_MODEL" "$(latest_merge)" --out m --force > /dev/null 2>&1 || return
  ab_of_record || return
  assert_eq "unknown" "$(env_get "$AB/ab.env" FILE_BASE_ACT_DTYPE)" "[base] FILE_BASE_ACT_DTYPE=unknown"
  assert_eq "1" "$(worker_log 1 | grep -c '^note: ')" "[base] one note"
  assert_contains "$(worker_log 1)" "note: the activated file's activation dtype is bfloat16 and its base's is unknown; this A/B runs with bfloat16" "[base] it names the file's, the base's and the run's"
  assert_exit 0 "[base] the A/B was not refused: it has a decision" -- test -s "$AB/decision.txt"
  # 3: a record that names no dtype at all (by hand, or an older version)
  mv_record hand b2
  mv_verb activate "$MOE_MODEL" hand --out m --force > /dev/null 2>&1 || return
  ab_of_record || return
  assert_eq "unknown" "$(env_get "$AB/ab.env" FILE_ACT_DTYPE)" "[older record] FILE_ACT_DTYPE=unknown"
  assert_eq "unknown" "$(env_get "$AB/ab.env" FILE_BASE_ACT_DTYPE)" "[older record] FILE_BASE_ACT_DTYPE=unknown"
  assert_eq "1" "$(worker_log 1 | grep -c '^note: ')" "[older record] one note"
  assert_contains "$(worker_log 1)" "activation dtype is unknown and its base's is unknown; this A/B runs with bfloat16" "[older record] it says unknown"
}

t_u13i_an_activate_env_leftover_of_an_older_version_is_recovered_and_the_ab_calls_its_dtypes_unknown() {
  mv_setup "$FUNCNAME"
  killed_after_the_swap || return
  local part
  part="$(ls "$EX/merged"/activate.env.part-* | head -n 1)"
  assert_exit 0 "the leftover of the killed verb is there, with the dtype keys of this version" -- grep -q '^ACT_DTYPE=' "$part"
  sed -i '/^ACT_DTYPE=/d; /^BASE_ACT_DTYPE=/d' "$part" # what a verb of the older version wrote
  moe_ab_answers "/work/r9700/moe/$MOE_MODEL/merged" "$NAME" b2
  assert_exit 0 "an A/B after the kill" -- mv_verb ab "$MOE_MODEL" --keys "8 16 20 24 32 48 64 96 128 192 256" --rule median --rule-keys "24" --layer experts --out m
  assert_contains "$(worker_log 1)" "recovered activate.env from" "the worker finished the rename first"
  assert_eq "$S2" "$(env_get "$EX/merged/activate.env" STAMP)" "activate.env names the new activation"
  assert_eq "unknown" "$(env_get "$(ls -d "$OUTD"/ab/*/ | tail -n 1)ab.env" FILE_ACT_DTYPE)" "the A/B calls the dtype of that file unknown"
  assert_eq "unknown" "$(env_get "$(ls -d "$OUTD"/ab/*/ | tail -n 1)ab.env" FILE_BASE_ACT_DTYPE)" "and its base's"
}

# ---- a recorded chunk is checked for its layer too, and the dry run asks the same question -----------------------------------------------------------

t_u3d_a_recorded_chunk_of_another_layer_or_of_none_is_refused_and_a_resume_of_each_layer_is_not() {
  mv_setup "$FUNCNAME"
  assert_exit 0 "an experts chunk named mine" -- mv_verb chunk "$MOE_MODEL" --keys "24" --chunk mine --out m
  chunk_json_for b1 256
  assert_exit 0 "a draft chunk" -- mv_verb chunk "$MOE_MODEL" --keys "256" --layer draft --out m
  local before
  before="$(calls_n)"
  assert_exit 0 "resume of the experts chunk" -- mv_verb chunk "$MOE_MODEL" --keys "24" --chunk mine --out m
  assert_contains "$OUT" "moe-tune: chunk mine is recorded, nothing to do" "the experts resume is nothing to do"
  assert_exit 0 "resume of the draft chunk" -- mv_verb chunk "$MOE_MODEL" --keys "256" --layer draft --out m
  assert_contains "$OUT" "moe-tune: chunk draft-full-256 is recorded, nothing to do" "the draft resume is nothing to do (its record holds bfloat16)"
  assert_exit 2 "the experts chunk's name asked for the draft layer" -- mv_verb chunk "$MOE_MODEL" --keys "24" --layer draft --chunk mine --out m
  assert_contains "$ERR" "moe-tune: chunk mine is recorded for the layer experts but this run is of the layer draft: a record is never replaced, use another --out" "the line names both layers"
  assert_exit 2 "the draft chunk's name asked for the experts layer" -- mv_verb chunk "$MOE_MODEL" --keys "256" --chunk draft-full-256 --out m
  assert_contains "$ERR" "is recorded for the layer draft but this run is of the layer experts" "and the other way round"
  old_chunk mine nolayer
  assert_exit 2 "a record with no LAYER" -- mv_verb chunk "$MOE_MODEL" --keys "24" --chunk mine --out m
  assert_contains "$ERR" "moe-tune: chunk mine is recorded with no layer (a record that names none is not taken for experts): use another --out" "the line says the layer is unknown"
  assert_eq "0" "$(since_count "$before" wslc stop)" "no stop for any of them"
  assert_eq "0" "$(since_count "$before" wslc run)" "and no container"
}

t_u3e_a_dry_run_of_a_chunk_the_real_run_refuses_is_refused_and_one_it_accepts_prints_the_container_line() {
  mv_setup "$FUNCNAME"
  assert_exit 0 "the first verb chunk (the 35B file serves bfloat16)" -- mv_verb chunk "$MOE_MODEL" --keys "24" --out m
  mv_variant "MOE_ACT_DTYPE=float16"
  assert_exit 2 "the dry run under a model that serves float16" -- mv_verb chunk "$MVM" --keys "24" --out m --dry-run
  assert_contains "$ERR" "moe-tune: chunk experts-full-24 is recorded with ACT_DTYPE bfloat16 but this run tunes for float16" "the same line as the real run"
  assert_not_contains "$OUT" "dry-run: wslc run" "and no container line"
  assert_exit 2 "the real run is refused too" -- mv_verb chunk "$MVM" --keys "24" --out m
  assert_exit 0 "the dry run of the same dtype" -- mv_verb chunk "$MOE_MODEL" --keys "24" --out m --dry-run
  assert_contains "$OUT" "dry-run: wslc run --rm --name r9700tune-moe-tune-experts-full-24 " "it prints the container line as before"
  old_chunk experts-full-24 empty
  assert_exit 2 "the dry run over an old record" -- mv_verb chunk "$MOE_MODEL" --keys "24" --out m --dry-run
  assert_contains "$ERR" "recorded with no activation dtype" "refused"
}

run_all_tests
