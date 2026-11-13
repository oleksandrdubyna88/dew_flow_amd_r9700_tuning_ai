#!/usr/bin/env bash
# 360 version 2 "v2v" (the owner 2026-11-12 15:40: "all 360 videos in 2 versions: one as now, the second via v2v so it
# joins"). Starts after run_all360_orbits.sh writes "ORBITS DONE" (one GPU job at a time; waits on the LOG LINE, not
# pgrep). For each of the six 360s: half 2 again with the last 9 frames of half 1 as start frames (all360.py v2v), a
# fresh server before each clip (rule), FILM 32 fps, concat with the existing half-1 FILM file (the first 17 FILM frames
# of half 2 = the 9 context frames are cut) -> series/all360/<key>/orbit_360_v2v.mp4 + orbit_360_v2v_frames.jpg; then
# compare_360_v2v.mp4 (3x2, the same order as compare_360.mp4). Own RAM guard. Log all360_v2v.log ("V2V DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/all360_v2v.log"; STOPF="$DIR/.guard_off_all360v2v"; R="$COMFY_HOME_WIN"
A=/data/output/series/all360; O="$COMFY_HOME"/output/series/all360; T="$COMFY_HOME"/tests
WAIT="${WAIT_TAG:-ORBITS DONE}"; CMP="${CMP_NAME:-compare_360_v2v}"; END="${V2V_TAG:-V2V DONE}"
echo "v2v waiting for $WAIT $(date +%H:%M)" >> "$LOG"
until grep -q "^$WAIT" "$DIR/all360.log"; do sleep 30; done
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
job() { pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c '$1'" 2>&1 | tr -d '\r' | grep -E "all360|film |rror|out of memory|Trace" | head -20 >> "$LOG"; }
guarded() { [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; return 1; }; return 0; }
ff() { pwsh.exe -NoProfile -Command "wslc run --rm --name a360v2v -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint ffmpeg comfyui-r9700:local -v error -threads 2 -n $1" 2>&1 | tr -d '\r' | head -5 >> "$LOG"; }
echo "v2v start $(date +%H:%M)" >> "$LOG"
for m in qwen flux2 sdxl flux2k9 real2 arc; do
  case $m in
    arc)   H1F=/data/output/series/arc360/film/orbit_h1_32fps_00001_.mp4 ;;
    real2) H1F=/data/output/series/real2check/film/orbit_h1_32fps_00001_.mp4 ;;
    *)     H1F=$A/$m/film/orbit_h1_32fps_00001_.mp4 ;;
  esac
  [ -f "$COMFY_HOME/output${H1F#/data/output}" ] || { echo "$m SKIP: no half-1 FILM file" >> "$LOG"; continue; }
  d=$A/$m; o=$O/$m
  [ -f $o/orbit_360_v2v.mp4 ] && { echo "$m v2v already done" >> "$LOG"; continue; }
  echo "$m v2v start $(date +%H:%M)" >> "$LOG"
  ls $o/orbit_h2v_*.mp4 > /dev/null 2>&1 || { restart && job "python /opt/tests/all360.py v2v $m"; guarded || exit 0; }
  ls $o/orbit_h2v_*.mp4 > /dev/null 2>&1 || { echo "$m V2V FAILED: no half 2" >> "$LOG"; continue; }
  restart && job "python /opt/tests/ep3_film.py file $d/orbit_h2v_00001_.mp4 series/all360/$m/film/orbit_h2v_32fps"; guarded || exit 0
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
  ff "-i $H1F -i $d/film/orbit_h2v_32fps_00001_.mp4 -filter_complex '[1:v]trim=start_frame=17,setpts=PTS-STARTPTS[b];[0:v][b]concat=n=2:v=1[v]' -map '[v]' -c:v libx264 -crf 17 -pix_fmt yuv420p $d/orbit_360_v2v.mp4"
  ff "-i $d/orbit_360_v2v.mp4 -vf fps=1,scale=384:-2,tile=5x2 -frames:v 1 $d/orbit_360_v2v_frames.jpg"
  [ -f $o/orbit_360_v2v.mp4 ] && echo "$m V2V DONE $(date +%H:%M)" >> "$LOG" || echo "$m V2V FAILED $(date +%H:%M)" >> "$LOG"
done
# compare: 3x2, tile 640x352, the same order as compare_360.mp4: painted v1 | realistic v2 | qwen v3 / flux2 | sdxl | flux2k9
IN=""; F=""; i=0
for m in arc real2 qwen flux2 sdxl flux2k9; do
  if [ -f $O/$m/orbit_360_v2v.mp4 ]; then IN="$IN -i $A/$m/orbit_360_v2v.mp4"; F="$F[$i:v]fps=32,scale=640:352,setsar=1,trim=duration=10,setpts=PTS-STARTPTS[t$i];"; i=$((i+1))
  fi
done
n=$i
while [ $i -lt 6 ]; do F="${F}color=black:s=640x352:r=32:d=10[t$i];"; i=$((i+1)); done
F="$F[t0][t1][t2][t3][t4][t5]xstack=inputs=6:layout=0_0|640_0|1280_0|0_352|640_352|1280_352[v]"
printf '%s' "$F" > $T/all360_v2v_compare_filter.txt
[ $n -gt 0 ] && ff "$IN -filter_complex_script /opt/tests/all360_v2v_compare_filter.txt -map [v] -c:v libx264 -crf 20 -pix_fmt yuv420p $A/$CMP.mp4"
[ -f $O/$CMP.mp4 ] && echo "compare v2v ok $CMP ($n of 6)" >> "$LOG"
echo "$END $(date +%H:%M)" >> "$LOG"
