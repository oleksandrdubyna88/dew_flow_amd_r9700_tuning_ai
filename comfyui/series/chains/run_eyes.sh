#!/usr/bin/env bash
# The owner (2026-11-09): "the eyes are the main thing — they must be flawless". New order, eyes first:
#  1. after realistic clip 2 (rendering now) stop run_after_lora.sh;
#  2. the eye test: ep1 shot 2 (the face close-up) A = new seed, B = 8 steps, C = 8 steps + eye sentence -> "EYES READY";
#  3. LoRA v1 strength test 0.5 / 0.7 / 0.7 soft + 24 soft candidates -> "V2 CANDIDATES READY";
#  4. realistic clips 3-9, join, mix -> "REAL DONE";
#  5. LoRA v2 (waits for my dataset lora/slvra_v2/READY): VM 40 GB, train 8 epochs, VM 20 GB, copy, test -> "V2 DONE".
# Logs to eyes_run.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN WSLC_SETTINGS_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/eyes_run.log"; R="$COMFY_HOME_WIN"; SET="$WSLC_SETTINGS"
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
clip() {  # $1 = driver + args before the shot number, $2 = shot (+ optional label for eyetest)
  for try in 1 2; do
    restart || return 1
    out="$(pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/$1 $2" 2>&1 | tr -d '\r')"
    echo "$out" | grep -E "shot|out of memory|Error" | head -3 >> "$LOG"
    echo "$out" | grep -qE "shot [0-9]+: clip" && return 0
    echo "$1 $2: try $try failed" >> "$LOG"
  done
}
lt() { pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/lora_test.py $*" 2>&1 | tr -d '\r' | grep -E "slvra|base|soft|rror" >> "$LOG"; }
until grep -qE "real shot 2: clip|ep2_real.py shot 2: try 2 failed" "$DIR/after_lora.log" 2>/dev/null; do sleep 20; done
P=run_after; P="${P}_lora.sh"; pkill -f "bash $(cd "$(dirname "$0")" && pwd)/$P" && echo "run_after_lora stopped after real clip 2 $(date +%H:%M)" >> "$LOG"
for v in A B C; do clip "young_face.py eyetest 2" "$v"; done
echo "EYES READY $(date +%H:%M)" >> "$LOG"
restart
lt slvra_v1.safetensors 0.5; lt slvra_v1.safetensors 0.7; lt slvra_v1.safetensors 0.7 --soft
lt softset slvra_v1.safetensors 0.6
echo "V2 CANDIDATES READY $(date +%H:%M)" >> "$LOG"
for k in 3 4 5 6 7 8 9; do clip "ep2_real.py shot" "$k"; done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_real.py join" 2>&1 | tr -d '\r' | tail -1 >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name comfyui-mix -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/voiceover.py /data/output/series/ep2_real/ep2_real_14b.mp4 ep2/vox --shot 5.0625 --end slowmo" 2>&1 | tr -d '\r' | grep -E "ending|audio ok|written|bad|rror" >> "$LOG"
echo "REAL DONE $(date +%H:%M)" >> "$LOG"
until [ -f "$COMFY_HOME"/output/lora/slvra_v2/READY ]; do sleep 60; done
vm_memory 40GB
pwsh.exe -NoProfile -Command "wslc run --rm --name lora-train --gpus all -e LORA_NAME=slvra_v2 -e LORA_EPOCHS=8 -v lora-env:/lora -v comfy-models:/models:ro -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint bash comfyui-r9700:local /opt/tests/lora_train.sh all" > "$DIR/lora2_train_console.log" 2>&1
echo "training exit $? $(date +%H:%M)" >> "$LOG"; tr -d '\r' < "$DIR/lora2_train_console.log" | grep -E "model saved|Error|Traceback" | tail -3 >> "$LOG"
vm_memory 20GB
pwsh.exe -NoProfile -Command "wslc run --rm --name lora-copy -v comfy-models:/models -v '$R\output:/data/output:ro' --entrypoint cp comfyui-r9700:local /data/output/lora/out/slvra_v2.safetensors /models/loras/slvra_v2.safetensors" 2>&1 | tr -d '\r' >> "$LOG"
restart
lt slvra_v2.safetensors 1.0; lt slvra_v2.safetensors 0.7
echo "V2 DONE $(date +%H:%M)" >> "$LOG"
