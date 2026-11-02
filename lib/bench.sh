#!/usr/bin/env bash
# lib/bench.sh — the measured benchmark of one running server. SOURCED; defines functions and runs nothing. Bash >= 4.4, `set -u` safe,
# no `set -e`. Needs lib/adapter.sh and a loaded config.
#
#   bench_run <container> <tag>
#   prefill_run <container> <tag> <input length>      speed_A.sh lines 30-37: 3 prompts at c=1, random input <length>, output 128, seeds 1-3
#   bench_argv_text <container> <c> <r> / prefill_argv_text <container> <length> <r>    the line one measurement runs, for a dry run
#
# The six `vllm bench serve` runs of the old bench.sh, through wslc_exec 1800: random input 1024 and output 512 tokens, concurrency 1
# with 6 prompts and concurrency 4 with 12, seeds 1-3 each. Of every run it keeps the three metric lines (output token throughput,
# mean TTFT, mean TPOT) and prints them with the prefix `<tag> c=<c> r=<r> ` — the grammar lib/verdict.py parses. It prints; the caller
# decides where the lines go. The first run that fails ends the loop with its code and one `bench:` line naming the measurement.

# _bench_words <array name> <input len> <output len> <prompts> <concurrency> <seed>: the words after `exec <container>` of ONE measurement. The
# one place the `vllm bench serve` argv is written: the decode runs and the prefill runs differ only in these five numbers.
_bench_words() {
  local -n _bench_out="$1"
  _bench_out=(vllm bench serve --backend vllm --base-url http://127.0.0.1:8000 --model "$R9700_SERVED_NAME" --tokenizer "$R9700_MODEL_DIR"
    --dataset-name random --random-input-len "$2" --random-output-len "$3" --ignore-eos --num-prompts "$4" --max-concurrency "$5" --seed "$6")
}

_bench_tag_ok() {
  [[ ${1:-} =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] && return 0
  echo "$2: the tag \"${1:-}\" is not letters, digits, . _ - (no leading -)" >&2
  return 2
}

bench_argv_text() {
  local -a words=()
  _bench_words words 1024 512 "$((${2:-1} == 1 ? 6 : 12))" "${2:-1}" "${3:-1}"
  wslc_argv_text exec "${1:-}" "${words[@]}"
}

prefill_argv_text() {
  local -a words=()
  _bench_words words "${2:-}" 128 3 1 "${3:-1}"
  wslc_argv_text exec "${1:-}" "${words[@]}"
}

prefill_run() {
  local name="${1:-}" tag="${2:-}" len="${3:-}" r rc
  local -a words=()
  if [ "$#" -ne 3 ]; then
    echo "prefill_run: usage: prefill_run <container> <tag> <input length>" >&2
    return 2
  fi
  _adapter_name_ok prefill_run "$name" || return 2
  _bench_tag_ok "$tag" prefill_run || return 2
  if ! [[ $len =~ ^[1-9][0-9]{0,8}$ ]]; then
    echo "prefill_run: the input length \"$len\" is not a positive integer" >&2
    return 2
  fi
  for r in 1 2 3; do
    _bench_words words "$len" 128 3 1 "$r"
    wslc_exec 1800 "$name" "${words[@]}" | grep -E "Output token throughput|Mean TTFT|Median TTFT" 9>&- | sed "s/^/$tag prefill$len r=$r /" 9>&-
    rc="${PIPESTATUS[0]}"
    if [ "$rc" -ne 0 ]; then
      echo "prefill: the run $len r=$r on $name failed (code $rc); the series stops here" >&2
      return "$rc"
    fi
  done
  return 0
}

bench_run() {
  local name="${1:-}" tag="${2:-}" c r n rc
  local -a words=()
  if [ "$#" -ne 2 ]; then
    echo "bench_run: usage: bench_run <container> <tag>" >&2
    return 2
  fi
  _adapter_name_ok bench_run "$name" || return 2
  _bench_tag_ok "$tag" bench_run || return 2
  for c in 1 4; do
    for r in 1 2 3; do
      n=$((c == 1 ? 6 : 12))
      _bench_words words 1024 512 "$n" "$c" "$r"
      wslc_exec 1800 "$name" "${words[@]}" | grep -E "Output token throughput|Mean TTFT|Mean TPOT" 9>&- | sed "s/^/$tag c=$c r=$r /" 9>&-
      rc="${PIPESTATUS[0]}"
      if [ "$rc" -ne 0 ]; then
        echo "bench: the run c=$c r=$r on $name failed (code $rc); the series stops here" >&2
        return "$rc"
      fi
    done
  done
  return 0
}
