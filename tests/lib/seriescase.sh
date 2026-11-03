#!/usr/bin/env bash
# Shared by tests/test_series.sh, tests/test_series_identity.sh and tests/test_series_verdict.sh (E1.S3): "a stub series" and the helpers that read
# what it left. Sourced after tests/lib/stepcase.sh; no t_ function in it.
#
#   series_setup <name> [<model file>]  step_setup, plus the stub answers of a stub series (the fixture's complete fcombo-2 block, 50 log lines with
#                                       a MoE configuration line, a model listing, a generation config, two spec-decode metrics), the GSM8K data
#                                       file, and the operator's server running
#   sr <args...>                        `bin/r9700 series <35B model> <args...>` as a user runs it
#   srm <model> <args...>               the same with another model file
#   series_bg <args...>                 `bin/r9700 series <35B model> <args...>` in the background (SUP, then step_end); the output is in $CASE/sup.*
#   outdir [<name>]                     $R9700_RESULTS_DIR/<name>, default s
#   starts                              the names of the detached test containers the call log shows (not the operator's server), in order
#   prod_stops                          how many times the operator's server was stopped
#   calls_since <n>                     the call-log lines after line <n>
#   json_get <file> <python expression over d>   one value of a JSON file
#   short_variant                       the short variant of S2's G5: T_STOP 9.4 s after the start (scale 25; budget 425 since E2.S2 decision 6)
#   build_fixture_outdir <dir>          an outdir built from tests/fixtures/ship_test/bench_final_ab.txt, the way S16 describes
#   lose_server_after <n>               a killer: after the n-th `bench serve` call of a container the container is killed

# shellcheck source=tests/lib/stepcase.sh
source "$HERE/lib/stepcase.sh"

BENCH_FIXTURE="$HERE/fixtures/ship_test/bench_final_ab.txt"
SERIES_MODEL="qwen3.6-35b-a3b-gptq"

series_setup() {
  step_setup "$1" "${2:-$MODEL_35B}"
  sed -n 175,210p "$BENCH_FIXTURE" | sed -E 's/^fcombo-2 //' > "$STUB/answers/bench"
  { for i in $(seq 1 49); do echo "INFO (EngineCore) line $i"; done; echo "INFO Using configuration from /work/moe/tune/merged for MoE layer."; } > "$STUB/answers/logs"
  printf 'a.safetensors 100\nconfig.json 10\n' > "$STUB/answers/find"
  printf 'generation_config.json %s\n' "$(printf '0%.0s' $(seq 1 64))" > "$STUB/answers/genconfig"
  printf 'vllm:spec_decode_num_drafts_total{engine="0"} 12.0\nvllm:spec_decode_num_accepted_tokens_total{engine="0"} 20.0\n' > "$STUB/answers/metrics"
  mkdir -p "$CASE/work/gsm8k"
  : > "$CASE/work/gsm8k/test.jsonl"
  prod_running
}

sr() { r9700 series "$SERIES_MODEL" "$@"; }

srm() {
  local model="$1"
  shift
  r9700 series "$model" "$@"
}

series_bg() {
  local -a drop=()
  local key
  while read -r key; do drop+=(-u "R9700_$key"); done < <(config_keys | awk '{ print $2 }')
  ( exec env "${drop[@]}" "$REPO/bin/r9700" series "$SERIES_MODEL" "$@" ) > "$CASE/sup.out" 2> "$CASE/sup.err" &
  SUP=$!
  guard_pid "$SUP" "supervisor-$SUP"
}

outdir() { printf '%s/%s\n' "$R9700_RESULTS_DIR" "${1:-s}"; }

starts() { awk '$3 == "wslc" && $4 == "run" && $5 == "-d" { for (i = 6; i <= NF; i++) if ($i == "--name" && $(i + 1) != "vllm") { print $(i + 1); break } }' "$STUB/calls.log"; }

prod_stops() { awk '$3 == "wslc" && $4 == "stop" && $5 == "vllm" { n++ } END { print n + 0 }' "$STUB/calls.log"; }

calls_since() { tail -n +"$(($1 + 1))" "$STUB/calls.log"; }

json_get() { python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2"; }

short_variant() { step_cfg MAX_RUN_MINUTES=11 CLEANUP_BUDGET_S=425 READY_TIMEOUT_S=60; export R9700_TIME_SCALE=25; }

# build_fixture_outdir <dir>: every line of the recorded bench file goes to rounds/<its own tag>/bench.txt in file order (the tags are read from
# the lines, never typed), the fingerprint is written with the base fbase, the arms fbase fcombo fb1, 3 rounds and the prefill lengths 8192 32768,
# and the quality files of the S1 fixture go to quality/
build_fixture_outdir() {
  local dir="$1" tag
  mkdir -p "$dir/rounds" "$dir/quality"
  while read -r tag; do mkdir -p "$dir/rounds/$tag"; done < <(awk '{ print $1 }' "$BENCH_FIXTURE" | sort -u)
  awk -v dir="$dir" '{ print >> (dir "/rounds/" $1 "/bench.txt") }' "$BENCH_FIXTURE"
  python3 - "$dir/fingerprint.json" <<'EOF'
import hashlib, json, sys
arm = {"args": [], "env": [], "mounts": []}
components = {"base": "fbase", "rounds": 3, "arms": {"fbase": arm, "fcombo": arm, "fb1": arm}, "workload": {"prefill": {"lens": [8192, 32768]}}}
sha = hashlib.sha256(json.dumps(components, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()).hexdigest()  # a document is read only with its true digest
json.dump({"version": 1, "sha256": sha, "components": components}, open(sys.argv[1], "w"))
EOF
  cp "$HERE/fixtures/ship_test/quality/gsm8k_fbase.json" "$HERE/fixtures/ship_test/quality/gsm8k_fcombo.json" "$HERE/fixtures/ship_test/quality/gsm8k_fb1.json" "$dir/quality/"
}

# lose_server_after <container> <n>: in the background, waits (bounded, 30 s) until the call log shows <n> `bench serve` calls on the container,
# then kills the container's process: the server is lost in the middle of the bench. Needs R9700_STUB_DELAY_S so the call is still running.
lose_server_after() {
  (
    local i
    for i in $(seq 1 600); do
      [ "$(grep -c " wslc exec $1 vllm bench serve " "$STUB/calls.log" 2> /dev/null)" -ge "$2" ] && break
      sleep 0.05
    done
    kill -KILL "$(pid_of "$1")" 2> /dev/null
  ) &
  guard_pid "$!" "killer-$!"
}
