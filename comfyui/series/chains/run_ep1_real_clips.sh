#!/usr/bin/env bash
# Episode 1 realistic, step 3 (2026-11-11): picks (chosen by eye from keys_sheet.png: s1 c1, s2 c3 = plain silhouette,
# s3 c1, s4 c2, s5 c1, s6 c2; s5 c2 had two women) -> pick_s<k>.png (copied IN a container, the folder is root-owned)
# -> one Wan 2.2 14B clip per fresh server (MIOpen on) -> FILM x2 of all 6 -> the episode 1 v3 edit and sound
# (ep1_edit.py with EP1_DIR) -> series/elf_real/ep1/ep1_v3_real.mp4. Own guard stop file, killed on exit.
# Each DONE line is written only when its file exists (the false-DONE lesson, §34).
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep1_real.log"; STOPF="$DIR/.guard_off_ep1rc"
R="$COMFY_HOME_WIN"; O="$COMFY_HOME"/output/series/elf_real/ep1; V=/data/output/series/elf_real/ep1
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
box() {  # $1 = entrypoint, rest = args: a one-off container with output + tests
  local ep="$1"; shift
  pwsh.exe -NoProfile -Command "wslc run --rm --name kep1r -e EP1_DIR=$V -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint $ep comfyui-r9700:local $*" 2>&1 | tr -d '\r'
}
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
job() { pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c '$1'" 2>&1 | tr -d '\r' | grep -E "ep1 real|film |rror|out of memory|Trace" | head -20 >> "$LOG"; }
guarded() { [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; return 1; }; return 0; }
echo "ep1 real clips start $(date +%H:%M)" >> "$LOG"
box sh -c "'cd $V && cp key_s1_c1_00001_.png pick_s1.png && cp key_s2_c3_00001_.png pick_s2.png && cp key_s3_c1_00001_.png pick_s3.png && cp key_s4_c2_00001_.png pick_s4.png && cp key_s5_c1_00001_.png pick_s5.png && cp key_s6_c2_00001_.png pick_s6.png'" >> "$LOG"
for k in 1 2 3 4 5 6; do [ -s "$O/pick_s$k.png" ] || { echo "PICKS FAILED (pick_s$k missing)" >> "$LOG"; exit 1; }; done
for k in 1 2 3 4 5 6; do
  ls $O/clip_s${k}_0*.mp4 > /dev/null 2>&1 && continue
  restart && job "python /opt/tests/ep1_real.py shot $k"; guarded || exit 0
  ls $O/clip_s${k}_0*.mp4 > /dev/null 2>&1 || { echo "CLIP s$k FAILED $(date +%H:%M)" >> "$LOG"; exit 1; }
done
echo "CLIPS DONE $(date +%H:%M)" >> "$LOG"
F=""; for k in 1 2 3 4 5 6; do F="$F $V/clip_s${k}_00001_.mp4 series/elf_real/ep1/film/clip_s${k}_32fps"; done
restart && job "python /opt/tests/ep3_film.py file$F"; guarded || exit 0
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
n=$(ls $O/film/clip_s*_32fps_*.mp4 2>/dev/null | wc -l); echo "FILM files: $n of 6 $(date +%H:%M)" >> "$LOG"
box python3 /opt/tests/ep1_edit.py --out real >> "$LOG"
if [ -s "$O/ep1_v3_real.mp4" ]; then echo "EP1 REAL DONE $(date +%H:%M)" >> "$LOG"; else echo "EP1 REAL EDIT FAILED $(date +%H:%M)" >> "$LOG"; fi
