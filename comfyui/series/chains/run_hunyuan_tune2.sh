#!/usr/bin/env bash
# Hunyuan 2.1 tune ROUND 2 (2026-11-12 22:55): round 1 v2-v5 drew a 40-50 year old woman (silver hair read as age); v6 young + dyed platinum hair + youthful skin, v7 the old look without "pale skin", v8 = v6 cfg 5. Waits for "^EP3REAL KEYS DONE".
# 5 variants (prompt without "pale skin" + long photo prompt, 50 steps, shift 5, cfg) x 3 scenes, no LoRA ->
# series/she3check/hunyuan21_tune/ + tune_hunyuan21.jpg. Waits for "^HIDREAM REST2 DONE" (checked: absent before start).
# Fresh server, full output in hunyuan_tune.out. Log newmodel.log ("HUNYUAN TUNE DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
DIR="$(dirname "$0")"; R="$COMFY_HOME_WIN"
until grep -q "^EP3REAL KEYS DONE" "$DIR/ep3_real.log"; do sleep 30; done
echo "hunyuan tune r2 start $(date +%H:%M)" >> "$DIR/newmodel.log"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break; sleep 5; done
pwsh.exe -NoProfile -Command "wslc exec -e TUNE_ROUND=2 comfyui sh -c 'python /opt/tests/newmodel_check.py tune hunyuan21'" > "$DIR/hunyuan_tune_r2.out" 2>&1
grep -E "newmodel|rror|Trace|imeout|Killed" "$DIR/hunyuan_tune_r2.out" | tr -d '\r' | head -20 >> "$DIR/newmodel.log"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name nm-tune2 -e TUNE_ROUND=2 -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/newmodel_check.py tune_sheet hunyuan21" 2>&1 | tr -d '\r' | tail -3 >> "$DIR/newmodel.log"
echo "HUNYUAN TUNE R2 DONE $(date +%H:%M)" >> "$DIR/newmodel.log"
