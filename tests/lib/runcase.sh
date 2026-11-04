#!/usr/bin/env bash
# Shared by tests/test_run.sh (E3.S2): "a stub chain" — a plan of stub steps — and the helpers that read what it left. Sourced after tests/lib/assert.sh, stubcase.sh and
# lifecycle.sh; no t_ function in it. It builds on tests/lib/kernelcase.sh (the kernels steps and, through it, the series and the MoE helpers).
#
#   run_setup <name> [<model file>]   series_setup (the stub answers of a one-round series, the operator's server running), the kernels answers (a linear unit for `1 2 6`, sweep `6`);
#                                     sets MODEL, KMODEL (its name), RECS (<RESULTS_DIR>/kernels-<model>), SDIR (the series' outdir)
#   plan_write <name> <line>...       $CASE/<name>.plan with one step per argument; sets PLAN
#   plan_fixture <name>               a copy of tests/fixtures/plans/<name>.plan in $CASE (it is the operator's file: a test never edits the tracked one); sets PLAN
#   run_bg <args...>                  `bin/r9700 run <args...>` in the background as a user runs it (SUP, then run_end); the output is in $CASE/sup.*
#   run_end                           step_end under another name: SRC, SOUT, SERR
#   run_txt                           the run.txt of the newest run folder
#   run_state <k>                     "<state> <code>" of step k in that run.txt
#   run_inline_bg <plan> <function>...  `verb_run <plan>` in a background subshell of THIS shell after sourcing bin/r9700, with the named functions (defined by the test) put over the
#                                     verbs' own: a plan step can then be a stand-in worker (a test of the CHAIN, not of the verb); SUP, then run_end
#   run_inline <plan> <function>...   the same, waited for: SRC, SOUT, SERR

# shellcheck source=tests/lib/kernelcase.sh
source "$HERE/lib/kernelcase.sh"

PLAN_FIXTURES="$HERE/fixtures/plans"

run_setup() {
  series_setup "$1" "${2:-$MODEL_35B}"
  MODEL="${2:-$MODEL_35B}"
  KMODEL="$(basename "$MODEL" .env)"
  RECS="$R9700_RESULTS_DIR/kernels-$KMODEL"
  SDIR="$R9700_RESULTS_DIR/$KMODEL"
  MOE_MODEL="$KMODEL"
  WORK="$R9700_WORK_DIR/r9700"
  mkdir -p "$WORK"
  linear_answer "1 2 6" "6"
}

plan_write() {
  local name="$1"
  shift
  PLAN="$CASE/$name.plan"
  printf '%s\n' "$@" > "$PLAN"
}

plan_fixture() {
  PLAN="$CASE/$1.plan"
  cp "$PLAN_FIXTURES/$1.plan" "$PLAN"
}

run_bg() {
  local -a drop=()
  local key
  while read -r key; do drop+=(-u "R9700_$key"); done < <(config_keys | awk '{ print $2 }')
  ( exec env "${drop[@]}" "$REPO/bin/r9700" run "$@" ) > "$CASE/sup.out" 2> "$CASE/sup.err" &
  SUP=$!
  guard_pid "$SUP" "supervisor-$SUP"
}

run_end() { step_end "$@"; }

run_txt() { cat "$(last_run_dir)/run.txt"; }

run_state() { awk -v k="$1" '$1 == k { print $2, $3 }' "$(last_run_dir)/run.txt"; }

run_inline_bg() {
  local plan="$1" f defs=""
  shift
  for f in "$@"; do defs+="$(declare -f "$f")"$'\n'; done
  ( source "$REPO/bin/r9700"; eval "$defs"; verb_run "$plan" ) > "$CASE/sup.out" 2> "$CASE/sup.err" &
  SUP=$!
  guard_pid "$SUP" "supervisor-$SUP"
}

run_inline() {
  run_inline_bg "$@"
  step_end
}
