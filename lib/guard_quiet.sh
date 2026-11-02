#!/usr/bin/env bash
# lib/guard_quiet.sh — the quiet-PC guard. SOURCED; defines functions and runs nothing. Bash >= 4.4, `set -u` safe, no `set -e`. Needs
# lib/run_guarded.sh (t_scale, rg_log) and a loaded config (R9700_QUIET_LOAD_MAX, R9700_QUIET_BUSY_PATTERN, R9700_QUIET_BUSY_IGNORE).
#
#   quiet_check          prints "coai-exp processes=<n> load=<l>"; 0 when quiet, 1 when not. A load that cannot be read, or a missing pgrep when
#                        a busy pattern is set, prints "load unreadable: not quiet" and returns 1: nothing counts an unreadable value as fine
#   quiet_wait <s>       the loop of the old wait_quiet.sh: R9700_QUIET_CHECKS quiet checks in a row (default 3), 300 s apart, for at most <s>
#                        production seconds; 0 quiet, 1 ceiling reached, 2 a bad argument. Each check is one supervisor line ending in
#                        quiet-checks=<k>/<n>
#
# Test knobs (the environment only, never machine.env): R9700_QUIET_CHECKS (the number of checks, 1..10; the lifecycle tests use 1) and
# R9700_LOADAVG_FILE (the file the load is read from; default /proc/loadavg).

quiet_check() {
  local file="${R9700_LOADAVG_FILE:-/proc/loadavg}" line="" load pattern="${R9700_QUIET_BUSY_PATTERN:-}" ignore="${R9700_QUIET_BUSY_IGNORE:-}"
  local n=0 pid cmd found prc
  if ! { IFS= read -r line < "$file"; } 2> /dev/null; then echo "load unreadable: not quiet"; return 1; fi
  load="${line%% *}"
  if ! [[ $load =~ ^[0-9]+(\.[0-9]+)?$ ]]; then echo "load unreadable: not quiet"; return 1; fi
  if [ -n "$pattern" ]; then
    if ! command -v pgrep > /dev/null 2>&1; then echo "load unreadable: not quiet"; return 1; fi
    found="$(pgrep -f -- "$pattern" 2> /dev/null 9>&-)"
    prc=$?
    if [ "$prc" -gt 1 ]; then echo "load unreadable: not quiet"; return 1; fi
    while read -r pid; do
      [ -n "$pid" ] && [ "$pid" != "$$" ] && [ "$pid" != "$BASHPID" ] || continue
      cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2> /dev/null 9>&-)" || continue
      [ -n "$cmd" ] || continue # the process ended after pgrep saw it
      if [ -n "$ignore" ] && [[ $cmd == *"$ignore"* ]]; then continue; fi
      n=$((n + 1))
    done <<< "$found"
  fi
  printf 'coai-exp processes=%s load=%s\n' "$n" "$load"
  [ "$n" -eq 0 ] && awk -v l="$load" -v m="${R9700_QUIET_LOAD_MAX:-4}" 'BEGIN { exit !(l < m) }' 9>&-
}

quiet_wait() {
  local ceiling="${1:-}" need="${R9700_QUIET_CHECKS:-3}" streak=0 limit tick start end now left out
  if ! [[ $ceiling =~ ^[0-9]+(\.[0-9]+)?$ ]]; then echo "quiet_wait: the ceiling \"$ceiling\" is not a number of seconds" >&2; return 2; fi
  if ! [[ $need =~ ^([1-9]|10)$ ]]; then echo "quiet_wait: R9700_QUIET_CHECKS \"$need\" is not a whole number from 1 to 10" >&2; return 2; fi
  limit="$(t_scale "$ceiling")" || return 2
  tick="$(t_scale 300)" || return 2
  start="$(date +%s.%N 9>&-)"
  end="$(awk -v a="$start" -v l="$limit" 'BEGIN { printf "%.3f", a + l }' 9>&-)"
  while :; do
    out="$(quiet_check)" && streak=$((streak + 1)) || streak=0
    rg_log "$out quiet-checks=$streak/$need"
    if [ "$streak" -ge "$need" ]; then rg_log QUIET; return 0; fi
    now="$(date +%s.%N 9>&-)"
    left="$(awk -v e="$end" -v n="$now" -v t="$tick" 'BEGIN { l = e - n; if (l <= 0) { print 0; exit } if (l > t) l = t; printf "%.3f", l }' 9>&-)"
    [ "$left" != 0 ] || return 1
    _rg_sleep "$left"
    now="$(date +%s.%N 9>&-)"
    awk -v e="$end" -v n="$now" 'BEGIN { exit !(n >= e) }' 9>&- && return 1
  done
}
