#!/usr/bin/env bash
# One sword everywhere (2026-11-10, the owner: the s09 sword style): inpaint_sword.py on ep3 picks 7 8 11 17.
# Waits for nothing (one GPU job at a time). Edit model only; RAM guard; logs to sword.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/sword.log"
"$DIR/guard_ram.sh" 6000 & GUARD=$!
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break; sleep 5; done
echo "start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/inpaint_sword.py run 7 8 11 17'" 2>&1 | tr -d '\r' | grep -E "ep3 sword|out of memory|Error|rror" | head -40 >> "$LOG"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
touch "$DIR/.guard_off"; wait $GUARD 2>/dev/null
echo "SWORD DONE $(date +%H:%M)" >> "$LOG"
