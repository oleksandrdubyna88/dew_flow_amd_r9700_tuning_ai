#!/usr/bin/env bash
# Download HiDream-I1 Full (MIT; the owner 2026-11-12 ~16:05: HiDream-I1 Full + HunyuanImage 2.1, then LoRAs + 360 videos)
# repo Comfy-Org/HiDream (open, not gated, no token). bf16/fp16 = LoRA training base, fp8 = ComfyUI inference.
# Network + disk only, no GPU. Logs to hidream_download.log ("DL DONE").
set -u
DIR="$(dirname "$0")"; LOG="$DIR/hidream_download.log"
echo "download start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name hidream-dl -v comfy-models:/models --entrypoint sh comfyui-r9700:local -c 'cd /models
get() { if [ -s \$1 ]; then echo have \$1; return; fi
  curl -fL -C - --retry 20 --retry-delay 15 --retry-all-errors --speed-limit 100000 --speed-time 90 -sS -o \$1.part \$2 && mv \$1.part \$1 && echo got \$1 \$(du -h \$1 | cut -f1); }
get diffusion_models/hidream_i1_full_fp16.safetensors https://huggingface.co/Comfy-Org/HiDream/resolve/main/split_files/diffusion_models/hidream_i1_full_fp16.safetensors
get diffusion_models/hidream_i1_full_fp8.safetensors https://huggingface.co/Comfy-Org/HiDream/resolve/main/split_files/diffusion_models/hidream_i1_full_fp8.safetensors
get text_encoders/clip_g_hidream.safetensors https://huggingface.co/Comfy-Org/HiDream/resolve/main/split_files/text_encoders/clip_g_hidream.safetensors
get text_encoders/clip_l_hidream.safetensors https://huggingface.co/Comfy-Org/HiDream/resolve/main/split_files/text_encoders/clip_l_hidream.safetensors
get text_encoders/llama_3.1_8b_instruct_fp8_scaled.safetensors https://huggingface.co/Comfy-Org/HiDream/resolve/main/split_files/text_encoders/llama_3.1_8b_instruct_fp8_scaled.safetensors
get text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors https://huggingface.co/Comfy-Org/HiDream/resolve/main/split_files/text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors
get vae/ae.safetensors https://huggingface.co/Comfy-Org/HiDream/resolve/main/split_files/vae/ae.safetensors
ls -la diffusion_models/hidream_i1_full_fp16.safetensors diffusion_models/hidream_i1_full_fp8.safetensors text_encoders/clip_g_hidream.safetensors text_encoders/clip_l_hidream.safetensors text_encoders/llama_3.1_8b_instruct_fp8_scaled.safetensors text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors vae/ae.safetensors'" 2>&1 | tr -d '\r' >> "$LOG"
n=$(grep -cE "^(got|have) " "$LOG"); [ "$n" -ge 7 ] && echo "DL DONE $(date +%H:%M)" >> "$LOG" || echo "DL FAILED $(date +%H:%M) ($n/7)" >> "$LOG"
