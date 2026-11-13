#!/usr/bin/env bash
# The character LoRA BEFORE the realistic episode (owner 2026-11-09: approved musubi-tuner; wants the face kept by a LoRA).
# After EP1 DONE: stop run_young.sh (its next step was the realistic clips), make 10 close-up portraits for the dataset,
# raise the wslc VM memory to 40 GB for training (docs: 64 GB RAM recommended; session restart allowed between jobs by
# the owner), cache + train (tests/lora_train.sh), set the VM back to 20 GB, then the realistic episode 2 clips 2-9.
# Logs to lora_run.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN WSLC_SETTINGS_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/lora_run.log"; R="$COMFY_HOME_WIN"; SET="$WSLC_SETTINGS"
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do
    pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0
    sleep 5
  done
  echo "restart: not ready after 300 s" >> "$LOG"; return 1
}
vm_memory() {  # $1 = e.g. 40GB; a new session reads it
  sed -i "s/^  memorySize: .*/  memorySize: $1/" "$SET"
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -Command "wslc system session terminate" > /dev/null 2>&1; sleep 5
  echo "VM memory set to $1 (session restarted) $(date +%H:%M)" >> "$LOG"
}
clip() {  # $1 = driver + args before the shot number, $2 = shot
  for try in 1 2; do
    restart || return 1
    out="$(pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/$1 $2" 2>&1 | tr -d '\r')"
    echo "$out" | grep -E "shot|out of memory|Error" | head -3 >> "$LOG"
    echo "$out" | grep -qE "shot $2: clip" && return 0
    echo "$1 $2: try $try failed" >> "$LOG"
  done
}
until grep -q "EP1 DONE" "$DIR/young_run.log" 2>/dev/null; do sleep 20; done
P=run_; P="${P}young.sh"; pkill -f "bash $(cd "$(dirname "$0")" && pwd)/$P" && echo "run_young stopped after EP1 (the realistic clips follow the LoRA) $(date +%H:%M)" >> "$LOG"
until grep -q "^exit 0" "$DIR/fetch-lora.log" 2>/dev/null; do sleep 30; done
restart && pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/young_face.py portraits" 2>&1 | tr -d '\r' | grep -E "portrait|rror" >> "$LOG"
vm_memory 40GB
pwsh.exe -NoProfile -Command "wslc run --rm --name lora-train --gpus all -v lora-env:/lora -v comfy-models:/models:ro -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint bash comfyui-r9700:local /opt/tests/lora_train.sh all" > "$DIR/lora_train_console.log" 2>&1
echo "training exit $? $(date +%H:%M); last lines:" >> "$LOG"; tr -d '\r' < "$DIR/lora_train_console.log" | grep -vE "^\s*$" | tail -5 >> "$LOG"
vm_memory 20GB
echo "LORA DONE $(date +%H:%M)" >> "$LOG"
for k in 2 3 4 5 6 7 8 9; do clip "ep2_real.py shot" "$k"; done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_real.py join" 2>&1 | tr -d '\r' | tail -1 >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name comfyui-mix -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/voiceover.py /data/output/series/ep2_real/ep2_real_14b.mp4 ep2/vox --shot 5.0625 --end slowmo" 2>&1 | tr -d '\r' | grep -E "ending|audio ok|written|bad|rror" >> "$LOG"
echo "all done $(date +%H:%M)" >> "$LOG"
