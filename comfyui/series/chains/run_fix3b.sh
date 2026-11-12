#!/usr/bin/env bash
# Shot 3 again (the owner: the eyes twitch). run_fix3.sh did not re-render: its `mv` of the root-owned clip failed from WSL,
# so the driver saw "clip exists". Here the old clip is moved INSIDE a container. After FIX6 DONE; then ep2 join + mix,
# then my ep1 picks (which let run_young.sh start the ep1 clips). Logs to young_run.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/young_run.log"; R="$COMFY_HOME_WIN"
until grep -q "FIX6 DONE" "$LOG" 2>/dev/null; do sleep 30; done
pwsh.exe -NoProfile -Command "wslc exec comfyui mv /data/output/series/ep2/v4/clip_s3_00001_.mp4 /data/output/series/ep2/v4/blink_clip_s3_00001_.mp4" 2>&1 | tr -d '\r' | sed 's/^/fix3b: /' >> "$LOG"
[ -f "$COMFY_HOME"/output/series/ep2/v4/blink_clip_s3_00001_.mp4 ] && echo "fix3b: old clip 3 -> blink_clip_s3_00001_.mp4" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
for i in $(seq 1 60); do
  pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break
  sleep 5
done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_v4.py shot 3" 2>&1 | tr -d '\r' | grep -E "shot|out of memory|Error" | sed 's/^/fix3b: /' >> "$LOG"
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_v4.py join" 2>&1 | tr -d '\r' | tail -1 | sed 's/^/fix3b: /' >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name comfyui-mix -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/voiceover.py /data/output/series/ep2/ep2_arcane_14b_v4.mp4 ep2/vox --shot 5.0625 --end slowmo" 2>&1 | tr -d '\r' | grep -E "ending|audio ok|written|bad|rror" | sed 's/^/fix3b: /' >> "$LOG"
echo "FIX3B DONE $(date +%H:%M)" >> "$LOG"
for kn in "1 51" "2 51" "3 52" "4 52" "5 52" "6 51"; do
  pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/young_face.py pick ep1 $kn" 2>&1 | tr -d '\r' >> "$LOG"
done
