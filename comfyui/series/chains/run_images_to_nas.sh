#!/usr/bin/env bash
# The owner 2026-11-12 ~20:37: "also put copies of the vLLM and ComfyUI images that now run in wslc there, just in case".
# wslc save -> NAS_IMAGES_WIN (next to the weights master, COMFY_STORE_WIN): comfyui-r9700:local (27.3 GB,
# image 3a98d3d4baa5) and rocm/vllm:rocm10.1.0_..._vllm-0.29.0 (75.2 GB, 2d41964ed4f4). Writes <name>.tar.part, then mv,
# then a .sha256 next to it, read back from the NAS. Starts after the weights copy ("MODELS NAS DONE") so the NAS
# writes do not fight. Restore: wslc load -i <tar>. Log images_to_nas.log ("IMAGES NAS DONE").
. "$(dirname "$0")/_env.sh" NAS_IMAGES_WIN || exit 2
DIR="$(dirname "$0")"; LOG="$DIR/images_to_nas.log"; D="$NAS_IMAGES"; W="$NAS_IMAGES_WIN"
echo "images to nas waiting for MODELS NAS DONE $(date +%H:%M)" >> "$LOG"
until grep -q "^MODELS NAS DONE" "$DIR/models_to_nas.log" 2>/dev/null; do sleep 60; done
mkdir -p "$D"
for spec in "comfyui-r9700:local|comfyui-r9700_local_3a98d3d4baa5" "rocm/vllm:rocm10.1.0_ubuntu24.04_py3.14-pytorch_2.13.0_vllm-0.29.0|rocm-vllm_0.29.0_rocm10.1.0_2d41964ed4f4"; do
  img=${spec%%|*}; n=${spec##*|}
  [ -f "$D/$n.tar" ] && { echo "have $n.tar" >> "$LOG"; continue; }
  echo "save $img start $(date +%H:%M)" >> "$LOG"
  pwsh.exe -NoProfile -Command "wslc save -o '$W\\$n.tar.part' '$img'" 2>&1 | tr -d '\r' | tail -3 >> "$LOG"
  [ -s "$D/$n.tar.part" ] && mv "$D/$n.tar.part" "$D/$n.tar"
  ( cd "$D" && nice -n 19 sha256sum "$n.tar" > "$n.tar.sha256" )
  echo "$n.tar $(du -h "$D/$n.tar" | cut -f1) sha256 $(cut -c1-16 "$D/$n.tar.sha256")… $(date +%H:%M)" >> "$LOG"
done
echo "IMAGES NAS DONE $(date +%H:%M)" >> "$LOG"
