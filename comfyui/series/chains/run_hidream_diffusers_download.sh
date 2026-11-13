#!/usr/bin/env bash
# HiDream-I1-Full in diffusers format (MIT, open) for diffusion-pipe (models/hidream.py loads diffusers_path with
# from_pretrained; the ComfyUI single file is for inference only). -> comfy-models:/models/diffusers/HiDream-I1-Full
# Network + disk only. Logs to hidream_diffusers_download.log ("DL DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
DIR="$(dirname "$0")"; LOG="$DIR/hidream_diffusers_download.log"
echo "download start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name hidream-dfs-dl -v comfy-models:/models -v '$COMFY_HOME_WIN\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local -I /opt/tests/hf_repo_get.py HiDream-ai/HiDream-I1-Full /models/diffusers/HiDream-I1-Full demo.jpg" 2>&1 | tr -d '\r' >> "$LOG"
grep -q "^REPO OK" "$LOG" && echo "DL DONE $(date +%H:%M)" >> "$LOG" || echo "DL FAILED $(date +%H:%M)" >> "$LOG"
