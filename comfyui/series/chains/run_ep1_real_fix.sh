#!/usr/bin/env bash
# Episode 1 realistic fix (2026-11-11, the owner): (1) the face test lora_face_real_test.py — the chosen slvra_v1
# face (0.7, also 0.5) in the photo style, slvrareal 1.0 for comparison; (2) s6 re-roll "b" (she stays kneeling; the
# first clip folded her body backwards) -> FILM -> the edit with EP1_CHOICE=6:b -> ep1_v3_real_v2.mp4. DONE lines only
# when the file exists.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep1_real.log"; STOPF="$DIR/.guard_off_ep1rf"
R="$COMFY_HOME_WIN"; O="$COMFY_HOME"/output/series/elf_real/ep1; V=/data/output/series/elf_real/ep1
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
box() {  # $1 = entrypoint, rest = args: a one-off container with output + tests
  local ep="$1"; shift
  pwsh.exe -NoProfile -Command "wslc run --rm --name kep1r -e EP1_DIR=$V -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' -e EP1_CHOICE=6:b --entrypoint $ep comfyui-r9700:local $*" 2>&1 | tr -d '\r'
}
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
job() { pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c '$1'" 2>&1 | tr -d '\r' | grep -E "ep1 real|realface|film |rror|out of memory|Trace" | head -20 >> "$LOG"; }
guarded() { [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; return 1; }; return 0; }
echo "ep1 real fix start $(date +%H:%M)" >> "$LOG"
restart && job "python /opt/tests/lora_face_real_test.py"; guarded || exit 0
echo "FACE TEST DONE $(date +%H:%M)" >> "$LOG"
restart && job "python /opt/tests/ep1_real.py shot 6 b"; guarded || exit 0
ls $O/clip_s6b_0*.mp4 > /dev/null 2>&1 || { echo "CLIP s6b FAILED $(date +%H:%M)" >> "$LOG"; exit 1; }
restart && job "python /opt/tests/ep3_film.py file $V/clip_s6b_00001_.mp4 series/elf_real/ep1/film/clip_s6b_32fps"; guarded || exit 0
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
ls $O/film/clip_s6b_32fps_*.mp4 > /dev/null 2>&1 || { echo "FILM s6b FAILED" >> "$LOG"; exit 1; }
box python3 /opt/tests/ep1_edit.py --out real_v2 >> "$LOG"
if [ -s "$O/ep1_v3_real_v2.mp4" ]; then echo "EP1 REAL V2 DONE $(date +%H:%M)" >> "$LOG"; else echo "EP1 REAL V2 EDIT FAILED $(date +%H:%M)" >> "$LOG"; fi
