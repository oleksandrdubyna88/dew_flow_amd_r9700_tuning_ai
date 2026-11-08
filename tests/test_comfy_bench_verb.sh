#!/usr/bin/env bash
# The verb `bin/r9700 comfy bench <workflow> <arm>... [--rounds N] [--out <name>] [--dry-run]` (E2.S3), part 1: the argument grammar before the lock (CV1), the prepare after the restore and before any
# stop (CV2), the owner check and the lock (CV3, CV4), the dry run (CV10) and the folder name (CV12), and CV15 (the arm `base` must be one of the arms: a grammar check). One arm-round end to end, the extensions and the
# refusals of another experiment are tests/test_comfy_bench_verb_run.sh (CV5-CV9, CV11); a signal and a lost run are tests/test_comfy_bench_verb_signal.sh (CV13, CV14); the verdict over a bench folder
# is tests/test_comfy_bench_verdict.sh (VD1-VD6). The worker itself is E2.S2's (tests/test_comfy_bench*.sh). The stub world is tests/lib/benchverbcase.sh. Every test body is a function
# t_<guarantee>; each runs in its own subshell and writes only below $R9700_TEST_ROOT. Waits are bounded polls on a call-log line or a file, never a fixed sleep.
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

WORKER="$STUBS/worker.sh"
USAGE_LINE="usage: bench <workflow> <arm>... [--rounds <1..20>] [--out <name>] [--dry-run]"

# CV1
t_the_grammar_is_refused_before_the_lock_and_the_workflows_are_derived() {
  bv_setup "$FUNCNAME"
  local legal arg
  legal="$(comfy_bench_workflows | tr '\n' ' ' | sed 's/ $//')"
  assert_contains " $legal " " zimage " "the legal workflows are read from the program: zimage"
  assert_contains " $legal " " wan5b " "and wan5b"
  assert_exit 2 "bench with no word" -- bv
  assert_contains "$ERR" "r9700: comfy: bench: $USAGE_LINE" "the usage line"
  assert_contains "$ERR" "the arm base must be one of the arms" "which says that base is always one of the arms"
  assert_eq "1" "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "one line"
  assert_exit 0 "nothing happened" -- bv_untouched
  bv_refuse "an unknown workflow" "r9700: comfy: bench: unknown workflow \"nosuch\"; legal: $legal" nosuch base
  bv_refuse "no arm" "r9700: comfy: bench: at least one arm is needed" zimage
  bv_refuse "a capital letter" "r9700: comfy: bench: \"Base\" is not an arm name (lower-case letters and digits only)" zimage Base
  bv_refuse "an arm with a dash" "\"fp-16\" is not an arm name" zimage base fp-16
  bv_refuse "an arm given twice" "r9700: comfy: bench: the arm \"base\" is given twice" zimage base base
  for arg in 0 21 x -1 ""; do
    bv_refuse "--rounds \"$arg\"" "r9700: comfy: bench: --rounds \"$arg\" is not a whole number from 1 to 20" zimage base --rounds "$arg"
  done
  bv_refuse "--rounds with no value" "r9700: comfy: bench: --rounds needs a value" zimage base --rounds
  bv_refuse "--out with a dot-dot" "r9700: comfy: bench: --out \"../x\" is not a name" zimage base --out ../x
  bv_refuse "--out with no value" "r9700: comfy: bench: --out needs a value" zimage base --out
  bv_refuse "an unknown option" "r9700: comfy: bench: unknown option \"--frob\"; legal: --rounds <1..20>, --out <name>, --dry-run" zimage base --frob
  bv_refuse "an unknown option first" "unknown option \"--frob\"" --frob
  assert_exit 0 "the legal rounds are 1 to 20: 20 is not refused by the grammar (a dry run stops nothing)" -- bv zimage base --rounds 20 --dry-run
  kill_recorded_pids "$CASE"
}

# CV2
t_the_prepare_refuses_after_the_restore_and_before_any_stop_and_needs_no_model_file() {
  bv_setup "$FUNCNAME"
  local ev="$CASE/arm_evidence.conf" n0
  assert_exit 2 "an arm that is not in the table" -- bv zimage base nosuch
  assert_contains "$ERR" "config: arm \"nosuch\" is not in " "the arm line of the table"
  assert_contains "$ERR" "legal: base fp16acc fp8wmm tunableop miopen compile" "naming the legal arms"
  assert_eq "0" "$(stop_lines)" "no stop"
  assert_exit 0 "no run folder" -- bv_no_runs
  assert_exit 0 "the lock is free afterwards" -- lock_free
  assert_missing "$OUTD/fingerprint.json" "no identity was written"
  grep -v '^fp16acc ' "$REPO/comfyui/arm_evidence.conf" > "$ev"
  assert_exit 0 "the evidence copy has teeth: it lost one row" -- test "$(grep -c '^fp16acc ' "$ev")" -eq 0
  R9700_COMFY_EVIDENCE_CONF="$ev" assert_exit 2 "an evidence table without the fp16acc row" -- bv zimage base fp16acc
  assert_contains "$ERR" "arm \"fp16acc\" has no row in arm_evidence.conf" "names the arm and the table"
  assert_eq "0" "$(stop_lines)" "no stop"
  assert_exit 0 "no run folder" -- bv_no_runs
  assert_exit 0 "the lock is free afterwards" -- lock_free
  assert_exit 1 "two model files are in models/ and no --model is given: the verb needs none (the machine config alone)" -- test "$(ls "$REPO"/models/*.env | wc -l | tr -d ' ')" -lt 2
  wslc stop vllm > /dev/null
  n0="$(stop_lines)"
  write_marker
  assert_exit 2 "with a recovery marker left" -- bv zimage base nosuch
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the restore ran first: one start of the server"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_contains "$ERR" "config: arm \"nosuch\" is not in " "and then the same refusal"
  assert_eq "$n0" "$(stop_lines)" "no stop but the test's own"
  kill_recorded_pids "$CASE"
  bv_setup "$FUNCNAME-b"
  knobs COMFY_CONTAINER=r9700tune-comfy
  assert_exit 2 "a machine file whose COMFY_CONTAINER starts with the prefix" -- bv zimage base
  assert_contains "$ERR" "COMFY_CONTAINER: \"r9700tune-comfy\" starts with the container prefix \"r9700tune-\"" "E1's name-rule line"
  assert_eq "0" "$(stop_lines)" "no stop"
  assert_exit 0 "no run folder" -- bv_no_runs
  kill_recorded_pids "$CASE"
}

# CV3
t_a_listed_comfyui_refuses_the_bench_with_the_one_owner_line_before_anything_is_stopped() {
  bv_setup "$FUNCNAME"
  comfy_listed
  assert_exit 2 "bench beside a listed ComfyUI" -- bv zimage base
  assert_eq "$(comfy_owner_line)" "$ERR" "exactly the owner line, one stderr line"
  assert_contains "$ERR" "bin/r9700 comfy stop" "which names the remedy"
  assert_eq "0" "$(stop_lines)" "no stop"
  assert_exit 0 "no run folder" -- bv_no_runs
  assert_missing "$OUTD/fingerprint.json" "no identity was written"
  assert_exit 0 "comfyui is still listed" -- alive comfyui
  assert_exit 0 "and so is the server" -- alive vllm
  assert_exit 0 "the lock is free afterwards" -- lock_free
  kill_recorded_pids "$CASE"
  bv_setup "$FUNCNAME-b"
  comfy_listed comfyuix
  assert_exit 0 "a container named comfyuix is not the operator's ComfyUI (a whole name): the run goes on" -- bv zimage base --dry-run
  assert_contains "$OUT" "dry-run: " "to the dry run"
  assert_eq "0" "$(stop_lines)" "no stop"
  kill_recorded_pids "$CASE"
}

# CV4
t_a_held_lock_comes_first_and_a_bench_holds_it_through_its_run() {
  bv_setup "$FUNCNAME"
  local holder calls
  step_bg --model "$MODEL_35B" t -- "$WORKER" child
  wait_for "$STUB/child.pid" 100
  holder="$SUP"
  calls="$(wslc_calls)"
  assert_exit 4 "bench under a held lock" -- bv zimage base
  assert_contains "$ERR" "pid $holder, step, since" "the holder line"
  assert_eq "$calls" "$(wslc_calls)" "no engine call (the held step's guards read the PC through pwsh, not the engine)"
  comfy_listed
  calls="$(wslc_calls)"
  assert_exit 4 "the same with ComfyUI ALSO listed: still the lock first" -- bv zimage base
  assert_contains "$ERR" "pid $holder, step, since" "the holder line"
  assert_not_contains "$ERR" "holds the card" "and no owner line (the owner check is after the lock)"
  assert_eq "$calls" "$(wslc_calls)" "no engine call"
  kill -TERM "$holder"
  SUP="$holder"
  step_end
  kill_recorded_pids "$CASE"
  bv_setup "$FUNCNAME-b"
  printf 'slow 3\n' > "$STUB/answers/comfy_bench_mode.1"
  bv_bg zimage base --rounds 1
  wait_call ' wslc exec r9700tune-comfy-base-1 .*--run 1 ' 300
  assert_exit 4 "a step while a bench runs" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  assert_contains "$ERR" "pid $SUP, comfy, since" "the holder line names comfy"
  bv_end 120
  assert_eq "0" "$SRC" "the bench itself ends 0"
  kill_recorded_pids "$CASE"
}

# CV10
t_the_dry_run_prints_and_changes_nothing_but_restores_first() {
  bv_setup "$FUNCNAME"
  local n0 line runs
  assert_exit 0 "bench --dry-run" -- bv zimage base fp16acc --dry-run
  assert_contains "$OUT" "comfy: bench: outdir $OUTD" "the first line names the folder"
  assert_contains "$OUT" "dry-run: " "dry-run lines"
  assert_eq "0" "$(grep -vc '^dry-run: \|^comfy: bench: ' <<< "$OUT" | tr -d ' ')" "and nothing else but the verb's own lines"
  assert_contains "$OUT" "--rm --name r9700tune-comfy-clear-1 " "the clear container"
  assert_contains "$OUT" "--tmpfs /data:exec,size=8g" "the bench container's run with its tmpfs word"
  assert_contains "$OUT" "-v comfy-models:/models:ro" "and the read-only models volume"
  assert_contains "$OUT" "exec r9700tune-comfy-base-1 env " "the exec of bench.py"
  assert_contains "$OUT" "bench.py run zimage --tag base-1 --run cold" "of the cold run"
  assert_eq "0" "$(stop_lines)" "no stop"
  assert_eq "" "$(bench_names)" "no bench container was started"
  assert_eq "0" "$(bv_clears)" "no clear container was run"
  runs="$(awk '$3 == "wslc" && $4 == "run" && $0 !~ / --name vllm( |$)/' "$STUB/calls.log")"
  assert_eq "1" "$(grep -c . <<< "$runs")" "exactly ONE run call besides the test's own: nothing else started a container"
  assert_contains "$runs" " --name r9700tune-comfy-fp-" "it is the read-only listing container of the identity (as the series' dry run has)"
  assert_contains "$runs" "-v comfy-models:/models:ro" "with the models volume read-only"
  assert_not_contains "$runs" "--gpus" "and without the card"
  assert_missing "$OUTD/fingerprint.json" "no identity"
  assert_missing "$OUTD/rounds" "no rounds folder"
  assert_exit 0 "the placed bench.py exists (the placement comes before the dry run)" -- test -s "$R9700_WORK_DIR/r9700/comfyui/bench.py"
  assert_eq "0" "$(log_count pwsh.exe -Detach)" "the server was not restarted: it was never stopped"
  assert_exit 0 "the lock is free afterwards" -- lock_free
  wslc stop vllm > /dev/null
  n0="$(stop_lines)"
  write_marker
  assert_exit 0 "a dry run with a marker left" -- bv zimage base --dry-run
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "takes the lock and restores first: one start of the server"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_contains "$OUT" "dry-run: " "then the dry run"
  assert_eq "$n0" "$(stop_lines)" "no stop but the test's own"
  line="$(grep -c '^dry-run: ' <<< "$OUT")"
  assert_exit 0 "the dry run printed its lines" -- test "$line" -ge 4
  kill_recorded_pids "$CASE"
}

# CV12
t_the_folder_is_named_for_the_workflow_unless_out_says_otherwise() {
  bv_setup "$FUNCNAME"
  assert_exit 0 "no --out" -- bv zimage base --dry-run
  assert_contains "$OUT" "comfy: bench: outdir $R9700_RESULTS_DIR/comfy-zimage" "comfy-zimage"
  assert_exit 0 "--out zt1" -- bv zimage base --out zt1 --dry-run
  assert_contains "$OUT" "comfy: bench: outdir $R9700_RESULTS_DIR/zt1" "RESULTS_DIR/zt1"
  assert_exit 0 "wan5b" -- bv wan5b base --dry-run
  assert_contains "$OUT" "comfy: bench: outdir $R9700_RESULTS_DIR/comfy-wan5b" "comfy-wan5b"
  assert_contains "$OUT" "bench.py run wan5b --tag base-1 --run cold" "and the wan5b workflow in the exec"
  kill_recorded_pids "$CASE"
}

# CV15
t_the_arm_base_must_be_one_of_the_arms_is_a_grammar_check_before_the_lock() {
  bv_setup "$FUNCNAME"
  bv_refuse "an invocation without base" "r9700: comfy: bench: the arm base must be one of the arms" zimage fp16acc
  bv_refuse "the same with --dry-run" "r9700: comfy: bench: the arm base must be one of the arms" zimage fp16acc --dry-run
  assert_missing "$OUTD" "no results folder was left behind"
  assert_exit 0 "no run folder" -- bv_no_runs
  assert_exit 0 "base in the second place is a legal command line (a dry run changes nothing)" -- bv zimage fp16acc base --dry-run
  kill_recorded_pids "$CASE"
}

run_all_tests
