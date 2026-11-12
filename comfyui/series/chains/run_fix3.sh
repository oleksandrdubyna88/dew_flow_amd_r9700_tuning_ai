#!/usr/bin/env bash
# Open ep3 fixes (2026-11-10, the owner: "yes, fix"): s16 at sunrise (sets 6+7 = c11-c14, new text, positive-only
# costume words) in two phases; then masked repaints s05 (the small dragon) and s20 (flames on the rug). RAM guard.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/fix3.log"
"$DIR/guard_ram.sh" 6000 & GUARD=$!
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
job() { pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c '$1'" 2>&1 | tr -d '\r' | grep -E "ep3 key|ep3 pose|ep3 ears|out of memory|rror" | head -40 >> "$LOG"; }
for phase in text edit; do
  echo "phase $phase $(date +%H:%M)" >> "$LOG"
  restart || break
  job "EP3_PHASE=$phase EP3_SET=6 python /opt/tests/ep3_keys.py 16"
  job "EP3_PHASE=$phase EP3_SET=7 python /opt/tests/ep3_keys.py 16"
  [ "$phase" = edit ] && job "python /opt/tests/inpaint_ears.py run 5 20"
  grep -q "GUARD STOP" "$DIR/guard.log" 2>/dev/null && { echo "guard stopped comfyui — ending" >> "$LOG"; break; }
done
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
touch "$DIR/.guard_off"; wait $GUARD 2>/dev/null
echo "FIX3 DONE $(date +%H:%M)" >> "$LOG"
