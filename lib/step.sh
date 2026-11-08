#!/usr/bin/env bash
# lib/step.sh — one guarded step: the quiet wait, the disk gate, the admission that stops the operator's server, the worker in its own
# session behind the gate, the guards, the typed outcome, the retries (decisions 6, 8, 15; amendments A5, A8, A14). SOURCED; defines
# functions and runs nothing. Bash >= 4.4, `set -u` safe, no `set -e`. Needs lib/run_guarded.sh, lib/restore.sh, lib/adapter.sh,
# lib/guard_quiet.sh, lib/guard_ram.sh, lib/guard_deadline.sh, lib/disk_gate.sh and a loaded config with the deadline computed (supervise does
# both); it is called inside `supervise` (lib/run_guarded.sh), which owns the lock, the traps and the one cleanup.
#
#   step_run <label> -- <command...>   runs ONE step and neither restores the server nor releases the lock. Returns the exit table of decision 6:
#                                      0 done; 2 refused arguments, or the operator's ComfyUI is listed at an admission (E1.S2); 5 a restore while waiting did not become ready; 6 the deadline stopped the
#                                      step or the worker said nothing more fits; 7 the step failed MAX_FAILED_TRIES times; 8 not quiet before
#                                      the deadline, or the server-stop budget is used, or the worker exited 3 more often than the repeat bound
#                                      (3 x MAX_FAILED_TRIES); 9 the disk gate stopped the run
#
# Per invocation (reset by supervise): _RG_STEP_N counts worker starts (the number in steps/<n>.*), _RG_STOPS the ACTUAL stops of the operator's server, _RG_PROD_STOPPED
# says whether the marker stands (the server is stopped by us), _RG_PROD_WAS what the server's state was before the first stop.

_STEP_LABEL_RE='^[a-z0-9][a-z0-9-]{0,39}$'

# _step_left: the production seconds left until T_STOP (negative once it has passed)
_step_left() { awk -v s="${T_STOP:?}" -v n="$(date +%s.%N 9>&-)" -v k="${R9700_TIME_SCALE-1}" 'BEGIN { printf "%.3f\n", (s - n) * k }' 9>&-; }

_step_expired() { awk -v l="$(_step_left)" 'BEGIN { exit !(l <= 0) }' 9>&-; }

# _step_restore: the restore of the operator's server in the middle of a run (decision 15: the PC is not quiet and the server must not stay
# down). 0 restored and ready, 5 not. The marker is removed by the restore itself.
_step_restore() {
  local rc
  rg_log "restoring the operator's server while the PC is not quiet"
  restore_now
  rc=$?
  if [ "$rc" -ne 0 ]; then _RG_RESTORE_RC=5; return 5; fi
  _RG_PROD_STOPPED=no
  rg_log restored
}

# _step_quiet_phase: one quiet wait of at most 900 s and at most the time to T_STOP. 0 quiet (admit), 1 not quiet and the server is running
# (wait again), 5 the restore did not become ready, 8 no time left, 2 the quiet knobs are refused.
_step_quiet_phase() {
  local left ceiling qrc
  left="$(_step_left)"
  if awk -v l="$left" 'BEGIN { exit !(l <= 0) }' 9>&-; then rg_err "r9700: not quiet before the deadline"; return 8; fi
  ceiling="$(awk -v l="$left" 'BEGIN { if (l > 900) l = 900; printf "%.3f", l }' 9>&-)"
  quiet_wait "$ceiling"
  qrc=$?
  if [ "$qrc" -eq 2 ]; then return 2; fi
  if _step_expired; then
    if [ "$qrc" -eq 0 ]; then rg_err "r9700: the deadline came before the step could start"; else rg_err "r9700: not quiet before the deadline"; fi
    return 8
  fi
  [ "$qrc" -eq 0 ] && return 0
  # not quiet, and a ceiling of 900 s is not the deadline: with the server stopped it goes back up while we wait (decision 15)
  if [ "${_RG_PROD_STOPPED:-no}" = yes ]; then _step_restore || return 5; fi
  return 1
}

# _step_disk_gate: the baseline at the first admission of the invocation, a check at every later one. 0 ok, 9 stop (the line goes to stderr).
_step_disk_gate() {
  local out rc state="$RUN_DIR/disk_gate.state"
  if [ "${_RG_DISK_BASED:-no}" = yes ]; then _rg_run out disk_gate_check "$state"; else _rg_run out disk_gate_baseline "$state"; fi
  rc=$?
  rg_log "disk gate: $out"
  if [ "$rc" -ne 0 ]; then rg_err "r9700: disk gate: $out"; return 9; fi
  _RG_DISK_BASED=yes
}

# _step_failed_try <kind> <detail>: counts one failed try. 0 when there are tries left (the caller waits and repeats), 7 when they are used up.
_step_failed_try() {
  _RG_TRIES=$((_RG_TRIES + 1))
  rg_log "failed try $_RG_TRIES of $R9700_MAX_FAILED_TRIES: $1 $2"
  if [ "$_RG_TRIES" -ge "$R9700_MAX_FAILED_TRIES" ]; then
    rg_err "r9700: step failed $_RG_TRIES times, last: $1 $2"
    return 7
  fi
  return 0
}

# _step_guards_start <session id> <step n> <outcome file>: the RAM guard and the deadline watcher, two background forks of the supervisor with
# descriptor 9 closed (amendment A1); their ids go to _RG_WATCHERS
_step_guards_start() {
  local sid="$1" n="$2" outcome="$3"
  _RG_WATCHERS=()
  # what a guard prints (a failed stop of a container) goes to its own log, beside the lines it writes there itself
  ( guard_ram "$sid" "$R9700_RAM_MIN_MB" "$outcome" "$RUN_DIR/steps/$n.ram_guard.log" ) 9>&- >> "$RUN_DIR/steps/$n.ram_guard.log" 2>&1 &
  _RG_WATCHERS+=("$!")
  ( deadline_watch "$sid" "$outcome" "$RUN_DIR/steps/$n.deadline.log" ) 9>&- >> "$RUN_DIR/steps/$n.deadline.log" 2>&1 &
  _RG_WATCHERS+=("$!")
}

# _step_stop_prod: the stop of the operator's server. 0 it is stopped; 1 it is not (or cannot be shown to be gone): _RG_FAIL says what, and the caller counts a failed try.
# A stop that returns non-zero is not yet a failure (2026-11-03: `wslc stop vllm` returned 1 in 2 of 6 admissions and the server WAS stopped: the next admission found
# it not listed, and each time a failed try was charged for a stop that had worked). So after a non-zero stop the list is read again: a server that is no longer listed
# is a stopped server (one line says so; the stop stays charged, as every stop is), one that is still listed, or a list that cannot be read, is the failed try it always was.
# What wslc printed (the last 20 lines, from wslc_stop) is logged on a failure, line by line, so the cause is no longer lost.
_step_stop_prod() {
  local rc out line listing
  _rg_run out wslc_stop "$R9700_PROD_CONTAINER"
  rc=$?
  [ "$rc" -eq 0 ] && return 0
  while IFS= read -r line; do [ -n "$line" ] && rg_log "stop output: $line"; done <<< "$out"
  if _rg_run listing wslc_list && ! grep -Fxq -- "$R9700_PROD_CONTAINER" <<< "$listing"; then
    rg_log "stop returned $rc but the server is gone: counted as stopped"
    return 0
  fi
  _RG_FAIL="stopping $R9700_PROD_CONTAINER failed (code $rc)"
  return 1
}

# _step_admit <label> <command...>: the stop of the operator's server and the start of the worker. 0 the worker runs (WORKER_PID, behind an open
# gate, guards on); 1 a failed admission (_RG_FAIL says what; the caller counts a try); 2 the operator's ComfyUI is listed (comfy_owner_check prints the line; no stop,
# no marker, no worker); 8 the stop budget is used; 9 the disk gate stopped.
_step_admit() {
  local label="$1" listing rc n listed=no gate outcome wlog
  shift
  _step_disk_gate || return 9
  if ! _rg_run listing wslc_list; then _RG_FAIL="the container list failed (${listing%%$'\n'*})"; return 1; fi
  grep -Fxq -- "$R9700_PROD_CONTAINER" <<< "$listing" && listed=yes
  comfy_owner_check "$listing" || return 2 # the operator's ComfyUI started since the check of `supervise`: before the stop cap, the marker and the stop
  # MAX_SERVER_STOPS is a RUN-WIDE cap on ACTUAL stops of the operator's server (E3.S2 decision 4): charged right before the stop below, and only when the
  # server is listed. An admission that finds it already down (the quiet chain after the first step, the retry after an exit 3) charges nothing, so a quiet
  # chain of any length costs ONE stop and ONE restore. An admission that would stop the server past the cap is refused HERE: before the marker, the
  # stop and any worker; the marker of an earlier stop stands, and cleanup_once restores from it. Nothing resets the count inside an invocation.
  if [ "$listed" = yes ] && [ $((_RG_STOPS + 1)) -gt "$R9700_MAX_SERVER_STOPS" ]; then
    rg_err "r9700: stopped the operator's server $_RG_STOPS times, limit MAX_SERVER_STOPS=$R9700_MAX_SERVER_STOPS"
    return 8
  fi
  # What the restore must put back: yes when the server runs now; else what it was before our first stop
  if [ "$listed" = yes ]; then _RG_PROD_WAS=yes; elif [ "${_RG_PROD_STOPPED:-no}" != yes ]; then _RG_PROD_WAS=no; fi
  n=$((_RG_STEP_N + 1))
  _RG_STEP_N="$n"
  gate="$RUN_DIR/steps/$n.gate" outcome="$RUN_DIR/steps/$n.outcome" wlog="$RUN_DIR/steps/$n.worker.log"
  # the marker BEFORE the stop (decision 3), and its copy as evidence with its time kept
  if ! marker_write_base "$MARKER_FILE" "$RUN_ID" "$_RG_PROD_WAS" "$RUN_DIR"; then _RG_FAIL="the recovery marker cannot be written"; return 1; fi
  _RG_PROD_STOPPED=yes
  cp -p "$MARKER_FILE" "$RUN_DIR/steps/$n.marker" # the evidence if the supervisor dies before the worker keys; replaced below, with this time
  if [ "$listed" = yes ]; then
    _RG_STOPS=$((_RG_STOPS + 1))
    _step_stop_prod || return 1
    rg_log "stopped the operator's server (stop $_RG_STOPS of $R9700_MAX_SERVER_STOPS)"
  fi
  rg_log admitted
  export R9700_RUN_DIR="$RUN_DIR" R9700_STEP_N="$n" R9700_STEP_LABEL="$label" R9700_OUTCOME_FILE="$outcome"
  if ! worker_start "$gate" "$wlog" "$@"; then _RG_FAIL="the worker did not start as a session of its own"; return 1; fi
  if [ "${R9700_TEST_KILL_BEFORE_GATE:-}" = 1 ]; then kill -KILL "$$"; fi # scenario L21: the window between the worker start and the gate
  if ! marker_add_worker "$MARKER_FILE" "$WORKER_PID" "$WORKER_TICKS"; then
    session_stop "$WORKER_PID"
    wait "$WORKER_PID" 2> /dev/null
    _RG_FAIL="the worker keys cannot be written to the marker"
    return 1
  fi
  # the evidence copy of the marker WITH the worker keys, carrying the time of the first write (the one before the stop)
  cp "$MARKER_FILE" "$RUN_DIR/steps/$n.marker.part" && touch -r "$RUN_DIR/steps/$n.marker" "$RUN_DIR/steps/$n.marker.part" \
    && mv "$RUN_DIR/steps/$n.marker.part" "$RUN_DIR/steps/$n.marker"
  _RG_WORKER_SID="$WORKER_PID" _RG_OUTCOME="$outcome"
  rg_log "worker started: session $WORKER_PID, start ticks $WORKER_TICKS"
  _step_guards_start "$WORKER_PID" "$n" "$outcome" # the guards watch from the first moment the worker may run
  gate_open "$gate" # only now: the marker names the worker and the guards are on
  return 0
}

# _step_wait_worker: waits for the worker, stops the guards, ends what is left of its session, and settles the typed outcome. Sets O_KIND O_RC
# O_DETAIL. The first writer of the outcome wins: a guard that wrote before the worker ended keeps its word.
_step_wait_worker() {
  local rc pid sid="$WORKER_PID" outcome="$_RG_OUTCOME" ticks="$WORKER_TICKS" tick grace now
  tick="$(t_scale 5)"
  grace="$(ceil_seconds "$(t_scale 60)")"
  # The wait has a ceiling of its own: the deadline watcher stops the worker at T_STOP, and when the watcher is gone (killed, crashed) the
  # supervisor does it a minute later. A zombie is not alive (guard_alive); `wait` then only collects the code.
  while guard_alive "$sid" "$ticks"; do
    printf -v now '%(%s)T' -1
    if [ "$now" -ge $((T_STOP + grace)) ]; then
      outcome_write "$outcome" KIND=deadline "DETAIL=the deadline watcher did not stop the worker (T_STOP $T_STOP)"
      rg_log "the worker is still running a minute after T_STOP: stopping its session"
      session_stop "$sid"
      break
    fi
    _rg_sleep "$tick"
  done
  wait "$sid"
  rc=$?
  for pid in "${_RG_WATCHERS[@]}"; do _rg_tree_kill "$pid"; done
  _RG_WATCHERS=()
  session_stop "$sid" # a grandchild the worker left behind (amendment A8)
  _RG_WORKER_SID="" _RG_OUTCOME=""
  rg_log "worker ended rc=$rc"
  outcome_write "$outcome" KIND=worker "RC=$rc" "DETAIL=$rc"
  outcome_read "$outcome" || { O_KIND=worker O_RC="$rc" O_DETAIL="$rc"; }
  # A guard that stopped the step was killed above, maybe in the middle of its second container (the worker follows its first one and ends at
  # once): whatever it did not reach is stopped here, BEFORE a retry could admit next to a live container of this try.
  case $O_KIND in ram_guard | deadline) _step_stop_containers ;; esac
}

# _step_stop_containers: every prefixed container, log tails first; no stop time (cleanup-phase work, decision 8), so that it also works after T_STOP
_step_stop_containers() {
  local R9700_T_STOP=""
  container_stop_all "$RUN_DIR" || true
}

# _step_settle: what the outcome means. 0 done, 10 try again (nothing counted, or a counted try with tries left), 6 7 9 final.
_step_settle() {
  local when
  case "$O_KIND:$O_RC" in
    worker:0) _RG_UNITS_DONE=$((_RG_UNITS_DONE + 1)); return 0 ;;
    worker:3)
      # not a failed try, and an admission that finds the server down charges no stop: so the repeats have a bound of their own (3 x MAX_FAILED_TRIES, or the knob), or a worker whose
      # gate and the supervisor's quiet check disagree would be started again until T_STOP
      _RG_WAITS=$((_RG_WAITS + 1))
      if [ "$_RG_WAITS" -gt "$_RG_WAIT_LIMIT" ]; then
        rg_err "r9700: $_RG_STEP_LABEL waited $_RG_WAITS times (worker exit 3), limit $_RG_WAIT_LIMIT"
        return 8
      fi
      rg_log "not quiet at a unit start, waiting"
      return 10
      ;;
    refused:*) rg_err "r9700: the worker refused to go on: $O_DETAIL"; return 2 ;; # the worker's own typed word, never a bare exit code: a retry would be refused again
    worker:4) ;;
    deadline:*) ;;
    disk_gate:*) rg_err "r9700: disk gate: $O_DETAIL"; return 9 ;;
    *) _step_failed_try "$O_KIND" "$O_DETAIL" && return 10; return 7 ;;
  esac
  when="$(date -u +%FT%TZ 9>&-)"
  rg_err "r9700: deadline: step stopped at $when, $_RG_UNITS_DONE units done"
  return 6
}

# step_budget_reset: the failed-try count and the exit-3 repeat count of the next step (step_run zeroes them itself; a chain says it where it begins a step). The stop count
# _RG_STOPS is run-wide and is NEVER reset by a step: a chain that bounced the server once per step would otherwise have no cap at all (E3.S2 decision 4).
step_budget_reset() { _RG_TRIES=0 _RG_WAITS=0; }

# _step_wait_limit: prints how many exit-3 repeats one step may have: 3 x MAX_FAILED_TRIES, or R9700_MAX_WAIT_REPEATS (a test knob, the environment only, never machine.env);
# 2 and one line when the knob is not a whole number from 1 to 999999
_step_wait_limit() {
  local knob="${R9700_MAX_WAIT_REPEATS-}"
  if [ -z "$knob" ]; then echo $((3 * R9700_MAX_FAILED_TRIES)); return 0; fi
  [[ $knob =~ ^[1-9][0-9]{0,5}$ ]] || { echo "r9700: R9700_MAX_WAIT_REPEATS \"$knob\" is not a whole number from 1 to 999999" >&2; return 2; }
  echo "$knob"
}

step_run() {
  local label="${1:-}" rc
  if [ "${2:-}" != -- ] || [ "$#" -lt 3 ]; then echo "r9700: step: usage: step_run <label> -- <command...>" >&2; return 2; fi
  if ! [[ $label =~ $_STEP_LABEL_RE ]]; then echo "r9700: step: the label \"$label\" is not $_STEP_LABEL_RE" >&2; return 2; fi
  shift 2
  step_budget_reset
  _RG_STEP_LABEL="$label"
  _RG_WAIT_LIMIT="$(_step_wait_limit)" || return 2
  while :; do
    _step_quiet_phase
    rc=$?
    case $rc in 0) ;; 1) continue ;; *) return "$rc" ;; esac
    _step_admit "$label" "$@"
    rc=$?
    case $rc in
      0) ;;
      1) _step_failed_try admit "$_RG_FAIL" || return 7; continue ;;
      *) return "$rc" ;;
    esac
    _step_wait_worker
    _step_settle
    rc=$?
    [ "$rc" -eq 10 ] && continue
    return "$rc"
  done
}
