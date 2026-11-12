#!/usr/bin/env bash
# RAM guard (2026-11-10, after the PC ran out of RAM twice during keyframe runs): every 5 s read Windows' available
# memory; when it is below LIMIT_MB in TWO readings in a row (~10 s), stop ComfyUI (the GPU job dies, the PC survives) and
# write GUARD STOP to guard.log. Two readings (2026-11-10 21:45): every container stop between clips makes Windows hold
# the VM's memory as "modified" pages for ~10 s (modified 9 -> 35 GB, available 23 -> 3.5 GB, back to 38 GB free 10 s
# later) — one low reading is that spike, not a crisis (the crises were sustained, < 150 MB).
# Runs until its stop file exists (default .guard_off next to it). Usage: guard_ram.sh [LIMIT_MB] [STOP_FILE]
# (A run that shares .guard_off can leave an older guard running — a new guard deletes the file at start.)
set -u
DIR="$(dirname "$0")"; LOG="$DIR/guard.log"; LIMIT="${1:-6000}"; STOPF="${2:-$DIR/.guard_off}"
rm -f "$STOPF"
echo "guard on $(date +%H:%M:%S), limit $LIMIT MB (2 readings in a row)" >> "$LOG"
low=0
while [ ! -f "$STOPF" ]; do
  a="$(pwsh.exe -NoProfile -Command '(Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory).AvailableMBytes' 2>/dev/null | tr -d '\r')"
  if [ -n "$a" ] && [ "$a" -lt "$LIMIT" ] 2>/dev/null; then
    low=$((low + 1))
    if [ "$low" -ge 2 ]; then
      pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
      echo "GUARD STOP $(date +%H:%M:%S): available $a MB < $LIMIT MB in 2 readings — comfyui stopped" >> "$LOG"
      low=0; sleep 60
    else
      echo "guard: one low reading $(date +%H:%M:%S): $a MB (waiting for a second)" >> "$LOG"
    fi
  else
    low=0
  fi
  sleep 5
done
echo "guard off $(date +%H:%M:%S)" >> "$LOG"
