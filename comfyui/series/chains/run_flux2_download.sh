#!/usr/bin/env bash
# FLUX.2 klein 4B (the owner 2026-11-12 ~01:20: "then let's try Flux too"; "you may install in WSL what is needed").
# The only open Flux (Apache 2.0, not gated): Comfy-Org/Flux-2-Klein-4B — base 4B (for training), distilled 4B (4-step
# inference), Qwen3 4B text encoder, flux2 VAE -> the comfy-models volume. FLUX.1-dev / FLUX.2-dev / klein 9B are gated
# (Hugging Face login) — not used. Network + disk only, no GPU. Logs to flux2_download.log ("FLUX2 DL DONE").
set -u
DIR="$(dirname "$0")"; LOG="$DIR/flux2_download.log"
B=https://huggingface.co/Comfy-Org/Flux-2-Klein-4B/resolve/main/split_files
echo "download start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name flux2-dl -v comfy-models:/models --entrypoint sh comfyui-r9700:local -c 'set -e; cd /models
for f in diffusion_models/flux-2-klein-base-4b.safetensors diffusion_models/flux-2-klein-4b.safetensors text_encoders/qwen_3_4b.safetensors vae/flux2-vae.safetensors; do
  if [ -s \$f ]; then echo have \$f; continue; fi
  curl -fL --retry 5 --retry-delay 10 -s -o \$f.part $B/\$f && mv \$f.part \$f && echo got \$f \$(du -h \$f | cut -f1)
done; ls -la diffusion_models/flux-2* text_encoders/qwen_3_4b* vae/flux2*'" 2>&1 | tr -d '\r' >> "$LOG"
n=$(grep -cE "^(got|have) " "$LOG"); [ "$n" -ge 4 ] && echo "FLUX2 DL DONE $(date +%H:%M)" >> "$LOG" || echo "FLUX2 DL FAILED $(date +%H:%M) ($n/4)" >> "$LOG"
