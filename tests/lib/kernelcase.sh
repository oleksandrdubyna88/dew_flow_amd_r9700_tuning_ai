#!/usr/bin/env bash
# Shared by tests/test_kernels.sh and tests/test_kernels_verb.sh (E3.S1): "a stub linear unit", "a stub prefix unit", the answers the stub gives them and the helpers
# that read what they left. Sourced after tests/lib/assert.sh, stubcase.sh and lifecycle.sh; no t_ function in it. It builds on tests/lib/moecase.sh (the E2.S2 helpers
# for a unit under `step`) and tests/lib/seriescase.sh (the short deadline, the lost server).
#
#   kernels_setup <name> [<model file>]  step_setup, the operator's server running, the two placed files, the stub answers of a linear unit for `1 2 6` with the sweep
#                                        `6`; sets MODEL, KMODEL (its name), RECS (<RESULTS_DIR>/kernels-<model>), WORK (the placed-files folder)
#   linear_answer <ms> <sweep> [<mode>]  answers/linear: the published fixture's rows for the CONFIG's shapes (the fixture's shape names replaced by the model's, in
#                                        order) and those Ms. Modes (a refused result): none | no-layers (row 0 without `layers`) | dup (a pair twice, the first
#                                        pair gone: the row count is right) | missing (the last pair gone) | extra (a pair for M 7)
#   klinear <name> <timer> "<ms>" "<sweep>"   `bin/r9700 step ... -- bash lib/kernels.sh linear ...` as a user runs it (label linear-bench)
#   kprefix <name> <arm> "<lens>" <tail>      the same for `prefix` (label prefixtest)
#   body_linear / body_prefix             bodies for moe_sup_bg (a named unit k1 / p1)
#   serve_argv <name>                     ARGV: the argument array of the last `wslc run ... --name <prefix><name>` call
#   exec_argv <name>                      ARGV: the last `wslc exec <prefix><name> ...` call that runs the prefix check
#   lose_prefix_server <container>        a killer: once the prefix check is running in the container, the container is killed
#   rejected_of <kind> <name>             the newest rejected/<kind>-<name>-<stamp> folder of RECS

# shellcheck source=tests/lib/moecase.sh
source "$HERE/lib/moecase.sh"
# shellcheck source=tests/lib/seriescase.sh
source "$HERE/lib/seriescase.sh"
# shellcheck source=lib/series.sh
source "$REPO/lib/series.sh"
# shellcheck source=lib/moe_verb.sh
source "$REPO/lib/moe_verb.sh"
# shellcheck source=lib/kernels.sh
source "$REPO/lib/kernels.sh"

KERNELS_FIXTURES="$HERE/fixtures/kernels"

kernels_setup() {
  step_setup "$1" "${2:-$MODEL_35B}"
  prod_running
  MODEL="${2:-$MODEL_35B}"
  KMODEL="$(basename "$MODEL" .env)"
  RECS="$R9700_RESULTS_DIR/kernels-$KMODEL"
  MOE_MODEL="$KMODEL"
  WORK="$R9700_WORK_DIR/r9700"
  mkdir -p "$WORK"
  cp "$REPO/lib/linear_bench.py" "$REPO/lib/prefixtest.py" "$WORK/"
  printf 'INFO (EngineCore) server line %s\n' 1 2 3 > "$STUB/answers/logs" # what `wslc logs` of the server prints: server.log must not be empty
  arms_load "$(series_arms_conf)" # the arm table in this shell too: the tests build the series' own serve line from it
  linear_answer "1 2 6" "6"
}

linear_answer() {
  python3 - "$KERNELS_FIXTURES/linear_bench_graph.json" "$STUB/answers/linear" "$1" "$2" "${3:-none}" "$R9700_LINEAR_SHAPES" << 'PYEND'
import json, sys
src, dest, ms, sweep, mode, shapes = sys.argv[1], sys.argv[2], [int(x) for x in sys.argv[3].split()], [int(x) for x in sys.argv[4].split()], sys.argv[5], sys.argv[6]
names = [word.split(":")[0] for word in shapes.split()]
fixture = json.load(open(src))
order = list(dict.fromkeys(row["shape"] for row in fixture))
assert len(order) == len(names), "the fixture and the model file have the same number of shapes"
rows = []
for name, old in zip(names, order):
    for m in ms:
        row = dict(next(r for r in fixture if r["shape"] == old and r["M"] == m))
        row["shape"] = name
        if m not in sweep:
            for key in ("tuned_us", "tuned_tile", "tuned_maxdiff"):
                row.pop(key, None)
        rows.append(row)
if mode == "no-layers":
    del rows[0]["layers"]
elif mode == "dup":
    rows[0] = dict(rows[1])  # (first shape, second M) now stands twice and (first shape, first M) is gone: as many rows as expected
elif mode == "missing":
    rows.pop()
elif mode == "extra":
    rows.append({**rows[0], "M": 7})
json.dump(rows, open(dest, "w"), indent=1)
PYEND
}

klinear() { r9700 step --model "$MODEL" linear-bench -- bash "$REPO/lib/kernels.sh" linear "$RECS" "$KMODEL" "$@"; }

kprefix() { r9700 step --model "$MODEL" prefixtest -- bash "$REPO/lib/kernels.sh" prefix "$RECS" "$KMODEL" "$@"; }

body_linear() { step_run linear-bench -- bash "$REPO/lib/kernels.sh" linear "$MOE_OUT" "$MOE_MODEL_NAME" k1 graph "1 2 6" "6"; }

body_prefix() { step_run prefixtest -- bash "$REPO/lib/kernels.sh" prefix "$MOE_OUT" "$MOE_MODEL_NAME" p1 base "8192 1024" 64; }

# _argv_of_call <first word> <container name>: ARGV of the LAST wslc call whose argv starts with the word and names the container (as the word after --name, or as the second word)
_argv_of_call() {
  local want="$1" name="$2" line in=0 cur=() hit=()
  ARGV=()
  while IFS= read -r line; do
    if [[ $line == '@@ '* ]]; then
      cur=()
      in=1
    elif [ -z "$line" ]; then
      if [ "${#cur[@]}" -ge 2 ] && [ "${cur[0]}" = "$want" ] && { [ "${cur[1]}" = "$name" ] || [[ " ${cur[*]} " == *" --name $name "* ]]; }; then hit=("${cur[@]}"); fi
      in=0
    elif [ "$in" = 1 ]; then
      cur+=("$line")
    fi
  done < "$STUB/calls.argv"
  ARGV=("${hit[@]}")
}

serve_argv() { _argv_of_call run "${R9700_CONTAINER_PREFIX}$1"; }

exec_argv() {
  local name="${R9700_CONTAINER_PREFIX}$1" line in=0 cur=() hit=()
  ARGV=()
  while IFS= read -r line; do
    if [[ $line == '@@ '* ]]; then
      cur=()
      in=1
    elif [ -z "$line" ]; then
      if [ "${#cur[@]}" -ge 4 ] && [ "${cur[0]}" = exec ] && [ "${cur[1]}" = "$name" ] && [[ ${cur[3]} == */prefixtest.py ]]; then hit=("${cur[@]}"); fi
      in=0
    elif [ "$in" = 1 ]; then
      cur+=("$line")
    fi
  done < "$STUB/calls.argv"
  ARGV=("${hit[@]}")
}

lose_prefix_server() {
  (
    local i
    for i in $(seq 1 600); do
      grep -q " wslc exec $1 python3 /work/r9700/prefixtest.py" "$STUB/calls.log" 2> /dev/null && break
      sleep 0.05
    done
    kill -KILL "$(pid_of "$1")" 2> /dev/null
  ) &
  guard_pid "$!" "killer-$!"
}

rejected_of() { ls -d "$RECS"/rejected/"$1-$2"-* 2> /dev/null | sort | tail -n 1; }
