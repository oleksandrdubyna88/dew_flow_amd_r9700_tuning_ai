#!/usr/bin/env bash
# Download HunyuanImage 2.1 (Tencent Hunyuan Community License: NOT for the EU, UK, South Korea; the owner confirmed 2026-11-12 ~16:10 "not in EU")
# repo Comfy-Org/Hunyuan-Image-2.1 (open, not gated, no token). bf16/fp16 = LoRA training base, fp8 = ComfyUI inference.
# Network + disk only, no GPU. Logs to hunyuan21_download.log ("DL DONE").
set -u
DIR="$(dirname "$0")"; LOG="$DIR/hunyuan21_download.log"
echo "download start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name hunyuan21-dl -v comfy-models:/models --entrypoint sh comfyui-r9700:local -c 'cd /models
get() { if [ -s \$1 ]; then echo have \$1; return; fi
  curl -fL -C - --retry 20 --retry-delay 15 --retry-all-errors --speed-limit 100000 --speed-time 90 -sS -o \$1.part \$2 && mv \$1.part \$1 && echo got \$1 \$(du -h \$1 | cut -f1); }
get diffusion_models/hunyuanimage2.1_bf16.safetensors https://huggingface.co/Comfy-Org/Hunyuan-Image-2.1/resolve/main/split_files/diffusion_models/hunyuanimage2.1_bf16.safetensors
get diffusion_models/hunyuanimage2.1_fp8_e4m3fn.safetensors https://huggingface.co/Comfy-Org/Hunyuan-Image-2.1/resolve/main/split_files/diffusion_models/hunyuanimage2.1_fp8_e4m3fn.safetensors
get text_encoders/byt5_small_glyphxl_fp16.safetensors https://huggingface.co/Comfy-Org/Hunyuan-Image-2.1/resolve/main/split_files/text_encoders/byt5_small_glyphxl_fp16.safetensors
get vae/hunyuan_image_2.1_vae_fp16.safetensors https://huggingface.co/Comfy-Org/Hunyuan-Image-2.1/resolve/main/split_files/vae/hunyuan_image_2.1_vae_fp16.safetensors
ls -la diffusion_models/hunyuanimage2.1_bf16.safetensors diffusion_models/hunyuanimage2.1_fp8_e4m3fn.safetensors text_encoders/byt5_small_glyphxl_fp16.safetensors vae/hunyuan_image_2.1_vae_fp16.safetensors'" 2>&1 | tr -d '\r' >> "$LOG"
n=$(grep -cE "^(got|have) " "$LOG"); [ "$n" -ge 4 ] && echo "DL DONE $(date +%H:%M)" >> "$LOG" || echo "DL FAILED $(date +%H:%M) ($n/4)" >> "$LOG"
