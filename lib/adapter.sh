#!/usr/bin/env bash
# lib/adapter.sh — the adapter seam: EVERY call to `wslc` and to Windows PowerShell goes through a function of this file, and this is the
# only file under lib/ and bin/ that expands $R9700_WSLC, $R9700_POWERSHELL or $R9700_RESTORE_SHELL (tests/check_static.sh --seam
# checks it), so the CI stubs in tests/stubs replace exactly one place. SOURCED; defines functions and runs nothing. Bash >= 4.4,
# `set -u` safe, no `set -e`. It reads R9700_* variables only (config_load exports them); it reads no file.
#
#   wslc_run <name> <args...>               run -d --rm --name <name> <args...>; prints the last 2 lines                       120 s
#   wslc_exec <ceiling-s> <name> <cmd...>   exec <name> <cmd...>; stdout and stderr merged                                     the argument
#   wslc_run_once <ceiling-s> <args...>     run --rm <args...> in the FOREGROUND (a throwaway container whose answer is read); the
#                                           stdout and stderr merged                                                           the argument
#   wslc_argv_text <args...>                prints `wslc <args...>`, one line, for a dry run; calls nothing
#   wslc_list                               the names of the listed containers (list --no-trunc), one per line                 60 s
#   wslc_stop <name>                        stop <name>; prints the child's output (stdout and stderr, CRs removed, the last 20 lines)  60 s
#   wslc_logs <name>                        logs <name>, stderr merged                                                         60 s
#   wslc_build <ceiling-s> <args...>        build <args...> (an image build); every line is printed as it comes, stdout and stderr merged  the argument
#   wslc_volume_list                        the names of the listed volumes (volume list), one per line                        60 s
#   wslc_volume_create <name>               volume create <name>; prints the child's output (stdout and stderr merged)                  60 s
#   wslc_remove <name>                      remove <name> (a STOPPED container keeps its name until it is removed); prints the child's output   60 s
#   wslc_inspect <reference>                inspect <reference> (an image or a container); prints the JSON the engine answers                    60 s
#   wslc_tag <source> <target>              tag <source> <target>: a second name for an image; prints the child's output                         60 s
#   wslc_rmi <repository>:<tag>             rmi <exact tag>: removes ONE tag, never an id, a pattern or an option; prints the child's output       60 s
#   wslc_image_list                         `image list --no-trunc`: `<repository> <tag> <id>` per image, one per line, no header                60 s
#   comfy_probe <name>                      the readiness check of a ComfyUI container through wslc_exec 20: prints `device <name>`, then `vram_free <n>` and `vram_total <n>`
#                                           (or the one line `vram: not in the answer`), then `ready`; or `system_stats: HTTP <status>` / `system_stats: <exception class>`
#                                           and returns 1   20 s
#   win_ram_mb                              the Windows "Available MBytes" integer; nothing and 1 when it is not an integer    30 s
#   win_disk_newest                         the newest disk/stornvme System-log record id; nothing and 1 when not an integer   60 s
#   restore_start                           the operator's start script through the restore shell; prints the last 5 lines    120 s
#   restore_probe <name>                    the two readiness checks of decision 5 through wslc_exec 70: prints models,
#                                           completion, or "<check>: HTTP <status>" / "<check>: <exception class>" and returns 1  70 s
#
# Every call is an argv (never a shell string) under `timeout --kill-after=5 <ceiling>`: the child is killed at its ceiling, not
# merely waited for (a timeout that only stops waiting makes an orphan). Every number goes through t_ceiling (lib/run_guarded.sh), and
# when R9700_T_STOP (an epoch second, set by the supervisor) is set, no call waits past it: its ceiling is the smaller of its own and the
# time left, and a call made at or after R9700_T_STOP is refused.
# CRs are removed from every output (the executables are Windows programs). Return codes: the child's own; 124 when the ceiling
# ended it (137 when it needed the KILL after the grace); 2 for a bad argument (nothing is called); 10 when the adapter itself cannot
# call (an executable or t_ceiling is missing, a scale or R9700_T_STOP is invalid or already passed), with one stderr line that starts `adapter:`.

_ADAPTER_NAME_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$' # a container name never starts with "-": it can never be read as an option
_ADAPTER_REF_RE='^[A-Za-z0-9][A-Za-z0-9._:/-]*$' # an image reference has "/" and ":"; it never starts with "-" and has no space
_ADAPTER_TAGGED_RE='^[A-Za-z0-9][A-Za-z0-9._/-]*:[A-Za-z0-9._-]+$' # an EXACT image tag <repository>:<tag>: no bare repository (the engine would read :latest), no pattern, no option

# The Windows PowerShell commands of the old guards, one argv element each (ram_guard_all.sh line 8, disk_gate.sh line 7).
_ADAPTER_RAM_PS='[int](Get-Counter "\Memory\Available MBytes").CounterSamples[0].CookedValue'
_ADAPTER_DISK_PS='$e = Get-WinEvent -FilterHashtable @{LogName="System"; ProviderName="disk","stornvme"} -MaxEvents 1 -ErrorAction Stop; $e.RecordId'

# The readiness probe: ONE Python program, run inside the server's container. Check 1: GET /v1/models answers 200 within 5 s. Check 2:
# POST /v1/completions with the first model id and one token answers 200 within 60 s. It prints what passed and, at the first failure,
# "<check>: HTTP <status>" or "<check>: <exception class>", and exits 1.
_ADAPTER_PROBE_PY='import json, sys, urllib.error, urllib.request
BASE = "http://127.0.0.1:8000"


def fetch(check, path, timeout, body=None):
    headers = {"Content-Type": "application/json"} if body else {}
    request = urllib.request.Request(BASE + path, data=body, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            status, text = response.status, response.read()
    except urllib.error.HTTPError as error:
        print(check + ": HTTP " + str(error.code))
        sys.exit(1)
    except Exception as error:
        print(check + ": " + type(error).__name__)
        sys.exit(1)
    if status != 200:
        print(check + ": HTTP " + str(status))
        sys.exit(1)
    return text


try:
    model = json.loads(fetch("models", "/v1/models", 5))["data"][0]["id"]
except Exception as error:
    print("models: " + type(error).__name__)
    sys.exit(1)
print("models")
fetch("completion", "/v1/completions", 60, json.dumps({"model": model, "prompt": "Hi", "max_tokens": 1}).encode())
print("completion")'

# adapter_probe_program: prints the readiness program (the tests run it against a fake urlopen)
adapter_probe_program() { printf '%s\n' "$_ADAPTER_PROBE_PY"; }

# The readiness probe of the operator's ComfyUI: ONE Python program, run inside its container. GET /system_stats on 127.0.0.1:8188 answers 200 within 5 s with a
# JSON that names a device (devices[0].name: the shape is taken from ComfyUI's source, not observed here). It prints `device <name>`, then the card's two memory numbers
# (devices[0].vram_free and vram_total, whole numbers: `vram_free <n>`, `vram_total <n>`; E2.S2) or, when either is not a whole number, the one line `vram: not in the
# answer` (ComfyUI is ready; the card reading is a separate fact and never an absent number made into 0), then `ready`; or at the first failure `system_stats: HTTP <status>`
# / `system_stats: <exception class>`, and exits 1.
_COMFY_PROBE_PY='import json, sys, urllib.error, urllib.request
URL = "http://127.0.0.1:8188/system_stats"
try:
    with urllib.request.urlopen(urllib.request.Request(URL), timeout=5) as response:
        status, text = response.status, response.read()
except urllib.error.HTTPError as error:
    print("system_stats: HTTP " + str(error.code))
    sys.exit(1)
except Exception as error:
    print("system_stats: " + type(error).__name__)
    sys.exit(1)
if status != 200:
    print("system_stats: HTTP " + str(status))
    sys.exit(1)
try:
    card = json.loads(text)["devices"][0]
    name = card["name"]
except Exception as error:
    print("system_stats: " + type(error).__name__)
    sys.exit(1)
print("device " + name)
numbers = [card.get(key) for key in ("vram_free", "vram_total")]
if all(isinstance(n, int) and not isinstance(n, bool) and n >= 0 for n in numbers):
    print("vram_free " + str(numbers[0]))
    print("vram_total " + str(numbers[1]))
else:
    print("vram: not in the answer")
print("ready")'

# comfy_probe_program: prints the ComfyUI readiness program (the tests run it against a fake urlopen)
comfy_probe_program() { printf '%s\n' "$_COMFY_PROBE_PY"; }

# adapter_marker_words: the two executables as the recovery marker records them, one KEY=VALUE word per line (WSLC, RESTORE_SHELL): the
# restore needs them and must work without the config, and no other file may expand these variables.
adapter_marker_words() {
  printf 'WSLC=%s\n' "$R9700_WSLC"
  printf 'RESTORE_SHELL=%s\n' "$R9700_RESTORE_SHELL"
}

# adapter_exe <value>: an absolute path is printed as given (it must be an executable file); a bare name is resolved on PATH now.
adapter_exe() {
  local _adapter_value="${1:-}" _adapter_found
  if [[ $_adapter_value == /* ]]; then
    if [ -f "$_adapter_value" ] && [ -x "$_adapter_value" ]; then printf '%s\n' "$_adapter_value"; return 0; fi
    echo "adapter: $_adapter_value is not an executable file" >&2
    return 10
  fi
  _adapter_found="$(command -v -- "$_adapter_value" 2> /dev/null)"
  if [[ -n $_adapter_value && $_adapter_found == /* ]]; then printf '%s\n' "$_adapter_found"; return 0; fi
  echo "adapter: ${_adapter_value:-(empty)} not found on PATH" >&2
  return 10
}

# _adapter_ceiling <ceiling-s>: prints the ceiling of a call in seconds: t_ceiling of the argument, cut at R9700_T_STOP when that is sooner.
# Returns 10 with an `adapter:` line when R9700_T_STOP is not an epoch second or is not in the future.
_adapter_ceiling() {
  local _adapter_ceil _adapter_cut
  _adapter_ceil="$(t_ceiling "$1")" || return 10
  if [ -z "${R9700_T_STOP:-}" ]; then printf '%s\n' "$_adapter_ceil"; return 0; fi
  if ! [[ $R9700_T_STOP =~ ^[0-9]+$ ]]; then
    echo "adapter: R9700_T_STOP \"$R9700_T_STOP\" is not an epoch second (digits only)" >&2
    return 10
  fi
  _adapter_cut="$(awk -v c="$_adapter_ceil" -v stop="$R9700_T_STOP" -v now="$(date +%s.%N)" \
    'BEGIN { left = stop - now; if (left <= 0) { printf "%.0f\n", -left; exit 1 } if (left < c) c = left; if (c < 0.01) c = 0.01; printf "%.2f\n", c }' 9>&-)" || {
    echo "adapter: R9700_T_STOP passed ${_adapter_cut} s ago; no call is made after the stop time" >&2
    return 10
  }
  printf '%s\n' "$_adapter_cut"
}

# _adapter_drop_lock: descriptor 9 is the supervisor's lock (amendment A1). A fork of the supervisor (a command substitution, the left side
# of a pipeline) that kept it would keep the lock after a SIGKILL of the supervisor until its call ends. In a fork, close it for good;
# in the process that took the lock (lock_take records it in _RG_LOCK_OWNER; without a lock: the main shell) do nothing. The commands on
# the right of a pipe and `timeout` get `9>&-` on their own command line (a temporary redirection of a shell function would leave a saved
# copy of the descriptor open in the fork).
_adapter_drop_lock() { [ "$BASHPID" = "${_RG_LOCK_OWNER:-$$}" ] || exec 9>&-; }

# _adapter_group_kill <pgid>: KILL for the process group <pgid>, in ONE step, when at least one live process of that group is in the
# caller's own session. `timeout` makes its pid the id of a group of its own; once `timeout` is reaped that number is only a number, so a
# group of another session with the same id (a pid that was reused) is never touched. The scan only confirms the group is ours: a group id
# cannot be reused while it has a member, and a member that forks while the kill is on its way is in the group too. Nothing to kill is not
# an error.
_adapter_group_kill() {
  local _adapter_pgid="$1" _adapter_dir _adapter_mysid _adapter_mypgrp
  proc_stat_fields "$BASHPID" || return 0
  _adapter_mypgrp="${PROC_STAT[2]:-}"
  _adapter_mysid="${PROC_STAT[3]:-}"
  [ "$_adapter_pgid" != "$_adapter_mypgrp" ] || return 0
  for _adapter_dir in /proc/[0-9]*; do
    proc_stat_fields "${_adapter_dir#/proc/}" || continue
    if [ "${PROC_STAT[0]:-Z}" != Z ] && [ "${PROC_STAT[2]:-}" = "$_adapter_pgid" ] && [ "${PROC_STAT[3]:-}" = "$_adapter_mysid" ]; then
      kill -KILL -- "-$_adapter_pgid" 2> /dev/null
      return 0
    fi
  done
  return 0
}

# The interrupt chain of a waiting call (amendment A14). Each call keeps what it saved of the caller's traps in a LOCAL associative array
# _adapter_acts_<depth> of _adapter_wait, where <depth> counts the waits that are open (a handler may make an adapter call of its own, the
# plan's cleanup path: a nested wait). Its hooks carry their depth, and _adapter_on_signal reads the array of that depth through bash's
# dynamic scope; nothing is global but the counter, so nested calls never overwrite one another's saved actions.
#   act:<SIG>   the caller's real action for the signal ('' when it has none)
#   text:<SIG>  the `trap -p` text the signal had when the wait began (put back by eval when the wait ends)
_ADAPTER_DEPTH=0

# _adapter_on_signal <pgid> <signal> <owner|fork> <depth>: the trap of a waiting call. The call's group is killed FIRST. In the process that
# owns the caller's traps (owner) the caller's own action for the signal then runs, with $? = 128 + the signal number as in any trap (no
# action: the signal's default effect, by raising it again). A fork (a command substitution or a pipeline part) never owns them: `trap -p`
# there shows the PARENT's, which the parent runs itself, so a fork only dies of the signal.
_adapter_on_signal() {
  local _adapter_n _adapter_act
  local -n _adapter_frame="_adapter_acts_$4"
  _adapter_group_kill "$1"
  case $2 in TERM) _adapter_n=15 ;; INT) _adapter_n=2 ;; *) _adapter_n=1 ;; esac
  _adapter_act="${_adapter_frame[act:$2]-}"
  if [ "$3" = owner ] && [ -n "$_adapter_act" ]; then
    trap -- "$_adapter_act" "$2"
    (exit $((128 + _adapter_n)))
    eval "$_adapter_act"
    return
  fi
  trap - "$2"
  kill -s "$2" "$BASHPID"
}

# _adapter_wait <pid>: `wait` for the call, with _adapter_on_signal installed for TERM, INT and HUP. A signal the caller IGNORES (trap '') is
# left ignored: a cleanup that shuts signals out keeps its call. A signal that already carries a hook of an outer call (we are nested, inside
# a handler) takes that call's saved action as the caller's real one. The caller's traps are back when it returns.
_adapter_wait() {
  local _adapter_pid="$1" _adapter_wrc _adapter_sig _adapter_text _adapter_handler _adapter_role=fork _adapter_depth _adapter_outer_depth
  local -a _adapter_hooked=()
  _ADAPTER_DEPTH=$((_ADAPTER_DEPTH + 1))
  _adapter_depth=$_ADAPTER_DEPTH
  local -A "_adapter_acts_$_adapter_depth"
  local -n _adapter_mine="_adapter_acts_$_adapter_depth"
  [ "$BASHPID" = "${_RG_LOCK_OWNER:-$$}" ] && _adapter_role=owner
  for _adapter_sig in TERM INT HUP; do
    _adapter_text="$(trap -p "$_adapter_sig")"
    _adapter_mine[text:$_adapter_sig]="$_adapter_text"
    _adapter_handler=""
    if [ -n "$_adapter_text" ]; then
      eval "set -- $_adapter_text"
      _adapter_handler="${3-}"
      if [[ $_adapter_handler == '_adapter_on_signal '* ]]; then
        read -r _ _ _ _ _adapter_outer_depth <<< "$_adapter_handler"
        local -n _adapter_outer="_adapter_acts_$_adapter_outer_depth"
        _adapter_handler="${_adapter_outer[act:$_adapter_sig]-}"
        unset -n _adapter_outer
      elif [ -z "$_adapter_handler" ]; then
        continue # an ignored signal stays ignored
      fi
    fi
    _adapter_mine[act:$_adapter_sig]="$_adapter_handler"
    trap "_adapter_on_signal $_adapter_pid $_adapter_sig $_adapter_role $_adapter_depth" "$_adapter_sig"
    _adapter_hooked+=("$_adapter_sig")
  done
  wait "$_adapter_pid"
  _adapter_wrc=$?
  for _adapter_sig in "${_adapter_hooked[@]}"; do
    _adapter_text="${_adapter_mine[text:$_adapter_sig]}"
    if [ "$_adapter_role" = owner ] && [ -n "$_adapter_text" ]; then eval "$_adapter_text"; else trap - "$_adapter_sig"; fi
  done
  _ADAPTER_DEPTH=$((_ADAPTER_DEPTH - 1))
  return "$_adapter_wrc"
}

# _adapter_call --merge|--quiet <ceiling-s> <executable value> <argv...>: the one place that starts a child. Standard input is /dev/null
# (a child must never eat the caller's loop input). The child's stderr goes to its stdout (--merge) or is dropped (--quiet); the
# adapter's own `adapter:` lines are never merged or dropped.
_adapter_call() {
  _adapter_drop_lock
  local _adapter_mode _adapter_ceiling_s _adapter_grace _adapter_exe _adapter_tpid _adapter_rc
  case ${1:-} in
    --merge | --quiet) _adapter_mode="${1#--}"; shift ;;
    *) echo "adapter: _adapter_call needs --merge or --quiet (an internal error)" >&2; return 10 ;;
  esac
  if ! declare -F t_ceiling > /dev/null; then
    echo "adapter: t_ceiling is not defined (source lib/run_guarded.sh first)" >&2
    return 10
  fi
  _adapter_grace="$(t_ceiling 5)" || return 10
  _adapter_ceiling_s="$(_adapter_ceiling "$1")" || return 10
  _adapter_exe="$(adapter_exe "$2")" || return 10
  shift 2
  # The call runs in the background so that its pid is known: GNU timeout makes that pid the id of a process group of its own, and
  # --kill-after kills only timeout's direct child (amendment A12). Descriptor 9, the supervisor's lock, is closed for the child (A1).
  case $_adapter_mode in
    merge) timeout --kill-after="$_adapter_grace" "$_adapter_ceiling_s" "$_adapter_exe" "$@" < /dev/null 9>&- 2>&1 & ;;
    quiet) timeout --kill-after="$_adapter_grace" "$_adapter_ceiling_s" "$_adapter_exe" "$@" < /dev/null 9>&- 2> /dev/null & ;;
  esac
  _adapter_tpid=$!
  _adapter_wait "$_adapter_tpid"
  _adapter_rc=$?
  # The ceiling ended the call (124, or 137 after the grace), or the wait was interrupted (more than 128): whatever of the call's group is
  # still alive gets the KILL.
  if [ "$_adapter_rc" = 124 ] || [ "$_adapter_rc" -gt 128 ]; then
    _adapter_group_kill "$_adapter_tpid"
    wait "$_adapter_tpid" 2> /dev/null # reaps timeout; the code to return is the one the wait gave
  fi
  return "$_adapter_rc"
}

# _adapter_name_ok <function> <name> [<what>]: 0 for a name (a container name unless <what> says another noun, e.g. "volume name"); else one stderr line naming the function, and 2
_adapter_name_ok() {
  [[ ${2:-} =~ $_ADAPTER_NAME_RE ]] && return 0
  echo "$1: \"${2:-}\" is not a ${3:-container name} (letters, digits, . _ -; no leading -)" >&2
  return 2
}

wslc_run() {
  _adapter_drop_lock
  _adapter_name_ok wslc_run "${1:-}" || return 2
  local _adapter_name="$1"
  shift
  _adapter_call --merge 120 "$R9700_WSLC" run -d --rm --name "$_adapter_name" "$@" | tr -d '\r' 9>&- | tail -n 2 9>&-
  return "${PIPESTATUS[0]}"
}

wslc_exec() {
  _adapter_drop_lock
  local _adapter_ceiling="${1:-}"
  if ! [[ $_adapter_ceiling =~ ^[1-9][0-9]*$ ]]; then
    echo "wslc_exec: the ceiling \"$_adapter_ceiling\" is not a positive integer (seconds)" >&2
    return 2
  fi
  _adapter_name_ok wslc_exec "${2:-}" || return 2
  if [ "$#" -lt 3 ]; then
    echo "wslc_exec: no command to run in $2" >&2
    return 2
  fi
  local _adapter_name="$2"
  shift 2
  _adapter_call --merge "$_adapter_ceiling" "$R9700_WSLC" exec "$_adapter_name" "$@" | tr -d '\r' 9>&-
  return "${PIPESTATUS[0]}"
}

# wslc_run_once <ceiling-s> <args...>: a foreground `run --rm`: the container lives for the length of the call and its output is the answer.
# Every word is one argv element, so a value that holds `;` or `#` stays one value (the caller passes data as arguments, never inside a program).
wslc_run_once() {
  _adapter_drop_lock
  local _adapter_ceiling="${1:-}"
  if ! [[ $_adapter_ceiling =~ ^[1-9][0-9]*$ ]]; then
    echo "wslc_run_once: the ceiling \"$_adapter_ceiling\" is not a positive integer (seconds)" >&2
    return 2
  fi
  if [ "$#" -lt 2 ]; then
    echo "wslc_run_once: no word to run" >&2
    return 2
  fi
  shift
  _adapter_call --merge "$_adapter_ceiling" "$R9700_WSLC" run --rm "$@" | tr -d '\r' 9>&-
  return "${PIPESTATUS[0]}"
}

# wslc_argv_text <args...>: the command line a call of wslc with these words would run, for the output of a dry run. Nothing is called; the
# program's name is printed as `wslc` whatever the configured executable is (the line is for a person).
wslc_argv_text() {
  printf 'wslc'
  printf ' %s' "$@"
  printf '\n'
}

# The container names: the last column of `list --no-trunc` (plain `list` cuts long names), without the header line.
wslc_list() {
  _adapter_drop_lock
  _adapter_call --quiet 60 "$R9700_WSLC" list --no-trunc | tr -d '\r' 9>&- | awk 'NR > 1 && NF { print $NF }' 9>&-
  return "${PIPESTATUS[0]}"
}

# wslc_stop <name>: stops <name> and prints what wslc printed (stdout and stderr merged, CRs removed, the LAST 20 lines): a caller that does not
# want it redirects it, a caller that logs a failure shows it (2026-11-03: a stop returned 1 and nothing said why, because the output was dropped).
# NOT a pipeline: the call must stay in the caller's own shell, where the caller's TERM trap and the interrupt chain of _adapter_wait reach it (a
# pipeline would be a fork that the caller's trap cannot end until the call does). The output goes through a process substitution on a descriptor
# of its own, closed when the call ends; the substitution is waited for, so everything it keeps is printed before the function returns.
wslc_stop() {
  _adapter_drop_lock
  _adapter_name_ok wslc_stop "${1:-}" || return 2
  local _adapter_fd _adapter_ps _adapter_rc
  exec {_adapter_fd}> >(exec 9>&-; tr -d '\r' | tail -n 20)
  _adapter_ps=$!
  _adapter_call --merge 60 "$R9700_WSLC" stop "$1" >&"$_adapter_fd" {_adapter_fd}>&- # the child gets the pipe as its stdout ONLY: a copy on this descriptor would outlive it in a process the stop leaves running
  _adapter_rc=$?
  exec {_adapter_fd}>&-
  wait "$_adapter_ps" 2> /dev/null
  return "$_adapter_rc"
}

wslc_logs() {
  _adapter_drop_lock
  _adapter_name_ok wslc_logs "${1:-}" || return 2
  _adapter_call --merge 60 "$R9700_WSLC" logs "$1" | tr -d '\r' 9>&-
  return "${PIPESTATUS[0]}"
}

# wslc_remove <name>: `remove <name>`; prints what wslc printed (stdout and stderr merged, CRs removed). wslc_run always passes --rm, but a container the engine kept
# STOPPED (the operator's ComfyUI of the hand-made script era) keeps its name, and a run of that name is refused until it is removed.
wslc_remove() {
  _adapter_drop_lock
  _adapter_name_ok wslc_remove "${1:-}" || return 2
  _adapter_call --merge 60 "$R9700_WSLC" remove "$1" | tr -d '\r' 9>&-
  return "${PIPESTATUS[0]}"
}

# wslc_inspect <reference>: `inspect <reference>`: the JSON of an image (its "Created" is read) or a container; stdout and stderr merged, CRs removed.
wslc_inspect() {
  _adapter_drop_lock
  if ! [[ ${1:-} =~ $_ADAPTER_REF_RE ]]; then
    echo "wslc_inspect: \"${1:-}\" is not a reference (letters, digits, . _ : / -; no leading -)" >&2
    return 2
  fi
  _adapter_call --merge 60 "$R9700_WSLC" inspect "$1" | tr -d '\r' 9>&-
  return "${PIPESTATUS[0]}"
}

# wslc_build <ceiling-s> <args...>: `build <args...>` (an image build: -t <tag>, -f <file>, --build-arg words, the context folder). Every line the build prints is
# printed as it comes (stdout and stderr merged, CRs removed); nothing is cut, a caller that wants a tail cuts it. Every word is one argv element.
wslc_build() {
  _adapter_drop_lock
  local _adapter_ceiling="${1:-}"
  if ! [[ $_adapter_ceiling =~ ^[1-9][0-9]*$ ]]; then
    echo "wslc_build: the ceiling \"$_adapter_ceiling\" is not a positive integer (seconds)" >&2
    return 2
  fi
  if [ "$#" -lt 2 ]; then
    echo "wslc_build: no word to build with" >&2
    return 2
  fi
  shift
  _adapter_call --merge "$_adapter_ceiling" "$R9700_WSLC" build "$@" | tr -d '\r' 9>&-
  return "${PIPESTATUS[0]}"
}

# wslc_tag <source> <target>: `tag <source> <target>` (alias `image tag`): the target names the image the source names. Both words are references (the check of wslc_inspect), and
# there are exactly two. The output of a tag, on success and on failure, was not observed by hand (E1's acceptance records it); the argv shape is the engine's own help text.
wslc_tag() {
  _adapter_drop_lock
  local _adapter_word
  for _adapter_word in "${1:-}" "${2:-}"; do
    if ! [[ $_adapter_word =~ $_ADAPTER_REF_RE ]]; then
      echo "wslc_tag: \"$_adapter_word\" is not a reference (letters, digits, . _ : / -; no leading -)" >&2
      return 2
    fi
  done
  if [ "$#" -ne 2 ]; then
    echo "wslc_tag: two references are needed (a source and a target), got $#" >&2
    return 2
  fi
  _adapter_call --merge 60 "$R9700_WSLC" tag "$1" "$2" | tr -d '\r' 9>&-
  return "${PIPESTATUS[0]}"
}

# wslc_rmi <exact tag>: `rmi <repository>:<tag>` (alias `image remove`), ONE reference. The word must be an exact tag: a bare repository would be read as :latest, an image id
# (`sha256:...`, or its short hex form) or a pattern could remove more than one image, and a word that starts with - is an option (-f). Neither -f nor --no-prune is ever passed.
# A short hex id has no colon, so the tag shape already refuses it; `sha256:<hex>` has one and is refused by name. The output of an rmi was not observed by hand.
wslc_rmi() {
  _adapter_drop_lock
  if [ "$#" -ne 1 ] || ! [[ ${1:-} =~ $_ADAPTER_TAGGED_RE ]] || [[ $1 == sha256:* ]]; then
    echo "wslc_rmi: \"$*\" is not an exact image tag (<repository>:<tag>; never an id, a pattern or an option)" >&2
    return 2
  fi
  _adapter_call --merge 60 "$R9700_WSLC" rmi "$1" | tr -d '\r' 9>&-
  return "${PIPESTATUS[0]}"
}

# wslc_image_list: `image list --no-trunc`: the first three columns of every row after the header, `<repository> <tag> <id>`. Observed by hand on the operator's PC (2026-11-07,
# through pwsh.exe): the header is `REPOSITORY TAG IMAGE ID CREATED SIZE`, a row is `comfyui-r9700 local sha256:<64 hex> 6 hours ago 27.3GB`, an untagged image is
# `<none> <none> sha256:<64 hex> ...`. CREATED is several words ("6 hours ago") and SIZE never matters, so only $1 $2 $3 are read: none of them holds a space.
wslc_image_list() {
  _adapter_drop_lock
  _adapter_call --quiet 60 "$R9700_WSLC" image list --no-trunc | tr -d '\r' 9>&- | awk 'NR > 1 && NF { print $1, $2, $3 }' 9>&-
  return "${PIPESTATUS[0]}"
}

# The volume names: the last column of `volume list` after the header line, the parse of wslc_list. The output shape (a header `DRIVER    VOLUME NAME`, then
# `<driver> <name>` per line) was observed once by hand on the operator's PC (2026-11-07, through pwsh.exe), never by the suite; E1's acceptance records it again.
wslc_volume_list() {
  _adapter_drop_lock
  _adapter_call --quiet 60 "$R9700_WSLC" volume list | tr -d '\r' 9>&- | awk 'NR > 1 && NF { print $NF }' 9>&-
  return "${PIPESTATUS[0]}"
}

# wslc_volume_create <name>: `volume create <name>`; prints what wslc printed (stdout and stderr merged, CRs removed). A volume that exists is an error of
# wslc (exit 1, ERROR_ALREADY_EXISTS, observed once by hand on the operator's PC, 2026-11-07, through pwsh.exe, never by the suite; E1's acceptance records it again), so a caller lists first and creates only a missing volume.
wslc_volume_create() {
  _adapter_drop_lock
  _adapter_name_ok wslc_volume_create "${1:-}" "volume name" || return 2
  _adapter_call --merge 60 "$R9700_WSLC" volume create "$1" | tr -d '\r' 9>&-
  return "${PIPESTATUS[0]}"
}

# _adapter_integer <ceiling-s> <PowerShell command>: prints the integer the command answers; nothing and 1 unless the answer is exactly one
# non-empty line (blank lines and spaces around it are trimmed) that is only digits: `100` then `0` is two answers, never 1000. On 1 it
# says on stderr what it got: `adapter: unreadable answer "<raw>"`. A ceiling or an adapter failure returns its own code.
_adapter_integer() {
  local _adapter_out _adapter_rc _adapter_line _adapter_value="" _adapter_count=0
  _adapter_out="$(_adapter_call --quiet "$1" "$R9700_POWERSHELL" -NoProfile -Command "$2")"
  _adapter_rc=$?
  if [ "$_adapter_rc" -ne 0 ]; then return "$_adapter_rc"; fi
  while IFS= read -r _adapter_line || [ -n "$_adapter_line" ]; do
    _adapter_line="${_adapter_line//$'\r'/}"
    _adapter_line="${_adapter_line#"${_adapter_line%%[![:space:]]*}"}"
    _adapter_line="${_adapter_line%"${_adapter_line##*[![:space:]]}"}"
    [ -n "$_adapter_line" ] || continue
    _adapter_value="$_adapter_line"
    _adapter_count=$((_adapter_count + 1))
  done <<< "$_adapter_out"
  if [ "$_adapter_count" -ne 1 ] || ! [[ $_adapter_value =~ ^[0-9]+$ ]]; then
    _adapter_value="${_adapter_out//$'\r'/}"
    _adapter_value="${_adapter_value//$'\n'/ | }"
    echo "adapter: unreadable answer \"${_adapter_value:0:80}\"" >&2 # the raw answer, so a caller can show what it could not read
    return 1
  fi
  printf '%s\n' "$_adapter_value"
}

win_ram_mb() { _adapter_drop_lock; _adapter_integer 30 "$_ADAPTER_RAM_PS"; }

win_disk_newest() { _adapter_drop_lock; _adapter_integer 60 "$_ADAPTER_DISK_PS"; }

# restore_start: the start script with the configured arguments, one argv element per word (restore_server.sh lines 18-21). RESTORE_ARGS
# is what the operator wrote; -Detach is added only when it lacks one, so the start script never gets it twice.
restore_start() {
  _adapter_drop_lock
  local -a _adapter_extra=()
  local _adapter_word _adapter_detach=0
  read -r -a _adapter_extra <<< "$R9700_RESTORE_ARGS"
  for _adapter_word in "${_adapter_extra[@]}"; do [ "${_adapter_word,,}" = -detach ] && _adapter_detach=1; done
  [ "$_adapter_detach" = 1 ] || _adapter_extra+=(-Detach)
  _adapter_call --merge 120 "$R9700_RESTORE_SHELL" -NoProfile -File "$R9700_RESTORE_SCRIPT_WIN" "${_adapter_extra[@]}" | tr -d '\r' 9>&- | tail -n 5 9>&-
  return "${PIPESTATUS[0]}"
}

restore_probe() {
  _adapter_drop_lock
  _adapter_name_ok restore_probe "${1:-}" || return 2
  wslc_exec 70 "$1" python3 -c "$_ADAPTER_PROBE_PY"
}

# comfy_probe <name>: the ComfyUI readiness check through wslc_exec 20 (5 s of HTTP plus the interpreter's start; the restore's probe has 70 s because of its 60 s completion)
comfy_probe() {
  _adapter_drop_lock
  _adapter_name_ok comfy_probe "${1:-}" || return 2
  wslc_exec 20 "$1" python3 -c "$_COMFY_PROBE_PY"
}
