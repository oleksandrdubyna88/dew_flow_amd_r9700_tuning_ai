#!/usr/bin/env bash
# Night chain after the Qwen LoRA v3 (the owner 2026-11-12 ~01:30: "then Flux too", "and Stable Diffusion too", "do the
# maximum you can, I hope all is ready in the morning"). One GPU job at a time:
#   1. Qwen test (she3_check.py qwen + sheet)                       "QTEST DONE"
#   2. VM 40 GB -> FLUX.2 klein base 4B LoRA (lora_train_flux2.sh)  "FTRAIN exit"
#   3.            SDXL RealVisXL LoRA (lora_train_sdxl.sh)           "STRAIN exit"
#   4. VM 20 GB -> copy both LoRAs to /models/loras
#   5. FLUX.2 test, SDXL test (+ sheets)                             "NIGHT V3 DONE"
# Each step goes on when the one before fails (logged), so one broken trainer does not stop the rest.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN WSLC_SETTINGS_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/night_v3.log"; STOPF="$DIR/.guard_off_nv3"; R="$COMFY_HOME_WIN"
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
  pwsh.exe -NoProfile -Command "wslc run --rm --name lora-train-$1 --gpus all -e LORA_NAME=slvrareal3 -v lora-env:/lora -v comfy-models:/models:ro -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint bash comfyui-r9700:local /opt/tests/$2" > "$DIR/night_v3_$1_console.log" 2>&1
  echo "$1 exit $? $(date +%H:%M); last lines:" >> "$LOG"; tr -d '\r' < "$DIR/night_v3_$1_console.log" | grep -vE "^\s*$" | tail -4 | cut -c1-300 >> "$LOG"
}
echo "waiting for LSHE3 $(date +%H:%M)" >> "$LOG"
until grep -qE "LSHE3 (DONE|FAILED)" "$DIR/lora_she3_train.log" 2>/dev/null; do sleep 60; done
sleep 20
echo "chain start $(date +%H:%M)" >> "$LOG"
grep -q "LSHE3 DONE" "$DIR/lora_she3_train.log" && { test_model qwen; echo "QTEST DONE $(date +%H:%M)" >> "$LOG"; }
until grep -qE "FLUX2 DL (DONE|FAILED)" "$DIR/flux2_download.log" 2>/dev/null; do sleep 60; done
until grep -qE "SDSETUP (DONE|FAILED)" "$DIR/sdscripts_setup.log" 2>/dev/null; do sleep 60; done
vm_memory 40GB
grep -q "FLUX2 DL DONE" "$DIR/flux2_download.log" && train FTRAIN lora_train_flux2.sh
grep -q "SDSETUP DONE" "$DIR/sdscripts_setup.log" && train STRAIN lora_train_sdxl.sh
vm_memory 20GB
pwsh.exe -NoProfile -Command "wslc run --rm --name lora-copy-v3 -v comfy-models:/models -v '$R\output:/data/output' --entrypoint sh comfyui-r9700:local -c 'for f in slvrareal3_flux2k4b slvrareal3_sdxl; do [ -f /data/output/lora/out/\$f.safetensors ] && cp /data/output/lora/out/\$f.safetensors /models/loras/ && echo copied \$f; done; ls -la /models/loras/slvrareal3*'" 2>&1 | tr -d '\r' >> "$LOG"
grep -q "copied slvrareal3_flux2k4b" "$LOG" && test_model flux2
grep -q "copied slvrareal3_sdxl" "$LOG" && test_model sdxl
echo "NIGHT V3 DONE $(date +%H:%M)" >> "$LOG"
