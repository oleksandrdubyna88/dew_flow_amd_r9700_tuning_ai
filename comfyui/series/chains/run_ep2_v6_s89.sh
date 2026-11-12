#!/usr/bin/env bash
# Episode 2 v6: new keyframes for s8/s9 (set 2: the vehicle from BEHIND), after the realistic LoRA pictures (LGEN DONE).
# Text phase only (scene kind). Own guard. Logs to ep2_v6.log ("S89 DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep2_v6.log"; STOPF="$DIR/.guard_off_ep2s89"
until grep -q "LGEN DONE" "$DIR/lora_real.log" 2>/dev/null; do sleep 30; done
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break; sleep 5; done
pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'EP2V6_SET=2 EP3_PHASE=text python /opt/tests/ep2_v6.py keys 8 9'" 2>&1 | tr -d '\r' | grep -E "ep2 v6|rror" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
echo "S89 DONE $(date +%H:%M)" >> "$LOG"
