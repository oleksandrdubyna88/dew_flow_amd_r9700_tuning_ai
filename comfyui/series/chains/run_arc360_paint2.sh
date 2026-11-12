#!/usr/bin/env bash
# Painted 360 step 2, try 2 (00:55): paint_c* pasted a giant head -> arc_orbit.py paint2 with ARC_REFS=1 and 2, keys c2/c3.
# Logs to arc360_paint2.log ("ARCPAINT2 DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/arc360_paint2.log"; STOPF="$DIR/.guard_off_arcp2"; R="$COMFY_HOME_WIN"
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
pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'ARC_REFS=1 python /opt/tests/arc_orbit.py paint2; ARC_REFS=2 python /opt/tests/arc_orbit.py paint2'" 2>&1 | tr -d '\r' | grep -E "arc360|rror|Trace" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
true
n=$(ls $O/paint[12]r_c*.png 2>/dev/null | wc -l)
[ "$n" = 4 ] && echo "ARCPAINT2 DONE $(date +%H:%M)" >> "$LOG" || echo "ARCPAINT2 INCOMPLETE ($n/4)" >> "$LOG"
