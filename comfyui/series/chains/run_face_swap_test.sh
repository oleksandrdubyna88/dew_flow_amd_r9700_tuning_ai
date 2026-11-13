#!/usr/bin/env bash
# Step B test 2 (2026-11-11 14:30, the owner: "ok, do test 2"): a FULL Qwen-Edit of the head crop (FACE_METHOD=swap,
# FACE_VAR=_sw; the young_face.py method) on 7 pictures, then real2c_face/test_swap.jpg (target | original | mask 0.75 |
# swap). Own RAM guard. Logs to face_repaint.log ("STEST DONE" only when all 14 files exist).
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/face_repaint.log"; STOPF="$DIR/.guard_off_fst"
R="$COMFY_HOME_WIN"; F="$COMFY_HOME"/output/lora/real2c_face/full
NAMES="tunic_portrait_l7_s6101 fur_portrait_l7_s6202 fur_hips_l7_s6101 fur_laugh_l7_s6101 fur_front_l7_s6202 tunic_profile_l7_s6101 fur_drink_l7_s6202"
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
up=0
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && { up=1; break; }; sleep 5; done
[ "$up" = 1 ] || { echo "STEST FAILED $(date +%H:%M): comfyui did not answer" >> "$LOG"; exit 1; }
echo "swap test start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'FACE_METHOD=swap FACE_VAR=_sw python /opt/tests/face_repaint_real.py run $NAMES'" 2>&1 | tr -d '\r' | grep -E "realface|rror|Trace|failed" >> "$LOG"
sleep 15
[ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; exit 0; }
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name fstest -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/face_repaint_real.py test $NAMES" 2>&1 | tr -d '\r' | grep -E "test sheet|rror|Trace" >> "$LOG"
miss=0; for n in $NAMES; do for r in 1 2; do [ -f "$F/${n}_r${r}_sw.png" ] || miss=$((miss + 1)); done; done
if [ "$miss" = 0 ]; then echo "STEST DONE $(date +%H:%M)" >> "$LOG"; else echo "STEST INCOMPLETE $(date +%H:%M) ($miss missing)" >> "$LOG"; fi
