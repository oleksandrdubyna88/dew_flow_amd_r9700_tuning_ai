#!/usr/bin/env bash
# lib/guard_common.sh — what the guards share. SOURCED; defines functions and runs nothing. Bash >= 4.4, `set -u` safe, no `set -e`. Needs
# lib/run_guarded.sh (outcome_write, session_stop, proc_ticks) and lib/restore.sh (container_stop_all).
#
#   guard_log <log> <text>                                  appends "<UTC time> <text>" to the guard's own log
#   guard_alive <session id> <start ticks>                  0 while the worker's leader is the same live process (not a zombie)
#   guard_fire <session id> <outcome> <log> <kind> <detail> the stop of a guard: the outcome first (an exclusive create: another writer's
#                                                           stays), then every prefixed container (its log tail saved BEFORE the stop), then
#                                                           the whole worker SESSION (amendment A8: TERM, the grace, KILL). Needs RUN_DIR.
#
# A guard runs as a background fork of the supervisor. Whatever it does is cleanup-phase work: it has no stop time of its own (decision 8),
# so every guard clears R9700_T_STOP for itself.

guard_log() { printf '%s %s\n' "$(date -u +%FT%TZ 9>&-)" "$2" >> "$1"; }

# guard_alive <pid> <start ticks>: 0 while the process is running (not a zombie) with those start ticks
guard_alive() {
  proc_stat_fields "$1" || return 1
  [ "${PROC_STAT[0]:-Z}" != Z ] && [ "${PROC_STAT[19]:-}" = "$2" ]
}

guard_fire() {
  local sid="$1" outcome="$2" log="$3" kind="$4" detail="$5"
  guard_log "$log" "$kind: $detail; stopping the step"
  outcome_write "$outcome" "KIND=$kind" "DETAIL=$detail"
  container_stop_all "${RUN_DIR:?}"
  session_stop "$sid"
}
