#!/usr/bin/env bash
# 360 on all LoRAs, step 2: for each line "<model> c<n>" in all360_picks.txt: key_c<n> -> orbit_pick.png, Wan 14B half 1,
# half 2 (first-last frame), a fresh server before each clip (rule), FILM 32 fps, concat (2 frames of half 2 cut) ->
# series/all360/<model>/orbit_360.mp4 + orbit_360_frames.jpg; at the end the 3x2 compare video of all six 360s
# (series/all360/compare_360.mp4). Own RAM guard. Logs to all360.log ("ORBITS DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/all360.log"; STOPF="$DIR/.guard_off_all360"; R="$COMFY_HOME_WIN"
A=/data/output/series/all360; O="$COMFY_HOME"/output/series/all360
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
ff() { pwsh.exe -NoProfile -Command "wslc run --rm --name a360ff -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint ffmpeg comfyui-r9700:local -v error -threads 2 -n $1" 2>&1 | tr -d '\r' | head -5 >> "$LOG"; }
TAG="${ORBITS_TAG:-ORBITS DONE}"; CMP="${CMP_NAME:-compare_360}"
echo "orbits start $(date +%H:%M)" >> "$LOG"
# fd 3: pwsh.exe inside the loop reads stdin and ate the rest of the picks file (2026-11-12 15:38: only qwen ran)
while read -r m c <&3; do
  [ -z "$m" ] && continue
  d=$A/$m; o=$O/$m
  [ -f $o/orbit_360.mp4 ] && { echo "$m already done" >> "$LOG"; continue; }
  echo "$m $c start $(date +%H:%M)" >> "$LOG"
  ls $o/orbit_h1_*.mp4 > /dev/null 2>&1 || { restart && job "python /opt/tests/all360.py orbit $m 1 $c"; guarded || exit 0; }
  ls $o/orbit_h1_*.mp4 > /dev/null 2>&1 || { echo "$m FAILED: no half 1" >> "$LOG"; continue; }
  ls $o/orbit_h2f_*.mp4 > /dev/null 2>&1 || { restart && job "python /opt/tests/all360.py orbit $m 2"; guarded || exit 0; }
  ls $o/orbit_h2f_*.mp4 > /dev/null 2>&1 || { echo "$m FAILED: no half 2" >> "$LOG"; continue; }
  restart && job "python /opt/tests/ep3_film.py file $d/orbit_h1_00001_.mp4 series/all360/$m/film/orbit_h1_32fps $d/orbit_h2f_00001_.mp4 series/all360/$m/film/orbit_h2f_32fps"; guarded || exit 0
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
  ff "-i $d/film/orbit_h1_32fps_00001_.mp4 -i $d/film/orbit_h2f_32fps_00001_.mp4 -filter_complex '[1:v]trim=start_frame=2,setpts=PTS-STARTPTS[b];[0:v][b]concat=n=2:v=1[v]' -map '[v]' -c:v libx264 -crf 17 -pix_fmt yuv420p $d/orbit_360.mp4"
  ff "-i $d/orbit_360.mp4 -vf fps=1,scale=384:-2,tile=5x2 -frames:v 1 $d/orbit_360_frames.jpg"
  [ -f $o/orbit_360.mp4 ] && echo "$m ORBIT DONE $(date +%H:%M)" >> "$LOG" || echo "$m ORBIT FAILED $(date +%H:%M)" >> "$LOG"
done 3< "$DIR/all360_picks.txt"
# compare: 3x2 grid, each tile 640x352, no text (order in compare_360_order.txt):
# painted v1 | realistic v2 | qwen v3 / flux2 v3 | sdxl v3 | flux2k9 v3 (black tile if missing). The filter goes in a file
# (-filter_complex_script) so no quotes cross pwsh.
V=(/data/output/series/arc360/orbit_360_v1.mp4 /data/output/series/real2check/orbit_360_v2.mp4)
N=("painted slvra_v1" "realistic slvrareal2_tunic 0.6")
for m in qwen flux2 sdxl flux2k9; do [ -f $O/$m/orbit_360.mp4 ] && { V+=($A/$m/orbit_360.mp4); N+=("$m v3"); }; done
IN=""; F=""; i=0
for v in "${V[@]}"; do IN="$IN -i $v"; F="$F[$i:v]fps=32,scale=640:352,setsar=1,trim=duration=10,setpts=PTS-STARTPTS[t$i];"; i=$((i+1)); done
while [ $i -lt 6 ]; do F="${F}color=black:s=640x352:r=32:d=10[t$i];"; i=$((i+1)); done
F="$F[t0][t1][t2][t3][t4][t5]xstack=inputs=6:layout=0_0|640_0|1280_0|0_352|640_352|1280_352[v]"
T="$COMFY_HOME"/tests
printf '%s' "$F" > $T/all360_compare_filter.txt
printf '%s\n' "top row: ${N[0]} | ${N[1]} | ${N[2]:-empty}" "bottom row: ${N[3]:-empty} | ${N[4]:-empty} | ${N[5]:-empty}" > $T/all360_compare_order.txt
ff "$IN -filter_complex_script /opt/tests/all360_compare_filter.txt -map [v] -c:v libx264 -crf 20 -pix_fmt yuv420p $A/$CMP.mp4"
[ -f $O/$CMP.mp4 ] && echo "compare ok $CMP" >> "$LOG"
echo "$TAG $(date +%H:%M)" >> "$LOG"
