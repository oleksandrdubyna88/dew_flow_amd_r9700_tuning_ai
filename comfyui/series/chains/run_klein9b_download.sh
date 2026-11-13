#!/usr/bin/env bash
# FLUX.2 klein 9B (the owner 2026-11-12 ~08:40: "is there a stronger Flux?" -> accepted the licence and gave a read token).
# GATED, FLUX Non-Commercial License: a LoRA on it must NOT be released under Apache-2.0.
#   black-forest-labs/FLUX.2-klein-base-9B  flux-2-klein-base-9b.safetensors  (training base)   token
#   black-forest-labs/FLUX.2-klein-9B       flux-2-klein-9b.safetensors       (4-step distilled) token
#   Comfy-Org/Flux-2-Klein-9B               qwen_3_8b.safetensors             (text encoder)     open
# The token file is mounted read-only from the secrets folder of COMFY_HOME_WIN (deleted after the download), never on a command line.
# Network + disk only, no GPU. Logs to klein9b_download.log ("K9 DL DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/klein9b_download.log"
echo "download start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name k9-dl -v comfy-models:/models -v '$COMFY_HOME_WIN\secrets:/secrets:ro' --entrypoint sh comfyui-r9700:local -c 'cd /models
get() { if [ -s \$1 ]; then echo have \$1; return; fi
  if [ \"\$3\" = auth ]; then H=\"-H@/tmp/auth\"; else H=\"\"; fi
  curl -fL -C - --retry 5 --retry-delay 10 -sS \$H -o \$1.part \$2 && mv \$1.part \$1 && echo got \$1 \$(du -h \$1 | cut -f1); }
B=Bearer; printf \"Authorization: %s %s\" \$B \"\$(cat /secrets/hf_token)\" > /tmp/auth
get diffusion_models/flux-2-klein-base-9b.safetensors https://huggingface.co/black-forest-labs/FLUX.2-klein-base-9B/resolve/main/flux-2-klein-base-9b.safetensors auth
get diffusion_models/flux-2-klein-9b.safetensors https://huggingface.co/black-forest-labs/FLUX.2-klein-9B/resolve/main/flux-2-klein-9b.safetensors auth
get text_encoders/qwen_3_8b.safetensors https://huggingface.co/Comfy-Org/Flux-2-Klein-9B/resolve/main/split_files/text_encoders/qwen_3_8b.safetensors open
rm -f /tmp/auth; ls -la diffusion_models/flux-2-klein*9b* text_encoders/qwen_3_8b*'" 2>&1 | tr -d '\r' >> "$LOG"
n=$(grep -cE "^(got|have) " "$LOG"); [ "$n" -ge 3 ] && echo "K9 DL DONE $(date +%H:%M)" >> "$LOG" || echo "K9 DL FAILED $(date +%H:%M) ($n/3)" >> "$LOG"
# 08:35: keep the token file until all 3 files are here (1st run: 403 — the licences were not yet accepted)
grep -q "K9 DL DONE" "$LOG" && rm -f "$COMFY_HOME/secrets/hf_token"
