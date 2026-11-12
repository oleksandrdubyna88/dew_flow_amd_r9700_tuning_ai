#!/usr/bin/env bash
# Llama-3.1-8B-Instruct in HF format, the text encoder 4 that diffusion-pipe's HiDream needs (llama3_path). The owner
# chose 2026-11-12 ~17:15 option 1: the open unsloth copy (same weights; Meta Llama 3.1 Community License applies).
# -> comfy-models:/models/llm/Meta-Llama-3.1-8B-Instruct (16.1 GB). Network + disk only. Log llama31_download.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
DIR="$(dirname "$0")"; LOG="$DIR/llama31_download.log"
echo "download start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name llama31-dl -v comfy-models:/models -v '$COMFY_HOME_WIN\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local -I /opt/tests/hf_repo_get.py unsloth/Meta-Llama-3.1-8B-Instruct /models/llm/Meta-Llama-3.1-8B-Instruct" 2>&1 | tr -d '\r' >> "$LOG"
grep -q "^REPO OK" "$LOG" && echo "DL DONE $(date +%H:%M)" >> "$LOG" || echo "DL FAILED $(date +%H:%M)" >> "$LOG"
