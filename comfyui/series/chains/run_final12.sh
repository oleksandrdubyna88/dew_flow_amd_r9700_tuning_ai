#!/usr/bin/env bash
# The owner's choices (2026-11-10): eyes = the new seeds everywhere; realistic shot 7 must get in behind the WHEEL (new
# front-view keyframe c12). Realistic shot 7 again (reroll -> reroll_s7), realistic join (prefers reroll_s2/6/7) + mix;
# episode 1 join (prefers eyetest_A) + the three narrations. Logs to final12.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/final12.log"; R="$COMFY_HOME_WIN"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break; sleep 5; done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_real.py reroll 7" 2>&1 | tr -d '\r' | grep -E "real shot|rror" >> "$LOG"
mix() { pwsh.exe -NoProfile -Command "wslc run --rm --name comfyui-mix -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/voiceover.py $1 $2 --shot 5.0625 --end slowmo" 2>&1 | tr -d '\r' | grep -E "ending|audio ok|written|bad|rror" >> "$LOG"; }
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_real.py join" 2>&1 | tr -d '\r' | tail -1 >> "$LOG"
mix /data/output/series/ep2_real/ep2_real_14b.mp4 ep2/vox
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/young_face.py join ep1" 2>&1 | tr -d '\r' | tail -1 >> "$LOG"
F=/data/output/series/elf_set2_arcane/elf_set2_arcane_14b_30s_young.mp4
mix $F tune/vox_t10; mix $F woman/ep1; mix $F woman_qwen/woman_qwen
echo "FINAL12 DONE $(date +%H:%M)" >> "$LOG"
