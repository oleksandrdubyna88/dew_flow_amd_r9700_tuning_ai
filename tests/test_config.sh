#!/usr/bin/env bash
# lib/config.sh: the config loader and the arm table (scenarios 1-18, plus the S2 fields and the grammar edges).
# Every test body is a function t_<guarantee>; each runs in its own subshell and writes only below $R9700_TEST_ROOT.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=lib/config.sh
source "$REPO/lib/config.sh"

FIXTURE="$HERE/fixtures/config/machine.env.in"
MODEL_35B="$REPO/models/qwen3.6-35b-a3b-gptq.env"
MODEL_27B="$REPO/models/qwen3.8-27b-awq.env"
ARMS="$REPO/config/arms.conf"

# case_root <name>: a fresh folder with the files the machine fixture names (empty files stand in for the patches).
case_root() {
  local root="$R9700_TEST_ROOT/case-$1" file
  mkdir -p "$root/work" "$root/patches/C" "$root/patches/work/speed/o7" "$root/patches/work/speed/ra"
  for file in C/auto_gptq.py C/gptq_utils.py work/speed/o7/rdna_hybrid_w4a16.py work/speed/ra/rocm_attn.py; do : > "$root/patches/$file"; done
  echo "$root"
}

# variant <source file> <dest file> <root> [<KEY> [<replacement line, empty = remove the key>]]
# The source with every @ROOT@ replaced; the line of KEY replaced, removed, or (when absent) added.
variant() {
  local src="$1" dest="$2" root="$3" key="${4:-}" repl="${5-}" line out="" hit=0
  repl="${repl//@ROOT@/$root}"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line//@ROOT@/$root}"
    if [ -n "$key" ] && [[ $line == "$key="* ]]; then
      hit=1
      [ -n "$repl" ] && out+="$repl"$'\n'
      continue
    fi
    out+="$line"$'\n'
  done < "$src"
  if [ -n "$key" ] && [ "$hit" = 0 ] && [ -n "$repl" ]; then out+="$repl"$'\n'; fi
  printf '%s' "$out" > "$dest"
}

machine() { variant "$FIXTURE" "$1/machine.env" "$1" "${@:2}"; }
model() { variant "$1" "$2/model.env" "$2" "${@:3}"; }
legal_keys() { config_keys | awk -v scope="$1" '$1 == scope { printf "%s ", $2 }' | sed 's/ $//'; }
lines_of() { wc -l < "$1" | tr -d ' '; }

# ---- scenarios 1-2: the examples load, defaults apply ----------------------------------------------------------

t_the_machine_fixture_and_the_35b_example_load_and_apply_the_defaults() {
  local root; root="$(case_root "$FUNCNAME")"; machine "$root"
  assert_exit 0 "config_load returns 0" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_eq "" "$ERR" "nothing on stderr"
  assert_eq "qwen3.6-35b-a3b" "$R9700_SERVED_NAME" "served name"
  assert_eq "131072" "$R9700_MAX_MODEL_LEN" "max model len"
  assert_eq "8192 32768" "$R9700_PREFILL_LENS" "prefill lens"
  assert_eq "2048" "$R9700_RAM_MIN_MB" "RAM_MIN_MB default"
  assert_eq "r9700tune-" "$R9700_CONTAINER_PREFIX" "CONTAINER_PREFIX default"
  assert_eq "1500" "$R9700_CLEANUP_BUDGET_S" "CLEANUP_BUDGET_S default (1500: S2 decision 8)"
}

t_the_s2_lifecycle_fields_take_their_defaults() {
  local root; root="$(case_root "$FUNCNAME")"; machine "$root"
  assert_exit 0 "load" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_eq "1200" "$R9700_READY_TIMEOUT_S" "READY_TIMEOUT_S default"
  assert_eq "6" "$R9700_MAX_FAILED_TRIES" "MAX_FAILED_TRIES default"
  assert_eq "3" "$R9700_MAX_SERVER_STOPS" "MAX_SERVER_STOPS default"
  assert_eq "720" "$R9700_MAX_RUN_MINUTES" "MAX_RUN_MINUTES default"
  assert_eq "on" "$R9700_DISK_GATE" "DISK_GATE default"
  assert_eq "0.85" "$R9700_GPU_MEM_UTIL" "GPU_MEM_UTIL default"
}

t_every_example_model_file_loads_unedited() {
  local root file n=0; root="$(case_root "$FUNCNAME")"; machine "$root"
  for file in "$REPO"/models/*.env; do
    n=$((n + 1))
    assert_exit 0 "$(basename "$file") loads" -- config_load "$root/machine.env" "$file"
    assert_eq "" "$ERR" "$(basename "$file"): nothing on stderr"
  done
  assert_eq "2" "$n" "the loop found both example models"
  assert_exit 0 "27b loads" -- config_load "$root/machine.env" "$MODEL_27B"
  assert_eq "qwen3.8-27b" "$R9700_SERVED_NAME" "27b served name"
  assert_eq "16" "$R9700_MAX_NUM_SEQS" "27b max num seqs"
  assert_eq "16384" "$R9700_MAX_MODEL_LEN" "27b max model len"
  assert_eq "8192" "$R9700_PREFILL_LENS" "27b prefill lens"
}

# ---- scenarios 3-10: one refusal per kind of mistake -----------------------------------------------------------

t_a_missing_required_key_is_refused_with_the_field_and_its_legal_values() {
  local root; root="$(case_root "$FUNCNAME")"; machine "$root" IMAGE ""
  assert_exit 2 "refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_eq "1" "$(grep -c '^config: ' <<< "$ERR")" "exactly one config: line"
  assert_contains "$ERR" "IMAGE: required" "names the field"
  assert_contains "$ERR" "image reference <repository>:<tag>" "names the legal shape"
  assert_contains "$ERR" "$root/machine.env: IMAGE" "names the file but no line (the line does not exist)"
}

t_a_non_integer_is_refused_with_the_range() {
  local root n; root="$(case_root "$FUNCNAME")"; machine "$root" RAM_MIN_MB "RAM_MIN_MB=2GB"
  n="$(lines_of "$root/machine.env")"
  assert_exit 2 "refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" 'RAM_MIN_MB: "2GB" is not an integer; legal: 512..65536' "names the field, the value and the range"
  assert_contains "$ERR" "$root/machine.env:$n:" "names the file and the line number"
}

t_an_integer_outside_the_range_is_refused_with_the_range() {
  local root; root="$(case_root "$FUNCNAME")"; machine "$root" RAM_MIN_MB "RAM_MIN_MB=100"
  assert_exit 2 "refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" 'RAM_MIN_MB: "100" is outside 512..65536; legal: 512..65536' "range message"
  machine "$root" RAM_MIN_MB "RAM_MIN_MB=512"
  assert_exit 0 "the lowest legal value loads" -- config_load "$root/machine.env" "$MODEL_35B"
  machine "$root" RAM_MIN_MB "RAM_MIN_MB=65536"
  assert_exit 0 "the highest legal value loads" -- config_load "$root/machine.env" "$MODEL_35B"
}

t_an_enum_value_outside_the_set_is_refused_with_the_set() {
  local root; root="$(case_root "$FUNCNAME")"; machine "$root" DISK_GATE "DISK_GATE=maybe"
  assert_exit 2 "refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" 'DISK_GATE: "maybe" is not one of: on off' "names the set"
}

t_an_unknown_key_is_refused_with_the_list_of_legal_keys() {
  local root; root="$(case_root "$FUNCNAME")"; machine "$root" RAM_MIN "RAM_MIN=2048"
  assert_exit 2 "refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" "RAM_MIN: unknown key" "names the typo"
  assert_contains "$ERR" "legal: $(legal_keys machine)" "lists the machine keys exactly as config_keys prints them"
  assert_contains "$ERR" "RAM_MIN_MB" "the right spelling is in the list"
}

t_a_key_of_the_other_scope_is_unknown_in_this_file() {
  local root; root="$(case_root "$FUNCNAME")"; machine "$root"
  model "$MODEL_35B" "$root" IMAGE "IMAGE=rocm/vllm:x"
  assert_exit 2 "IMAGE in a model file is refused" -- config_load "$root/machine.env" "$root/model.env"
  assert_contains "$ERR" "IMAGE: unknown key; legal: $(legal_keys model)" "lists the model keys"
  machine "$root" SERVED_NAME "SERVED_NAME=x"
  assert_exit 2 "SERVED_NAME in a machine file is refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" "SERVED_NAME: unknown key" "refused"
}

t_the_loader_never_executes_the_file() {
  local root; root="$(case_root "$FUNCNAME")"
  machine "$root" IMAGE 'IMAGE=$(touch @ROOT@/pwned)'
  assert_exit 2 "dollar form refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" 'IMAGE: "$" and "`" are not allowed (values are never expanded)' "says why"
  assert_missing "$root/pwned" "the command did not run"
  machine "$root" IMAGE 'IMAGE=`touch @ROOT@/pwned2`'
  assert_exit 2 "backtick form refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" 'IMAGE: "$" and "`" are not allowed (values are never expanded)' "says why"
  assert_missing "$root/pwned2" "the backtick command did not run"
  machine "$root" IMAGE 'IMAGE="rocm/vllm:$HOME"'
  assert_exit 2 "a dollar inside quotes is refused too" -- config_load "$root/machine.env" "$MODEL_35B"
}

t_all_errors_are_reported_in_one_pass() {
  local root; root="$(case_root "$FUNCNAME")"; machine "$root" RAM_MIN_MB "RAM_MIN_MB=x"
  printf '%s\n' "DISK_GATE=maybe" >> "$root/machine.env"
  assert_exit 2 "refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_eq "2" "$(grep -c '^config: ' <<< "$ERR")" "exactly two config: lines"
  assert_contains "$ERR" "RAM_MIN_MB" "first field"
  assert_contains "$ERR" "DISK_GATE" "second field"
}

t_a_failed_load_leaves_no_half_loaded_values() {
  local root; root="$(case_root "$FUNCNAME")"; machine "$root"
  assert_exit 0 "a good load first" -- config_load "$root/machine.env" "$MODEL_35B"
  machine "$root" RAM_MIN_MB "RAM_MIN_MB=x"
  assert_exit 2 "then a bad one" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_eq "" "${R9700_SERVED_NAME:-}" "no value of the earlier load survives a refused one"
  assert_eq "" "${R9700_IMAGE:-}" "not even a valid field of the refused file"
}

t_a_duplicate_key_is_refused() {
  local root first second; root="$(case_root "$FUNCNAME")"; machine "$root"
  first="$(grep -n '^IMAGE=' "$root/machine.env" | cut -d: -f1)"
  printf '%s\n' "IMAGE=rocm/vllm:other" >> "$root/machine.env"
  second="$(lines_of "$root/machine.env")"
  assert_exit 2 "refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" "machine.env:$second: IMAGE: set twice (first on line $first)" "names both lines"
}

t_a_wsl_path_where_a_windows_path_is_required_is_refused() {
  local root; root="$(case_root "$FUNCNAME")"; machine "$root" WORK_DIR_WIN "WORK_DIR_WIN=/mnt/c/r9700/work"
  assert_exit 2 "refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" 'WORK_DIR_WIN: "/mnt/c/r9700/work" is not a Windows path; legal: X:\…' "names the shape"
}

t_a_directory_that_does_not_exist_is_refused() {
  local root; root="$(case_root "$FUNCNAME")"; machine "$root" WORK_DIR "WORK_DIR=@ROOT@/nowhere"
  assert_exit 2 "refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" "WORK_DIR: \"$root/nowhere\" is not an existing absolute directory" "names the path"
  machine "$root" RESULTS_DIR "RESULTS_DIR=@ROOT@/missing-parent/results"
  assert_exit 2 "a results dir whose parent is missing is refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" "RESULTS_DIR" "names the field"
}

t_the_grammar_refuses_crlf_unbalanced_quotes_and_text_after_the_closing_quote() {
  local root; root="$(case_root "$FUNCNAME")"
  machine "$root"; printf 'DISK_GATE=on\r\n' >> "$root/machine.env"
  assert_exit 2 "a CRLF line end is refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" "DISK_GATE" "names the field"
  machine "$root" RESTORE_ARGS 'RESTORE_ARGS="-Detach'
  assert_exit 2 "an unterminated quote is refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" "RESTORE_ARGS" "names the field"
  machine "$root" RESTORE_ARGS 'RESTORE_ARGS="-Detach" -Extra'
  assert_exit 2 "text after the closing quote is refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" "trailing text after the closing quote" "says why"
  machine "$root" RESTORE_ARGS 'RESTORE_ARGS="-De"tach"'
  assert_exit 2 "a quote inside a quoted value is refused" -- config_load "$root/machine.env" "$MODEL_35B"
  machine "$root" RESTORE_ARGS 'RESTORE_ARGS=-Model x'
  assert_exit 2 "a bare value with a space is refused" -- config_load "$root/machine.env" "$MODEL_35B"
  machine "$root" RESTORE_ARGS "RESTORE_ARGS='-Detach'"
  assert_exit 2 "single quotes are refused" -- config_load "$root/machine.env" "$MODEL_35B"
  machine "$root"; printf 'this is not a key line\n' >> "$root/machine.env"
  assert_exit 2 "a line that is neither KEY=VALUE nor a comment is refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" "machine.env:$(lines_of "$root/machine.env"):" "names its line"
}

t_an_unreadable_file_is_refused_by_name() {
  local root; root="$(case_root "$FUNCNAME")"; machine "$root"
  assert_exit 2 "a missing model file is refused" -- config_load "$root/machine.env" "$root/nosuch.env"
  assert_contains "$ERR" "config: $root/nosuch.env: cannot read" "names the file"
}

# ---- scenarios 11-12 and the other cross-field checks ----------------------------------------------------------

t_a_prefill_length_that_does_not_fit_the_context_is_refused() {
  local root; root="$(case_root "$FUNCNAME")"; machine "$root"
  model "$MODEL_27B" "$root" PREFILL_LENS 'PREFILL_LENS="8192 16384"'
  assert_exit 2 "refused" -- config_load "$root/machine.env" "$root/model.env"
  assert_contains "$ERR" "PREFILL_LENS: 16384 + 128 output tokens exceed MAX_MODEL_LEN 16384" "names the length and the limit"
  assert_exit 0 "the unchanged 27B file passes (the positive for the same fixture)" -- config_load "$root/machine.env" "$MODEL_27B"
  model "$MODEL_27B" "$root" PREFILL_LENS 'PREFILL_LENS="8192 16256"'
  assert_exit 0 "16256 + 128 = 16384 fits exactly" -- config_load "$root/machine.env" "$root/model.env"
}

t_a_mount_that_leaves_the_patch_directory_is_refused() {
  local root; root="$(case_root "$FUNCNAME")"; machine "$root"
  model "$MODEL_35B" "$root" MOUNTS 'MOUNTS="../x.py:/opt/x.py:ro"'
  assert_exit 2 "refused" -- config_load "$root/machine.env" "$root/model.env"
  assert_contains "$ERR" 'MOUNTS: "../x.py" leaves PATCH_DIR' "names the source"
  model "$MODEL_35B" "$root" MOUNTS 'MOUNTS="/etc/x.py:/opt/x.py:ro"'
  assert_exit 2 "an absolute source is refused" -- config_load "$root/machine.env" "$root/model.env"
  assert_contains "$ERR" 'MOUNTS: "/etc/x.py" leaves PATCH_DIR' "names the source"
}

t_a_mount_source_that_does_not_exist_under_the_patch_directory_is_refused() {
  local root; root="$(case_root "$FUNCNAME")"; machine "$root"
  rm "$root/patches/C/auto_gptq.py"
  assert_exit 2 "refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" 'MOUNTS: "C/auto_gptq.py" does not exist under PATCH_DIR' "names the missing source"
}

t_a_cleanup_budget_that_cannot_hold_the_restore_is_refused() {
  local root; root="$(case_root "$FUNCNAME")"
  machine "$root" CLEANUP_BUDGET_S "CLEANUP_BUDGET_S=1319"
  assert_exit 2 "1319 < 1200 + 120 is refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" "CLEANUP_BUDGET_S: 1319 is less than READY_TIMEOUT_S 1200 + 120" "names both fields"
  machine "$root" CLEANUP_BUDGET_S "CLEANUP_BUDGET_S=1320"
  assert_exit 0 "1320 = 1200 + 120 passes" -- config_load "$root/machine.env" "$MODEL_35B"
  machine "$root" READY_TIMEOUT_S "READY_TIMEOUT_S=3480"
  assert_exit 2 "the default budget 1500 cannot hold a 3480 s readiness wait" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" "READY_TIMEOUT_S 3480 + 120" "names the readiness value"
  printf '%s\n' "CLEANUP_BUDGET_S=3600" >> "$root/machine.env"
  assert_exit 0 "READY_TIMEOUT_S 3480 with the largest budget 3600 = 3480 + 120 passes" -- config_load "$root/machine.env" "$MODEL_35B"
}

t_the_readiness_timeout_tops_out_where_the_largest_budget_can_still_hold_it() {
  local root; root="$(case_root "$FUNCNAME")"
  machine "$root" READY_TIMEOUT_S "READY_TIMEOUT_S=3481"
  assert_exit 2 "3481 is refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" 'READY_TIMEOUT_S: "3481" is outside 60..3480' "the range is 60..3480"
}

# ---- the resolved view -----------------------------------------------------------------------------------------

t_config_resolved_prints_every_value_sorted_by_key_defaults_included() {
  local root keys; root="$(case_root "$FUNCNAME")"; machine "$root"
  assert_exit 0 "load" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_exit 0 "resolved" -- config_resolved
  keys="$(sed 's/=.*//' <<< "$OUT")"
  assert_eq "$(LC_ALL=C sort <<< "$keys")" "$keys" "sorted by key"
  assert_contains "$OUT" "R9700_RAM_MIN_MB=2048" "a default is there"
  assert_contains "$OUT" "R9700_SERVED_NAME=qwen3.6-35b-a3b" "a model value is there"
  assert_eq "$(config_keys | wc -l | tr -d ' ')" "$(wc -l <<< "$OUT" | tr -d ' ')" "one line per field of the table"
}

# ---- scenarios 13-16: the arm table ----------------------------------------------------------------------------

t_the_arm_table_gives_the_measured_arguments() {
  local mtp1 mtp2 mtp3 arm got
  mtp1="--speculative-config.method mtp --speculative-config.num_speculative_tokens 1"
  mtp2="--speculative-config.method mtp --speculative-config.num_speculative_tokens 2"
  mtp3="--speculative-config.method mtp --speculative-config.num_speculative_tokens 3"
  declare -A ref=(
    [base]="$mtp2" [fbase]="$mtp2" [mtp1]="$mtp1" [mtp3]="$mtp3" [ra3]="$mtp3"
    [mnbt8k]="$mtp2 --max-num-batched-tokens 8192" [tattn]="$mtp2 --attention-backend TRITON_ATTN" [fp8kv]="$mtp2 --kv-cache-dtype fp8"
    [fcombo]="$mtp3 --attention-backend TRITON_ATTN" [o7ref]="$mtp3 --attention-backend TRITON_ATTN" [ta3]="$mtp3 --attention-backend TRITON_ATTN"
    [ta3mb]="$mtp3 --attention-backend TRITON_ATTN --max-num-batched-tokens 8192" [fb1]="$mtp2"
    [o7]="$mtp3 --attention-backend TRITON_ATTN" [ra3opt]="$mtp3"
  )
  assert_exit 0 "arms_load" -- arms_load "$ARMS"
  for arm in "${!ref[@]}"; do
    mapfile -t got < <(arm_args "$arm")
    assert_eq "${ref[$arm]}" "${got[*]}" "arm_args $arm"
  done
  assert_eq "4" "$(arm_args base | wc -l | tr -d ' ')" "one argument per line"
  assert_eq "VLLM_TUNED_CONFIG_FOLDER=/work/moe/tune/merged_b1" "$(arm_env fb1)" "arm_env fb1"
  assert_eq "" "$(arm_env base)" "arm_env base is empty"
  assert_eq "work/speed/o7/rdna_hybrid_w4a16.py:/opt/python/lib/python3.14/site-packages/vllm/model_executor/kernels/linear/mixed_precision/rdna_hybrid_w4a16.py:ro" \
    "$(arm_mounts o7)" "arm_mounts o7 prints the one o7 mount"
  assert_eq "work/speed/ra/rocm_attn.py:/opt/python/lib/python3.14/site-packages/vllm/v1/attention/backends/rocm_attn.py:ro" \
    "$(arm_mounts ra3opt)" "arm_mounts ra3opt"
  assert_eq "" "$(arm_mounts base)" "arm_mounts base is empty"
}

t_generation_config_is_not_in_the_arm_table() {
  assert_exit 0 "arms_load" -- arms_load "$ARMS"
  assert_not_contains "$(grep -v '^#' "$ARMS")" "generation-config" "serve.sh adds it for every arm"
}

t_an_unknown_arm_is_refused_with_the_legal_arms() {
  local name
  assert_exit 0 "arms_load" -- arms_load "$ARMS"
  assert_exit 2 "arms_check base nosuch" -- arms_check base nosuch
  assert_contains "$ERR" 'arm "nosuch" is not in config/arms.conf; legal:' "names the arm and the table"
  while read -r name; do assert_contains "$ERR" "$name" "legal arm $name is listed"; done < <(arms_names)
}

t_a_missing_mount_source_is_refused_before_use() {
  local root; root="$(case_root "$FUNCNAME")"; machine "$root"
  assert_exit 0 "load" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_exit 0 "arms_load" -- arms_load "$ARMS"
  rm "$root/patches/work/speed/o7/rdna_hybrid_w4a16.py"
  assert_exit 2 "arms_check o7 is refused" -- arms_check o7
  assert_contains "$ERR" "work/speed/o7/rdna_hybrid_w4a16.py" "names the missing file"
  assert_exit 0 "arms_check fcombo is fine" -- arms_check fcombo
}

t_a_duplicate_arm_is_refused_with_its_line() {
  local root; root="$(case_root "$FUNCNAME")"
  printf '%s\n' "# two rows of one arm" "base | --a 1 | | " "base | --a 2 | | " > "$root/arms.conf"
  assert_exit 2 "refused" -- arms_load "$root/arms.conf"
  assert_contains "$ERR" "base: defined twice (lines 2 and 3)" "names both lines"
}

t_an_arm_row_with_a_bad_name_quotes_or_wrong_field_count_is_refused() {
  local root; root="$(case_root "$FUNCNAME")"
  printf '%s\n' "Base | --a 1 | | " > "$root/arms.conf"
  assert_exit 2 "an upper-case name is refused" -- arms_load "$root/arms.conf"
  assert_contains "$ERR" 'Base: arm names are' "says what a name is"
  printf '%s\n' 'base | --a "1" | | ' > "$root/arms.conf"
  assert_exit 2 "quotes in the arguments are refused" -- arms_load "$root/arms.conf"
  printf '%s\n' 'base | --a $HOME | | ' > "$root/arms.conf"
  assert_exit 2 "a dollar in the arguments is refused" -- arms_load "$root/arms.conf"
  printf '%s\n' 'base | --a 1 | ' > "$root/arms.conf"
  assert_exit 2 "three fields instead of four are refused" -- arms_load "$root/arms.conf"
  assert_contains "$ERR" "arms.conf:1:" "names the line"
  printf '%s\n' 'base | --a 1 | lowercase=1 | ' > "$root/arms.conf"
  assert_exit 2 "an env word that is not KEY=VALUE with an upper-case key is refused" -- arms_load "$root/arms.conf"
  printf '%s\n' 'base | --a 1 | | ../x.py:/opt/x.py:ro' > "$root/arms.conf"
  assert_exit 2 "a mount that leaves the patch directory is refused" -- arms_load "$root/arms.conf"
}

t_an_arm_row_applies_the_same_argument_check_as_extra_serve_args() {
  local root bad; root="$(case_root "$FUNCNAME")"
  for bad in '--a *' '--a [x]' '--a ?' "--a"$'\t'"b"; do
    printf '%s\n' "base | $bad | |" > "$root/arms.conf"
    assert_exit 2 "arms_load refuses [$bad]" -- arms_load "$root/arms.conf"
    assert_contains "$ERR" "base:" "names the arm"
  done
  printf '%s\n' "base | --a b --c 1 | |" > "$root/arms.conf"
  assert_exit 0 "plain words load" -- arms_load "$root/arms.conf"
  assert_eq "1" "$(grep -c '_cfg_args_problem' "$REPO/lib/config.sh" | awk '{ print ($1 >= 3) }')" "one function (defined once, used by the type check and the arm table)"
}

# ---- scenarios 17-18: the docs and the example file hold exactly the keys of the table -------------------------

t_every_field_is_documented_and_nothing_else_is() {
  local table doc
  table="$(config_keys | awk '{print $2}' | LC_ALL=C sort)"
  doc="$(awk -F'|' '$2 ~ /^ *`[A-Z][A-Z0-9_]*` *$/ { gsub(/[ `]/, "", $2); print $2 }' "$REPO/research/module_config.md" | LC_ALL=C sort)"
  assert_eq "" "$(diff <(echo "$table") <(echo "$doc"))" "the keys of config_keys equal the keys of the doc tables"
  assert_eq "1" "$([ -n "$table" ] && echo 1)" "the scan found keys (a scan of nothing proves nothing)"
}

t_the_example_machine_file_holds_every_machine_key() {
  local key n=0
  while read -r key; do
    n=$((n + 1))
    grep -qE "^(# )?$key=" "$REPO/machine.env.example"
    assert_eq "0" "$?" "machine.env.example holds $key"
  done < <(config_keys | awk '$1 == "machine" { print $2 }')
  assert_eq "1" "$([ "$n" -gt 20 ] && echo 1)" "the loop found the machine keys"
}

t_an_optional_machine_key_is_commented_out_in_the_example_and_a_required_one_is_not() {
  local scope key type default
  while read -r scope key type default; do
    [ "$scope" = machine ] || continue
    if [ "$default" = required ]; then
      assert_eq "1" "$(grep -cE "^$key=" "$REPO/machine.env.example")" "required $key is set (as a placeholder)"
    else
      assert_eq "1" "$(grep -cE "^# $key=" "$REPO/machine.env.example")" "optional $key is commented out at its default"
    fi
  done < <(config_keys)
}

t_the_example_machine_file_loads_once_its_placeholders_name_real_folders() {
  local root; root="$(case_root "$FUNCNAME")"
  sed -e "s#^WORK_DIR=.*#WORK_DIR=$root/work#" -e "s#^PATCH_DIR=.*#PATCH_DIR=$root/patches#" \
    -e "s#^RESULTS_DIR=.*#RESULTS_DIR=$root/results#" "$REPO/machine.env.example" > "$root/machine.env"
  assert_exit 0 "the example file is valid config once the three WSL folders exist" -- config_load "$root/machine.env" "$MODEL_35B"
}

# ---- review round: one refusal and one boundary-good value per field TYPE, the types derived from config_keys -------

# type family | scope | KEY | boundary-good line | bad line   (a type of config_keys without a row here fails the test)
TYPE_CASES=(
  'cmd|machine|WSLC|WSLC="/a b/wslc.exe"|WSLC=.'
  'image|machine|IMAGE|IMAGE=a:b|IMAGE=Rocm/vllm:x'
  'name|machine|HF_VOLUME|HF_VOLUME=a|HF_VOLUME=_a'
  'prefix|machine|CONTAINER_PREFIX|CONTAINER_PREFIX=aaaaaaaaaaaaaaaa-|CONTAINER_PREFIX=aaaaaaaaaaaaaaaaa-'
  'dir|machine|WORK_DIR|WORK_DIR=@ROOT@/work|WORK_DIR=@ROOT@/nowhere'
  'path|machine|RESULTS_DIR|RESULTS_DIR=@ROOT@/results|RESULTS_DIR=results'
  'win|machine|WORK_DIR_WIN|WORK_DIR_WIN=C:\|WORK_DIR_WIN=C:'
  'cpath|machine|GSM8K_DATA|GSM8K_DATA=/|GSM8K_DATA=work/x'
  'cpath?|model|TUNED_CONFIG_DIR|TUNED_CONFIG_DIR=|TUNED_CONFIG_DIR=work/x'
  'int|machine|RAM_MIN_MB|RAM_MIN_MB=512|RAM_MIN_MB=511'
  'dec|model|GPU_MEM_UTIL|GPU_MEM_UTIL=0.95|GPU_MEM_UTIL=0.951'
  'enum|machine|DISK_GATE|DISK_GATE=off|DISK_GATE=of'
  'hhmm?|machine|DEADLINE|DEADLINE=23:59|DEADLINE=24:00'
  'str|machine|RESTORE_ARGS|RESTORE_ARGS=-Detach|RESTORE_ARGS="   "'
  'str?|machine|QUIET_BUSY_PATTERN|QUIET_BUSY_PATTERN="a b"|QUIET_BUSY_PATTERN=a$b'
  'ints|model|PREFILL_LENS|PREFILL_LENS=8192|PREFILL_LENS=0'
  'mounts|model|MOUNTS|MOUNTS=C/auto_gptq.py:/opt/x.py|MOUNTS=C/auto_gptq.py'
  'args|model|EXTRA_SERVE_ARGS|EXTRA_SERVE_ARGS="--a b"|EXTRA_SERVE_ARGS="--a *"'
)

t_every_field_type_has_a_refusal_and_a_boundary_good_value_and_the_loader_applies_them() {
  local row type scope key good bad root families="" family seen=" " n=0
  root="$(case_root "$FUNCNAME")"
  while read -r family; do
    families+="$family "
  done < <(config_keys | awk '{ t = $3; sub(/:.*/, "", t); print t }' | sort -u)
  for family in $families; do
    for row in "${TYPE_CASES[@]}"; do [ "${row%%|*}" = "$family" ] && seen+="$family "; done
    case " $seen" in *" $family "*) ;; *) _assert_fail "type $family has a case" "add a row for the type \"$family\" to TYPE_CASES" ;; esac
  done
  for row in "${TYPE_CASES[@]}"; do
    IFS='|' read -r type scope key good bad <<< "$row"
    n=$((n + 1))
    case " $families" in *" $type "*) ;; *) _assert_fail "case for $type" "no field has the type \"$type\" any more" ;; esac
    machine "$root"
    if [ "$scope" = machine ]; then machine "$root" "$key" "$good"; assert_exit 0 "$type: boundary-good $key line loads" -- config_load "$root/machine.env" "$MODEL_35B"
    else model "$MODEL_35B" "$root" "$key" "$good"; assert_exit 0 "$type: boundary-good $key line loads" -- config_load "$root/machine.env" "$root/model.env"; fi
    machine "$root"
    if [ "$scope" = machine ]; then machine "$root" "$key" "$bad"; assert_exit 2 "$type: bad $key line is refused" -- config_load "$root/machine.env" "$MODEL_35B"
    else model "$MODEL_35B" "$root" "$key" "$bad"; assert_exit 2 "$type: bad $key line is refused" -- config_load "$root/machine.env" "$root/model.env"; fi
    assert_contains "$ERR" "$key:" "$type: the refusal names $key"
  done
  assert_eq "1" "$([ "$n" -ge 17 ] && echo 1)" "the table has a row per type"
}

t_a_container_prefix_error_states_the_length_the_pattern_allows() {
  local root; root="$(case_root "$FUNCNAME")"
  machine "$root" CONTAINER_PREFIX "CONTAINER_PREFIX=aaaaaaaaaaaaaaaaa-"
  assert_exit 2 "18 characters are refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" "2 to 17 characters" "the legal text and the pattern agree"
}

# ---- review round: cross-field and grammar edges ---------------------------------------------------------------

t_the_operator_server_name_must_not_start_with_the_container_prefix() {
  local root; root="$(case_root "$FUNCNAME")"
  machine "$root" PROD_CONTAINER "PROD_CONTAINER=r9700tune-vllm"
  assert_exit 2 "a production container named under the default prefix is refused" -- config_load "$root/machine.env" "$MODEL_35B"
  assert_contains "$ERR" "PROD_CONTAINER must not start with CONTAINER_PREFIX" "says why"
  machine "$root" PROD_CONTAINER "PROD_CONTAINER=x-server"
  printf '%s\n' "CONTAINER_PREFIX=x-" >> "$root/machine.env"
  assert_exit 2 "the same for a custom prefix" -- config_load "$root/machine.env" "$MODEL_35B"
  machine "$root" PROD_CONTAINER "PROD_CONTAINER=r9700tune"
  assert_exit 0 "a name that merely begins like the prefix without its closing dash is fine" -- config_load "$root/machine.env" "$MODEL_35B"
}

t_cross_field_checks_run_even_when_a_single_field_is_wrong() {
  local root; root="$(case_root "$FUNCNAME")"
  machine "$root" RAM_MIN_MB "RAM_MIN_MB=x"
  model "$MODEL_27B" "$root" PREFILL_LENS 'PREFILL_LENS="8192 16384"'
  assert_exit 2 "refused" -- config_load "$root/machine.env" "$root/model.env"
  assert_contains "$ERR" "RAM_MIN_MB" "the single-field error is there"
  assert_contains "$ERR" "PREFILL_LENS: 16384 + 128 output tokens exceed MAX_MODEL_LEN 16384" "and the cross-field one"
}

t_a_huge_prefill_length_cannot_overflow_the_arithmetic() {
  local root; root="$(case_root "$FUNCNAME")"; machine "$root"
  model "$MODEL_35B" "$root" PREFILL_LENS "PREFILL_LENS=9223372036854775807"
  assert_exit 2 "refused" -- config_load "$root/machine.env" "$root/model.env"
  assert_contains "$ERR" "PREFILL_LENS" "names the field"
  model "$MODEL_35B" "$root" PREFILL_LENS 'PREFILL_LENS="8192 8192"'
  assert_exit 2 "a repeated length is refused" -- config_load "$root/machine.env" "$root/model.env"
}

t_a_windows_path_with_a_second_colon_or_a_reserved_character_is_refused() {
  local root; root="$(case_root "$FUNCNAME")"
  machine "$root" WORK_DIR_WIN 'WORK_DIR_WIN=C:\r9700\work:/etc'
  assert_exit 2 "a colon after the drive is refused" -- config_load "$root/machine.env" "$MODEL_35B"
  machine "$root" WORK_DIR_WIN 'WORK_DIR_WIN=C:\a|b'
  assert_exit 2 "a pipe is refused" -- config_load "$root/machine.env" "$MODEL_35B"
  machine "$root" WORK_DIR_WIN 'WORK_DIR_WIN=C:\a*b'
  assert_exit 2 "a star is refused" -- config_load "$root/machine.env" "$MODEL_35B"
  machine "$root" WORK_DIR_WIN 'WORK_DIR_WIN=C:\a?b'
  assert_exit 2 "a question mark is refused" -- config_load "$root/machine.env" "$MODEL_35B"
}

t_a_command_cannot_be_dot_or_start_with_a_dash_and_args_refuse_globs_and_tabs() {
  local root; root="$(case_root "$FUNCNAME")"
  machine "$root" WSLC "WSLC=.."
  assert_exit 2 "dot-dot is not a command" -- config_load "$root/machine.env" "$MODEL_35B"
  machine "$root" WSLC "WSLC=-rf"
  assert_exit 2 "a name starting with a dash is not a command" -- config_load "$root/machine.env" "$MODEL_35B"
  machine "$root"
  model "$MODEL_35B" "$root" EXTRA_SERVE_ARGS 'EXTRA_SERVE_ARGS="--a [x]"'
  assert_exit 2 "a glob bracket in the serve arguments is refused" -- config_load "$root/machine.env" "$root/model.env"
  model "$MODEL_35B" "$root" EXTRA_SERVE_ARGS "EXTRA_SERVE_ARGS=\"--a"$'\t'"b\""
  assert_exit 2 "a tab in the serve arguments is refused" -- config_load "$root/machine.env" "$root/model.env"
}

t_a_utf8_byte_order_mark_gets_its_own_error() {
  local root; root="$(case_root "$FUNCNAME")"; machine "$root"
  { printf '\xef\xbb\xbf'; cat "$root/machine.env"; } > "$root/bom.env"
  assert_exit 2 "refused" -- config_load "$root/bom.env" "$MODEL_35B"
  assert_contains "$ERR" "file starts with a UTF-8 byte-order mark" "says exactly that"
  assert_eq "1" "$(grep -c '^config: ' <<< "$ERR")" "one error, not a second syntax error for the same line"
  { printf '\xef\xbb\xbf'; cat "$ARMS"; } > "$root/bom-arms.conf"
  assert_exit 2 "the arm table too" -- arms_load "$root/bom-arms.conf"
  assert_contains "$ERR" "file starts with a UTF-8 byte-order mark" "says exactly that"
}

t_an_old_bash_is_refused_with_one_line() {
  assert_exit 1 "bash 3.2 is refused" -- _cfg_bash_guard 3 2
  assert_eq "1" "$(wc -l <<< "$ERR" | tr -d ' ')" "one line"
  assert_contains "$ERR" "bash 4.4 or newer" "says what is needed"
  assert_exit 1 "bash 4.3 is refused" -- _cfg_bash_guard 4 3
  assert_exit 0 "bash 4.4 passes" -- _cfg_bash_guard 4 4
  assert_exit 0 "the running bash passes" -- _cfg_bash_guard "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}"
}

t_an_unknown_arm_message_names_the_arms_file_it_was_looked_up_in() {
  local root; root="$(case_root "$FUNCNAME")"
  printf '%s\n' "mine | --a 1 | |" > "$root/other.conf"
  assert_exit 0 "load a custom table" -- arms_load "$root/other.conf"
  assert_exit 2 "an unknown arm" -- arms_check nosuch
  assert_contains "$ERR" "arm \"nosuch\" is not in $root/other.conf; legal: mine" "the file as given"
  assert_exit 0 "load the shipped table" -- arms_load "$ARMS"
  assert_exit 2 "an unknown arm" -- arms_check nosuch
  assert_contains "$ERR" 'arm "nosuch" is not in config/arms.conf; legal:' "a file under the working directory is shown relative to it"
}

t_the_example_comments_and_the_doc_column_equal_the_field_descriptions() {
  local key desc line prev doc
  while read -r key desc; do
    prev=""
    while IFS= read -r line; do
      case $line in "$key="* | "# $key="*) break ;; esac
      prev="$line"
    done < "$REPO/machine.env.example"
    if [ "$(config_keys | awk -v k="$key" '$2 == k { print $1 }')" = machine ]; then
      assert_eq "# $desc" "$prev" "machine.env.example: the comment line above $key is its description"
    fi
    doc="$(awk -F'|' -v k="\`$key\`" '{ c = $2; gsub(/^ +| +$/, "", c) } c == k { d = $5; gsub(/^ +| +$/, "", d); print d }' "$REPO/research/module_config.md")"
    assert_eq "$desc" "$doc" "module_config.md: the description column of $key"
  done < <(config_descriptions)
}

run_all_tests
