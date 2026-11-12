#!/usr/bin/env bash
# s21 keyframe: flames on the rug edges -> fur (2026-11-10 20:45).
# Waits for run_s17.sh to end (one GPU job at a time). Edit model only; RAM guard; logs to s21fix.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/s21fix.log"
"$DIR/guard_ram.sh" 6000 & GUARD=$!
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break; sleep 5; done
echo "start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/inpaint_ears.py run 21'" 2>&1 | tr -d '\r' | grep -E "ep3 ears|out of memory|Error|rror" | head -40 >> "$LOG"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
touch "$DIR/.guard_off"; wait $GUARD 2>/dev/null
echo "S21FIX DONE $(date +%H:%M)" >> "$LOG"
