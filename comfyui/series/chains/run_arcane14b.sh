#!/usr/bin/env bash
# Render the Arcane 14B film shot by shot, restarting the hand-made ComfyUI before every second clip (the 14B pair runs
# out of memory after ~3 clips on one server). Logs to arcane14b.log next to this script.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
LOG="$(dirname "$0")/arcane14b.log"
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
  sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do
    pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0
    sleep 5
  done
  echo "restart: not ready after 300 s" >> "$LOG"; return 1
}
for k in 1 2 3 4 5 6; do
  if [ $((k % 2)) -eq 1 ]; then restart || exit 1; fi
  for try in 1 2; do
    out="$(pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/arcane14b.py shot $k" 2>&1 | tr -d '\r')"
    echo "$out" | grep -E "^shot|out of memory|Error" | head -3 >> "$LOG"
    echo "$out" | grep -qE "^shot $k: clip" && break
    echo "shot $k: try $try failed; restarting" >> "$LOG"; restart || exit 1
  done
done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/arcane14b.py join" 2>&1 | tr -d '\r' | tail -1 >> "$LOG"
echo "all done" >> "$LOG"
