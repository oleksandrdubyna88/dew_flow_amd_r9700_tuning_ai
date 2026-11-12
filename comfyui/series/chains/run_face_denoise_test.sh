#!/usr/bin/env bash
# Step B check (2026-11-11 14:05): at denoise 0.75 the repainted faces move only a little toward the target. Waits for the
# full 0.75 run (FACE DONE after the 14:01 restart), then repaints 5 pictures at 0.9 and 1.0 (FACE_VAR _d90/_d100) and
# makes real2c_face/test_denoise.jpg (target | original | 0.75 | 0.9 | 1.0). Logs to face_repaint.log ("DTEST DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/face_repaint.log"; STOPF="$DIR/.guard_off_fdt"
R="$COMFY_HOME_WIN"
NAMES="tunic_portrait_l7_s6101 fur_portrait_l7_s6202 fur_hips_l7_s6101 fur_laugh_l7_s6101 fur_front_l7_s6202"
START=$(grep -n -- "--- restart after GUARD STOP 14:00" "$LOG" | cut -d: -f1)
until tail -n +"$START" "$LOG" | grep -qE "FACE (DONE|INCOMPLETE|FAILED)|guard stopped"; do sleep 20; done
sleep 5
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
up=0
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && { up=1; break; }; sleep 5; done
[ "$up" = 1 ] || { echo "DTEST FAILED $(date +%H:%M): comfyui did not answer" >> "$LOG"; exit 1; }
echo "denoise test start $(date +%H:%M)" >> "$LOG"
for v in "0.9 _d90" "1.0 _d100"; do
  set -- $v
  pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'FACE_DENOISE=$1 FACE_VAR=$2 python /opt/tests/face_repaint_real.py run $NAMES'" 2>&1 | tr -d '\r' | grep -E "realface|rror|Trace|failed" >> "$LOG"
  sleep 15
  [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; exit 0; }
done
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name fdtest -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/face_repaint_real.py test $NAMES" 2>&1 | tr -d '\r' | grep -E "test sheet|rror" >> "$LOG"
n=$(ls "$COMFY_HOME"/output/lora/real2c_face/full/*_d90.png "$COMFY_HOME"/output/lora/real2c_face/full/*_d100.png 2>/dev/null | wc -l)
if [ "$n" -ge 20 ]; then echo "DTEST DONE $(date +%H:%M) ($n files)" >> "$LOG"; else echo "DTEST INCOMPLETE $(date +%H:%M) ($n of 20)" >> "$LOG"; fi
