#!/usr/bin/env bash
# Painted 360 start picture face (01:00): arc_face.py run (s19 adult ref, masked, crop-enlarged) + sheet FACE_compare.jpg.
# Logs to arc360_face.log ("ARCFACE90 DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/arc360_face.log"; STOPF="$DIR/.guard_off_arcf"; R="$COMFY_HOME_WIN"
O="$COMFY_HOME"/output/series/arc360
echo "paint start $(date +%H:%M)" >> "$LOG"
sleep 10
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
up=0; for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && { up=1; break; }; sleep 5; done
[ "$up" = 1 ] || { echo "ARCPAINT FAILED: comfyui did not answer" >> "$LOG"; exit 1; }
pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'ARC_D=0.9 python /opt/tests/arc_face.py run'" 2>&1 | tr -d '\r' | grep -E "arc360|rror|Trace" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name arcfsheet -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/arc_face.py sheet" 2>&1 | tr -d '\r' | grep -E "arc360|rror|Trace" >> "$LOG"
n=$(ls $O/face/full/c3_r*_a90.png 2>/dev/null | wc -l)
[ "$n" = 2 ] && echo "ARCFACE90 DONE $(date +%H:%M)" >> "$LOG" || echo "ARCFACE90 INCOMPLETE ($n/2)" >> "$LOG"
