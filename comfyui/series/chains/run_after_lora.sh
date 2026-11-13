#!/usr/bin/env bash
# After "LORA DONE" (run_lora.sh): stop run_lora (its next step is the realistic clips), copy the final LoRA and the
# epoch-8 checkpoint into the models volume, test both from text only (lora_test.py, + the same seeds without the LoRA),
# then the realistic episode 2 clips 2-9, join, mix. The eye test renders are added when the owner gives the times.
# Logs to after_lora.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/after_lora.log"; R="$COMFY_HOME_WIN"
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do
    pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0
    sleep 5
  done
  echo "restart: not ready after 300 s" >> "$LOG"; return 1
}
clip() {  # $1 = driver + args before the shot number, $2 = shot
  for try in 1 2; do
    restart || return 1
    out="$(pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/$1 $2" 2>&1 | tr -d '\r')"
    echo "$out" | grep -E "shot|out of memory|Error" | head -3 >> "$LOG"
    echo "$out" | grep -qE "shot $2: clip" && return 0
    echo "$1 $2: try $try failed" >> "$LOG"
  done
}
until grep -q "LORA DONE" "$DIR/lora_run.log" 2>/dev/null; do sleep 30; done
P=run_; P="${P}lora.sh"; pkill -f "bash $(cd "$(dirname "$0")" && pwd)/$P" && echo "run_lora stopped after LORA DONE $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name lora-copy -v comfy-models:/models -v '$R\output:/data/output:ro' --entrypoint sh comfyui-r9700:local -c 'cp /data/output/lora/out/slvra.safetensors /models/loras/slvra_v1.safetensors && cp /data/output/lora/out/slvra-000008.safetensors /models/loras/slvra_v1_e8.safetensors && ls -la /models/loras | grep slvra'" 2>&1 | tr -d '\r' >> "$LOG"
restart
for l in slvra_v1.safetensors slvra_v1_e8.safetensors; do
  pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/lora_test.py $l 1.0" 2>&1 | tr -d '\r' | grep -E "slvra|base|rror" >> "$LOG"
done
pwsh.exe -NoProfile -Command "wslc logs comfyui" 2>&1 | tr -d '\r' | grep -ciE "lora key not loaded" | sed 's/^/lora keys NOT loaded (count): /' >> "$LOG"
echo "LORA TEST DONE $(date +%H:%M)" >> "$LOG"
for k in 2 3 4 5 6 7 8 9; do clip "ep2_real.py shot" "$k"; done
pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_real.py join" 2>&1 | tr -d '\r' | tail -1 >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name comfyui-mix -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/voiceover.py /data/output/series/ep2_real/ep2_real_14b.mp4 ep2/vox --shot 5.0625 --end slowmo" 2>&1 | tr -d '\r' | grep -E "ending|audio ok|written|bad|rror" >> "$LOG"
echo "all done $(date +%H:%M)" >> "$LOG"
