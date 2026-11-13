#!/usr/bin/env bash
# Base test sheets (no LoRA) of HiDream-I1 Full and HunyuanImage 2.1 (the owner 2026-11-12 ~16:05). Waits on LOG LINES
# (never pgrep): the 360 chain "REST DONE" (one GPU job at a time) + each model's "DL DONE". A fresh server per model,
# 5 scenes at strength 0.0, then the sheet -> series/she3check/base_<model>.jpg. Own RAM guard (the VM stays 20 GB; the
# guard stops ComfyUI if the RAM runs out). Logs to newmodel.log ("NEWBASE DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/newmodel.log"; STOPF="$DIR/.guard_off_newmodel"; R="$COMFY_HOME_WIN"
echo "newbase waiting $(date +%H:%M)" >> "$LOG"
until grep -q "^V2VFIX2 DONE" "$DIR/all360_v2vfix.log" 2>/dev/null; do sleep 60; done
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
for m in hidream hunyuan21; do
  until grep -q "^DL DONE\|^DL FAILED" "$DIR/${m}_download.log" 2>/dev/null; do sleep 60; done
  grep -q "^DL DONE" "$DIR/${m}_download.log" || { echo "$m SKIP: download failed" >> "$LOG"; continue; }
  echo "$m base start $(date +%H:%M)" >> "$LOG"
  restart && pwsh.exe -NoProfile -Command "wslc exec -e SHE3_STRENGTHS=0.0 comfyui sh -c 'python /opt/tests/newmodel_check.py run $m'" 2>&1 | tr -d '\r' | grep -E "newmodel|rror|Trace|out of memory" | head -20 >> "$LOG"
  [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; break; }
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
  pwsh.exe -NoProfile -Command "wslc run --rm --name nm-sheet -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/newmodel_check.py sheet $m" 2>&1 | tr -d '\r' | tail -3 >> "$LOG"
done
echo "NEWBASE DONE $(date +%H:%M)" >> "$LOG"
