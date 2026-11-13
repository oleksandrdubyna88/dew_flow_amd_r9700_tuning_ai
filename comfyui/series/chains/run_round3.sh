#!/usr/bin/env bash
# v4 round-3 keyframes (shots 4, 5) with the cleaned references, after the realistic clips ("real done" in clips.log) and
# before the v4 clips (run_clips.sh waits for pick_s4/5/7.png). Logs to clips.log.
set -u
DIR="$(dirname "$0")"; LOG="$DIR/clips.log"
until grep -q "real done" "$LOG" 2>/dev/null; do sleep 30; done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_v4.py keyframes3" 2>&1 | tr -d '\r' | grep -E "^shot|rror" >> "$LOG"
echo "v4 round-3 keys ready $(date +%H:%M)" >> "$LOG"
