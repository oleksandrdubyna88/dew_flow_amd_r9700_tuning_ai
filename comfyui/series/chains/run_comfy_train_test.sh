#!/usr/bin/env bash
# ComfyUI built-in TrainLoraNode test on the R9700 (the owner 2026-11-12 ~23:59: "check it on our AMD card and set it
# up"). Waits for "^HUNYUAN TUNE R2 DONE" (checked absent before start; one GPU job at a time). Fresh server, prep the
# dataset folder, train 100 steps on FLUX.2 klein base 4B (s/step, errors), dump the UI workflow. Log comfytrain.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
DIR="$(dirname "$0")"; LOG="$DIR/comfytrain.log"; R="$COMFY_HOME_WIN"
echo "comfytrain waiting $(date +%H:%M)" >> "$LOG"
until grep -q "^HUNYUAN TUNE R2 DONE" "$DIR/newmodel.log"; do sleep 30; done
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break; sleep 5; done
echo "comfytrain start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/comfy_train_test.py prep; python /opt/tests/comfy_train_test.py train 100; python /opt/tests/comfy_train_test.py dump'" > "$DIR/comfytrain.out" 2>&1
grep -E "comfytrain|rror|Trace|imeout|out of memory|Killed" "$DIR/comfytrain.out" | tr -d '\r' | head -20 >> "$LOG"
pwsh.exe -NoProfile -Command "wslc logs comfyui" 2>&1 | tr -d '\r' | grep -iE "train|loss|error|memory|step" | tail -n 40 > "$DIR/comfytrain_server.log"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
echo "COMFYTRAIN DONE $(date +%H:%M)" >> "$LOG"
