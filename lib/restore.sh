#!/usr/bin/env bash
# lib/restore.sh — the recovery marker and the restore of the operator's server. SOURCED; defines functions and runs nothing. Bash >= 4.4,
# `set -u` safe, no `set -e`. Needs lib/config.sh (its value grammar and type checks), lib/adapter.sh and lib/run_guarded.sh. The restore
# needs NO loaded config: the marker carries every value it uses (decision 3), so a broken machine.env cannot block it (decision 4).
#
#   marker_write <file> <KEY=VALUE>...            .part, then mv; a value is bare or in one pair of double quotes; 2 on a value it cannot store
#   marker_read <file>                            parses into the array MARKER; 2 with `marker: <file>:<line>: ...` on the first thing wrong
#   marker_write_base <file> <run id> <yes|no> <run dir>   the first write, BEFORE the stop of the operator's server, from the config
#   marker_add_worker <file> <pgid> <start ticks> the second write: the worker keys and the boot id
#   marker_remove <file>                          after sync
#   marker_run_dir                                where a restore of the marker in MARKER saves its log tails
#   container_stop_all <run dir>                  for every prefixed container: the last 200 lines of its log, then stop
#   ready_wait <container> <timeout s> [<probe function> [<ready word> [<line prefix>]]]   decision 5; 0 ready, 5 not ready (one stderr line).
#                                                 The defaults are the restore's own (restore_probe, the word `completion`, the prefix `r9700: restore:`); the ComfyUI
#                                                 start passes its probe, `ready` and `r9700: comfy: start:` (the prefix `-` prints no line). It sets READY_ANSWER (the
#                                                 probe's whole output on 0, else empty), READY_ELAPSED_S (the production seconds the wait took) and READY_LINE
#                                                 (`<container> not ready after <n> s (<reason>)` on 5, else empty), for a caller that prints its own lines
#   restore_from_marker <marker file> <run dir>   0 restored, 2 marker unreadable, 5 not restored (the marker stays)
#   restore_now                                   restore_from_marker "$MARKER_FILE" "$RUN_DIR" (the supervisor's own path, worker already stopped)
#   restore_first                                 when a marker exists: restore from it before anything else (exits 11 when it cannot be read, or the
#                                                 code of a restore that did not become ready); supervise and the verbs init and verdict call it
#
# The marker is a KEY=VALUE file in the config grammar (no $, no backtick). Keys: MARKER_VERSION RUN_ID WRITTEN_AT PROD_CONTAINER
# PROD_WAS_RUNNING WSLC RESTORE_SHELL RESTORE_SCRIPT_WIN RESTORE_ARGS CONTAINER_PREFIX READY_TIMEOUT_S, then COMFY_CONTAINER (optional: the name of the operator's
# ComfyUI, so that the restore can refuse to start the server beside it without a loaded config; a marker written before E1.S2 has none and restores as it always did), then RUN_DIR (optional: where the
# run's own folder is, so the tails of a restore after a hard kill land beside the run's evidence), then the three worker keys together:
# WORKER_PGID WORKER_START_TICKS BOOT_ID (the worker is `setsid`, so its pid is its process group id and its session id).

declare -gA MARKER=()
_MARKER_ORDER=(MARKER_VERSION RUN_ID WRITTEN_AT PROD_CONTAINER PROD_WAS_RUNNING WSLC RESTORE_SHELL RESTORE_SCRIPT_WIN RESTORE_ARGS CONTAINER_PREFIX READY_TIMEOUT_S COMFY_CONTAINER RUN_DIR WORKER_PGID WORKER_START_TICKS BOOT_ID)
_MARKER_REQUIRED=(MARKER_VERSION RUN_ID WRITTEN_AT PROD_CONTAINER PROD_WAS_RUNNING WSLC RESTORE_SHELL RESTORE_SCRIPT_WIN RESTORE_ARGS CONTAINER_PREFIX READY_TIMEOUT_S)
_MARKER_WORKER=(WORKER_PGID WORKER_START_TICKS BOOT_ID)
_MARKER_RUN_ID_RE='^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'

_marker_has_key() { local k; for k in "${_MARKER_ORDER[@]}"; do [ "$k" = "$1" ] && return 0; done; return 1; }

# _marker_check <key> <value>: 0, or 1 with the problem in _PE
_marker_check() {
  local key="$1" v="$2"
  _PE=""
  case $key in
    MARKER_VERSION) [ "$v" = 1 ] || _PE="\"$v\" is not a marker version this program reads (1)" ;;
    RUN_ID) [[ $v =~ $_MARKER_RUN_ID_RE ]] || _PE="\"$v\" is not a run id (letters, digits, . _ -; at most 64)" ;;
    WRITTEN_AT) [[ $v =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || _PE="\"$v\" is not a UTC time YYYY-MM-DDTHH:MM:SSZ" ;;
    PROD_CONTAINER) _cfg_check name "$v" ;;
    PROD_WAS_RUNNING) _cfg_check enum:yes,no "$v" ;;
    WSLC | RESTORE_SHELL) _cfg_check cmd "$v" ;;
    RESTORE_SCRIPT_WIN) _cfg_check win "$v" ;;
    RESTORE_ARGS) _cfg_check args "$v" && { [[ $v == *[![:space:]]* ]] || _PE="the value is empty or only spaces"; } ;;
    CONTAINER_PREFIX) _cfg_check prefix "$v" ;;
    # wider than the loader's cap (3235, config.sh) on purpose: a marker written by an older version may hold up to 3300 and crash recovery must accept it
    READY_TIMEOUT_S) _cfg_check int:60:3300 "$v" ;;
    COMFY_CONTAINER) _cfg_check name "$v" ;;
    RUN_DIR) [[ $v =~ ^/[^\"\$\`[:cntrl:]]*$ ]] || _PE="\"$v\" is not an absolute path without quotes, \$ or a backtick" ;;
    WORKER_PGID) _cfg_check int:2:999999999 "$v" ;;
    WORKER_START_TICKS) [[ $v =~ ^[0-9]{1,18}$ ]] || _PE="\"$v\" is not a number of clock ticks" ;;
    BOOT_ID) [[ $v =~ ^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$ ]] || _PE="\"$v\" is not a boot id" ;;
  esac
  [ -z "$_PE" ]
}

marker_write() {
  local file="$1" word key value out=""
  shift
  for word in "$@"; do
    if ! [[ $word =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]]; then
      echo "marker: \"${word%%=*}\" is not KEY=VALUE with an UPPER_CASE key" >&2
      return 2
    fi
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    case $value in
      *'"'* | *'$'* | *'`'* | *$'\n'* | *$'\r'*)
        echo "marker: $key: a value with a quote, \$, a backtick or a line break cannot be stored" >&2
        return 2
        ;;
    esac
    case $value in *[[:space:]]*) value="\"$value\"" ;; esac
    out+="$key=$value"$'\n'
  done
  if ! printf '%s' "$out" > "$file.part" 2> /dev/null; then
    rm -f "$file.part"
    echo "marker: cannot write $file.part" >&2
    return 1
  fi
  mv "$file.part" "$file"
}

# _marker_fail <file> <line or ""> <text>: one `marker:` line; returns 2
_marker_fail() {
  if [ -n "$2" ]; then echo "marker: $1:$2: $3" >&2; else echo "marker: $1: $3" >&2; fi
  return 2
}

marker_read() {
  local file="$1" line n=0 key k workers=0
  MARKER=()
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then _marker_fail "$file" "" "cannot read (it is missing or not a readable file)"; return 2; fi
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    [ -n "$line" ] || continue
    if ! [[ $line =~ $_RE_LINE ]]; then _marker_fail "$file" "$n" "not a KEY=VALUE line"; return 2; fi
    key="${BASH_REMATCH[1]}"
    if ! _marker_has_key "$key"; then _marker_fail "$file" "$n" "$key: unknown key"; return 2; fi
    if [ -n "${MARKER[$key]+set}" ]; then _marker_fail "$file" "$n" "$key: given twice"; return 2; fi
    if ! _cfg_value "${BASH_REMATCH[2]}"; then _marker_fail "$file" "$n" "$key: $_PE"; return 2; fi
    if ! _marker_check "$key" "$_PV"; then _marker_fail "$file" "$n" "$key: $_PE"; return 2; fi
    MARKER[$key]="$_PV"
  done < "$file"
  for k in "${_MARKER_REQUIRED[@]}"; do
    [ -n "${MARKER[$k]+set}" ] || { _marker_fail "$file" "" "missing $k"; return 2; }
  done
  for k in "${_MARKER_WORKER[@]}"; do [ -n "${MARKER[$k]+set}" ] && workers=$((workers + 1)); done
  if [ "$workers" -ne 0 ] && [ "$workers" -ne "${#_MARKER_WORKER[@]}" ]; then
    _marker_fail "$file" "" "${_MARKER_WORKER[*]} come together or not at all"
    return 2
  fi
  return 0
}

marker_write_base() {
  local file="$1" run_id="$2" was="$3" run_dir="$4"
  if ! [[ $run_id =~ $_MARKER_RUN_ID_RE ]]; then echo "marker: \"$run_id\" is not a run id" >&2; return 2; fi
  if [ "$was" != yes ] && [ "$was" != no ]; then echo "marker: \"$was\" is not yes or no" >&2; return 2; fi
  local -a exes=()
  mapfile -t exes < <(adapter_marker_words) # WSLC=... and RESTORE_SHELL=...: only the adapter reads those variables
  marker_write "$file" MARKER_VERSION=1 "RUN_ID=$run_id" "WRITTEN_AT=$(date -u +%FT%TZ)" "PROD_CONTAINER=$R9700_PROD_CONTAINER" \
    "PROD_WAS_RUNNING=$was" "${exes[0]}" "${exes[1]}" "RESTORE_SCRIPT_WIN=$R9700_RESTORE_SCRIPT_WIN" \
    "RESTORE_ARGS=$R9700_RESTORE_ARGS" "CONTAINER_PREFIX=$R9700_CONTAINER_PREFIX" "READY_TIMEOUT_S=$R9700_READY_TIMEOUT_S" \
    "COMFY_CONTAINER=$R9700_COMFY_CONTAINER" "RUN_DIR=$run_dir"
}

marker_add_worker() {
  local file="$1" pgid="$2" ticks="$3" key boot
  local -a words=()
  boot="$(cat /proc/sys/kernel/random/boot_id)"
  _marker_check WORKER_PGID "$pgid" || { echo "marker: WORKER_PGID: $_PE" >&2; return 2; }
  _marker_check WORKER_START_TICKS "$ticks" || { echo "marker: WORKER_START_TICKS: $_PE" >&2; return 2; }
  marker_read "$file" || return 2
  for key in "${_MARKER_ORDER[@]}"; do
    case $key in WORKER_PGID | WORKER_START_TICKS | BOOT_ID) continue ;; esac
    [ -n "${MARKER[$key]+set}" ] && words+=("$key=${MARKER[$key]}")
  done
  marker_write "$file" "${words[@]}" "WORKER_PGID=$pgid" "WORKER_START_TICKS=$ticks" "BOOT_ID=$boot"
}

marker_remove() {
  sync "$1" 2> /dev/null
  rm -f "$1"
}

marker_run_dir() {
  if [ -n "${MARKER[RUN_DIR]:-}" ] && [ -d "${MARKER[RUN_DIR]}" ]; then printf '%s\n' "${MARKER[RUN_DIR]}"; return 0; fi
  printf '%s/restore-%s\n' "$(state_dir)" "${MARKER[RUN_ID]}"
}

# container_stop_all <run dir>: every container whose name starts with R9700_CONTAINER_PREFIX (never another one): its log tail is saved
# BEFORE the stop (--rm removes the container with its log). 1 with one `r9700: restore:` line when a list or a stop failed.
container_stop_all() {
  local run="$1" listing name stamp status=0 rc
  if ! listing="$(wslc_list 2>&1)"; then
    echo "r9700: restore: the container list failed (${listing%%$'\n'*})" >&2
    return 1
  fi
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  while read -r name; do
    [[ -n $name && $name == "$R9700_CONTAINER_PREFIX"* ]] || continue
    mkdir -p "$run/guard"
    wslc_logs "$name" 2> /dev/null | tail -n 200 9>&- > "$run/guard/$stamp-$name.tail.log"
    # wslc_stop prints the text of the stop (the step logs it); the restore reports the code only
    wslc_stop "$name" > /dev/null
    rc=$?
    if [ "$rc" -ne 0 ]; then
      echo "r9700: restore: $name did not stop (code $rc)" >&2
      status=1
    fi
  done <<< "$listing"
  return "$status"
}

# ready_wait <container> <timeout s> [<probe function> [<ready word> [<line prefix>]]]: decision 5. The probe (default restore_probe; called with the container's
# name) every 10 s (t_scale) until the window is up; the wait is over when the LAST line of a successful probe is the ready word (default `completion`); a container
# that is not listed three times in a row is reported at once. The window is also an R9700_T_STOP for every call inside it (amendment A13), so the wait ends within
# one grace of its end. The line of a failed wait is `<prefix> <container> not ready after <n> s (<reason>)` on stderr (default prefix `r9700: restore:`; the prefix `-`
# prints none). READY_ANSWER, READY_ELAPSED_S and READY_LINE are set for the caller (see the header).
ready_wait() {
  local prod="${1:-}" limit_s="${2:-}" probe="${3:-restore_probe}" word="${4:-completion}" prefix="${5:-r9700: restore:}"
  local limit interval start now miss=0 last="no probe answered" note="" out rc elapsed n reason R9700_T_STOP
  READY_ANSWER="" READY_ELAPSED_S="" READY_LINE=""
  _adapter_name_ok ready_wait "$prod" || return 2
  [[ $limit_s =~ ^[1-9][0-9]*$ ]] || { echo "ready_wait: \"$limit_s\" is not a number of seconds" >&2; return 2; }
  limit="$(t_scale "$limit_s")" || return 2
  interval="$(t_scale 10)" || return 2
  start="$(date +%s.%N)"
  # The window ends at start + READY_TIMEOUT_S, rounded up to a whole second: every list and probe below is cut by it (amendment A9, A13), and
  # a call refused after it counts as "not ready". The overrun is one grace, not a full sleep, list and probe.
  R9700_T_STOP="$(ceil_seconds "$(awk -v a="$start" -v l="$limit" 'BEGIN { printf "%.3f\n", a + l }')")"
  while :; do
    if out="$(wslc_list 2>&1)" && grep -Fxq -- "$prod" <<< "$out"; then miss=0; else miss=$((miss + 1)); fi
    if [ "$miss" -ge 3 ]; then last="$prod not listed 3 times in a row"; break; fi
    out="$("$probe" "$prod" 2>&1)"
    rc=$?
    if [ "$rc" -eq 0 ] && [ "${out##*$'\n'}" = "$word" ]; then
      READY_ANSWER="$out"
      READY_ELAPSED_S="$(_restore_elapsed "$start")"
      return 0
    fi
    # A call the window refused or cut says nothing about the server: it is a NOTE next to the last real answer, never a replacement.
    if [ -z "${out##*$'\n'}" ]; then
      if [ "$rc" = 124 ] || [ "$rc" = 137 ]; then note="the probe timed out"; else note="the probe failed (code $rc)"; fi
    elif [[ ${out##*$'\n'} == 'adapter: R9700_T_STOP passed'* ]]; then
      note="the readiness window ended"
    else
      last="${out##*$'\n'}"
      note=""
    fi
    now="$(date +%s.%N)"
    elapsed="$(awk -v a="$start" -v b="$now" 'BEGIN { print b - a }')"
    awk -v e="$elapsed" -v l="$limit" 'BEGIN { exit !(e >= l) }' && break
    # the sleep never runs past the window, and the window's end is the end of the wait (A13)
    sleep_in_window "$(awk -v a="$start" -v l="$limit" 'BEGIN { printf "%.3f\n", a + l }')" "$interval" || break
  done
  READY_ELAPSED_S="$(_restore_elapsed "$start")"
  n="$READY_ELAPSED_S"
  if [ -z "$note" ]; then reason="$last"; elif [ "$last" = "no probe answered" ]; then reason="$note"; else reason="$note; last answer: $last"; fi
  READY_LINE="$prod not ready after $n s ($reason)"
  [ "$prefix" = - ] || echo "$prefix $READY_LINE" >&2
  return 5
}

# worker_stop_recorded: stops the worker session the marker in MARKER names, but only when the process is provably the one the supervisor
# started: the same boot, and a leader with the recorded start ticks, or no leader at all (a leader that ended cannot have its pid reused
# while its session has members; an unrelated process with that pid would be a live leader with other ticks). By SESSION (amendment A8):
# the adapter calls of the worker run in process groups of their own.
worker_stop_recorded() {
  local sid="${MARKER[WORKER_PGID]:-}" now
  [ -n "$sid" ] || return 0
  if [ "${MARKER[BOOT_ID]}" != "$(cat /proc/sys/kernel/random/boot_id)" ]; then
    echo "restore: worker $sid is from another boot: not stopped"
    return 0
  fi
  now="$(proc_ticks "$sid")"
  if [ -n "$now" ] && [ "$now" != "${MARKER[WORKER_START_TICKS]}" ]; then
    echo "restore: pid $sid is another process now (other start ticks): not stopped"
    return 0
  fi
  [ -n "$(session_pids "$sid")" ] || return 0
  session_stop "$sid"
  echo "restore: stopped worker session $sid"
}

_RESTORE_LISTING=""

# _restore_elapsed <start epoch.ns>: the seconds since <start> in production seconds (the scale is undone), rounded
_restore_elapsed() {
  awk -v a="$1" -v b="$(date +%s.%N)" -v k="${R9700_TIME_SCALE:-1}" 'BEGIN { printf "%d", (b - a) * k + 0.5 }'
}

# _restore_prepare <prod> <run dir>: stops every prefixed container (log tails first), and answers the list the server start needs, with up to 3
# tries, t_scale 10 s apart (A22): a transient fault of wslc must not leave the operator's server down. Only after the third failure the contract
# line `r9700: restore: <prod> not ready after <n> s (<reason>)` and 5. The listing of the last answer is in _RESTORE_LISTING.
_restore_prepare() {
  local prod="$1" run="$2" start err rc i
  start="$(date +%s.%N)"
  for i in 1 2 3; do
    err="$(container_stop_all "$run" 2>&1)"
    rc=$?
    if [ "$rc" -eq 0 ] && _RESTORE_LISTING="$(wslc_list 2>&1)"; then return 0; fi
    if [ "$rc" -eq 0 ]; then err="r9700: restore: the container list failed (${_RESTORE_LISTING%%$'\n'*})"; fi
    [ "$i" -lt 3 ] && sleep "$(t_scale 10)" 9>&-
  done
  err="${err%%$'\n'*}"
  echo "r9700: restore: $prod not ready after $(_restore_elapsed "$start") s (${err#r9700: restore: })" >&2
  return 5
}

# _restore_server <prod>: start the operator's server unless it is listed (in _RESTORE_LISTING, the answer of _restore_prepare), then wait until it
# is ready; 5 with the one line otherwise
_restore_server() {
  local prod="$1" out="$_RESTORE_LISTING"
  if grep -Fxq -- "$prod" <<< "$out"; then
    echo "restore: $prod already running"
  else
    echo "restore: starting $prod with $R9700_RESTORE_SCRIPT_WIN"
    if ! out="$(restore_start 2>&1)"; then
      echo "r9700: restore: $prod not ready after 0 s (restore start failed: ${out##*$'\n'})" >&2
      return 5
    fi
    printf '%s\n' "$out"
  fi
  ready_wait "$prod" "$R9700_READY_TIMEOUT_S"
}

# _restore_comfy_free <prod>: the restore's own half of "one owner of the card" (E1.S2). 0 when the marker names no ComfyUI (a marker written before this key existed), its
# container is not a whole line of the listing the preparation just read (_RESTORE_LISTING), or the server itself is listed (nothing would be started); else the one line below on stderr and 5: the server is NOT started beside the
# operator's ComfyUI, the marker stays, the next verb after `comfy stop` restores. Config-free, like every value of the restore: the name comes from the marker.
_restore_comfy_free() {
  local prod="$1" comfy="${MARKER[COMFY_CONTAINER]:-}"
  [ -n "$comfy" ] || return 0
  grep -Fxq -- "$comfy" <<< "$_RESTORE_LISTING" || return 0
  grep -Fxq -- "$prod" <<< "$_RESTORE_LISTING" && return 0 # the server is listed too: nothing would be started, and "not started" would be false
  echo "r9700: restore: $prod not started: the operator's ComfyUI ($comfy) is listed; run bin/r9700 comfy stop, then any verb restores $prod (the marker stays)" >&2
  return 5
}

restore_from_marker() {
  local marker="$1" run="$2"
  marker_read "$marker" || return 2
  # The marker's values, not the config's, for the whole restore; and no run deadline (the cleanup phase has none, decision 8).
  local R9700_WSLC="${MARKER[WSLC]}" R9700_RESTORE_SHELL="${MARKER[RESTORE_SHELL]}" R9700_RESTORE_SCRIPT_WIN="${MARKER[RESTORE_SCRIPT_WIN]}"
  local R9700_RESTORE_ARGS="${MARKER[RESTORE_ARGS]}" R9700_CONTAINER_PREFIX="${MARKER[CONTAINER_PREFIX]}" R9700_T_STOP=""
  local R9700_READY_TIMEOUT_S="${MARKER[READY_TIMEOUT_S]}" prod="${MARKER[PROD_CONTAINER]}" was="${MARKER[PROD_WAS_RUNNING]}"
  worker_stop_recorded
  _restore_prepare "$prod" "$run" || return 5
  if [ "$was" = yes ]; then
    _restore_comfy_free "$prod" || return 5
    _restore_server "$prod" || return 5
  fi
  marker_remove "$marker"
}

# restore_dirs_prune <keep>: the folders `<state dir>/restore-<run id>` hold the log tails of restores after a hard kill; this keeps the newest
# <keep> by modification time and removes the older ones, each by its exact name: a real folder (not a link) whose name is `restore-` and
# a run id, never a prefix match on its own. The one retention owner of that growth surface (`init` calls it).
restore_dirs_prune() {
  local keep="$1" dir entry name
  local -a found=()
  dir="$(state_dir)"
  for entry in "$dir"/restore-*; do
    [ -d "$entry" ] && [ ! -L "$entry" ] || continue
    name="${entry##*/}"
    [[ ${name#restore-} =~ $_MARKER_RUN_ID_RE ]] || continue
    found+=("$(stat -c '%Y' -- "$entry") $name")
  done
  [ "${#found[@]}" -gt "$keep" ] || return 0
  printf '%s\n' "${found[@]}" | sort -rn | tail -n "+$((keep + 1))" | while read -r _ name; do
    rm -rf -- "${dir:?}/$name"
  done
}

restore_now() {
  if [ -z "${RUN_DIR:-}" ]; then echo "restore_now: RUN_DIR is not set" >&2; return 2; fi
  restore_from_marker "${MARKER_FILE:-$(marker_path)}" "$RUN_DIR"
}

# restore_first: when a recovery marker exists, restore from it before anything else (the previous run was killed). Needs no config.
# A marker that cannot be read is exit 11 with its remedy: nothing can say what to restore, and a person must look at the server.
restore_first() {
  local marker rc
  marker="$(marker_path)"
  [ -f "$marker" ] || return 0
  if ! marker_read "$marker"; then marker_unreadable "$marker"; fi
  echo "r9700: recovery marker found (run ${MARKER[RUN_ID]}), restoring first"
  restore_from_marker "$marker" "$(marker_run_dir)"
  rc=$?
  [ "$rc" -ne 2 ] || marker_unreadable "$marker"
  [ "$rc" -eq 0 ] || exit "$rc"
}

marker_unreadable() {
  echo "r9700: recovery marker $1 is unreadable: check the operator's server by hand, then remove $1" >&2
  exit 11
}
