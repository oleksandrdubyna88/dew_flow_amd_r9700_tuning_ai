#!/usr/bin/env bash
# The arm-round of a ComfyUI arm and its measurement contract (E2.S2), part 1: the worker lib/comfy_bench.sh in the stub world, run as ONE step under `bin/r9700 step --model <35B> comfy-bench -- bash lib/comfy_bench.sh <outdir> <workflow> <rounds> <arm>...` (the verb `comfy bench` is E2.S3's; the fingerprint is built first, in the test shell, as the verb will). Scenarios BW1-BW5, BW6 (the adapter's ceiling), BW7, BW8. The rest of BW is tests/test_comfy_bench_records.sh (BW9-BW13, BW19) and tests/test_comfy_bench_resume.sh (BW6 guard and TERM, BW14-BW18); the evidence and the tables (BE, BA) are tests/test_comfy_bench_evidence.sh, the identity (BF) tests/test_comfy_bench_identity.sh: one file of all of them ran past the runner's ten minutes. The Python half of BF is tests/test_fingerprint.py, bench.py itself tests/test_comfy_bench_py.py. Every test body is a function t_<guarantee>; each runs in its own subshell and writes only below $R9700_TEST_ROOT.
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



t_one_arm_round_is_one_fresh_prefixed_container_with_the_isolation_words() {
  bench_setup "$FUNCNAME"
  local out="$BWORK/cb/base-1" word
  assert_exit 0 "one arm-round of base" -- cb zimage 1 base
  assert_eq "r9700tune-comfy-base-1" "$(bench_names)" "exactly one detached container, named for its arm and round"
  argv_of_bench base-1
  assert_exit 0 "--tmpfs is followed by /data:exec,size=8g (the exact word: a plain --tmpfs /data is noexec and the entrypoint could not start)" -- has_pair --tmpfs /data:exec,size=8g
  assert_exit 0 "the models volume is read-only" -- has_pair -v comfy-models:/models:ro
  assert_exit 0 "the bench cache volume of the prefix" -- has_pair -v r9700tune-comfy-cache:/cache
  assert_exit 0 "the card" -- has_pair --gpus all
  assert_exit 0 "the shared memory" -- has_pair --shm-size 8g
  assert_exit 0 "ComfyUI writes its outputs into the exchange folder of the tag" -- has_pair --output-directory "/work/r9700/comfyui/bench/cb/base-1"
  for word in comfy-data comfy-cache:/cache -p --highvram --lowvram --normalvram --gpu-only --novram --cpu; do
    assert_exit 1 "no word $word (never the operator's volumes, never a port, never a memory mode)" -- has_word "$word"
  done
  ARGV=(--tmpfs /data run)
  assert_exit 1 "the scan has teeth: a plain --tmpfs /data does not pass the pair check" -- has_pair --tmpfs /data:exec,size=8g
  newout cb2
  rm -f "$STUB/calls.log" "$STUB/calls.argv"
  # the second container's start asks the engine, at the moment it starts, whether the first is still listed: the answer is the proof that it starts only after the first is gone
  printf 'wslc list | tr -d "\\r" | awk "NR > 1 { print \\$NF }" | grep -cFx r9700tune-comfy-base-1 > %s/base-listed-at-fp16acc-start\n' "$CASE" > "$STUB/on-start-r9700tune-comfy-fp16acc-1"
  assert_exit 0 "two arms in one round" -- cb zimage 1 base fp16acc
  assert_eq "r9700tune-comfy-base-1 r9700tune-comfy-fp16acc-1" "$(bench_names | tr '\n' ' ' | sed 's/ $//')" "one container per arm-round, in the given order"
  assert_exit 0 "the second container is started after the first one's clean stop (call order, after the calls of the first run were cleared)" -- test "$(call_line ' wslc exec r9700tune-comfy-base-1 python3 -c .*SIGINT')" -lt "$(call_line ' wslc run -d --rm --name r9700tune-comfy-fp16acc-1 ')"
  assert_eq "0" "$(cat "$CASE/base-listed-at-fp16acc-start")" "and the first container was no longer listed when the second started"
}

t_the_bench_cache_is_cleared_before_every_arm_round_and_a_failed_clear_refuses_the_arm_round() {
  bench_setup "$FUNCNAME"
  assert_exit 0 "two rounds of base" -- cb zimage 2 base
  local clears
  clears="$(grep -nE ' wslc run --rm --name r9700tune-comfy-clear-[0-9]+ ' "$STUB/calls.log" | cut -d: -f1 | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "2" "$(wc -w <<< "$clears" | tr -d ' ')" "one clear before each of the two arm-rounds"
  assert_contains "$(sed -n "${clears%% *}p" "$STUB/calls.log")" "/cache/tunableop" "the program names the tunableop folder"
  assert_contains "$(sed -n "${clears%% *}p" "$STUB/calls.log")" "mkdir -p" "and makes the folders again after it removed them"
  assert_exit 0 "each clear comes right before its container (call order)" -- test "${clears%% *}" -lt "$(call_line ' wslc run -d --rm --name r9700tune-comfy-base-1 ')" -a "${clears##* }" -lt "$(call_line ' wslc run -d --rm --name r9700tune-comfy-base-2 ')" -a "${clears##* }" -gt "$(call_line ' wslc run -d --rm --name r9700tune-comfy-base-1 ')"
  assert_eq "before clear: 12 /cache/miopen" "$(head -n 1 "$(rec base-1 cache.txt)")" "cache.txt starts with the sizes the clear printed"
  newout cb2
  printf '2\n' > "$STUB/answers/comfy_clear_rc"
  rm -f "$STUB/calls.log" "$STUB/calls.argv"
  rm -rf "$R9700_RESULTS_DIR/runs"
  assert_exit 2 "a clear that fails refuses the arm-round" -- cb zimage 1 base
  assert_eq "" "$(bench_names)" "no bench container was started"
  assert_contains "$SERR" "the worker refused to go on" "the supervisor says the worker refused: no retry"
  outcome_read "$(run_dir_of)/steps/1.outcome"
  assert_eq "refused 2" "$O_KIND $O_RC" "the outcome is KIND=refused RC=2"
  assert_contains "$O_DETAIL" "the bench cache could not be cleared" "and names the cause"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the operator's server was restored"
  assert_contains "$(reason_of base-1)" "REFUSED: the bench cache could not be cleared" "the attempt is kept in rejected/"
  assert_missing "$OUTD/rounds/base-1" "and there is no record"
}

t_the_bench_cache_volume_is_made_when_it_is_missing_and_only_then() {
  bench_setup "$FUNCNAME"
  assert_exit 0 "two rounds of base: the volume is missing at the start" -- cb zimage 2 base
  assert_eq "1" "$(grep -c ' wslc volume create r9700tune-comfy-cache' "$STUB/calls.log")" "one volume create for both arm-rounds"
  assert_exit 0 "the volume list came first (call order)" -- test "$(call_line ' wslc volume list')" -lt "$(call_line ' wslc volume create r9700tune-comfy-cache')"
  assert_exit 0 "and the create came before the clear" -- test "$(call_line ' wslc volume create r9700tune-comfy-cache')" -lt "$(call_line ' wslc run --rm --name r9700tune-comfy-clear-')"
  assert_contains "$(wlog)" "comfy: bench: created volume r9700tune-comfy-cache" "the worker says it made the volume"
  newout cb2
  rm -f "$STUB/calls.log" "$STUB/calls.argv"
  assert_exit 0 "with the volume there" -- cb zimage 1 base
  assert_eq "0" "$(grep -c ' wslc volume create' "$STUB/calls.log")" "nothing is created"
  newout cb3
  rm -f "$STUB/volumes/r9700tune-comfy-cache" "$STUB/calls.log" "$STUB/calls.argv"
  knobs MAX_FAILED_TRIES=1
  printf '3\n' > "$STUB/fail-volume-list"
  assert_exit 7 "a volume list that fails" -- cb zimage 1 base
  assert_contains "$(reason_of base-1)" "the volume list failed" "the arm-round is rejected with the cause"
  assert_eq "" "$(bench_names)" "and no container was started"
}

t_the_card_must_be_free_before_the_cold_run_and_the_reading_is_recorded() {
  bench_setup "$FUNCNAME"
  printf '1000000000 34359738368\n1000000000 34359738368\n1000000000 34359738368\n33000000000 34359738368\n' > "$STUB/answers/comfy_vram"
  assert_exit 0 "a card that frees after three probes" -- cb zimage 1 base
  assert_eq "33000000000" "$(env_val "$(rec base-1 record.env)" VRAM_FREE_BEFORE)" "VRAM_FREE_BEFORE is the reading that passed"
  assert_eq "34359738368" "$(env_val "$(rec base-1 record.env)" VRAM_TOTAL_BEFORE)" "VRAM_TOTAL_BEFORE"
  assert_eq "1000000000" "$(env_val "$(rec base-1 record.env)" VRAM_FREE_FIRST)" "and the first reading is kept"
  local first_run probes
  first_run="$(call_line ' wslc exec r9700tune-comfy-base-1 env python3 .*bench.py run ')"
  probes="$(head -n "$((first_run - 1))" "$STUB/calls.log" | grep -c 'system_stats')"
  assert_eq "4" "$probes" "four probe calls before the first bench.py exec: one readiness, three waits"
  assert_exit 0 "the waits are t_scale 10 apart" -- awk -v n="$(grep -n 'system_stats' "$STUB/calls.log" | sed -n 2p | cut -d: -f1)" -v m="$(grep -n 'system_stats' "$STUB/calls.log" | sed -n 4p | cut -d: -f1)" 'NR == n { a = $1 } NR == m { b = $1 } END { exit !(b - a >= 0.18) }' "$STUB/calls.log"
  newout cb2
  knobs MAX_FAILED_TRIES=1
  printf '1000000000 34359738368\n' > "$STUB/answers/comfy_vram"
  rm -f "$STUB/answers/comfy_vram.n" "$STUB/counters/answer-comfy_vram"
  rm -f "$STUB/calls.log" "$STUB/calls.argv"
  assert_exit 7 "a card that never frees" -- cb zimage 1 base
  assert_eq "UNSTARTED: the card is not free (vram_free 1000000000 of 34359738368 after 300 s)" "$(sed -n 1p "$(reject_of base-1)/reason")" "the reason names the readings and the wait"
  assert_eq "0" "$(grep -c 'bench.py' "$STUB/calls.log")" "no bench.py exec"
  assert_eq "1" "$(stops | grep -c '^r9700tune-comfy-base-1$')" "the container was stopped"
  assert_exit 1 "and is not listed" -- listed r9700tune-comfy-base-1
  newout cb3
  printf 'none\n' > "$STUB/answers/comfy_vram"
  rm -f "$STUB/counters/answer-comfy_vram"
  assert_exit 7 "a probe without the two numbers" -- cb zimage 1 base
  assert_eq "CARD: vram not reported by /system_stats" "$(sed -n 1p "$(reject_of base-1)/reason")" "is named, never taken for a free card"
}

t_a_container_that_does_not_become_ready_is_stopped_by_name_and_the_attempt_is_rejected() {
  bench_setup "$FUNCNAME"
  knobs READY_TIMEOUT_S=120 MAX_FAILED_TRIES=2
  printf 'fail\n' > "$STUB/answers/comfy_ready"
  assert_exit 7 "a container that never answers" -- cb zimage 1 base
  assert_contains "$(sed -n 1p "$(reject_of base-1)/reason")" "UNSTARTED: r9700tune-comfy-base-1 not ready after " "the reason says the container was not ready"
  assert_exit 0 "its server.log is saved" -- test -s "$(reject_of base-1)/server.log"
  assert_exit 0 "logs, then stop, in call order" -- test "$(call_line ' wslc logs r9700tune-comfy-base-1')" -lt "$(call_line ' wslc stop r9700tune-comfy-base-1')"
  assert_exit 1 "the container is not listed at the end" -- listed r9700tune-comfy-base-1
  assert_eq "2" "$(bench_names | wc -l | tr -d ' ')" "two attempts (two failed tries of the step)"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore of the operator's server"
  assert_exit 1 "no unsupported/ mark ever: a start that fails is a machine fault to retry" -- test -e "$OUTD/unsupported"
}

t_a_run_that_outlives_the_adapters_ceiling_ends_the_container() {
  bench_setup "$FUNCNAME"
  export R9700_CEILING_SCALE=1 R9700_COMFY_TEST_EXEC_S=3
  knobs MAX_FAILED_TRIES=1
  printf 'slow 9\n' > "$STUB/answers/comfy_bench_mode.1"
  assert_exit 7 "run 1 is slower than the exec's ceiling" -- cb zimage 1 base
  assert_eq "CEILING: the exec of run 1 was ended by the adapter" "$(sed -n 1p "$(reject_of base-1)/reason")" "the reason says the adapter ended it"
  assert_exit 0 "the stop of the container came after the exec (call order)" -- test "$(call_line ' wslc exec r9700tune-comfy-base-1 .*--run 1 ')" -lt "$(call_line ' wslc stop r9700tune-comfy-base-1')"
  assert_exit 1 "the container is not listed at the end" -- listed r9700tune-comfy-base-1
  assert_missing "$OUTD/rounds/base-1" "no record"
  kill_recorded_pids "$CASE"
}

t_a_cold_run_past_its_ceiling_is_cold_timeout_and_nothing_follows() {
  bench_setup "$FUNCNAME"
  knobs MAX_FAILED_TRIES=1
  printf 'cold_timeout\n' > "$STUB/answers/comfy_bench_mode.cold"
  assert_exit 7 "a cold run past cold_max_s" -- cb zimage 1 base
  assert_eq "COLD_TIMEOUT: the cold run reached 1801.0 s of cold_max_s 1800" "$(sed -n 1p "$(reject_of base-1)/reason")" "the word and the time it reached"
  assert_eq "0" "$(grep -c ' --run [123] ' "$STUB/calls.log")" "no measured run followed"
  assert_exit 1 "the container is not listed" -- listed r9700tune-comfy-base-1
  assert_missing "$OUTD/rounds/base-1" "no record"
  assert_not_contains "$(wlog)$(reason_of base-1)" "slower" "the arm is never reported slower"
}

t_a_complete_arm_round_becomes_final_by_one_rename_and_holds_its_record() {
  bench_setup "$FUNCNAME"
  local out="$OUTD" tag=base-1 f
  # a watcher reads rounds/ fifty times a second through the whole step: the record is a part, then final, never both
  ( while :; do printf '%s\n' "$(ls "$out/rounds" 2> /dev/null | tr '\n' ' ')"; sleep 0.02; done > "$CASE/rounds.log" 2> /dev/null ) &
  guard_pid "$!" "watcher-$!"
  local watcher=$!
  cb_bg zimage 1 base
  step_end 120
  kill "$watcher" 2> /dev/null
  assert_eq "0" "$SRC" "the step ends 0: $SERR"
  assert_exit 0 "rounds/ held the part while the record was built" -- grep -q '^base-1\.part-[^ ]* $' "$CASE/rounds.log"
  assert_exit 0 "and later held the final record alone" -- grep -qx 'base-1 ' "$CASE/rounds.log"
  assert_exit 1 "but never both at once: ONE rename, never a copy" -- grep -Eq 'base-1\.part-.*base-1 |base-1 .*base-1\.part-' "$CASE/rounds.log"
  assert_exit 0 "the watcher saw a part before the final record (order of the lines)" -- test "$(grep -n -m1 'part-' "$CASE/rounds.log" | cut -d: -f1)" -lt "$(grep -nx -m1 'base-1 ' "$CASE/rounds.log" | cut -d: -f1)"
  assert_exit 0 "the record exists" -- test -d "$(rec "$tag" .)"
  for f in record.env bench.txt server.log evidence.txt drift.txt flags.txt cache.txt runs/cold.txt runs/cold.json runs/1.json runs/2.json runs/3.json runs/cold.log runs/1.log runs/2.log runs/3.log; do
    assert_exit 0 "$tag/$f exists" -- test -e "$(rec "$tag" "$f")"
  done
  assert_eq "4" "$(find "$(rec "$tag" outputs)" -type f | wc -l | tr -d ' ')" "outputs/ holds four files"
  assert_eq "0" "$(find "$out/rounds" -name '*.part-*' | wc -l | tr -d ' ')" "no .part- folder remains"
  assert_eq "9" "$(wc -l < "$(rec "$tag" bench.txt)" | tr -d ' ')" "bench.txt: nine lines"
  assert_exit 0 "bench.txt passes comfy-check-block" -- python3 "$REPO/lib/verdict.py" comfy-check-block --tag "$tag" --workflow zimage --metrics "total_s sampler_s vae_s" "$(rec "$tag" bench.txt)"
  assert_eq "ARM=base ROUND=1 CONTAINER=r9700tune-comfy-base-1 WORKFLOW=zimage STOP=clean INERT=no" "$(for k in ARM ROUND CONTAINER WORKFLOW STOP INERT; do printf '%s=%s ' "$k" "$(env_val "$(rec "$tag" record.env)" "$k")"; done | sed 's/ $//')" "record.env: the identity and the outcome"
  for k in RUN_ID STARTED_AT FINGERPRINT IMAGE_ID VRAM_FREE_BEFORE VRAM_TOTAL_BEFORE FLAGS_RUN_1 FLAGS_RUN_2 FLAGS_RUN_3 FINISHED_AT; do
    assert_exit 0 "record.env has $k" -- grep -q "^$k=." "$(rec "$tag" record.env)"
  done
  assert_eq "$(cat "$STUB/answers/logs" 2> /dev/null; cat "$STUB/logs.d/r9700tune-comfy-base-1")" "$(cat "$(rec "$tag" server.log)")" "server.log is the stub's whole log at the last save"
  assert_missing "$BWORK/cb/$tag" "the exchange folder of the tag is gone"
  assert_eq "5" "$(awk '$3 == "wslc" && $4 == "logs" { n++ } END { print n + 0 }' "$STUB/calls.log")" "the log was saved after each of the four runs and once before the stop"
  assert_eq "recorded $tag" "$(grep -x "recorded $tag" <<< "$(wlog)")" "the step log says recorded"
}

run_all_tests
