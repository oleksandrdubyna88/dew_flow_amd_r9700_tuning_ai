#!/usr/bin/env bash
# FLUX.2 klein base 4B LoRA (the owner 2026-11-12 ~01:20: "then let's try Flux too"), same dataset as the Qwen LoRA v3
# (lora/slvrareal3, 37 pictures). musubi-tuner flux_2 scripts, --model_version klein-base-$SIZE (the docs: train on the base,
# the distilled klein-4b is for 4-step inference). 4B in bf16 = ~8 GB: no fp8 needed on the 32 GB R9700.
# Own toml + cache folder (never the Qwen cache). Run with the GPU and NO ComfyUI job at the same time:
#   wslc run --rm --gpus all -v lora-env:/lora -v comfy-models:/models:ro -v <output>:/data/output -v <tests>:/opt/tests:ro `
#     -e LORA_NAME=slvrareal3 --entrypoint bash comfyui-r9700:local /opt/tests/lora_train_flux2.sh [cache|train|all]
# Writes /data/output/lora/out/<name>_flux2k4b*.safetensors.
set -euo pipefail
STEP="${1:-all}"
DATA_NAME="${LORA_NAME:-slvrareal3}"
SIZE="${FLUX2_SIZE:-4b}"  # 4b (Apache) | 9b (gated, FLUX Non-Commercial License; owner 2026-11-12 08:45 "then the Flux 9B LoRA")
NAME="${DATA_NAME}_flux2k${SIZE}"
EPOCHS="${LORA_EPOCHS:-12}"
M=/models
DIT=$M/diffusion_models/flux-2-klein-base-$SIZE.safetensors
TE=$M/text_encoders/$([ "$SIZE" = 9b ] && echo qwen_3_8b || echo qwen_3_4b).safetensors
VAE=$M/vae/flux2-vae.safetensors
DATA=/data/output/lora/$DATA_NAME
OUT=/data/output/lora/out
CACHE=/lora/cache/$NAME
PY=/lora/venv/bin/python
cd /lora/musubi-tuner
mkdir -p "$OUT" "$CACHE"
cat > /lora/$NAME.toml <<EOF
[general]
resolution = [1024, 576]
caption_extension = ".txt"
batch_size = 1
enable_bucket = true
bucket_no_upscale = false

[[datasets]]
image_directory = "$DATA"
cache_directory = "$CACHE"
num_repeats = 4
EOF
if [ "$STEP" = cache ] || [ "$STEP" = all ]; then
  $PY src/musubi_tuner/flux_2_cache_latents.py --dataset_config /lora/$NAME.toml --vae "$VAE" --model_version klein-base-$SIZE
  $PY src/musubi_tuner/flux_2_cache_text_encoder_outputs.py --dataset_config /lora/$NAME.toml --text_encoder "$TE" \
    --batch_size 1 --model_version klein-base-$SIZE
fi
if [ "$STEP" = train ] || [ "$STEP" = all ]; then
  # adamw (torch) as in lora_train.sh: bitsandbytes on ROCm is not checked here
  /lora/venv/bin/accelerate launch --num_cpu_threads_per_process 1 --mixed_precision bf16 \
    src/musubi_tuner/flux_2_train_network.py --model_version klein-base-$SIZE \
    --dit "$DIT" --vae "$VAE" --text_encoder "$TE" \
    --dataset_config /lora/$NAME.toml --sdpa --mixed_precision bf16 \
    --timestep_sampling flux2_shift --weighting_scheme none \
    --optimizer_type adamw --learning_rate 1e-4 --gradient_checkpointing \
    --max_data_loader_n_workers 2 --persistent_data_loader_workers \
    --network_module networks.lora_flux_2 --network_dim 32 --network_alpha 32 \
    --max_train_epochs "$EPOCHS" --save_every_n_epochs 2 --seed 42 \
    --output_dir "$OUT" --output_name "$NAME" 2>&1 | tee -a "$OUT/train_$NAME.log"
fi
