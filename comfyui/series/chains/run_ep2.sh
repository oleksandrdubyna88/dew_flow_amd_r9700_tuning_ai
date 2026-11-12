#!/usr/bin/env bash
# Episode 2: each 14B clip on a FRESHLY restarted ComfyUI. The Arcane 14B run (2026-11-08) took
# ~1000 s for every clip right after a restart and ~1790 s for every second clip on the same server, and a restart costs
# ~30 s, so a restart before EVERY clip is the faster rule. Logs to ep2.log next to this script.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
LOG="$(dirname "$0")/ep2.log"
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
restart || exit 1
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/episode2.py keyframes" 2>&1 | tr -d '\r' | grep -E "^shot" >> "$LOG"
for k in 1 2 3 4 5 6 7 8; do
  for try in 1 2; do
    restart || exit 1
    out="$(pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/episode2.py shot $k" 2>&1 | tr -d '\r')"
    echo "$out" | grep -E "^shot|out of memory|Error" | head -3 >> "$LOG"
    echo "$out" | grep -qE "^shot $k: clip" && break
    echo "shot $k: try $try failed" >> "$LOG"
  done
done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/episode2.py join" 2>&1 | tr -d '\r' | tail -1 >> "$LOG"
echo "all done" >> "$LOG"
