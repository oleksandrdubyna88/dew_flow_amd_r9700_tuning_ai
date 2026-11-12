#!/usr/bin/env bash
# Episode 3 look test B vs C after the rebuild (FINAL12 DONE). Logs to look.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/look.log"
until grep -q "FINAL12 DONE" "$DIR/final12.log" 2>/dev/null; do sleep 30; done
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break; sleep 5; done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep3_look.py" 2>&1 | tr -d '\r' | grep -E "look|rror|Trace" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc logs comfyui" 2>&1 | tr -d '\r' | grep -ciE "lora key not loaded" | sed 's/^/lora keys NOT loaded on the edit model (count): /' >> "$LOG"
echo "LOOK DONE $(date +%H:%M)" >> "$LOG"
