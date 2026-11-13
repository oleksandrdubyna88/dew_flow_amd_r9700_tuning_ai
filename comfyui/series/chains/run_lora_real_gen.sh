#!/usr/bin/env bash
# Realistic LoRA dataset pictures (2026-11-10 night, the owner: "render the LoRAs for realism"), after the ep2 v6 keyframes:
# two phases (one big image model per session): text = realistic poses, edit = her realistic face (set-2 refs).
# Own guard stop file, killed on exit. Logs to lora_real.log; ends with "KEYS DONE" (then: picks by eye).
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/lora_real.log"; STOPF="$DIR/.guard_off_lreal"
until grep -q "KEYS DONE" "$DIR/ep2_v6.log" 2>/dev/null; do sleep 30; done
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
job() { pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c '$1'" 2>&1 | tr -d '\r' | grep -E "lora real|rror|out of memory" | head -40 >> "$LOG"; }
guarded() { [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; return 1; }; return 0; }
for phase in text edit; do
  echo "phase $phase $(date +%H:%M)" >> "$LOG"
  restart || break
  job "EP3_PHASE=$phase python /opt/tests/lora_dataset_real.py gen"
  guarded || exit 0
done
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
echo "LGEN DONE $(date +%H:%M)" >> "$LOG"
