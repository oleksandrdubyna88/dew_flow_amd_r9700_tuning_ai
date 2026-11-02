#!/usr/bin/env bash
# lib/wait_ready.sh — waits until a test server answers, from the worker's side (the old wait_ready.sh). SOURCED; defines functions and runs
# nothing. Bash >= 4.4, `set -u` safe, no `set -e`. Needs lib/adapter.sh and a loaded config (R9700_READY_TIMEOUT_S).
#
#   wait_ready <container> <log>      0 ready, 1 not ready (exited, or the window ended), 2 a bad argument
#   wait_ready_probe_program          prints the readiness program (the tests run it against a fake urlopen)
#
# Every 10 s (t_scale) up to R9700_READY_TIMEOUT_S: one `wslc_list` (a container that is not listed three times in a row has EXITED: reported
# at once) and the first check of the restore's probe, GET /v1/models answering 200 within 5 s, through `wslc_exec` inside the container. The
# window ends at the sooner of its own end and R9700_T_STOP (amendment A9: every list and probe is cut by it, and a call refused after it
# counts as "not ready"). The log of the container is ALWAYS saved through `wslc_logs` into <log> before the verdict line: `READY (waited <n> s
# here)` (stdout only, so the saved log is exactly the container's), `SERVER EXITED`, or `SERVER NOT READY after <n> s (<reason>)` (stdout and
# the end of the saved log). No heartbeat file: the supervisor is the heartbeat.

_WAIT_READY_PY='import sys, urllib.request
try:
    with urllib.request.urlopen("http://127.0.0.1:8000/v1/models", timeout=5) as response:
        sys.exit(0 if response.status == 200 else 1)
except Exception:
    sys.exit(1)'

wait_ready_probe_program() { printf '%s\n' "$_WAIT_READY_PY"; }

wait_ready() {
  local name="${1:-}" log="${2:-}" limit interval start now elapsed n miss=0 out reason="" verdict="" stop_at
  _adapter_name_ok wait_ready "$name" || return 2
  if [ -z "$log" ]; then echo "wait_ready: usage: wait_ready <container> <log>" >&2; return 2; fi
  [[ ${R9700_READY_TIMEOUT_S:-} =~ ^[1-9][0-9]*$ ]] || { echo "wait_ready: R9700_READY_TIMEOUT_S \"${R9700_READY_TIMEOUT_S:-}\" is not a number of seconds" >&2; return 2; }
  limit="$(t_scale "$R9700_READY_TIMEOUT_S")" || return 2
  interval="$(t_scale 10)" || return 2
  start="$(date +%s.%N 9>&-)"
  # the window as an epoch second for the adapter, rounded up; the caller's own stop time stays when it is sooner
  stop_at="$(awk -v a="$start" -v l="$limit" -v c="${R9700_T_STOP:-}" 'BEGIN { t = a + l; n = int(t); if (t > n) n++; if (c != "" && c + 0 < n) n = c + 0; print n }' 9>&-)"
  local R9700_T_STOP="$stop_at"
  while :; do
    if out="$(wslc_list 2> /dev/null)" && grep -Fxq -- "$name" <<< "$out"; then miss=0; else miss=$((miss + 1)); fi
    if [ "$miss" -ge 3 ]; then verdict=exited; break; fi
    if wslc_exec 10 "$name" python3 -c "$_WAIT_READY_PY" > /dev/null 2>&1; then verdict=ready; break; fi
    now="$(date +%s.%N 9>&-)"
    elapsed="$(awk -v a="$start" -v b="$now" 'BEGIN { print b - a }' 9>&-)"
    if awk -v e="$elapsed" -v l="$limit" -v s="$stop_at" -v n="$now" 'BEGIN { exit !(e >= l || n >= s) }' 9>&-; then verdict=late; break; fi
    # the sleep never runs past the window or the stop time, and their end is the end of the wait (A13)
    if ! sleep_in_window "$(awk -v a="$start" -v l="$limit" -v s="$stop_at" 'BEGIN { e = a + l; if (s + 0 < e) e = s + 0; printf "%.3f\n", e }' 9>&-)" "$interval"; then verdict=late; break; fi
  done
  now="$(date +%s.%N 9>&-)"
  n="$(awk -v a="$start" -v b="$now" -v k="${R9700_TIME_SCALE:-1}" 'BEGIN { printf "%d", (b - a) * k + 0.5 }' 9>&-)"
  R9700_T_STOP="" # the window is over; saving the log is not cut by it (the call has its own ceiling)
  # whole or not at all: a reader that waits for the file (a test, the supervisor) never sees it half written
  { wslc_logs "$name" > "$log.part" 2> /dev/null || true; } && mv "$log.part" "$log"
  case $verdict in
    ready) echo "READY (waited $n s here)"; return 0 ;;
    exited) reason="SERVER EXITED" ;;
    *) reason="SERVER NOT READY after $n s (the window of ${R9700_READY_TIMEOUT_S} s or the stop time ended)" ;;
  esac
  echo "$reason"
  echo "$reason" >> "$log"
  return 1
}
