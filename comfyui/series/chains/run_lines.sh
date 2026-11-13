#!/usr/bin/env bash
# Her ep3 lines with the chosen voice (her_qwen_t3), after the keyframes ("KEYS DONE" in ep3_keys.log). Logs to ep3_voice.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; R="$COMFY_HOME_WIN"
until grep -q "KEYS DONE" "$DIR/ep3_keys.log" 2>/dev/null; do sleep 30; done
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -Command "wslc run --rm --name ep3-lines --gpus all -e MIOPEN_FIND_MODE=FAST -v tts-qwen-env:/tts -v comfy-models:/models:ro -v '$R\output:/out' -v '$R\tests:/opt/tests:ro' --entrypoint /tts/venv/bin/python comfyui-r9700:local /opt/tests/ep3_voice.py lines" 2>&1 | tr -d '\r' | grep -E "clone|design_|Error|Trace" >> "$DIR/ep3_voice.log"
echo "LINES DONE $(date +%H:%M)" >> "$DIR/ep3_voice.log"
