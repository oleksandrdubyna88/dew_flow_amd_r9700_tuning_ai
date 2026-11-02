#!/usr/bin/env bash
# lib/disk_gate.sh — the disk gate: a new disk or stornvme event in the Windows System log since the baseline stops the run. SOURCED; defines
# functions and runs nothing. Bash >= 4.4, `set -u` safe, no `set -e`. Needs lib/adapter.sh (win_disk_newest) and a loaded config.
#
#   disk_gate_decide <baseline> <current>     prints the verdict line; 0 ok, 1 a new event, 2 the query failed or the log was reset
#   disk_gate_baseline <state file>           records the newest record id in <state file> (the run's own folder, never beside the script)
#   disk_gate_check <state file>              compares the newest record with the baseline; the return codes of disk_gate_decide
#
# Exit codes as the old disk_gate.sh: 0 ok, 1 new event, 2 the query failed or the log was reset. A baseline that is missing or not a
# number is "STOP: baseline missing (<file>)" with 2. With R9700_DISK_GATE=off both functions print `disk gate off` and return 0 without a call.

disk_gate_decide() {
  local base="$1" cur="$2"
  if ! [[ $cur =~ ^[0-9]+$ ]]; then echo "STOP: query failed"; return 2; fi
  if ((cur < base)); then echo "STOP: log reset (newest $cur < baseline $base)"; return 2; fi
  if ((cur > base)); then echo "STOP: new disk event (record $cur > baseline $base)"; return 1; fi
  echo "OK: no new disk event (newest $cur)"
  return 0
}

disk_gate_baseline() {
  local state="${1:-}" id
  if [ "${R9700_DISK_GATE:-on}" = off ]; then echo "disk gate off"; return 0; fi
  if ! id="$(win_disk_newest 2> /dev/null)" || ! [[ $id =~ ^[0-9]+$ ]]; then echo "STOP: query failed"; return 2; fi
  if ! printf '%s\n' "$id" > "$state.part" 2> /dev/null || ! mv "$state.part" "$state"; then
    rm -f "$state.part"
    echo "STOP: baseline cannot be written ($state)"
    return 2
  fi
  echo "baseline $id"
}

disk_gate_check() {
  local state="${1:-}" base="" cur
  if [ "${R9700_DISK_GATE:-on}" = off ]; then echo "disk gate off"; return 0; fi
  { IFS= read -r base < "$state"; } 2> /dev/null
  if ! [[ $base =~ ^[0-9]+$ ]]; then echo "STOP: baseline missing ($state)"; return 2; fi
  cur="$(win_disk_newest 2> /dev/null)" || cur=""
  disk_gate_decide "$base" "$cur"
}
