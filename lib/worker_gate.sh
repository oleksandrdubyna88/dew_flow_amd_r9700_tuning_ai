#!/usr/bin/env bash
# lib/worker_gate.sh <gate file> <command...> — the worker's first step (amendment A2, decision 3). RUN, not sourced, as
# `setsid lib/worker_gate.sh <gate file> <command...> 9>&-` by the supervisor. It waits, bounded (30 s through t_ceiling: a wait with a ceiling), until <gate
# file> exists, then `exec`s the command, which is then the same process. The supervisor creates the gate file only AFTER the recovery
# marker names this worker (its process group, its start ticks), so a worker never touches the GPU or a container before a restore could
# find it. When the gate file never appears (the supervisor was killed in that window) the worker exits 5 by itself and runs nothing (4 is the series worker's "nothing more fits before the deadline").
#   exit 2  bad arguments or an invalid scale      exit 5  the gate file did not appear in time (a failed try for the supervisor)
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/run_guarded.sh
source "$here/run_guarded.sh"
gate="${1:-}"
if [ -z "$gate" ] || [ "$#" -lt 2 ]; then
  echo "worker_gate: usage: worker_gate.sh <gate file> <command...>" >&2
  exit 2
fi
shift
limit="$(t_ceiling 30)" || exit 2
steps="$(awk -v s="$limit" 'BEGIN { n = int(s / 0.05); print (n < 1 ? 1 : n) }')"
for ((i = 0; i < steps; i++)); do
  [ -f "$gate" ] && exec "$@"
  sleep 0.05
done
[ -f "$gate" ] && exec "$@"
echo "worker_gate: the gate file $gate did not appear within ${limit} s; the worker gives up and runs nothing" >&2
exit 5
