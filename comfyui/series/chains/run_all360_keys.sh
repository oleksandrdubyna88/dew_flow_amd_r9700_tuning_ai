#!/usr/bin/env bash
# 360 on all LoRAs, step 1 (the owner ~11:00: "make the 9B LoRA, then the 360 videos on all LoRAs"): waits for
# "K9 CHAIN2 DONE" (one GPU job at a time), then 4 start pictures per model (qwen, flux2, sdxl, flux2k9 if its LoRA
# exists) with a fresh ComfyUI per model -> series/all360/keys.jpg. Logs to all360.log ("KEYS DONE"). The owner/I pick
# one start picture per model into all360_picks.txt, then run_all360_orbits.sh.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/all360.log"; R="$COMFY_HOME_WIN"
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
job() { pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c '$1'" 2>&1 | tr -d '\r' | grep -E "all360|rror|out of memory|Trace" | head -20 >> "$LOG"; }
echo "waiting for K9 CHAIN2 $(date +%H:%M)" >> "$LOG"
until grep -q "K9 CHAIN2 DONE" "$DIR/k9_chain2.log" 2>/dev/null; do sleep 60; done
sleep 20
echo "keys start $(date +%H:%M)" >> "$LOG"
for m in qwen flux2 sdxl flux2k9; do
  if [ $m = flux2k9 ] && ! grep -q "copied slvrareal3_flux2k9b" "$DIR/k9_chain2.log"; then echo "no 9B LoRA — skip flux2k9" >> "$LOG"; continue; fi
  restart && job "python /opt/tests/all360.py keys $m"
done
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name a360sheet -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/all360.py keysheet" 2>&1 | tr -d '\r' | grep -E "all360|rror" >> "$LOG"
echo "KEYS DONE $(date +%H:%M)" >> "$LOG"
