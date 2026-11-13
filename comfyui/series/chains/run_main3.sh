#!/usr/bin/env bash
# The owner (2026-11-09): "make ONE clip first, I confirm it is what is needed, then all". Order:
#  1. (done by run_main2) Arcane TEST clip shot 4 -> here: the preview -> "TEST READY" -> the wslc VM restart (20GB);
#     then round 5 keys (shots 3 5 6, body ref first) for my picks;
#  2. meanwhile the realistic episode 2: clips 2-9 (clip 1 done), join, VoxCPM mix -> "real done";
#  3. after the owner's OK (v4/APPROVED) and my picks of shots 3 5 6 (round 5): Arcane clips 3 5 6 7 9, join, mix.
# One clip per freshly started ComfyUI (--fast-disk --disable-pinned-memory). Logs to main.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/main.log"; R="$COMFY_HOME_WIN"; V4="$COMFY_HOME"/output/series/ep2/v4
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
echo "start (main3) $(date +%H:%M)" >> "$LOG"
E=/data/output/series/ep2
pwsh.exe -NoProfile -Command "wslc run --rm --name comfyui-mix -v '$R\output:/data/output' --entrypoint ffmpeg comfyui-r9700:local -y -loglevel error -i $E/v3/clip_s1_00001_.mp4 -i $E/v3/clip_s2_00001_.mp4 -i $E/v4/clip_s4_00001_.mp4 -filter_complex concat=n=3:v=1:a=0 -c:v libx264 -pix_fmt yuv420p -crf 18 -threads 2 -movflags +faststart $E/ep2_v4_test_shots124.mp4" 2>&1 | tr -d '\r' >> "$LOG"
echo "TEST READY $(date +%H:%M): series/ep2/ep2_v4_test_shots124.mp4 and v4/clip_s4_00001_.mp4" >> "$LOG"
# the owner (2026-11-09): the wslc VM memory limit 20GB (settings.yaml session.memorySize); the VM is torn down after 30 s
# without containers (idleTimeout) and starts again with the new limit; then the VM size is logged
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
for i in $(seq 1 36); do pwsh.exe -NoProfile -Command "Get-Process vmmemwslc* -ErrorAction SilentlyContinue" 2>/dev/null | grep -q vmmem || break; sleep 5; done
echo "wslc VM gone after ~$((i * 5)) s" >> "$LOG"
restart && pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c \"free -m | head -2\"" 2>&1 | tr -d '\r' >> "$LOG"
restart && pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_v4.py keyframes5" 2>&1 | tr -d '\r' | grep -E "^shot|rror" >> "$LOG"
echo "round-5 keys ready $(date +%H:%M)" >> "$LOG"
for k in 2 3 4 5 6 7 8 9; do clip ep2_real.py "$k"; done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_real.py join" 2>&1 | tr -d '\r' | tail -1 >> "$LOG"
mix /data/output/series/ep2_real/ep2_real_14b.mp4
echo "real done $(date +%H:%M)" >> "$LOG"
until [ -f "$V4/APPROVED" ] && [ -f "$V4/pick4_s3.png" ] && [ -f "$V4/pick4_s5.png" ] && [ -f "$V4/pick4_s6.png" ]; do sleep 60; done
for k in 3 5 6 7 9; do clip ep2_v4.py "$k"; done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_v4.py join" 2>&1 | tr -d '\r' | tail -1 >> "$LOG"
mix /data/output/series/ep2/ep2_arcane_14b_v4.mp4
echo "all done $(date +%H:%M)" >> "$LOG"
