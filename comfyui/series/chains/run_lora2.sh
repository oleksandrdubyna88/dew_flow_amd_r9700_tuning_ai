#!/usr/bin/env bash
# The owner (2026-11-09): "yes, do" the LoRA strength test (0.5 / 0.7), and train a SECOND LoRA separately (keep v1) that
# may keep softer facial features. After the realistic episode ("all done" in after_lora.log):
#  1. lora_test.py slvra_v1 at 0.5, 0.7 and 0.7 + soft words  -> series/lora_test/
#  2. 24 soft candidates (LoRA v1 at 0.6 + soft words)        -> series/lora_v2_cand/, "V2 CANDIDATES READY"
#  3. waits for MY dataset lora/slvra_v2/READY, VM 40 GB, train slvra_v2 (8 epochs), VM 20 GB, copy, test -> "V2 DONE".
# Logs to lora2_run.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN WSLC_SETTINGS_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/lora2_run.log"; R="$COMFY_HOME_WIN"; SET="$WSLC_SETTINGS"
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do
    pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0
    sleep 5
  done
  echo "restart: not ready after 300 s" >> "$LOG"; return 1
}
vm_memory() {
  sed -i "s/^  memorySize: .*/  memorySize: $1/" "$SET"
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -Command "wslc system session terminate" > /dev/null 2>&1; sleep 5
  echo "VM memory set to $1 (session restarted) $(date +%H:%M)" >> "$LOG"
}
lt() { pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/lora_test.py $*" 2>&1 | tr -d '\r' | grep -E "slvra|base|soft|rror" >> "$LOG"; }
until grep -q "^all done" "$DIR/after_lora.log" 2>/dev/null; do sleep 60; done
echo "start $(date +%H:%M)" >> "$LOG"
restart
lt slvra_v1.safetensors 0.5; lt slvra_v1.safetensors 0.7; lt slvra_v1.safetensors 0.7 --soft
lt softset slvra_v1.safetensors 0.6
echo "V2 CANDIDATES READY $(date +%H:%M)" >> "$LOG"
until [ -f "$COMFY_HOME"/output/lora/slvra_v2/READY ]; do sleep 60; done
vm_memory 40GB
pwsh.exe -NoProfile -Command "wslc run --rm --name lora-train --gpus all -e LORA_NAME=slvra_v2 -e LORA_EPOCHS=8 -v lora-env:/lora -v comfy-models:/models:ro -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint bash comfyui-r9700:local /opt/tests/lora_train.sh all" > "$DIR/lora2_train_console.log" 2>&1
echo "training exit $? $(date +%H:%M)" >> "$LOG"; tr -d '\r' < "$DIR/lora2_train_console.log" | grep -E "model saved|Error|Traceback" | tail -3 >> "$LOG"
vm_memory 20GB
pwsh.exe -NoProfile -Command "wslc run --rm --name lora-copy -v comfy-models:/models -v '$R\output:/data/output:ro' --entrypoint cp comfyui-r9700:local /data/output/lora/out/slvra_v2.safetensors /models/loras/slvra_v2.safetensors" 2>&1 | tr -d '\r' >> "$LOG"
restart
lt slvra_v2.safetensors 1.0; lt slvra_v2.safetensors 0.7
echo "V2 DONE $(date +%H:%M)" >> "$LOG"
