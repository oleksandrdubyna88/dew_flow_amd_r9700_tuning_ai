#!/usr/bin/env bash
# Shared by tests/test_moe.sh (E2.S2): "a stub chunk", "a stub A/B", the hook scenarios and the helpers that read what they left. Sourced after
# tests/lib/stepcase.sh; no t_ function in it.
#
#   moe_setup <name> [<model file>]  step_setup, the operator's server running, the placed files (benchmark_moe.py, the candidates), the exchange
#                                    folder, and the stub answers of a chunk of key 24 (chunk_json_for b2 24); sets MODEL (the 35B file), MOE_MODEL
#                                    (its name), RECS (the record folder, `OUT` is the assert library's), EX (the exchange folder) and WORK (the placed-files folder)
#   chunk_json_for <b1|b2> <keys...> answers/moe_json/<the fixture's own file name>: a chunk file built from a merged fixture for those keys
#   moe_chunk <chunk> <layer> <search> <keys...>   `bin/r9700 step ... -- bash lib/moe.sh chunk ...` as a user runs it
#   moe_ab <layer> <rule> "<rule keys>" <reps> "<keys>"   the same for `ab`
#   moe_ab_answers <b folder> <b file> [<b1|b2>]   per-rep stub logs from a fixture A/B folder, the tuned one with its `Using configuration` line
#                                    pointing at <b folder>/<b file>
#   moe_merged_place <b1|b2>         copies the fixture's merged file into the exchange folder's merged/
#   moe_sup_bg <body function> [<KEY=VALUE>...]   `supervise moe prepare_run <body>` with the cleanup hook registered, in the background as a user's
#                                    verb would run it (SUP, then step_end); the body is a function the child gets by `declare -f`
#   body_chunk / body_two_chunks / body_nothing   bodies for moe_sup_bg
#   prod_stops                       how many times the operator's server was stopped
#   last_run_dir / worker_log <n> / sup_log      the newest run folder, its worker log of step <n>, its supervisor log
#   run_lines <name>                 the call-log line numbers of `wslc run --rm --name <prefix><name>`
#   line_of <regex>                  the number of the first call-log line matching
#   run_argv <name>                  ARGV: the argument array of the last `wslc run --rm --name <prefix><name>` call
#   env_get <file> <KEY>             the value of a KEY=value line (one pair of double quotes removed)
#   body_args <word>...              the words the body_chunk body hands to `moe.sh chunk` after the outdir and the model
#   ram_stop_run                     a chunk that sleeps; once its container is listed the RAM answer drops: the RAM guard stops the step (SRC, SOUT, SERR)
#   last_stamp_of <regex> / last_line_of <regex>   the epoch stamp and the number of the LAST call-log line matching
#   hung_alive                       the pids recorded in hung/containers that are still the same live processes
#   unhang_all                       kills every process recorded in hung/containers (a test that left a hung stub behind)

# shellcheck source=tests/lib/stepcase.sh
source "$HERE/lib/stepcase.sh"
# shellcheck source=lib/moe.sh
source "$REPO/lib/moe.sh"

MOE_FIXTURES="$HERE/fixtures/moe"

moe_setup() {
  step_setup "$1" "${2:-$MODEL_35B}"
  prod_running
  MODEL="${2:-$MODEL_35B}"
  MOE_MODEL="$(basename "$MODEL" .env)"
  RECS="$R9700_RESULTS_DIR/moe-$MOE_MODEL"
  WORK="$R9700_WORK_DIR/r9700"
  EX="$WORK/moe/$MOE_MODEL"
  mkdir -p "$EX/tune"
  cp "$REPO/vendor/benchmark_moe.py" "$WORK/benchmark_moe.py"
  cp "$REPO/config/coarse_candidates.json" "$WORK/coarse_candidates.json"
  chunk_json_for b2 24
}

chunk_json_for() {
  local fixture="$MOE_FIXTURES/$1" file
  shift
  file="$(ls "$fixture"/E=*.json)"
  rm -rf "$STUB/answers/moe_json"
  mkdir -p "$STUB/answers/moe_json"
  python3 - "$file" "$STUB/answers/moe_json/$(basename "$file")" "$@" << 'EOF'
import json, sys
src, dest, keys = sys.argv[1], sys.argv[2], sys.argv[3:]
data = json.load(open(src))
json.dump({"triton_version": data["triton_version"], **{k: data[k] for k in keys}}, open(dest, "w"), indent=4)
EOF
}

moe_chunk() { r9700 step --model "$MODEL" moe-chunk -- bash "$REPO/lib/moe.sh" chunk "$RECS" "$MOE_MODEL" "$@"; }

moe_ab() { r9700 step --model "$MODEL" moe-ab -- bash "$REPO/lib/moe.sh" ab "$RECS" "$MOE_MODEL" "$@"; }

moe_ab_answers() {
  local bfolder="$1" bfile="$2" fixture="$MOE_FIXTURES/${3:-b1}_ab" rep
  for rep in 1 2 3; do
    cp "$fixture/default-$rep.log" "$STUB/answers/moe_ab.default.$rep"
    sed "s|Using configuration from [^ ]* for MoE layer|Using configuration from $bfolder/$bfile for MoE layer|" "$fixture/tuned-$rep.log" > "$STUB/answers/moe_ab.tuned.$rep"
  done
}

# moe_merged_place <b1|b2>: the fixture's merged file in the exchange folder AS `activate` leaves it: the file and an activate.env that names it and its layer
# (b1 is the draft layer's file, b2 the experts layer's)
moe_merged_place() {
  local file layer=experts
  [ "$1" = b1 ] && layer=draft
  mkdir -p "$EX/merged"
  cp "$MOE_FIXTURES/$1"/E=*.json "$EX/merged/"
  file="$(basename "$(ls "$MOE_FIXTURES/$1"/E=*.json)")"
  printf 'STAMP=hand\nNAME=%s\nLAYER=%s\nSHA256=%s\nPREVIOUS=none\nACTIVATED_AT=2026-11-02T00:00:00Z\nFORCED=no\n' "$file" "$layer" "$(sha256sum "$EX/merged/$file" | cut -d' ' -f1)" > "$EX/merged/activate.env"
}

# the bodies of moe_sup_bg: they read their words from the environment of the child (MOE_BODY_ARGS holds one word per line)
body_chunk() {
  local -a words
  mapfile -t words <<< "$MOE_BODY_ARGS"
  step_run moe-chunk -- bash "$REPO/lib/moe.sh" chunk "$MOE_OUT" "$MOE_MODEL_NAME" "${words[@]}"
}

body_two_chunks() {
  step_run moe-chunk -- bash "$REPO/lib/moe.sh" chunk "$MOE_OUT" "$MOE_MODEL_NAME" a24 experts full 24 || return $?
  step_run moe-chunk -- bash "$REPO/lib/moe.sh" chunk "$MOE_OUT" "$MOE_MODEL_NAME" b24 experts full 24
}

body_nothing() { echo "nothing to do"; return 0; }

moe_sup_bg() {
  local body="$1" word
  local -a drop=()
  shift
  while read -r word; do drop+=(-u "R9700_$word"); done < <(config_keys | awk '{ print $2 }')
  ( exec env "${drop[@]}" MOE_OUT="$RECS" MOE_MODEL_NAME="$MOE_MODEL" MOE_BODY_ARGS="${MOE_BODY_ARGS-}" "$@" bash -c "
    source \"$REPO/bin/r9700\"; source \"$REPO/lib/moe.sh\"
    REPO=\"$REPO\"
    $(declare -f "$body")
    _R9700_MODEL_ARG=\"$MODEL\"
    cleanup_hook_set moe_cache_clear
    supervise moe prepare_run $body
    exit \$?" ) > "$CASE/sup.out" 2> "$CASE/sup.err" &
  SUP=$!
  guard_pid "$SUP" "supervisor-$SUP"
}

prod_stops() { awk '$3 == "wslc" && $4 == "stop" && $5 == "vllm" { n++ } END { print n + 0 }' "$STUB/calls.log"; }

body_args() { local IFS=$'\n'; MOE_BODY_ARGS="$*"; export MOE_BODY_ARGS; }

ram_stop_run() {
  printf '100\n' > "$STUB/answers/moe_tune_seconds"
  printf '8000\n' > "$STUB/answers/ram"
  body_args int4-24 experts full 24
  moe_sup_bg body_chunk
  wait_for "$STUB/containers/${R9700_CONTAINER_PREFIX}moe-tune-int4-24.pid" 100
  append_answer ram 100 # the guard's next read is below the limit: only now, so that it never fires before the container exists
  step_end
}

last_stamp_of() { awk -v re="$1" '$0 ~ re { s = $1 } END { print s }' "$STUB/calls.log"; }

last_line_of() { grep -n -E "$1" "$STUB/calls.log" | tail -n 1 | cut -d: -f1; }

hung_alive() {
  local file pid ticks
  for file in "$STUB"/hung/containers/*.pid; do
    [ -f "$file" ] || continue
    read -r pid ticks < "$file"
    [ "$(_start_ticks "$pid")" = "$ticks" ] && echo "$pid"
  done
  return 0
}

last_run_dir() { ls -d "$R9700_RESULTS_DIR"/runs/*/ 2> /dev/null | sort | tail -n 1 | sed 's|/$||'; }

worker_log() { cat "$(last_run_dir)/steps/$1.worker.log"; }

sup_log() { cat "$(last_run_dir)/supervisor.log"; }

run_lines() { grep -n " wslc run --rm --name ${R9700_CONTAINER_PREFIX}$1 " "$STUB/calls.log" | cut -d: -f1; }

line_of() { grep -n -E -m 1 "$1" "$STUB/calls.log" | cut -d: -f1; }

run_argv() {
  local want="${R9700_CONTAINER_PREFIX}$1" line in=0 cur=() hit=()
  ARGV=()
  while IFS= read -r line; do
    if [[ $line == '@@ '* ]]; then
      cur=()
      in=1
    elif [ -z "$line" ]; then
      if [ "${#cur[@]}" -ge 4 ] && [ "${cur[0]}" = run ] && [ "${cur[1]}" = --rm ] && [ "${cur[2]}" = --name ] && [ "${cur[3]}" = "$want" ]; then hit=("${cur[@]}"); fi
      in=0
    elif [ "$in" = 1 ]; then
      cur+=("$line")
    fi
  done < "$STUB/calls.argv"
  ARGV=("${hit[@]}")
}

env_get() {
  local value
  value="$(sed -n "s/^$2=//p" "$1" | head -n 1)"
  if [[ $value == \"*\" ]]; then value="${value#\"}"; value="${value%\"}"; fi
  printf '%s\n' "$value"
}

unhang_all() {
  local file pid _t
  for file in "$STUB"/hung/containers/*.pid; do
    [ -f "$file" ] || continue
    read -r pid _t < "$file"
    kill -KILL "$pid" 2> /dev/null
  done
}
