#!/usr/bin/env bash
# The kernels units as workers under the E1 supervisor (E3.S1): the linear-bench unit and the prefixtest unit of lib/kernels.sh, their records, the cache clear of
# the one hook, the identity check of every placed asset, the server that does not become ready. Scenarios KW1-KW13 of the story (KW10, the reused --name of another
# experiment, is a verb rule and is in tests/test_kernels_verb.sh with the verbs). Every test body is a function t_<guarantee>; each runs in its own subshell and
# writes only below $R9700_TEST_ROOT. "A stub linear unit" is `step linear-bench -- bash lib/kernels.sh linear <outdir> <model> n1 graph "1 2 6" "6"`; "a stub
# prefix unit" is `step prefixtest -- bash lib/kernels.sh prefix <outdir> <model> p1 base "8192 1024" 64` (tests/lib/kernelcase.sh).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"
# shellcheck source=tests/lib/lifecycle.sh
source "$HERE/lib/lifecycle.sh"
# shellcheck source=tests/lib/kernelcase.sh
source "$HERE/lib/kernelcase.sh"

# ---- KW1: a linear unit records only a validated JSON, with the measured argv ---------------------------------------------------------------------------------------------

t_kw1_a_linear_unit_records_a_validated_json_with_the_measured_argv_and_the_identity() {
  kernels_setup "$FUNCNAME"
  local rec="$RECS/linear/n1" stale="$WORK/linear/n1/stale.json" expect
  mkdir -p "$WORK/linear/n1"
  : > "$stale" # a file of an earlier run in the exchange folder: it must be gone
  assert_exit 0 "a stub linear unit" -- klinear n1 graph "1 2 6" "6"
  for file in linear_bench.json linear.log summary.txt linear.env; do assert_exit 0 "the record holds $file" -- test -s "$rec/$file"; done
  assert_missing "$stale" "the exchange folder was deleted and made again before the run"
  run_argv linear-bench-1
  expect="run|--rm|--name|r9700tune-linear-bench-1|--gpus|all|--shm-size|16g|-e|HIP_VISIBLE_DEVICES=0|-e|TRITON_CACHE_DIR=/root/.cache/vllm/triton-linear"
  expect+="|-v|vllm-cache:/root/.cache/vllm|-v|C:\\r9700\\work:/work|$R9700_IMAGE|python3|/work/r9700/linear_bench.py|run|--out|/work/r9700/linear/n1/linear_bench.json"
  expect+="|--shapes|$R9700_LINEAR_SHAPES|--group-size|128|--ms|1 2 6|--sweep-ms|6|--timer|graph"
  assert_eq "$expect" "$(IFS='|'; echo "${ARGV[*]}")" "the argv of night3.sh lines 38-40 through the adapter, word by word (the shapes and the Ms are ONE word each)"
  assert_eq "$(sha256sum "$REPO/lib/linear_bench.py" | cut -d' ' -f1)" "$(env_get "$rec/linear.env" LINEAR_BENCH_SHA256)" "linear.env names the hash of the placed benchmark"
  assert_eq "$(sha256sum "$REPO/lib/prefixtest.py" | cut -d' ' -f1)" "$(env_get "$rec/linear.env" PREFIXTEST_SHA256)" "and of the other placed file"
  assert_eq "$R9700_LINEAR_SHAPES" "$(env_get "$rec/linear.env" SHAPES)" "SHAPES"
  assert_eq "1 2 6" "$(env_get "$rec/linear.env" MS)" "MS"
  assert_eq "6" "$(env_get "$rec/linear.env" SWEEP_MS)" "SWEEP_MS"
  assert_eq "graph" "$(env_get "$rec/linear.env" TIMER)" "TIMER"
  assert_eq "$R9700_IMAGE" "$(env_get "$rec/linear.env" IMAGE)" "IMAGE"
  assert_eq "$R9700_MODEL_DIR" "$(env_get "$rec/linear.env" MODEL_DIR)" "MODEL_DIR"
  assert_eq "0" "$(env_get "$rec/linear.env" RC)" "RC=0"
  assert_eq "${R9700_CONTAINER_PREFIX}linear-bench-1" "$(env_get "$rec/linear.env" CONTAINER)" "CONTAINER"
  assert_eq "$(python3 "$REPO/lib/linear_bench.py" summarize "$rec/linear_bench.json")" "$(cat "$rec/summary.txt")" "summary.txt is the summarize output of the recorded JSON"
  assert_eq "0" "$(find "$RECS" -name '*.part-*' | wc -l | tr -d ' ')" "no .part- directory remains"
  assert_eq "1" "$(prod_stops)" "the operator's server was stopped once"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "and restored once"
  assert_eq "done" "$(cat "$(last_run_dir)/status")" "the run's status is done"
}

# ---- KW2, KW3: a result that fails the check is a rejected record and a failed try -------------------------------------------------------------------------------------

t_kw2_a_json_that_fails_the_check_is_a_rejected_record_and_a_failed_try() {
  kernels_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  linear_answer "1 2 6" "6" no-layers
  assert_exit 7 "a stub linear unit whose JSON has a row without layers (MAX_FAILED_TRIES=1)" -- klinear n1 graph "1 2 6" "6"
  assert_missing "$RECS/linear/n1" "no record"
  assert_contains "$(cat "$(rejected_of linear n1)/reason")" "row 0: layers is not a positive integer" "the reason names the row and the key"
  assert_exit 0 "the rejected record keeps the log and the JSON" -- test -s "$(rejected_of linear n1)/linear_bench.json"
  outcome_read "$(last_run_dir)/steps/1.outcome"
  assert_eq "worker" "$O_KIND" "KIND=worker"
  assert_eq "1" "$O_RC" "the worker exited 1"
}

t_kw3_every_shape_and_m_pair_exactly_once_a_count_of_rows_would_pass_a_duplicate() {
  kernels_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  linear_answer "1 2 6" "6" missing
  assert_exit 7 "(a) 14 rows for 5 shapes x 3 Ms" -- klinear a graph "1 2 6" "6"
  assert_contains "$(cat "$(rejected_of linear a)/reason")" "missing (shared_expert.down_proj, M 6)" "the reason names the first missing pair"
  linear_answer "1 2 6" "6" dup
  assert_eq "15" "$(python3 -c 'import json, sys; print(len(json.load(open(sys.argv[1]))))' "$STUB/answers/linear")" "(b) the premise: as many rows as asked for"
  assert_exit 7 "(b) 15 rows where a pair is doubled and another is missing" -- klinear b graph "1 2 6" "6"
  assert_contains "$(cat "$(rejected_of linear b)/reason")" "duplicate (linear_attn.in_proj_qkvz, M 2)" "the reason names the duplicate: the case a bare count passes"
  assert_contains "$(cat "$(rejected_of linear b)/reason")" "missing (linear_attn.in_proj_qkvz, M 1)" "and the pair that is missing"
  linear_answer "1 2 6" "6" extra
  assert_exit 7 "(c) 16 rows with a pair for an M that was not asked" -- klinear c graph "1 2 6" "6"
  assert_contains "$(cat "$(rejected_of linear c)/reason")" "unexpected (linear_attn.in_proj_qkvz, M 7)" "the reason names it"
  assert_missing "$RECS/linear/a" "no record of a"
  assert_missing "$RECS/linear/b" "no record of b"
  assert_missing "$RECS/linear/c" "no record of c"
}

# ---- KW4, KW11, KW12: the identity of the placed files -----------------------------------------------------------------------------------------------------------------

t_kw4_a_placed_file_edited_between_the_placement_and_the_unit_is_refused() {
  kernels_setup "$FUNCNAME"
  printf 'x' >> "$WORK/linear_bench.py"
  assert_exit 2 "a stub linear unit over an edited placed benchmark" -- klinear n1 graph "1 2 6" "6"
  outcome_read "$(last_run_dir)/steps/1.outcome"
  assert_eq "refused" "$O_KIND" "KIND=refused"
  assert_contains "$O_DETAIL" "linear_bench.py in the work folder differs from lib/linear_bench.py" "the detail names the file and its source"
  assert_eq "0" "$(run_lines linear-bench-1 | wc -l | tr -d ' ')" "no container ran"
  assert_missing "$RECS/linear/n1" "no record"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
}

t_kw11_the_identity_check_covers_every_kernels_asset_derived_from_the_table() {
  kernels_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  local name source need n=0 placed line
  local -a assets=()
  mapfile -t assets < <(kernels_assets)
  for line in "${assets[@]}"; do
    read -r name source need _ <<< "$line"
    n=$((n + 1))
    placed="$WORK/$name"
    printf 'x' >> "$placed"
    assert_exit 2 "$name differs: a stub linear unit is refused" -- klinear "id-$n" graph "1 2 6" "6"
    outcome_read "$(last_run_dir)/steps/1.outcome"
    assert_contains "$O_DETAIL" "$name in the work folder differs from $source" "$name: the detail names the asset"
    assert_exit 2 "$name differs: a stub prefix unit is refused too" -- kprefix "ip-$n" base "8192 1024" 64
    assert_eq "0" "$(run_lines "linear-bench-1" | wc -l | tr -d ' ')" "$name: no container ran"
    cp "$REPO/$source" "$placed"
    mv "$placed" "$placed.away"
    assert_exit 2 "$name (required) missing: refused" -- klinear "miss-$n" graph "1 2 6" "6"
    outcome_read "$(last_run_dir)/steps/1.outcome"
    assert_contains "$O_DETAIL" "$name is missing in the work folder" "$name: the detail says it is missing"
    mv "$placed.away" "$placed"
  done
  if [ "$n" -ge 2 ]; then assert_eq ok ok "the loop derived the assets from the table ($n of them)"; else assert_eq ">= 2" "$n" "the table lists the two assets"; fi
  assert_exit 0 "all exact again: a stub linear unit is recorded" -- klinear ok graph "1 2 6" "6"
}

t_kw12_the_placement_and_the_identity_check_without_an_argument_still_read_the_moe_table() {
  kernels_setup "$FUNCNAME"
  _MOE_WHO=test
  rm -f "$WORK/benchmark_moe.py" "$WORK/coarse_candidates.json"
  assert_exit 0 "moe_place with no argument places the MoE files" -- moe_place
  assert_exit 0 "and the two files are there" -- test -s "$WORK/benchmark_moe.py" -a -s "$WORK/coarse_candidates.json"
  printf 'x' >> "$WORK/linear_bench.py"
  assert_exit 0 "moe_identity_check with no argument does not look at the kernels files" -- moe_identity_check
  assert_exit 2 "with the kernels table it does" -- moe_identity_check kernels_assets
  assert_contains "$OUT" "linear_bench.py in the work folder differs" "and says which file"
  assert_contains "$(moe_asset_hashes)" "BENCHMARK_SHA256=" "moe_asset_hashes with no argument names the MoE assets"
  assert_not_contains "$(moe_asset_hashes)" "LINEAR_BENCH_SHA256" "and not the kernels assets"
  assert_contains "$(moe_asset_hashes kernels_assets)" "LINEAR_BENCH_SHA256=" "with the kernels table it names the kernels assets"
}

# ---- KW5, KW6: the deadline and a RAM stop in a linear unit ------------------------------------------------------------------------------------------------------------

t_kw5_the_deadline_ends_a_linear_unit_as_kind_deadline_and_the_part_becomes_evidence() {
  kernels_setup "$FUNCNAME"
  # Time scale 5, NOT short_variant's 25: T_STOP 35 s after the start, the cleanup budget 85 s and the readiness window 12 s (short_variant: 9.4 s, 17 s, 2.4 s). The deadline is fixed when
  # the supervisor starts; the quiet wait, the disk gate, the stop of the operator's server and the worker's identity check come after it, and the cleanup and the restore must end
  # inside the budget. On a starved CPU (2026-11-04: 7 busy loops on one core) the 9.4 s window had passed before the unit's container started (step ended 8, "not quiet before the
  # deadline", no part) and the restore did not become ready in 2.4 s (step ended 5): a race between the test's clock and the load, not a defect of the product.
  step_cfg MAX_RUN_MINUTES=10 CLEANUP_BUDGET_S=425 READY_TIMEOUT_S=60
  export R9700_TIME_SCALE=5
  printf '100\n' > "$STUB/answers/linear_seconds"
  moe_sup_bg body_linear
  step_end
  local run
  run="$(last_run_dir)"
  assert_eq "6" "$SRC" "exit 6"
  outcome_read "$run/steps/1.outcome"
  assert_eq "deadline" "$O_KIND" "KIND=deadline"
  for _w in $(seq 1 100); do [ -e "$STUB/containers/${R9700_CONTAINER_PREFIX}linear-bench-1.pid" ] || break; sleep 0.1; done
  assert_missing "$STUB/containers/${R9700_CONTAINER_PREFIX}linear-bench-1.pid" "the linear container is stopped (its record is gone)"
  assert_eq "1" "$(find "$RECS/linear" -maxdepth 1 -name '*.part-*' | wc -l | tr -d ' ')" "the part stays"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
  printf '0\n' > "$STUB/answers/linear_seconds"
  sed -i '/^MAX_RUN_MINUTES=/d; /^CLEANUP_BUDGET_S=/d; /^READY_TIMEOUT_S=/d' "$CASE/machine.env"
  export R9700_TIME_SCALE=100
  assert_exit 0 "the next stub linear unit (with the default deadline)" -- klinear k1 graph "1 2 6" "6"
  assert_contains "$(cat "$(rejected_of linear k1)/reason")" "INTERRUPTED: " "its start moved the part to rejected/ with an INTERRUPTED reason"
}

t_kw6_a_ram_stop_during_a_linear_unit_leaves_no_prefixed_container_and_the_hook_clears_all_three_cache_folders_before_the_restore() {
  kernels_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  printf '100\n' > "$STUB/answers/linear_seconds"
  printf '8000\n' > "$STUB/answers/ram"
  moe_sup_bg body_linear
  wait_for "$STUB/containers/${R9700_CONTAINER_PREFIX}linear-bench-1.pid" 100
  append_answer ram 100
  step_end
  local run clear pwsh stop
  run="$(last_run_dir)"
  assert_eq "7" "$SRC" "the supervisor exits 7 (MAX_FAILED_TRIES=1)"
  outcome_read "$run/steps/1.outcome"
  assert_eq "ram_guard" "$O_KIND" "KIND=ram_guard"
  assert_eq "0" "$(wslc list | grep -c "^${R9700_CONTAINER_PREFIX}")" "no prefixed container is listed after the exit"
  assert_missing "$STUB/containers/${R9700_CONTAINER_PREFIX}linear-bench-1.pid" "and the linear container's record is gone"
  clear="$(last_line_of " wslc run --rm --name ${R9700_CONTAINER_PREFIX}moe-clear ")"
  pwsh="$(line_of " pwsh.exe ")"
  stop="$(line_of " wslc stop ${R9700_CONTAINER_PREFIX}linear-bench-1")"
  if [ -n "$stop" ] && [ "$stop" -lt "$clear" ] && [ "$clear" -lt "$pwsh" ]; then assert_eq ok ok "the stop (line $stop), then the exit-path clear (line $clear), then the restore (line $pwsh)"; else assert_eq "stop < clear < restore" "$stop $clear $pwsh" "the order in the call log"; fi
  run_argv moe-clear
  local got
  got="$(IFS='|'; echo "${ARGV[*]}")"
  assert_contains "$got" "du -sh /root/.cache/vllm/triton-moe-tune /root/.cache/vllm/triton-moe-ab /root/.cache/vllm/triton-linear" "the clear's du names all three cache folders"
  assert_contains "$got" "rm -rf /root/.cache/vllm/triton-moe-tune /root/.cache/vllm/triton-moe-ab /root/.cache/vllm/triton-linear" "and its rm too"
  assert_contains "$(sup_log)" "cleanup hook: moe_cache_clear rc=0" "the supervisor log says the hook ended with rc=0"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the server was restored once"
}

# ---- KW7-KW9, KW13: the prefix unit ---------------------------------------------------------------------------------------------------------------------------------------

t_kw7_a_prefix_unit_starts_the_arms_server_sends_the_exec_stops_the_server_and_records() {
  kernels_setup "$FUNCNAME"
  assert_exit 0 "a stub prefix unit" -- kprefix p1 base "8192 1024" 64
  local rec="$RECS/prefix/p1" want got
  serve_argv prefix-base-1
  got="wslc ${ARGV[*]}"
  local -a envs=() mounts=() sargs=()
  _series_serve_options envs mounts sargs base
  want="$(serve_start --print "${R9700_CONTAINER_PREFIX}prefix-base-1" /dev/null "${envs[@]}" "${mounts[@]}" -- "${sargs[@]}")"
  assert_eq "$want" "$got" "the serve line is the series' serve line for the arm (compared with serve_start --print over the series' own option builder)"
  exec_argv prefix-base-1
  assert_eq "exec|${R9700_CONTAINER_PREFIX}prefix-base-1|python3|/work/r9700/prefixtest.py|run|http://127.0.0.1:8000|qwen3.6-35b-a3b|p1|--lens|8192 1024|--tail|64" "$(IFS='|'; echo "${ARGV[*]}")" "the exec: the check inside the server's container, the Ms and lens as ONE word each"
  local run_line exec_line stop_line
  run_line="$(line_of " wslc run -d --rm --name ${R9700_CONTAINER_PREFIX}prefix-base-1 ")"
  exec_line="$(line_of " wslc exec ${R9700_CONTAINER_PREFIX}prefix-base-1 python3 /work/r9700/prefixtest.py")"
  stop_line="$(line_of " wslc stop ${R9700_CONTAINER_PREFIX}prefix-base-1")"
  if [ "$run_line" -lt "$exec_line" ] && [ "$exec_line" -lt "$stop_line" ]; then assert_eq ok ok "in the call log: start, exec, stop"; else assert_eq "run < exec < stop" "$run_line $exec_line $stop_line" "the order"; fi
  assert_eq "$(wslc list | grep -c "^${R9700_CONTAINER_PREFIX}")" "0" "the server is stopped (not listed)"
  assert_eq "2" "$(wc -l < "$rec/prefixtest.txt" | tr -d ' ')" "prefixtest.txt is the two answer lines"
  assert_eq "$(python3 "$REPO/lib/prefixtest.py" summarize "$rec/prefixtest.txt")" "$(cat "$rec/summary.txt")" "summary.txt is the summarize output"
  assert_contains "$(cat "$rec/summary.txt")" "PREFIX p1 len=8192: cold 2.13 s, hit 0.50 s (4.3x), partial 0.49 s" "with the ratios of the recorded fcombo-1 line (the tag is the record's name)"
  assert_eq "base" "$(env_get "$rec/prefix.env" ARM)" "prefix.env: ARM"
  assert_eq "$(_kern_arm_words base arm_args)" "$(env_get "$rec/prefix.env" ARM_ARGS)" "ARM_ARGS is the arm's words"
  assert_eq "qwen3.6-35b-a3b" "$(env_get "$rec/prefix.env" SERVED_NAME)" "SERVED_NAME"
  assert_eq "8192 1024" "$(env_get "$rec/prefix.env" LENS)" "LENS"
  assert_eq "64" "$(env_get "$rec/prefix.env" TAIL)" "TAIL"
  assert_eq "$(sha256sum "$REPO/lib/prefixtest.py" | cut -d' ' -f1)" "$(env_get "$rec/prefix.env" PREFIXTEST_SHA256)" "the hashes of the placed files"
  assert_exit 0 "server.log is kept" -- test -s "$rec/server.log"
  assert_eq "1" "$(prod_stops)" "the operator's server was stopped once"
}

t_kw8_a_server_lost_during_the_exec_leaves_no_record() {
  kernels_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  export R9700_STUB_DELAY_S=2
  lose_prefix_server "${R9700_CONTAINER_PREFIX}prefix-base-1"
  assert_exit 7 "a stub prefix unit whose server dies in the exec" -- kprefix p1 base "8192 1024" 64
  unset R9700_STUB_DELAY_S
  assert_missing "$RECS/prefix/p1" "no record"
  assert_contains "$(cat "$(rejected_of prefix p1)/reason")" "the server was not listed" "the reason says the server was lost"
}

t_kw8b_a_lost_server_is_named_lost_even_when_the_exec_returned_an_error_code() {
  kernels_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  export R9700_STUB_DELAY_S=2
  printf '1\n' > "$STUB/answers/prefix_rc" # the exec fails because the container went away under it
  lose_prefix_server "${R9700_CONTAINER_PREFIX}prefix-base-1"
  assert_exit 7 "a stub prefix unit whose server dies and whose exec returns 1" -- kprefix p1 base "8192 1024" 64
  unset R9700_STUB_DELAY_S
  assert_contains "$(cat "$(rejected_of prefix p1)/reason")" "LOST: the server was not listed" "the reason is LOST, not rc=1: a lost server is always named"
}

t_kw9_exactly_one_line_per_requested_length_a_count_of_two_would_pass_a_duplicate() {
  kernels_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  local l8k="x prefixtest len=8192 A cold=2.1s A hit=0.5s A hit=0.51s B cold=2.15s B hit=0.48s A partial=0.49s"
  local l1k="${l8k/8192/1024}"
  printf '%s\n' "$l8k" > "$STUB/answers/prefix"
  assert_exit 7 "(a) one line for two lengths" -- kprefix a base "8192 1024" 64
  assert_contains "$(cat "$(rejected_of prefix a)/reason")" "missing len=1024" "the reason says missing len=1024"
  printf '%s\n%s\n' "$l8k" "$l8k" > "$STUB/answers/prefix"
  assert_exit 7 "(b) two lines, both len=8192: as many lines as asked" -- kprefix b base "8192 1024" 64
  assert_contains "$(cat "$(rejected_of prefix b)/reason")" "duplicate len=8192" "the reason names the duplicate"
  printf '%s\n%s\n%s\n' "$l8k" "$l1k" "${l8k/8192/512}" > "$STUB/answers/prefix"
  assert_exit 7 "(c) a third line for len=512" -- kprefix c base "8192 1024" 64
  assert_contains "$(cat "$(rejected_of prefix c)/reason")" "unexpected len=512" "the reason names the unexpected length"
  assert_missing "$RECS/prefix/a" "no record of a"
  assert_missing "$RECS/prefix/b" "no record of b"
}

t_kw13_a_server_that_does_not_become_ready_is_stopped_before_the_worker_exits_and_a_retry_starts_cleanly() {
  kernels_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=2
  printf 'down\n' > "$STUB/answers/ready.${R9700_CONTAINER_PREFIX}prefix-base-1"
  assert_exit 0 "a stub prefix unit whose first server never answers; the retry does" -- kprefix p1 base "8192 1024" 64
  assert_missing "$STUB/containers/${R9700_CONTAINER_PREFIX}prefix-base-1.pid" "the first server's record is gone: it was stopped"
  local probe stop outcome
  probe="$(last_line_of " wslc exec ${R9700_CONTAINER_PREFIX}prefix-base-1 python3 -c")"
  stop="$(line_of " wslc stop ${R9700_CONTAINER_PREFIX}prefix-base-1")"
  if [ -n "$probe" ] && [ -n "$stop" ] && [ "$probe" -lt "$stop" ]; then assert_eq ok ok "in the call log: the last readiness probe (line $probe), then the stop (line $stop)"; else assert_eq "probe < stop" "$probe $stop" "the order"; fi
  local second
  second="$(line_of " wslc run -d --rm --name ${R9700_CONTAINER_PREFIX}prefix-base-2 ")"
  if [ -n "$stop" ] && [ -n "$second" ] && [ "$stop" -lt "$second" ]; then assert_eq ok ok "the first server was stopped (line $stop) BEFORE the retry started its own (line $second): not left for the exit's sweep"; else assert_eq "stop < retry's run" "$stop $second" "the order"; fi
  assert_contains "$(cat "$(rejected_of prefix p1)/reason")" "not ready" "the first try is a rejected record with the reason"
  assert_exit 0 "the second try recorded" -- test -s "$RECS/prefix/p1/prefixtest.txt"
  assert_exit 0 "under a container name of its own (the step number is in the label)" -- test "$(env_get "$RECS/prefix/p1/prefix.env" CONTAINER)" = "${R9700_CONTAINER_PREFIX}prefix-base-2"
  outcome="$(last_run_dir)/steps/1.outcome"
  assert_exit 0 "the first try's outcome exists" -- test -s "$outcome"
}

t_kw17_a_linear_container_left_running_by_a_cut_call_is_stopped_before_the_unit_ends() {
  kernels_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=2
  printf '124\n' > "$STUB/answers/fault.${R9700_CONTAINER_PREFIX}linear-bench-1" # the call is cut at its ceiling and its container stays listed
  assert_exit 0 "a stub linear unit whose first call is cut (124); the retry runs clean" -- klinear n1 graph "1 2 6" "6"
  local stop second
  stop="$(line_of " wslc stop ${R9700_CONTAINER_PREFIX}linear-bench-1")"
  second="$(line_of " wslc run --rm --name ${R9700_CONTAINER_PREFIX}linear-bench-2 ")"
  if [ -n "$stop" ] && [ -n "$second" ] && [ "$stop" -lt "$second" ]; then assert_eq ok ok "the cut call's container was stopped by name (line $stop) before the retry ran (line $second)"; else assert_eq "stop < retry's run" "$stop $second" "the order"; fi
  assert_contains "$(cat "$(rejected_of linear n1)/reason")" "rc=124" "the first try is a rejected record with the code"
  assert_exit 0 "the second try recorded" -- test -s "$RECS/linear/n1/linear_bench.json"
}

t_kw18_a_failed_stop_of_an_unready_server_is_tried_again_and_checked() {
  kernels_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  local name="${R9700_CONTAINER_PREFIX}prefix-base-1"
  printf 'down\n' > "$STUB/answers/ready.$name"
  printf '1\n' > "$STUB/stop-fail-$name" # the first stop does not work
  assert_exit 7 "a stub prefix unit whose server is not ready and whose first stop fails" -- kprefix p1 base "8192 1024" 64
  assert_contains "$(worker_log 1)" "kernels: $name is still listed after stop 1 of 3, stopping it again" "the worker checked the first stop and said so"
  assert_eq "2" "$(grep -c " wslc stop $name\$" "$STUB/calls.log")" "two stops in all"
  assert_missing "$STUB/containers/$name.pid" "the server is gone"
  assert_contains "$(cat "$(rejected_of prefix p1)/reason")" "not ready" "and the first try is a plain rejected record"
}

t_kw19_a_server_that_cannot_be_stopped_is_refused_for_the_supervisors_sweep() {
  kernels_setup "$FUNCNAME"
  local name="${R9700_CONTAINER_PREFIX}prefix-base-1"
  printf 'down\n' > "$STUB/answers/ready.$name"
  printf '3\n' > "$STUB/stop-fail-$name" # every bounded try of the worker fails; the supervisor's own sweep after it works
  assert_exit 2 "a stub prefix unit whose server is not ready and cannot be stopped" -- kprefix p1 base "8192 1024" 64
  outcome_read "$(last_run_dir)/steps/1.outcome"
  assert_eq "refused" "$O_KIND" "KIND=refused: no retry beside a live container"
  assert_contains "$O_DETAIL" "$name is still listed after 3 stops" "the line names the server and the number of stops"
  assert_contains "$(cat "$(rejected_of prefix p1)/reason")" "still listed" "the attempt is kept as evidence"
  assert_eq "0" "$(find "$RECS" -name '*.part-*' | wc -l | tr -d ' ')" "no part directory is left"
  assert_missing "$STUB/containers/$name.pid" "the supervisor's cleanup sweep stopped the server in the end"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
}

t_kw20_a_refused_exchange_folder_leaves_no_part_directory_for_a_false_interrupted_record() {
  kernels_setup "$FUNCNAME"
  if [ "$(id -u)" = 0 ]; then assert_eq ok ok "skipped: running as root (chmod a-w does not stop root)"; return; fi
  mkdir -p "$WORK/linear/n1"
  : > "$WORK/linear/n1/stale"
  chmod a-w "$WORK/linear/n1" # the stale file cannot be removed
  assert_exit 2 "a stub linear unit over an exchange folder that cannot be cleared" -- klinear n1 graph "1 2 6" "6"
  chmod u+w "$WORK/linear/n1"
  outcome_read "$(last_run_dir)/steps/1.outcome"
  assert_eq "refused" "$O_KIND" "KIND=refused"
  assert_eq "0" "$(find "$RECS" -name '*.part-*' 2> /dev/null | wc -l | tr -d ' ')" "no empty part directory was made before the refusal"
  rm -f "$WORK/linear/n1/stale"
  assert_exit 0 "the same unit once the folder is fine" -- klinear n1 graph "1 2 6" "6"
  assert_missing "$RECS/rejected" "and no INTERRUPTED record was made from a part the refusal left"
}

t_kw21_the_server_log_is_never_a_temporary_file_inside_the_part() {
  kernels_setup "$FUNCNAME"
  local name="${R9700_CONTAINER_PREFIX}prefix-base-1"
  printf 'find "%s" -name "server.log.new*" > "%s/logs-seen"\n' "$RECS" "$CASE" > "$STUB/on-logs-$name" # what the part holds while `wslc logs` runs
  assert_exit 0 "a stub prefix unit" -- kprefix p1 base "8192 1024" 64
  assert_exit 0 "the logs call ran" -- test -e "$CASE/logs-seen"
  assert_eq "" "$(cat "$CASE/logs-seen")" "no temporary log file stood in the record while the logs were taken: a kill then leaves nothing behind"
  assert_exit 0 "server.log is there" -- test -s "$RECS/prefix/p1/server.log"
  assert_eq "0" "$(find "$RECS" -name 'server.log.new*' | wc -l | tr -d ' ')" "and no temporary file at the end"
}

t_kw14_a_recorded_name_is_not_run_again_by_the_worker() {
  kernels_setup "$FUNCNAME"
  assert_exit 0 "a stub linear unit" -- klinear n1 graph "1 2 6" "6"
  local before
  before="$(stat -c %Y "$RECS/linear/n1")"
  assert_exit 0 "the same unit again" -- klinear n1 graph "1 2 6" "6"
  assert_contains "$(worker_log 1)" "linear n1: recorded, nothing to do" "the worker says so"
  assert_eq "1" "$(run_lines linear-bench-1 | wc -l | tr -d ' ')" "the call log has no second linear run"
  assert_eq "$before" "$(stat -c %Y "$RECS/linear/n1")" "the record is unchanged"
}

t_kw15_a_stale_part_directory_is_evidence_not_a_record() {
  kernels_setup "$FUNCNAME"
  mkdir -p "$RECS/linear/old.part-hand-1" "$RECS/prefix/older.part-hand-2"
  assert_exit 0 "a stub linear unit after a worker that left parts" -- klinear n1 graph "1 2 6" "6"
  assert_contains "$(worker_log 1 | head -n 3)" "kernels: old.part-hand-1 moved to rejected/linear-old-" "the old linear part moved to rejected/"
  assert_contains "$(cat "$(rejected_of linear old)/reason")" "INTERRUPTED: " "with an INTERRUPTED reason"
  assert_contains "$(cat "$(rejected_of prefix older)/reason")" "INTERRUPTED: " "the prefix part too"
}

t_kw16_a_bad_worker_argument_is_one_line_and_exit_2() {
  kernels_setup "$FUNCNAME"
  mkdir -p "$CASE/run/steps"
  local w="env R9700_RUN_DIR=$CASE/run R9700_OUTCOME_FILE=$CASE/run/steps/1.outcome bash $REPO/lib/kernels.sh"
  assert_exit 2 "an unknown unit" -- $w nosuch
  assert_contains "$ERR" 'kernels: unknown unit "nosuch"; legal: linear prefix' "names the legal units"
  assert_exit 2 "a timer that is not graph or eager" -- $w linear "$RECS" "$KMODEL" n1 slow "1 2" "1"
  assert_contains "$ERR" 'the timer "slow" is not graph or eager' "names it"
  assert_exit 2 "a name that is not a name" -- $w linear "$RECS" "$KMODEL" N1 graph "1 2" "1"
  assert_exit 2 "an arm that is not a name" -- $w prefix "$RECS" "$KMODEL" p1 Base "8192" 64
  assert_exit 2 "a wrong number of arguments" -- $w linear "$RECS"
  assert_eq "0" "$(stop_lines)" "nothing was stopped"
}

run_all_tests
