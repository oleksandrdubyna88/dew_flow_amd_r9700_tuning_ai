#!/usr/bin/env bash
# 360 half-2 rerolls (the owner 2026-11-12 ~17:12): sdxl "beautiful, but she twisted her neck, regenerate" (half 2 at
# ~8 s: the head turns to the camera while the body still faces away); flux2k9 "good, but she turns 180 and back, not
# 360" (half 2: the camera goes back the same way). Half 1 stays. Per model 2 seeds (tags b, c; new file names) with
# extra POSITIVE motion words: the camera keeps the first half's direction and passes her other side; head, shoulders
# and body turn together. Then FILM + concat -> series/all360/<m>/orbit_360_<tag>.mp4 + _frames.jpg.
# Waits for the 360 chain ("^REST DONE"), then starts run_newmodel_base.sh (it waits for "^REROLL DONE").
# Own RAM guard, fresh server before each clip (rule). Log all360_reroll.log ("REROLL DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/all360_reroll.log"; STOPF="$DIR/.guard_off_reroll"; R="$COMFY_HOME_WIN"
A=/data/output/series/all360; O="$COMFY_HOME"/output/series/all360
# 17:20 the owner: flux2 has the same problem ("all except qwen must be regenerated so she turns steadily through 360");
# flux2 half 1 never reaches her back -> flux2 rerolls BOTH halves (h1<t> then h2f<t> from it, ORBIT_H1=<t>)
EXTRA1="The camera travels a full half circle around her, so at the end we see her back and her long silver hair."
EXTRA="The camera continues in the same direction as in the first half, still moving to the right, and passes her other side. Her head, shoulders and body turn together naturally."
# run_newmodel_base.sh was started by the first copy of this script (17:12) and waits for "^REROLL DONE"
echo "reroll waiting for REST DONE $(date +%H:%M)" >> "$LOG"
until grep -q "^REST DONE" "$DIR/all360_v2v.log"; do sleep 30; done
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
ff() { pwsh.exe -NoProfile -Command "wslc run --rm --name a360rr -v '$R\output:/data/output' --entrypoint ffmpeg comfyui-r9700:local -v error -threads 2 -n $1" 2>&1 | tr -d '\r' | head -5 >> "$LOG"; }
echo "reroll start $(date +%H:%M)" >> "$LOG"
for m in sdxl flux2k9 flux2; do
  for ts in b:4542 c:4552; do
    t=${ts%%:*}; s=${ts##*:}; d=$A/$m; o=$O/$m; H1=""
    if [ $m = flux2 ]; then
      H1=$t
      if ! ls $o/orbit_h1${t}_*.mp4 > /dev/null 2>&1; then
        restart && pwsh.exe -NoProfile -Command "wslc exec -e ORBIT_SEED=$((s - 1)) -e ORBIT_TAG=$t -e 'ORBIT_EXTRA=$EXTRA1' comfyui sh -c 'python /opt/tests/all360.py orbit $m 1'" 2>&1 | tr -d '\r' | grep -E "all360|rror|out of memory|Trace" | head -10 >> "$LOG"
        guarded || exit 0
      fi
      ls $o/orbit_h1${t}_*.mp4 > /dev/null 2>&1 || { echo "$m $t FAILED: no half 1" >> "$LOG"; continue; }
      restart && pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/ep3_film.py file $d/orbit_h1${t}_00001_.mp4 series/all360/$m/film/orbit_h1${t}_32fps'" 2>&1 | tr -d '\r' | grep -E "film |rror|Trace" | head -5 >> "$LOG"
      guarded || exit 0
    fi
    if ! ls $o/orbit_h2f${t}_*.mp4 > /dev/null 2>&1; then
      restart && pwsh.exe -NoProfile -Command "wslc exec -e ORBIT_SEED=$s -e ORBIT_TAG=$t -e ORBIT_H1=$H1 -e 'ORBIT_EXTRA=$EXTRA' comfyui sh -c 'python /opt/tests/all360.py orbit $m 2'" 2>&1 | tr -d '\r' | grep -E "all360|rror|out of memory|Trace" | head -10 >> "$LOG"
      guarded || exit 0
    fi
    ls $o/orbit_h2f${t}_*.mp4 > /dev/null 2>&1 || { echo "$m $t FAILED: no half 2" >> "$LOG"; continue; }
    restart && pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/ep3_film.py file $d/orbit_h2f${t}_00001_.mp4 series/all360/$m/film/orbit_h2f${t}_32fps'" 2>&1 | tr -d '\r' | grep -E "film |rror|Trace" | head -5 >> "$LOG"
    guarded || exit 0
    pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
    ff "-i $d/film/orbit_h1${H1}_32fps_00001_.mp4 -i $d/film/orbit_h2f${t}_32fps_00001_.mp4 -filter_complex '[1:v]trim=start_frame=2,setpts=PTS-STARTPTS[b];[0:v][b]concat=n=2:v=1[v]' -map '[v]' -c:v libx264 -crf 17 -pix_fmt yuv420p $d/orbit_360_${t}.mp4"
    ff "-i $d/orbit_360_${t}.mp4 -vf fps=2,scale=320:-2,tile=5x4 -frames:v 1 $d/orbit_360_${t}_frames.jpg"
    [ -f $o/orbit_360_${t}.mp4 ] && echo "$m $t REROLL OK $(date +%H:%M)" >> "$LOG" || echo "$m $t REROLL FAILED $(date +%H:%M)" >> "$LOG"
  done
done
echo "REROLL DONE $(date +%H:%M)" >> "$LOG"
