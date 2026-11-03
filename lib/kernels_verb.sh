#!/usr/bin/env bash
# lib/kernels_verb.sh — the supervisor's half of `bin/r9700 linear-bench` and `bin/r9700 prefixtest` (E3.S1): the argument grammar, the checks with the config, the two
# bodies of `supervise` and the dry runs. SOURCED by bin/r9700 after lib/kernels.sh (the units live there and run as workers). Bash >= 4.4, `set -u` safe, no
# `set -e`. Nothing here takes the lock or sets a trap: the lock, the restore-first and the one cleanup belong to `supervise`.
#
#   kernels_args <linear-bench|prefixtest> <args...>   the SYNTAX of a command line, before the lock; sets _KERN_VERB, _R9700_MODEL_ARG, _KERN_MODEL, _KERN_NAME,
#                                                      _KERN_OUT, _KERN_MS, _KERN_SWEEP, _KERN_TIMER, _KERN_ARM, _KERN_LENS, _KERN_TAIL, _KERN_DRY; 2 and one line
#   kernels_prepare                                    after the restore-first: the model and machine config, the field and arm checks, the container labels
#   kernels_linear_body / kernels_prefix_body          the bodies of `supervise`: the placement, the dry run, the same-experiment check and the recorded count (before
#                                                      admission), then ONE step_run
#
# A record is named: `--name` (default the UTC stamp: a new record every run). With a name, a final record of that name is "recorded, nothing to do" — but only when it is
# the same experiment (decision 6): its env file is compared key by key with the request, and a difference is refused (exit 2) before anything is stopped.

_KERN_STAMP_FMT='%Y%m%dt%H%M%Sz' # lower-case, 16 characters: fits _KERN_NAME_RE

_kern_err() { echo "r9700: $_KERN_VERB: $*" >&2; }

# _kern_opt_list <verb>: the legal options
_kern_opt_list() {
  case $1 in
    linear-bench) echo "--name, --ms, --sweep-ms, --timer, --out, --dry-run" ;;
    prefixtest) echo "--name, --arm, --lens, --tail, --out, --dry-run" ;;
  esac
}

# _kern_set_opt <option> <value>
_kern_set_opt() {
  case $1 in
    --name) _KERN_NAME="$2" ;;
    --out) _KERN_OUT="$2" ;;
    --ms) _KERN_MS="$2" ;;
    --sweep-ms) _KERN_SWEEP="$2" ;;
    --timer) _KERN_TIMER="$2" ;;
    --arm) _KERN_ARM="$2" ;;
    --lens) _KERN_LENS="$2" ;;
    --tail) _KERN_TAIL="$2" ;;
    --dry-run) _KERN_DRY=yes ;;
  esac
}

# _kern_ints <option> <value>: 2 and one line unless the value is distinct positive integers (the config's own check, _cfg_ints_problem)
_kern_ints() {
  _cfg_ints_problem "$2" || { _kern_err "$1 $_PE"; return 2; }
}

_kern_args_linear() {
  local m
  case $_KERN_TIMER in graph | eager) ;; *) _kern_err "--timer \"$_KERN_TIMER\" is not one of: graph eager"; return 2 ;; esac
  _kern_ints --ms "$_KERN_MS" || return 2
  _kern_ints --sweep-ms "$_KERN_SWEEP" || return 2
  for m in $_KERN_SWEEP; do
    [[ " $_KERN_MS " == *" $m "* ]] || { _kern_err "sweep M $m is not in --ms \"$_KERN_MS\""; return 2; }
  done
}

_kern_args_prefix() {
  local shortest
  [[ $_KERN_ARM =~ $_RE_ARM ]] || { _kern_err "--arm \"$_KERN_ARM\" is not an arm name (lower-case letters and digits only)"; return 2; }
  _kern_ints --lens "$_KERN_LENS" || return 2
  [[ $_KERN_TAIL =~ ^[1-9][0-9]{0,8}$ ]] || { _kern_err "--tail \"$_KERN_TAIL\" is not a positive whole number"; return 2; }
  shortest="$(printf '%s\n' $_KERN_LENS | sort -n | head -n 1)"
  [ "$_KERN_TAIL" -lt "$shortest" ] || { _kern_err "--tail $_KERN_TAIL is not below the shortest length $shortest"; return 2; }
}

# kernels_args <verb> <args...>
kernels_args() {
  local opt
  local -a pos=()
  _KERN_VERB="$1"
  shift
  _R9700_MODEL_ARG="" _KERN_NAME="" _KERN_OUT="" _KERN_DRY=no
  _KERN_MS="$_KERN_DEFAULT_MS" _KERN_SWEEP="$_KERN_DEFAULT_SWEEP" _KERN_TIMER="$_KERN_DEFAULT_TIMER"
  _KERN_ARM=base _KERN_LENS="$_KERN_DEFAULT_LENS" _KERN_TAIL="$_KERN_DEFAULT_TAIL"
  while [ "$#" -gt 0 ]; do
    case $1 in
      -*)
        [[ ", $(_kern_opt_list "$_KERN_VERB")," == *", $1,"* ]] || { _kern_err "unknown option \"$1\"; legal: $(_kern_opt_list "$_KERN_VERB")"; return 2; }
        opt="$1"
        if [ "$opt" = --dry-run ]; then _kern_set_opt "$opt" yes; shift; continue; fi
        [ "$#" -ge 2 ] || { _kern_err "$opt needs a value"; return 2; }
        _kern_set_opt "$opt" "$2"
        shift 2
        ;;
      *) pos+=("$1"); shift ;;
    esac
  done
  [ "${#pos[@]}" -ge 1 ] || { echo "r9700: $_KERN_VERB: usage: $_KERN_VERB <model file or name> [options]; legal options: $(_kern_opt_list "$_KERN_VERB")" >&2; return 2; }
  [ "${#pos[@]}" -eq 1 ] || { _kern_err "unexpected argument \"${pos[1]}\""; return 2; }
  _R9700_MODEL_ARG="${pos[0]}"
  _KERN_MODEL="${_R9700_MODEL_ARG##*/}"
  _KERN_MODEL="${_KERN_MODEL%.env}"
  [[ $_KERN_MODEL =~ $_MOE_MODEL_RE ]] || { _kern_err "the model name \"$_KERN_MODEL\" is not $_MOE_MODEL_RE"; return 2; }
  [ -n "$_KERN_OUT" ] || _KERN_OUT="kernels-$_KERN_MODEL" # no date: a --name resumes on another day
  [[ $_KERN_OUT =~ $_MOE_NAME_RE ]] || { _kern_err "--out \"$_KERN_OUT\" is not a name ($_MOE_NAME_RE)"; return 2; }
  [ -n "$_KERN_NAME" ] || _KERN_NAME="$(date -u +"$_KERN_STAMP_FMT" 9>&-)"
  [[ $_KERN_NAME =~ $_KERN_NAME_RE ]] || { _kern_err "--name \"$_KERN_NAME\" is not $_KERN_NAME_RE"; return 2; }
  if [ "$_KERN_VERB" = linear-bench ]; then _kern_args_linear; else _kern_args_prefix; fi
}

# _kern_lens_fit: every length plus one output token fits MAX_MODEL_LEN
_kern_lens_fit() {
  local len
  for len in $_KERN_LENS; do
    [ $((len + 1)) -le "$R9700_MAX_MODEL_LEN" ] || { _kern_err "$_KERN_MODEL: len $len + 1 > MAX_MODEL_LEN $R9700_MAX_MODEL_LEN"; return 2; }
  done
}

# kernels_prepare: what `supervise` calls after the restore-first; 2 and one line when a refusal. The files are placed later, in the body (as moe-tune does).
kernels_prepare() {
  prepare_run || return 2
  if [ "$_KERN_VERB" = linear-bench ]; then
    [ -n "$R9700_LINEAR_SHAPES" ] || { _kern_err "$_KERN_MODEL: LINEAR_SHAPES is empty: no shapes to time"; return 2; }
    container_name "linear-bench-99" > /dev/null || return 2
    return 0
  fi
  arms_load "$(series_arms_conf)" || return 2
  arms_check "$_KERN_ARM" || return 2
  container_name "prefix-$_KERN_ARM-99" > /dev/null || return 2
  _kern_lens_fit
}

# _kern_request_identity: the identity lines of the request (the identity words, then the asset hashes as the placed files now are)
_kern_request_identity() {
  if [ "$_KERN_VERB" = linear-bench ]; then kernels_identity linear "$_KERN_MODEL" "$_KERN_MS" "$_KERN_SWEEP" "$_KERN_TIMER" "$_KERN_NAME"
  else kernels_identity prefix "$_KERN_MODEL" "$_KERN_ARM" "$_KERN_LENS" "$_KERN_TAIL"; fi
  moe_asset_hashes kernels_assets
}

# _kern_same_experiment <linear|prefix> <outdir>: 0 when no record of the name exists or it is the same experiment; else 2 with one line per differing key
_kern_same_experiment() {
  local kind="$1" env="$2/$1/$_KERN_NAME/$1.env" diff line
  [ -d "$2/$kind/$_KERN_NAME" ] || return 0
  [ -f "$env" ] || { _kern_err "the record $kind/$_KERN_NAME holds no $kind.env: use another --name"; return 2; }
  diff="$(kernels_record_diff "$env" "$(_kern_request_identity)")" && return 0
  while IFS= read -r line; do
    _kern_err "the record $kind/$_KERN_NAME is another experiment: $line; use another --name"
  done <<< "$diff"
  return 2
}

# ---------- the dry runs ----------
_kern_dry_linear() {
  local -a argv=()
  kernels_linear_argv argv "$(container_name linear-bench-1)" "$_KERN_NAME" "$_KERN_TIMER" "$_KERN_MS" "$_KERN_SWEEP" || return 2
  echo "dry-run: $(wslc_argv_text run --rm "${argv[@]}")"
  _moe_dry_clear
}

_kern_dry_prefix() {
  local sname
  local -a envs=() mounts=() sargs=() exec_words=()
  sname="$(container_name "prefix-$_KERN_ARM-1")" || return 2
  _series_serve_options envs mounts sargs "$_KERN_ARM"
  echo "dry-run: $(serve_start --print "$sname" /dev/null "${envs[@]}" "${mounts[@]}" -- "${sargs[@]}")"
  kernels_prefix_exec_words exec_words "$_KERN_NAME" "$_KERN_LENS" "$_KERN_TAIL"
  echo "dry-run: $(wslc_argv_text exec "$sname" "${exec_words[@]}")"
  echo "dry-run: $(wslc_argv_text stop "$sname")"
}

# ---------- the bodies ----------
# _kern_body <linear|prefix>: the shared order. The files are placed (hash-checked, before anything is stopped), the dry run, the same-experiment check and the count of a
# recorded name (before admission: nothing is stopped for a record that is done), then ONE step_run; a done step prints its record and its summary.
_kern_body() {
  local kind="$1" outdir="$R9700_RESULTS_DIR/$_KERN_OUT" dest
  local _MOE_PLACED_BY="$_KERN_VERB" # local: it names the verb in a placement refusal and must not leak to a later step of a chain
  local -a worker=()
  echo "kernels: outdir $outdir"
  moe_place kernels_assets || return 2
  if [ "$_KERN_DRY" = yes ]; then
    if [ "$kind" = linear ]; then _kern_dry_linear; else _kern_dry_prefix; fi
    return $?
  fi
  _kern_same_experiment "$kind" "$outdir" || return 2
  dest="$outdir/$kind/$_KERN_NAME"
  if [ -d "$dest" ]; then echo "recorded $kind/$_KERN_NAME, nothing to do"; return 0; fi
  if [ "$kind" = linear ]; then
    worker=(linear "$outdir" "$_KERN_MODEL" "$_KERN_NAME" "$_KERN_TIMER" "$_KERN_MS" "$_KERN_SWEEP")
    cleanup_hook_set moe_cache_clear || return 2 # the ONE hook: it clears every Triton tuning cache the toolkit fills
  else
    worker=(prefix "$outdir" "$_KERN_MODEL" "$_KERN_NAME" "$_KERN_ARM" "$_KERN_LENS" "$_KERN_TAIL")
  fi
  step_run "$_KERN_VERB" -- bash "$R9700_ROOT/lib/kernels.sh" "${worker[@]}" || return $?
  if [ -d "$dest" ]; then
    echo "recorded $kind/$_KERN_NAME"
    cat "$dest/summary.txt" 9>&-
  fi
}

kernels_linear_body() { _kern_body linear; }

kernels_prefix_body() { _kern_body prefix; }
