#!/usr/bin/env bash
# After the after-v3 chain (memory A/B + ep2 v3 slowmo mix), all on the GPU:
#  1. the Qwen3-TTS female narration of episode 1 (owner 2026-11-09), mixed with the moving ending;
#  2. episode 2 v4 keyframe candidates (ep2_v4.py keyframes) — then STOP: the candidates are picked by eye before clips.
# Logs to next.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/next.log"; R="$COMFY_HOME_WIN"
until grep -q "all done" "$DIR/after-v3.log" 2>/dev/null; do sleep 30; done
echo "start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name comfyui-tts --gpus all -v tts-env:/tts -v comfy-models:/models:ro -v '$R\output:/out' -v '$R\tests:/opt/tests:ro' --entrypoint /tts/venv/bin/python comfyui-r9700:local /opt/tests/narrate.py qwen-woman ep1 woman_qwen/woman_qwen" 2>&1 | tr -d '\r' | grep -E "woman|reference|Error|Trace|rror" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name comfyui-mix -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/voiceover.py /data/output/series/elf_set2_arcane/elf_set2_arcane_14b_30s.mp4 woman_qwen/woman_qwen --shot 5.0625 --end slowmo" 2>&1 | tr -d '\r' | grep -E "ending|audio ok|written|bad|rror" >> "$LOG"
echo "qwen woman done $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
for i in $(seq 1 60); do
  pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break
  sleep 5
done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_v4.py keyframes" 2>&1 | tr -d '\r' | grep -E "^shot|rror" >> "$LOG"
echo "keys ready $(date +%H:%M)" >> "$LOG"
