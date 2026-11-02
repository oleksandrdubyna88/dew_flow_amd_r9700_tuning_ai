#!/usr/bin/env bash
# lib/guard_deadline.sh — the deadline watcher (decision 8). SOURCED; defines functions and runs nothing. Bash >= 4.4, `set -u` safe, no
# `set -e`. Needs lib/guard_common.sh and the variable T_STOP (epoch seconds; deadline_compute sets it).
#
#   deadline_watch <worker session id> <outcome file> <log>
#
# Fires at T_STOP, not at T_END, so the cleanup budget stays free (night5.sh lines 21-24, with its 30 s check as the longest sleep; the last
# sleep is cut to the time left, so the stop is not up to 30 s late). It writes KIND=deadline first, then stops every prefixed container (log
# tails saved first) and the whole worker session, and returns 0. It ends by itself (0, no outcome) when the worker's leader is gone. 2 on a
# bad argument.

deadline_watch() {
  local sid="${1:-}" outcome="${2:-}" log="${3:-}" ticks now left tick
  local R9700_T_STOP="" # cleanup-phase work: no stop time of its own (decision 8)
  if ! [[ $sid =~ ^[0-9]+$ ]]; then echo "deadline_watch: \"$sid\" is not a session id" >&2; return 2; fi
  if ! [[ ${T_STOP:-} =~ ^[0-9]+$ ]]; then echo "deadline_watch: T_STOP \"${T_STOP:-}\" is not an epoch second" >&2; return 2; fi
  if [ -z "$outcome" ] || [ -z "$log" ] || [ -z "${RUN_DIR:-}" ]; then echo "deadline_watch: needs an outcome file, a log and RUN_DIR" >&2; return 2; fi
  tick="$(t_scale 30)" || return 2
  ticks="$(proc_ticks "$sid")"
  [ -n "$ticks" ] || return 0
  while guard_alive "$sid" "$ticks"; do
    now="$(date +%s.%N 9>&-)"
    left="$(awk -v s="$T_STOP" -v n="$now" -v t="$tick" 'BEGIN { l = s - n; if (l <= 0) { print 0; exit } if (l > t) l = t; if (l < 0.01) l = 0.01; printf "%.3f", l }' 9>&-)"
    if [ "$left" = 0 ]; then
      guard_fire "$sid" "$outcome" "$log" deadline "deadline reached (T_STOP $T_STOP)"
      return 0
    fi
    _rg_fork_sleep "$left"
  done
  return 0
}
