#!/usr/bin/env bash
# Hunyuan 2.1 tune (the owner 2026-11-12 21:35: base_hunyuan21.jpg "looks like Gollum, work on it, make it good"):
# 5 variants (prompt without "pale skin" + long photo prompt, 50 steps, shift 5, cfg) x 3 scenes, no LoRA ->
# series/she3check/hunyuan21_tune/ + tune_hunyuan21.jpg. Waits for "^HIDREAM REST2 DONE" (checked: absent before start).
# Fresh server, full output in hunyuan_tune.out. Log newmodel.log ("HUNYUAN TUNE DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
DIR="$(dirname "$0")"; R="$COMFY_HOME_WIN"
until grep -q "^HIDREAM REST2 DONE" "$DIR/newmodel.log"; do sleep 30; done
echo "hunyuan tune start $(date +%H:%M)" >> "$DIR/newmodel.log"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break; sleep 5; done
pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/newmodel_check.py tune hunyuan21'" > "$DIR/hunyuan_tune.out" 2>&1
grep -E "newmodel|rror|Trace|imeout|Killed" "$DIR/hunyuan_tune.out" | tr -d '\r' | head -20 >> "$DIR/newmodel.log"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name nm-tune -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/newmodel_check.py tune_sheet hunyuan21" 2>&1 | tr -d '\r' | tail -3 >> "$DIR/newmodel.log"
echo "HUNYUAN TUNE DONE $(date +%H:%M)" >> "$DIR/newmodel.log"
