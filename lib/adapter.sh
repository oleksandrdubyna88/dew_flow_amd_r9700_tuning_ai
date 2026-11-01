#!/usr/bin/env bash
# lib/adapter.sh — the adapter seam: EVERY call to `wslc` and to Windows PowerShell goes through a function of this file, and this is the
# only file under lib/ and bin/ that expands $R9700_WSLC, $R9700_POWERSHELL or $R9700_RESTORE_SHELL (tests/check_static.sh --seam
# checks it), so the CI stubs in tests/stubs replace exactly one place. SOURCED; defines functions and runs nothing. Bash >= 4.4,
# `set -u` safe, no `set -e`. It reads R9700_* variables only (config_load exports them); it reads no file.
#
#   wslc_run <name> <args...>               run -d --rm --name <name> <args...>; prints the last 2 lines                       120 s
#   wslc_exec <ceiling-s> <name> <cmd...>   exec <name> <cmd...>; stdout and stderr merged                                     the argument
#   wslc_list                               the names of the listed containers (list --no-trunc), one per line                 60 s
#   wslc_stop <name>                        stop <name>; the child's output is discarded                                       60 s
#   wslc_logs <name>                        logs <name>, stderr merged                                                         60 s
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

# adapter_exe <value>: an absolute path is printed as given (it must be an executable file); a bare name is resolved on PATH now.
adapter_exe() {
  local value="${1:-}" found
  if [[ $value == /* ]]; then
    if [ -f "$value" ] && [ -x "$value" ]; then printf '%s\n' "$value"; return 0; fi
    echo "adapter: $value is not an executable file" >&2
    return 10
  fi
  found="$(command -v -- "$value" 2> /dev/null)"
  if [[ -n $value && $found == /* ]]; then printf '%s\n' "$found"; return 0; fi
  echo "adapter: ${value:-(empty)} not found on PATH" >&2
  return 10
}

# _adapter_ceiling <ceiling-s>: prints the ceiling of a call in seconds: t_ceiling of the argument, cut at R9700_T_STOP when that is sooner.
# Returns 10 with an `adapter:` line when R9700_T_STOP is not an epoch second or is not in the future.
_adapter_ceiling() {
  local ceiling cut
  ceiling="$(t_ceiling "$1")" || return 10
  if [ -z "${R9700_T_STOP:-}" ]; then printf '%s\n' "$ceiling"; return 0; fi
  if ! [[ $R9700_T_STOP =~ ^[0-9]+$ ]]; then
    echo "adapter: R9700_T_STOP \"$R9700_T_STOP\" is not an epoch second (digits only)" >&2
    return 10
  fi
  cut="$(awk -v c="$ceiling" -v stop="$R9700_T_STOP" -v now="$(date +%s.%N)" \
    'BEGIN { left = stop - now; if (left <= 0) { printf "%.0f\n", -left; exit 1 } if (left < c) c = left; if (c < 0.01) c = 0.01; printf "%.2f\n", c }')" || {
    echo "adapter: R9700_T_STOP passed ${cut} s ago; no call is made after the stop time" >&2
    return 10
  }
  printf '%s\n' "$cut"
}

# _adapter_call --merge|--quiet <ceiling-s> <executable value> <argv...>: the one place that starts a child. Standard input is /dev/null
# (a child must never eat the caller's loop input). The child's stderr goes to its stdout (--merge) or is dropped (--quiet); the
# adapter's own `adapter:` lines are never merged or dropped.
_adapter_call() {
  local mode ceiling grace exe
  case ${1:-} in
    --merge | --quiet) mode="${1#--}"; shift ;;
    *) echo "adapter: _adapter_call needs --merge or --quiet (an internal error)" >&2; return 10 ;;
  esac
  if ! declare -F t_ceiling > /dev/null; then
    echo "adapter: t_ceiling is not defined (source lib/run_guarded.sh first)" >&2
    return 10
  fi
  grace="$(t_ceiling 5)" || return 10
  ceiling="$(_adapter_ceiling "$1")" || return 10
  exe="$(adapter_exe "$2")" || return 10
  shift 2
  case $mode in
    merge) timeout --kill-after="$grace" "$ceiling" "$exe" "$@" < /dev/null 2>&1 ;;
    quiet) timeout --kill-after="$grace" "$ceiling" "$exe" "$@" < /dev/null 2> /dev/null ;;
  esac
}

# _adapter_name_ok <function> <name>: 0 for a container name; else one stderr line naming the function, and 2
_adapter_name_ok() {
  [[ ${2:-} =~ $_ADAPTER_NAME_RE ]] && return 0
  echo "$1: \"${2:-}\" is not a container name (letters, digits, . _ -; no leading -)" >&2
  return 2
}

wslc_run() {
  _adapter_name_ok wslc_run "${1:-}" || return 2
  local name="$1"
  shift
  _adapter_call --merge 120 "$R9700_WSLC" run -d --rm --name "$name" "$@" | tr -d '\r' | tail -n 2
  return "${PIPESTATUS[0]}"
}

wslc_exec() {
  local ceiling="${1:-}"
  if ! [[ $ceiling =~ ^[1-9][0-9]*$ ]]; then
    echo "wslc_exec: the ceiling \"$ceiling\" is not a positive integer (seconds)" >&2
    return 2
  fi
  _adapter_name_ok wslc_exec "${2:-}" || return 2
  if [ "$#" -lt 3 ]; then
    echo "wslc_exec: no command to run in $2" >&2
    return 2
  fi
  local name="$2"
  shift 2
  _adapter_call --merge "$ceiling" "$R9700_WSLC" exec "$name" "$@" | tr -d '\r'
  return "${PIPESTATUS[0]}"
}

# The container names: the last column of `list --no-trunc` (plain `list` cuts long names), without the header line.
wslc_list() {
  _adapter_call --quiet 60 "$R9700_WSLC" list --no-trunc | tr -d '\r' | awk 'NR > 1 && NF { print $NF }'
  return "${PIPESTATUS[0]}"
}

wslc_stop() {
  _adapter_name_ok wslc_stop "${1:-}" || return 2
  _adapter_call --merge 60 "$R9700_WSLC" stop "$1" > /dev/null
}

wslc_logs() {
  _adapter_name_ok wslc_logs "${1:-}" || return 2
  _adapter_call --merge 60 "$R9700_WSLC" logs "$1" | tr -d '\r'
  return "${PIPESTATUS[0]}"
}

# _adapter_integer <ceiling-s> <PowerShell command>: prints the integer the command answers; nothing and 1 unless the answer is exactly one
# non-empty line (blank lines and spaces around it are trimmed) that is only digits: `100` then `0` is two answers, never 1000. A ceiling
# or an adapter failure returns its own code.
_adapter_integer() {
  local out rc line value="" count=0
  out="$(_adapter_call --quiet "$1" "$R9700_POWERSHELL" -NoProfile -Command "$2")"
  rc=$?
  if [ "$rc" -ne 0 ]; then return "$rc"; fi
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line//$'\r'/}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -n "$line" ] || continue
    value="$line"
    count=$((count + 1))
  done <<< "$out"
  [ "$count" -eq 1 ] && [[ $value =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$value"
}

win_ram_mb() { _adapter_integer 30 "$_ADAPTER_RAM_PS"; }

win_disk_newest() { _adapter_integer 60 "$_ADAPTER_DISK_PS"; }

# restore_start: the start script with the configured arguments, one argv element per word (restore_server.sh lines 18-21). RESTORE_ARGS
# is what the operator wrote; -Detach is added only when it lacks one, so the start script never gets it twice.
restore_start() {
  local -a extra=()
  local word detach=0
  read -r -a extra <<< "$R9700_RESTORE_ARGS"
  for word in "${extra[@]}"; do [ "${word,,}" = -detach ] && detach=1; done
  [ "$detach" = 1 ] || extra+=(-Detach)
  _adapter_call --merge 120 "$R9700_RESTORE_SHELL" -NoProfile -File "$R9700_RESTORE_SCRIPT_WIN" "${extra[@]}" | tr -d '\r' | tail -n 5
  return "${PIPESTATUS[0]}"
}

restore_probe() {
  _adapter_name_ok restore_probe "${1:-}" || return 2
  wslc_exec 70 "$1" python3 -c "$_ADAPTER_PROBE_PY"
}
