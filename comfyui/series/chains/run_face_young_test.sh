#!/usr/bin/env bash
# Step B test 5 (2026-11-11 16:00, the owner: some faces look older, likes the younger ones): InstantID w1.2 cn0.5
# with FACE_YOUNG=1 (younger prompt), denoise 0.6 / 0.75 (_y60/_y75) on 7 pictures -> real2c_face/test_young.jpg
# (target | original | w12 | y60 | y75). Own RAM guard. Logs to face_repaint.log ("YTEST DONE" when all 28 files exist).
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/face_repaint.log"; STOPF="$DIR/.guard_off_fyt"
R="$COMFY_HOME_WIN"; F="$COMFY_HOME"/output/lora/real2c_face/full
NAMES="fur_runwall_l7_s6202 fur_drink_l7_s6202 fur_hips_l7_s6101 fur_portrait_l7_s6202 fur_rug_l7_s6101 tunic_portrait_l7_s6101 fur_climb_l7_s6101"
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
up=0
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && { up=1; break; }; sleep 5; done
[ "$up" = 1 ] || { echo "YTEST FAILED $(date +%H:%M): comfyui did not answer" >> "$LOG"; exit 1; }
echo "instantid young test start $(date +%H:%M)" >> "$LOG"
for v in "0.6 _y60" "0.75 _y75"; do
  set -- $v
  pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'FACE_YOUNG=1 FACE_METHOD=iid FACE_DENOISE=$1 FACE_CN=0.5 FACE_IPW=1.2 FACE_VAR=$2 python /opt/tests/face_repaint_real.py run $NAMES'" 2>&1 | tr -d '\r' | grep -E "realface|rror|Trace|failed|Exception" >> "$LOG"
  sleep 15
  [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; exit 0; }
done
pwsh.exe -NoProfile -Command "wslc logs comfyui 2>&1 | Select-String -Pattern 'InstantID|insightface|IMPORT FAILED|Cannot import'" 2>&1 | tr -d '\r' | head -5 >> "$LOG"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name fytest -e FACE_TEST_VARS=_w12,_y60,_y75 -e FACE_TEST_TAG=_young -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/face_repaint_real.py test $NAMES" 2>&1 | tr -d '\r' | grep -E "test sheet|rror|Trace" >> "$LOG"
miss=0; for n in $NAMES; do for v in _y60 _y75; do for r in 1 2; do [ -f "$F/${n}_r${r}${v}.png" ] || miss=$((miss + 1)); done; done; done
if [ "$miss" = 0 ]; then echo "YTEST DONE $(date +%H:%M)" >> "$LOG"; else echo "YTEST INCOMPLETE $(date +%H:%M) ($miss missing)" >> "$LOG"; fi
