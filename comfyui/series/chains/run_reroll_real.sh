#!/usr/bin/env bash
# The realistic ep2: shot 2 opened her eyes while sleeping, shot 6's hair turned dark at the end (2026-11-10, by eye on
# ep2_real/real_1234.png, real_5678.png). A second seed for both (ep2_real.py reroll -> reroll_s<k>_*), after the ep1
# re-rolls ("REROLL DONE" in reroll.log). I compare and choose by eye. Logs to reroll.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/reroll.log"
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do
    pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0
    sleep 5
  done
  echo "restart: not ready after 300 s" >> "$LOG"; return 1
}
until grep -q "REROLL DONE" "$LOG" 2>/dev/null; do sleep 60; done
for k in 2 6; do
  restart || break
  pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_real.py reroll $k" 2>&1 | tr -d '\r' | grep -E "real shot|out of memory|Error" | head -3 >> "$LOG"
done
echo "REAL REROLL DONE $(date +%H:%M)" >> "$LOG"
