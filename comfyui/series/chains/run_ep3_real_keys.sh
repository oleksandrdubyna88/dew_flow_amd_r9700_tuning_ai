#!/usr/bin/env bash
# Realistic ep3 keyframes with all 4 LoRA v3 (the owner 2026-11-12 ~22:10). Waits for the Hunyuan tune
# ("^HUNYUAN TUNE DONE", checked absent before this start). Per model a fresh server, 23 shots x 2 candidates, then the
# sheet series/ep3_real/<model>/keys.jpg. NO clips (the owner sees the keyframes first). Log ep3_real.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
DIR="$(dirname "$0")"; LOG="$DIR/ep3_real.log"; R="$COMFY_HOME_WIN"
echo "ep3real keys waiting $(date +%H:%M)" >> "$LOG"
until grep -q "^HUNYUAN TUNE DONE" "$DIR/newmodel.log"; do sleep 30; done
for m in flux2k9 qwen flux2 sdxl; do
  echo "$m keys start $(date +%H:%M)" >> "$LOG"
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break; sleep 5; done
  pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/ep3_real.py keys $m'" > "$DIR/ep3_real_keys_$m.out" 2>&1
  grep -E "rror|Trace|imeout|Killed" "$DIR/ep3_real_keys_$m.out" | tr -d '\r' | head -5 >> "$LOG"
  echo "$m keys: $(grep -c 'ep3real .* key ' "$DIR/ep3_real_keys_$m.out") made $(date +%H:%M)" >> "$LOG"
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
  pwsh.exe -NoProfile -Command "wslc run --rm --name e3r-sheet -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/ep3_real.py keysheet $m" 2>&1 | tr -d '\r' | tail -2 >> "$LOG"
done
echo "EP3REAL KEYS DONE $(date +%H:%M)" >> "$LOG"
