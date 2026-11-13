#!/usr/bin/env bash
# 360 joint fix 2 (the owner 2026-11-12 ~18:42: "flux2 the same: redo so it is right, no face moving into the back of her head"): flux2 (4B) half 2 as v2v from half 1 b (ORBIT_H1=b; the owner liked flux2_b), 2 seeds (vb, vc). Waits for "^V2VFIX DONE" (one GPU job at a time).
# sdxl b/c "her face turns into the back of her head at the joint, but the picture is good"). Half 2 again as v2v (the
# last 9 frames of half 1 as start frames: the motion continues over the joint) + the reroll's direction words, 2 seeds
# (tags vb, vc; new files). FILM, concat with the half-1 FILM file (the first 17 FILM frames = context cut) ->
# series/all360/<m>/orbit_360_v2v<t>.mp4 + 2 fps sheet, copies in series/all360/v2vfix_4/. Log all360_v2vfix.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/all360_v2vfix.log"; STOPF="$DIR/.guard_off_v2vfix2"; R="$COMFY_HOME_WIN"
A=/data/output/series/all360; O="$COMFY_HOME"/output/series/all360
EXTRA="The camera continues in the same direction as in the first half, still moving to the right, and passes her other side. Her head, shoulders and body turn together naturally."
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
ff() { pwsh.exe -NoProfile -Command "wslc run --rm --name a360vf -v '$R\output:/data/output' --entrypoint ffmpeg comfyui-r9700:local -v error -threads 2 -n $1" 2>&1 | tr -d '\r' | head -5 >> "$LOG"; }
until grep -q "^V2VFIX DONE" "$LOG"; do sleep 30; done
echo "v2vfix2 start $(date +%H:%M)" >> "$LOG"
for m in flux2; do
  for ts in vb:4562 vc:4572; do
    t=${ts%%:*}; s=${ts##*:}; d=$A/$m; o=$O/$m
    if ! ls $o/orbit_h2v${t}_*.mp4 > /dev/null 2>&1; then
      restart && pwsh.exe -NoProfile -Command "wslc exec -e ORBIT_SEED=$s -e ORBIT_TAG=$t -e ORBIT_H1=b -e 'ORBIT_EXTRA=$EXTRA' comfyui sh -c 'python /opt/tests/all360.py v2v $m'" 2>&1 | tr -d '\r' | grep -E "all360|rror|out of memory|Trace" | head -10 >> "$LOG"
      guarded || exit 0
    fi
    ls $o/orbit_h2v${t}_*.mp4 > /dev/null 2>&1 || { echo "$m $t FAILED: no half 2" >> "$LOG"; continue; }
    restart && pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/ep3_film.py file $d/orbit_h2v${t}_00001_.mp4 series/all360/$m/film/orbit_h2v${t}_32fps'" 2>&1 | tr -d '\r' | grep -E "film |rror|Trace" | head -5 >> "$LOG"
    guarded || exit 0
    pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
    ff "-i $d/film/orbit_h1b_32fps_00001_.mp4 -i $d/film/orbit_h2v${t}_32fps_00001_.mp4 -filter_complex '[1:v]trim=start_frame=17,setpts=PTS-STARTPTS[b];[0:v][b]concat=n=2:v=1[v]' -map '[v]' -c:v libx264 -crf 17 -pix_fmt yuv420p $d/orbit_360_v2v${t}.mp4"
    ff "-i $d/orbit_360_v2v${t}.mp4 -vf fps=2,scale=320:-2,tile=5x4 -frames:v 1 $d/orbit_360_v2v${t}_frames.jpg"
    pwsh.exe -NoProfile -Command "wslc run --rm --name a360vfc -v '$R\output:/data/output' --entrypoint sh comfyui-r9700:local -c 'mkdir -p $A/v2vfix_4; cp -n $d/orbit_360_v2v${t}.mp4 $A/v2vfix_4/${m}_${t}.mp4; cp -n $d/orbit_360_v2v${t}_frames.jpg $A/v2vfix_4/${m}_${t}_frames.jpg'" > /dev/null 2>&1
    [ -f $O/v2vfix_4/${m}_${t}.mp4 ] && echo "$m $t V2VFIX OK $(date +%H:%M)" >> "$LOG" || echo "$m $t V2VFIX FAILED $(date +%H:%M)" >> "$LOG"
  done
done
echo "V2VFIX2 DONE $(date +%H:%M)" >> "$LOG"
