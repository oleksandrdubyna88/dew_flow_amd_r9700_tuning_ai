#!/usr/bin/env bash
# The Qwen3-TTS female narration of episode 1 (owner 2026-11-09), on the GPU after the keyframes ("real keys ready").
# qwen_tts lives in the tts-qwen-env volume (tts-env has VoxCPM). Logs to next.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/next.log"; R="$COMFY_HOME_WIN"
until grep -q "real keys ready" "$LOG" 2>/dev/null; do sleep 30; done
pwsh.exe -NoProfile -Command "wslc run --rm --name comfyui-tts --gpus all -v tts-qwen-env:/tts -v comfy-models:/models:ro -v '$R\output:/out' -v '$R\tests:/opt/tests:ro' --entrypoint /tts/venv/bin/python comfyui-r9700:local /opt/tests/narrate.py qwen-woman ep1 woman_qwen/woman_qwen" 2>&1 | tr -d '\r' | grep -E "woman|reference|Error|Trace|rror" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name comfyui-mix -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/voiceover.py /data/output/series/elf_set2_arcane/elf_set2_arcane_14b_30s.mp4 woman_qwen/woman_qwen --shot 5.0625 --end slowmo" 2>&1 | tr -d '\r' | grep -E "ending|audio ok|written|bad|rror" >> "$LOG"
echo "qwen woman done $(date +%H:%M)" >> "$LOG"
