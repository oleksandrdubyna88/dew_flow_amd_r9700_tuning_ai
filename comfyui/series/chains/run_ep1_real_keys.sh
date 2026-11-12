#!/usr/bin/env bash
# Episode 1 realistic, step 2 (2026-11-11): keyframes of shots 1-6, two candidates each, slvrareal at 1.0 (chosen by eye
# from the strength test: 0.6/0.8/1.0 nearly equal, 1.0 closest to the set-2 face). Own guard. Logs to ep1_real.log ("KEYS DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep1_real.log"; STOPF="$DIR/.guard_off_ep1rk"
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break; sleep 5; done
pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'LREAL_STRENGTH=1.0 python /opt/tests/ep1_real.py keys 1 2 3 4 5 6'" 2>&1 | tr -d '\r' | grep -E "ep1 real|rror" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
echo "KEYS DONE $(date +%H:%M)" >> "$LOG"
