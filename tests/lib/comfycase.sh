#!/usr/bin/env bash
# Shared by tests/test_comfy.sh and tests/test_comfy_start.sh (E1.S2): the stub world of the ComfyUI verb and the helpers that read what it left. Sourced after tests/lib/assert.sh,
# stubcase.sh and lifecycle.sh; no t_ function in it. It builds on tests/lib/runcase.sh (the run, kernels, series and MoE setups of the verbs under the supervisor) and sources lib/comfy.sh.
#
#   comfy_setup <name>      lc_setup, the readiness answer `ok`, the three default volumes present as files below $STUB/volumes
#   comfy <args...>         `bin/r9700 comfy <args...>` as a user runs it (the config variables of this test shell are not handed on)
#   comfy_bg <args...>      the same in the background (SUP; output in $CASE/sup.out and $CASE/sup.err); comfy_end [<s>] waits for it (SRC, SOUT, SERR)
#   comfy_run_argv          ARGV: the argument array of the last `run ... --name <COMFY_CONTAINER>` call
#   comfy_listed [<name>]   the operator's ComfyUI runs (a stub container named comfyui, or <name>)
#   wait_call <regex> [<n>] waits (bounded: n * 0.1 s, default 100) for a call-log line that matches; 1 when none does
#   call_order <regex>...   0 when the first line of each regex is in the call log after the first line of the one before
#   comfy_owner_line [<name>] / comfy_server_line [<name>] / comfy_restore_line   the exact lines of the owner check, the card-free admission and the restore
#   lock_free               0 when the lock file can be taken now
#   alive <container>       0 while the stub container's record is a live process

# shellcheck source=tests/lib/runcase.sh
source "$HERE/lib/runcase.sh"
# shellcheck source=lib/comfy.sh
source "$REPO/lib/comfy.sh"

comfy_setup() {
  lc_setup "$1"
  local volume
  printf 'ok\n' > "$STUB/answers/comfy_ready"
  mkdir -p "$STUB/volumes"
  for volume in "$R9700_COMFY_MODELS_VOLUME" "$R9700_COMFY_DATA_VOLUME" "$R9700_COMFY_CACHE_VOLUME"; do : > "$STUB/volumes/$volume"; done
}

comfy() { r9700 comfy "$@"; }

comfy_bg() {
  local -a drop=()
  local key
  while read -r key; do drop+=("R9700_$key"); done < <(config_keys | awk '{ print $2 }')
  # a background job of a non-interactive shell ignores SIGINT, and an ignored signal cannot be trapped: start the verb with the default (as tests/test_step.sh does for INT)
  python3 -I -c 'import os, signal, sys
signal.signal(signal.SIGINT, signal.SIG_DFL)
for key in sys.argv[1].split(): os.environ.pop(key, None)
os.execv(sys.argv[2], sys.argv[2:])' "${drop[*]}" "$REPO/bin/r9700" comfy "$@" > "$CASE/sup.out" 2> "$CASE/sup.err" &
  SUP=$!
  guard_pid "$SUP" "supervisor-$SUP"
}

comfy_end() { step_end "$@"; }

comfy_run_argv() { _argv_of_call run "${1:-$R9700_COMFY_CONTAINER}"; }

comfy_listed() { wslc run -d --rm --name "${1:-comfyui}" img > /dev/null; }

wait_call() {
  local i
  for i in $(seq 1 "${2:-100}"); do
    grep -qE -- "$1" "$STUB/calls.log" 2> /dev/null && return 0
    sleep 0.1
  done
  return 1
}

# call_order <regex>...: the line number of the first match of each regex, in the call log, must grow
call_order() {
  local re last=0 n
  for re in "$@"; do
    n="$(grep -nE -- "$re" "$STUB/calls.log" | head -n 1 | cut -d: -f1)"
    [ -n "$n" ] && [ "$n" -gt "$last" ] || return 1
    last="$n"
  done
}

comfy_owner_line() { printf "r9700: the operator's ComfyUI (%s) is listed and holds the card; run bin/r9700 comfy stop first" "${1:-comfyui}"; }

comfy_server_line() { printf "r9700: the operator's server (%s) is listed and holds the card; stop it by hand first (no verb of the toolkit stops it for a build)" "${1:-vllm}"; }

comfy_restore_line() { printf "r9700: restore: vllm not started: the operator's ComfyUI (comfyui) is listed; run bin/r9700 comfy stop, then any verb restores vllm (the marker stays)"; }

lock_free() { flock -n "$R9700_STATE_DIR/lock" true; }

alive() { [ -f "$STUB/containers/$1.pid" ] && kill -0 "$(pid_of "$1")" 2> /dev/null; }
