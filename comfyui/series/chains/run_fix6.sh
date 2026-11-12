#!/usr/bin/env bash
# Episode 2 v4 shot 6 failed in run_young.sh (KeyError 6: no v4 motion; fixed with the episode motion as fallback).
# Shot 6 after FIX3 DONE, while run_young.sh still waits for my ep1 picks; then ep2 join + mix again.
# Logs to young_run.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/young_run.log"; R="$COMFY_HOME_WIN"; V4="$COMFY_HOME"/output/series/ep2/v4
until grep -q "FIX3 DONE" "$LOG" 2>/dev/null; do sleep 30; done
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
for i in $(seq 1 60); do
  pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break
  sleep 5
done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_v4.py shot 6" 2>&1 | tr -d '\r' | grep -E "shot|out of memory|Error" | sed 's/^/fix6: /' >> "$LOG"
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_v4.py join" 2>&1 | tr -d '\r' | tail -1 | sed 's/^/fix6: /' >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name comfyui-mix -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/voiceover.py /data/output/series/ep2/ep2_arcane_14b_v4.mp4 ep2/vox --shot 5.0625 --end slowmo" 2>&1 | tr -d '\r' | grep -E "ending|audio ok|written|bad|rror" | sed 's/^/fix6: /' >> "$LOG"
echo "FIX6 DONE $(date +%H:%M)" >> "$LOG"
