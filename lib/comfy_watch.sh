#!/usr/bin/env bash
# lib/comfy_watch.sh — two watchers of the operator's ComfyUI container for long hand-run job queues (keyframes, clips), next to `bin/r9700 comfy`. SOURCED by
# bin/r9700 after lib/comfy.sh; defines functions and runs nothing. Bash >= 4.4, `set -u` safe, no `set -e`. Needs lib/config.sh (config_load_machine),
# lib/run_guarded.sh (t_scale, _rg_listing_tries), lib/adapter.sh (win_ram_mb, wslc_stop, wslc_logs) and lib/comfy.sh (_comfy_say, _comfy_err).
# Messages start `comfy: <mode>:` on stdout and `r9700: comfy: <mode>:` on stderr. Neither mode takes the lock: both run BESIDE a job, never instead of one.
#
#   comfy_mode_guard [--min-mb <n>] [--until <file>] [--max-s <s>]
#       every 5 s one read of Windows' available MBytes; below <n> (default 6000) it stops the ComfyUI container (the job dies, the PC survives) and waits
#       60 s before the next read. A read that is not an integer is a miss; THREE misses in a row are unsafe and stop the container too: nothing counts an
#       unreadable value as fine. It ends when <file> exists or after <s> seconds (default 86400): a queue script touches the file when it is done. A stop
#       that failed (or a container list that could not be read) is one stderr line; the guard keeps watching and tries again at the next unsafe read, and
#       its end is then exit 1 with a line saying so, so a stop that never took is not reported as a guarded run. The first read and every 20th are
#       printed. It never STARTS ComfyUI: a restart would bring back the pressure that fired it, and the job queue starts its own ComfyUI per job. Found
#       2026-11-10: two big image models switched inside one server under a 20 GB VM filled the host's write cache within minutes and took WSL down
#       (research/SCREENING_comfyui_2026-11-08.md §29).
#   comfy_mode_timeline [--out <file>] [--until <text>] [--max-s <s>]
#       every 20 s the container's log; each NEW line is written with the UTC time it was first seen (`HH:MM:SSZ <line>`, ANSI colour removed), to <file>
#       (appended) or stdout. It ends (0) at the first new line that contains <text> (a plain substring, default "Prompt executed"), and with 1 after <s>
#       seconds (default 7200) or after three failed log reads in a row. A log that got SHORTER is a restarted container: it says so and starts over.
#       Why: a clip's phases (model loads, the two samplers, the decode) carry no time stamps in the log, and the time a line appears is the measurement.
#       Residual: a container restarted between two reads whose new log is already as long as the old one is not seen as a restart (its first lines are
#       taken as old); a log the engine rotated or cut would look like a restart. The line counts are all `wslc logs` gives (no offset, no container id).
#
# Exit codes: 0 done; 1 (guard) a stop failed during the run, (timeline) the ceiling or the log reads; 2 a bad argument or machine config.
#
# Growth: guard none (stdout only); timeline appends to <file>, which the operator owns.

_COMFY_GUARD_TICK_S=5
_COMFY_GUARD_COOL_S=60
_COMFY_GUARD_MISSES=3
_COMFY_GUARD_PRINT_EVERY=20
_COMFY_TIMELINE_TICK_S=20
_COMFY_TIMELINE_FAILS=3

# _comfy_watch_number <mode> <flag> <value>: 0 when <value> is a positive integer; 2 with one line naming the flag otherwise
_comfy_watch_number() {
  [[ ${3:-} =~ ^[1-9][0-9]{0,8}$ ]] && return 0
  _comfy_err "$1" "$2 takes a positive whole number; got \"${3:-}\""
  return 2
}

# _comfy_guard_stop <reason>: stops the operator's ComfyUI when it is listed; one line either way
_comfy_guard_stop() {
  local name="$R9700_COMFY_CONTAINER" out rc
  if ! _rg_listing_tries; then
    _comfy_err guard "$(date -u +%TZ) $1; the container list failed 3 times ($_RG_LIST_ERR): $name was not stopped"
    return 1
  fi
  if ! grep -Fxq -- "$name" <<< "$_RG_LISTING"; then
    _comfy_say guard "$(date -u +%TZ) $1; $name is not running"
    return 0
  fi
  out="$(wslc_stop "$name" 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    _comfy_say guard "$(date -u +%TZ) GUARD STOP: $1 — $name stopped"
    return 0
  fi
  _comfy_err guard "$(date -u +%TZ) $1; the stop of $name failed (code $rc): ${out##*$'\n'}"
  return 1
}

# _comfy_guard_off <reason> <failed>: the last line of a guard: 0, or 1 with a stderr line when a stop failed during the run
_comfy_guard_off() {
  _comfy_say guard "off: $1"
  [ "$2" -eq 0 ] && return 0
  _comfy_err guard "a stop of $R9700_COMFY_CONTAINER failed during this run (the lines above): the guard did not hold"
  return 1
}

comfy_mode_guard() {
  local min=6000 until="" max=86400 mb misses=0 reads=0 failed=0 start tick cool
  while [ "$#" -gt 0 ]; do
    case $1 in
      --min-mb) _comfy_watch_number guard --min-mb "${2:-}" || return 2; min=$2; shift 2 ;;
      --max-s) _comfy_watch_number guard --max-s "${2:-}" || return 2; max=$2; shift 2 ;;
      --until)
        if [ -z "${2:-}" ]; then _comfy_err guard "--until takes a file name"; return 2; fi
        until=$2
        shift 2
        ;;
      *) _comfy_err guard "unexpected argument \"$1\"; legal: --min-mb <n> --until <file> --max-s <s>"; return 2 ;;
    esac
  done
  config_load_machine "${R9700_MACHINE_ENV:-./machine.env}" || return 2
  tick="$(t_scale "$_COMFY_GUARD_TICK_S")" || return 2
  cool="$(t_scale "$_COMFY_GUARD_COOL_S")" || return 2
  start=$SECONDS
  _comfy_say guard "on: $R9700_COMFY_CONTAINER is stopped below $min MB available; off when ${until:-the ceiling} (at most $max s)"
  while :; do
    if [ -n "$until" ] && [ -e "$until" ]; then _comfy_guard_off "$until exists" "$failed"; return; fi
    if [ $((SECONDS - start)) -ge "$max" ]; then _comfy_guard_off "the ceiling of $max s" "$failed"; return; fi
    if mb="$(win_ram_mb 2> /dev/null)" && [[ $mb =~ ^[0-9]+$ ]]; then
      misses=0
      if [ $((reads % _COMFY_GUARD_PRINT_EVERY)) -eq 0 ]; then _comfy_say guard "$(date -u +%TZ) available $mb MB"; fi
      reads=$((reads + 1))
      if [ "$mb" -lt "$min" ]; then
        _comfy_guard_stop "available $mb MB < $min MB" || failed=1
        sleep "$cool"
      fi
    else
      misses=$((misses + 1))
      _comfy_say guard "$(date -u +%TZ) telemetry unreadable ($misses of $_COMFY_GUARD_MISSES)"
      if [ "$misses" -ge "$_COMFY_GUARD_MISSES" ]; then
        _comfy_guard_stop "telemetry unreadable $_COMFY_GUARD_MISSES times" || failed=1
        misses=0
        sleep "$cool"
      fi
    fi
    sleep "$tick"
  done
}

# _comfy_timeline_emit <out> <line>: one line with the UTC time it was seen, to <out> (appended) or stdout when <out> is empty
_comfy_timeline_emit() {
  if [ -n "$1" ]; then
    printf '%s %s\n' "$(date -u +%TZ)" "$2" >> "$1"
  else
    printf '%s %s\n' "$(date -u +%TZ)" "$2"
  fi
}

comfy_mode_timeline() {
  local out="" until="Prompt executed" max=7200 start tick text rc fails=0 seen=0 i
  local -a lines=()
  while [ "$#" -gt 0 ]; do
    case $1 in
      --max-s) _comfy_watch_number timeline --max-s "${2:-}" || return 2; max=$2; shift 2 ;;
      --out | --until)
        if [ -z "${2:-}" ]; then _comfy_err timeline "$1 takes a value"; return 2; fi
        if [ "$1" = --out ]; then out=$2; else until=$2; fi
        shift 2
        ;;
      *) _comfy_err timeline "unexpected argument \"$1\"; legal: --out <file> --until <text> --max-s <s>"; return 2 ;;
    esac
  done
  config_load_machine "${R9700_MACHINE_ENV:-./machine.env}" || return 2
  tick="$(t_scale "$_COMFY_TIMELINE_TICK_S")" || return 2
  start=$SECONDS
  _comfy_say timeline "on: the log of $R9700_COMFY_CONTAINER until a line contains \"$until\" (at most $max s)${out:+, to $out}"
  while [ $((SECONDS - start)) -lt "$max" ]; do
    text="$(wslc_logs "$R9700_COMFY_CONTAINER" 2>&1)"
    rc=$?
    if [ "$rc" -ne 0 ]; then
      fails=$((fails + 1))
      if [ "$fails" -ge "$_COMFY_TIMELINE_FAILS" ]; then
        _comfy_err timeline "the log of $R9700_COMFY_CONTAINER could not be read $_COMFY_TIMELINE_FAILS times in a row (code $rc): ${text##*$'\n'}"
        return 1
      fi
    else
      fails=0
      mapfile -t lines < <(sed 's/\x1b\[[0-9;]*m//g' <<< "$text" | grep -v '^[[:space:]]*$')
      if [ "${#lines[@]}" -lt "$seen" ]; then
        _comfy_say timeline "the log got shorter: $R9700_COMFY_CONTAINER restarted; reading it from its start"
        seen=0
      fi
      for ((i = seen; i < ${#lines[@]}; i++)); do
        _comfy_timeline_emit "$out" "${lines[$i]}"
        if [[ ${lines[$i]} == *"$until"* ]]; then _comfy_say timeline "done: a line contains \"$until\""; return 0; fi
      done
      seen=${#lines[@]}
    fi
    sleep "$tick"
  done
  _comfy_err timeline "the ceiling of $max s: no line contained \"$until\""
  return 1
}
