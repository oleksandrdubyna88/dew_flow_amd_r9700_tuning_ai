#!/usr/bin/env bash
# The owner (2026-11-09): "re-render episodes 1 and 2 with this face" (the approved test ep2_v4_test_shots124).
#  1. Arcane episode 2 v4: clips 3 5 6 7 9 (shot 4 = the approved test; v3 shots 1-2 and the old shot 8 stay), join,
#     VoxCPM narration with the moving ending;
#  2. Arcane episode 1: round-7 keyframes (young_face.py keys7) -> MY picks (young/pick_s1..6.png) -> clips 1-6, join,
#     the three narrations (VoxCPM storyteller, VoxCPM woman, Qwen woman) with the moving ending;
#  3. the realistic episode 2: clips 2-9 (clip 1 done), join, mix.
# One clip per freshly started ComfyUI (--fast-disk --disable-pinned-memory, VM 20 GB). Logs to young_run.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/young_run.log"; R="$COMFY_HOME_WIN"; Y1="$COMFY_HOME"/output/series/elf_set2_arcane/young
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do
    pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0
    sleep 5
  done
  echo "restart: not ready after 300 s" >> "$LOG"; return 1
}
clip() {  # $1 = driver + args before the shot number, $2 = shot
  for try in 1 2; do
    restart || return 1
    out="$(pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/$1 $2" 2>&1 | tr -d '\r')"
    echo "$out" | grep -E "shot|out of memory|Error" | head -3 >> "$LOG"
    echo "$out" | grep -qE "shot $2: clip" && return 0
    echo "$1 $2: try $try failed" >> "$LOG"
  done
}
mix() {  # $1 = film, $2 = narration prefix
  pwsh.exe -NoProfile -Command "wslc run --rm --name comfyui-mix -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/voiceover.py $1 $2 --shot 5.0625 --end slowmo" 2>&1 | tr -d '\r' | grep -E "ending|audio ok|written|bad|rror" >> "$LOG"
}
echo "start $(date +%H:%M)" >> "$LOG"
for k in 3 5 6 7 9; do clip "ep2_v4.py shot" "$k"; done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_v4.py join" 2>&1 | tr -d '\r' | tail -1 >> "$LOG"
mix /data/output/series/ep2/ep2_arcane_14b_v4.mp4 ep2/vox
echo "EP2 DONE $(date +%H:%M)" >> "$LOG"
restart && pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/young_face.py keys7" 2>&1 | tr -d '\r' | grep -E "shot|rror" >> "$LOG"
echo "ep1 keys ready $(date +%H:%M)" >> "$LOG"
until [ -f "$Y1/pick_s1.png" ] && [ -f "$Y1/pick_s2.png" ] && [ -f "$Y1/pick_s3.png" ] && [ -f "$Y1/pick_s4.png" ] && [ -f "$Y1/pick_s5.png" ] && [ -f "$Y1/pick_s6.png" ]; do sleep 60; done
for k in 1 2 3 4 5 6; do clip "young_face.py shot ep1" "$k"; done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/young_face.py join ep1" 2>&1 | tr -d '\r' | tail -1 >> "$LOG"
F=/data/output/series/elf_set2_arcane/elf_set2_arcane_14b_30s_young.mp4
mix $F tune/vox_t10; mix $F woman/ep1; mix $F woman_qwen/woman_qwen
echo "EP1 DONE $(date +%H:%M) (the woman/ep1 mix is named _vo_ep1_slowmo)" >> "$LOG"
for k in 2 3 4 5 6 7 8 9; do clip "ep2_real.py shot" "$k"; done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_real.py join" 2>&1 | tr -d '\r' | tail -1 >> "$LOG"
mix /data/output/series/ep2_real/ep2_real_14b.mp4 ep2/vox
echo "all done $(date +%H:%M)" >> "$LOG"
