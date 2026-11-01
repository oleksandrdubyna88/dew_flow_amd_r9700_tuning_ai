#!/usr/bin/env bash
# serve_start and bench_run (E1.S2 part (a), scenario A8). Every test body is a function t_<guarantee>; each runs in its own subshell.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"

BENCH_FIXTURE="$HERE/fixtures/ship_test/bench_final_ab.txt"
SERVE_FIXED='--gpus all --shm-size 16g -e HIP_VISIBLE_DEVICES=0 -e TRITON_CACHE_DIR=/root/.cache/vllm/triton -e PYTHONPYCACHEPREFIX=/tmp/pyc-fresh -e PYTHONDONTWRITEBYTECODE=1'
SERVE_IMAGE='rocm/vllm:rocm10.1.0_ubuntu24.04_py3.14-pytorch_2.13.0_vllm-0.29.0'
SERVE_ARGS='vllm serve /root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ --served-model-name qwen3.6-35b-a3b --host 0.0.0.0 --port 8000 --max-model-len 131072 --gpu-memory-utilization 0.85 --max-num-seqs 4 --generation-config /genconfig --limit-mm-per-prompt.image 0 --limit-mm-per-prompt.video 0'

# model_without_mounts: the 35B example with its MOUNTS line removed (the expected line of A8 holds only the given mount)
model_without_mounts() {
  grep -v '^MOUNTS=' "$MODEL_35B" > "$CASE/model.env"
}

t_serve_start_builds_the_measured_container_command() {
  setup_case "$FUNCNAME"
  model_without_mounts
  config_load "$CASE/machine.env" "$CASE/model.env" || exit 2
  local want
  want="run -d --rm --name r9700tune-t-1 $SERVE_FIXED -e A=1 -v hf-cache:/root/.cache/huggingface -v vllm-cache:/root/.cache/vllm -v C:\\r9700\\work:/work -v C:\\r9700\\genconfig:/genconfig:ro -v C:\\r9700\\patches\\C\\auto_gptq.py:/opt/x.py:ro $SERVE_IMAGE $SERVE_ARGS --speculative-config.method mtp"
  assert_exit 0 "serve_start returns what wait_ready returned" -- serve_start r9700tune-t-1 "$CASE/server.log" -e A=1 -v C/auto_gptq.py:/opt/x.py:ro -- --speculative-config.method mtp
  assert_eq "$want" "$(log_args wslc)" "the run line, in order"
  argv_of wslc
  assert_eq "run" "${ARGV[0]}" "the first argument is run"
  assert_eq "1" "$(printf '%s\n' "${ARGV[@]}" | grep -cxF 'C:\r9700\patches\C\auto_gptq.py:/opt/x.py:ro')" "the mount is ONE argument of its own"
  assert_eq "r9700tune-t-1 $CASE/server.log" "$(cat "$CASE/wait_ready.calls")" "wait_ready was called once with the name and the log"
  kill_recorded_pids "$CASE"
}

t_serve_start_returns_the_code_of_wait_ready_and_runs_it_after_the_container_started() {
  setup_case "$FUNCNAME"
  DOUBLE_READY_RC=1
  assert_exit 1 "wait_ready said 1" -- serve_start r9700tune-t-1 "$CASE/server.log" --
  DOUBLE_READY_RC=0
  assert_exit 0 "wait_ready said 0" -- serve_start r9700tune-t-2 "$CASE/server.log" --
  assert_eq "2" "$(wc -l < "$CASE/wait_ready.calls" | tr -d ' ')" "wait_ready ran once per start"
  assert_eq "r9700tune-t-1 r9700tune-t-2" "$(wslc_list | sort | tr '\n' ' ' | sed 's/ $//')" "both containers were started first"
  kill_recorded_pids "$CASE"
}

t_serve_start_puts_the_model_mounts_before_the_given_mounts_and_translates_each_source() {
  setup_case "$FUNCNAME"
  serve_start r9700tune-t-1 "$CASE/server.log" -v C/gptq_utils.py:/opt/y.py -- > /dev/null
  local line
  line="$(log_args wslc)"
  assert_contains "$line" "-v C:\\r9700\\patches\\C\\auto_gptq.py:/opt/python/lib/python3.14/site-packages/vllm/model_executor/layers/quantization/auto_gptq.py:ro -v C:\\r9700\\patches\\C\\gptq_utils.py:/opt/python/lib/python3.14/site-packages/vllm/model_executor/layers/quantization/utils/gptq_utils.py:ro -v C:\\r9700\\patches\\C\\gptq_utils.py:/opt/y.py $SERVE_IMAGE" "the model's two mounts, then the given one (no :ro: none was asked), then the image"
  kill_recorded_pids "$CASE"
}

t_serve_start_never_expands_a_glob_in_the_model_mounts_or_the_extra_arguments() {
  setup_case "$FUNCNAME"
  : > "$CASE/glob-bait.txt"
  cd "$CASE" || exit 2
  R9700_MOUNTS='*:/x' R9700_EXTRA_SERVE_ARGS='--a *' serve_start r9700tune-t-1 "$CASE/server.log" -- > /dev/null
  assert_contains "$(log_args wslc)" "-v C:\\r9700\\patches\\*:/x " "the mount source stays a literal star"
  assert_contains "$(log_args wslc)" " --a *" "the extra argument stays a literal star"
  assert_not_contains "$(log_args wslc)" "glob-bait" "no file name was substituted"
  kill_recorded_pids "$CASE"
}

t_serve_start_splits_a_nested_source_into_windows_folders() {
  setup_case "$FUNCNAME"
  mkdir -p "$CASE/patches/work/speed/o7"
  : > "$CASE/patches/work/speed/o7/k.py"
  model_without_mounts
  config_load "$CASE/machine.env" "$CASE/model.env" || exit 2
  serve_start r9700tune-t-1 "$CASE/server.log" -v work/speed/o7/k.py:/opt/k.py:ro -- > /dev/null
  assert_contains "$(log_args wslc)" "-v C:\\r9700\\patches\\work\\speed\\o7\\k.py:/opt/k.py:ro " "slashes of the relative source become backslashes"
  kill_recorded_pids "$CASE"
}

t_serve_start_refuses_bad_arguments_before_any_call() {
  setup_case "$FUNCNAME"
  assert_exit 2 "a lower-case environment name" -- serve_start r9700tune-t-1 "$CASE/s.log" -e a=1 --
  assert_contains "$ERR" "serve: " "the line starts with serve:"
  assert_exit 2 "an environment word with a space" -- serve_start r9700tune-t-1 "$CASE/s.log" -e "A=1 B=2" --
  assert_exit 2 "a mount that leaves PATCH_DIR" -- serve_start r9700tune-t-1 "$CASE/s.log" -v ../x:/y --
  assert_exit 2 "an absolute mount source" -- serve_start r9700tune-t-1 "$CASE/s.log" -v /etc/passwd:/y --
  assert_exit 2 "a mount with no container path" -- serve_start r9700tune-t-1 "$CASE/s.log" -v C/auto_gptq.py --
  assert_exit 2 "an unknown option" -- serve_start r9700tune-t-1 "$CASE/s.log" --rm --
  assert_contains "$ERR" "legal:" "the line names the legal options"
  assert_exit 2 "no name" -- serve_start
  assert_exit 2 "a name that could be an option" -- serve_start --x "$CASE/s.log" --
  assert_missing "$STUB/calls.log" "no stub was called"
  assert_missing "$CASE/wait_ready.calls" "wait_ready was not called"
}

t_serve_start_does_not_wait_for_a_server_that_wslc_could_not_start() {
  setup_case "$FUNCNAME"
  R9700_WSLC=nonesuch-wslc
  assert_exit 10 "the adapter's code is returned" -- serve_start r9700tune-t-1 "$CASE/s.log" --
  assert_contains "$ERR" "serve: " "a serve: line says what failed"
  assert_missing "$CASE/wait_ready.calls" "wait_ready was not called"
}

t_bench_run_prints_the_recorded_lines_and_runs_the_six_measured_commands() {
  setup_case "$FUNCNAME"
  local want
  # the 18 decode lines of the recorded fcombo-2 block, without their tag: what vllm bench serve prints, unprefixed
  sed -n 175,192p "$BENCH_FIXTURE" | sed -E 's/^fcombo-2 c=[0-9] r=[0-9] //' > "$STUB/answers/bench"
  want="$(sed -n 175,192p "$BENCH_FIXTURE")"
  wslc_run r9700tune-t-1 img > /dev/null
  assert_exit 0 "bench_run" -- bench_run r9700tune-t-1 fcombo-2
  assert_eq "$want" "$OUT" "the output equals the recorded 18 lines, tag, c=, r= and trailing spaces included"
  assert_eq "6" "$(grep -c ' wslc exec ' "$STUB/calls.log")" "six exec calls"
  local expected="" c n r
  for c in 1 4; do
    n=$((c == 1 ? 6 : 12))
    for r in 1 2 3; do
      expected+="exec r9700tune-t-1 vllm bench serve --backend vllm --base-url http://127.0.0.1:8000 --model qwen3.6-35b-a3b --tokenizer /root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ --dataset-name random --random-input-len 1024 --random-output-len 512 --ignore-eos --num-prompts $n --max-concurrency $c --seed $r"$'\n'
    done
  done
  assert_eq "${expected%$'\n'}" "$(awk '$3 == "wslc" && $4 == "exec" { sub(/^[^ ]+ [^ ]+ [^ ]+ /, ""); print }' "$STUB/calls.log")" "the six commands: 6 prompts at c=1 x3, 12 at c=4 x3, seeds 1-3, random 1024/512"
}

t_bench_run_keeps_only_the_three_metric_lines_and_refuses_a_bad_tag() {
  setup_case "$FUNCNAME"
  # one block of three lines (the last block repeats for every run): a noise line between two metrics
  printf 'noise line\nOutput token throughput (tok/s):  1.5\nMean TPOT (ms):  3.5\n' > "$STUB/answers/bench"
  wslc_run r9700tune-t-1 img > /dev/null
  assert_exit 0 "bench_run" -- bench_run r9700tune-t-1 base-1
  assert_not_contains "$OUT" "noise" "lines that are not a metric are cut"
  assert_eq "12" "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" "two metric lines per call, six calls"
  assert_eq "base-1 c=1 r=1 Output token throughput (tok/s):  1.5" "$(printf '%s\n' "$OUT" | sed -n 1p)" "the tag, c= and r= prefix"
  assert_eq "base-1 c=4 r=3 Mean TPOT (ms):  3.5" "$(printf '%s\n' "$OUT" | tail -n 1)" "the last line is c=4 r=3"
  local before; before="$(wc -l < "$STUB/calls.log")"
  assert_exit 2 "a tag with a slash" -- bench_run r9700tune-t-1 'a/b'
  assert_exit 2 "a tag with a space" -- bench_run r9700tune-t-1 'a b'
  assert_exit 2 "an empty tag" -- bench_run r9700tune-t-1 ''
  assert_exit 2 "a bad container name" -- bench_run '-x' tag
  assert_eq "$before" "$(wc -l < "$STUB/calls.log")" "a refused call made no stub call"
}

t_bench_run_stops_at_the_first_failed_exec_and_says_so() {
  setup_case "$FUNCNAME"
  R9700_WSLC=nonesuch-wslc
  assert_exit 10 "the adapter's code is returned" -- bench_run r9700tune-t-1 tag
  assert_contains "$ERR" "bench: " "a bench: line says where"
  assert_contains "$ERR" "c=1 r=1" "and at which measurement"
  assert_eq "1" "$(grep -c 'adapter:' <<< "$ERR")" "the adapter's line once: the loop did not go on"
}

run_all_tests
