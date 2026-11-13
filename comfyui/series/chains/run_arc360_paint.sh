#!/usr/bin/env bash
# Painted 360 step 2 (00:50): the text keys looked like photos -> arc_orbit.py paint (edit model + slvra_v1, face =
# ep3 s19 head, style = the ep3 s19 frame) + sheet paints.jpg. Logs to arc360_paint.log ("ARCPAINT DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/arc360_paint.log"; STOPF="$DIR/.guard_off_arcp"; R="$COMFY_HOME_WIN"
O="$COMFY_HOME"/output/series/arc360
echo "paint start $(date +%H:%M)" >> "$LOG"
true
sleep 10
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
up=0; for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && { up=1; break; }; sleep 5; done
[ "$up" = 1 ] || { echo "ARCPAINT FAILED: comfyui did not answer" >> "$LOG"; exit 1; }
pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/arc_orbit.py paint'" 2>&1 | tr -d '\r' | grep -E "arc360|rror|Trace" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name arcpsheet -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' -e ARC_SHEET=paint --entrypoint python3 comfyui-r9700:local /opt/tests/arc_orbit.py sheet" 2>&1 | tr -d '\r' | grep -E "arc360|rror|Trace" >> "$LOG"
n=$(ls $O/paint_c*.png 2>/dev/null | wc -l)
[ "$n" = 4 ] && [ -f $O/paints.jpg ] && echo "ARCPAINT DONE $(date +%H:%M)" >> "$LOG" || echo "ARCPAINT INCOMPLETE $(date +%H:%M) ($n/4)" >> "$LOG"
