#!/usr/bin/env bash
# After the realistic LoRAs v2 (the owner 2026-11-11 18:45: "ok, we wait"): waits for "LREAL2 DONE" in
# lora_real2_train.log (stops on LREAL2 FAILED), then one GPU job at a time:
#   1. run_ep1_s1_adult.sh — painted ep1 s1 face with the ep3 s19 adult reference ("S1ADULT DONE")
#   2. real2_check.py test + sheet — both new LoRAs x 0.6/0.8/1.0, 3 scenes -> series/real2check/test_sheet.jpg
#   3. real2_check.py keys (tunic LoRA 0.8) — two full-body start pictures for the 360-degree video
# The orbit clips wait for my pick of the start picture. Own RAM guard for 2-3. Logs to after_real2.log ("AFTER DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/after_real2.log"; STOPF="$DIR/.guard_off_ar2"; R="$COMFY_HOME_WIN"
echo "waiting for LREAL2 DONE $(date +%H:%M)" >> "$LOG"
until grep -q "LREAL2 DONE" "$DIR/lora_real2_train.log" 2>/dev/null; do
  grep -q "LREAL2 FAILED" "$DIR/lora_real2_train.log" 2>/dev/null && { echo "training FAILED — chain not started $(date +%H:%M)" >> "$LOG"; exit 1; }
  sleep 60
done
sleep 30
echo "chain start $(date +%H:%M)" >> "$LOG"
"$DIR/run_ep1_s1_adult.sh"; tail -1 "$DIR/ep1_s1_face.log" >> "$LOG"
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
up=0
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && { up=1; break; }; sleep 5; done
[ "$up" = 1 ] || { echo "AFTER FAILED $(date +%H:%M): comfyui did not answer" >> "$LOG"; exit 1; }
pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/real2_check.py test && REAL2_S=0.8 python /opt/tests/real2_check.py keys'" 2>&1 | tr -d '\r' | grep -E "real2check|rror|Trace|failed" >> "$LOG"
sleep 15
[ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; exit 0; }
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name r2sheet -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/real2_check.py sheet" 2>&1 | tr -d '\r' | grep -E "sheet|rror|Trace" >> "$LOG"
n=$(ls "$COMFY_HOME"/output/series/real2check/test/*.png 2>/dev/null | wc -l)
k=$(ls "$COMFY_HOME"/output/series/real2check/orbit_key_c*.png 2>/dev/null | wc -l)
if [ "$n" = 18 ] && [ "$k" = 2 ]; then echo "AFTER DONE $(date +%H:%M)" >> "$LOG"; else echo "AFTER INCOMPLETE $(date +%H:%M) (test $n/18, keys $k/2)" >> "$LOG"; fi
