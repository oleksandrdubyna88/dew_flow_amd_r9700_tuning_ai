#!/usr/bin/env bash
# lib/bench.sh — the measured benchmark of one running server. SOURCED; defines functions and runs nothing. Bash >= 4.4, `set -u` safe,
# no `set -e`. Needs lib/adapter.sh and a loaded config.
#
#   bench_run <container> <tag>
#
# The six `vllm bench serve` runs of the old bench.sh, through wslc_exec 1800: random input 1024 and output 512 tokens, concurrency 1
# with 6 prompts and concurrency 4 with 12, seeds 1-3 each. Of every run it keeps the three metric lines (output token throughput,
# mean TTFT, mean TPOT) and prints them with the prefix `<tag> c=<c> r=<r> ` — the grammar lib/verdict.py parses. It prints; the caller
# decides where the lines go. The first run that fails ends the loop with its code and one `bench:` line naming the measurement.

bench_run() {
  local name="${1:-}" tag="${2:-}" c r n rc
  if [ "$#" -ne 2 ]; then
    echo "bench_run: usage: bench_run <container> <tag>" >&2
    return 2
  fi
  _adapter_name_ok bench_run "$name" || return 2
  if ! [[ $tag =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    echo "bench_run: the tag \"$tag\" is not letters, digits, . _ - (no leading -)" >&2
    return 2
  fi
  for c in 1 4; do
    for r in 1 2 3; do
      n=$((c == 1 ? 6 : 12))
      wslc_exec 1800 "$name" vllm bench serve --backend vllm --base-url http://127.0.0.1:8000 --model "$R9700_SERVED_NAME" \
        --tokenizer "$R9700_MODEL_DIR" --dataset-name random --random-input-len 1024 --random-output-len 512 --ignore-eos \
        --num-prompts "$n" --max-concurrency "$c" --seed "$r" | grep -E "Output token throughput|Mean TTFT|Mean TPOT" 9>&- | sed "s/^/$tag c=$c r=$r /" 9>&-
      rc="${PIPESTATUS[0]}"
      if [ "$rc" -ne 0 ]; then
        echo "bench: the run c=$c r=$r on $name failed (code $rc); the series stops here" >&2
        return "$rc"
      fi
    done
  done
  return 0
}
