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
#   comfy_volume_ensure <name> <listing> [<mode>]   creates the volume unless it is a whole line of <listing>; stdout `comfy: <mode>: created volume <name>` (mode default start); 1 and _COMFY_ERR when it fails
#   comfy_tails_prune <keep>      keeps the newest <keep> files <state dir>/comfy-start-<UTC stamp>-<pid>.tail.log, removes the older ones by exact name
#   comfy_mode_start [--stop-vllm] [-- <main.py args>]   the lock, the volumes, the container, the readiness wait; a failed start reconciles against the container list.
#                                 A signal ends the long calls at once (the vLLM stop and the run call go through _rg_run, whose tree is killed by the handler); the other waits
#                                 delay it until the call in flight ends, each bounded by its own ceiling: the container listing tries, the volume list and create and the remove
#                                 calls, and the readiness probe and its sleep
#   comfy_mode_stop               stops the container when it is listed; no lock, no restore
#   comfy_mode_build [--no-cache]   (E1.S3) the image from the repository: the card-free entry, the placement of comfyui/, a build to a STAMPED tag <repository of COMFY_IMAGE>:<UTC stamp>, the
#                                 check of that tag by a throwaway container on the card, the promotion of COMFY_IMAGE only after the check, the retention of the newest four stamped tags
#   comfy_mode_fetch <set>...     (E1.S3) the pinned model sets of comfyui/models.conf into the models volume: its own lock (<state dir>/comfy-fetch.lock, never the GPU lock), no card
#   comfy_assets                  the three files of comfyui/ the placement (moe_place) copies into $WORK_DIR/r9700/comfyui/, hash-checked
#   comfy_win_dir                 the Windows spelling of that folder: <WORK_DIR_WIN without a trailing \>\r9700\comfyui
#   comfy_models_conf             ${R9700_COMFY_MODELS_CONF:-<repository>/comfyui/models.conf} (a test knob, the shape of series_arms_conf)
#   comfy_models_load <file>      parses models.conf: 0 and the arrays _COMFY_M_SET/_DIR/_URL/_SHA in file order; 2 with `r9700: comfy: <file>:<line>: <problem>` for every bad line
#   comfy_sets                    the set names of the loaded file, file order, each once
#   comfy_build_stamp             the UTC stamp of a build (R9700_TEST_COMFY_STAMP, a test knob, replaces the clock); 2 when it is not a stamp
#   comfy_images_prune <repository> <stamped tag>   the retention: after a passed build, the stamped tags beyond the newest four are removed by their exact names
#   comfy_mode_status             prints what can be known; no lock
#
# Exit codes of the modes (build and fetch: bin/r9700 holds the whole table): 0 done; 1 a stop, a volume, the remove or the run call failed (nothing of ComfyUI is left running), or a state could not be read; 2 a refused
# argument, mode or config, a start beside the operator's listed server without --stop-vllm, a container list that failed three times; 4 another run holds the lock; 5 ComfyUI
# did not become ready (its log tail is saved, it is stopped, the operator's server is restored when this invocation stopped it), or the container list could not be read after
# the launch (nothing is stopped; the line names `comfy stop` and `init`), or the restore beside a listed ComfyUI.
#
# Growth: the volume COMFY_MODELS_VOLUME and the store (the operator removes them), the placed copies of comfyui/ (rewritten when the repository's file changes), the stamped images of COMFY_IMAGE's
# repository (comfy_images_prune keeps the newest four), the fetch lock file (one line); the tail files of failed starts (comfy_tails_prune is their owner: at most ten stay); the folder <state dir>/restore-comfy-<stamp>-<pid> of a start with --stop-vllm
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

# comfy_volume_ensure <name> <listing> [<mode>]: a volume the engine lists is left alone (creating one that exists is an error of the engine, so the caller lists first)
comfy_volume_ensure() {
  local name="$1" listing="$2" mode="${3:-start}" out rc
  grep -Fxq -- "$name" <<< "$listing" && return 0
  out="$(wslc_volume_create "$name" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    _COMFY_ERR="volume create $name failed (code $rc): ${out##*$'\n'}"
    return 1
  fi
  _comfy_say "$mode" "created volume $name"
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

# ---------- the image and the model sets (E1.S3) ----------
_COMFY_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_COMFY_REPO="$(dirname "$_COMFY_LIB")"
_COMFY_STAMP_RE='^[0-9]{8}T[0-9]{6}Z$' # a build stamp, YYYYMMDDTHHMMSSZ, UTC: its text order is its time order, so the retention sorts the TAG (the engine's CREATED is relative words)
_COMFY_IMAGES_KEEP=4                   # the current image plus three to roll back to: the rollback depth of development-workflow, and the retention IS that trail
_COMFY_CHECK_MAX_S=600                 # the ceiling of the check container
_COMFY_CONTAINER_DIR=/work/r9700/comfyui # where the placed folder is seen inside the fetch container: WORK_DIR_WIN is mounted at /work

# The program of the check container: stdlib and torch, no variable in it. Exactly four lines (an exception adds an `error` line): `torch <version>`, `hip <torch.version.hip>`,
# `device <name or none>`, `matmul ok|nan` (a 1024x1024 fp16 x @ x on the device, its float sum finite). It exits 1 when hip is None, no device is there or the sum is not finite.
_COMFY_CHECK_PY='import sys
import torch

hip = torch.version.hip
device, matmul, error = "none", "nan", None
try:
    if torch.cuda.is_available():
        device = torch.cuda.get_device_name(0) or "none"
        x = torch.randn(1024, 1024, device="cuda", dtype=torch.float16)
        total = float((x @ x).float().sum())
        matmul = "ok" if total - total == 0 else "nan"
except Exception as exc:
    error = type(exc).__name__
print("torch " + torch.__version__)
print("hip " + str(hip))
print("device " + device)
print("matmul " + matmul)
if error:
    print("error " + error)
sys.exit(0 if hip is not None and device != "none" and matmul == "ok" else 1)'

comfy_assets() {
  printf '%s\n' \
    "comfyui/Containerfile comfyui/Containerfile required" \
    "comfyui/entrypoint.sh comfyui/entrypoint.sh required" \
    "comfyui/fetch_model.sh comfyui/fetch_model.sh required"
}

comfy_win_dir() { printf '%s\\r9700\\comfyui\n' "${R9700_WORK_DIR_WIN%\\}"; }

comfy_models_conf() { printf '%s\n' "${R9700_COMFY_MODELS_CONF:-$_COMFY_REPO/comfyui/models.conf}"; }

# The ONE rule of a model url and of the file name made from it, shared with comfyui/fetch_model.sh (which repeats these two lines: it runs inside the image and cannot source this file; tests/test_comfy_fetch_model.sh
# FM10 and tests/test_comfy.sh MC2 feed both the same hostile shapes). A url is https, with no quote, backslash, backtick, bracket, brace or blank (curl would expand [] and {} as a glob, and a quote or a blank
# splits a word somewhere); the file name is the last part of the url path before any ? or #, made by ${path##*/} (so a trailing / gives an empty name), and is letters, digits, . _ - starting with a
# letter or digit: never `.`, `..` or a leading `-`, so the store and models paths below a folder can never leave it.
_COMFY_URL_RE='^https://[^][{}"\`[:space:]]+$'
_COMFY_FILE_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$'

_comfy_conf_err() { printf 'r9700: comfy: %s:%s: %s\n' "$1" "$2" "$3" >&2; }

# comfy_models_load <file>: every problem of every line, with its place, in one pass; 2 when there is one. On 0 the arrays are the lines in file order. Called in the caller's own shell.
comfy_models_load() {
  local file="${1:-}" line n=0 bad=0 set dir url sha name key
  local -a words=()
  local -A first=()
  _COMFY_M_SET=() _COMFY_M_DIR=() _COMFY_M_URL=() _COMFY_M_SHA=()
  if [ ! -r "$file" ]; then
    printf 'r9700: comfy: %s: cannot be read\n' "$file" >&2
    return 2
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
    read -r -a words <<< "$line"
    if [ "${#words[@]}" -ne 4 ]; then
      _comfy_conf_err "$file" "$n" "a line has four words (set, folder, url, sha256), this one has ${#words[@]}"
      bad=1
      continue
    fi
    set="${words[0]}" dir="${words[1]}" url="${words[2]}" sha="${words[3]}"
    name="${url%%[?#]*}"
    name="${name##*/}"
    [[ $set =~ ^[a-z0-9]+$ ]] || { _comfy_conf_err "$file" "$n" "the set \"$set\" is not lower-case letters and digits"; bad=1; }
    [[ $dir =~ ^[a-z_]+$ ]] || { _comfy_conf_err "$file" "$n" "the folder \"$dir\" is not lower-case letters and _"; bad=1; }
    [[ $url =~ $_COMFY_URL_RE ]] || { _comfy_conf_err "$file" "$n" "the url is not an https:// address without a quote, backslash, backtick, bracket, brace or blank"; bad=1; }
    [[ $name =~ $_COMFY_FILE_RE ]] || { _comfy_conf_err "$file" "$n" "the file name \"$name\" (the last part of the url path) is not letters, digits, . _ - starting with a letter or digit"; bad=1; }
    [[ $sha =~ ^[0-9a-f]{64}$ ]] || { _comfy_conf_err "$file" "$n" "the sha256 is not 64 lower-case hex characters"; bad=1; }
    key="$dir/$name"
    if [ -n "${first[$key]+set}" ]; then
      _comfy_conf_err "$file" "$n" "$key is there twice (first at line ${first[$key]})"
      bad=1
    else
      first[$key]="$n"
    fi
    _COMFY_M_SET+=("$set") _COMFY_M_DIR+=("$dir") _COMFY_M_URL+=("$url") _COMFY_M_SHA+=("$sha")
  done < "$file"
  [ "$bad" -eq 0 ] || return 2
  if [ "${#_COMFY_M_SET[@]}" -eq 0 ]; then
    printf 'r9700: comfy: %s: holds no set\n' "$file" >&2
    return 2
  fi
}

# comfy_sets: the set names of the file comfy_models_load read, in file order, each once
comfy_sets() {
  [ "${#_COMFY_M_SET[@]}" -gt 0 ] || return 0
  printf '%s\n' "${_COMFY_M_SET[@]}" | awk '!seen[$0]++'
}

comfy_build_stamp() {
  local stamp="${R9700_TEST_COMFY_STAMP:-$(date -u +%Y%m%dT%H%M%SZ 9>&-)}"
  if ! [[ $stamp =~ $_COMFY_STAMP_RE ]]; then
    _comfy_err build "R9700_TEST_COMFY_STAMP \"$stamp\" is not a build stamp (YYYYMMDDTHHMMSSZ)"
    return 2
  fi
  printf '%s\n' "$stamp"
}

# _comfy_row_id <listing> <repository> <tag>: the id of the row `<repository> <tag> <id>` of an image listing; nothing and 1 when there is none
_comfy_row_id() { awk -v r="$2" -v t="$3" '$1 == r && $2 == t { print $3; f = 1; exit } END { exit !f }' <<< "$1"; }

# ---------- build ----------
comfy_mode_build() {
  local arg
  for arg in "$@"; do
    if [ "$arg" != --no-cache ]; then
      _comfy_err build "unknown argument \"$arg\"; legal: --no-cache"
      return 2
    fi
  done
  comfy_locked build card-free comfy_build_body "$@"
}

# comfy_build_reject <line>: the one failure path of the build. The rejected STAMPED tag goes, by its exact name, and nothing else: a tag that is not a row of the list was never made
# (a failed build normally tags nothing); a row on the id COMFY_IMAGE names is kept (a cached rebuild of the same image); a list that cannot be read decides nothing. Prints the one stderr line; 1.
comfy_build_reject() {
  local line="$1" out rc
  if ! _rg_listing_tries wslc_image_list; then
    line="$line; whether $_COMFY_B_STAMPED was tagged is not known (the image list failed): remove it by hand if the list shows it"
  elif _comfy_row_id "$_RG_LISTING" "$_COMFY_B_REPO" "${_COMFY_B_STAMPED##*:}" > /dev/null; then
    if [ -n "$_COMFY_B_CUR_ID" ] && [ "$(_comfy_row_id "$_RG_LISTING" "$_COMFY_B_REPO" "${_COMFY_B_STAMPED##*:}")" = "$_COMFY_B_CUR_ID" ]; then
      line="$line; $_COMFY_B_STAMPED is the image $R9700_COMFY_IMAGE already names; kept"
    else
      out="$(wslc_rmi "$_COMFY_B_STAMPED" 2>&1)"
      rc=$?
      [ "$rc" -eq 0 ] || line="$line; $_COMFY_B_STAMPED could not be removed (code $rc): remove it by hand"
    fi
  fi
  _comfy_err build "$line"
  return 1
}

# _comfy_check_why <output> <rc>: what is wrong with the check container's answer; nothing (and 0) when the image is usable. The ARTEFACT is judged: a zero exit code alone is not enough.
_comfy_check_why() {
  local out="$1" rc="$2" word
  for word in "hip:hip None" "device:device none"; do
    if ! grep -q "^${word%%:*} " <<< "$out"; then printf 'the check printed no %s line (its last line: %s)\n' "${word%%:*}" "$(tail -n 1 <<< "$out")"; return 1; fi
    if grep -qx "${word#*:}" <<< "$out"; then printf '%s\n' "${word#*:}"; return 1; fi
  done
  if ! grep -qx 'matmul ok' <<< "$out"; then printf '%s\n' "$(grep -m1 '^matmul ' <<< "$out" || echo 'the check printed no matmul ok line')"; return 1; fi
  case $rc in
    0) return 0 ;;
    124 | 137) printf 'the check was ended by its ceiling of %s s\n' "$_COMFY_CHECK_MAX_S" ;;
    *) printf 'the check exited with code %s: %s\n' "$rc" "$(tail -n 1 <<< "$out")" ;;
  esac
  return 1
}

# comfy_build_body: the build under the entry's lock, after the admission (the entry has refused a listed ComfyUI or server already). See the header for the order of the steps.
comfy_build_body() {
  local tag stamp why out rc listing win device no_cache=no
  local -a extra=()
  for tag in "$@"; do [ "$tag" != --no-cache ] || no_cache=yes; done
  _COMFY_B_REPO="${R9700_COMFY_IMAGE%:*}" _COMFY_B_CUR_ID="" _COMFY_B_STAMPED=""
  tag="${R9700_COMFY_IMAGE##*:}"
  if [[ $tag =~ $_COMFY_STAMP_RE ]]; then
    _comfy_err build "COMFY_IMAGE's tag \"$tag\" has the shape of a build stamp; give it another tag"
    return 2
  fi
  stamp="$(comfy_build_stamp)" || return 2
  _COMFY_B_STAMPED="$_COMFY_B_REPO:$stamp"
  local _MOE_PLACED_BY=comfy # local: it names the verb in a placement refusal and must not leak
  moe_place comfy_assets || return 2
  if ! _rg_listing_tries wslc_image_list; then
    _comfy_err build "the image list failed 3 times ($_RG_LIST_ERR); nothing was built"
    return 1
  fi
  listing="$_RG_LISTING"
  if _comfy_row_id "$listing" "$_COMFY_B_REPO" "$stamp" > /dev/null; then
    _comfy_err build "the tag $_COMFY_B_STAMPED exists already; nothing was built"
    return 1
  fi
  _COMFY_B_CUR_ID="$(_comfy_row_id "$listing" "$_COMFY_B_REPO" "$tag")"
  win="$(comfy_win_dir)"
  [ "$no_cache" = no ] || extra=(--no-cache)
  # the STAMPED tag, never COMFY_IMAGE: a fixed tag moved by every build left three untagged 27.3 GB images on the operator's PC (observed 2026-11-07). BASE and COMFYUI_REF were validated
  # when the config was loaded (an image reference, a git tag word): neither can hold a space or start with -
  wslc_build "$R9700_COMFY_BUILD_MAX_S" -t "$_COMFY_B_STAMPED" -f "$win\\Containerfile" --build-arg "BASE=$R9700_COMFY_BASE_IMAGE" --build-arg "COMFYUI_REF=$R9700_COMFY_REF" "${extra[@]}" "$win"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    case $rc in
      124 | 137) comfy_build_reject "the build failed (timeout after $R9700_COMFY_BUILD_MAX_S s: the ceiling ended it)" ;;
      *) comfy_build_reject "the build failed (code $rc)" ;;
    esac
    return 1
  fi
  out="$(wslc_run_once "$_COMFY_CHECK_MAX_S" --name "$(container_name comfy-check)" --gpus all --entrypoint python3 "$_COMFY_B_STAMPED" -c "$_COMFY_CHECK_PY" 2>&1)"
  rc=$?
  if why="$(_comfy_check_why "$out" "$rc")"; then :; else
    comfy_build_reject "the built image $_COMFY_B_STAMPED is not usable on the card: $why; $R9700_COMFY_IMAGE was not moved"
    return 1
  fi
  # the promotion, only now; a failure keeps the passed tag: a good image, one hand command from being current
  device="$(grep -m1 '^device ' <<< "$out" | cut -d' ' -f2-)"
  out="$(wslc_tag "$_COMFY_B_STAMPED" "$R9700_COMFY_IMAGE" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    _comfy_err build "$_COMFY_B_STAMPED passed its check but $R9700_COMFY_IMAGE was not moved (code $rc): ${out##*$'\n'}; tag it by hand (README, ComfyUI)"
    return 1
  fi
  _comfy_say build "device $device"
  _comfy_say build "$R9700_COMFY_IMAGE now names $_COMFY_B_STAMPED"
  comfy_images_prune "$_COMFY_B_REPO" "$_COMFY_B_STAMPED"
  return 0
}

# comfy_images_prune <repository> <new stamped tag>: the retention, never before the promotion and never on a view it cannot trust (retention must never empty the shelf). The candidates are
# the rows of THIS repository whose tag is a build stamp (another repository, an untagged row and a tag of another shape are not ours), newest first by the tag; the newest four stay; an older
# one on the id COMFY_IMAGE names stays (a cached rebuild has the id of an older build; whether the engine's rmi of a shared id only untags is not observed, so it is never asked); the others
# go one exact tag per call. Returns 0 whatever it reports: the new image passed and is current, and the next build's retention catches up.
comfy_images_prune() {
  local repo="$1" new="$2" new_id cur_id tag id out rc
  local -a old=()
  if ! _rg_listing_tries wslc_image_list; then
    _comfy_err build "warning: the image list failed 3 times ($_RG_LIST_ERR); no old image was removed"
    return 0
  fi
  if ! _comfy_row_id "$_RG_LISTING" "$repo" "${new##*:}" > /dev/null; then
    _comfy_err build "warning: the image list does not show $new; no old image was removed"
    return 0
  fi
  # the guard that spares the image COMFY_IMAGE names needs that row: a view without it, or with it on another image than the promoted one, is not a view to remove on
  new_id="$(_comfy_row_id "$_RG_LISTING" "$repo" "${new##*:}")"
  cur_id="$(_comfy_row_id "$_RG_LISTING" "$repo" "${R9700_COMFY_IMAGE##*:}")"
  if [ -z "$cur_id" ] || [ "$cur_id" != "$new_id" ]; then
    _comfy_err build "warning: the image list does not show $R9700_COMFY_IMAGE on $new; no old image was removed"
    return 0
  fi
  mapfile -t old < <(awk -v r="$repo" '$1 == r { print $2 }' <<< "$_RG_LISTING" | grep -E "$_COMFY_STAMP_RE" | LC_ALL=C sort -r | tail -n "+$((_COMFY_IMAGES_KEEP + 1))")
  for tag in "${old[@]}"; do
    [ "$tag" != "${new##*:}" ] || continue # never the tag just promoted, whatever the sort says
    id="$(_comfy_row_id "$_RG_LISTING" "$repo" "$tag")"
    if [ -n "$cur_id" ] && [ "$id" = "$cur_id" ]; then
      _comfy_say build "kept $repo:$tag: it is the image $R9700_COMFY_IMAGE names"
      continue
    fi
    out="$(wslc_rmi "$repo:$tag" 2>&1)"
    rc=$?
    if [ "$rc" -eq 0 ]; then
      _comfy_say build "removed $repo:$tag"
    else
      _comfy_err build "warning: $repo:$tag could not be removed (code $rc): ${out##*$'\n'}"
    fi
  done
  return 0
}

# ---------- fetch ----------
# comfy_fetch_triples <set>...: sets _COMFY_TRIPLES to the `<folder> <url> <sha256>` words of the sets in the order given, each file once, file order inside a set
comfy_fetch_triples() {
  local set i
  local -A done_set=()
  _COMFY_TRIPLES=()
  for set in "$@"; do
    [ -z "${done_set[$set]+set}" ] || continue
    done_set[$set]=1
    for i in "${!_COMFY_M_SET[@]}"; do
      [ "${_COMFY_M_SET[$i]}" = "$set" ] && _COMFY_TRIPLES+=("${_COMFY_M_DIR[$i]}" "${_COMFY_M_URL[$i]}" "${_COMFY_M_SHA[$i]}")
    done
  done
}

# comfy_mode_fetch <set>...: the order of decision 4 without the restore: the grammar and the sets (before the lock: a refused argument never waits on a running fetch), the lock of its own,
# the config, the container list, the placement, the volume, the container. 0 done; 1 a file did not arrive, a call failed or the ceiling ended it; 2 a refusal; 4 the lock is held, or a
# fetch container is still listed (a fetch whose host process was killed leaves its container running with the lock released: a second container would resume the same .part beside it).
comfy_mode_fetch() {
  local set known="" listing name vols out rc
  local -a run_args=()
  comfy_models_load "$(comfy_models_conf)" || return 2
  if [ "$#" -eq 0 ]; then
    _comfy_err fetch "usage: bin/r9700 comfy fetch <set>...; legal sets: $(comfy_sets | tr '\n' ' ' | sed 's/ $//')"
    return 2
  fi
  for set in "$@"; do
    if ! comfy_sets | grep -Fxq -- "$set"; then
      _comfy_err fetch "unknown set \"$set\"; legal: $(comfy_sets | tr '\n' ' ' | sed 's/ $//')"
      return 2
    fi
  done
  comfy_fetch_triples "$@"
  lock_take comfy-fetch comfy-fetch.lock || return $?
  config_load_machine "${R9700_MACHINE_ENV:-./machine.env}" || { lock_release; return 2; }
  name="$(comfy_fetch_name)"
  if ! _rg_listing_tries; then
    _comfy_err fetch "the container list failed 3 times ($_RG_LIST_ERR)"
    lock_release
    return 2
  fi
  listing="$_RG_LISTING"
  if grep -Fxq -- "$name" <<< "$listing"; then
    _comfy_err fetch "a fetch container is still running: $name; wait for it or stop it"
    lock_release
    return 4
  fi
  local _MOE_PLACED_BY=comfy # local: it names the verb in a placement refusal
  moe_place comfy_assets || { lock_release; return 2; }
  vols="$(wslc_volume_list 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    _comfy_err fetch "the volume list failed (code $rc)${vols:+: ${vols##*$'\n'}}"
    lock_release
    return 1
  fi
  if ! comfy_volume_ensure "$R9700_COMFY_MODELS_VOLUME" "$vols" fetch; then
    _comfy_err fetch "$_COMFY_ERR"
    lock_release
    return 1
  fi
  run_args=(--name "$name" -v "$R9700_COMFY_MODELS_VOLUME:/models")
  [ -z "$R9700_COMFY_STORE_WIN" ] || run_args+=(-v "$R9700_COMFY_STORE_WIN:/store")
  run_args+=(-v "$R9700_WORK_DIR_WIN:/work:ro" --entrypoint bash "$R9700_COMFY_IMAGE" "$_COMFY_CONTAINER_DIR/fetch_model.sh" "${_COMFY_TRIPLES[@]}")
  wslc_run_once "$R9700_COMFY_FETCH_MAX_S" "${run_args[@]}"
  rc=$?
  lock_release
  case $rc in
    0) return 0 ;;
    3) _comfy_err fetch "a source publishes another sha256 than comfyui/models.conf pins (the container's lines are above); nothing of that file was downloaded"; return 2 ;;
    124 | 137) _comfy_err fetch "the ceiling of $R9700_COMFY_FETCH_MAX_S s ended the fetch container $name; run the same fetch again, it resumes"; return 1 ;;
    *) _comfy_err fetch "the fetch container $name ended with code $rc (its lines are above); run the same fetch again, it resumes"; return 1 ;;
  esac
}
