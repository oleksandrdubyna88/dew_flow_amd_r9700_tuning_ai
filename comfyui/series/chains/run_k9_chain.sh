#!/usr/bin/env bash
# FLUX.2 klein 9B LoRA chain (the owner 2026-11-12 ~08:45: "do SDXL, then the Flux 9B LoRA. Work autonomously").
# 1. download (run_klein9b_download.sh) retried every 10 min until "K9 DL DONE" — the 2 gated files give 403 until the
#    owner accepts both licences; never started while the SDXL chain restarts the wslc session
# 2. wait "SDXL V3 DONE" (one GPU job at a time)  3. VM 40 GB -> K9TRAIN (lora_train_flux2.sh, FLUX2_SIZE=9b)
# 4. VM 20 GB -> copy -> she3_check.py flux2k9 + sheet -> "K9 CHAIN DONE". Log k9_chain.log.
# The LoRA is under the FLUX Non-Commercial License: NOT for an Apache release.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN WSLC_SETTINGS_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/k9_chain.log"; STOPF="$DIR/.guard_off_k9"; R="$COMFY_HOME_WIN"
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
  pwsh.exe -NoProfile -Command "wslc run --rm --name lora-train-$1 --gpus all -e LORA_NAME=slvrareal3 -v lora-env:/lora -v comfy-models:/models:ro -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint bash comfyui-r9700:local /opt/tests/$2" > "$DIR/k9_$1_console.log" 2>&1
  echo "$1 exit $? $(date +%H:%M); last lines:" >> "$LOG"; tr -d '\r' < "$DIR/k9_$1_console.log" | grep -vE "^\s*$" | tail -4 | cut -c1-300 >> "$LOG"
}
SX="$DIR/sdxl_v3.log"; DL="$DIR/klein9b_download.log"
sdxl_quiet() {  # true while the SDXL trainer runs (2nd STRAIN not ended) or after the SDXL chain is done
  [ "$(grep -c 'SDXL V3 DONE' "$SX")" -ge 2 ] && return 0
  [ "$(grep -c 'STRAIN exit' "$SX")" -lt 2 ] && grep -q "rerun 08:29" "$SX" && return 0
  return 1
}
while pgrep -f run_klein9b_download.sh > /dev/null; do sleep 30; done  # the 08:33 TE download still running
echo "k9 chain start $(date +%H:%M)" >> "$LOG"
for i in $(seq 1 60); do
  grep -q "K9 DL DONE" "$DL" && break
  if sdxl_quiet; then echo "--- try $i $(date +%H:%M)" >> "$DL"; "$DIR/run_klein9b_download.sh"; fi
  grep -q "K9 DL DONE" "$DL" && break
  sleep 600
done
grep -q "K9 DL DONE" "$DL" || { echo "K9 DL never done — stop $(date +%H:%M)" >> "$LOG"; echo "K9 CHAIN DONE $(date +%H:%M)" >> "$LOG"; exit 1; }
echo "download ok $(date +%H:%M)" >> "$LOG"
until [ "$(grep -c 'SDXL V3 DONE' "$SX")" -ge 2 ]; do sleep 60; done
sleep 20
vm_memory 40GB
pwsh.exe -NoProfile -Command "wslc run --rm --name lora-train-k9 --gpus all -e LORA_NAME=slvrareal3 -e FLUX2_SIZE=9b -v lora-env:/lora -v comfy-models:/models:ro -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint bash comfyui-r9700:local /opt/tests/lora_train_flux2.sh" > "$DIR/k9_K9TRAIN_console.log" 2>&1
echo "K9TRAIN exit $? $(date +%H:%M); last lines:" >> "$LOG"; tr -d '\r' < "$DIR/k9_K9TRAIN_console.log" | grep -vE "^\s*$" | tail -4 | cut -c1-300 >> "$LOG"
vm_memory 20GB
pwsh.exe -NoProfile -Command "wslc run --rm --name lora-copy-k9 -v comfy-models:/models -v '$R\output:/data/output' --entrypoint sh comfyui-r9700:local -c '[ -f /data/output/lora/out/slvrareal3_flux2k9b.safetensors ] && cp /data/output/lora/out/slvrareal3_flux2k9b.safetensors /models/loras/ && echo copied slvrareal3_flux2k9b; ls -la /models/loras/slvrareal3*'" 2>&1 | tr -d '\r' >> "$LOG"
grep -q "copied slvrareal3_flux2k9b" "$LOG" && test_model flux2k9
echo "K9 CHAIN DONE $(date +%H:%M)" >> "$LOG"
