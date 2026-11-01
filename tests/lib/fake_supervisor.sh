#!/usr/bin/env bash
# A TEST DOUBLE of the supervisor's `step` (E1.S2 part (c)): it takes the lock, writes the recovery marker, stops the operator's server,
# starts the stub worker behind the worker gate, adds the worker keys to the marker, opens the gate and waits - using only the part (b)
# functions, so the ownership and recovery tests can kill it. Run as: fake_supervisor.sh <mode> <dir> <machine.env> <model.env>
#   run                 the whole sequence; <dir>/ready appears when the worker's child runs
#   kill-before-gate    the window of scenario L21: SIGKILL right after the worker start, before the second marker write and the gate
set -u
mode="$1" dir="$2" machine="$3" model="$4"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$(dirname "$HERE")")"
source "$REPO/lib/config.sh"
source "$REPO/lib/run_guarded.sh"
source "$REPO/lib/adapter.sh"
source "$REPO/lib/restore.sh"
config_load "$machine" "$model" || exit 2
lock_take step || exit 4
run_dir="$dir/run"
mkdir -p "$run_dir/steps" "$run_dir/guard"
marker="$(marker_path)"
marker_write_base "$marker" "fake-$$" yes "$run_dir" || exit 3
if wslc_list | grep -Fxq "$R9700_PROD_CONTAINER"; then wslc_stop "$R9700_PROD_CONTAINER"; fi
export R9700_RUN_DIR="$run_dir" R9700_STEP_N=1
worker_start "$run_dir/steps/1.gate" "$run_dir/steps/1.worker.log" "$REPO/tests/stubs/worker.sh" child || exit 3
if [ "$mode" = kill-before-gate ]; then
  : > "$dir/ready"
  kill -KILL $$
fi
marker_add_worker "$marker" "$WORKER_PID" "$WORKER_TICKS" || exit 3
cp "$marker" "$run_dir/steps/1.marker"
gate_open "$run_dir/steps/1.gate"
for _ in $(seq 1 100); do [ -f "$R9700_STUB_DIR/child.pid" ] && break; sleep 0.1; done
: > "$dir/ready"
wait "$WORKER_PID"
