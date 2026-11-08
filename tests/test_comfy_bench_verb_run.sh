#!/usr/bin/env bash
# The verb `bin/r9700 comfy bench` (E2.S3), part 2: arm-rounds end to end through the verb under the supervisor, in the stub world of tests/lib/benchverbcase.sh. CV5 (one arm-round: one stop, one restore,
# one record), CV6 and CV7 (two arms, two rounds, the order alternates; the same command again does nothing and stops nothing), CV8 (another experiment is refused before anything is stopped), CV9 (more
# rounds and a new arm are extensions that run only what is new), CV11 (an arm-round rejected on every try ends at MAX_FAILED_TRIES with the server restored once). The grammar, the refusals, the dry
# run and the folder name are tests/test_comfy_bench_verb.sh; a signal and a lost run tests/test_comfy_bench_verb_signal.sh; the worker itself is E2.S2's. Every test body is a function t_<guarantee>;
# each runs in its own subshell and writes only below $R9700_TEST_ROOT.
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

# prefixed_listed: how many prefixed containers the engine lists now
prefixed_listed() { wslc list | tr -d '\r' | awk 'NR > 1 { print $NF }' | grep -c '^r9700tune-'; }

# sequence: C for a clear container and B for a bench container, in call order
sequence() { awk '$3 == "wslc" && $4 == "run" { if ($0 ~ / --name r9700tune-comfy-clear-/) printf "C"; else if ($5 == "-d" && $0 !~ / --name vllm /) printf "B" }' "$STUB/calls.log"; }

# CV5
t_one_arm_round_end_to_end_is_one_stop_one_restore_and_one_record() {
  bv_setup "$FUNCNAME"
  local word
  assert_exit 0 "bench zimage base --rounds 1" -- bv zimage base --rounds 1
  assert_contains "$OUT" "comfy: bench: outdir $OUTD" "stdout names the folder"
  assert_contains "$OUT" "comfy: bench: 1 of 1 arm-rounds recorded; read them with bin/r9700 verdict $OUTD" "and the summary"
  assert_eq "1" "$(bv_stops vllm)" "exactly one stop of the server"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one start of the server"
  assert_exit 0 "the start came after the stop (call order)" -- call_order ' wslc stop vllm$' ' pwsh.exe .* -Detach$'
  assert_exit 0 "the server is listed at the end" -- alive vllm
  assert_missing "$MARKER_FILE" "no marker"
  assert_exit 0 "the lock is free" -- lock_free
  assert_eq "0" "$(prefixed_listed)" "no prefixed container is listed at the end"
  assert_eq "comfy" "$(python3 "$REPO/lib/fingerprint.py" show "$OUTD/fingerprint.json" kind)" "fingerprint.json is a comfy identity (kind comfy)"
  assert_exit 0 "rounds/base-1/bench.txt is one complete block" -- python3 "$REPO/lib/verdict.py" comfy-check-block --tag base-1 --workflow zimage --metrics "$(comfy_bench_metrics)" "$OUTD/rounds/base-1/bench.txt"
  argv_of_bench base-1
  assert_exit 0 "the bench container has the tmpfs with exec" -- has_pair --tmpfs /data:exec,size=8g
  assert_exit 0 "and the models volume read-only" -- has_pair -v comfy-models:/models:ro
  for word in comfy-data comfy-cache:/cache; do
    assert_exit 1 "never the operator's volume $word" -- has_word "$word"
  done
  assert_eq "" "$(ls "$OUTD/rejected" 2> /dev/null)" "nothing was rejected"
  assert_exit 0 "the placed bench.py is the repository's file (hash)" -- cmp "$REPO/comfyui/bench.py" "$R9700_WORK_DIR/r9700/comfyui/bench.py"
  kill_recorded_pids "$CASE"
}

# CV6, CV7
t_two_arms_in_two_rounds_are_one_stop_one_restore_alternate_and_the_same_command_again_does_nothing() {
  bv_setup "$FUNCNAME"
  assert_exit 0 "bench zimage base fp16acc --rounds 2" -- bv zimage base fp16acc --rounds 2
  assert_eq "1" "$(bv_stops vllm)" "one stop of the server"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one start of the server"
  assert_eq "4" "$(ls "$OUTD/rounds" | wc -l | tr -d ' ')" "four records"
  assert_eq "base-1 fp16acc-1 fp16acc-2 base-2" "$(bench_names | sed 's/r9700tune-comfy-//' | tr '\n' ' ' | sed 's/ $//')" "the containers, in log order: round 1 as given, round 2 reversed"
  assert_eq "CBCBCBCB" "$(sequence)" "four clear containers, one before each bench container"
  assert_contains "$OUT" "comfy: bench: 4 of 4 arm-rounds recorded; read them with bin/r9700 verdict $OUTD" "the summary counts the four"
  rm -f "$STUB/calls.log" "$STUB/calls.argv"
  assert_exit 0 "the same command again" -- bv zimage base fp16acc --rounds 2
  assert_contains "$OUT" "comfy: bench: 4 of 4 arm-rounds recorded, nothing to do" "CV7: nothing to do"
  assert_eq "0" "$(bv_stops vllm)" "no stop"
  assert_eq "" "$(bench_names)" "no bench container was started"
  assert_eq "0" "$(bv_clears)" "no clear container was run"
  assert_eq "0" "$(log_count pwsh.exe -Detach)" "no restore: nothing was stopped"
  kill_recorded_pids "$CASE"
}

# CV8
t_another_experiment_is_refused_before_anything_is_stopped_and_the_identity_is_left_as_it_was() {
  bv_setup "$FUNCNAME"
  local arms="$CASE/arms.conf" before
  assert_exit 0 "one arm-round recorded" -- bv zimage base --rounds 1
  before="$(sha256sum "$OUTD/fingerprint.json" | cut -c1-64)"
  sed 's/^base .*/base | --preview-method none | |/' "$REPO/comfyui/arms.conf" > "$arms"
  assert_exit 0 "the arm table copy has teeth: its base row has one more argument" -- grep -q '^base | --preview-method none | |$' "$arms"
  rm -f "$STUB/calls.log" "$STUB/calls.argv"
  R9700_COMFY_ARMS_CONF="$arms" assert_exit 2 "the same command with another base row" -- bv zimage base --rounds 1
  assert_contains "$ERR" "fingerprint differs: arms.base.args: [] -> [\"--preview-method\",\"none\"]" "the line names what differs"
  assert_eq "0" "$(bv_stops vllm)" "no stop"
  assert_eq "" "$(bench_names)" "no container"
  assert_eq "1" "$(ls "$OUTD/rounds" | wc -l | tr -d ' ')" "no new record"
  assert_eq "$before" "$(sha256sum "$OUTD/fingerprint.json" | cut -c1-64)" "the stored fingerprint.json is byte for byte what it was"
  assert_exit 0 "the lock is free" -- lock_free
  kill_recorded_pids "$CASE"
}

# CV9
t_more_rounds_and_a_new_arm_are_extensions_that_run_only_what_is_new() {
  bv_setup "$FUNCNAME"
  assert_exit 0 "one arm-round recorded" -- bv zimage base --rounds 1
  rm -f "$STUB/calls.log" "$STUB/calls.argv"
  assert_exit 0 "two rounds of base" -- bv zimage base --rounds 2
  assert_eq "r9700tune-comfy-base-2" "$(bench_names)" "only base-2 ran: one bench container"
  assert_eq "1" "$(bv_stops vllm)" "one stop"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
  assert_contains "$OUT" "fingerprint: rounds extended 1 -> 2" "the extension is said"
  rm -f "$STUB/calls.log" "$STUB/calls.argv"
  assert_exit 0 "a new arm" -- bv zimage base fp16acc --rounds 2
  assert_contains "$OUT" "fingerprint: arm fp16acc added" "the new arm is said"
  assert_eq "r9700tune-comfy-fp16acc-1 r9700tune-comfy-fp16acc-2" "$(bench_names | tr '\n' ' ' | sed 's/ $//')" "only fp16acc-1 and fp16acc-2 ran"
  assert_eq "1" "$(bv_stops vllm)" "one stop"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
  assert_eq "4" "$(ls "$OUTD/rounds" | wc -l | tr -d ' ')" "four records in all"
  kill_recorded_pids "$CASE"
}

# CV11
t_an_arm_round_rejected_on_every_try_ends_at_max_failed_tries_with_the_server_restored_once() {
  bv_setup "$FUNCNAME"
  local dir
  knobs MAX_FAILED_TRIES=3
  printf 'error\n' > "$STUB/answers/comfy_bench_mode.cold"
  assert_exit 7 "an execution error on every run" -- bv zimage base --rounds 1
  assert_contains "$ERR" "step failed 3 times" "the supervisor says it failed three times"
  assert_eq "3" "$(ls "$OUTD/rejected" | grep -c '^base-1-')" "three rejected attempts"
  for dir in "$OUTD"/rejected/base-1-*; do
    assert_contains "$(cat "$dir/reason")" "EXECUTION_ERROR" "[$dir] each with its reason"
  done
  assert_missing "$OUTD/rounds/base-1" "no record"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one start of the server at the end"
  assert_eq "1" "$(bv_stops vllm)" "and one stop"
  assert_eq "0" "$(prefixed_listed)" "no prefixed container is listed"
  kill_recorded_pids "$CASE"
  bv_setup "$FUNCNAME-b"
  knobs MAX_FAILED_TRIES=2
  printf 'cold_timeout\n' > "$STUB/answers/comfy_bench_mode.cold"
  assert_exit 7 "a cold run past its ceiling" -- bv zimage base --rounds 1
  for dir in "$OUTD"/rejected/base-1-*; do
    assert_contains "$(cat "$dir/reason")" "COLD_TIMEOUT" "[$dir] the reason says COLD_TIMEOUT"
  done
  assert_eq "2" "$(ls "$OUTD/rejected" | grep -c '^base-1-')" "two attempts"
  assert_eq "0" "$(prefixed_listed)" "no bench container is listed at the end: every ceiling ended its container"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the server was restored once"
  kill_recorded_pids "$CASE"
}

run_all_tests
