#!/usr/bin/env bash
# Shared by tests/test_comfy_bench_verb*.sh and tests/test_comfy_bench_verdict.sh (E2.S3): the stub world of the VERB `bin/r9700 comfy bench` and of `bin/r9700 verdict` over a bench folder. Sourced after
# tests/lib/assert.sh, stubcase.sh and lifecycle.sh; no t_ function in it. It builds on tests/lib/benchcase.sh (the stub bench of the worker, E2.S2): the worker's own cases run the worker as a step, these
# run the verb, which places bench.py, builds the identity and starts the worker itself.
#
#   bv_setup <name>        bench_world (the operator's server running, the three volumes, the real arm and evidence tables: R9700_COMFY_ARMS_CONF and R9700_COMFY_EVIDENCE_CONF unset), the outdir OUTD
#                          the verb names by default (<RESULTS_DIR>/comfy-zimage), and BV_CALLS0, the number of `wslc` calls the setup left
#   bv <args...>           `bin/r9700 comfy bench <args...>` as a user runs it (the config variables of this test shell are not handed on)
#   bv_bg <args...>        the same in the background (SUP; output in $CASE/sup.out and $CASE/sup.err); bv_end [<s>] waits for it (SRC, SOUT, SERR)
#   bv_untouched           0 when nothing happened: no lock file was made and no `wslc` call was logged since bv_setup (wslc_calls of tests/lib/comfycase.sh counts them)
#   bv_refuse <name> <text> <args...>   the verb is refused: exit 2, exactly one stderr line that contains <text>, and nothing happened
#   bv_no_runs             0 when no run folder was made under RESULTS_DIR/runs
#   bv_stops <name>        how many `wslc stop <name>` calls the call log holds
#   bv_clears              how many bench-cache clear containers (`comfy-clear-`) the call log shows (the bench containers are bench_names of tests/lib/benchcase.sh)
#   vd_fold <outdir> <workflow> <rounds> <arm>...   a bench FOLDER built by the test: the identity through comfy_bench_check and comfy_bench_fingerprint (the verb's calls), no arm-round yet
#   vd_round <outdir> <arm> <round> <total_s of run 1>   rounds/<arm>-<round>/bench.txt in S1's grammar for zimage (run k adds 0.1 to the total; the sampler is 80 %, the vae 1.500)

# shellcheck source=tests/lib/benchcase.sh
source "$HERE/lib/benchcase.sh"

bv_setup() {
  bench_world "$1"
  OUTD="$R9700_RESULTS_DIR/comfy-zimage"
  BV_CALLS0="$(wslc_calls)"
  unset R9700_COMFY_ARMS_CONF R9700_COMFY_EVIDENCE_CONF
}

bv() { comfy bench "$@"; }

bv_bg() { comfy_bg bench "$@"; }

bv_end() { comfy_end "$@"; }

bv_untouched() {
  [ ! -e "$R9700_STATE_DIR/lock" ] || { echo "the lock file was made" >&2; return 1; }
  [ "$(wslc_calls)" = "$BV_CALLS0" ] || { echo "a wslc call was logged" >&2; return 1; }
}

bv_refuse() {
  local name="$1" text="$2"
  shift 2
  assert_exit 2 "$name: refused" -- bv "$@"
  assert_contains "$ERR" "$text" "$name: the line says it"
  assert_eq "1" "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "$name: exactly one stderr line"
  assert_exit 0 "$name: nothing happened" -- bv_untouched
}

bv_no_runs() { [ -z "$(ls -A "$R9700_RESULTS_DIR/runs" 2> /dev/null)" ]; }

bv_stops() { awk -v n="$1" '$3 == "wslc" && $4 == "stop" && $5 == n { c++ } END { print c + 0 }' "$STUB/calls.log"; }

bv_clears() { grep -cE ' wslc run --rm --name r9700tune-comfy-clear-[0-9]+ ' "$STUB/calls.log"; }

vd_fold() {
  local outdir="$1"
  shift
  OUTD="$outdir"
  RUN_DIR="${RUN_DIR:-$CASE/fprun}"
  mkdir -p "$RUN_DIR"
  local _MOE_PLACED_BY=comfy
  moe_place comfy_bench_assets
  bench_fp "$@" > "$CASE/fold.out" 2> "$CASE/fold.err" || { echo "vd_fold: the identity was refused: $(cat "$CASE/fold.err")" >&2; return 1; }
}

vd_round() {
  local dir="$1/rounds/$2-$3" run total
  mkdir -p "$dir"
  : > "$dir/bench.txt"
  for run in 1 2 3; do
    total="$(awk -v t="$4" -v r="$run" 'BEGIN { printf "%.3f", t + (r - 1) * 0.1 }')"
    printf '%s-%s zimage r=%s total_s: %s\n' "$2" "$3" "$run" "$total" >> "$dir/bench.txt"
    printf '%s-%s zimage r=%s sampler_s: %s\n' "$2" "$3" "$run" "$(awk -v t="$total" 'BEGIN { printf "%.3f", t * 0.8 }')" >> "$dir/bench.txt"
    printf '%s-%s zimage r=%s vae_s: 1.500\n' "$2" "$3" "$run" >> "$dir/bench.txt"
  done
  printf 'ARM=%s\nROUND=%s\nINERT=no\n' "$2" "$3" > "$dir/record.env"
}
