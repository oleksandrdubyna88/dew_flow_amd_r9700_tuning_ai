#!/usr/bin/env bash
# The REALISTIC LoRA "slvrareal" (the owner, 2026-11-10 night: "render the LoRAs for realism"), after the episode 2 v6 run:
# the wslc VM to 40 GB for training (as for v1; a session restart between jobs is allowed by the owner), cache + train
# (lora_train.sh, LORA_NAME=slvrareal, 14 epochs = 32 pictures x 4 repeats x 14 = 1792 steps, v1 took 2048 steps in
# 2 h 36 min), the VM back to 20 GB, the LoRA copied into the models volume. Logs to lora_real.log ("LREAL DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN WSLC_SETTINGS_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/lora_real.log"; R="$COMFY_HOME_WIN"; SET="$WSLC_SETTINGS"
vm_memory() {  # $1 = e.g. 40GB; a new session reads it
  sed -i "s/^  memorySize: .*/  memorySize: $1/" "$SET"
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  timeout 300 pwsh.exe -NoProfile -Command "wslc system session terminate" > /dev/null 2>&1 || echo "session terminate TIMED OUT $(date +%H:%M)" >> "$LOG"; sleep 5
  echo "VM memory set to $1 (session restarted) $(date +%H:%M)" >> "$LOG"
}
until grep -q "EP2 V6 DONE" "$DIR/ep2_v6_clips.log" 2>/dev/null; do sleep 30; done
grep -q "^  memorySize: 40GB" "$SET" || vm_memory 40GB  # 2026-11-11: skipped when the session already has 40 GB (a fresh boot)
pwsh.exe -NoProfile -Command "wslc run --rm --name lora-train-real --gpus all -e LORA_NAME=slvrareal -e LORA_EPOCHS=14 -v lora-env:/lora -v comfy-models:/models:ro -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint bash comfyui-r9700:local /opt/tests/lora_train.sh all" > "$DIR/lora_real_train_console.log" 2>&1
echo "training exit $? $(date +%H:%M); last lines:" >> "$LOG"; tr -d '\r' < "$DIR/lora_real_train_console.log" | grep -vE "^\s*$" | tail -5 >> "$LOG"
vm_memory 20GB
pwsh.exe -NoProfile -Command "wslc run --rm --name lora-copy -v comfy-models:/models -v '$R\output:/data/output' --entrypoint sh comfyui-r9700:local -c 'cp /data/output/lora/out/slvrareal.safetensors /models/loras/slvrareal.safetensors && ls -la /models/loras/slvrareal*'" 2>&1 | tr -d '\r' >> "$LOG"
if [ -s "$COMFY_HOME"/output/lora/out/slvrareal.safetensors ] && grep -q "slvrareal.safetensors" "$LOG"; then echo "LREAL DONE $(date +%H:%M)" >> "$LOG"; else echo "LREAL FAILED $(date +%H:%M)" >> "$LOG"; fi
