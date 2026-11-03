#!/usr/bin/env bash
# lib/moe_verb.sh — the supervisor's half of `bin/r9700 moe-tune` (E2.S3): the placed files, the merge record, the activation and the dry run. SOURCED by
# bin/r9700 after lib/moe.sh (the units of E2.S2 live there and run as workers; this file holds what the verb itself does, in the supervisor). Bash >= 4.4,
# `set -u` safe, no `set -e`. Nothing here takes the lock or sets a trap: the lock, the restore-first and the one cleanup belong to `supervise`.
#
#   moe_place                                          vendor/benchmark_moe.py and config/coarse_candidates.json into $R9700_WORK_DIR/r9700/, hash-checked
#   moe_dry_run chunk|ab ...                           the resolved container lines (through the worker's own argument builder) and the clear's line
#   moe_merge_verb <outdir> <model> <layer> <base> <chunk>...   a new record merged/<stamp>/ (merge_moe.py), merge.env; nothing replaced
#   moe_activate_verb <outdir> <model> <stamp> <yes|no force>   the one step that changes what a server reads: refused while a server is listed
#   moe_sweep_part_files <dir>                         the stale `.part-<pid>-<ticks>` files of an interrupted activation
#
# The policy (E2 decision 1): a merge writes a new versioned record and replaces nothing; `activate` is explicit, atomic (a part file, fsync, one rename),
# keeps the previous file under merged/previous/ and is refused while a container that may read the exchange folder is listed. Test knob (environment only,
# never machine.env): R9700_TEST_ACTIVATE_HOLD_S, a pause between the part write and the rename, so a test can kill the verb inside that window.

_MOE_NAME_RE='^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$' # an outdir name (--out) and a merge stamp, as the verb takes them

# _moe_part_tag: `<pid>-<start ticks>` of this process, the owner words of a part file (the bash twin of lib/merge_moe.py's); `$$` is the process that
# holds the lock, also inside a command substitution
_moe_part_tag() { printf '%s-%s\n' "$$" "$(proc_ticks "$$")"; }

# _moe_free_stamp <dir> <suffix>: a UTC stamp for which <dir>/<stamp><suffix> does not exist ("-2", "-3" ... when taken in the same second)
_moe_free_stamp() {
  local stamp n=1
  stamp="$(_moe_stamp)"
  while [ -e "$1/$stamp$2" ]; do n=$((n + 1)); stamp="$(_moe_stamp)-$n"; done
  printf '%s\n' "$stamp"
}

# moe_place: the vendored benchmark and the coarse candidates into the placed folder (the shape of series_preflight's harness.py: a .part, then a move), where
# the file is missing or its hash differs; then the hash is checked again. A `required` row of moe_assets is placed when missing; an `optional` one (harness.py,
# placed by `series`) is only REFRESHED when it is present: a copy left by an older series would otherwise fail the identity check of every unit for ever.
# 2 and one line when a file cannot be placed: before anything is stopped. A .part left by a kill is replaced by the next call.
moe_place() {
  local name source need dest want
  while read -r name source need _; do
    dest="$(moe_placed_dir)/$name"
    [ "$need" = required ] || [ -f "$dest" ] || continue
    want="$(_moe_sha "$_MOE_REPO/$source")"
    [ -n "$want" ] || { echo "moe-tune: $source is missing in the repository" >&2; return 2; }
    [ "$(_moe_sha "$dest")" = "$want" ] && continue
    if ! { mkdir -p "${dest%/*}" && cp -- "$_MOE_REPO/$source" "$dest.part" && mv -f -- "$dest.part" "$dest"; } 2> /dev/null; then
      echo "moe-tune: $name cannot be placed in ${dest%/*}" >&2
      return 2
    fi
    [ "$(_moe_sha "$dest")" = "$want" ] || { echo "moe-tune: $name in ${dest%/*} is not $source after it was placed" >&2; return 2; }
  done < <(moe_assets)
}

# _moe_dry_clear: the line of the cache-clear container, the words of moe_cache_clear
_moe_dry_clear() {
  echo "dry-run: $(wslc_argv_text run --rm --name "$(container_name moe-clear)" -v "$R9700_CACHE_VOLUME:/root/.cache/vllm" "$R9700_IMAGE" sh -c "$_MOE_CLEAR_SH")"
}

# moe_dry_run chunk <model> <layer> <search> <chunk> <keys...> | ab <model> <layer> <reps> <keys...>: the resolved container lines, printed through the
# argument builder of the worker (moe_argv), and the clear's line. Nothing is started and nothing is written (the A17 shape).
moe_dry_run() {
  local mode="$1" model="$2" layer="$3" search reps chunk name rep arm
  local -a argv=() extra=()
  shift 3
  case $mode in
    chunk)
      search="$1" chunk="$2"
      shift 2
      [ "$search" = coarse ] && extra=(-e "MOE_TUNE_CANDIDATES=$_MOE_CONTAINER_ROOT/coarse_candidates.json")
      moe_argv argv extra tune "$layer" "$model" "$chunk" "$@" || return 2
      name="$(container_name "moe-tune-$chunk")" || return 2
      echo "dry-run: $(wslc_argv_text run --rm --name "$name" "${argv[@]}")"
      ;;
    ab)
      reps="$1"
      shift
      for ((rep = 1; rep <= reps; rep++)); do
        for arm in default tuned; do
          _moe_ab_arm_envs extra "$arm" "${R9700_TUNED_CONFIG_DIR:-}" "$(moe_container_dir "$model")/merged"
          moe_argv argv extra ab "$layer" "$model" "" "$@" || return 2
          name="$(container_name "moe-ab-$arm-$rep")" || return 2
          echo "dry-run: $(wslc_argv_text run --rm --name "$name" "${argv[@]}")"
        done
      done
      ;;
    *) echo "moe_dry_run: the mode \"$mode\" is not chunk or ab" >&2; return 2 ;;
  esac
  _moe_dry_clear
}

# ---- merge ----
# _moe_merge_layer_check <layer> <chunk dir>...: a chunk whose chunk.env names another layer is refused (an empty layer checks nothing)
_moe_merge_layer_check() {
  local layer="$1" dir got
  shift
  [ -n "$layer" ] || return 0
  for dir in "$@"; do
    [ -f "$dir/chunk.env" ] || continue
    got="$(_moe_env_value "$dir/chunk.env" LAYER)"
    [ -z "$got" ] || [ "$got" = "$layer" ] || { echo "moe-tune: merge: chunk ${dir##*/} is of the layer $got, not $layer (pass --layer $got)" >&2; return 2; }
  done
}

# _moe_merge_base <auto|none|file> <first chunk dir>: sets _MOE_BASE_FILE ("" for none). `auto` is the file of the merged NAME in the model's TUNED_CONFIG_DIR,
# translated by container_host_path (the only container path that can be read from WSL is one under /work): a TUNED_CONFIG_DIR that does not translate REFUSES
# (2; pass --base <file> or --base none), it never silently means "no base". An unset TUNED_CONFIG_DIR is said, and means no base.
_moe_merge_base() {
  local mode="$1" first="$2" tuned="${R9700_TUNED_CONFIG_DIR:-}" file
  local -a found=()
  _MOE_BASE_FILE=""
  case $mode in
    none) return 0 ;;
    auto) ;;
    *)
      [ -f "$mode" ] || { echo "moe-tune: merge: --base $mode is not a file" >&2; return 2; }
      _MOE_BASE_FILE="$mode"
      return 0
      ;;
  esac
  if [ -z "$tuned" ]; then echo "base: TUNED_CONFIG_DIR is not set, no base"; return 0; fi
  file="$(container_host_path "$tuned/x" 2> /dev/null)" || {
    echo "moe-tune: merge: TUNED_CONFIG_DIR $tuned is not under /work, so the production file cannot be read from here: pass --base <file>, or --base none" >&2
    return 2
  }
  found=("$first"/E=*.json)
  [ -f "${found[0]}" ] || return 0 # merge_moe.py names the chunk that holds none
  file="${file%/x}/${found[0]##*/}"
  if [ -f "$file" ]; then _MOE_BASE_FILE="$file"; echo "base: $file"; else echo "base: $file does not exist, no base"; fi
}

# _moe_merge_env <record dir> <chunk names> <layer>: merge.env, written beside and moved (the record's own file is never half there)
_moe_merge_env() {
  local dest="$1" bsha=none
  local -a out=()
  out=("$dest"/E=*.json)
  [ -z "$_MOE_BASE_FILE" ] || bsha="$(_moe_sha "$_MOE_BASE_FILE")"
  {
    _moe_env_line CHUNKS "$2"
    _moe_env_line LAYER "${3:-unknown}"
    _moe_env_line BASE "${_MOE_BASE_FILE:-none}"
    _moe_env_line BASE_SHA256 "$bsha"
    _moe_env_line OUTPUT_SHA256 "$(_moe_sha "${out[0]}")"
    _moe_env_line WRITTEN_AT "$(_moe_iso)"
  } > "$dest/merge.env.part" && mv -T -- "$dest/merge.env.part" "$dest/merge.env"
}

# moe_merge_verb <outdir> <model> <layer> <base> <chunk>...: the merge mode. A new folder merged/<stamp>/ per merge, nothing replaced and the exchange
# folder never touched (which file a server reads is `activate`). The exit code is merge_moe.py's (0, 2).
moe_merge_verb() {
  local outdir="$1" model="$2" layer="$3" base="$4" stamp dest rc chunk hint=""
  local -a dirs=()
  shift 4
  for chunk in "$@"; do dirs+=("$outdir/chunks/$chunk"); done
  _moe_merge_layer_check "$layer" "${dirs[@]}" || return 2
  _moe_merge_base "$base" "${dirs[0]}" || return 2
  stamp="$(_moe_free_stamp "$outdir/merged" "")"
  dest="$outdir/merged/$stamp"
  python3 "$_MOE_LIB/merge_moe.py" merge --out "$dest" ${_MOE_BASE_FILE:+--base "$_MOE_BASE_FILE"} "${dirs[@]}" 9>&-
  rc=$?
  if [ "$rc" -ne 0 ]; then rmdir "$dest" "$outdir/merged" 2> /dev/null; return "$rc"; fi
  _moe_merge_env "$dest" "$*" "${layer:-$(_moe_env_value "${dirs[0]}/chunk.env" LAYER)}" || { echo "moe-tune: merge: merge.env cannot be written in $dest" >&2; return 2; }
  [ "${outdir##*/}" = "moe-$model" ] || hint=" --out ${outdir##*/}"
  echo "merged: $stamp (activate it with: moe-tune activate $model $stamp$hint)"
}

# ---- activate ----
# moe_sweep_part_files <dir>: the stale parts of an interrupted activation. A part names its owner (`.part-<pid>-<start ticks>`); one whose owner is gone is
# removed and said; one whose owner lives, or that names none, is a refusal (2). The bash twin of the sweep in lib/merge_moe.py.
moe_sweep_part_files() {
  local part pid ticks
  for part in "$1"/*.part-*; do
    [ -e "$part" ] || continue
    if ! [[ $part =~ \.part-([0-9]+)-([0-9]+)$ ]]; then
      echo "moe-tune: activate: cannot tell the owner of $part from its name; remove it by hand" >&2
      return 2
    fi
    pid="${BASH_REMATCH[1]}" ticks="${BASH_REMATCH[2]}"
    if [ "$(proc_ticks "$pid")" = "$ticks" ]; then
      echo "moe-tune: activate: another activation is writing $part (pid $pid)" >&2
      return 2
    fi
    rm -f -- "$part" && echo "removed stale $part (owner $pid gone)"
  done
  return 0
}

# _moe_activate_hold <before|after>: the test knobs R9700_TEST_ACTIVATE_HOLD_S (between the part write and the swap) and R9700_TEST_ACTIVATE_HOLD_AFTER_S
# (between the swap and the rename of activate.env), the environment only, never machine.env: ONE sleep (descriptor 9 closed, A1), so that a test can kill the
# verb inside the window; the test kills the verb's whole process group, so the sleeper goes with it.
_moe_activate_hold() {
  local hold
  case $1 in before) hold="${R9700_TEST_ACTIVATE_HOLD_S:-0}" ;; *) hold="${R9700_TEST_ACTIVATE_HOLD_AFTER_S:-0}" ;; esac
  [[ $hold =~ ^[0-9]+$ ]] && [ "$hold" -gt 0 ] || return 0
  sleep "$hold" 9>&-
}

# _moe_activate_record <record dir>: the one E=*.json of a merge record; sets _MOE_REC_FILE. 2 and one line otherwise
_moe_activate_record() {
  local rec="$1"
  local -a found=()
  _MOE_REC_FILE=""
  found=("$rec"/E=*.json)
  [ -f "${found[0]}" ] || { echo "moe-tune: activate: $rec is not a merge record (no E=*.json)" >&2; return 2; }
  if [ "${#found[@]}" -gt 1 ]; then
    echo "moe-tune: activate: $rec holds ${#found[@]} files E=*.json, expected one: ${found[*]##*/}" >&2
    return 2
  fi
  _MOE_REC_FILE="${found[0]}"
}

# _moe_activate_readers: the listed containers that may read the exchange folder (the operator's server, every prefixed one): _MOE_READERS. 1 when the
# list cannot be read. The toolkit cannot see what a container mounts (no wslc inspect verb is verified), so a listed server counts as a reader.
_moe_activate_readers() {
  local listing name
  _MOE_READERS=()
  _rg_run listing wslc_list || return 1 # through _rg_run (A19): a TERM during the call ends the verb at once, not after the call's ceiling
  while read -r name; do
    [ -n "$name" ] || continue
    if [ "$name" = "$R9700_PROD_CONTAINER" ] || { [ -n "$R9700_CONTAINER_PREFIX" ] && [[ $name == "$R9700_CONTAINER_PREFIX"* ]]; }; then _MOE_READERS+=("$name"); fi
  done <<< "$listing"
  return 0
}

# _moe_activate_refusal <exchange merged folder> <yes|no force>: sets _MOE_FORCED. 2 and one line when a server may read the folder and --force is not
# given; with --force the word is logged (the supervisor log) and goes into activate.env
_moe_activate_refusal() {
  local folder="$1" force="$2" names verb=is
  _MOE_FORCED=no
  if ! _moe_activate_readers; then
    if [ "$force" != yes ]; then
      echo "moe-tune: activate: the container list cannot be read, so a server that reads $folder cannot be ruled out; try again, or pass --force" >&2
      return 2
    fi
    _MOE_FORCED=yes
    rg_log "activate: forced while the container list could not be read"
    return 0
  fi
  [ "${#_MOE_READERS[@]}" -gt 0 ] || return 0
  names="${_MOE_READERS[*]}"
  [ "${#_MOE_READERS[@]}" -eq 1 ] || verb=are
  if [ "$force" != yes ]; then
    echo "moe-tune: activate: $names $verb running and may read $folder; stop it, or pass --force" >&2
    return 2
  fi
  _MOE_FORCED=yes
  rg_log "activate: forced while $names running"
}

# _moe_activate_keep <exchange merged folder> <name>: the file now active, copied to previous/<UTC stamp>-<name> before the swap (a copy, never a move
# or a delete); sets _MOE_PREVIOUS (`none` when no file was active)
_moe_activate_keep() {
  local ex="$1" name="$2" stamp part
  _MOE_PREVIOUS=none
  [ -f "$ex/$name" ] || return 0
  mkdir -p "$ex/previous" || return 1
  stamp="$(_moe_free_stamp "$ex/previous" "-$name")"
  part="$ex/previous/$stamp-$name.part-$(_moe_part_tag)"
  { cp -p -- "$ex/$name" "$part" && sync -- "$part" && mv -T -- "$part" "$ex/previous/$stamp-$name"; } 9>&- || { rm -f -- "$part"; return 1; }
  _MOE_PREVIOUS="$ex/previous/$stamp-$name"
}

# _moe_activate_swap <record file> <active file>: the record's bytes to <active>.part-<owner>, fsync, then ONE rename(2) onto <active>: a container that
# opens the file sees the old bytes or the new, never a half. The window between the two is the test knob's.
_moe_activate_swap() {
  local part="$2.part-$(_moe_part_tag)"
  { cp -- "$1" "$part" && sync -- "$part"; } 9>&- || { rm -f -- "$part"; echo "moe-tune: activate: cannot write $part" >&2; return 2; }
  _moe_activate_hold before
  mv -T -- "$part" "$2" 9>&- || { rm -f -- "$part"; echo "moe-tune: activate: cannot move $part onto $2" >&2; return 2; }
}

# _moe_activate_env_part <exchange merged folder> <stamp> <name> <sha256> <previous> <forced> <layer>: activate.env written to a PART beside it (sets _MOE_ENV_PART), BEFORE
# the swap, so that the record of the swap is ready and only a rename is left after it. 1 when it cannot be written.
_moe_activate_env_part() {
  _MOE_ENV_PART="$1/activate.env.part-$(_moe_part_tag)"
  {
    _moe_env_line STAMP "$2"
    _moe_env_line NAME "$3"
    _moe_env_line LAYER "$7"
    _moe_env_line SHA256 "$4"
    _moe_env_line PREVIOUS "$5"
    _moe_env_line ACTIVATED_AT "$(_moe_iso)"
    _moe_env_line FORCED "$6"
  } > "$_MOE_ENV_PART" 2> /dev/null || { rm -f -- "$_MOE_ENV_PART"; return 1; }
}

# _moe_activate_undo <active file>: the swap is done and the record of it cannot be put in place: the state before is restored. The previous file (kept in
# previous/) goes back by the same part-and-rename; with no previous file the new one is removed (it is the one this call made). 0 when restored.
_moe_activate_undo() {
  local part
  if [ "$_MOE_PREVIOUS" = none ]; then rm -f -- "$1"; return $?; fi
  part="$1.part-$(_moe_part_tag)"
  { cp -p -- "$_MOE_PREVIOUS" "$part" && mv -T -- "$part" "$1"; } 9>&- 2> /dev/null || { rm -f -- "$part"; return 1; }
}

# _moe_activate_layer <record dir> <layer argument or "">: the layer of the file to activate, from merge.env (written by `merge`) or from --layer; sets _MOE_ACT_LAYER.
# 2 and one line when none is known, or when the two differ: `ab` finds the file of a layer by this word, so it is never guessed.
_moe_activate_layer() {
  local rec_layer
  rec_layer="$(_moe_env_value "$1/merge.env" LAYER)"
  case $rec_layer in experts | draft) ;; *) rec_layer="" ;; esac
  if [ -n "$2" ] && [ -n "$rec_layer" ] && [ "$2" != "$rec_layer" ]; then
    echo "moe-tune: activate: $1 is a record of the layer $rec_layer, not $2" >&2
    return 2
  fi
  _MOE_ACT_LAYER="${2:-$rec_layer}"
  [ -n "$_MOE_ACT_LAYER" ] || { echo "moe-tune: activate: the layer of $1 is not known (no LAYER in its merge.env): pass --layer experts|draft" >&2; return 2; }
}

# moe_activate_verb <outdir> <model> <stamp> <force: yes|no> [<layer>]: the activate mode. The record merged/<stamp>/ must hold one E=*.json and a known layer; a
# listed server is a reader and the swap is refused unless forced; a leftover activate.env.part of a dead owner whose swap had completed is finished first; stale
# parts are swept; the active file is kept under previous/; activate.env (with the layer: `ab` reads it) is written to a part; the new file is swapped in
# atomically; then activate.env is renamed into place. Recoverable: a failed swap removes the parts and changes nothing; a failed rename of activate.env puts
# the previous file back (or removes the new one when none was active), so the state never says one thing and holds another; a hard kill between the swap and
# the rename is finished by the next activate (or by the start of an A/B). 0, or 2 with one line.
moe_activate_verb() {
  local outdir="$1" model="$2" stamp="$3" force="$4" layer="${5:-}" ex name active sha
  _moe_activate_record "$outdir/merged/$stamp" || return 2
  _moe_activate_layer "$outdir/merged/$stamp" "$layer" || return 2
  layer="$_MOE_ACT_LAYER"
  name="${_MOE_REC_FILE##*/}"
  ex="$(moe_exchange_dir "$model")/merged"
  active="$ex/$name"
  moe_activate_recover "$ex" || true # a leftover that does not match is removed by the sweep below
  if [ "$(_moe_env_value "$ex/activate.env" STAMP)" = "$stamp" ] && [ "$(_moe_env_value "$ex/activate.env" LAYER)" = "$layer" ] && cmp -s "$_MOE_REC_FILE" "$active" 2> /dev/null; then
    echo "activate: $stamp is already active ($active)"
    return 0
  fi
  _moe_activate_refusal "$ex" "$force" || return 2
  mkdir -p "$ex" || { echo "moe-tune: activate: $ex cannot be made" >&2; return 2; }
  moe_sweep_part_files "$ex" || return 2
  moe_sweep_part_files "$ex/previous" || return 2
  _moe_activate_keep "$ex" "$name" || { echo "moe-tune: activate: the previous file cannot be kept under $ex/previous" >&2; return 2; }
  sha="$(_moe_sha "$_MOE_REC_FILE")"
  _moe_activate_env_part "$ex" "$stamp" "$name" "$sha" "$_MOE_PREVIOUS" "$_MOE_FORCED" "$layer" || { echo "moe-tune: activate: activate.env cannot be written in $ex" >&2; return 2; }
  _moe_activate_swap "$_MOE_REC_FILE" "$active" || { rm -f -- "$_MOE_ENV_PART"; return 2; } # a failed swap removes its own part; nothing was changed
  _moe_activate_hold after
  if ! mv -T -- "$_MOE_ENV_PART" "$ex/activate.env" 9>&- 2> /dev/null; then
    rm -f -- "$_MOE_ENV_PART"
    if _moe_activate_undo "$active"; then
      echo "moe-tune: activate: activate.env cannot be written in $ex; the previous file was put back (${_MOE_PREVIOUS})" >&2
    else
      echo "moe-tune: activate: activate.env cannot be written in $ex AND the previous file could not be put back: copy ${_MOE_PREVIOUS} over $active by hand" >&2
    fi
    return 2
  fi
  echo "activated: $active ($stamp, sha256 ${sha:0:12}; previous kept as $_MOE_PREVIOUS)"
}
