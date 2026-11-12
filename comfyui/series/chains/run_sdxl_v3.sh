#!/usr/bin/env bash
# SDXL LoRA v3 (the owner ran run_sdscripts_setup.sh: SDSETUP DONE 08:27). Same helpers as run_night_v3.sh:
# VM 40 GB -> STRAIN (lora_train_sdxl.sh) -> VM 20 GB -> copy -> she3_check.py sdxl + sheet. Log sdxl_v3.log, "SDXL V3 DONE".
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN WSLC_SETTINGS_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/sdxl_v3.log"; STOPF="$DIR/.guard_off_sx3"; R="$COMFY_HOME_WIN"
SET="$WSLC_SETTINGS"; O="$COMFY_HOME"/output
vm_memory() {
  sed -i "s/^  memorySize: .*/  memorySize: $1/" "$SET"
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  timeout 300 pwsh.exe -NoProfile -Command "wslc system session terminate" > /dev/null 2>&1 || echo "session terminate TIMED OUT $(date +%H:%M)" >> "$LOG"; sleep 5
  echo "VM memory set to $1 (session restarted) $(date +%H:%M)" >> "$LOG"
}
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
test_model() {  # $1 = qwen | flux2 | sdxl
  restart || return 1
  "$DIR/guard_ram.sh" 6000 "$STOPF.$1" & local G=$!
  pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/she3_check.py $1'" 2>&1 | tr -d '\r' | grep -E "she3check|rror|Trace" | head -30 >> "$LOG"
  pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'grep -c \"lora key not loaded\" /tmp/comfyui.log 2>/dev/null || true'" 2>&1 | tr -d '\r' | sed "s/^/lora keys not loaded ($1): /" >> "$LOG"
  touch "$STOPF.$1"; kill $G 2>/dev/null
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
  pwsh.exe -NoProfile -Command "wslc run --rm --name s3sheet -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/she3_check.py sheet $1" 2>&1 | tr -d '\r' | grep -E "she3check|rror" >> "$LOG"
}
train() {  # $1 = label, $2 = script
  pwsh.exe -NoProfile -Command "wslc run --rm --name lora-train-$1 --gpus all -e LORA_NAME=slvrareal3 -v lora-env:/lora -v comfy-models:/models:ro -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint bash comfyui-r9700:local /opt/tests/$2" > "$DIR/sdxl_v3_$1_console.log" 2>&1
  echo "$1 exit $? $(date +%H:%M); last lines:" >> "$LOG"; tr -d '\r' < "$DIR/sdxl_v3_$1_console.log" | grep -vE "^\s*$" | tail -4 | cut -c1-300 >> "$LOG"
}
echo "sdxl chain start $(date +%H:%M)" >> "$LOG"
vm_memory 40GB
train STRAIN lora_train_sdxl.sh
vm_memory 20GB
pwsh.exe -NoProfile -Command "wslc run --rm --name lora-copy-sx3 -v comfy-models:/models -v '$R\output:/data/output' --entrypoint sh comfyui-r9700:local -c '[ -f /data/output/lora/out/slvrareal3_sdxl.safetensors ] && cp /data/output/lora/out/slvrareal3_sdxl.safetensors /models/loras/ && echo copied slvrareal3_sdxl; ls -la /models/loras/slvrareal3*'" 2>&1 | tr -d '\r' >> "$LOG"
grep -q "copied slvrareal3_sdxl" "$LOG" && test_model sdxl
echo "SDXL V3 DONE $(date +%H:%M)" >> "$LOG"
