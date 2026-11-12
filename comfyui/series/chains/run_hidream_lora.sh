#!/usr/bin/env bash
# HiDream LoRA chain (the owner 2026-11-13 ~00:35 "train a LoRA on HiDream too"; ~00:50 "if something must be installed
# in WSL - allowed"). Waits for the realistic ep3 Flux 9B run ("^EP3REAL FLUX2K9 DONE", checked absent before start;
# one GPU job at a time). VM 40 GB (training rule) -> SMOKE 10 steps (deepspeed on ROCm/WSL never tested) -> only if it
# saved a LoRA: FULL 8 epochs -> VM 20 GB -> copy the last epoch to /models/loras/slvrareal_hidream.safetensors (+ each
# epoch as slvrareal6b_hidream_eN) -> test sheet (newmodel_check.py run hidream, 0.6/0.8/1.0 -> sheet_hidream.jpg).
# Log hidream_lora.log ("HIDREAM LORA DONE" / "HIDREAM SMOKE FAILED").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN WSLC_SETTINGS_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/hidream_lora.log"; R="$COMFY_HOME_WIN"
SET="$WSLC_SETTINGS"; O="$COMFY_HOME"/output
vm_memory() {
  sed -i "s/^  memorySize: .*/  memorySize: $1/" "$SET"
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  timeout 300 pwsh.exe -NoProfile -Command "wslc system session terminate" > /dev/null 2>&1 || echo "session terminate TIMED OUT $(date +%H:%M)" >> "$LOG"; sleep 5
  echo "VM memory set to $1 (session restarted) $(date +%H:%M)" >> "$LOG"
}
train() {  # $1 smoke|full
  pwsh.exe -NoProfile -Command "wslc run --rm --name dp-hidream-$1 --gpus all --shm-size 8G -e DP_SWAP=${DP_SWAP:-12} -v lora-env:/lora -v comfy-models:/models:ro -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint bash comfyui-r9700:local /opt/tests/lora_train_hidream.sh $1" > "$DIR/hidream_lora_$1_console.log" 2>&1
  tr -d '\r' < "$DIR/hidream_lora_$1_console.log" | grep -E "accel|train exit|rror|Traceback|out of memory|Block swap|steps:|epoch" | tail -12 >> "$LOG"
}
echo "hidream lora waiting $(date +%H:%M)" >> "$LOG"
until grep -q "^EP3REAL FLUX2K9 DONE" "$DIR/ep3_real.log"; do sleep 60; done
vm_memory 40GB
echo "smoke start $(date +%H:%M)" >> "$LOG"
train smoke
if ! ls "$O"/lora/dp_runs/slvrareal6b_hidream_smoke/*/*/adapter_model.safetensors > /dev/null 2>&1; then
  echo "HIDREAM SMOKE FAILED $(date +%H:%M) - see hidream_lora_smoke_console.log" >> "$LOG"
  vm_memory 20GB
  exit 0
fi
echo "smoke OK $(date +%H:%M); full start" >> "$LOG"
train full
vm_memory 20GB
pwsh.exe -NoProfile -Command "wslc run --rm --name dp-copy -v comfy-models:/models -v '$R\output:/data/output' --entrypoint sh comfyui-r9700:local -c 'cd /data/output/lora/dp_runs/slvrareal6b_hidream_full; last=; for e in \$(ls -d */epoch* 2>/dev/null | sort -V); do n=\$(basename \$e | tr -dc 0-9); cp -n \$e/adapter_model.safetensors /models/loras/slvrareal6b_hidream_e\$n.safetensors; last=\$e; done; [ -n \"\$last\" ] && cp \$last/adapter_model.safetensors /models/loras/slvrareal_hidream.safetensors && echo copied last \$last; ls -la /models/loras/ | grep hidream'" 2>&1 | tr -d '\r' >> "$LOG"
pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break; sleep 5; done
pwsh.exe -NoProfile -Command "wslc exec -e SHE3_STRENGTHS=0.6,0.8,1.0 comfyui sh -c 'python /opt/tests/newmodel_check.py run hidream'" > "$DIR/hidream_lora_test.out" 2>&1
grep -E "newmodel|rror|imeout" "$DIR/hidream_lora_test.out" | tr -d '\r' | tail -16 >> "$LOG"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name nm-sheet-h -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/newmodel_check.py sheet hidream" 2>&1 | tr -d '\r' | tail -2 >> "$LOG"
echo "HIDREAM LORA DONE $(date +%H:%M)" >> "$LOG"
