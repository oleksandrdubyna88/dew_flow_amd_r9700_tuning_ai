#!/usr/bin/env bash
# Episode 2 clips, all on the GPU, ComfyUI restarted before every clip (now with --fast-disk --disable-pinned-memory):
#  0. after the Qwen female voice: the v4 round-2 keyframes (ep2_v4.py keyframes2), for picking by eye;
#  1. the realistic episode 2: clips 1-9 (shot 9 after 8), join, mix with the VoxCPM narration;
#  2. the Arcane v4: waits until v4/pick_s4/5/7.png exist (picked by eye), clips 3 4 5 7 9, join, mix.
# During realistic clip 1, Windows memory incl. GPU shared/dedicated usage is sampled (gpumem_s1.csv).
# Logs to clips.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/clips.log"; R="$COMFY_HOME_WIN"
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do
    pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0
    sleep 5
  done
  echo "restart: not ready after 300 s" >> "$LOG"; return 1
}
clip() {  # $1 = driver, $2 = shot
  for try in 1 2; do
    restart || return 1
    out="$(pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/$1 shot $2" 2>&1 | tr -d '\r')"
    echo "$out" | grep -E "shot|out of memory|Error" | head -3 >> "$LOG"
    echo "$out" | grep -qE "shot $2: clip" && return 0
    echo "$1 shot $2: try $try failed" >> "$LOG"
  done
}
mix() {  # $1 = film
  pwsh.exe -NoProfile -Command "wslc run --rm --name comfyui-mix -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/voiceover.py $1 ep2/vox --shot 5.0625 --end slowmo" 2>&1 | tr -d '\r' | grep -E "ending|audio ok|written|bad|rror" >> "$LOG"
}
until [ "$(grep -c "qwen woman done" "$DIR/next.log")" -ge 2 ]; do sleep 30; done
echo "start $(date +%H:%M)" >> "$LOG"
restart && pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_v4.py keyframes2" 2>&1 | tr -d '\r' | grep -E "^shot|rror" >> "$LOG"
echo "v4 round-2 keys ready $(date +%H:%M)" >> "$LOG"
for k in 1 2 3 4 5 6 7 8 9; do
  if [ "$k" = 1 ]; then "$DIR/gpumem.sh" "$DIR/gpumem_s1.csv" & GP=$!; fi
  clip ep2_real.py "$k"
  if [ "$k" = 1 ]; then sleep 120; kill "$GP" 2>/dev/null; fi
done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_real.py join" 2>&1 | tr -d '\r' | tail -1 >> "$LOG"
mix /data/output/series/ep2_real/ep2_real_14b.mp4
echo "real done $(date +%H:%M)" >> "$LOG"
until [ -f "$COMFY_HOME"/output/series/ep2/v4/pick_s4.png ] && [ -f "$COMFY_HOME"/output/series/ep2/v4/pick_s5.png ] && [ -f "$COMFY_HOME"/output/series/ep2/v4/pick_s7.png ]; do sleep 60; done
for k in 3 4 5 7 9; do clip ep2_v4.py "$k"; done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_v4.py join" 2>&1 | tr -d '\r' | tail -1 >> "$LOG"
mix /data/output/series/ep2/ep2_arcane_14b_v4.mp4
echo "all done $(date +%H:%M)" >> "$LOG"
