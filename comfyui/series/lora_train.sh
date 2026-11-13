#!/usr/bin/env bash
# Train the character LoRA "slvra" (the owner, 2026-11-09: "put it through a LoRA so we don't lose it") with musubi-tuner
# (volume lora-env) on Qwen-Image bf16, quantized to fp8 at load (--fp8_base --fp8_scaled: ~30 GB VRAM per the docs;
# blocks_to_swap adds headroom on the 32 GB R9700). Steps: cache the VAE latents, cache the text-encoder outputs, train.
# Run with the GPU and NO ComfyUI job at the same time:
#   wslc run --rm --gpus all -v lora-env:/lora -v comfy-models:/models:ro -v <output>:/data/output -v <tests>:/opt/tests:ro `
#     --entrypoint bash comfyui-r9700:local /opt/tests/lora_train.sh [cache|train|all]
# Writes /data/output/lora/out/slvra-*.safetensors (one per epoch) and logs to /data/output/lora/out/train.log.
set -euo pipefail
STEP="${1:-all}"
NAME="${LORA_NAME:-slvra}"        # the second LoRA (owner 2026-11-09): LORA_NAME=slvra_v2 LORA_EPOCHS=8
EPOCHS="${LORA_EPOCHS:-16}"
M=/models
DIT=$M/diffusion_models/qwen_image_bf16.safetensors
TE=$M/text_encoders/qwen_2.5_vl_7b.safetensors
VAE=$M/vae/qwen_image_vae.safetensors
DATA=/data/output/lora/$NAME
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
$(bash /opt/tests/lora_datasets_toml.sh "$DATA" "$CACHE" musubi)
EOF
grep -o 'cache_directory = "[^"]*"' /lora/$NAME.toml | cut -d'"' -f2 | xargs -r mkdir -p
if [ "$STEP" = cache ] || [ "$STEP" = all ]; then
  $PY src/musubi_tuner/qwen_image_cache_latents.py --dataset_config /lora/$NAME.toml --vae "$VAE" --model_version original
  $PY src/musubi_tuner/qwen_image_cache_text_encoder_outputs.py --dataset_config /lora/$NAME.toml --text_encoder "$TE" \
    --batch_size 1 --model_version original
fi
if [ "$STEP" = train ] || [ "$STEP" = all ]; then
  # adamw (torch) instead of the docs' adamw8bit: bitsandbytes on ROCm is not checked here; a LoRA of dim 16 is small
  /lora/venv/bin/accelerate launch --num_cpu_threads_per_process 1 --mixed_precision bf16 \
    src/musubi_tuner/qwen_image_train_network.py \
    --dit "$DIT" --vae "$VAE" --text_encoder "$TE" --model_version original \
    --dataset_config /lora/$NAME.toml --sdpa --mixed_precision bf16 \
    --fp8_base --fp8_scaled --blocks_to_swap 8 \
    --timestep_sampling shift --weighting_scheme none --discrete_flow_shift 2.2 \
    --optimizer_type adamw --learning_rate 5e-5 --gradient_checkpointing \
    --max_data_loader_n_workers 2 --persistent_data_loader_workers \
    --network_module networks.lora_qwen_image --network_dim 16 --network_alpha 16 \
    --max_train_epochs "$EPOCHS" --save_every_n_epochs 2 --seed 42 \
    --output_dir "$OUT" --output_name "$NAME" 2>&1 | tee -a "$OUT/train_$NAME.log"
fi
