#!/usr/bin/env bash
# The stub worker of the lifecycle and guard tests (E1.S2 decision 12): worker.sh <mode>. Every mode records its call in
# worker.calls, writes <run dir>/steps/<n>.ready when R9700_RUN_DIR and R9700_STEP_N are set (so a test that triggers a fault waits
# for the worker, never for a fixed time), records its own pid for the killer, and writes `heartbeat` every 0.1 s while it waits.
#   ok             waits R9700_STUB_OK_HOLD s (default 0.3: a guard gets reads), writes worker.done, exit 0
#   child          starts `sleep 1000` in its group (child.pid), then waits 1000 s
#   exit3-then-ok  exit 3 on the first call, then as ok
#   exit3 | exit4 | fail     exit 3, 4 and 1
# The mode `serve` (serve_start and wait_ready through the real lib/ functions) comes with the part that builds wait_ready.
set -u
# shellcheck source=tests/stubs/stub_common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/stub_common.sh"
LEGAL="ok child exit3-then-ok exit3 exit4 fail"
mode="${1:-}"
case " $LEGAL " in
  *" $mode "*) [ -n "$mode" ] || { echo "worker.sh: no mode; legal: $LEGAL" >&2; exit 2; } ;;
  *) echo "worker.sh: unknown mode \"$mode\"; legal: $LEGAL" >&2; exit 2 ;;
esac

# hold <seconds>: waits, touching the heartbeat every 0.1 s
hold() {
  local i ticks
  ticks="$(awk -v s="$1" 'BEGIN { printf "%d", s * 10 }')"
  for ((i = 0; i < ticks; i++)); do
    : > "$R9700_STUB_DIR/heartbeat"
    sleep 0.1
  done
}

done_ok() {
  hold "${R9700_STUB_OK_HOLD:-0.3}"
  : > "$R9700_STUB_DIR/worker.done"
  exit 0
}

printf '%s\n' "$mode" >> "$R9700_STUB_DIR/worker.calls"
calls="$(wc -l < "$R9700_STUB_DIR/worker.calls")"
stub_record_pid "$R9700_STUB_DIR/workers/containers/worker-$$.pid" "$$"

if [ "$mode" = child ]; then
  sleep 1000 < /dev/null > /dev/null 2>&1 &
  child=$!
  stub_record_pid "$R9700_STUB_DIR/workers/containers/child-$child.pid" "$child"
  printf '%s\n' "$child" > "$R9700_STUB_DIR/child.pid"
fi
if [ -n "${R9700_RUN_DIR:-}" ] && [ -n "${R9700_STEP_N:-}" ]; then
  stub_mkdir "$R9700_RUN_DIR/steps"
  : > "$R9700_RUN_DIR/steps/$R9700_STEP_N.ready"
fi

case $mode in
  ok) done_ok ;;
  child) hold 1000 ;;
  exit3-then-ok) [ "${calls// /}" -eq 1 ] && exit 3; done_ok ;;
  exit3) exit 3 ;;
  exit4) exit 4 ;;
  fail) exit 1 ;;
esac
