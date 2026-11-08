#!/usr/bin/env bash
# The arm-round of a ComfyUI arm (E2.S2), part 3: a lost arm-round and what continues it: BW6 (a guard stop, a TERM), BW14 (the resume), BW15 (the identity re-checked before every arm-round), BW16 (the gate: disk, quiet, fit), BW17 (the drift pairing), BW18 (never the operator's containers). The stub world and the way the worker is run are described in tests/test_comfy_bench.sh.
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



t_a_guard_stop_ends_the_container_and_the_next_start_sweeps_the_part_as_interrupted() {
  bench_setup "$FUNCNAME"
  knobs MAX_FAILED_TRIES=1
  printf '8000\n' > "$STUB/answers/ram"
  printf 'slow 30\n' > "$STUB/answers/comfy_bench_mode.1"
  cb_bg zimage 1 base
  wait_call ' wslc exec r9700tune-comfy-base-1 .*--run 1 ' 200
  append_answer ram 100
  step_end
  assert_eq "7" "$SRC" "the RAM guard stopped the step: a failed try"
  assert_exit 1 "no container is alive at the supervisor's exit" -- listed r9700tune-comfy-base-1
  assert_eq "1" "$(ls "$OUTD/rounds" | grep -c '\.part-')" "the killed worker left its part"
  assert_missing "$OUTD/rounds/base-1" "and no record"
  unhang_all
  rm -f "$STUB/answers/comfy_bench_mode.1"
  printf '8000\n' > "$STUB/answers/ram"
  rm -f "$STUB/counters/answer-ram"
  assert_exit 0 "the same command again" -- cbp zimage 1 base
  assert_contains "$(wlog)" "comfy-bench: base-1.part-" "the sweep says what it moved"
  assert_contains "$(cat "$(reject_of base-1)/reason")" "INTERRUPTED: base-1.part-" "as INTERRUPTED"
  assert_exit 0 "and base-1 was then run" -- test -d "$(rec base-1 .)"
}

t_a_term_to_the_supervisor_during_a_run_stops_the_container_and_restores_the_server() {
  bench_setup "$FUNCNAME"
  printf 'slow 30\n' > "$STUB/answers/comfy_bench_mode.1"
  cb_bg zimage 1 base
  wait_call ' wslc exec r9700tune-comfy-base-1 .*--run 1 ' 200
  kill -TERM "$SUP"
  step_end
  assert_eq "143" "$SRC" "exit 143"
  assert_exit 1 "the container was stopped by the cleanup" -- listed r9700tune-comfy-base-1
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "restored once"
  unhang_all
}

t_after_a_lost_arm_round_the_same_command_continues_from_the_first_missing_one() {
  bench_setup "$FUNCNAME"
  local before_base before_fp
  printf 'slow 4\n' > "$STUB/answers/comfy_bench_mode.fp16acc.cold"
  cb_bg zimage 2 base fp16acc
  wait_call ' wslc exec r9700tune-comfy-fp16acc-2 .*--run cold ' 300
  kill -KILL "$SUP"
  wait "$SUP" 2> /dev/null
  assert_eq "2" "$(comfy_bench_left "$OUTD" 2 base fp16acc)" "two arm-rounds have no record"
  assert_eq "2" "$(comfy_bench_recorded "$OUTD" 2 base fp16acc)" "and two have one"
  rm -f "$STUB/answers/comfy_bench_mode.fp16acc.cold"
  before_base="$(tree_hash "$OUTD/rounds/base-1")"
  before_fp="$(tree_hash "$OUTD/rounds/fp16acc-1")"
  assert_exit 0 "the same command again" -- cb zimage 2 base fp16acc
  assert_contains "$(wlog)" "comfy-bench: fp16acc-2.part-" "the sweep names the part it moved"
  assert_eq "fp16acc-2 base-2" "$(bench_names | sed 's/r9700tune-comfy-//' | tail -n 2 | tr '\n' ' ' | sed 's/ $//')" "the containers of the second command: fp16acc-2, then base-2 (round 2 reversed, from the first missing)"
  assert_eq "4" "$(ls "$OUTD/rounds" | wc -l | tr -d ' ')" "four records"
  assert_eq "$before_base" "$(tree_hash "$OUTD/rounds/base-1")" "base-1 is byte for byte what it was"
  assert_eq "$before_fp" "$(tree_hash "$OUTD/rounds/fp16acc-1")" "so is fp16acc-1"
  assert_contains "$(cat "$(reject_of fp16acc-2)/reason")" "INTERRUPTED: fp16acc-2.part-" "the lost arm-round is named in the record, with its cause"
  unhang_all
}

t_the_identity_is_rechecked_before_every_arm_round_and_a_change_refuses_before_the_next_container() {
  bench_setup "$FUNCNAME"
  local arms="$CASE/arms.conf" ev="$CASE/arm_evidence.conf" placed="$R9700_WORK_DIR/r9700/comfyui/bench.py" want
  cp "$REPO/comfyui/arms.conf" "$arms"
  cp "$REPO/comfyui/arm_evidence.conf" "$ev"
  export R9700_COMFY_ARMS_CONF="$arms" R9700_COMFY_EVIDENCE_CONF="$ev"
  local variant n=0
  for variant in arms evidence bench image; do
    n=$((n + 1))
    newout "cb$n"
    cp "$REPO/comfyui/arms.conf" "$arms"
    cp "$REPO/comfyui/arm_evidence.conf" "$ev"
    cp "$REPO/comfyui/bench.py" "$placed"
    rm -f "$STUB/answers/inspect" "$STUB/calls.log" "$STUB/calls.argv"
    case $variant in
      arms) hook_stop r9700tune-comfy-base-1 "sed -i 's/^base .*/base | --fast fp16_accumulation | |/' '$arms'"; want="fingerprint differs: arms.base.args: [] -> [\"--fast\",\"fp16_accumulation\"]" ;;
      evidence) hook_stop r9700tune-comfy-base-1 "sed -i 's/Using pytorch attention/Using  pytorch attention/' '$ev'"; want="fingerprint differs: tools.evidence_conf: " ;;
      bench) hook_stop r9700tune-comfy-base-1 "echo '# touched' >> '$placed'"; want="fingerprint differs: tools.bench_py: " ;;
      image) hook_stop r9700tune-comfy-base-1 "printf '[{\"Id\": \"sha256:other\"}]\n' > '$STUB/answers/inspect'"; want="fingerprint differs: image.id: sha256:stub -> sha256:other" ;;
    esac
    assert_exit 2 "[$variant] the second arm-round is refused" -- cb zimage 2 base
    assert_contains "$(wlog)" "$want" "[$variant] the worker prints the difference"
    outcome_read "$(run_dir_of)/steps/1.outcome"
    assert_eq "refused 2" "$O_KIND $O_RC" "[$variant] the outcome is KIND=refused RC=2"
    assert_contains "$O_DETAIL" "fingerprint differs: " "[$variant] and carries the line"
    assert_eq "r9700tune-comfy-base-1" "$(bench_names)" "[$variant] only the first container was started"
    assert_eq "1" "$(ls "$OUTD/rounds" | wc -l | tr -d ' ')" "[$variant] one record"
    rm -rf "$R9700_RESULTS_DIR/runs"
    rm -f "$STUB/on-stop-r9700tune-comfy-base-1"
  done
}

t_the_gate_before_an_arm_round_stops_on_a_disk_event_waits_for_a_quiet_pc_and_refuses_what_does_not_fit() {
  bench_setup "$FUNCNAME"
  printf '100\n101\n' > "$STUB/answers/disk"
  assert_exit 9 "a new disk record at the first gate" -- cb zimage 1 base
  outcome_read "$(run_dir_of)/steps/1.outcome"
  assert_eq "disk_gate" "$O_KIND" "the worker's outcome is KIND=disk_gate"
  assert_eq "" "$(bench_names)" "no container was started"
  newout cb2
  printf '100\n' > "$STUB/answers/disk"
  rm -f "$STUB/counters/answer-disk" "$STUB/calls.log" "$STUB/calls.argv"
  rm -rf "$R9700_RESULTS_DIR/runs"
  hook_stop r9700tune-comfy-base-1 "printf '9.00 0.40 0.30 1/100 1\n' > '$CASE/loadavg'; setsid bash -c \"sleep 1.5; printf '0.50 0.40 0.30 1/100 1\\n' > '$CASE/loadavg'\" > /dev/null 2>&1 &"
  assert_exit 0 "a PC that gets busy after the first arm-round: the supervisor waits and admits again" -- cb zimage 1 base fp16acc
  assert_contains "$(wlog)" "NOT QUIET: fp16acc round 1 (" "the worker's line"
  assert_exit 0 "and fp16acc-1 is recorded after the wait" -- test -d "$(rec fp16acc-1 .)"
  newout cb3
  rm -rf "$R9700_RESULTS_DIR/runs"
  rm -f "$STUB/on-stop-r9700tune-comfy-base-1" "$STUB/calls.log" "$STUB/calls.argv"
  export R9700_COMFY_ARM_SECONDS=100000
  assert_exit 6 "an arm-round that no longer fits before the deadline" -- cb zimage 1 base fp16acc
  assert_contains "$(wlog)" "comfy-bench: 2 arm-rounds no longer fit before the deadline" "the worker's line"
  assert_eq "" "$(bench_names)" "no container"
  newout cb4
  unset R9700_COMFY_ARM_SECONDS
  rm -rf "$R9700_RESULTS_DIR/runs"
  assert_exit 0 "the default allowance" -- cb zimage 1 base
  assert_contains "$(wlog)" "comfy-bench: fit: 3300 s per arm-round" "is the cold ceiling, three run ceilings and 600 s: 3300 for zimage"
}

t_the_drift_is_paired_with_the_bases_round_1_output_of_the_same_seed() {
  bench_setup "$FUNCNAME"
  # at the start of fp16acc-1 the test lists the references and changes ONE of them: the stub's drift reads the reference folder, so run 2's line must differ
  printf 'ls %s/cb/ref > %s/ref-at-start.txt; echo changed >> %s/cb/ref/zimage_r2_00001_.png\n' "$BWORK" "$CASE" "$BWORK" > "$STUB/on-start-r9700tune-comfy-fp16acc-1"
  assert_exit 0 "two rounds of base and fp16acc" -- cb zimage 2 base fp16acc
  assert_eq "zimage_r1_00001_.png zimage_r2_00001_.png zimage_r3_00001_.png" "$(tr '\n' ' ' < "$CASE/ref-at-start.txt" | sed 's/ $//')" "before fp16acc-1's runs the base's round-1 outputs of runs 1-3 are in ref/"
  assert_eq "drift r=1: mad 0.000 psnr identical|drift r=2: mad 1.000 psnr 48.131|drift r=3: mad 0.000 psnr identical" "$(tr '\n' '|' < "$(rec fp16acc-1 drift.txt)" | sed 's/|$//')" "fp16acc-1's drift is computed against the references of its folder (the one the test changed differs)"
  assert_eq "drift r=1: mad 0.000 psnr identical|drift r=2: mad 0.000 psnr identical|drift r=3: mad 0.000 psnr identical" "$(tr '\n' '|' < "$(rec base-2 drift.txt)" | sed 's/|$//')" "base-2 is paired with base-1's outputs (fresh references: the change of fp16acc-1's folder is gone)"
  assert_eq "drift: unavailable (base-1 is the reference)" "$(cat "$(rec base-1 drift.txt)")" "base-1 is the reference"
  assert_missing "$BWORK/cb/ref" "ref/ is gone after the arm-rounds"
  newout cb2
  assert_exit 0 "fp16acc first in round 1: its reference does not exist yet" -- cb zimage 1 fp16acc base
  assert_eq "drift: unavailable (no base-1 record)" "$(cat "$(rec fp16acc-1 drift.txt)")" "unavailable, never a number against another run"
  newout cb3
  bench_fp zimage 1 fp16acc base > /dev/null 2>&1
  mkdir -p "$OUTD/rejected/base-1-20261108T000000Z"
  assert_exit 0 "with a rejected base-1 attempt only" -- cbp zimage 1 fp16acc base
  assert_eq "drift: unavailable (no base-1 record)" "$(cat "$(rec fp16acc-1 drift.txt)")" "a rejected attempt is not a reference"
}

t_the_worker_never_stops_or_starts_the_operators_containers_and_every_container_is_prefixed() {
  bench_setup "$FUNCNAME"
  stub_container comfyui-fetch
  assert_exit 0 "an arm-round" -- cb zimage 1 base
  local target bad=""
  while read -r target; do
    case $target in vllm | r9700tune-comfy-*) ;; *) bad+="$target " ;; esac
  done < <(stops)
  assert_eq "" "$bad" "every stop names the operator's server (the supervisor's one) or a prefixed bench container"
  assert_eq "1" "$(stops | grep -c '^vllm$')" "and the operator's server was stopped once, by the supervisor before the worker"
  assert_exit 0 "the fetch container of another run is alive" -- listed comfyui-fetch
  assert_eq "" "$(awk '$3 == "wslc" && $4 == "run" { for (i = 5; i <= NF; i++) if ($i == "--name" && $(i + 1) !~ /^r9700tune-/ && $(i + 1) != "vllm" && $(i + 1) != "comfyui-fetch") print $(i + 1) }' "$STUB/calls.log")" "every container the worker made has a prefixed name"
  kill_recorded_pids "$CASE"
}

run_all_tests
