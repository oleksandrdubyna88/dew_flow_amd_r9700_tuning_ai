#!/usr/bin/env bash
# Painted 360 start pictures (the owner 00:30: "one more 360 with the cartoon LoRA"). Waits for the realistic orbit
# (real2_orbit.log ORBIT DONE/FAILED — one GPU job at a time), then arc_orbit.py keys (4 seeds) + sheet keys.jpg.
# Logs to arc360.log ("ARCKEYS DONE"). The orbit itself is run_arc360_orbit.sh after my pick.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/arc360.log"; STOPF="$DIR/.guard_off_arck"; R="$COMFY_HOME_WIN"
O="$COMFY_HOME"/output/series/arc360
echo "waiting for ORBIT $(date +%H:%M)" >> "$LOG"
until grep -qE "ORBIT (DONE|FAILED)|guard stopped|restart: not ready" "$DIR/real2_orbit.log" 2>/dev/null; do sleep 30; done
sleep 10
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
up=0; for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && { up=1; break; }; sleep 5; done
[ "$up" = 1 ] || { echo "ARCKEYS FAILED: comfyui did not answer" >> "$LOG"; exit 1; }
pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/arc_orbit.py keys'" 2>&1 | tr -d '\r' | grep -E "arc360|rror|Trace" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name arcsheet -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/arc_orbit.py sheet" 2>&1 | tr -d '\r' | grep -E "arc360|rror|Trace" >> "$LOG"
n=$(ls $O/key_c*.png 2>/dev/null | wc -l)
[ "$n" = 4 ] && [ -f $O/keys.jpg ] && echo "ARCKEYS DONE $(date +%H:%M)" >> "$LOG" || echo "ARCKEYS INCOMPLETE $(date +%H:%M) ($n/4)" >> "$LOG"
