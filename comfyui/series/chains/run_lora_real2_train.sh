#!/usr/bin/env bash
# The REALISTIC LoRAs v2 (the owner, 2026-11-11: two LoRAs, one per outfit; the faces of set c replaced with the chosen
# face by InstantID, face weight 1.2 — face_repaint_real.py pick -> lora/real2cf_gen -> lora_dataset_real2.py collect with
# REAL2_SET=cf -> lora/slvrareal2_tunic, lora/slvrareal2_fur). Same safe pattern as run_lora_real_train.sh: the wslc VM to
# 40 GB (session restart between jobs, allowed by the owner; skipped when already 40 GB), train tunic then fur
# (lora_train.sh, 12 epochs: ~27 pictures x 4 repeats x 12 ~ 1300 steps ~ 1 h 40 min each), the VM back to 20 GB, the
# LoRAs copied into the models volume. 17:58: the y75 mix datasets slvrareal2_tunic/fur (27+27, real2cy_gen) -> LoRAs slvrareal2_*. Logs to lora_real2_train.log ("LREAL2 DONE" only when both files are copied).
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN WSLC_SETTINGS_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/lora_real2_train.log"; R="$COMFY_HOME_WIN"; SET="$WSLC_SETTINGS"
O="$COMFY_HOME"/output/lora
vm_memory() {  # $1 = e.g. 40GB; a new session reads it
  sed -i "s/^  memorySize: .*/  memorySize: $1/" "$SET"
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  timeout 300 pwsh.exe -NoProfile -Command "wslc system session terminate" > /dev/null 2>&1 || echo "session terminate TIMED OUT $(date +%H:%M)" >> "$LOG"; sleep 5
  echo "VM memory set to $1 (session restarted) $(date +%H:%M)" >> "$LOG"
}
for o in tunic fur; do
  n=$(ls "$O/slvrareal2_$o"/*.png 2>/dev/null | wc -l); t=$(ls "$O/slvrareal2_$o"/*.txt 2>/dev/null | wc -l)
  [ "$n" -ge 20 ] && [ "$n" = "$t" ] || { echo "LREAL2 FAILED $(date +%H:%M): dataset $o has $n pictures, $t captions" >> "$LOG"; exit 1; }
done
echo "real2 training start $(date +%H:%M)" >> "$LOG"
grep -q "^  memorySize: 40GB" "$SET" || vm_memory 40GB
for o in tunic fur; do
  pwsh.exe -NoProfile -Command "wslc run --rm --name lora-train-$o --gpus all -e LORA_NAME=slvrareal2_$o -e LORA_EPOCHS=12 -v lora-env:/lora -v comfy-models:/models:ro -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint bash comfyui-r9700:local /opt/tests/lora_train.sh all" > "$DIR/lora_real2_${o}_console.log" 2>&1
  echo "training $o exit $? $(date +%H:%M); last lines:" >> "$LOG"; tr -d '\r' < "$DIR/lora_real2_${o}_console.log" | grep -vE "^\s*$" | tail -4 >> "$LOG"
done
vm_memory 20GB
pwsh.exe -NoProfile -Command "wslc run --rm --name lora-copy -v comfy-models:/models -v '$R\output:/data/output' --entrypoint sh comfyui-r9700:local -c 'cp /data/output/lora/out/slvrareal2_tunic.safetensors /data/output/lora/out/slvrareal2_fur.safetensors /models/loras/ && ls -la /models/loras/slvrareal2_*'" 2>&1 | tr -d '\r' >> "$LOG"
if grep -q "slvrareal2_tunic.safetensors" "$LOG" && grep -q "slvrareal2_fur.safetensors" "$LOG"; then echo "LREAL2 DONE $(date +%H:%M)" >> "$LOG"; else echo "LREAL2 FAILED $(date +%H:%M)" >> "$LOG"; fi
