#!/usr/bin/env bash
# Arcane v4 with the young face (owner 2026-11-09): after the realistic clips ("real done" in clips.log) stop run_clips.sh
# (its v4 part only had shots 3 4 5 7 9), draw round 4 (ep2_v4.py keyframes4, shots 1-6), wait for my picks by eye
# (v4/pick4_s3..6.png; shot 7 keeps pick_s7.png; v3 shots 1-2 stay), then clips 3-7 and 9 (one per fresh server), join, mix. Logs to v4b.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/v4b.log"; R="$COMFY_HOME_WIN"; V4="$COMFY_HOME"/output/series/ep2/v4
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do
    pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0
    sleep 5
  done
  echo "restart: not ready after 300 s" >> "$LOG"; return 1
}
until grep -q "real done" "$DIR/clips.log" 2>/dev/null; do sleep 30; done
pkill -f "bash $(cd "$(dirname "$0")" && pwd)/run_clips.sh" && echo "run_clips.sh stopped (its v4 part is replaced)" >> "$LOG"
restart && pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_v4.py keyframes4" 2>&1 | tr -d '\r' | grep -E "^shot|rror" >> "$LOG"
echo "round-4 keys ready $(date +%H:%M)" >> "$LOG"
until [ -f "$V4/pick4_s3.png" ] && [ -f "$V4/pick4_s4.png" ] && [ -f "$V4/pick4_s5.png" ] && [ -f "$V4/pick4_s6.png" ]; do sleep 60; done
for k in 3 4 5 6 7 9; do  # owner: the first 10 s (v3 shots 1, 2) are good and stay
  for try in 1 2; do
    restart || exit 1
    out="$(pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_v4.py shot $k" 2>&1 | tr -d '\r')"
    echo "$out" | grep -E "shot|out of memory|Error" | head -3 >> "$LOG"
    echo "$out" | grep -qE "shot $k: clip" && break
    echo "shot $k: try $try failed" >> "$LOG"
  done
done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_v4.py join" 2>&1 | tr -d '\r' | tail -1 >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name comfyui-mix -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/voiceover.py /data/output/series/ep2/ep2_arcane_14b_v4.mp4 ep2/vox --shot 5.0625 --end slowmo" 2>&1 | tr -d '\r' | grep -E "ending|audio ok|written|bad|rror" >> "$LOG"
echo "all done $(date +%H:%M)" >> "$LOG"
