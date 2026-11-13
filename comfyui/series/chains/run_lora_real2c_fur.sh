#!/usr/bin/env bash
# The realistic LoRAs v2 (2026-11-11, the owner: the chosen face slvra_v1 0.7, two LoRAs — tunic and fur): the dataset
# pictures from text (lora_dataset_real2.py gen tunic, gen fur) after the ep1 real fix run ends. Own guard. Logs to
# lora_real2.log ("GEN C FUR DONE" only when the pictures exist). Then: sheets -> DROP markers by eye -> collect -> train.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/lora_real2.log"; STOPF="$DIR/.guard_off_lr2"
G="$COMFY_HOME"/output/lora/real2c_gen
: # set b: nothing to wait for
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break; sleep 5; done
echo "real2 SET C fur gen start $(date +%H:%M)" >> "$LOG"
for o in fur; do
  pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/lora_dataset_real2.py gen $o'" 2>&1 | tr -d '\r' | grep -E "real2|rror|Trace" >> "$LOG"
  [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; exit 0; }
done
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
t=$(ls $G/tunic_*.png 2>/dev/null | wc -l); f=$(ls $G/fur_*.png 2>/dev/null | wc -l)
if [ "$t" -ge 28 ] && true; then echo "GEN C FUR DONE $(date +%H:%M) (tunic $t, fur $f)" >> "$LOG"; else echo "GEN C FUR INCOMPLETE $(date +%H:%M) (tunic $t, fur $f)" >> "$LOG"; fi
