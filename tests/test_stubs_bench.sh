#!/usr/bin/env bash
# The ComfyUI bench part of the CI stubs (E2.S2, split from tests/test_stubs.sh, which is at the file-size limit): SC1-SC7, the answers of tests/stubs/stub_bench.sh. Every test body is a function
# t_<guarantee>; each runs in its own subshell. The readiness answer of the stub (SC6) is also read by the existing test in tests/test_stubs.sh, which now expects its four lines.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"

BENCH_C=/work/r9700/comfyui/bench.py

# bench_exec <container> <env words...> -- <bench.py words...>: `wslc exec <container> env <words> python3 bench.py <words>`
bench_exec() {
  local name="$1"
  shift
  local -a env_words=()
  while [ "$1" != -- ]; do env_words+=("$1"); shift; done
  shift
  wslc exec "$name" env "${env_words[@]}" python3 "$BENCH_C" "$@"
}

# SC1
t_the_stub_answers_the_exec_of_bench_py_from_scripted_files() {
  setup_case "$FUNCNAME"
  local c=r9700tune-comfy-base-1 out="$R9700_WORK_DIR/r9700/comfyui/bench/o/base-1" want i
  wslc run -d --rm --name "$c" img > /dev/null
  assert_exit 0 "run 1" -- bench_exec "$c" COMFY_BENCH_X=1 -- run zimage --tag base-1 --run 1 --out /work/r9700/comfyui/bench/o/base-1
  assert_eq "base-1 zimage r=1 total_s: 12.345$CR|base-1 zimage r=1 sampler_s: 10.000$CR|base-1 zimage r=1 vae_s: 1.500$CR" "$(tr '\n' '|' <<< "$OUT" | sed 's/|$//')" "the three default lines of run 1, CRLF ends"
  assert_exit 0 "run-1.json is there" -- test -s "$out/run-1.json"
  assert_exit 0 "and the output file" -- test -f "$out/zimage_r1_00001_.png"
  assert_eq "False|['unet', 'clip', 'vaeload', 'pos']|['main.py']" "$(python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); print("|".join(map(str, [d["cold"], d["cached_nodes"], d["server_argv"]])))' "$out/run-1.json")" "the JSON: not cold, the loaders reused from the cache as in a real measured run, the argv of ComfyUI"
  assert_exit 0 "run 3" -- bench_exec "$c" -- run zimage --tag base-1 --run 3 --out /work/r9700/comfyui/bench/o/base-1
  assert_eq "base-1 zimage r=3 total_s: 12.365$CR" "$(sed -n 1p <<< "$OUT")" "run 3: +0.010 per run"
  printf 'r=2 total_s: 9.000\nr=2 sampler_s: 8.000\n' > "$STUB/answers/comfy_bench_lines"
  assert_exit 0 "run 2 with scripted lines" -- bench_exec "$c" -- run zimage --tag base-1 --run 2 --out /work/r9700/comfyui/bench/o/base-1
  assert_eq "base-1 zimage r=2 total_s: 9.000$CR|base-1 zimage r=2 sampler_s: 8.000$CR" "$(tr '\n' '|' <<< "$OUT" | sed 's/|$//')" "the lines of the file for run 2, the tag and the workflow put in front, a line left out stays out"
  rm -f "$STUB/answers/comfy_bench_lines"
  assert_exit 0 "the cold run" -- bench_exec "$c" -- run zimage --tag base-1 --run cold --out /work/r9700/comfyui/bench/o/base-1
  assert_eq "cold: total 40.000 s$CR" "$OUT" "prints the cold line and no verdict line"
  assert_eq "run cold started$CR" "$ERR" "and says on stderr that the run started (stdout keeps the grammar)"
  assert_eq "True|0" "$(python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); print("|".join(map(str, [d["cold"], d["cache_after"]["inductor"]["files"]])))' "$out/run-cold.json")" "run-cold.json: cold, the inductor cache empty"
  for want in "error|EXECUTION_ERROR: node sampler (KSampler): boom|1" "constant|OUTPUT: the image is constant (every pixel 128)|1" "cached|CACHED: the sampler did not execute (cached: sampler)|1" \
              "refused|PROMPT: refused: x|1" "cold_timeout|COLD_TIMEOUT 1801.0|3" "run_timeout|RUN_TIMEOUT 601.0|3"; do
    IFS='|' read -r mode line rc <<< "$want"
    printf '%s\n' "$mode" > "$STUB/answers/comfy_bench_mode.1"
    assert_exit "$rc" "mode $mode" -- bench_exec "$c" -- run zimage --tag base-1 --run 1 --out /work/r9700/comfyui/bench/o/base-1
    assert_eq "$line$CR" "$OUT" "mode $mode prints its line"
  done
  printf 'slow 1\n' > "$STUB/answers/comfy_bench_mode.2"
  printf 'error\n' > "$STUB/answers/comfy_bench_mode.compile.3"
  assert_exit 1 "mode.<arm>.<run> wins for its arm" -- bench_exec r9700tune-comfy-compile-1 -- run zimage --tag compile-1 --run 3 --out /work/r9700/comfyui/bench/o/compile-1
  assert_contains "$ERR" "container not running" "an exec into a name that is not listed fails as today"
  wslc run -d --rm --name r9700tune-comfy-compile-1 img > /dev/null
  assert_exit 1 "the arm's own mode" -- bench_exec r9700tune-comfy-compile-1 -- run zimage --tag compile-1 --run 3 --out /work/r9700/comfyui/bench/o/compile-1
  assert_exit 0 "a slow run sleeps and then answers" -- bench_exec "$c" -- run zimage --tag base-1 --run 2 --out /work/r9700/comfyui/bench/o/base-1
  assert_exit 0 "compile's cold run" -- bench_exec r9700tune-comfy-compile-1 -- run zimage --tag compile-1 --run cold --out /work/r9700/comfyui/bench/o/compile-1
  assert_eq "3" "$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["cache_after"]["inductor"]["files"])' "$R9700_WORK_DIR/r9700/comfyui/bench/o/compile-1/run-cold.json")" "the compile arm: three inductor files"
  local n x="$R9700_WORK_DIR/x" y="$R9700_WORK_DIR/y"
  mkdir -p "$x" "$y"
  for n in 1 2 3; do printf 'same %s\n' "$n" > "$x/zimage_r${n}_00001_.png"; printf 'same %s\n' "$n" > "$y/zimage_r${n}_00001_.png"; done
  assert_eq "drift r=1: mad 0.000 psnr identical$CR|drift r=2: mad 0.000 psnr identical$CR|drift r=3: mad 0.000 psnr identical$CR" "$(bench_exec "$c" -- drift zimage --out /work/x --ref /work/y | tr '\n' '|' | sed 's/|$//')" "drift: identical files, three identical lines"
  printf 'other\n' > "$y/zimage_r2_00001_.png"
  rm -f "$y/zimage_r3_00001_.png"
  assert_eq "drift r=1: mad 0.000 psnr identical$CR|drift r=2: mad 1.000 psnr 48.131$CR|drift r=3: unavailable (the reference of seed 3 is missing)$CR" "$(bench_exec "$c" -- drift zimage --out /work/x --ref /work/y | tr '\n' '|' | sed 's/|$//')" "the answer depends on the reference folder: another content differs, a missing file is unavailable"
  printf 'drift r=1: unavailable (x)\n' > "$STUB/answers/comfy_drift"
  assert_eq "drift r=1: unavailable (x)$CR" "$(bench_exec "$c" -- drift zimage --out /work/x --ref /work/y)" "or answers/comfy_drift"
  kill_recorded_pids "$CASE"
}

# SC2
t_the_stub_clear_container_prints_a_size_line_and_empties_the_bench_cache() {
  setup_case "$FUNCNAME"
  local program='du -s /cache/miopen /cache/tunableop 2> /dev/null; rm -rf /cache/miopen /cache/tunableop; mkdir -p /cache/tunableop'
  mkdir -p "$STUB/cache/miopen"
  : > "$STUB/cache/miopen/x"
  assert_exit 0 "the clear" -- wslc run --rm --name r9700tune-comfy-clear-1 -v r9700tune-comfy-cache:/cache --entrypoint sh img -c "$program"
  assert_eq "12$(printf '\t')/cache/miopen$CR|4$(printf '\t')/cache/triton$CR|0$(printf '\t')/cache/tunableop$CR|0$(printf '\t')/cache/inductor$CR" "$(tr '\n' '|' <<< "$OUT" | sed 's/|$//')" "the default size lines, CRLF ends"
  assert_missing "$STUB/cache" "the stub's bench cache is empty"
  printf '99\t/cache/miopen\n' > "$STUB/answers/comfy_cache"
  printf '2\n' > "$STUB/answers/comfy_clear_rc"
  assert_exit 2 "answers/comfy_clear_rc fails it" -- wslc run --rm --name r9700tune-comfy-clear-2 -v r9700tune-comfy-cache:/cache --entrypoint sh img -c "$program"
  assert_eq "99$(printf '\t')/cache/miopen$CR" "$OUT" "with the scripted lines"
  assert_exit 0 "a run of another program is not the clear" -- wslc run --rm --name r9700tune-comfy-other-1 --entrypoint sh img -c 'echo hi'
  assert_not_contains "$OUT" "99" "it prints nothing of the clear"
}

# SC3 and SC4
t_the_stub_log_grows_per_run_and_the_isolation_words_are_logged_as_given() {
  setup_case "$FUNCNAME"
  local c=r9700tune-comfy-base-1
  printf 'planted line\n' > "$STUB/answers/logs"
  printf 'run one line\n' > "$STUB/answers/comfy_bench_log.1"
  wslc run -d --rm --name "$c" --tmpfs /data:exec,size=8g -v comfy-models:/models:ro -v r9700tune-comfy-cache:/cache img > /dev/null
  bench_exec "$c" -- run zimage --tag base-1 --run cold --out /work/r9700/comfyui/bench/o/base-1 > /dev/null
  assert_eq "planted line|Using pytorch attention" "$(wslc logs "$c" | tr -d '\r' | tr '\n' '|' | sed 's/|$//')" "after the cold run: the planted log, then the evidence lines of base"
  bench_exec "$c" -- run zimage --tag base-1 --run 1 --out /work/r9700/comfyui/bench/o/base-1 > /dev/null
  assert_eq "planted line|Using pytorch attention|run one line" "$(wslc logs "$c" | tr -d '\r' | tr '\n' '|' | sed 's/|$//')" "after run 1: the scripted lines of run 1, in that order"
  printf 'only this\n' > "$STUB/answers/comfy_evidence.fp16acc"
  wslc run -d --rm --name r9700tune-comfy-fp16acc-1 img > /dev/null
  bench_exec r9700tune-comfy-fp16acc-1 -- run zimage --tag fp16acc-1 --run cold --out /work/r9700/comfyui/bench/o/fp16acc-1 > /dev/null
  assert_eq "planted line|only this" "$(wslc logs r9700tune-comfy-fp16acc-1 | tr -d '\r' | tr '\n' '|' | sed 's/|$//')" "another container has its own growth (answers/comfy_evidence.<arm> replaces the default lines)"
  argv_of wslc
  local -a block
  mapfile -t block < <(awk '/^@@ [0-9]+ wslc / { n++ } n == 1 && !/^@@/ && NF { print }' "$STUB/calls.argv")
  assert_eq "run -d --rm --name $c --tmpfs /data:exec,size=8g -v comfy-models:/models:ro -v r9700tune-comfy-cache:/cache img" "${block[*]}" "SC4: the detached run's argv holds --tmpfs and /data:exec,size=8g as two consecutive words and the :ro volume as one"
  assert_eq "1" "$(awk '$1 == "--tmpfs" { getline n; if (n == "/data:exec,size=8g") c++ } END { print c + 0 }' <(printf '%s\n' "${block[@]}"))" "and the pair is found by a scan that reads consecutive words"
  kill_recorded_pids "$CASE"
}

# SC5
t_the_stub_report_container_and_the_clean_stop() {
  setup_case "$FUNCNAME"
  local c=r9700tune-comfy-base-1 report='du -s /cache/tunableop; for f in /cache/tunableop/tunableop_results*.csv; do echo "--- ${f##*/}"; cat "$f"; done'
  assert_exit 0 "the report without a results file" -- wslc run --rm --name r9700tune-comfy-report-1 -v r9700tune-comfy-cache:/cache --entrypoint sh img -c "$report"
  assert_eq "4" "$(wc -l <<< "$OUT" | tr -d ' ')" "four du lines and no file marker when there is no results file"
  printf 'Validator,a,b\nGemmTunableOp_float_NN,1,2,3\n' > "$STUB/answers/comfy_tunableop"
  assert_exit 0 "the report with a results file" -- wslc run --rm --name r9700tune-comfy-report-2 -v r9700tune-comfy-cache:/cache --entrypoint sh img -c "$report"
  assert_eq "--- tunableop_results0.csv$CR|Validator,a,b$CR|GemmTunableOp_float_NN,1,2,3$CR" "$(tail -n 3 <<< "$OUT" | tr '\n' '|' | sed 's/|$//')" "the file, named with the device number as TunableOp names it, follows its marker line"
  printf 'tunableop_results1.csv\n' > "$STUB/answers/comfy_tunableop_name"
  assert_exit 0 "another device number" -- wslc run --rm --name r9700tune-comfy-report-2b -v r9700tune-comfy-cache:/cache --entrypoint sh img -c "$report"
  assert_eq "--- tunableop_results1.csv$CR" "$(tail -n 3 <<< "$OUT" | head -n 1)" "answers/comfy_tunableop_name names the file"
  rm -f "$STUB/answers/comfy_tunableop_name"
  printf '4\n' > "$STUB/answers/comfy_report_rc"
  assert_exit 4 "answers/comfy_report_rc" -- wslc run --rm --name r9700tune-comfy-report-3 -v r9700tune-comfy-cache:/cache --entrypoint sh img -c "$report"
  local sigint='import os, signal; os.kill(1, signal.SIGINT)'
  wslc run -d --rm --name "$c" img > /dev/null
  assert_exit 0 "the clean stop" -- wslc exec "$c" python3 -c "$sigint"
  assert_eq "" "$OUT" "prints nothing"
  assert_exit 0 "wslc list" -- wslc list
  assert_not_contains "$OUT" "$c" "the container is gone, as after a stop"
  wslc run -d --rm --name "$c" img > /dev/null
  printf 'ignore\n' > "$STUB/answers/comfy_clean_stop"
  assert_exit 0 "a clean stop that the server ignores" -- wslc exec "$c" python3 -c "$sigint"
  assert_exit 0 "wslc list" -- wslc list
  assert_contains "$OUT" "$c" "the container is still listed"
  assert_exit 0 "the detached run runs the on-start hook of the test" -- bash -c "printf 'touch %s/started\n' '$CASE' > '$STUB/on-start-x1'; wslc run -d --rm --name x1 img"
  assert_exit 0 "and it ran" -- test -f "$CASE/started"
  kill_recorded_pids "$CASE"
}

# SC6
t_the_ok_readiness_answer_carries_the_card_memory_from_the_comfy_vram_file() {
  setup_case "$FUNCNAME"
  wslc run -d --rm --name a img > /dev/null
  local program='import urllib.request; urllib.request.urlopen("http://127.0.0.1:8188/system_stats")'
  printf 'ok\n' > "$STUB/answers/comfy_ready"
  assert_exit 0 "with no comfy_vram file the default is the card's" -- wslc exec a python3 -c "$program"
  assert_eq "vram_free 34000000000$CR|vram_total 34359738368$CR" "$(sed -n '2,3p' <<< "$OUT" | tr '\n' '|' | sed 's/|$//')" "the default numbers"
  printf '1000000000 34359738368\n33000000000 34359738368\nnone\n' > "$STUB/answers/comfy_vram"
  assert_eq "vram_free 1000000000$CR" "$(wslc exec a python3 -c "$program" | sed -n 2p)" "call 1 takes line 1"
  assert_eq "vram_free 33000000000$CR" "$(wslc exec a python3 -c "$program" | sed -n 2p)" "call 2 takes line 2"
  assert_eq "device cuda:0 AMD Radeon AI PRO R9700 : native$CR|vram: not in the answer$CR|ready$CR" "$(wslc exec a python3 -c "$program" | tr '\n' '|' | sed 's/|$//')" "the word none prints the one line (call 3), device first and ready last"
  assert_eq "vram: not in the answer$CR" "$(wslc exec a python3 -c "$program" | sed -n 2p)" "the last line repeats"
  kill_recorded_pids "$CASE"
}

# SC7 (E2.S2, added): the model listing container
t_the_stub_lists_the_asked_model_files_and_a_scripted_answer_replaces_the_list() {
  setup_case "$FUNCNAME"
  local program='for f in "$@"; do [ -f "/models/$f" ] && echo "$f $(stat -c %s "/models/$f")"; done'
  assert_exit 0 "the listing container" -- wslc run --rm --name r9700tune-comfy-fp-1 -v comfy-models:/models:ro --entrypoint sh img -c "$program" sh vae/ae.safetensors loras/x.safetensors
  assert_eq "vae/ae.safetensors 1000$CR|loras/x.safetensors 1000$CR" "$(tr '\n' '|' <<< "$OUT" | sed 's/|$//')" "every asked file is listed with a size"
  printf 'vae/ae.safetensors 5\n' > "$STUB/answers/comfy_models_listing"
  assert_exit 0 "a scripted listing" -- wslc run --rm --name r9700tune-comfy-fp-2 -v comfy-models:/models:ro --entrypoint sh img -c "$program" sh vae/ae.safetensors loras/x.safetensors
  assert_eq "vae/ae.safetensors 5$CR" "$OUT" "replaces the list"
}

run_all_tests
