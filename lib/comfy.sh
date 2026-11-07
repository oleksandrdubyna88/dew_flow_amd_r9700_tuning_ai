#!/usr/bin/env bash
# lib/comfy.sh — the verb `bin/r9700 comfy <mode>` (E1.S2 of the ComfyUI plan): the operator's own ComfyUI container on the same card as the operator's vLLM server, one owner
# at a time. SOURCED by bin/r9700; defines functions and runs nothing. Bash >= 4.4, `set -u` safe, no `set -e`. Needs lib/config.sh, lib/run_guarded.sh, lib/adapter.sh and
# lib/restore.sh. Messages start `r9700: comfy: <mode>:` on stderr and `comfy: <mode>:` on stdout. Nothing here sets a trap except `comfy start`, which owns its one failure path.
#
#   comfy_modes                   the legal modes, one per line, derived from the functions comfy_mode_<mode> that are defined (never typed)
#   comfy_fetch_name              the name of the fetch container: <COMFY_CONTAINER><_COMFY_FETCH_SUFFIX> (the suffix is lib/config.sh's one constant)
#   comfy_locked <mode> <admit> <body> [args...]   the entry of a mode that takes the lock: the lock (holder word `comfy`), restore_first, the machine config, the
#                                 admission named by <admit>, the body, the release. <admit> is `body` (the body admits itself: `start` decides between a listed ComfyUI,
#                                 a listed vLLM and --stop-vllm) or `card-free` (the entry refuses, before the body, while EITHER the operator's ComfyUI or the operator's
#                                 server is listed: comfy_owners_check, lib/run_guarded.sh). 0 the body's code; 2 a refusal (config, list, owner); 4 the lock is held
#   comfy_volume_ensure <name> <listing>   creates the volume unless it is a whole line of <listing>; stdout `comfy: start: created volume <name>`; 1 and _COMFY_ERR when it fails
#   comfy_tails_prune <keep>      keeps the newest <keep> files <state dir>/comfy-start-<UTC stamp>-<pid>.tail.log, removes the older ones by exact name
#   comfy_mode_start [--stop-vllm] [-- <main.py args>]   the lock, the volumes, the container, the readiness wait; a failed start reconciles against the container list.
#                                 A signal ends the long calls at once (the vLLM stop and the run call go through _rg_run, whose tree is killed by the handler); the other waits
#                                 delay it until the call in flight ends, each bounded by its own ceiling: the container listing tries, the volume list and create and the remove
#                                 calls, and the readiness probe and its sleep
#   comfy_mode_stop               stops the container when it is listed; no lock, no restore
#   comfy_mode_status             prints what can be known; no lock
#
# Exit codes of the modes: 0 done; 1 a stop, a volume, the remove or the run call failed (nothing of ComfyUI is left running), or a state could not be read; 2 a refused
# argument, mode or config, a start beside the operator's listed server without --stop-vllm, a container list that failed three times; 4 another run holds the lock; 5 ComfyUI
# did not become ready (its log tail is saved, it is stopped, the operator's server is restored when this invocation stopped it), or the container list could not be read after
# the launch (nothing is stopped; the line names `comfy stop` and `init`), or the restore beside a listed ComfyUI.
#
# Growth: the tail files of failed starts (comfy_tails_prune is their owner: at most ten stay); the folder <state dir>/restore-comfy-<stamp>-<pid> of a start with --stop-vllm
# is the restore's (restore_dirs_prune, called by `init`, owns it).

_comfy_say() { local mode="$1"; shift; printf 'comfy: %s: %s\n' "$mode" "$*"; }

_comfy_err() { local mode="$1"; shift; printf 'r9700: comfy: %s: %s\n' "$mode" "$*" >&2; }

comfy_modes() { declare -F | awk '{ print $3 }' | grep '^comfy_mode_' | sed 's/^comfy_mode_//' | LC_ALL=C sort; }

comfy_fetch_name() { printf '%s%s\n' "$R9700_COMFY_CONTAINER" "$_COMFY_FETCH_SUFFIX"; }

# comfy_locked <mode> <admit> <body> [args...]: see the header. restore_first may END the process (exit 5 or 11, as in every verb under the lock): the marker stays and the lock
# goes with the process.
comfy_locked() {
  local mode="${1:-}" admit="${2:-}" body="${3:-}" rc
  case $admit in
    body | card-free) ;;
    *) echo "comfy_locked: \"$admit\" is not an admission (body, card-free)" >&2; return 2 ;;
  esac
  shift 3
  lock_take comfy || return $?
  restore_first
  config_load_machine "${R9700_MACHINE_ENV:-./machine.env}" || { lock_release; return 2; }
  if [ "$admit" = card-free ]; then
    # before the body: a build takes minutes, and a refusal after it would be waste
    if ! _rg_listing_tries; then
      _comfy_err "$mode" "the container list failed 3 times ($_RG_LIST_ERR)"
      lock_release
      return 2
    fi
    comfy_owners_check "$_RG_LISTING" || { lock_release; return 2; }
  fi
  "$body" "$@"
  rc=$?
  lock_release
  return "$rc"
}

# comfy_volume_ensure <name> <listing>: a volume the engine lists is left alone (creating one that exists is an error of the engine, so the caller lists first)
comfy_volume_ensure() {
  local name="$1" listing="$2" out rc
  grep -Fxq -- "$name" <<< "$listing" && return 0
  out="$(wslc_volume_create "$name" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    _COMFY_ERR="volume create $name failed (code $rc): ${out##*$'\n'}"
    return 1
  fi
  _comfy_say start "created volume $name"
}

# comfy_tails_prune <keep>: the one retention owner of the tail files of failed starts (the shape of restore_dirs_prune, lib/restore.sh, over files): regular files whose name
# is exactly comfy-start-<stamp>-<pid>.tail.log; the newest <keep> by modification time stay, the others go by exact name
comfy_tails_prune() {
  local keep="$1" dir entry name
  local -a found=()
  dir="$(state_dir)"
  for entry in "$dir"/comfy-start-*.tail.log; do
    [ -f "$entry" ] && [ ! -L "$entry" ] || continue
    name="${entry##*/}"
    [[ $name =~ ^comfy-start-[0-9]{8}T[0-9]{6}Z-[0-9]+\.tail\.log$ ]] || continue
    found+=("$(stat -c '%Y' -- "$entry") $name")
  done
  [ "${#found[@]}" -gt "$keep" ] || return 0
  printf '%s\n' "${found[@]}" | sort -k1,1nr -k2,2r | tail -n "+$((keep + 1))" | while read -r _ name; do
    rm -f -- "${dir:?}/$name"
  done
}

# ---------- start ----------
# comfy_start_args <args...>: sets _COMFY_STOP_VLLM (yes|no) and _COMFY_EXTRA (the words after --, ComfyUI's own); 2 and one line for any other word
comfy_start_args() {
  _COMFY_STOP_VLLM=no
  _COMFY_EXTRA=()
  while [ "$#" -gt 0 ]; do
    case $1 in
      --stop-vllm) _COMFY_STOP_VLLM=yes; shift ;;
      --) shift; _COMFY_EXTRA=("$@"); return 0 ;;
      *) _comfy_err start "unknown argument \"$1\"; legal: --stop-vllm, -- <main.py args>"; return 2 ;;
    esac
  done
}

comfy_mode_start() {
  comfy_start_args "$@" || return 2
  comfy_locked start body comfy_start_body
}

# comfy_start_body: the start under the lock. The traps are set for the whole body and removed before it returns; every failure after the first thing that changes the machine
# goes through comfy_start_fail, the one failure path.
comfy_start_body() {
  local rc
  _COMFY_LAUNCHED=no _COMFY_STOPPED_PROD=no _COMFY_RUN_DIR="" _COMFY_ERR=""
  _RG_CALL_DIR="$(state_dir)" # the long calls below run through _rg_run (in the background, waited for), so that a signal ends them at once; their output files are named here
  trap '_comfy_on_signal INT' INT
  trap '_comfy_on_signal TERM' TERM
  trap '_comfy_on_signal HUP' HUP
  _comfy_start_steps
  rc=$?
  trap - INT TERM HUP
  unset _RG_CALL_DIR
  return "$rc"
}

# _comfy_stop_prod: the stop of the operator's server for --stop-vllm, after the marker is written. 0 stopped; 1 with the reason in _COMFY_ERR. The lesson of _step_stop_prod
# (lib/step.sh): a stop that returns non-zero is not yet a failure, so the list is read again and a server that is gone counts as stopped.
_comfy_stop_prod() {
  local prod="$R9700_PROD_CONTAINER" out rc
  _rg_run out wslc_stop "$prod"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    if ! _rg_listing_tries; then
      _COMFY_ERR="stopping the operator's server $prod failed (code $rc): ${out##*$'\n'}; the container list failed 3 times ($_RG_LIST_ERR), so whether it runs is not known (the marker stays)"
      return 1
    elif grep -Fxq -- "$prod" <<< "$_RG_LISTING"; then
      marker_remove "$(marker_path)" # still listed: nothing is owed, the server is up
      _COMFY_STOPPED_PROD=no
      _COMFY_ERR="stopping the operator's server $prod failed (code $rc): ${out##*$'\n'}"
      return 1
    fi
    _comfy_say start "the stop returned $rc but $prod is gone: counted as stopped"
  fi
  _comfy_say start "stopped the operator's server $prod"
}

# _comfy_start_steps: the steps of the start, in order. 0 ready (or already running); 1 a failed step; 2 a refusal; 5 not ready.
_comfy_start_steps() {
  local name="$R9700_COMFY_CONTAINER" prod="$R9700_PROD_CONTAINER" listing volume out rc stamp
  local -a run_args=()
  # 1. the container list: three tries
  if ! _rg_listing_tries; then
    _comfy_err start "the container list failed 3 times ($_RG_LIST_ERR)"
    return 2
  fi
  listing="$_RG_LISTING"
  # 2. already running
  if grep -Fxq -- "$name" <<< "$listing"; then
    if [ "${#_COMFY_EXTRA[@]}" -gt 0 ]; then
      _comfy_say start "$name is already running, nothing to do (the arguments after -- were not applied)"
    else
      _comfy_say start "$name is already running, nothing to do"
    fi
    return 0
  fi
  # 3. the operator's server holds the card
  if grep -Fxq -- "$prod" <<< "$listing"; then
    if [ "$_COMFY_STOP_VLLM" != yes ]; then
      _comfy_err start "the operator's server $prod is listed and holds the card; pass --stop-vllm, or stop it by hand"
      return 2
    fi
    # 4. --stop-vllm: the marker BEFORE the stop (a hard kill anywhere in the start leaves the debt recorded), then the stop
    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    _COMFY_RUN_DIR="$(state_dir)/restore-comfy-$stamp-$$"
    if ! marker_write_base "$(marker_path)" "comfy-$stamp-$$" yes "$_COMFY_RUN_DIR"; then
      _comfy_err start "the recovery marker cannot be written; nothing was stopped"
      return 2
    fi
    _COMFY_STOPPED_PROD=yes
    if ! _comfy_stop_prod; then
      _comfy_err start "$_COMFY_ERR"
      return 1
    fi
  fi
  # 5. the volumes: list, then create the missing ones, in this order
  out="$(wslc_volume_list 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    comfy_start_fail 1 "the volume list failed (code $rc)${out:+: ${out##*$'\n'}}"
    return $?
  fi
  for volume in "$R9700_COMFY_MODELS_VOLUME" "$R9700_COMFY_DATA_VOLUME" "$R9700_COMFY_CACHE_VOLUME"; do
    comfy_volume_ensure "$volume" "$out" || { comfy_start_fail 1 "$_COMFY_ERR"; return $?; }
  done
  # 6. the growth surface of the failed starts
  comfy_tails_prune 10
  # 7. a stopped container keeps its name until it is removed (the run below always passes --rm, but the hand-made era left stopped ones)
  if out="$(wslc_remove "$name" 2>&1)"; then _comfy_say start "removed the stopped container $name"; fi
  # 8. the launch: the ATTEMPT is recorded before the call, never after it (a detached run under a ceiling: the engine may create the container while the call returns 124,
  #    non-zero, or not at all because a signal cut it)
  run_args=(--gpus all -p "$R9700_COMFY_PORT:8188" -v "$R9700_COMFY_MODELS_VOLUME:/models" -v "$R9700_COMFY_DATA_VOLUME:/data" -v "$R9700_COMFY_CACHE_VOLUME:/cache")
  [ -z "$R9700_COMFY_OUTPUT_WIN" ] || run_args+=(-v "$R9700_COMFY_OUTPUT_WIN:/data/output")
  run_args+=(--shm-size 8g "$R9700_COMFY_IMAGE" "${_COMFY_EXTRA[@]}")
  _COMFY_LAUNCHED=yes
  _rg_run out wslc_run "$name" "${run_args[@]}"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    comfy_start_fail 1 "the run of $name failed (code $rc): ${out##*$'\n'}"
    return $?
  fi
  # 9. the readiness wait: ready_wait with the ComfyUI probe; its line is ours (the prefix - prints none)
  ready_wait "$name" "$R9700_READY_TIMEOUT_S" comfy_probe ready -
  rc=$?
  if [ "$rc" -ne 0 ]; then
    comfy_start_fail 5 "${READY_LINE:-$name is not ready (the readiness wait ended with code $rc)}"
    return $?
  fi
  _comfy_say start "$name ready after $READY_ELAPSED_S s"
  _comfy_say start "$(grep -m1 '^device ' <<< "$READY_ANSWER")"
  _comfy_say start "open http://127.0.0.1:$R9700_COMFY_PORT"
  if [ "$_COMFY_STOPPED_PROD" = yes ]; then
    # the operator asked for the server down: this is the manual workstation mode, and a marker left standing would make every reading verb refuse its restore while ComfyUI runs
    marker_remove "$(marker_path)"
    _COMFY_STOPPED_PROD=no
    _comfy_say start "$prod stays down; start it by hand when ComfyUI is done"
  fi
  return 0
}

# _comfy_save_tail <file>: the last 200 log lines of the container into <file>; an empty file when the engine has no log to give (a container that is gone)
_comfy_save_tail() {
  local name="$R9700_COMFY_CONTAINER"
  wslc_logs "$name" 2> /dev/null | tail -n 200 9>&- > "$1"
  [ "${PIPESTATUS[0]}" -eq 0 ] || : > "$1"
  _comfy_say start "saved the last 200 log lines of $name to $1"
}

# comfy_start_fail <code> <line>: the ONE failure path of the start. Signals are ignored for its whole length (a signal must not cut it in half). Whenever a launch was attempted
# the container LIST decides, never what the launch call returned: listed -> its log tail is saved, it is stopped and found gone; not listed -> nothing to stop (a start that
# was cut while it waited for readiness still saves the tail, which is then empty). Only after ComfyUI is known gone is the operator's server restored (when this invocation
# stopped it): the restore's own guard would otherwise refuse, correctly, and leave the server down with the marker standing and ComfyUI running after a start that reported
# failure. A list that cannot be read stops nothing and leaves the marker. Prints the one stderr line; returns the code (5 when the restore, the stop or the list failed). The lock
# is released by comfy_locked after this returns, last.
comfy_start_fail() {
  local code="$1" line="$2" name="$R9700_COMFY_CONTAINER" known=yes gone=yes tail_file=""
  trap '' INT TERM HUP
  rm -f "$(state_dir)"/.call."$$".* 2> /dev/null # the output of a call that a signal cut
  if [ "${_COMFY_LAUNCHED:-no}" = yes ]; then
    if ! _rg_listing_tries; then
      known=no
    else
      if grep -Fxq -- "$name" <<< "$_RG_LISTING" || [ "$code" = 5 ]; then
        comfy_tails_prune 9 # the file written below is the tenth
        tail_file="$(state_dir)/comfy-start-$(date -u +%Y%m%dT%H%M%SZ)-$$.tail.log"
        _comfy_save_tail "$tail_file"
      fi
      if ! grep -Fxq -- "$name" <<< "$_RG_LISTING"; then
        _comfy_say start "$name is not listed after the failed start; nothing to stop"
      else
        wslc_stop "$name" > /dev/null
        if ! _rg_listing_tries; then
          known=no
        elif grep -Fxq -- "$name" <<< "$_RG_LISTING"; then
          gone=no
        else
          _comfy_say start "stopped $name"
          [ "$code" != 1 ] || line="$line; $name was listed after the failed launch and was stopped"
        fi
      fi
    fi
  fi
  if [ "$known" = no ]; then
    line="$line; the container list failed 3 times ($_RG_LIST_ERR) after the launch: whether $name runs is not known; run bin/r9700 comfy stop, then bin/r9700 init"
    [ "${_COMFY_STOPPED_PROD:-no}" != yes ] || line="$line (the marker stays)"
    code=5
  elif [ "$gone" = no ]; then
    line="$name is still listed after the stop; stop it by hand"
    code=5
  elif [ "${_COMFY_STOPPED_PROD:-no}" = yes ]; then
    restore_from_marker "$(marker_path)" "$_COMFY_RUN_DIR" || code=5 # its own line is already printed; on a failure the marker stays
  fi
  if [ -n "$tail_file" ]; then _comfy_err start "$line; its last 200 log lines are in $tail_file"; else _comfy_err start "$line"; fi
  return "$code"
}

# _comfy_on_signal <INT|TERM|HUP>: the handler of the start. The call in the background (if any) is ended with its whole tree, then the failure path runs, then the lock goes and
# the process exits with the code of the signal (130, 143, 129), whatever the failure path had to say about the restore.
_comfy_on_signal() {
  local code
  trap '' INT TERM HUP
  case $1 in INT) code=130 ;; HUP) code=129 ;; *) code=143 ;; esac
  [ -z "${_RG_SLEEPER:-}" ] || kill "$_RG_SLEEPER" 2> /dev/null
  [ -z "${_RG_BG:-}" ] || _rg_bg_kill
  comfy_start_fail "$code" "interrupted by $1"
  lock_release
  exit "$code"
}

# ---------- stop and status ----------
# _comfy_no_args <mode> <args...>: 2 and one line when the mode got an argument
_comfy_no_args() {
  local mode="$1"
  shift
  [ "$#" -eq 0 ] && return 0
  _comfy_err "$mode" "unexpected argument \"$1\"; $mode takes none"
  return 2
}

comfy_mode_stop() {
  local name out rc
  _comfy_no_args stop "$@" || return 2
  config_load_machine "${R9700_MACHINE_ENV:-./machine.env}" || return 2
  name="$R9700_COMFY_CONTAINER"
  if ! _rg_listing_tries; then
    _comfy_err stop "the container list failed 3 times ($_RG_LIST_ERR)"
    return 1
  fi
  if ! grep -Fxq -- "$name" <<< "$_RG_LISTING"; then
    _comfy_say stop "$name is not running, nothing to do"
    return 0
  fi
  out="$(wslc_stop "$name" 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    _comfy_say stop "stopped $name"
    return 0
  fi
  if ! _rg_listing_tries; then
    _comfy_err stop "$name did not stop (code $rc): ${out##*$'\n'}; the container list failed 3 times ($_RG_LIST_ERR) after it, so whether it runs is not known"
    return 1
  fi
  if ! grep -Fxq -- "$name" <<< "$_RG_LISTING"; then
    _comfy_say stop "the stop returned $rc but $name is gone: counted as stopped"
    return 0
  fi
  _comfy_err stop "$name did not stop (code $rc): ${out##*$'\n'}"
  return 1
}

comfy_mode_status() {
  local status=0 container image created volume out rc
  _comfy_no_args status "$@" || return 2
  config_load_machine "${R9700_MACHINE_ENV:-./machine.env}" || return 2
  image="$R9700_COMFY_IMAGE"
  if _rg_listing_tries; then
    for container in "$R9700_COMFY_CONTAINER" "$R9700_PROD_CONTAINER"; do
      if grep -Fxq -- "$container" <<< "$_RG_LISTING"; then _comfy_say status "$container: running"; else _comfy_say status "$container: not running"; fi
    done
  else
    _comfy_say status "containers: not known ($_RG_LIST_ERR)"
    status=1
  fi
  out="$(wslc_inspect "$image" 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    created="$(sed -n 's/.*"Created": *"\([^"]*\)".*/\1/p' <<< "$out" | head -n 1)"
    if [ -n "$created" ]; then
      _comfy_say status "image $image: created $created"
    else
      _comfy_say status "image $image: created: not known (no Created in the answer)"
      status=1
    fi
  else
    case $rc in
      # a call the ceiling ended (124, 137) or the adapter could not make (10) says nothing about the image: absent is not the same fact as not known
      124 | 137 | 10) _comfy_say status "image $image: created: not known (code $rc)"; status=1 ;;
      *) _comfy_say status "image $image: not present" ;;
    esac
  fi
  out="$(wslc_volume_list 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    _comfy_say status "volumes: not known (code $rc${out:+: ${out%%$'\n'*}})"
    status=1
    return "$status"
  fi
  for volume in "$R9700_COMFY_MODELS_VOLUME" "$R9700_COMFY_DATA_VOLUME" "$R9700_COMFY_CACHE_VOLUME"; do
    if ! grep -Fxq -- "$volume" <<< "$out"; then
      _comfy_say status "volume $volume: absent"
    elif [ "$volume" = "$R9700_COMFY_CACHE_VOLUME" ]; then
      _comfy_say status "volume $volume: present; size: not known (the engine reports no volume size)"
    else
      _comfy_say status "volume $volume: present"
    fi
  done
  return "$status"
}
