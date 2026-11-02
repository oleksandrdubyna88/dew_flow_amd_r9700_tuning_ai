#!/usr/bin/env bash
# The stub worker of the lifecycle and guard tests (E1.S2 decision 12): worker.sh <mode>. Every mode records its call in
# worker.calls, writes <run dir>/steps/<n>.ready when R9700_RUN_DIR and R9700_STEP_N are set (so a test that triggers a fault waits
# for the worker, never for a fixed time), records its own pid for the killer, and writes `heartbeat` every 0.1 s while it waits.
#   ok             waits R9700_STUB_OK_HOLD s (default 0.3: a guard gets reads), writes worker.done, exit 0
#   child          starts `sleep 1000` in its group (child.pid), then waits 1000 s
#   exit3-then-ok  exit 3 on the first call, then as ok
#   exit3 | exit4 | fail     exit 3, 4 and 1
# Every mode also writes worker.env: the five variables the supervisor hands a worker (R9700_RUN_DIR, R9700_STEP_N, R9700_STEP_LABEL,
# R9700_T_STOP, R9700_OUTCOME_FILE), one KEY=VALUE per line, so a test can see what the worker was given.
#   serve          the disk gate's check (a stop: KIND=disk_gate in R9700_OUTCOME_FILE, exit 1), then serve_start through the real lib/ functions
#                  (container <prefix><label>-<n>, log <run dir>/steps/<n>.server.log; exit 1 when it returns non-zero), then waits 1000 s
#   adapter-hang   waits for the file `mode` to appear in the stub directory, then makes an adapter call (wslc_list) into the stub, which
#                  hangs by that mode: a worker that sits inside a hung adapter call (amendment A8)
#   container-bound  writes the prefixed containers it finds to running.<n>, starts the containers <prefix>a-<n> and <prefix>b-<n>, and exits
#                  as soon as the first one is no longer running (a worker that follows its server)
set -u
# shellcheck source=tests/stubs/stub_common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/stub_common.sh"
LEGAL="ok child exit3-then-ok exit3 exit4 fail serve adapter-hang container-bound"
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

printf 'RUN_DIR=%s\nSTEP_N=%s\nSTEP_LABEL=%s\nT_STOP=%s\nOUTCOME_FILE=%s\n' "${R9700_RUN_DIR-}" "${R9700_STEP_N-}" "${R9700_STEP_LABEL-}" "${R9700_T_STOP-}" "${R9700_OUTCOME_FILE-}" > "$R9700_STUB_DIR/worker.env"
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

# worker_libs: the real lib/ functions the modes serve and adapter-hang use; the configuration is in the environment (config_load exported it)
worker_libs() {
  local repo
  repo="$(dirname "$(dirname "$STUB_HERE")")"
  for lib in config run_guarded adapter disk_gate serve wait_ready; do
    # shellcheck source=/dev/null
    source "$repo/lib/$lib.sh" || exit 2
  done
}

case $mode in
  ok) done_ok ;;
  child) hold 1000 ;;
  exit3-then-ok) [ "${calls// /}" -eq 1 ] && exit 3; done_ok ;;
  exit3) exit 3 ;;
  exit4) exit 4 ;;
  fail) exit 1 ;;
  serve)
    worker_libs
    line="$(disk_gate_check "${R9700_RUN_DIR:?}/disk_gate.state")" || {
      outcome_write "${R9700_OUTCOME_FILE:?}" KIND=disk_gate RC=1 "DETAIL=$line"
      exit 1
    }
    serve_start "${R9700_CONTAINER_PREFIX}${R9700_STEP_LABEL}-${R9700_STEP_N}" "$R9700_RUN_DIR/steps/$R9700_STEP_N.server.log" -- || exit 1
    hold "${R9700_STUB_SERVE_HOLD:-1000}"
    exit 0
    ;;
  container-bound)
    worker_libs
    wslc_list > "$R9700_STUB_DIR/running.$R9700_STEP_N"
    wslc_run "${R9700_CONTAINER_PREFIX}a-$R9700_STEP_N" img > /dev/null
    wslc_run "${R9700_CONTAINER_PREFIX}b-$R9700_STEP_N" img > /dev/null
    while stub_alive "$R9700_STUB_DIR/containers/${R9700_CONTAINER_PREFIX}a-$R9700_STEP_N.pid"; do sleep 0.05; done
    exit 1
    ;;
  adapter-hang)
    worker_libs
    while [ ! -f "$R9700_STUB_DIR/mode" ]; do sleep 0.05; done
    wslc_list > /dev/null
    hold 1000
    ;;
esac
