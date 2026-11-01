#!/usr/bin/env bash
# lib/run_guarded.sh — the supervisor's engine. SOURCED; defines functions and runs nothing. Bash >= 4.4, `set -u` safe, no `set -e`.
#
# Built so far: the scale functions (part (a)); the lock, the worker start behind its gate, and the session stop (part (b)). Part (c)
# adds the steps, the guards and the cleanup path on top of them.
#
#   t_scale <seconds>     <seconds> / R9700_TIME_SCALE, two decimals: every sleep in lib/
#   t_ceiling <seconds>   <seconds> / R9700_CEILING_SCALE (default: R9700_TIME_SCALE), two decimals: every ceiling of the adapter
#                         both: 1 when the scale is not a positive integer, 2 on bad seconds
#   state_dir             the state directory: R9700_STATE_DIR, else ${XDG_STATE_HOME:-$HOME/.local/state}/r9700
#   marker_path           <state dir>/recovery.env
#   lock_take <verb>      flock -n on <state dir>/lock (descriptor 9), holder line "<pid> <verb> <UTC time>"; 0, 4 when held, 2 on a bad state dir
#   lock_release          closes descriptor 9
#   proc_ticks <pid>      field 22 of /proc/<pid>/stat (the start time in clock ticks); empty for a pid that is not there
#   session_pids <sid>    the pids whose session id (field 6) is <sid>
#   session_stop <sid>    TERM to every member (never to the caller), the grace of 10 s, then KILL
#   worker_start <gate file> <log> <cmd...>   setsid lib/worker_gate.sh <gate> <cmd...> 9>&-; sets WORKER_PID and WORKER_TICKS
#   gate_open <gate file> creates the gate file: the worker may run

# _scale_div <scale variable name> <scale value> <seconds>: the one division. The result is never below 0.01, because `timeout 0` means
# no ceiling at all.
_scale_div() {
  local name="$1" scale="$2" seconds="${3:-}"
  case $scale in
    '' | *[!0-9]* | 0 | 0[0-9]*)
      echo "t_scale: $name must be a positive integer without a leading zero (got \"$scale\")" >&2
      return 1
      ;;
  esac
  if ! [[ $seconds =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "t_scale: usage: t_scale <seconds> (a non-negative number; got \"$seconds\")" >&2
    return 2
  fi
  awk -v seconds="$seconds" -v scale="$scale" 'BEGIN { v = seconds / scale; if (v < 0.01) v = 0.01; printf "%.2f\n", v }' 9>&-
}

# t_scale <seconds>: EVERY sleep in lib/ takes its number from here, so a test can run 1200 s as 12 s (R9700_TIME_SCALE=100). The default
# scale is 1: the production values are the literals of the old scripts. R9700_TIME_SCALE is a test knob: the environment only, never
# machine.env.
t_scale() { _scale_div R9700_TIME_SCALE "${R9700_TIME_SCALE-1}" "${1:-}"; }

# t_ceiling <seconds>: every ceiling of an adapter call (and its kill-after grace). R9700_CEILING_SCALE divides only these; it defaults to
# R9700_TIME_SCALE, and a test sets it to 1 to keep the ceilings real while the sleeps run fast.
t_ceiling() {
  if [ -n "${R9700_CEILING_SCALE+set}" ]; then
    _scale_div R9700_CEILING_SCALE "$R9700_CEILING_SCALE" "${1:-}"
  else
    _scale_div R9700_TIME_SCALE "${R9700_TIME_SCALE-1}" "${1:-}"
  fi
}

# ---------- the state directory and the lock (decision 2, amendment A1) ----------
_RG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

state_dir() { printf '%s\n' "${R9700_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/r9700}"; }

marker_path() { printf '%s/recovery.env\n' "$(state_dir)"; }

# lock_take <verb>: the atomic operation is the kernel's flock(2), which a SIGKILL releases. The lock file is opened for append (opening it
# for write would empty the holder line a refused taker is about to read); the winner then rewrites it. Descriptor 9 belongs to the
# supervisor alone: every child it starts is started with 9>&- (amendment A1), or a surviving child would keep the lock after a SIGKILL.
lock_take() {
  local dir file line
  dir="$(state_dir)"
  if ! mkdir -p -m 700 "$dir" 2> /dev/null; then
    echo "r9700: the state directory $dir cannot be made" >&2
    return 2
  fi
  file="$dir/lock"
  exec 9>> "$file"
  if ! flock -n 9; then
    line=""
    read -r line < "$file" 2> /dev/null
    exec 9>&-
    if [[ $line =~ ^([0-9]+)\ ([A-Za-z0-9_-]+)\ ([0-9T:Z-]+)$ ]]; then
      echo "r9700: another run holds $file: pid ${BASH_REMATCH[1]}, ${BASH_REMATCH[2]}, since ${BASH_REMATCH[3]}" >&2
    else
      echo "r9700: another run holds $file: holder unknown" >&2
    fi
    return 4
  fi
  : > "$file"
  printf '%s %s %s\n' "$BASHPID" "$1" "$(date -u +%FT%TZ)" >&9
  _RG_LOCK_OWNER="$BASHPID" # the process that holds the lock: the adapter keeps descriptor 9 open there and closes it in every fork
}

lock_release() { exec 9>&-; unset _RG_LOCK_OWNER; }

# ---------- processes and sessions (decision 1, amendment A8) ----------
# proc_ticks <pid>: field 22 of /proc/<pid>/stat, read after the LAST ")" (the command name may hold one); empty when the pid is gone
proc_ticks() {
  local stat
  stat="$(cat "/proc/$1/stat" 2> /dev/null)" || return 0
  stat="${stat##*) }"
  set -- $stat
  echo "${20:-}"
}

# session_pids <sid>: every live pid (a zombie is not live) whose session id (field 6 of /proc/<pid>/stat) is <sid>; 2 when <sid> is not a
# number
session_pids() {
  local stat dir sid="${1:-}"
  if ! [[ $sid =~ ^[0-9]+$ ]]; then
    echo "session_pids: \"$sid\" is not a session id" >&2
    return 2
  fi
  for dir in /proc/[0-9]*; do
    { IFS= read -r stat < "$dir/stat"; } 2> /dev/null || continue
    stat="${stat##*) }"
    set -- $stat
    [ "${1:-Z}" != Z ] && [ "${4:-}" = "$sid" ] && echo "${dir#/proc/}"
  done
  return 0
}

# _session_signal <sid> <signal>: sends <signal> to every live member of the session except the caller; 1 when there is no member
_session_signal() {
  local pid
  local -a members=()
  while read -r pid; do
    [ "$pid" = "$$" ] || [ "$pid" = "$BASHPID" ] || members+=("$pid")
  done < <(session_pids "$1")
  [ "${#members[@]}" -gt 0 ] || return 1
  kill "-$2" "${members[@]}" 2> /dev/null
  return 0
}

# session_stop <sid>: TERM to every member except the caller, up to 10 s of grace (t_scale; signal 0 asks who is left), then KILL.
session_stop() {
  local grace steps i
  grace="$(t_scale 10)" || return 1
  steps="$(awk -v g="$grace" 'BEGIN { n = int(g / 0.05); print (n < 1 ? 1 : n) }')"
  _session_signal "$1" TERM || return 0
  for ((i = 0; i < steps; i++)); do
    sleep 0.05 9>&-
    _session_signal "$1" 0 || return 0
  done
  _session_signal "$1" KILL
  return 0
}

# ---------- the worker and its gate (amendment A2, decision 3) ----------
# worker_start <gate file> <log> <cmd...>: starts the worker as `setsid lib/worker_gate.sh <gate> <cmd...>` with descriptor 9 closed
# (amendment A1) and its output appended to <log>. A background job of a non-interactive shell is not a group leader, so setsid does not
# fork: $! is the worker's pid, its process group id and its session id. The worker does nothing until gate_open.
worker_start() {
  local gate="$1" log="$2"
  shift 2
  setsid "$_RG_DIR/worker_gate.sh" "$gate" "$@" 9>&- >> "$log" 2>&1 &
  WORKER_PID=$!
  _worker_check_session "$WORKER_PID" || return 1
  WORKER_TICKS="$(proc_ticks "$WORKER_PID")"
  [ -n "$WORKER_TICKS" ]
}

# _worker_check_session <pid>: 0 when the process <pid> is the leader of a session of its own. `setsid` forks when its caller leads a process
# group (job control on): $! is then a process that is not the worker, and the worker's pid, ticks and session would all be wrong. The
# fork of the shell has to reach its setsid call first, so this polls (at most about 1 s) until the session id is the pid, and gives up at
# once when the process is gone (the parent of a forking setsid exits at once).
_worker_check_session() {
  local pid="$1" stat sid="" i
  for ((i = 0; i < 100; i++)); do
    sid=""
    if { IFS= read -r stat < "/proc/$pid/stat"; } 2> /dev/null; then
      stat="${stat##*) }"
      set -- $stat
      sid="${4:-}"
    else
      break
    fi
    [ "$sid" = "$pid" ] && return 0
    sleep 0.01 9>&-
  done
  echo "worker_start: the worker (pid $pid) is not the leader of a session of its own (session ${sid:-gone}): setsid forked because its caller leads a process group; the worker gives up at the gate by itself" >&2
  return 1
}

gate_open() { : > "$1"; }
