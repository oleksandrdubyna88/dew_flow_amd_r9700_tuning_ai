#!/usr/bin/env bash
# Episode 1 realistic, step 1 (2026-11-11 night): after the realistic LoRA (LREAL DONE), the strength test — shots 1 and
# 3 at slvrareal 0.6 / 0.8 / 1.0 (ep1_real.py test). Own guard. Logs to ep1_real.log ("TEST DONE"; then: choice by eye).
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep1_real.log"; STOPF="$DIR/.guard_off_ep1r"
until grep -q "LREAL DONE" "$DIR/lora_real.log" 2>/dev/null; do sleep 60; done
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break; sleep 5; done
pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/ep1_real.py test'" 2>&1 | tr -d '\r' | grep -E "ep1 real|rror" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
echo "TEST DONE $(date +%H:%M)" >> "$LOG"
