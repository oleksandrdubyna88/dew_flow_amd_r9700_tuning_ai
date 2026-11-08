#!/usr/bin/env bash
# What proves a ComfyUI arm took effect (E2.S2): scenarios BE1-BE8 (the evidence, in the stub world of tests/lib/benchcase.sh) and BA1-BA3 (the arm and evidence tables).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"
# shellcheck source=tests/lib/lifecycle.sh
source "$HERE/lib/lifecycle.sh"
# shellcheck source=tests/lib/benchcase.sh
source "$HERE/lib/benchcase.sh"

# BE1-BE8: the evidence

# BE1
t_an_arms_activation_evidence_is_recorded_beside_the_timings_and_its_absence_rejects_the_arm_round() {
  bench_setup "$FUNCNAME"
  knobs MAX_FAILED_TRIES=1
  assert_exit 0 "fp16acc with its default log" -- cb zimage 1 base fp16acc
  assert_exit 0 "evidence.txt names the check and the line of the log" -- grep -Eq '^activation log=Enabled fp16 accumulation: present \(server\.log:[0-9]+\)$' "$(rec fp16acc-1 evidence.txt)"
  newout cb2
  : > "$STUB/answers/comfy_evidence.fp16acc"
  assert_exit 7 "fp16acc with its evidence line gone" -- cb zimage 1 base fp16acc
  assert_eq "EVIDENCE: activation log=Enabled fp16 accumulation: missing (server.log)" "$(sed -n 1p "$(reject_of fp16acc-1)/reason")" "rejected, line 1 names what is missing"
  assert_missing "$OUTD/rounds/fp16acc-1" "no record"
}

# BE2
t_the_argv_alone_is_never_activation_evidence() {
  bench_setup "$FUNCNAME"
  knobs MAX_FAILED_TRIES=1
  assert_exit 0 "fp8wmm with the dtype line and the flag" -- cb zimage 1 base fp8wmm
  newout cb2
  printf 'INFO nothing about the dtype\n' > "$STUB/answers/comfy_evidence.fp8wmm"
  assert_exit 7 "the flag is in the argv, the dtype line is not in the log" -- cb zimage 1 base fp8wmm
  assert_contains "$(reason_of fp8wmm-1)" 'log=model weight dtype torch\.float8_e4m3fn: missing' "rejected naming the dtype line"
  newout cb3
  rm -f "$STUB/answers/comfy_evidence.fp8wmm"
  printf '{"server_argv": ["main.py"]}\n' > "$STUB/answers/comfy_bench_json"
  assert_exit 7 "the dtype line is in the log, the flag is not in the argv" -- cb zimage 1 base fp8wmm
  assert_contains "$(reason_of fp8wmm-1)" "argv=fp8_matrix_mult: missing (runs/cold.json)" "rejected naming the argv word"
  local ev="$CASE/arm_evidence.conf"
  sed 's/^fp8wmm .*/fp8wmm | argv=fp8_matrix_mult | -/' "$REPO/comfyui/arm_evidence.conf" > "$ev"
  export R9700_COMFY_EVIDENCE_CONF="$ev"
  assert_exit 2 "an evidence table whose fp8wmm activation is the argv alone" -- comfy_bench_check zimage 1 base fp8wmm
  assert_eq "r9700: comfy: bench: arm_evidence.conf: fp8wmm: the activation evidence is the argv alone; a passed flag is never proof it acted" "$ERR" "is refused before the lock, with its reason"
}

# BE3
t_fp16acc_is_inert_only_when_the_models_compute_dtype_and_the_vaes_dtype_are_both_bf16() {
  bench_setup "$FUNCNAME"
  printf 'Enabled fp16 accumulation.\nmodel weight dtype torch.bfloat16, manual cast: None\nVAE load device: cuda:0, offload device: cpu, dtype: torch.bfloat16\n' > "$STUB/answers/comfy_evidence.fp16acc"
  assert_exit 0 "fp16acc on bf16 weights and a bf16 VAE" -- cb zimage 1 base fp16acc
  assert_eq "yes" "$(env_val "$(rec fp16acc-1 record.env)" INERT)" "INERT=yes"
  assert_contains "$(env_val "$(rec fp16acc-1 record.env)" INERT_EVIDENCE)" "model weight dtype torch.bfloat16" "INERT_EVIDENCE holds the model's line"
  assert_contains "$(env_val "$(rec fp16acc-1 record.env)" INERT_EVIDENCE)" "dtype: torch.bfloat16" "and the VAE's"
  assert_contains "$(wlog)" "fp16acc-1: inert on zimage (" "the worker prints it"
  newout cb2
  printf 'Enabled fp16 accumulation.\nmodel weight dtype torch.bfloat16, manual cast: None\nVAE load device: cuda:0, offload device: cpu, dtype: torch.float16\n' > "$STUB/answers/comfy_evidence.fp16acc"
  assert_exit 0 "the same with an fp16 VAE" -- cb zimage 1 base fp16acc
  assert_eq "no" "$(env_val "$(rec fp16acc-1 record.env)" INERT)" "INERT=no: an acting arm"
  assert_not_contains "$(wlog)" "fp16acc-1: inert on" "no inert line"
}

# BE4
t_tunableops_results_file_must_be_non_empty_and_hold_rows() {
  bench_setup "$FUNCNAME"
  knobs MAX_FAILED_TRIES=1
  : > "$STUB/answers/comfy_tunableop"
  assert_exit 7 "an empty results file" -- cb zimage 1 base tunableop
  assert_contains "$(sed -n 1p "$(reject_of tunableop-1)/reason")" "tunable=tunableop_results.csv: missing (empty)" "rejected: empty"
  newout cb2
  printf 'Validator,PT_VERSION,2.13\nValidator,ROCM_VERSION,7.1\n' > "$STUB/answers/comfy_tunableop"
  assert_exit 7 "only Validator lines" -- cb zimage 1 base tunableop
  assert_contains "$(sed -n 1p "$(reject_of tunableop-1)/reason")" "tunable=tunableop_results.csv: missing (no result row)" "rejected: no result row"
  newout cb3
  printf 'GemmTunableOp_float_NN,nn_1024_1024_1024,Gemm_Hipblaslt_1,0.1\n' > "$STUB/answers/comfy_tunableop"
  assert_exit 7 "a row and no Validator line" -- cb zimage 1 base tunableop
  assert_contains "$(sed -n 1p "$(reject_of tunableop-1)/reason")" "no validator" "rejected: the file is not a TunableOp file"
}

# BE5
t_miopen_is_active_only_without_the_cudnn_off_line_and_with_find_lines_in_the_cold_run() {
  bench_setup "$FUNCNAME"
  knobs MAX_FAILED_TRIES=1
  assert_exit 0 "miopen with a find line in the cold run" -- cb zimage 1 base miopen
  newout cb2
  printf 'Set: torch.backends.cudnn.enabled = False for better AMD performance.\nMIOpen(HIP): Info [Find] x\n' > "$STUB/answers/comfy_evidence.miopen"
  assert_exit 7 "ComfyUI set cudnn off" -- cb zimage 1 base miopen
  assert_match "$(sed -n 1p "$(reject_of miopen-1)/reason")" '^EVIDENCE: activation nolog=cudnn\\.enabled = False: present \(server\.log:[0-9]+\)$' "rejected, naming the line number"
  newout cb3
  : > "$STUB/answers/comfy_evidence.miopen"
  printf 'MIOpen(HIP): Info [Find] x\n' > "$STUB/answers/comfy_bench_log.2"
  assert_exit 7 "a find line only in run 2's cut" -- cb zimage 1 base miopen
  assert_contains "$(reason_of miopen-1)" 'coldlog=MIOpen\(HIP\): Info.*[Ff]ind: missing (runs/cold.log)' "rejected: the cold run has none"
}

# BE7
t_base_is_accepted_with_its_attention_line_and_rejected_without_it() {
  bench_setup "$FUNCNAME"
  knobs MAX_FAILED_TRIES=1
  assert_exit 0 "base with its attention line" -- cb zimage 1 base
  newout cb2
  : > "$STUB/answers/comfy_evidence.base"
  assert_exit 7 "base without it" -- cb zimage 1 base
  assert_eq "EVIDENCE: activation log=Using pytorch attention: missing (server.log)" "$(sed -n 1p "$(reject_of base-1)/reason")" "rejected"
}

# BE8
t_the_evidence_tables_grammar_names_the_file_the_line_and_the_problem() {
  bench_setup "$FUNCNAME"
  local f="$CASE/ev.conf"
  printf 'base | log=x\n' > "$f"
  assert_exit 2 "a row with one |" -- comfy_evidence_load "$f"
  assert_eq "r9700: comfy: $f:1: a row has three fields (arm, activation, inertness), this one has 2" "$ERR" "names the file, the line and the count"
  printf 'base | foo=x | -\n' > "$f"
  assert_exit 2 "an unknown kind" -- comfy_evidence_load "$f"
  assert_eq "r9700: comfy: $f:1: unknown check kind \"foo\"; legal: log, nolog, coldlog, node, cache, tunable, argv" "$ERR" "names the legal kinds"
  printf 'base | log= | -\n' > "$f"
  assert_exit 2 "an empty argument" -- comfy_evidence_load "$f"
  assert_eq "r9700: comfy: $f:1: the check \"log=\" has no argument" "$ERR" "is named"
  printf 'base | log=x | -\nbase | log=y | -\n' > "$f"
  assert_exit 2 "a row twice" -- comfy_evidence_load "$f"
  assert_contains "$ERR" "$f:2: the arm \"base\" is defined twice" "is named with both lines"
  printf 'base | - | -\nfp16acc | log=a ; nolog=b | log=c\n' > "$f"
  assert_exit 0 "dash fields and checks joined by ;" -- comfy_evidence_load "$f"
  assert_eq "" "${_CE_ACT[base]}${_CE_INERT[base]}" "- loads as none"
  assert_eq "log=a ; nolog=b" "${_CE_ACT[fp16acc]}" "the field as written"
  assert_eq "log=a|nolog=b" "$(comfy_evidence_checks "${_CE_ACT[fp16acc]}" | tr '\n' '|' | sed 's/|$//')" "and split into its checks"
  printf 'base | log=( | -\nbad | log=x\nfp16acc | log=a | -\n' > "$f"
  assert_exit 2 "three problems" -- comfy_evidence_load "$f"
  assert_eq "2" "$(grep -c "^r9700: comfy: $f:" <<< "$ERR")" "are all reported in one pass (a regular expression grep refuses, a row of two fields)"
  assert_exit 0 "the real table loads" -- comfy_evidence_load "$REPO/comfyui/arm_evidence.conf"
}

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# The tables (BA1-BA3)

# BA1
t_the_six_rows_of_arms_conf_are_the_parents_arms_and_differ_from_base_in_one_change() {
  bench_setup "$FUNCNAME"
  assert_exit 0 "arms.conf loads" -- arms_load "$REPO/comfyui/arms.conf"
  assert_eq "base fp16acc fp8wmm tunableop miopen compile" "$(arms_names | tr '\n' ' ' | sed 's/ $//')" "the six arms in file order"
  local arm
  declare -A a_args a_env
  a_args=([base]="" [fp16acc]="--fast fp16_accumulation" [fp8wmm]="--fast fp8_matrix_mult" [tunableop]="" [miopen]="" [compile]="")
  a_env=([base]="" [fp16acc]="" [fp8wmm]="COMFY_BENCH_WEIGHT_DTYPE=fp8_e4m3fn"
       [tunableop]="PYTORCH_TUNABLEOP_ENABLED=1 PYTORCH_TUNABLEOP_FILENAME=/cache/tunableop/tunableop_results.csv PYTORCH_TUNABLEOP_MAX_TUNING_DURATION_MS=10 PYTORCH_TUNABLEOP_MAX_TUNING_ITERATIONS=10"
       [miopen]="COMFYUI_ENABLE_MIOPEN=1 MIOPEN_FIND_MODE=FAST MIOPEN_LOG_LEVEL=5" [compile]="COMFY_BENCH_COMPILE=1 TORCHINDUCTOR_CACHE_DIR=/cache/inductor TORCH_LOGS=recompiles")
  for arm in base fp16acc fp8wmm tunableop miopen compile; do
    assert_eq "${a_args[$arm]}" "$(arm_args "$arm" | tr '\n' ' ' | sed 's/ $//')" "$arm: the arguments"
    assert_eq "${a_env[$arm]}" "$(arm_env "$arm" | tr '\n' ' ' | sed 's/ $//')" "$arm: the environment"
    assert_eq "" "$(arm_mounts "$arm")" "$arm: no mount"
  done
}

# BA2
t_every_arm_has_exactly_one_evidence_row_and_the_other_way_round() {
  bench_setup "$FUNCNAME"
  arms_load "$REPO/comfyui/arms.conf"
  local arm_names ev_names
  arm_names="$(arms_names | LC_ALL=C sort | tr '\n' ' ')"
  comfy_evidence_load "$REPO/comfyui/arm_evidence.conf"
  ev_names="$(printf '%s\n' "${_CE_ORDER[@]}" | LC_ALL=C sort | tr '\n' ' ')"
  assert_eq "$arm_names" "$ev_names" "the arm names of the two files are the same set"
  assert_exit 0 "the scan is alive: there are six" -- test "$(wc -w <<< "$ev_names" | tr -d ' ')" -eq 6
  local ev="$CASE/arm_evidence.conf"
  grep -v '^miopen ' "$REPO/comfyui/arm_evidence.conf" > "$ev"
  export R9700_COMFY_EVIDENCE_CONF="$ev"
  assert_exit 2 "an evidence table without the miopen row" -- comfy_bench_check zimage 1 base
  assert_contains "$ERR" 'arm "miopen" has no row in arm_evidence.conf' "is refused naming the arm"
  { cat "$REPO/comfyui/arm_evidence.conf"; echo 'frob | log=x | -'; } > "$ev"
  assert_exit 2 "an evidence table with an extra row" -- comfy_bench_check zimage 1 base
  assert_contains "$ERR" 'arm_evidence.conf names "frob", which is not an arm of arms.conf' "is refused naming the row"
  rm -f "$CASE/arm_evidence.conf"
  unset R9700_COMFY_EVIDENCE_CONF
  assert_exit 0 "the real tables pass the check" -- comfy_bench_check zimage 1 base fp16acc fp8wmm tunableop miopen compile
}

# BA3
t_no_row_sets_a_forbidden_word_and_the_check_refuses_one_that_does() {
  bench_setup "$FUNCNAME"
  arms_load "$REPO/comfyui/arms.conf"
  local arm word bad="" n=0
  for arm in $(arms_names); do
    n=$((n + 1))
    [[ " $(arm_env "$arm" | tr '\n' ' ') " != *" PYTORCH_HIP_ALLOC_CONF="* ]] || bad+="$arm:alloc "
    for word in $(arm_args "$arm"); do case $word in --highvram | --lowvram | --normalvram | --gpu-only | --novram | --cpu | --listen | --port | --output-directory | --base-directory | --models-directory) bad+="$arm:$word " ;; esac; done
    [ -z "$(arm_mounts "$arm")" ] || bad+="$arm:mount "
  done
  assert_eq "" "$bad" "no row sets trap 1's variable, a memory mode, a word the worker owns or a mount"
  assert_exit 0 "the scan is alive: six rows" -- test "$n" -eq 6
  assert_contains "$(arm_env tunableop | tr '\n' ' ')" "PYTORCH_TUNABLEOP_MAX_TUNING_DURATION_MS=10" "tunableop carries the duration bound"
  assert_contains "$(arm_env tunableop | tr '\n' ' ')" "PYTORCH_TUNABLEOP_MAX_TUNING_ITERATIONS=10" "and the iteration bound"
  assert_contains "$(arm_env tunableop | tr '\n' ' ')" "PYTORCH_TUNABLEOP_FILENAME=/cache/tunableop/tunableop_results.csv" "and the file name"
  assert_contains "$(arm_env compile | tr '\n' ' ')" "TORCHINDUCTOR_CACHE_DIR=/cache/inductor" "compile carries the inductor cache folder"
  local copy="$CASE/arms.conf"
  sed 's/^fp16acc .*/fp16acc | --fast fp16_accumulation | PYTORCH_HIP_ALLOC_CONF=expandable_segments:True |/' "$REPO/comfyui/arms.conf" > "$copy"
  export R9700_COMFY_ARMS_CONF="$copy"
  assert_exit 2 "a copy with trap 1's variable in a row" -- comfy_bench_check zimage 1 base fp16acc
  assert_contains "$ERR" "PYTORCH_HIP_ALLOC_CONF: trap 1" "is refused naming trap 1"
  local row
  for row in "fp16acc | --fast fp16_accumulation | COMFY_BENCH_TEST_RUN_MAX_S=1 |" "fp16acc | --fast fp16_accumulation | COMFY_BENCH_API=http://127.0.0.1:1 |" "fp16acc | --fast fp16_accumulation | COMFY_BENCH_FROB=1 |" \
             "fp16acc | --disable-smart-memory | |" "fp16acc | --reserve-vram 2 | |" "fp16acc | --cache-lru 10 | |" "fp16acc | --lowvram | |" "fp16acc | --novram | |"; do
    sed "s#^fp16acc .*#$row#" "$REPO/comfyui/arms.conf" > "$copy"
    assert_exit 2 "a row [$row]" -- comfy_bench_check zimage 1 base fp16acc
    assert_match "$ERR" 'arm "fp16acc" sets (COMFY_BENCH_[A-Z_]+: only COMFY_BENCH_WEIGHT_DTYPE, COMFY_BENCH_COMPILE are words of an arm|--[a-z-]+, a memory or cache mode|--[a-z]+ ?[0-9]*, a memory or cache mode|--[a-z-]+)' "is refused: no row relaxes its own ceilings or sets a memory mode"
  done
  sed 's/^fp16acc .*/fp16acc | --fast fp16_accumulation | COMFY_BENCH_COMPILE=1 |/' "$REPO/comfyui/arms.conf" > "$copy"
  assert_exit 0 "the two legal COMFY_BENCH_ words are legal" -- comfy_bench_check zimage 1 base fp16acc
}


run_all_tests
