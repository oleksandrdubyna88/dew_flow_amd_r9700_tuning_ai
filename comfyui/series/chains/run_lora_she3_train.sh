#!/usr/bin/env bash
# Realistic LoRA v3 "slvrareal3" from the owner's Gemini pictures (2026-11-12 ~01:00: "finish what you started, then make a
# new LoRA from these pictures"; dataset lora/slvrareal3 by she3_dataset.py: 26 Gemini + 11 chat pictures (01:15) = 37 + captions). Waits for the last
# GPU job (real2_orbit2.log ORBIT DONE/FAILED), then: VM 40 GB, lora_train.sh 12 epochs (~37 x 4 x 12 ~ 1780 steps,
# ~2 h 25 min), VM 20 GB, copy to /models/loras. Logs to lora_she3_train.log ("LSHE3 DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN WSLC_SETTINGS_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/lora_she3_train.log"; R="$COMFY_HOME_WIN"; SET="$WSLC_SETTINGS"
O="$COMFY_HOME"/output/lora
vm_memory() {
  sed -i "s/^  memorySize: .*/  memorySize: $1/" "$SET"
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  timeout 300 pwsh.exe -NoProfile -Command "wslc system session terminate" > /dev/null 2>&1 || echo "session terminate TIMED OUT $(date +%H:%M)" >> "$LOG"; sleep 5
  echo "VM memory set to $1 (session restarted) $(date +%H:%M)" >> "$LOG"
}
echo "waiting for the realistic orbit v2 $(date +%H:%M)" >> "$LOG"
until grep -qE "ORBIT (DONE|FAILED)|guard stopped|restart: not ready" "$DIR/real2_orbit2.log" 2>/dev/null; do sleep 30; done
sleep 20
n=$(ls "$O/slvrareal3"/*.png 2>/dev/null | wc -l); t=$(ls "$O/slvrareal3"/*.txt 2>/dev/null | wc -l)
[ "$n" -ge 20 ] && [ "$n" = "$t" ] || { echo "LSHE3 FAILED $(date +%H:%M): dataset has $n pictures, $t captions" >> "$LOG"; exit 1; }
echo "she3 training start $(date +%H:%M) ($n pictures)" >> "$LOG"
grep -q "^  memorySize: 40GB" "$SET" || vm_memory 40GB
pwsh.exe -NoProfile -Command "wslc run --rm --name lora-train-she3 --gpus all -e LORA_NAME=slvrareal3 -e LORA_EPOCHS=12 -v lora-env:/lora -v comfy-models:/models:ro -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint bash comfyui-r9700:local /opt/tests/lora_train.sh all" > "$DIR/lora_she3_console.log" 2>&1
echo "training exit $? $(date +%H:%M); last lines:" >> "$LOG"; tr -d '\r' < "$DIR/lora_she3_console.log" | grep -vE "^\s*$" | tail -3 >> "$LOG"
vm_memory 20GB
pwsh.exe -NoProfile -Command "wslc run --rm --name lora-copy3 -v comfy-models:/models -v '$R\output:/data/output' --entrypoint sh comfyui-r9700:local -c 'cp /data/output/lora/out/slvrareal3.safetensors /models/loras/ && ls -la /models/loras/slvrareal3*'" 2>&1 | tr -d '\r' >> "$LOG"
grep -q "/models/loras/slvrareal3.safetensors" "$LOG" && echo "LSHE3 DONE $(date +%H:%M)" >> "$LOG" || echo "LSHE3 FAILED $(date +%H:%M)" >> "$LOG"
