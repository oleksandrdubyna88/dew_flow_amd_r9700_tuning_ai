#!/usr/bin/env bash
# Painted ep1 v3 scene 1 face, ADULT ref (the owner 18:25 rejected the young ref; 18:35 "ep3 60-65 s is ideal" = s19): tests/ep1_s1_face.py run (crop-enlarged face repaint of
# pick_s1.png, 2 seeds x denoise 0.75/0.85) then the sheets v3/S1_FACE_compare.jpg + S1_FACE_frames.jpg. Own RAM guard.
# Logs to ep1_s1_face.log ("S1ADULT DONE" when all 4 files exist).
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep1_s1_face.log"; STOPF="$DIR/.guard_off_s1a"
R="$COMFY_HOME_WIN"; F="$COMFY_HOME"/output/series/elf_set2_arcane/v3/s1face/full
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
up=0
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && { up=1; break; }; sleep 5; done
[ "$up" = 1 ] || { echo "S1ADULT FAILED $(date +%H:%M): comfyui did not answer" >> "$LOG"; exit 1; }
echo "s1 adult face start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'S1_ADULT=1 python /opt/tests/ep1_s1_face.py run'" 2>&1 | tr -d '\r' | grep -E "s1face|rror|Trace|failed|Exception" >> "$LOG"
sleep 15
[ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; exit 0; }
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name s1sheet -e S1_ADULT=1 -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/ep1_s1_face.py sheet" 2>&1 | tr -d '\r' | grep -E "sheets|rror|Trace" >> "$LOG"
miss=0; for d in 75 85; do for r in 1 2; do [ -f "$F/s1_r${r}_a$d.png" ] || miss=$((miss + 1)); done; done
if [ "$miss" = 0 ]; then echo "S1ADULT DONE $(date +%H:%M)" >> "$LOG"; else echo "S1ADULT INCOMPLETE $(date +%H:%M) ($miss missing)" >> "$LOG"; fi
