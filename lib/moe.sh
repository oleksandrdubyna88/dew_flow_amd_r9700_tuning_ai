#!/usr/bin/env bash
# lib/moe.sh — the MoE tuning units as workers under the E1 supervisor (E2.S2). Bash >= 4.4, `set -u` safe, no `set -e`. Two faces, like lib/series.sh:
# SOURCED, it defines functions (the cache clear is the supervisor's cleanup hook); RUN as the worker, `bash lib/moe.sh chunk|ab <args>...`, which
# `step_run` starts as ONE step. The worker sets no trap, takes no lock and never stops the operator's server: the supervisor owns all three.
#
#   bash lib/moe.sh chunk <outdir> <model> <chunk> <layer> <search> <keys...>     one tuning chunk (layer: experts|draft, search: full|coarse)
#   bash lib/moe.sh ab <outdir> <model> <layer> <rule> "<rule keys>" <reps> "<keys>"   one kernel A/B (rule: each|median)
#
#   moe_exchange_dir <model> / moe_container_dir <model>   $R9700_WORK_DIR/r9700/moe/<model> and its path inside the containers
#   moe_cache_clear                the Triton tuning caches cleared by a prefixed container with only the cache volume; the supervisor's hook
#   moe_assets                     `<placed name> <repository source> <required|optional>` per line: the ONE table of the identity check
#   moe_identity_check             every placed asset against its source; 2 and the outcome KIND=refused on a difference
#   moe_asset_hashes               the `<KEY>_SHA256=` lines of chunk.env and ab.env
#   moe_sweep_parts <outdir>       a part directory an earlier worker left is moved to rejected/ as INTERRUPTED evidence
#
# Records (E2.S2 decisions 2-4, the shape of lib/series.sh): chunks/<chunk>/ is final; while it is built it is chunks/<chunk>.part-<run id>/. It
# becomes final by ONE rename after the validation (RC=0, exactly one E=*.json, `merge_moe.py check` on it, a non-empty log). A failed validation
# moves the directory to rejected/<chunk>-<UTC stamp>/ with a `reason` file; nothing is ever deleted there. ab/<stamp>/ the same: six logs of their
# own (never appended to), ab.env, summary.txt and decision.txt, final only when every log holds one kernel time per key and every tuned log shows
# the activated file loaded. The exchange folder $R9700_WORK_DIR/r9700/moe/<model>/tune/<chunk>/ is scratch: deleted and made again before every run.
#
# Exit codes: 0 done (recorded, or already recorded); 1 the unit failed (a rejected record, or the disk gate: KIND=disk_gate; or the stop time came:
# KIND=deadline, and the part stays for the next start's sweep); 2 refused (KIND=refused when the identity check or the layer refuses: the supervisor
# stops at once; a bad argument is a plain 2 with one `moe:` line). No exit 3 or 4: the supervisor waits for quiet before every admission and a unit is
# one container run.

_MOE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_MOE_REPO="$(dirname "$_MOE_LIB")"
_MOE_CHUNK_RE='^[a-z0-9][a-z0-9-]{0,30}$'     # the label moe-tune-<chunk> must fit container_name's 40
_MOE_MODEL_RE='^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'
_MOE_CONTAINER_ROOT=/work/r9700                   # the work folder is mounted at /work; the toolkit's files are under r9700/
_MOE_TUNE_CACHE=/root/.cache/vllm/triton-moe-tune # tune_chunk.sh line 17
_MOE_AB_CACHE=/root/.cache/vllm/triton-moe-ab     # moe_kernel_ab.sh line 19
_MOE_DRAFT_ACT=bfloat16                           # speed_CB.sh line 22: the draft layer is tuned with BF16 activations (hook 3 of the vendored benchmark)
_MOE_AB_CEILING_S=1800                            # moe_kernel_ab.sh line 19: `timeout 1800`
# the program of the cache-clear container: no variable in it (plan-gate E1 finding 1); b2.sh line 21, with both cache folders
_MOE_CLEAR_SH='du -sh /root/.cache/vllm/triton-moe-tune /root/.cache/vllm/triton-moe-ab 2> /dev/null; rm -rf /root/.cache/vllm/triton-moe-tune /root/.cache/vllm/triton-moe-ab'
# The clear's own adapter ceiling. It is LONGER than the 65 s window the supervisor's hook gives it (run_guarded.sh, _rg_cleanup_hook_run): in the hook
# the supervisor's window is the enforced, outer one and kills the whole tree; this inner ceiling ends a clear that the worker runs before a unit.
_MOE_CLEAR_CEILING_S=90

moe_exchange_dir() { printf '%s/r9700/moe/%s\n' "${R9700_WORK_DIR:?}" "$1"; }

moe_container_dir() { printf '%s/moe/%s\n' "$_MOE_CONTAINER_ROOT" "$1"; }

_moe_iso() { date -u +%FT%TZ 9>&-; }

_moe_stamp() { date -u +%Y%m%dT%H%M%SZ 9>&-; }

_moe_sha() { sha256sum "$1" 2> /dev/null | cut -d' ' -f1; }

# _moe_env_line <KEY> <value>: a KEY=value line of chunk.env or ab.env; a value with a space is in one pair of double quotes (lib/merge_moe.py reads both)
_moe_env_line() {
  local value="${2//\"/}"
  if [[ $value == *[[:space:]]* ]]; then printf '%s="%s"\n' "$1" "$value"; else printf '%s=%s\n' "$1" "$value"; fi
}

# moe_cache_clear: the caches of both units cleared. A failure is logged and is not fatal: a stale cache only costs disk and compile time.
moe_cache_clear() {
  local out rc line
  local -a lines=()
  out="$(wslc_run_once "$_MOE_CLEAR_CEILING_S" --name "$(container_name moe-clear)" -v "$R9700_CACHE_VOLUME:/root/.cache/vllm" "$R9700_IMAGE" sh -c "$_MOE_CLEAR_SH")"
  rc=$?
  while IFS= read -r line; do [ -n "$line" ] && lines+=("${line//$'\t'/ }"); done <<< "$out"
  if [ "$rc" -eq 0 ]; then
    echo "cache before clear: $(IFS=,; echo "${lines[*]}")"
  else
    echo "cache clear failed (code $rc): ${lines[0]:-no output}; going on"
  fi
  return "$rc"
}

# ---------- the identity of the placed files (decision 8) ----------
moe_assets() {
  printf '%s\n' \
    "benchmark_moe.py vendor/benchmark_moe.py required" \
    "coarse_candidates.json config/coarse_candidates.json required" \
    "harness.py lib/harness.py optional"
}

# _moe_hash_key <placed name>: the word before _SHA256 in chunk.env and ab.env
_moe_hash_key() {
  case $1 in
    benchmark_moe.py) echo BENCHMARK ;;
    coarse_candidates.json) echo CANDIDATES ;;
    *) local stem="${1%.*}"; echo "${stem^^}" ;;
  esac
}

# _moe_refuse <detail>: the worker's own word that it will not go on (KIND=refused: the supervisor stops at once, no retry); 2
_moe_refuse() {
  echo "moe: $1"
  [ -z "${R9700_OUTCOME_FILE:-}" ] || outcome_write "$R9700_OUTCOME_FILE" KIND=refused RC=2 "DETAIL=moe: $1"
  return 2
}

moe_identity_check() {
  local name source need placed want got
  while read -r name source need _; do
    placed="${R9700_WORK_DIR:?}/r9700/$name"
    want="$(_moe_sha "$_MOE_REPO/$source")"
    if [ ! -f "$placed" ]; then
      [ "$need" = optional ] && continue
      _moe_refuse "$name is missing in the work folder (it is placed from $source by moe-tune)" || return 2
    fi
    got="$(_moe_sha "$placed")"
    [ "$got" = "$want" ] || { _moe_refuse "$name in the work folder differs from $source (${got:0:12} -> ${want:0:12})"; return 2; }
  done < <(moe_assets)
  return 0
}

moe_asset_hashes() {
  local name source need placed sum
  while read -r name source need _; do
    placed="${R9700_WORK_DIR:?}/r9700/$name"
    sum=absent
    [ -f "$placed" ] && sum="$(_moe_sha "$placed")"
    printf '%s_SHA256=%s\n' "$(_moe_hash_key "$name")" "$sum"
  done < <(moe_assets)
}

# ---------- the container ----------
# moe_layer_words <layer> <envs array> <dtype var>: the activation hook and the dtype of a layer (decision 2); 2 with one `moe:` line for another
moe_layer_words() {
  local -n _l_envs="$2"
  local -n _l_dtype="$3"
  case $1 in
    experts) _l_envs=(); _l_dtype="$R9700_MOE_DTYPE" ;;
    draft) _l_envs=(-e "MOE_TUNE_ACT_DTYPE=$_MOE_DRAFT_ACT"); _l_dtype=auto ;;
    *) echo "moe: the layer \"$1\" is not experts or draft" >&2; return 2 ;;
  esac
}

# moe_argv <argv array> <extra envs array> <tune|ab> <layer> <model> <chunk> <keys...>: the arguments after `run --rm --name <name>` (tune_chunk.sh lines 14-17;
# the A/B is the same without --tune and --save-dir, with its own cache folder). The extra environment words come right after HIP_VISIBLE_DEVICES.
moe_argv() {
  local -n _m_argv="$1"
  local -n _m_extra="$2"
  local mode="$3" layer="$4" model="$5" chunk="$6" cache dtype
  local -a layer_envs=()
  shift 6
  moe_layer_words "$layer" layer_envs dtype || return 2
  [ "$mode" = tune ] && cache="$_MOE_TUNE_CACHE" || cache="$_MOE_AB_CACHE"
  _m_argv=(
    --gpus all --shm-size 16g -e HIP_VISIBLE_DEVICES=0 "${_m_extra[@]}" "${layer_envs[@]}" -e "TRITON_CACHE_DIR=$cache"
    -v "$R9700_HF_VOLUME:/root/.cache/huggingface" -v "$R9700_CACHE_VOLUME:/root/.cache/vllm" -v "$R9700_WORK_DIR_WIN:/work" -w /work/r9700
    "$R9700_IMAGE" python3 benchmark_moe.py --model "$R9700_MODEL_DIR" --tp-size 1 --dtype "$dtype"
  )
  if [ "$mode" = tune ]; then
    _m_argv+=(--tune --batch-size "$@" --save-dir "$(moe_container_dir "$model")/tune/$chunk" --trust-remote-code)
  else
    _m_argv+=(--batch-size "$@" --trust-remote-code)
  fi
}

# ---------- records ----------
# moe_reject <outdir> <tag> <part dir> <reason>: moves the directory to rejected/<tag>-<UTC stamp>[-<n>]/ and writes `reason`; the new path is in _MOE_REJECTED
moe_reject() {
  local outdir="$1" tag="$2" part="$3" reason="$4" dest n=1
  mkdir -p "$outdir/rejected" || return 1
  dest="$outdir/rejected/$tag-$(_moe_stamp)"
  while [ -e "$dest" ]; do n=$((n + 1)); dest="$outdir/rejected/$tag-$(_moe_stamp)-$n"; done
  mv -T "$part" "$dest" || return 1
  printf '%s\n' "$reason" > "$dest/reason"
  _MOE_REJECTED="$dest"
}

# moe_sweep_parts <outdir>: the crash recovery of the worker: whatever an earlier worker left as a part directory is evidence, never a record
moe_sweep_parts() {
  local outdir="$1" dir name tag
  for dir in "$outdir"/chunks/*.part-* "$outdir"/ab/*.part-*; do
    [ -d "$dir" ] || continue
    name="${dir##*/}"
    tag="${name%%.part-*}"
    [[ $dir == */ab/* ]] && tag="ab-$tag"
    moe_reject "$outdir" "$tag" "$dir" "INTERRUPTED: $name was left by an earlier worker that did not finish it" \
      && echo "moe: $name moved to ${_MOE_REJECTED#"$outdir"/}"
  done
}

# _moe_disk_gate: the disk gate; a stop is the typed outcome KIND=disk_gate (the supervisor's exit 9) and the gate's line on stdout. 1 on a stop.
_moe_disk_gate() {
  local line
  if ! line="$(disk_gate_check "${R9700_RUN_DIR:?}/disk_gate.state")"; then
    outcome_write "${R9700_OUTCOME_FILE:?}" KIND=disk_gate RC=1 "DETAIL=$line"
    echo "$line"
    return 1
  fi
}

# _moe_stop_came: 0 when the stop time of the supervisor has come (R9700_T_STOP, an epoch second; 50 ms of slack for a timer that fires at it)
_moe_stop_came() {
  [[ ${R9700_T_STOP:-} =~ ^[0-9]+$ ]] || return 1
  awk -v s="$R9700_T_STOP" -v n="$(date +%s.%N 9>&-)" 'BEGIN { exit !(n >= s - 0.05) }' 9>&-
}

# _moe_deadline <what>: the stop time came while a container ran: the outcome says so (the first writer wins: the deadline watcher may have been first),
# and the part stays where it is, so that the next start's sweep keeps it as INTERRUPTED evidence, whichever of the watcher and the adapter's own cut ended the call
_moe_deadline() {
  echo "moe: the stop time came during $1"
  outcome_write "${R9700_OUTCOME_FILE:?}" KIND=deadline "DETAIL=the stop time came during $1"
}

# ---------- the chunk unit ----------
# _moe_chunk_env <part> <chunk> <layer> <search> <name> <started> <finished> <seconds> <rc> <keys...>: chunk.env
_moe_chunk_env() {
  local part="$1" chunk="$2" layer="$3" search="$4" name="$5" started="$6" finished="$7" elapsed="$8" rc="$9" dtype act=""
  local -a layer_envs=()
  shift 9
  moe_layer_words "$layer" layer_envs dtype
  [ "$layer" = draft ] && act="$_MOE_DRAFT_ACT"
  {
    _moe_env_line CHUNK "$chunk"
    _moe_env_line LAYER "$layer"
    _moe_env_line SEARCH "$search"
    _moe_env_line KEYS "$*"
    _moe_env_line DTYPE "$dtype"
    _moe_env_line ACT_DTYPE "$act"
    moe_asset_hashes
    _moe_env_line IMAGE "$R9700_IMAGE"
    _moe_env_line MODEL_DIR "$R9700_MODEL_DIR"
    _moe_env_line CONTAINER "$name"
    _moe_env_line RUN_ID "$RUN_ID"
    _moe_env_line STARTED_AT "$started"
    _moe_env_line FINISHED_AT "$finished"
    _moe_env_line SECONDS "$elapsed"
    _moe_env_line RC "$rc"
  } > "$part/chunk.env"
}

# _moe_chunk_validate <part> <exchange tune dir> <rc> <keys...>: sets _MOE_REASON and returns 1 on the first failed rule (decision 2: RC=0, exactly one
# E=*.json, `check`, a log that is not empty); the JSON is copied into the part on the way. The ImportError tracebacks at the end of a real log are
# not a failure: the rule is the exit code and the JSON, never a grep for `Traceback`.
_moe_chunk_validate() {
  local part="$1" tune="$2" rc="$3" first
  local -a found=()
  shift 3
  _MOE_REASON=""
  found=("$tune"/E=*.json)
  [ -f "${found[0]}" ] || found=()
  [ "${#found[@]}" -eq 1 ] && cp "${found[0]}" "$part/"
  if [ "$rc" -ne 0 ]; then _MOE_REASON="rc=$rc"; return 1; fi
  if [ "${#found[@]}" -eq 0 ]; then _MOE_REASON="no E=*.json in tune/${tune##*/}/"; return 1; fi
  if [ "${#found[@]}" -gt 1 ]; then _MOE_REASON="${#found[@]} files E=*.json in tune/${tune##*/}/, expected one"; return 1; fi
  if ! first="$(python3 "$_MOE_LIB/merge_moe.py" check --keys "$*" "$part/${found[0]##*/}")"; then _MOE_REASON="check: $first"; return 1; fi
  [ -s "$part/chunk.log" ] || { _MOE_REASON="chunk.log is empty"; return 1; }
}

# moe_chunk_unit <outdir> <model> <chunk> <layer> <search> <keys...>
moe_chunk_unit() {
  local outdir="$1" model="$2" chunk="$3" layer="$4" search="$5" part tune name started finished t0 t1 rc
  local -a keys=() argv=() extra=()
  shift 5
  keys=("$@")
  if [ -d "$outdir/chunks/$chunk" ]; then echo "chunk $chunk: recorded, nothing to do"; return 0; fi
  echo "=== $(_moe_iso) chunk $chunk ($layer, $search, keys ${keys[*]})"
  if [ "$layer" = experts ] && [ "$R9700_MOE_DTYPE" = none ]; then _moe_refuse "MOE_DTYPE is none: the model has no MoE layers to tune"; return 2; fi
  moe_identity_check || return 2
  _moe_disk_gate || return 1
  moe_cache_clear
  part="$outdir/chunks/$chunk.part-$RUN_ID"
  mkdir -p "$outdir/chunks" && mkdir "$part" || { echo "moe: $part cannot be made"; return 1; }
  tune="$(moe_exchange_dir "$model")/tune/$chunk"
  rm -rf "${tune:?}" # a half-written chunk holds no evidence (tune_chunk.sh line 9): it is deleted, and never taken for a result
  mkdir -p "$tune" || { echo "moe: $tune cannot be made"; return 1; }
  extra=()
  [ "$search" = coarse ] && extra=(-e "MOE_TUNE_CANDIDATES=$_MOE_CONTAINER_ROOT/coarse_candidates.json")
  moe_argv argv extra tune "$layer" "$model" "$chunk" "${keys[@]}" || return 2
  name="$(container_name "moe-tune-$chunk")" || return 2
  started="$(_moe_iso)"
  t0="$(date +%s 9>&-)"
  wslc_run_once "$R9700_MOE_CHUNK_MAX_S" --name "$name" "${argv[@]}" > "$part/chunk.log"
  rc=$?
  t1="$(date +%s 9>&-)"
  finished="$(_moe_iso)"
  if [ "$rc" -ne 0 ] && _moe_stop_came; then _moe_deadline "chunk $chunk"; return 1; fi
  _moe_chunk_env "$part" "$chunk" "$layer" "$search" "$name" "$started" "$finished" "$((t1 - t0))" "$rc" "${keys[@]}"
  grep -E 'Start tuning|Tuning space|Completed tuning|Best config|Kernel time|Error|Traceback' "$part/chunk.log" | tail -n 6 > "$part/chunk.summary"
  if ! _moe_chunk_validate "$part" "$tune" "$rc" "${keys[@]}"; then
    moe_reject "$outdir" "$chunk" "$part" "$_MOE_REASON"
    echo "chunk $chunk: rejected, ${_MOE_REJECTED#"$outdir"/}: $_MOE_REASON"
    return 1
  fi
  mv -T "$part" "$outdir/chunks/$chunk" || { echo "moe: $part cannot become chunks/$chunk"; return 1; }
  echo "recorded chunks/$chunk"
  _moe_disk_gate || return 1
}

# ---------- the A/B unit ----------
# _moe_b_file <outdir> <model> <layer>: the name of the layer's file in merged/, read back and never typed: from the chunk records of that layer, else
# from merged/ itself when it holds exactly one. Sets _MOE_B_FILE; 2 with the outcome KIND=refused when merged/ holds no such file.
_moe_b_file() {
  local outdir="$1" model="$2" layer="$3" merged env dir found=""
  local -a files=()
  merged="$(moe_exchange_dir "$model")/merged"
  for env in "$outdir"/chunks/*/chunk.env; do
    [ -f "$env" ] || continue
    [ "$(sed -n 's/^LAYER=//p' "$env" | head -n 1)" = "$layer" ] || continue
    dir="${env%/chunk.env}"
    files=("$dir"/E=*.json)
    [ -f "${files[0]}" ] && { found="${files[0]##*/}"; break; }
  done
  if [ -z "$found" ]; then
    files=("$merged"/E=*.json)
    [ -f "${files[0]}" ] || { _moe_refuse "merged/ holds no E=*.json (run activate first)"; return 2; }
    [ "${#files[@]}" -eq 1 ] || { _moe_refuse "merged/ holds ${#files[@]} files E=*.json and no chunk of the layer $layer says which is its"; return 2; }
    found="${files[0]##*/}"
  fi
  [ -f "$merged/$found" ] || { _moe_refuse "merged/ holds no $found (the file of the layer $layer; run activate first)"; return 2; }
  _MOE_B_FILE="$found"
}

# _moe_config_line <log> <prefer folder/file or "">: the first `Using configuration from <path> for MoE layer` or `Using default MoE config...` of a log
_moe_config_line() {
  grep -m 1 -oE 'Using configuration from [^ ]+ for MoE layer|Using default MoE config.*' "$1" 2> /dev/null
}

# _moe_ab_validate <part> <reps> <b folder> <b file> <keys count>: the rules of decision 4 (a) and (b); sets _MOE_REASON, 1 on the first failure
_moe_ab_validate() {
  local part="$1" reps="$2" want="Using configuration from $3/$4 for MoE layer" count="$5" rep arm n found
  _MOE_REASON=""
  for ((rep = 1; rep <= reps; rep++)); do
    for arm in default tuned; do
      n="$(grep -c '^Kernel time:' "$part/$arm-$rep.log" 2> /dev/null)"
      [ "${n:-0}" -eq "$count" ] || { _MOE_REASON="$arm-$rep.log: ${n:-0} kernel times, expected $count"; return 1; }
    done
  done
  for ((rep = 1; rep <= reps; rep++)); do
    grep -qF -- "$want" "$part/tuned-$rep.log" && continue
    found="$(_moe_config_line "$part/tuned-$rep.log")"
    _MOE_REASON="tuned-$rep.log: no \"Using configuration from $3/$4\" line (found: ${found:-none})"
    return 1
  done
}

# _moe_ab_env <part> <layer> <rule> <rule keys> <reps> <a folder> <b folder> <b file> <started> <finished> <keys>: ab.env
_moe_ab_env() {
  local part="$1" layer="$2" dtype act=""
  local -a layer_envs=()
  moe_layer_words "$layer" layer_envs dtype
  [ "$layer" = draft ] && act="$_MOE_DRAFT_ACT"
  {
    _moe_env_line LAYER "$layer"
    _moe_env_line DTYPE "$dtype"
    _moe_env_line ACT_DTYPE "$act"
    _moe_env_line KEYS "${11}"
    _moe_env_line RULE "$3"
    _moe_env_line RULE_KEYS "$4"
    _moe_env_line REPS "$5"
    _moe_env_line A_FOLDER "$6"
    _moe_env_line B_FOLDER "$7"
    _moe_env_line B_FILE "$8"
    _moe_env_line B_SHA256 "$(_moe_sha "${12:-/nonexistent}")"
    _moe_env_line A_CONFIG_LINE "$(_moe_config_line "$part/default-1.log")"
    _moe_env_line B_CONFIG_LINE "$(_moe_config_line "$part/tuned-1.log")"
    _moe_env_line IMAGE "$R9700_IMAGE"
    _moe_env_line MODEL_DIR "$R9700_MODEL_DIR"
    moe_asset_hashes
    _moe_env_line RUN_ID "$RUN_ID"
    _moe_env_line STARTED_AT "$9"
    _moe_env_line FINISHED_AT "${10}"
  } > "$part/ab.env"
}

# _moe_ab_containers <part> <model> <layer> <reps> <a folder> <b folder> <keys...>: the order of moe_kernel_ab.sh line 14: rep by rep, default then tuned;
# the disk gate before each container; each log is a file of its own that is written once. 0 all ran, 1 the gate stopped or the stop time came.
_moe_ab_containers() {
  local part="$1" model="$2" layer="$3" reps="$4" afolder="$5" bfolder="$6" rep arm name rc
  local -a argv=() extra=()
  shift 6
  for ((rep = 1; rep <= reps; rep++)); do
    for arm in default tuned; do
      _moe_disk_gate || return 1
      extra=()
      if [ "$arm" = tuned ]; then extra=(-e "VLLM_TUNED_CONFIG_FOLDER=$bfolder"); elif [ -n "$afolder" ]; then extra=(-e "VLLM_TUNED_CONFIG_FOLDER=$afolder"); fi
      moe_argv argv extra ab "$layer" "$model" "" "$@" || return 1
      name="$(container_name "moe-ab-$arm-$rep")" || return 1
      wslc_run_once "$_MOE_AB_CEILING_S" --name "$name" "${argv[@]}" > "$part/$arm-$rep.log"
      rc=$?
      if [ "$rc" -ne 0 ] && _moe_stop_came; then _moe_deadline "the A/B container $arm-$rep"; return 1; fi
    done
  done
}

# moe_ab_unit <outdir> <model> <layer> <rule> <rule keys> <reps> <keys>
moe_ab_unit() {
  local outdir="$1" model="$2" layer="$3" rule="$4" rule_keys="$5" reps="$6" keys="$7" stamp part dest n=1 started finished decision rc bfolder bfile
  local -a keylist=()
  read -r -a keylist <<< "$keys"
  echo "=== $(_moe_iso) ab ($layer, rule $rule over $rule_keys, $reps reps, keys $keys)"
  if [ "$layer" = experts ] && [ "$R9700_MOE_DTYPE" = none ]; then _moe_refuse "MOE_DTYPE is none: the model has no MoE layers to measure"; return 2; fi
  _moe_b_file "$outdir" "$model" "$layer" || return 2
  bfile="$_MOE_B_FILE"
  bfolder="$(moe_container_dir "$model")/merged"
  moe_identity_check || return 2
  moe_cache_clear
  stamp="$(_moe_stamp)"
  while [ -e "$outdir/ab/$stamp" ] || [ -e "$outdir/ab/$stamp.part-$RUN_ID" ]; do n=$((n + 1)); stamp="$(_moe_stamp)-$n"; done
  part="$outdir/ab/$stamp.part-$RUN_ID"
  mkdir -p "$outdir/ab" && mkdir "$part" || { echo "moe: $part cannot be made"; return 1; }
  started="$(_moe_iso)"
  _moe_ab_containers "$part" "$model" "$layer" "$reps" "$R9700_TUNED_CONFIG_DIR" "$bfolder" "${keylist[@]}" || return 1
  finished="$(_moe_iso)"
  _moe_ab_env "$part" "$layer" "$rule" "$rule_keys" "$reps" "$R9700_TUNED_CONFIG_DIR" "$bfolder" "$bfile" "$started" "$finished" "$keys" \
    "$(moe_exchange_dir "$model")/merged/$bfile"
  if ! _moe_ab_validate "$part" "$reps" "$bfolder" "$bfile" "${#keylist[@]}"; then
    moe_reject "$outdir" "ab-$stamp" "$part" "$_MOE_REASON"
    echo "ab $stamp: rejected, ${_MOE_REJECTED#"$outdir"/}: $_MOE_REASON"
    return 1
  fi
  decision="$(python3 "$_MOE_LIB/moe_kernel_ab.py" decide "$part" --keys "$keys" --rule "$rule" --rule-keys "$rule_keys" --reps "$reps" 2> "$part/decide.err")"
  rc=$?
  if [ "$rc" -gt 1 ]; then
    moe_reject "$outdir" "ab-$stamp" "$part" "decide: $(head -n 1 "$part/decide.err")"
    echo "ab $stamp: rejected, ${_MOE_REJECTED#"$outdir"/}: decide: $(head -n 1 "$part/decide.err")"
    return 1
  fi
  rm -f "$part/decide.err"
  printf '%s\n' "$decision" > "$part/summary.txt"
  printf '%s\n' "${decision##*$'\n'}" > "$part/decision.txt"
  dest="$outdir/ab/$stamp"
  mv -T "$part" "$dest" || { echo "moe: $part cannot become ab/$stamp"; return 1; }
  echo "recorded ab/$stamp"
  cat "$dest/decision.txt"
}

# ---------- the worker ----------
# _moe_keys_problem <keys...>: 1 with one `moe:` line unless 1..20 distinct positive integers of at most 65536
_moe_keys_problem() {
  local key seen=" "
  if [ "$#" -lt 1 ] || [ "$#" -gt 20 ]; then echo "moe: 1 to 20 batch sizes are needed (got $#)" >&2; return 1; fi
  for key in "$@"; do
    if ! [[ $key =~ ^[1-9][0-9]{0,4}$ ]] || [ "$key" -gt 65536 ]; then echo "moe: the batch size \"$key\" is not a whole number from 1 to 65536" >&2; return 1; fi
    case $seen in *" $key "*) echo "moe: the batch size $key is given twice" >&2; return 1 ;; esac
    seen+="$key "
  done
}

_moe_chunk_args() {
  local outdir="${1:-}" model="${2:-}" chunk="${3:-}" layer="${4:-}" search="${5:-}"
  [ "$#" -ge 6 ] || { echo "moe: usage: moe.sh chunk <outdir> <model> <chunk> <layer> <search> <keys...>" >&2; return 2; }
  [ -n "$outdir" ] || { echo "moe: the outdir is empty" >&2; return 2; }
  [[ $model =~ $_MOE_MODEL_RE ]] || { echo "moe: the model name \"$model\" is not $_MOE_MODEL_RE" >&2; return 2; }
  [[ $chunk =~ $_MOE_CHUNK_RE ]] || { echo "moe: the chunk name \"$chunk\" is not $_MOE_CHUNK_RE" >&2; return 2; }
  case $layer in experts | draft) ;; *) echo "moe: the layer \"$layer\" is not experts or draft" >&2; return 2 ;; esac
  case $search in full | coarse) ;; *) echo "moe: the search \"$search\" is not full or coarse" >&2; return 2 ;; esac
  shift 5
  _moe_keys_problem "$@" || return 2
}

_moe_ab_args() {
  local outdir="${1:-}" model="${2:-}" layer="${3:-}" rule="${4:-}" rule_keys="${5:-}" reps="${6:-}" keys="${7:-}"
  local -a kl=() rl=()
  local key
  [ "$#" -eq 7 ] || { echo "moe: usage: moe.sh ab <outdir> <model> <layer> <rule> \"<rule keys>\" <reps> \"<keys>\"" >&2; return 2; }
  [ -n "$outdir" ] || { echo "moe: the outdir is empty" >&2; return 2; }
  [[ $model =~ $_MOE_MODEL_RE ]] || { echo "moe: the model name \"$model\" is not $_MOE_MODEL_RE" >&2; return 2; }
  case $layer in experts | draft) ;; *) echo "moe: the layer \"$layer\" is not experts or draft" >&2; return 2 ;; esac
  case $rule in each | median) ;; *) echo "moe: the rule \"$rule\" is not each or median" >&2; return 2 ;; esac
  [[ $reps =~ ^[1-9]$ ]] || { echo "moe: the number of reps \"$reps\" is not a whole number from 1 to 9" >&2; return 2; }
  read -r -a kl <<< "$keys"
  read -r -a rl <<< "$rule_keys"
  _moe_keys_problem "${kl[@]}" || return 2
  _moe_keys_problem "${rl[@]}" || return 2
  for key in "${rl[@]}"; do # decide would refuse it after six containers: the worker refuses before the first
    [[ " ${kl[*]} " == *" $key "* ]] || { echo "moe: the rule key $key is not one of the keys \"$keys\"" >&2; return 2; }
  done
}

# moe_main chunk|ab <args...>: the worker
moe_main() {
  local unit="${1:-}" rc
  shift
  RUN_ID="$(basename "${R9700_RUN_DIR:?R9700_RUN_DIR is not set (run by the supervisor only)}")"
  case $unit in
    chunk) _moe_chunk_args "$@" || exit 2 ;;
    ab) _moe_ab_args "$@" || exit 2 ;;
    *) echo "moe: unknown unit \"$unit\"; legal: chunk ab" >&2; exit 2 ;;
  esac
  moe_sweep_parts "$1"
  if [ "$unit" = chunk ]; then moe_chunk_unit "$@"; else moe_ab_unit "$@"; fi
  rc=$?
  exit "$rc"
}

# run as the worker only when executed, not when sourced
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -u
  for _moe_lib in config run_guarded adapter serve disk_gate; do
    # shellcheck source=/dev/null
    source "$_MOE_LIB/$_moe_lib.sh" || exit 2
  done
  moe_main "$@"
fi
