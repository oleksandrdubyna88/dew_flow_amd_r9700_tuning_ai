#!/usr/bin/env bash
# 04:25: check that the FLUX.2 LoRA really loads — the night chain's "lora key not loaded" grep printed nothing
# (/tmp/comfyui.log missing?). Renders the 5 scenes with strength 0.0 (ComfyUI skips the LoRA) + 0.7 (loads it, for the log) -> she3check/flux2/<scene>_0_* and _70_*,
# then greps the container log. Logs to flux2_baseline.log, "FBASE DONE".
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
DIR="$(dirname "$0")"; LOG="$DIR/flux2_baseline.log"; R="$COMFY_HOME_WIN"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break; sleep 5; done
pwsh.exe -NoProfile -Command "wslc exec -e SHE3_STRENGTHS=0.0,0.7 comfyui sh -c 'python /opt/tests/she3_check.py flux2'" 2>&1 | tr -d '\r' | grep -E "she3check|rror|Trace" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc logs comfyui" 2>&1 | tr -d '\r' | grep -iE "lora key not loaded|lora" | sort | uniq -c | head -10 >> "$LOG"
pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'ls /tmp/*.log 2>/dev/null'" 2>&1 | tr -d '\r' >> "$LOG"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
echo "FBASE DONE $(date +%H:%M)" >> "$LOG"
