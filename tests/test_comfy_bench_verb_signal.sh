#!/usr/bin/env bash
# The verb `bin/r9700 comfy bench` (E2.S3), part 3: a signal during the bench (CV13) and a lost run continued by the same command (CV14), in the stub world of tests/lib/benchverbcase.sh. The grammar, the
# refusals, the dry run and the folder name are tests/test_comfy_bench_verb.sh; the arm-rounds end to end tests/test_comfy_bench_verb_run.sh; the worker's own signal cases (BW6, BW14) are E2.S2's. Every
# test body is a function t_<guarantee>; each runs in its own subshell and writes only below $R9700_TEST_ROOT. Waits are bounded polls on a call-log line or a file, never a fixed sleep.
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

# CV13
t_a_signal_during_the_bench_ends_it_cleanly() {
  bv_setup "$FUNCNAME"
  printf 'slow 30\n' > "$STUB/answers/comfy_bench_mode.1"
  bv_bg zimage base --rounds 1
  wait_call ' wslc exec r9700tune-comfy-base-1 .*--run 1 ' 300
  kill -TERM "$SUP"
  bv_end 60
  assert_eq "143" "$SRC" "the verb ends 143"
  assert_exit 1 "the bench container is not listed" -- listed r9700tune-comfy-base-1
  assert_exit 0 "the container was stopped by the cleanup" -- test "$(bv_stops r9700tune-comfy-base-1)" -ge 1
  assert_exit 0 "the server is listed again" -- alive vllm
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one start of the server"
  assert_missing "$MARKER_FILE" "no marker"
  assert_exit 0 "the lock is free" -- lock_free
  assert_missing "$OUTD/rounds/base-1" "rounds/ holds no final base-1"
  unhang_all
  kill_recorded_pids "$CASE"
}

# CV14
t_a_lost_run_is_continued_by_the_same_command_from_the_first_missing_arm_round() {
  bv_setup "$FUNCNAME"
  local before_base before_fp
  printf 'slow 6\n' > "$STUB/answers/comfy_bench_mode.fp16acc.cold"
  bv_bg zimage base fp16acc --rounds 2
  wait_call ' wslc exec r9700tune-comfy-fp16acc-2 .*--run cold ' 400
  assert_exit 0 "base-1 is final when the host is lost" -- test -d "$OUTD/rounds/base-1"
  assert_exit 0 "and fp16acc-1" -- test -d "$OUTD/rounds/fp16acc-1"
  kill -KILL "$SUP"
  wait "$SUP" 2> /dev/null
  assert_exit 0 "no cleanup ran: the marker is left" -- test -f "$MARKER_FILE"
  assert_exit 0 "and the third arm-round has no record" -- test ! -d "$OUTD/rounds/fp16acc-2"
  rm -f "$STUB/answers/comfy_bench_mode.fp16acc.cold"
  before_base="$(tree_hash "$OUTD/rounds/base-1")"
  before_fp="$(tree_hash "$OUTD/rounds/fp16acc-1")"
  rm -f "$STUB/calls.log" "$STUB/calls.argv"
  assert_exit 0 "the same command again" -- bv zimage base fp16acc --rounds 2
  assert_exit 0 "the restore from the marker ran first (before the first bench container)" -- call_order ' pwsh.exe .* -Detach$' ' wslc run -d --rm --name r9700tune-comfy-fp16acc-2 '
  assert_eq "2" "$(log_count pwsh.exe -Detach)" "two starts of the server: the restore of the lost run, and the end of this one"
  assert_eq "fp16acc-2 base-2" "$(bench_names | sed 's/r9700tune-comfy-//' | tr '\n' ' ' | sed 's/ $//')" "the containers of the second command: fp16acc-2, then base-2 (round 2 reversed)"
  assert_eq "4" "$(ls "$OUTD/rounds" | wc -l | tr -d ' ')" "four records"
  assert_eq "$before_base" "$(tree_hash "$OUTD/rounds/base-1")" "base-1 is byte for byte what it was"
  assert_eq "$before_fp" "$(tree_hash "$OUTD/rounds/fp16acc-1")" "so is fp16acc-1"
  assert_contains "$(cat "$(reject_of fp16acc-2)/reason")" "INTERRUPTED: fp16acc-2.part-" "the record names the lost arm-round and its cause"
  assert_missing "$MARKER_FILE" "no marker"
  assert_exit 0 "the server is listed" -- alive vllm
  assert_exit 0 "the same command with the arms in another order is the same experiment" -- bv zimage fp16acc base --rounds 2
  assert_contains "$OUT" "comfy: bench: 4 of 4 arm-rounds recorded, nothing to do" "and there is nothing to do"
  unhang_all
  kill_recorded_pids "$CASE"
}

run_all_tests
