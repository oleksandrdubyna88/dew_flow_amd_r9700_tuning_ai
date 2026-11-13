#!/usr/bin/env bash
# 360 arm fix (the owner 2026-11-12 ~19:40 approved the agent's proposal): half 2 as v2v with 17 context frames
# (ORBIT_CTX=17, length 97, ~1 s of half-1 motion) + an arm phrase ("her arms stay held out to her sides as the camera
# circles, and lower slowly only near the end") + the direction words; half 1 unchanged (flux2: h1b). 2 seeds per model
# (tags ab, ac; new files). FILM, concat with the half-1 FILM file, cut 2*17-1 = 33 FILM frames ->
# series/all360/<m>/orbit_360_v2v<t>.mp4 + 2 fps sheet, copies in series/all360/armfix_6/. Waits for the HiDream /
# Hunyuan base tests ("^NEWBASE DONE", one GPU job at a time). Own RAM guard. Log all360_armfix.log ("ARMFIX DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/all360_armfix.log"; STOPF="$DIR/.guard_off_armfix"; R="$COMFY_HOME_WIN"
A=/data/output/series/all360; O="$COMFY_HOME"/output/series/all360
EXTRA="The camera continues in the same direction as in the first half, still moving to the right, and passes her other side. Her head, shoulders and body turn together naturally. Her arms stay held out to her sides as the camera circles, and lower slowly only near the end."
# 20:06 FIX: the first start matched the OLD "NEWBASE DONE 18:24" line, started at once and its restart stopped ComfyUI
# in the middle of the HiDream base test (1 of 5 pictures done). Now: wait for a NEW "NEWBASE DONE" line (count > 1),
# then finish the HiDream base test (run() skips done pictures) + its sheet, then the arm fix.
echo "armfix waiting for the 2nd NEWBASE DONE $(date +%H:%M)" >> "$LOG"
until [ "$(grep -c "^NEWBASE DONE" "$DIR/newmodel.log")" -ge 2 ]; do sleep 30; done
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
guarded() { [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; return 1; }; return 0; }
ff() { pwsh.exe -NoProfile -Command "wslc run --rm --name a360af -v '$R\output:/data/output' --entrypoint ffmpeg comfyui-r9700:local -v error -threads 2 -n $1" 2>&1 | tr -d '\r' | head -5 >> "$LOG"; }
echo "hidream base rest $(date +%H:%M)" >> "$DIR/newmodel.log"
restart && pwsh.exe -NoProfile -Command "wslc exec -e SHE3_STRENGTHS=0.0 comfyui sh -c 'python /opt/tests/newmodel_check.py run hidream'" 2>&1 | tr -d '\r' | grep -E "newmodel|rror|Trace|out of memory" | head -20 >> "$DIR/newmodel.log"
guarded || exit 0
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name nm-sheet2 -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/newmodel_check.py sheet hidream" 2>&1 | tr -d '\r' | tail -3 >> "$DIR/newmodel.log"
echo "HIDREAM REST DONE $(date +%H:%M)" >> "$DIR/newmodel.log"
echo "armfix start $(date +%H:%M)" >> "$LOG"
for m in sdxl flux2k9 flux2; do
  H1=""; [ $m = flux2 ] && H1=b
  for ts in ab:4582 ac:4592; do
    t=${ts%%:*}; s=${ts##*:}; d=$A/$m; o=$O/$m
    if ! ls $o/orbit_h2v${t}_*.mp4 > /dev/null 2>&1; then
      restart && pwsh.exe -NoProfile -Command "wslc exec -e ORBIT_CTX=17 -e ORBIT_SEED=$s -e ORBIT_TAG=$t -e ORBIT_H1=$H1 -e 'ORBIT_EXTRA=$EXTRA' comfyui sh -c 'python /opt/tests/all360.py v2v $m'" 2>&1 | tr -d '\r' | grep -E "all360|rror|out of memory|Trace" | head -10 >> "$LOG"
      guarded || exit 0
    fi
    ls $o/orbit_h2v${t}_*.mp4 > /dev/null 2>&1 || { echo "$m $t FAILED: no half 2" >> "$LOG"; continue; }
    restart && pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/ep3_film.py file $d/orbit_h2v${t}_00001_.mp4 series/all360/$m/film/orbit_h2v${t}_32fps'" 2>&1 | tr -d '\r' | grep -E "film |rror|Trace" | head -5 >> "$LOG"
    guarded || exit 0
    pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
    ff "-i $d/film/orbit_h1${H1}_32fps_00001_.mp4 -i $d/film/orbit_h2v${t}_32fps_00001_.mp4 -filter_complex '[1:v]trim=start_frame=33,setpts=PTS-STARTPTS[b];[0:v][b]concat=n=2:v=1[v]' -map '[v]' -c:v libx264 -crf 17 -pix_fmt yuv420p $d/orbit_360_v2v${t}.mp4"
    ff "-i $d/orbit_360_v2v${t}.mp4 -vf fps=2,scale=320:-2,tile=5x4 -frames:v 1 $d/orbit_360_v2v${t}_frames.jpg"
    pwsh.exe -NoProfile -Command "wslc run --rm --name a360afc -v '$R\output:/data/output' --entrypoint sh comfyui-r9700:local -c 'mkdir -p $A/armfix_6; cp -n $d/orbit_360_v2v${t}.mp4 $A/armfix_6/${m}_${t}.mp4; cp -n $d/orbit_360_v2v${t}_frames.jpg $A/armfix_6/${m}_${t}_frames.jpg'" > /dev/null 2>&1
    [ -f $O/armfix_6/${m}_${t}.mp4 ] && echo "$m $t ARMFIX OK $(date +%H:%M)" >> "$LOG" || echo "$m $t ARMFIX FAILED $(date +%H:%M)" >> "$LOG"
  done
done
echo "ARMFIX DONE $(date +%H:%M)" >> "$LOG"
