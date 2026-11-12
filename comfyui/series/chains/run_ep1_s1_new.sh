#!/usr/bin/env bash
# Painted ep1 v3, scene 1 again (the owner 2026-11-12: picked "r2 0.75" = s1face/full/s1_r2_a75.png, the adult face with
# the ep3 s19 reference). Clip label "f" (same seed 3901 as the first s1 clip) -> FILM 32 fps -> ep1_edit.py with
# EP1_CHOICE=1:f -> ep1_v3_v2.mp4 (v1 stays). A fresh server, own guard. Logs to ep1_s1_new.log ("S1NEW DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep1_s1_new.log"; STOPF="$DIR/.guard_off_s1new"
V=/data/output/series/elf_set2_arcane/v3; P=series/elf_set2_arcane/v3/film; O="$COMFY_HOME"/output/series/elf_set2_arcane/v3
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
job() { pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c '$1'" 2>&1 | tr -d '\r' | grep -E "ep1 v3|film |rror|out of memory" | head -20 >> "$LOG"; }
guarded() { [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; return 1; }; return 0; }
echo "s1 new start $(date +%H:%M)" >> "$LOG"
ls $O/clip_s1f_0*.mp4 > /dev/null 2>&1 || { restart && job "EP1_PICK=$V/s1face/full/s1_r2_a75.png python /opt/tests/ep1_v3.py shot 1 - f"; guarded || exit 0; }
ls $O/clip_s1f_0*.mp4 > /dev/null 2>&1 || { echo "S1NEW FAILED $(date +%H:%M): no clip" >> "$LOG"; exit 1; }
ls $O/film/clip_s1f_32fps_*.mp4 > /dev/null 2>&1 || { restart && job "python /opt/tests/ep3_film.py file $V/clip_s1f_00001_.mp4 $P/clip_s1f_32fps"; guarded || exit 0; }
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name kep1s1 -e EP1_CHOICE=1:f -v '$COMFY_HOME_WIN\output:/data/output' -v '$COMFY_HOME_WIN\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/ep1_edit.py --out v2" 2>&1 | tr -d '\r' | grep -E "picture|done|missing|rror|Trace" >> "$LOG"
[ -f $O/ep1_v3_v2.mp4 ] && echo "S1NEW DONE $(date +%H:%M)" >> "$LOG" || echo "S1NEW FAILED $(date +%H:%M): no ep1_v3_v2.mp4" >> "$LOG"
