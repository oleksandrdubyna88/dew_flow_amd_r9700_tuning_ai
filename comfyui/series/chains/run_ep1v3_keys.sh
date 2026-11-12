#!/usr/bin/env bash
# Episode 1 v3 keyframes (the reviewer's critique), after the ep3 keyframes (KEYS2 DONE), ONE shot per fresh server.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep1v3.log"
until grep -q "KEYS2 DONE" "$DIR/ep3_keys.log" 2>/dev/null; do sleep 30; done
for k in 1 2 3 4 5 6; do
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break; sleep 5; done
  pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep1_v3.py keys $k" 2>&1 | tr -d '\r' | grep -E "ep1 v3|out of memory|Trace|Error" | head -4 >> "$LOG"
done
echo "EP1V3 KEYS DONE $(date +%H:%M)" >> "$LOG"
