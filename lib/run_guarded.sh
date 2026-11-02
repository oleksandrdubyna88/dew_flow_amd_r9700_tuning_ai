#!/usr/bin/env bash
# lib/run_guarded.sh — the supervisor's engine. SOURCED; defines functions and runs nothing. Bash >= 4.4, `set -u` safe, no `set -e`.
#
# Built so far: the scale functions (part (a)); the lock, the worker start behind its gate, and the session stop (part (b)); the outcome
# file, the deadline arithmetic, the supervisor log and the run folder, the interruptible sleep, and `supervise` with the one cleanup path
# (part (c); the step itself is lib/step.sh, the guards are lib/guard_*.sh).
#
#   t_scale <seconds>     <seconds> / R9700_TIME_SCALE, two decimals: every sleep in lib/
#   ceil_seconds <number> the number rounded up to a whole second
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
#   outcome_write <file> KIND=.. [RC=..] [DETAIL=..]   an exclusive create (the first writer wins): 0 written, 1 the file exists, 2 bad words
#   outcome_read <file>   sets O_KIND O_RC O_DETAIL O_ENDED_AT; 2 with `outcome: <file>:<line>: ..` when the file cannot be trusted
#   deadline_calc <now> <HH:MM or ""> <max run minutes> <budget s>   prints "<T_END> <T_STOP>" (two decimals, durations divided by the time scale)
#   deadline_compute [--quiet]   T_END and T_STOP as whole epoch seconds from the config, exports R9700_T_STOP; 2 (the numbers are still set) when under 60 s
#                         remain before the budget (--quiet: the line is only in DEADLINE_WHY)
#   rg_log <text> / rg_err <text>   a supervisor line: to stdout (stderr) and to <run dir>/supervisor.log
#   run_dir_new           RUN_DIR and RUN_ID under RESULTS_DIR/runs, with steps/ guard/ supervisor.log status; sets MARKER_FILE
#   _rg_sleep <seconds>   a sleep a trapped signal ends at once (a foreground sleep would delay the trap until it ends)
#   _rg_run <var> <cmd...>   an adapter call a trapped signal ends at once (the same reason: a $(...) or a pipeline would hold the trap)

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

# ceil_seconds <number>: the number rounded UP to a whole second (a whole number stays); the one rounding of every window and grace in lib/
ceil_seconds() { awk -v t="${1:-}" 'BEGIN { n = int(t); print (t > n ? n + 1 : n) }' 9>&-; }

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
# proc_stat_fields <pid>: the ONE parse of /proc/<pid>/stat. Sets the array PROC_STAT to the fields AFTER the command name (which may hold spaces and
# a ")": it is cut at the LAST ")"), so PROC_STAT[0] is the state (field 3), [1] the parent (4), [2] the process group (5), [3] the session (6)
# and [19] the start time in clock ticks (22). No fork, so a scan of /proc is cheap. 1, and an empty array, when the process is gone.
proc_stat_fields() {
  local _ps_line
  PROC_STAT=()
  { IFS= read -r _ps_line < "/proc/$1/stat"; } 2> /dev/null || return 1
  read -r -a PROC_STAT <<< "${_ps_line##*) }"
}

# proc_ticks <pid>: field 22 of /proc/<pid>/stat (proc_stat_fields); empty when the pid is gone
proc_ticks() {
  proc_stat_fields "$1" || return 0
  echo "${PROC_STAT[19]:-}"
}

# session_pids <sid>: every live pid (a zombie is not live) whose session id (field 6 of /proc/<pid>/stat) is <sid>; 2 when <sid> is not a
# number
session_pids() {
  local dir sid="${1:-}"
  if ! [[ $sid =~ ^[0-9]+$ ]]; then
    echo "session_pids: \"$sid\" is not a session id" >&2
    return 2
  fi
  for dir in /proc/[0-9]*; do
    proc_stat_fields "${dir#/proc/}" || continue
    [ "${PROC_STAT[0]:-Z}" != Z ] && [ "${PROC_STAT[3]:-}" = "$sid" ] && echo "${dir#/proc/}"
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
  local pid="$1" sid="" i
  for ((i = 0; i < 100; i++)); do
    sid=""
    if proc_stat_fields "$pid"; then sid="${PROC_STAT[3]:-}"; else break; fi
    [ "$sid" = "$pid" ] && return 0
    sleep 0.01 9>&-
  done
  echo "worker_start: the worker (pid $pid) is not the leader of a session of its own (session ${sid:-gone}): setsid forked because its caller leads a process group; the worker gives up at the gate by itself" >&2
  return 1
}

gate_open() { : > "$1"; }

# ---------- the outcome file (decision 6) ----------
_RG_KINDS="worker ram_guard disk_gate deadline interrupted refused"

# outcome_write <file> KIND=<kind> [RC=<number>] [DETAIL=<text>] [ENDED_AT=<UTC>]: the typed outcome of one step, the lines KIND, RC, DETAIL and
# ENDED_AT (now, UTC, when not given). An exclusive create: the whole file is written to a part file and linked to its name, so the first
# writer wins and a reader never sees half a file. 0 written; 1 the file exists (another writer was first); 2 the words are wrong.
outcome_write() {
  local file="$1" kind="" rc="" detail="" ended="" word part
  shift
  for word in "$@"; do
    case $word in
      KIND=*) kind="${word#KIND=}" ;;
      RC=*) rc="${word#RC=}" ;;
      DETAIL=*) detail="${word#DETAIL=}" ;;
      ENDED_AT=*) ended="${word#ENDED_AT=}" ;;
      *) echo "outcome: \"${word%%=*}\" is not a key of an outcome file (KIND, RC, DETAIL, ENDED_AT)" >&2; return 2 ;;
    esac
  done
  case " $_RG_KINDS " in
    *" $kind "*) [ -n "$kind" ] || { echo "outcome: KIND is missing; legal: $_RG_KINDS" >&2; return 2; } ;;
    *) echo "outcome: KIND \"$kind\" is not legal; legal: $_RG_KINDS" >&2; return 2 ;;
  esac
  if [ -n "$rc" ] && ! [[ $rc =~ ^[0-9]+$ ]]; then echo "outcome: RC \"$rc\" is not a number" >&2; return 2; fi
  detail="${detail//$'\n'/ }"
  detail="${detail//$'\r'/}"
  [ -n "$ended" ] || ended="$(date -u +%FT%TZ 9>&-)"
  part="$file.part.$BASHPID"
  if ! printf 'KIND=%s\nRC=%s\nDETAIL=%s\nENDED_AT=%s\n' "$kind" "$rc" "$detail" "$ended" > "$part" 2> /dev/null; then
    rm -f "$part"
    echo "outcome: cannot write $part" >&2
    return 2
  fi
  if ln "$part" "$file" 2> /dev/null; then rm -f "$part"; return 0; fi
  rm -f "$part"
  [ -e "$file" ] && return 1
  echo "outcome: cannot create $file" >&2
  return 2
}

# outcome_read <file>: sets O_KIND, O_RC, O_DETAIL and O_ENDED_AT. 2 with one `outcome: <file>:<line>: ...` line for a file that is missing,
# empty, has a key it does not know, a kind that is not legal or a code that is not a number.
outcome_read() {
  local file="$1" line n=0 key value
  O_KIND="" O_RC="" O_DETAIL="" O_ENDED_AT=""
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then echo "outcome: $file: cannot read (it is missing or not a readable file)" >&2; return 2; fi
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    if ! [[ $line =~ ^(KIND|RC|DETAIL|ENDED_AT)=(.*)$ ]]; then echo "outcome: $file:$n: not a KIND, RC, DETAIL or ENDED_AT line" >&2; return 2; fi
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    case $key in
      KIND)
        case " $_RG_KINDS " in *" $value "*) O_KIND="$value" ;; *) echo "outcome: $file:$n: KIND \"$value\" is not legal; legal: $_RG_KINDS" >&2; return 2 ;; esac
        ;;
      RC)
        [[ -z $value || $value =~ ^[0-9]+$ ]] || { echo "outcome: $file:$n: RC is not a number" >&2; return 2; }
        O_RC="$value"
        ;;
      DETAIL) O_DETAIL="$value" ;;
      ENDED_AT) O_ENDED_AT="$value" ;;
    esac
  done < "$file"
  [ -n "$O_KIND" ] || { echo "outcome: $file: no KIND line (the file is empty or half written)" >&2; return 2; }
}

# ---------- the deadline (decision 8) ----------
# deadline_calc <now epoch> <HH:MM or ""> <max run minutes> <budget s>: prints "<T_END> <T_STOP>". T_END is the sooner of the next occurrence of
# the clock time (an absolute time of day: the scale does not touch it) and now + the run minutes; T_STOP is T_END minus the cleanup budget.
# The two DURATIONS are divided by R9700_TIME_SCALE, so a test runs ten minutes as six seconds. 1 with a line when the scale is invalid.
deadline_calc() {
  local now="$1" hhmm="$2" minutes="$3" budget="$4" run_s budget_s clock=""
  run_s="$(t_scale "$((minutes * 60))")" || return 1
  budget_s="$(t_scale "$budget")" || return 1
  if [ -n "$hhmm" ]; then
    clock="$(date -d "$hhmm" +%s 9>&-)"
    if awk -v c="$clock" -v n="$now" 'BEGIN { exit !(c <= n) }'; then clock="$(date -d "tomorrow $hhmm" +%s 9>&-)"; fi
  fi
  awk -v now="$now" -v run="$run_s" -v budget="$budget_s" -v clock="$clock" \
    'BEGIN { e = now + run; if (clock != "" && clock + 0 < e) e = clock + 0; printf "%.2f %.2f\n", e, e - budget }' 9>&-
}

# deadline_compute: T_END and T_STOP for this run from the loaded config, in whole epoch seconds (rounded DOWN: the stop is never later than
# the arithmetic says), and R9700_T_STOP (exported) for the adapter and the worker. Refuses with `deadline: only <n> s remain before the
# cleanup budget` (n in production seconds, so the scale does not change it) and returns 2 when T_STOP is less than 60 s away.
deadline_compute() {
  local now out stop_d end_d remain scale quiet=no
  [ "${1:-}" = --quiet ] && quiet=yes
  T_END="" T_STOP="" DEADLINE_WHY=""
  now="$(date +%s.%N 9>&-)"
  out="$(deadline_calc "$now" "$R9700_DEADLINE" "$R9700_MAX_RUN_MINUTES" "$R9700_CLEANUP_BUDGET_S")" || return 2
  read -r end_d stop_d <<< "$out"
  scale="${R9700_TIME_SCALE-1}"
  remain="$(awk -v s="$stop_d" -v n="$now" -v k="$scale" 'BEGIN { printf "%.0f", (s - n) * k }')"
  # the numbers are set before the refusal: `step --show-deadline` shows them even for a run that would be refused
  T_END="$(awk -v e="$end_d" 'BEGIN { printf "%d", e }')"
  T_STOP="$(awk -v e="$stop_d" 'BEGIN { printf "%d", e }')"
  export R9700_T_STOP="$T_STOP"
  if awk -v s="$stop_d" -v n="$now" -v m="$(t_scale 60)" 'BEGIN { exit !(s < n + m - 0.01) }'; then
    DEADLINE_WHY="deadline: only $remain s remain before the cleanup budget"
    [ "$quiet" = yes ] || echo "$DEADLINE_WHY" >&2
    return 2
  fi
}

# ---------- the supervisor log and the run folder ----------
# rg_log <text>: one supervisor line "<UTC time> <text>" to stdout and, once the run folder exists, to <run dir>/supervisor.log
rg_log() {
  local line
  line="$(date -u +%FT%TZ 9>&-) $*"
  printf '%s\n' "$line"
  if [ -n "${RUN_DIR:-}" ] && [ -d "$RUN_DIR" ]; then printf '%s\n' "$line" >> "$RUN_DIR/supervisor.log"; fi
  return 0
}

# rg_err <text>: the same line to stderr (a line the operator must see) and to the log
rg_err() {
  printf '%s\n' "$*" >&2
  if [ -n "${RUN_DIR:-}" ] && [ -d "$RUN_DIR" ]; then printf '%s %s\n' "$(date -u +%FT%TZ 9>&-)" "$*" >> "$RUN_DIR/supervisor.log"; fi
  return 0
}

# run_dir_new: RESULTS_DIR/runs/<UTC yyyymmddThhmmssZ>-<pid>[-<n>] (a second call in the same second adds -<n>; a folder is never reused), with
# steps/, guard/, supervisor.log and the status `running`. Sets RUN_DIR, RUN_ID and MARKER_FILE. 2 with one line when it cannot be made.
run_dir_new() {
  local base stamp n=0 id
  base="${R9700_RESULTS_DIR:?}/runs"
  stamp="$(date -u +%Y%m%dT%H%M%SZ 9>&-)"
  mkdir -p "$base" 2> /dev/null || { echo "r9700: the run folder cannot be made under $R9700_RESULTS_DIR" >&2; return 2; }
  id="$stamp-$$"
  while ! mkdir "$base/$id" 2> /dev/null; do
    n=$((n + 1))
    [ "$n" -le 100 ] && [ ! -e "$base/$id" -o -d "$base/$id" ] || { echo "r9700: the run folder cannot be made under $R9700_RESULTS_DIR" >&2; return 2; }
    id="$stamp-$$-$n"
  done
  RUN_ID="$id"
  RUN_DIR="$base/$id"
  mkdir "$RUN_DIR/steps" "$RUN_DIR/guard" && : > "$RUN_DIR/supervisor.log" && printf 'running\n' > "$RUN_DIR/status" \
    || { echo "r9700: the run folder cannot be made under $R9700_RESULTS_DIR" >&2; return 2; }
  MARKER_FILE="$(marker_path)"
}

# _rg_sleep <seconds>: sleeps in the background and waits for it, so a trapped signal ends the wait at once (bash delays a trap until a
# FOREGROUND child ends). The sleeper is remembered in _RG_SLEEPER for the signal handler (and the fork's own TERM trap) to kill.
_rg_sleep() {
  sleep "$1" 9>&- &
  _RG_SLEEPER=$!
  wait "$_RG_SLEEPER" 2> /dev/null
  _RG_SLEEPER=""
}

# _rg_run <variable> <command...>: runs a command of the adapter (a function) in the BACKGROUND with its output (stdout and stderr merged) in a
# file, waits for it, and puts the output in <variable> (without the last line break, as $(...) would). Why: bash holds a trapped signal
# until a FOREGROUND command ends, and a $(...) or a pipeline in the main shell is one, so a TERM to the supervisor would wait for an adapter
# call (up to its ceiling) that a hung wslc never ends. A `wait` ends at once; the signal handler then sends TERM to the call's fork (_RG_BG),
# whose adapter trap kills the call's whole process group. The code of the command is returned.
_rg_run() {
  local var="$1" file rc
  shift
  _RG_CALLS=$((${_RG_CALLS:-0} + 1))
  file="${RUN_DIR:?}/.call.$$.$_RG_CALLS"
  "$@" > "$file" 2>&1 9>&- &
  _RG_BG=$!
  wait "$_RG_BG"
  rc=$?
  _RG_BG=""
  printf -v "$var" '%s' "$(cat "$file" 2> /dev/null 9>&-)"
  rm -f "$file"
  return "$rc"
}

# _rg_tree_kill <pid>: ends a background fork of the supervisor (a guard, or the call of _rg_run) and everything below it, and reaps it.
# Every descendant gets TERM first: a call's adapter fork then kills the call's whole process group by its own trap (amendment A12), and a
# sleeper dies. The fork itself gets KILL: bash holds a trapped signal until a foreground command of the fork ends, and a guard that sits in
# a hung adapter call would answer TERM only at the call's ceiling. A fork has nothing to clean up that the supervisor's cleanup does not do.
_rg_tree_kill() {
  local root="$1" dir pid next
  local -A kids=() pgrp=() sess=()
  local -a queue=("$root") all=()
  local mysid
  proc_stat_fields "$BASHPID"
  mysid="${PROC_STAT[3]:-}"
  for dir in /proc/[0-9]*; do
    pid="${dir#/proc/}"
    proc_stat_fields "$pid" || continue
    kids[${PROC_STAT[1]:-0}]+="$pid "
    pgrp[$pid]="${PROC_STAT[2]:-}"
    sess[$pid]="${PROC_STAT[3]:-}"
  done
  while [ "${#queue[@]}" -gt 0 ]; do
    pid="${queue[0]}"
    queue=("${queue[@]:1}")
    all+=("$pid")
    for next in ${kids[$pid]:-}; do queue+=("$next"); done
  done
  kill -TERM "${all[@]:1}" 2> /dev/null
  # The root gets KILL, so its own adapter hook never runs: a DIRECT call of the root (a guard's container_stop_all, a wslc_stop) would keep
  # its process group, and GNU timeout only TERMs that group, so a grandchild that ignores TERM would live on. Every descendant that leads a
  # process group of its own in our session (a `timeout`) therefore gets the group KILL here, the way the adapter does it (amendment A12).
  for pid in "${all[@]:1}"; do
    [ "${pgrp[$pid]:-}" = "$pid" ] && [ "${sess[$pid]:-}" = "$mysid" ] && _adapter_group_kill "$pid"
  done
  kill -KILL "$root" 2> /dev/null
  wait "$root" 2> /dev/null
  return 0
}

# _rg_bg_kill: ends the background call of _rg_run (the signal handler and the cleanup call it)
_rg_bg_kill() {
  _rg_tree_kill "$_RG_BG"
  _RG_BG=""
}

# _rg_fork_sleep <seconds>: _rg_sleep for a background fork of the supervisor (a guard). A TERM to the fork ends it AND its sleeper: the
# adapter takes a fork's TERM trap away after each call, so it is put back here before every sleep.
_rg_fork_sleep() {
  trap '[ -z "${_RG_SLEEPER:-}" ] || kill "$_RG_SLEEPER" 2> /dev/null; exit 0' TERM
  _rg_sleep "$1"
}

# ---------- supervise and the one cleanup (decision 1, amendment A5) ----------
# supervise <verb> <prepare function> <body function> [body arguments...]: the lifecycle of one invocation that may change the machine:
#   lock -> restore-first (restore_first, lib/restore.sh) -> <prepare> (loads and validates the config; non-zero refuses, exit 2) -> the deadline
#   -> the run folder -> the INT, TERM and HUP traps -> <body> -> cleanup_once. The body calls step_run (lib/step.sh) any number of times; the
#   server is restored once, at the end, by cleanup_once, and between steps only by the wait rule of decision 15. Returns the body's code, or
#   5 when the restore at the end did not become ready, or 130/143 after an interrupt (the handler exits itself).
supervise() {
  local verb="${1:-}" prepare="${2:-}" body="${3:-}" rc kind crc
  shift 3
  _rg_state_reset
  lock_take "$verb" || return $?
  restore_first
  if ! "$prepare"; then lock_release; return 2; fi
  if ! deadline_compute; then lock_release; return 2; fi
  if ! run_dir_new; then lock_release; return 2; fi
  _rg_traps_on
  "$body" "$@"
  rc=$?
  case $rc in 0) kind=done ;; 6) kind=deadline ;; 7) kind=failed ;; 8) kind=not-quiet ;; 9) kind=disk-gate ;; *) kind=failed ;; esac
  cleanup_once "$kind"
  crc=$?
  [ "$crc" -eq 0 ] || rc="$crc"
  _rg_traps_off
  return "$rc"
}

# _rg_state_reset: the per-invocation state of the step engine (lib/step.sh) and of the cleanup
_rg_state_reset() {
  _RG_CLEANED=0 _RG_CLEANUP_RC=0 _RG_RESTORE_RC=0 _RG_STEP_N=0 _RG_STOPS=0 _RG_PROD_STOPPED=no _RG_PROD_WAS=no _RG_UNITS_DONE=0
  _RG_DISK_BASED=no _RG_WORKER_SID="" _RG_OUTCOME="" _RG_TRIES=0 _RG_FAIL="" _RG_SLEEPER="" _RG_BG="" _RG_CALLS=0
  _RG_WATCHERS=()
}

_rg_traps_on() {
  trap '_rg_on_signal INT' INT
  trap '_rg_on_signal TERM' TERM
  trap '_rg_on_signal HUP' HUP
  trap '_rg_on_exit' EXIT
}

_rg_traps_off() { trap - INT TERM HUP EXIT; }

# _rg_on_signal <INT|TERM|HUP>: the handler of the supervisor. The step's outcome says `interrupted` (when none was written), then the one cleanup
# path runs (the worker's session, the containers, the restore), then the exit: 130, 143 or 129.
_rg_on_signal() {
  local code
  trap '' INT TERM HUP # a second signal must not start a second handler before the cleanup has taken over
  case $1 in INT) code=130 ;; HUP) code=129 ;; *) code=143 ;; esac
  [ -z "${_RG_SLEEPER:-}" ] || kill "$_RG_SLEEPER" 2> /dev/null
  [ -z "${_RG_BG:-}" ] || _rg_bg_kill # a call in the background: its adapter fork kills the call's process group
  if [ -n "${_RG_OUTCOME:-}" ]; then outcome_write "$_RG_OUTCOME" KIND=interrupted "DETAIL=signal $1"; fi
  rg_log "signal $1: cleaning up"
  if cleanup_once interrupted; then rg_err "r9700: interrupted, restored"; else rg_err "r9700: interrupted, the restore did not finish (the marker stays)"; fi
  exit "$code"
}

# _rg_on_exit: a safety net for an `exit` of the body: the cleanup runs once even then. Only the process that owns the lock does it.
_rg_on_exit() {
  [ "$BASHPID" = "${_RG_LOCK_OWNER:-$$}" ] || return 0
  cleanup_once failed
}

# _rg_status_write <kind>: <run dir>/status, replaced atomically
_rg_status_write() {
  [ -n "${RUN_DIR:-}" ] && [ -d "$RUN_DIR" ] || return 0
  printf '%s\n' "$1" > "$RUN_DIR/status.part" && mv "$RUN_DIR/status.part" "$RUN_DIR/status"
}

# cleanup_once <kind>: runs ONCE per invocation (a flag; the second call, from a second signal or the EXIT trap, returns the first one's
# result). INT, TERM and HUP are ignored from its first line: a signal must not cut the restore in half. In this order: the guards, the whole
# worker SESSION (amendment A8), every prefixed container (its log tail saved first), the restore of the operator's server when a marker
# stands (not again when a restore of this invocation already failed: the marker stays, decision 5), the status file, the lock. It has no stop
# time (decision 8). Returns 0, or 5 when the restore did not become ready.
cleanup_once() {
  local kind="${1:-failed}" rc=0 pid
  local R9700_T_STOP=""
  trap '' INT TERM HUP # first: a signal between the flag and this line would run a second cleanup_once that returns at the flag and cleans nothing
  [ "${_RG_CLEANED:-0}" = 1 ] && return "${_RG_CLEANUP_RC:-0}"
  _RG_CLEANED=1
  for pid in "${_RG_WATCHERS[@]}"; do _rg_tree_kill "$pid"; done
  _RG_WATCHERS=()
  [ -z "${_RG_SLEEPER:-}" ] || kill "$_RG_SLEEPER" 2> /dev/null
  [ -z "${_RG_BG:-}" ] || _rg_bg_kill
  [ -z "${RUN_DIR:-}" ] || rm -f "$RUN_DIR"/.call."$$".* 2> /dev/null
  if [ -n "${_RG_WORKER_SID:-}" ]; then session_stop "$_RG_WORKER_SID"; _RG_WORKER_SID=""; fi
  if [ "${_RG_STEP_N:-0}" -gt 0 ]; then container_stop_all "${RUN_DIR:-/nonexistent}" || true; fi
  if [ "${_RG_RESTORE_RC:-0}" -ne 0 ]; then
    rc=5
  elif [ -n "${MARKER_FILE:-}" ] && [ -f "$MARKER_FILE" ]; then
    if restore_now; then rg_log restored; else rc=5; fi
  fi
  if [ "$rc" -ne 0 ]; then kind=restore-failed; fi
  _rg_status_write "$kind"
  lock_release
  _RG_CLEANUP_RC="$rc"
  return "$rc"
}
