#!/usr/bin/env bash
# After the v4 keyframes (next.log "keys ready"): the realistic episode 2 keyframe candidates on the same server (the
# edit model is loaded). Then STOP: candidates are picked by eye. Logs to next.log.
set -u
DIR="$(dirname "$0")"; LOG="$DIR/next.log"
until grep -q "keys ready" "$LOG" 2>/dev/null; do sleep 30; done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_real.py keyframes" 2>&1 | tr -d '\r' | grep -E "^real|rror" >> "$LOG"
echo "real keys ready $(date +%H:%M)" >> "$LOG"
