#!/usr/bin/env bash
# lib/guard_ram.sh — the RAM guard (decision 7). SOURCED; defines functions and runs nothing. Bash >= 4.4, `set -u` safe, no `set -e`. Needs
# lib/guard_common.sh, lib/adapter.sh (win_ram_mb) and RUN_DIR.
#
#   guard_ram <worker session id> <min mb> <outcome file> <log>
#
# The loop of the old ram_guard_all.sh, read first and then slept: every 15 s (t_scale) one read of the Windows available MBytes. Below the
# limit the guard stops the step (guard_fire, KIND=ram_guard, DETAIL "available <mb> MB < <min> MB") and returns 1; a read exactly at the limit
# is fine. A read that is not an integer is a miss ("telemetry unreadable (<k> of 3)" in the log), a good read resets the count, and THREE
# misses in a row are unsafe (DETAIL "telemetry unreadable 3 times"): nothing counts an unreadable value as fine. The first read and every
# 20th are logged. The loop ends by itself (return 0, no outcome) when the worker's leader is gone: the same process by its start ticks, so a
# guard outlives a SIGKILLed supervisor by at most one tick and never follows a reused pid. 2 on a bad argument.

guard_ram() {
  local sid="${1:-}" min="${2:-}" outcome="${3:-}" log="${4:-}" ticks reads=0 misses=0 mb tick
  local R9700_T_STOP="" # a guard's work is cleanup-phase work: no stop time (decision 8)
  if ! [[ $sid =~ ^[0-9]+$ ]]; then echo "guard_ram: \"$sid\" is not a session id" >&2; return 2; fi
  if ! [[ $min =~ ^[0-9]+$ ]]; then echo "guard_ram: the limit \"$min\" is not a number of MB" >&2; return 2; fi
  if [ -z "$outcome" ] || [ -z "$log" ] || [ -z "${RUN_DIR:-}" ]; then echo "guard_ram: needs an outcome file, a log and RUN_DIR" >&2; return 2; fi
  tick="$(t_scale 15)" || return 2
  ticks="$(proc_ticks "$sid")"
  [ -n "$ticks" ] || return 0
  while guard_alive "$sid" "$ticks"; do
    if mb="$(win_ram_mb 2> /dev/null)" && [[ $mb =~ ^[0-9]+$ ]]; then
      misses=0
      if [ "$mb" -lt "$min" ]; then
        guard_fire "$sid" "$outcome" "$log" ram_guard "available $mb MB < $min MB"
        return 1
      fi
      if [ $((reads % 20)) -eq 0 ]; then guard_log "$log" "available RAM $mb MB"; fi
    else
      misses=$((misses + 1))
      guard_log "$log" "telemetry unreadable ($misses of 3)"
      if [ "$misses" -ge 3 ]; then
        guard_fire "$sid" "$outcome" "$log" ram_guard "telemetry unreadable 3 times"
        return 1
      fi
    fi
    reads=$((reads + 1))
    _rg_fork_sleep "$tick"
  done
  return 0
}
