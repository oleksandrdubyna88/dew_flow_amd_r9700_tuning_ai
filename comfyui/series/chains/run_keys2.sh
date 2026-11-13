#!/usr/bin/env bash
# ep3 keyframes, the rest: ONE shot per freshly started ComfyUI (the first run hit "out of memory" at shot 7 c2 after
# switching Qwen-Image / Qwen-Image-Edit + LoRA many times on one server). After her lines (LINES DONE). Shots 2 and 5
# again with fixed prompts as candidates c3/c4 (EP3_SET=2). Logs to ep3_keys.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep3_keys.log"
until grep -q "LINES DONE" "$DIR/ep3_voice.log" 2>/dev/null; do sleep 20; done
run() {  # $1 = shot, $2 = set
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break; sleep 5; done
  pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'EP3_SET=$2 python /opt/tests/ep3_keys.py $1'" 2>&1 | tr -d '\r' | grep -E "ep3 key|out of memory" | head -3 >> "$LOG"
}
for k in $(seq 15 23); do run "$k" 1; done  # resumed 2026-11-10 after the pause: 7-14 done
run 2 2; run 5 2
echo "KEYS2 DONE $(date +%H:%M)" >> "$LOG"
