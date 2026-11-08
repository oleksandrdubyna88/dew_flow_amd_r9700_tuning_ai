#!/usr/bin/env bash
# The arm-round of a ComfyUI arm (E2.S2), part 2: what is rejected and why, and what a record holds: BW9 (an execution error, a constant output, a cached sampler, a failed block check), BW10 and BW11 (the load and the recompile flag), BW12 (the balanced order), BW13 (the part sweep), BW19 (the clean and the forced stop). The stub world and the way the worker is run are described in tests/test_comfy_bench.sh.
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



t_an_execution_error_rejects_the_arm_round_with_its_line_and_counts_a_failed_try() {
  bench_setup "$FUNCNAME"
  knobs MAX_FAILED_TRIES=1
  printf 'error\n' > "$STUB/answers/comfy_bench_mode.2"
  assert_exit 7 "an execution_error in run 2" -- cb zimage 1 base
  assert_eq "EXECUTION_ERROR: node sampler (KSampler): boom" "$(sed -n 1p "$(reject_of base-1)/reason")" "line 1 of the reason"
  assert_contains "$(cat "$(run_dir_of)/supervisor.log")" "failed try 1 of 1" "the step's failed try is counted"
  assert_exit 1 "the container is not listed" -- listed r9700tune-comfy-base-1
  assert_missing "$OUTD/rounds/base-1" "no record"
}

t_a_constant_output_and_a_cached_sampler_are_rejected_with_their_lines() {
  bench_setup "$FUNCNAME"
  knobs MAX_FAILED_TRIES=1
  printf 'constant\n' > "$STUB/answers/comfy_bench_mode.1"
  assert_exit 7 "a constant image in run 1" -- cb zimage 1 base
  assert_eq "OUTPUT: the image is constant (every pixel 128)" "$(sed -n 1p "$(reject_of base-1)/reason")" "line 1"
  newout cb2
  printf 'cached\n' > "$STUB/answers/comfy_bench_mode.1"
  assert_exit 7 "a sampler that came from the cache" -- cb zimage 1 base
  assert_contains "$(sed -n 1p "$(reject_of base-1)/reason")" "CACHED: the sampler did not execute" "line 1"
  assert_exit 1 "the container is not listed" -- listed r9700tune-comfy-base-1
}

t_a_bench_txt_that_fails_the_block_check_rejects_the_arm_round() {
  bench_setup "$FUNCNAME"
  knobs MAX_FAILED_TRIES=1
  printf 'r=1 total_s: 12.000\nr=1 sampler_s: 10.000\nr=1 vae_s: 1.500\nr=2 total_s: 12.000\nr=2 sampler_s: 10.000\nr=2 vae_s: 1.500\nr=3 total_s: 12.000\nr=3 sampler_s: 10.000\n' > "$STUB/answers/comfy_bench_lines"
  assert_exit 7 "the line r=3 vae_s is left out" -- cb zimage 1 base
  assert_contains "$(reason_of base-1)" "check-block: expected 9 lines, found 8" "the block check's first line"
  assert_contains "$(reason_of base-1)" "missing r=3 vae_s" "and the line that is missing"
  assert_missing "$OUTD/rounds/base-1" "no record"
  assert_exit 1 "the container is not listed" -- listed r9700tune-comfy-base-1
}

t_a_model_load_inside_a_measured_run_is_flagged_outside_bench_txt() {
  bench_setup "$FUNCNAME"
  printf 'Requested to load WAN21\nloaded completely 9.5 1.2 True\n' > "$STUB/answers/comfy_bench_log.2"
  assert_exit 0 "a load in run 2" -- cb zimage 1 base
  assert_eq "run 1: load 0, recompile 0|run 2: load 2, recompile 0|run 3: load 0, recompile 0" "$(tr '\n' '|' < "$(rec base-1 flags.txt)" | sed 's/|$//')" "flags.txt: one line per measured run"
  assert_eq "load=2,recompile=0" "$(env_val "$(rec base-1 record.env)" FLAGS_RUN_2)" "record.env"
  assert_eq "load=0,recompile=0" "$(env_val "$(rec base-1 record.env)" FLAGS_RUN_1)" "a run without one is not flagged"
  assert_not_contains "$(cat "$(rec base-1 bench.txt)")" "load" "bench.txt holds no such line"
  assert_exit 0 "and still passes the block check" -- python3 "$REPO/lib/verdict.py" comfy-check-block --tag base-1 --workflow zimage --metrics "total_s sampler_s vae_s" "$(rec base-1 bench.txt)"
}

t_a_recompile_inside_a_measured_run_is_flagged_and_is_never_the_activation_evidence() {
  bench_setup "$FUNCNAME"
  knobs MAX_FAILED_TRIES=1
  printf 'Recompiling function forward in /opt/x.py:12\n' > "$STUB/answers/comfy_bench_log.3"
  assert_exit 0 "compile with a recompile in run 3" -- cb zimage 1 base compile
  assert_eq "run 3: load 0, recompile 1" "$(sed -n 3p "$(rec compile-1 flags.txt)")" "flags.txt"
  assert_contains "$(cat "$(rec compile-1 evidence.txt)")" "node=TorchCompileModel: present" "the node is the evidence"
  assert_contains "$(cat "$(rec compile-1 evidence.txt)")" "cache=inductor: present (3 files)" "and the inductor cache"
  assert_not_contains "$(cat "$(rec compile-1 evidence.txt)")" "Recompiling" "the recompile line is not among the evidence"
  newout cb2
  printf 'inductor 0\n' > "$STUB/answers/comfy_bench_cache"
  assert_exit 7 "the cold run wrote no inductor cache, although the recompile line is there" -- cb zimage 1 base compile
  assert_eq "EVIDENCE: activation cache=inductor: missing (runs/cold.json: 0 files)" "$(sed -n 1p "$(reject_of compile-1)/reason")" "rejected"
  newout cb3
  rm -f "$STUB/answers/comfy_bench_cache" "$STUB/answers/comfy_bench_log.3"
  printf 'UNETLoader\nKSampler\nVAEDecode\n' > "$STUB/answers/comfy_bench_nodes.2"
  assert_exit 7 "a measured run whose node list lacks the compile node" -- cb zimage 1 base compile
  assert_eq "EVIDENCE: activation node=TorchCompileModel: missing (runs/2.json)" "$(grep -m1 'node=' "$(reject_of compile-1)/reason")" "rejected naming the run"
}

t_odd_rounds_run_the_arms_as_given_and_even_rounds_reversed() {
  bench_setup "$FUNCNAME"
  assert_exit 0 "two rounds of base and fp16acc" -- cb zimage 2 base fp16acc
  assert_eq "base-1 fp16acc-1 fp16acc-2 base-2" "$(bench_names | sed 's/r9700tune-comfy-//' | tr '\n' ' ' | sed 's/ $//')" "the order of the containers"
  assert_exit 0 "a third round on top" -- cb zimage 3 base fp16acc
  assert_eq "base-1 fp16acc-1 fp16acc-2 base-2 base-3 fp16acc-3" "$(bench_names | sed 's/r9700tune-comfy-//' | tr '\n' ' ' | sed 's/ $//')" "round 3 runs base-3 and fp16acc-3 only, in the given order"
}

t_a_part_a_killed_worker_left_is_moved_to_rejected_as_interrupted_at_the_next_start() {
  bench_setup "$FUNCNAME"
  local id=20261108T000000Z-1
  bench_fp zimage 1 base > /dev/null 2>&1
  mkdir -p "$OUTD/rounds/base-1.part-$id" "$R9700_RESULTS_DIR/runs/$id" "$BWORK/cb/base-1"
  printf 'RUN_ID=%s\n' "$id" > "$OUTD/rounds/base-1.part-$id/record.env"
  printf 'interrupted\n' > "$R9700_RESULTS_DIR/runs/$id/status"
  : > "$BWORK/cb/base-1/junk"
  assert_exit 0 "the worker starts" -- cbp zimage 1 base
  assert_eq "INTERRUPTED: base-1.part-$id was left by run $id (its status: interrupted)" "$(cat "$(reject_of base-1)/reason")" "the reason names the run and its status"
  assert_contains "$(wlog)" "comfy-bench: base-1.part-$id moved to rejected/" "the worker's lines say so"
  assert_exit 0 "and base-1 was then run, not skipped" -- test -d "$(rec base-1 .)"
  assert_missing "$BWORK/cb/base-1/junk" "the exchange folder a kill left is removed at the start"
  newout cb2
  bench_fp zimage 1 base > /dev/null 2>&1
  mkdir -p "$OUTD/rounds/base-1.part-20200101T000000Z-9"
  assert_exit 0 "a part whose run has no status file" -- cbp zimage 1 base
  assert_contains "$(cat "$(reject_of base-1)/reason")" "(its status: not found)" "says so"
}

t_a_recorded_arm_round_ends_with_a_clean_stop_and_a_server_that_ignores_it_is_stopped_hard() {
  bench_setup "$FUNCNAME"
  assert_exit 0 "an arm-round" -- cb zimage 1 base
  assert_eq "clean" "$(env_val "$(rec base-1 record.env)" STOP)" "STOP=clean"
  assert_eq "0" "$(stops | grep -c '^r9700tune-comfy-base-1$')" "no stop call for the container: the clean stop ended it"
  local e r
  e="$(call_line ' wslc exec r9700tune-comfy-base-1 python3 -c .*SIGINT')"
  r="$(call_line ' wslc run --rm --name r9700tune-comfy-report-')"
  assert_exit 0 "the clean-stop exec, then a list, then the report's run (call order)" -- test -n "$e" -a -n "$r" -a "$(awk -v e="$e" -v r="$r" 'NR > e && NR < r && $3 == "wslc" && $4 == "list" { n++ } END { print n + 0 }' "$STUB/calls.log")" -ge 1
  assert_exit 0 "the last log was saved before the clean stop" -- test "$(last_call_line ' wslc logs r9700tune-comfy-base-1')" -lt "$e"
  newout cb2
  printf 'ignore\n' > "$STUB/answers/comfy_clean_stop"
  assert_exit 0 "a server that ignores the interrupt" -- cb zimage 1 base
  assert_eq "forced" "$(env_val "$(rec base-1 record.env)" STOP)" "STOP=forced: the record is still final for base"
  assert_eq "1" "$(stops | grep -c '^r9700tune-comfy-base-1$')" "the hard stop came"
  newout cb3
  knobs MAX_FAILED_TRIES=1
  assert_exit 7 "tunableop whose container ignored the interrupt" -- cb zimage 1 base tunableop
  assert_eq "EVIDENCE: activation tunable=tunableop_results.csv: missing (the stop was forced: the file is written at the server's exit)" "$(sed -n 1p "$(reject_of tunableop-1)/reason")" "its file was never written"
  newout cb4
  rm -f "$STUB/answers/comfy_clean_stop"
  printf 'Validator,PT_VERSION,2.13\nValidator,ROCM_VERSION,7.1\nGemmTunableOp_float_NN,nn_1024_1024_1024,Gemm_Hipblaslt_1,0.1\n' > "$STUB/answers/comfy_tunableop"
  assert_exit 0 "tunableop with a file and a clean stop" -- cb zimage 1 base tunableop
  assert_eq "$(cat "$STUB/answers/comfy_tunableop")" "$(cat "$(rec tunableop-1 tunableop_results0.csv)")" "the record holds the file as the report printed it, under the name TunableOp gave it (the device number before the extension)"
  assert_contains "$(cat "$(rec tunableop-1 evidence.txt)")" "tunable=tunableop_results.csv: present (1 row)" "evidence.txt counts the result row"
  newout cb5
  printf 'tunableop_results1.csv\n' > "$STUB/answers/comfy_tunableop_name"
  assert_exit 0 "TunableOp wrote the file of device 1" -- cb zimage 1 base tunableop
  assert_exit 0 "the record keeps it under that name and the evidence reads it (never the exact name tunableop_results.csv)" -- test -s "$(rec tunableop-1 tunableop_results1.csv)"
  assert_contains "$(cat "$(rec tunableop-1 evidence.txt)")" "tunable=tunableop_results.csv: present (1 row)" "the check names the stem"
  kill_recorded_pids "$CASE"
}

run_all_tests
