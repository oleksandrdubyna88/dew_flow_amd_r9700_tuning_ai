#!/usr/bin/env bash
# Touch-ups of the approved ep3 picks (2026-11-10, the owner: ordinary ears as on s14/s15; the s11 nose shadow; + the
# pending s05 small-dragon removal). Edit model only (one big model per session); RAM guard; logs to touch.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/touch.log"
"$DIR/guard_ram.sh" 6000 & GUARD=$!
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break; sleep 5; done
echo "start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/touchup.py 11 19 18 17 16 9 7 8 10 5'" 2>&1 | tr -d '\r' | grep -E "ep3 touch|out of memory|Error" | head -40 >> "$LOG"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
touch "$DIR/.guard_off"; wait $GUARD 2>/dev/null
echo "TOUCH DONE $(date +%H:%M)" >> "$LOG"
