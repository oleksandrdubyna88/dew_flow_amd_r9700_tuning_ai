#!/usr/bin/env bash
# Audio models for ep3 sound (2026-11-10): ACE-Step 1.5 (the sung line), Stable Audio 3 medium + its text encoders (SFX,
# music bed). LOCAL volume only — no /store (the NAS write through the Windows cache was part of RAM crisis #2); a NAS copy
# later with robocopy /J. Waits for the clips to end (25 GB of writes during a 14B clip could grow the host cache again).
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/fetch-audio-local.log"
until grep -q "REST DONE" "$DIR/ep3_clips.log" 2>/dev/null; do sleep 60; done
H=https://huggingface.co
echo "start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name comfyui-fetch-audio -v comfy-models:/models -v '$COMFY_HOME_WIN\tests:/opt/tests:ro' --entrypoint bash comfyui-r9700:local /opt/tests/fetch_model_pinned.sh checkpoints $H/Comfy-Org/ace_step_1.5_ComfyUI_files/resolve/main/checkpoints/ace_step_1.5_turbo_aio.safetensors 67b0f43aa5c51c840bd0228e6a935d8ff416ec87e5df2fc0637da17a561252bc text_encoders $H/Comfy-Org/stable-audio-3/resolve/main/text_encoders/t5gemma_b_b_ul2.safetensors 1e1eba25be8872edb0d3c6335c6658fd6388e7b14b60da6e454e404cfcd8150e text_encoders $H/Comfy-Org/Qwen3.5/resolve/main/text_encoders/qwen3.5_2b_bf16.safetensors aa33250c4fc64891ddfaba3a314fd9542ea371843c387178b425fbcc5ed680b1 checkpoints $H/Comfy-Org/stable-audio-3/resolve/main/checkpoints/stable_audio_3_medium.safetensors 48d9c65e290e7bcd5194e0633bfc2424a59ee9683f5c2d58762d997b7d8ce0b5" 2>&1 | tr -d '\r' >> "$LOG"
echo "FETCH DONE exit ${PIPESTATUS[0]} $(date +%H:%M)" >> "$LOG"
