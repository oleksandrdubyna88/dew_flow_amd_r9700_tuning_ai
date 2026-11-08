#!/usr/bin/env bash
# lib/comfy_bench_verb.sh — the supervisor's half of `bin/r9700 comfy bench` (E2.S3 of the ComfyUI plan) and the verdict over a bench folder: the argument grammar, the checks with the machine
# config, the body of `supervise` and the dry run. SOURCED by bin/r9700 after lib/comfy_bench.sh (the arm-round is E2.S2's worker there, run as ONE step). Bash >= 4.4, `set -u` safe, no `set -e`.
# Nothing here takes the lock or sets a trap: the lock, the restore-first, the owner check of the card (E1: the operator's ComfyUI listed is exit 2, AFTER the lock, so a held lock is exit 4
# first) and the one cleanup belong to `supervise`.
#
#   comfy_bench_args <args...>        the SYNTAX of `comfy bench <workflow> <arm>... [--rounds N] [--out <name>] [--dry-run]`, before the lock; sets _CBV_WORKFLOW, _CBV_ARMS, _CBV_ROUNDS,
#                                     _CBV_OUT, _CBV_DRY; 2 and one line
#   comfy_mode_bench <args...>        the mode (lib/comfy.sh derives the legal modes from the functions `comfy_mode_<mode>`, so this file adds `bench` to them): `supervise comfy` around the two
#                                     functions below, the lock holder word `comfy` like start and build
#   comfy_bench_prepare               after the restore-first: the machine config ALONE (no model file: a bench needs none), then the seam's check (both tables, every arm in both, the labels)
#   comfy_bench_body                  the body: the placement, the dry run, the identity (built, or compared and merged: another experiment is refused here, before anything is stopped), the
#                                     count of what is left (before admission: nothing is stopped for a bench that is done), then ONE step_run of the worker
#   verdict_is_comfy <args...>        0 when the folder of a `verdict` command line holds a fingerprint of kind `comfy`; anything else (a series, a missing or an untrusted file) is 1
#   comfy_bench_verdict <args...>     `verdict` over a bench folder: the comfy ship test of lib/verdict.py with the options of the series verdict, minus the quality gate a bench does not have
#
# The arm `base` is the reference of every verdict and of the drift (the worker pairs an output with the base's round 1), and the identity of an experiment names it: every invocation lists it, and
# the grammar refuses one that does not, before the lock (the fingerprint refuses it too, as the second line of defence).
# Globals: this file's are `_CBV_*` and its functions `_cbv_*`; lib/comfy_bench.sh's worker keeps `_CB_*` and `_cb_*` (there `_CB_OUT` is the outdir PATH), and what the worker needs is handed to it as arguments.
# Messages: `r9700: comfy: bench: <text>` on stderr and `comfy: bench: <text>` on stdout (the helpers of lib/comfy.sh).

_CBV_USAGE="usage: bench <workflow> <arm>... [--rounds <1..20>] [--out <name>] [--dry-run]; the arm base must be one of the arms"
_CBV_ROUNDS_DEFAULT=3                     # three rounds: the least the ship test reads as a provisional, workload-specific claim (the parent plan, The tuning series)
_COMFY_BENCH_DIRECTION=lower             # every metric of a bench is seconds

_cbv_arg_err() { _comfy_err bench "$@"; }

# comfy_bench_args <args...>: (_SERIES_OUT_RE, the series' folder-name rule, and _RE_ARM, the arm-name rule, are defined by bin/r9700 and lib/config.sh before any verb runs.) The checks in the order of the series grammar: the options while reading, then the usage, the workflow (a whole line of the program's list), at least one arm, the
# rounds, each arm by the arm-name rule and once, the folder name (default comfy-<workflow>)
comfy_bench_args() {
  local arm legal
  _CBV_WORKFLOW="" _CBV_ARMS=() _CBV_ROUNDS="$_CBV_ROUNDS_DEFAULT" _CBV_OUT="" _CBV_DRY=no
  while [ "$#" -gt 0 ]; do
    case $1 in
      --out)
        [ "$#" -ge 2 ] || { _cbv_arg_err "--out needs a value"; return 2; }
        _CBV_OUT="$2"
        shift 2
        ;;
      --rounds)
        [ "$#" -ge 2 ] || { _cbv_arg_err "--rounds needs a value"; return 2; }
        _CBV_ROUNDS="$2"
        shift 2
        ;;
      --dry-run) _CBV_DRY=yes; shift ;;
      -*) _cbv_arg_err "unknown option \"$1\"; legal: --rounds <1..20>, --out <name>, --dry-run"; return 2 ;;
      *)
        if [ -z "$_CBV_WORKFLOW" ]; then _CBV_WORKFLOW="$1"; else _CBV_ARMS+=("$1"); fi
        shift
        ;;
    esac
  done
  if [ -z "$_CBV_WORKFLOW" ]; then _cbv_arg_err "$_CBV_USAGE"; return 2; fi
  legal="$(comfy_bench_workflows | tr '\n' ' ' | sed 's/ $//')"
  [[ " $legal " == *" $_CBV_WORKFLOW "* ]] || { _cbv_arg_err "unknown workflow \"$_CBV_WORKFLOW\"; legal: $legal"; return 2; }
  if [ "${#_CBV_ARMS[@]}" -eq 0 ]; then _cbv_arg_err "at least one arm is needed ($_CBV_USAGE)"; return 2; fi
  [[ $_CBV_ROUNDS =~ ^([1-9]|1[0-9]|20)$ ]] || { _cbv_arg_err "--rounds \"$_CBV_ROUNDS\" is not a whole number from 1 to 20"; return 2; }
  for arm in "${_CBV_ARMS[@]}"; do
    [[ $arm =~ $_RE_ARM ]] || { _cbv_arg_err "\"$arm\" is not an arm name (lower-case letters and digits only)"; return 2; }
    [ "$(printf '%s\n' "${_CBV_ARMS[@]}" | grep -cxF -- "$arm")" -eq 1 ] || { _cbv_arg_err "the arm \"$arm\" is given twice"; return 2; }
  done
  printf '%s\n' "${_CBV_ARMS[@]}" | grep -qx base || { _cbv_arg_err "the arm base must be one of the arms"; return 2; } # the reference of the verdict and of the drift: the identity names it
  [ -n "$_CBV_OUT" ] || _CBV_OUT="comfy-$_CBV_WORKFLOW" # no date: the same command continues on another day
  [[ $_CBV_OUT =~ $_SERIES_OUT_RE ]] || { _cbv_arg_err "--out \"$_CBV_OUT\" is not a name (letters, digits, . _ -; starting with a letter or digit; at most 64)"; return 2; }
}

# comfy_mode_bench <args...>: the arguments are checked before the lock; then `supervise` (lock, restore-first, prepare, the owner check, deadline, run folder, body, one cleanup)
comfy_mode_bench() {
  comfy_bench_args "$@" || return 2
  supervise comfy comfy_bench_prepare comfy_bench_body
}

# comfy_bench_prepare: what `supervise` calls after the restore-first. The machine config alone: the worker reads no model key (the end-to-end cases run with two model files in models/ and no --model).
comfy_bench_prepare() {
  config_load_machine "${R9700_MACHINE_ENV:-./machine.env}" || return 2
  comfy_bench_check "$_CBV_WORKFLOW" "$_CBV_ROUNDS" "${_CBV_ARMS[@]}" || return 2
}

# comfy_bench_body: the body of `supervise`. The order of the series and of the kernels: the placement (hash-checked, before anything is stopped), the dry run, the identity (a refused resume stops
# here), the count of what is left, then the worker as ONE step of the supervisor.
comfy_bench_body() {
  local outdir="$R9700_RESULTS_DIR/$_CBV_OUT" left recorded total rc
  local _MOE_PLACED_BY=comfy # local: it names the verb in a placement refusal and must not leak to a later step of a chain
  total=$((_CBV_ROUNDS * ${#_CBV_ARMS[@]}))
  _comfy_say bench "outdir $outdir"
  moe_place comfy_bench_assets || return 2
  if [ "$_CBV_DRY" = yes ]; then
    comfy_bench_fingerprint "$outdir" "$_CBV_WORKFLOW" "$_CBV_ROUNDS" dry "${_CBV_ARMS[@]}" || return 2
    comfy_bench_dry_run "$outdir" "$_CBV_WORKFLOW" "$_CBV_ROUNDS" "${_CBV_ARMS[@]}"
    return $?
  fi
  comfy_bench_fingerprint "$outdir" "$_CBV_WORKFLOW" "$_CBV_ROUNDS" real "${_CBV_ARMS[@]}" || return 2
  left="$(comfy_bench_left "$outdir" "$_CBV_ROUNDS" "${_CBV_ARMS[@]}")"
  if [ "$left" -eq 0 ]; then
    recorded="$(comfy_bench_recorded "$outdir" "$_CBV_ROUNDS" "${_CBV_ARMS[@]}")"
    _comfy_say bench "$recorded of $total arm-rounds recorded, nothing to do"
    return 0
  fi
  step_run comfy-bench -- bash "$R9700_ROOT/lib/comfy_bench.sh" "$outdir" "$_CBV_WORKFLOW" "$_CBV_ROUNDS" "${_CBV_ARMS[@]}"
  rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  recorded="$(comfy_bench_recorded "$outdir" "$_CBV_ROUNDS" "${_CBV_ARMS[@]}")"
  _comfy_say bench "$recorded of $total arm-rounds recorded; read them with bin/r9700 verdict $outdir"
}

# ---------- the verdict over a bench folder ----------
# _cbv_verdict_dir <args...>: the folder of a `verdict` command line: the first word that is not an option and not the value of --base or --json
_cbv_verdict_dir() {
  local arg skip=no
  for arg in "$@"; do
    if [ "$skip" = yes ]; then skip=no; continue; fi
    case $arg in
      --base | --json) skip=yes ;;
      -*) ;;
      *) printf '%s\n' "$arg"; return 0 ;;
    esac
  done
  return 1
}

# verdict_is_comfy <args...>: 0 when <folder>/fingerprint.json is a file and `fingerprint.py show <it> kind` prints exactly `comfy`. A series folder (no `kind` leaf), a missing file and a file whose
# digest does not match all go to series_verdict, which reports them as it does today (the fingerprint program's own line).
verdict_is_comfy() {
  local dir
  dir="$(_cbv_verdict_dir "$@")" || return 1
  [ -f "$dir/fingerprint.json" ] || return 1
  [ "$(python3 "$_CB_LIB/fingerprint.py" show "$dir/fingerprint.json" kind 2> /dev/null)" = comfy ]
}

# _cbv_words <word>...: the words as a command line a person can run again: a word that holds a blank is put in double quotes (the metrics: --metrics "total_s sampler_s vae_s")
_cbv_words() {
  local word
  for word in "$@"; do
    if [[ $word == *[[:space:]]* ]]; then printf ' "%s"' "$word"; else printf ' %s' "$word"; fi
  done
}

_cbv_fp() { python3 "$_CB_LIB/fingerprint.py" show "$1/fingerprint.json" "$2"; }

# _cbv_inert_notes <outdir> <workflow> <arm>...: one `note: <arm> inert on <workflow> (<evidence>)` line per arm whose round-1 record says INERT=yes (the parent plan: an arm that could not act on the
# workload is reported as inert with the evidence, never as no gain)
_cbv_inert_notes() {
  local outdir="$1" workflow="$2" arm record
  shift 2
  for arm in "$@"; do
    record="$outdir/rounds/$arm-1/record.env"
    [ -f "$record" ] && [ "$(sed -n 's/^INERT=//p' "$record" | head -n 1)" = yes ] || continue
    echo "note: $arm inert on $workflow ($(sed -n 's/^INERT_EVIDENCE=//p' "$record" | head -n 1))"
  done
}

# comfy_bench_verdict <outdir> [--base <arm>] [--json <file>]: the argument loop of series_verdict (--no-quality is refused: a bench has no quality gate), the head line, the one-round note, the inert
# arms, then lib/verdict.py comfy over the record files that exist
comfy_bench_verdict() {
  local outdir="" base="" json="" workflow rounds sha arm round metrics have_base=no
  local -a fp_arms=() judged=() bench=() cmd=()
  while [ "$#" -gt 0 ]; do
    case $1 in
      --base) [ "$#" -ge 2 ] || { echo "r9700: verdict: --base needs a value" >&2; return 2; }; base="$2"; shift 2 ;;
      --json) [ "$#" -ge 2 ] || { echo "r9700: verdict: --json needs a value" >&2; return 2; }; json="$2"; shift 2 ;;
      --no-quality) echo "r9700: verdict: --no-quality is for a series of vLLM arms; a comfy bench has no quality gate (its drift numbers are in each record)" >&2; return 2 ;;
      -*) echo "r9700: verdict: unknown option \"$1\"; legal: --base <arm>, --json <file>" >&2; return 2 ;;
      *) [ -z "$outdir" ] || { echo "r9700: verdict: one outdir only (\"$outdir\" and \"$1\")" >&2; return 2; }; outdir="$1"; shift ;;
    esac
  done
  workflow="$(_cbv_fp "$outdir" workflow)" || return 2
  [ -n "$base" ] || base="$(_cbv_fp "$outdir" base)" || return 2
  rounds="$(_cbv_fp "$outdir" rounds)" || return 2
  sha="$(_cbv_fp "$outdir" sha256)" || return 2
  mapfile -t fp_arms < <(_cbv_fp "$outdir" arms)
  echo "comfy bench $outdir: workflow $workflow, base $base, $rounds rounds, fingerprint ${sha:0:12}"
  [ "$rounds" -ne 1 ] || echo "note: 1 round, 3 values per arm; the ship test of a series uses 3 rounds"
  for arm in "${fp_arms[@]}"; do
    [ "$arm" = "$base" ] || judged+=("$arm")
    for ((round = 1; round <= rounds; round++)); do
      [ -f "$outdir/rounds/$arm-$round/bench.txt" ] || continue
      bench+=(--bench "$outdir/rounds/$arm-$round/bench.txt")
      [ "$arm" != "$base" ] || have_base=yes
    done
  done
  _cbv_inert_notes "$outdir" "$workflow" "${fp_arms[@]}"
  if [ "$have_base" = no ]; then echo "r9700: verdict: base arm \"$base\" has no complete arm-round in the inputs" >&2; return 2; fi
  if [ "${#judged[@]}" -eq 0 ]; then echo "verdict: no arm besides the base to judge"; return 0; fi
  metrics="$(comfy_bench_metrics)" || return 2
  cmd=(python3 "$_CB_LIB/verdict.py" comfy --workflow "$workflow" --metrics "$metrics" --decide "${metrics%% *}" --direction "$_COMFY_BENCH_DIRECTION" --base "$base")
  for arm in "${judged[@]}"; do cmd+=(--arm "$arm"); done
  cmd+=("${bench[@]}" --rounds "$rounds")
  [ -z "$json" ] || cmd+=(--json "$json")
  echo "invoking:$(_cbv_words "${cmd[@]}")"
  "${cmd[@]}"
}
