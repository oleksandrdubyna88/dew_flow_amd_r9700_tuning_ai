#!/usr/bin/env bash
# Realistic 360 v2 (2026-11-12 00:40): v1 half 2 started from a back view and came back with another, rounder face and a
# changed tunic. v2 keeps half 1 and renders half 2 again with first-last frame (ORBIT_FLF=1, end = orbit_pick.png =
# the approved start picture) -> FILM -> real2check/orbit_360_v2.mp4 (v1 stays). Runs after the painted orbit.
# Logs to real2_orbit2.log ("ORBIT DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/real2_orbit2.log"; STOPF="$DIR/.guard_off_orbit2"; R="$COMFY_HOME_WIN"
D=/data/output/series/real2check; P=series/real2check/film; O="$COMFY_HOME"/output/series/real2check
echo "waiting for the painted orbit $(date +%H:%M)" >> "$LOG"
until grep -qE "ORBIT (DONE|FAILED)|guard stopped|ending" "$DIR/arc360_orbit.log" 2>/dev/null; do sleep 30; done
sleep 10
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
job() { pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c '$1'" 2>&1 | tr -d '\r' | grep -E "real2check|film |rror|out of memory|Trace" | head -20 >> "$LOG"; }
guarded() { [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; return 1; }; return 0; }
echo "orbit start $(date +%H:%M)" >> "$LOG"
restart || exit 1
[ -f $O/orbit_pick.png ] || job "cp -n $D/orbit_key06m_c2_00001_.png $D/orbit_pick.png"
ls $O/orbit_h1_*.mp4 > /dev/null 2>&1 || { job "python /opt/tests/real2_check.py orbit 1"; guarded || exit 0; }
ls $O/orbit_h1_*.mp4 > /dev/null 2>&1 || { echo "ORBIT FAILED $(date +%H:%M): no half 1" >> "$LOG"; exit 1; }
ls $O/orbit_h2f_*.mp4 > /dev/null 2>&1 || { restart && job "ORBIT_FLF=1 python /opt/tests/real2_check.py orbit 2"; guarded || exit 0; }
ls $O/orbit_h2f_*.mp4 > /dev/null 2>&1 || { echo "ORBIT FAILED $(date +%H:%M): no half 2" >> "$LOG"; exit 1; }
restart && job "python /opt/tests/ep3_film.py file $D/orbit_h2f_00001_.mp4 $P/orbit_h2f_32fps"; guarded || exit 0
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name orbcat2 -v '$R\output:/data/output' --entrypoint ffmpeg comfyui-r9700:local -v error -threads 2 -n -i $D/film/orbit_h1_32fps_00001_.mp4 -i $D/film/orbit_h2f_32fps_00001_.mp4 -filter_complex '[1:v]trim=start_frame=2,setpts=PTS-STARTPTS[b];[0:v][b]concat=n=2:v=1[v]' -map '[v]' -c:v libx264 -crf 17 -pix_fmt yuv420p $D/orbit_360_v2.mp4" 2>&1 | tr -d '\r' | head -5 >> "$LOG"
[ -f $O/orbit_360_v2.mp4 ] && echo "ORBIT DONE $(date +%H:%M)" >> "$LOG" || echo "ORBIT FAILED $(date +%H:%M): no orbit_360_v2.mp4" >> "$LOG"
