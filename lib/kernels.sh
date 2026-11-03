#!/usr/bin/env bash
# lib/kernels.sh — the linear-kernel micro-benchmark and the prefix-cache check as workers under the E1 supervisor (E3.S1). Bash >= 4.4, `set -u` safe, no
# `set -e`. Two faces, like lib/moe.sh: SOURCED, it defines functions (the verb half, lib/kernels_verb.sh, uses them); RUN as the worker,
# `bash lib/kernels.sh linear|prefix <args>...`, which `step_run` starts as ONE step. The worker sets no trap, takes no lock and never stops the operator's
# server: the supervisor owns all three. The placement, the identity check, the part-and-rename record, the cache clear and the stop-time rules are
# lib/moe.sh's and lib/moe_verb.sh's (imported, not copied: they take the name of the assets function).
#
#   bash lib/kernels.sh linear <outdir> <model> <name> <timer> "<ms>" "<sweep ms>"   one linear-bench unit (a foreground container)
#   bash lib/kernels.sh prefix <outdir> <model> <name> <arm> "<lens>" <tail>         one prefixtest unit (one measured server, one exec)
#
#   kernels_assets                   `<placed name> <repository source> <required|optional>` per line: linear_bench.py and prefixtest.py
#   kernels_exchange_dir <kind> <name>   $R9700_WORK_DIR/r9700/<kind>/<name>: the scratch folder the linear container writes its JSON to
#   kernels_linear_argv <array> <container name> <name> <timer> <ms> <sweep>   the words after `run --rm` of the linear container
#   kernels_prefix_exec_words <array> <name> <lens> <tail>                     the words after `exec <server>` of the prefix check
#   kernels_identity <linear|prefix> <model> <values...>                       the identity lines of a record's env file (also what a reused --name is compared with)
#   kernels_sweep_parts <outdir>     a part directory an earlier worker left is moved to rejected/ as INTERRUPTED evidence
#
# Records (E3.S1 decisions 4 and 7, the shape of lib/moe.sh): <outdir>/linear/<name>/ and <outdir>/prefix/<name>/ are final; while built they are
# <name>.part-<run id>/. A record becomes final by ONE rename after the validation (linear: RC=0, `linear_bench.py check` = every (shape, M) pair EXACTLY once, a
# tuned value at every sweep M; prefix: RC=0, the server still listed, `prefixtest.py check` = exactly one line per requested length). A failed validation moves
# the directory to rejected/<kind>-<name>-<UTC stamp>/ with a `reason`; nothing is ever deleted there. A server that does not become ready is stopped by name
# BEFORE the worker exits (a server a failed try leaves running is the ERROR_ALREADY_EXISTS of the next try, and the container the next step finds on the GPU).
#
# Exit codes: 0 done (recorded, or already recorded); 1 the unit failed (a rejected record, the disk gate: KIND=disk_gate, or the stop time came: KIND=deadline,
# and the part stays for the next start's sweep); 2 refused (KIND=refused when the identity check refuses; a bad argument is a plain 2 with one `kernels:` line).

_KERN_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_KERN_REPO="$(dirname "$_KERN_LIB")"
_KERN_NAME_RE='^[a-z0-9][a-z0-9-]{0,30}$' # the label linear-bench-<n> and prefix-<arm>-<n> must fit container_name's 40
_KERN_LINEAR_CEILING_S=5400               # speed_CB.sh line 16, night3.sh line 38: `timeout 5400`
_KERN_PREFIX_EXEC_S=1800                  # the ceiling of a bench run (lib/bench.sh)
_KERN_URL=http://127.0.0.1:8000
# the defaults of the verbs and of the programs (lib/linear_bench.py and lib/prefixtest.py hold the same figures; tests/test_kernels_verb.sh compares them)
_KERN_DEFAULT_MS="1 2 3 4 5 6 8 10 12 16"
_KERN_DEFAULT_SWEEP="6 8 12 16"
_KERN_DEFAULT_LENS="8192 1024"
_KERN_DEFAULT_TAIL=64
_KERN_DEFAULT_TIMER=graph

kernels_assets() {
  printf '%s\n' \
    "linear_bench.py lib/linear_bench.py required" \
    "prefixtest.py lib/prefixtest.py required"
}

# kernels_exchange_dir <linear|prefix> <name>: the host folder of /work/r9700/<kind>/<name> (the one translation, container_host_path)
kernels_exchange_dir() { container_host_path "$_MOE_CONTAINER_ROOT/$1/$2"; }

# kernels_linear_argv <array> <container name> <name> <timer> <ms> <sweep ms>: night3.sh lines 38-40 built from the config. Every word is one argv element (the shapes
# are ONE word with spaces in it).
kernels_linear_argv() {
  local -n _k_argv="$1"
  _k_argv=(
    --name "$2" --gpus all --shm-size 16g -e HIP_VISIBLE_DEVICES=0 -e "TRITON_CACHE_DIR=$_MOE_LINEAR_CACHE"
    -v "$R9700_CACHE_VOLUME:/root/.cache/vllm" -v "$R9700_WORK_DIR_WIN:/work"
    "$R9700_IMAGE" python3 "$_MOE_CONTAINER_ROOT/linear_bench.py" run --out "$_MOE_CONTAINER_ROOT/linear/$3/linear_bench.json"
    --shapes "$R9700_LINEAR_SHAPES" --group-size "$R9700_LINEAR_GROUP_SIZE" --ms "$5" --sweep-ms "$6" --timer "$4"
  )
}

# kernels_prefix_exec_words <array> <name> <lens> <tail>: speed_A.sh lines 76-78 (the tag is the record's name)
kernels_prefix_exec_words() {
  local -n _k_words="$1"
  _k_words=(python3 "$_MOE_CONTAINER_ROOT/prefixtest.py" run "$_KERN_URL" "$R9700_SERVED_NAME" "$2" --lens "$3" --tail "$4")
}

# _kern_arm_words <arm> <arm_args|arm_env|arm_mounts>: the words of an arm on one line
_kern_arm_words() { "$2" "$1" | tr '\n' ' ' | sed 's/ $//'; }

# kernels_identity linear <model> <ms> <sweep ms> <timer> <name> | prefix <model> <arm> <lens> <tail>: the identity lines (KEY=value) of a record. The same function
# writes the env file and answers "is the record of this name the same experiment" (decision 6), so the two can never disagree about a key.
kernels_identity() {
  local kind="$1" model="$2"
  _moe_env_line MODEL "$model"
  _moe_env_line IMAGE "$R9700_IMAGE"
  _moe_env_line MODEL_DIR "$R9700_MODEL_DIR"
  if [ "$kind" = linear ]; then
    _moe_env_line SHAPES "$R9700_LINEAR_SHAPES"
    _moe_env_line GROUP_SIZE "$R9700_LINEAR_GROUP_SIZE"
    _moe_env_line MS "$3"
    _moe_env_line SWEEP_MS "$4"
    _moe_env_line TIMER "$5"
    _moe_env_line LINEAR_ARGV "$(_kern_linear_line "$6" "$5" "$3" "$4")" # the whole container command: a field of machine.env or the model that changes it is another experiment
  else
    _moe_env_line ARM "$3"
    _moe_env_line ARM_ARGS "$(_kern_arm_words "$3" arm_args)"
    _moe_env_line ARM_ENV "$(_kern_arm_words "$3" arm_env)"
    _moe_env_line ARM_MOUNTS "$(_kern_arm_words "$3" arm_mounts)"
    _moe_env_line SERVED_NAME "$R9700_SERVED_NAME"
    _moe_env_line LENS "$4"
    _moe_env_line TAIL "$5"
    _moe_env_line SERVE_LINE "$(_kern_serve_line "$3")" # the whole start command: MAX_MODEL_LEN, EXTRA_SERVE_ARGS, MOUNTS, TUNED_CONFIG_DIR ... are in it
  fi
}

# _kern_linear_line <name> <timer> <ms> <sweep ms>: the linear container's command as text, with a fixed container name (the name of a try is not an experiment)
_kern_linear_line() {
  local -a argv=()
  kernels_linear_argv argv identity "$1" "$2" "$3" "$4"
  wslc_argv_text run --rm "${argv[@]}"
}

# _kern_serve_line <arm>: the arm's server start command as text (serve_start --print over the series' own option builder), with a fixed container name
_kern_serve_line() {
  local -a envs=() mounts=() sargs=()
  _series_serve_options envs mounts sargs "$1"
  serve_start --print identity /dev/null "${envs[@]}" "${mounts[@]}" -- "${sargs[@]}"
}

# _kern_unquote <value as written by _moe_env_line>
_kern_unquote() {
  local value="$1"
  if [[ $value == \"*\" ]]; then value="${value#\"}"; value="${value%\"}"; fi
  printf '%s' "$value"
}

# kernels_record_diff <env file of the record> <identity lines + hash lines of the request>: one `KEY "recorded" -> "requested"` line per differing key; 1 when any
kernels_record_diff() {
  local file="$1" line key want got n=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    key="${line%%=*}"
    want="${line#*=}"
    got="$(grep -m 1 "^$key=" "$file" 2> /dev/null | sed "s/^$key=//")"
    [ "$got" = "$want" ] && continue
    got="$(_kern_unquote "$got")"
    want="$(_kern_unquote "$want")"
    printf '%s "%s" -> "%s"\n' "$key" "${got:-absent}" "$want"
    n=$((n + 1))
  done <<< "$2"
  [ "$n" -eq 0 ]
}

# _kern_stop_server <name>: the cleanup-phase stop of one server by name, without the stop time (a stop must work after T_STOP too); never fatal
_kern_stop_server() { moe_stop_by_name "$1"; }

# kernels_sweep_parts <outdir>: whatever an earlier worker left as a part directory is evidence, never a record
kernels_sweep_parts() {
  local outdir="$1" dir name kind
  for dir in "$outdir"/linear/*.part-* "$outdir"/prefix/*.part-*; do
    [ -d "$dir" ] || continue
    name="${dir##*/}"
    kind="${dir%/*}"
    kind="${kind##*/}"
    moe_reject "$outdir" "$kind-${name%%.part-*}" "$dir" "INTERRUPTED: $name was left by an earlier worker that did not finish it" \
      && echo "kernels: $name moved to ${_MOE_REJECTED#"$outdir"/}"
  done
}

# _kern_reject <outdir> <kind> <name> <part> <reason>: the failed record is evidence; 1 (the worker's failed try)
_kern_reject() {
  moe_reject "$1" "$2-$3" "$4" "$5"
  echo "$2 $3: rejected, ${_MOE_REJECTED#"$1"/}: $5"
  return 1
}

# ---------- the linear unit ----------
# _kern_linear_env <part> <name> <model> <timer> <ms> <sweep> <container> <started> <finished> <rc>: linear.env
_kern_linear_env() {
  {
    _moe_env_line NAME "$2"
    kernels_identity linear "$3" "$5" "$6" "$4" "$2"
    printf '%s\n' "$_MOE_HASHES" # taken right after the identity check: what the container started with
    _moe_env_line CONTAINER "$7"
    _moe_env_line RUN_ID "$RUN_ID"
    _moe_env_line STARTED_AT "$8"
    _moe_env_line ENDED_AT "$9"
    _moe_env_line RC "${10}"
  } > "$1/linear.env"
}

# _kern_linear_validate <part> <exchange> <rc> <ms> <sweep>: sets _MOE_REASON, 1 on the first failed rule (decision 4); the JSON is copied into the part on the way
_kern_linear_validate() {
  local part="$1" exchange="$2" rc="$3" out
  _MOE_REASON=""
  [ -f "$exchange/linear_bench.json" ] && cp "$exchange/linear_bench.json" "$part/"
  if [ "$rc" -ne 0 ]; then _MOE_REASON="rc=$rc"; return 1; fi
  [ -f "$part/linear_bench.json" ] || { _MOE_REASON="no linear_bench.json in the exchange folder"; return 1; }
  if ! out="$(python3 "$_KERN_LIB/linear_bench.py" check "$part/linear_bench.json" --shapes "$R9700_LINEAR_SHAPES" --group-size "$R9700_LINEAR_GROUP_SIZE" --ms "$4" --sweep-ms "$5" 2>&1)"; then
    _MOE_REASON="check: ${out%%$'\n'*}"
    return 1
  fi
  python3 "$_KERN_LIB/linear_bench.py" summarize "$part/linear_bench.json" > "$part/summary.txt" || { _MOE_REASON="summarize failed"; return 1; }
  [ -s "$part/linear.log" ] || { _MOE_REASON="linear.log is empty"; return 1; }
}

# kernels_linear_unit <outdir> <model> <name> <timer> <ms> <sweep ms>
kernels_linear_unit() {
  local outdir="$1" model="$2" name="$3" timer="$4" ms="$5" sweep="$6" part exchange cname started finished rc valid
  local -a argv=()
  if [ -d "$outdir/linear/$name" ]; then echo "linear $name: recorded, nothing to do"; return 0; fi
  echo "=== $(_moe_iso) linear $name ($timer, ms $ms, sweep $sweep)"
  moe_identity_check kernels_assets || return 2
  _MOE_HASHES="$(moe_asset_hashes kernels_assets)"
  _moe_disk_gate || return 1
  _moe_clear_before_unit || return 2
  part="$outdir/linear/$name.part-$RUN_ID"
  mkdir -p "$outdir/linear" && mkdir "$part" || { echo "kernels: $part cannot be made"; return 1; }
  exchange="$(kernels_exchange_dir linear "$name")"
  # a half-written JSON holds no evidence: the folder is deleted and made again; one that cannot be emptied would let a stale file pass `check`: refused
  if ! rm -rf "${exchange:?}" 2> /dev/null || ! mkdir -p "$exchange" || [ -n "$(ls -A "$exchange" 2> /dev/null)" ]; then
    _moe_refuse "the exchange folder $exchange cannot be cleared"
    return 2
  fi
  cname="$(container_name "linear-bench-${R9700_STEP_N:?}")" || return 2
  kernels_linear_argv argv "$cname" "$name" "$timer" "$ms" "$sweep"
  started="$(_moe_iso)"
  wslc_run_once "$_KERN_LINEAR_CEILING_S" "${argv[@]}" > "$part/linear.log"
  rc=$?
  [ "$rc" -eq 0 ] || moe_stop_by_name "$cname" # a call cut at its ceiling leaves its container running
  if [ "$rc" -ne 0 ] && _moe_stop_came; then _moe_deadline "linear unit $name"; return 1; fi
  finished="$(_moe_iso)"
  _kern_linear_env "$part" "$name" "$model" "$timer" "$ms" "$sweep" "$cname" "$started" "$finished" "$rc"
  _kern_linear_validate "$part" "$exchange" "$rc" "$ms" "$sweep"
  valid=$?
  _moe_assets_unchanged kernels_assets || valid=1 # the record would name hashes the container did not run with
  [ "$valid" -eq 0 ] || { _kern_reject "$outdir" linear "$name" "$part" "$_MOE_REASON"; return 1; }
  mv -T "$part" "$outdir/linear/$name" || { echo "kernels: $part cannot become linear/$name"; return 1; }
  echo "recorded linear/$name"
  _moe_disk_gate || return 1
}

# ---------- the prefix unit ----------
# _kern_prefix_env <part> <name> <model> <arm> <lens> <tail> <container> <started> <finished> <rc>: prefix.env
_kern_prefix_env() {
  {
    _moe_env_line NAME "$2"
    kernels_identity prefix "$3" "$4" "$5" "$6"
    printf '%s\n' "$_MOE_HASHES"
    _moe_env_line CONTAINER "$7"
    _moe_env_line RUN_ID "$RUN_ID"
    _moe_env_line STARTED_AT "$8"
    _moe_env_line ENDED_AT "$9"
    _moe_env_line RC "${10}"
  } > "$1/prefix.env"
}

# _kern_prefix_validate <part> <rc> <alive 0|1> <name> <lens>: sets _MOE_REASON, 1 on the first failed rule (decision 7)
_kern_prefix_validate() {
  local part="$1" rc="$2" alive="$3" out
  _MOE_REASON=""
  # a lost server is named first: an exec whose container went away under it returns an error code too, and `rc=1` would hide the cause
  if [ "$alive" -ne 1 ]; then _MOE_REASON="LOST: the server was not listed after the check (a lost server leaves no record)"; return 1; fi
  if [ "$rc" -ne 0 ]; then _MOE_REASON="rc=$rc"; return 1; fi
  if ! out="$(python3 "$_KERN_LIB/prefixtest.py" check "$part/prefixtest.txt" --lens "$5" --tag "$4" 2>&1)"; then
    _MOE_REASON="check: ${out%%$'\n'*}"
    return 1
  fi
  python3 "$_KERN_LIB/prefixtest.py" summarize "$part/prefixtest.txt" > "$part/summary.txt" || { _MOE_REASON="summarize failed"; return 1; }
  [ -s "$part/server.log" ] || { _MOE_REASON="server.log is empty"; return 1; }
}

# _kern_prefix_serve <part> <server name> <arm>: starts the arm's server as the series does (the same option builder); 0 ready. A server that did not start or
# become ready is stopped by name here, before the worker goes on.
_kern_prefix_serve() {
  local -a envs=() mounts=() sargs=()
  _series_serve_options envs mounts sargs "$3"
  serve_start "$2" "$1/server.log" "${envs[@]}" "${mounts[@]}" -- "${sargs[@]}" && return 0
  _kern_stop_server "$2"
  return 1
}

# kernels_prefix_unit <outdir> <model> <name> <arm> <lens> <tail>
kernels_prefix_unit() {
  local outdir="$1" model="$2" name="$3" arm="$4" lens="$5" tail="$6" part sname started finished rc valid alive=0
  local -a words=()
  if [ -d "$outdir/prefix/$name" ]; then echo "prefix $name: recorded, nothing to do"; return 0; fi
  echo "=== $(_moe_iso) prefix $name (arm $arm, lens $lens, tail $tail)"
  moe_identity_check kernels_assets || return 2
  _MOE_HASHES="$(moe_asset_hashes kernels_assets)"
  _moe_disk_gate || return 1
  part="$outdir/prefix/$name.part-$RUN_ID"
  mkdir -p "$outdir/prefix" && mkdir "$part" || { echo "kernels: $part cannot be made"; return 1; }
  sname="$(container_name "prefix-$arm-${R9700_STEP_N:?}")" || return 2
  started="$(_moe_iso)"
  if ! _kern_prefix_serve "$part" "$sname" "$arm"; then
    if _moe_stop_came; then _moe_deadline "the start of $sname"; return 1; fi # the adapter refuses every call at the stop time: not the arm's fault, the part stays as evidence
    _kern_reject "$outdir" prefix "$name" "$part" "not ready: $sname did not start or become ready"
    return 1
  fi
  kernels_prefix_exec_words words "$name" "$lens" "$tail"
  wslc_exec "$_KERN_PREFIX_EXEC_S" "$sname" "${words[@]}" > "$part/prefixtest.txt"
  rc=$?
  if [ "$rc" -ne 0 ] && _moe_stop_came; then _kern_stop_server "$sname"; _moe_deadline "the prefix check $name"; return 1; fi
  _series_alive "$sname" && alive=1
  if wslc_logs "$sname" > "$part/server.log.new" 2> /dev/null && [ -s "$part/server.log.new" ]; then mv -f "$part/server.log.new" "$part/server.log"; else rm -f "$part/server.log.new"; fi
  _kern_stop_server "$sname"
  finished="$(_moe_iso)"
  _kern_prefix_env "$part" "$name" "$model" "$arm" "$lens" "$tail" "$sname" "$started" "$finished" "$rc"
  _kern_prefix_validate "$part" "$rc" "$alive" "$name" "$lens"
  valid=$?
  _moe_assets_unchanged kernels_assets || valid=1
  [ "$valid" -eq 0 ] || { _kern_reject "$outdir" prefix "$name" "$part" "$_MOE_REASON"; return 1; }
  mv -T "$part" "$outdir/prefix/$name" || { echo "kernels: $part cannot become prefix/$name"; return 1; }
  echo "recorded prefix/$name"
  _moe_disk_gate || return 1
}

# ---------- the worker ----------
# _kern_common_args <outdir> <model> <name>: 2 with one `kernels:` line
_kern_common_args() {
  [ -n "${1:-}" ] || { echo "kernels: the outdir is empty" >&2; return 2; }
  [[ ${2:-} =~ $_MOE_MODEL_RE ]] || { echo "kernels: the model name \"${2:-}\" is not $_MOE_MODEL_RE" >&2; return 2; }
  [[ ${3:-} =~ $_KERN_NAME_RE ]] || { echo "kernels: the name \"${3:-}\" is not $_KERN_NAME_RE" >&2; return 2; }
}

_kern_linear_args() {
  [ "$#" -eq 6 ] || { echo "kernels: usage: kernels.sh linear <outdir> <model> <name> <timer> \"<ms>\" \"<sweep ms>\"" >&2; return 2; }
  _kern_common_args "$1" "$2" "$3" || return 2
  case $4 in graph | eager) ;; *) echo "kernels: the timer \"$4\" is not graph or eager" >&2; return 2 ;; esac
  _cfg_ints_problem "$5" || { echo "kernels: --ms: $_PE" >&2; return 2; }
  _cfg_ints_problem "$6" || { echo "kernels: --sweep-ms: $_PE" >&2; return 2; }
}

_kern_prefix_args() {
  [ "$#" -eq 6 ] || { echo "kernels: usage: kernels.sh prefix <outdir> <model> <name> <arm> \"<lens>\" <tail>" >&2; return 2; }
  _kern_common_args "$1" "$2" "$3" || return 2
  [[ $4 =~ $_RE_ARM ]] || { echo "kernels: the arm \"$4\" is not an arm name" >&2; return 2; }
  _cfg_ints_problem "$5" || { echo "kernels: --lens: $_PE" >&2; return 2; }
  [[ $6 =~ ^[1-9][0-9]{0,8}$ ]] || { echo "kernels: the tail \"$6\" is not a positive integer" >&2; return 2; }
}

# kernels_main linear|prefix <args...>: the worker
kernels_main() {
  local unit="${1:-}" rc
  shift
  RUN_ID="$(basename "${R9700_RUN_DIR:?R9700_RUN_DIR is not set (run by the supervisor only)}")"
  _MOE_WHO=kernels
  case $unit in
    linear) _kern_linear_args "$@" || exit 2; _MOE_PLACED_BY=linear-bench ;;
    prefix) _kern_prefix_args "$@" || exit 2; _MOE_PLACED_BY=prefixtest; arms_load "$(series_arms_conf)" || exit 2 ;;
    *) echo "kernels: unknown unit \"$unit\"; legal: linear prefix" >&2; exit 2 ;;
  esac
  kernels_sweep_parts "$1"
  if [ "$unit" = linear ]; then kernels_linear_unit "$@"; else kernels_prefix_unit "$@"; fi
  rc=$?
  exit "$rc"
}

# run as the worker only when executed, not when sourced
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -u
  for _kern_lib in config run_guarded adapter serve wait_ready disk_gate series moe; do
    # shellcheck source=/dev/null
    source "$_KERN_LIB/$_kern_lib.sh" || exit 2
  done
  kernels_main "$@"
fi
