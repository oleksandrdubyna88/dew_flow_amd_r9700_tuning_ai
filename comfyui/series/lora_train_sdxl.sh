#!/usr/bin/env bash
# SDXL LoRA (the owner 2026-11-12 ~01:30: "Stable Diffusion too") on the same dataset as the Qwen / FLUX.2 LoRAs v3
# (lora/slvrareal3, 37 pictures). Base = RealVisXL V5.0 (already used for the InstantID face repaints). kohya sd-scripts in
# /lora/sd-scripts with /lora/venv_sd (run_sdscripts_setup.sh). U-Net only (the text encoders stay), long captions ->
# --max_token_length 225, --no_half_vae (the fp16 SDXL VAE makes NaNs). Run with the GPU and NO ComfyUI job:
#   wslc run --rm --gpus all -v lora-env:/lora -v comfy-models:/models:ro -v <output>:/data/output -v <tests>:/opt/tests:ro `
#     -e LORA_NAME=slvrareal3 --entrypoint bash comfyui-r9700:local /opt/tests/lora_train_sdxl.sh
# Writes /data/output/lora/out/<name>_sdxl*.safetensors. 08:30: accelerate lives in the system packages (no bin/accelerate in venv_sd) -> python -m accelerate.commands.launch.
set -euo pipefail
DATA_NAME="${LORA_NAME:-slvrareal3}"
NAME="${DATA_NAME}_sdxl"
EPOCHS="${LORA_EPOCHS:-10}"
CKPT=/models/checkpoints/RealVisXL_V5.0_fp16.safetensors
OUT=/data/output/lora/out
cd /lora/sd-scripts
mkdir -p "$OUT"
cat > /lora/$NAME.toml <<EOF
[general]
caption_extension = ".txt"
shuffle_caption = false
keep_tokens = 1

[[datasets]]
resolution = 1024
batch_size = 1
enable_bucket = true
min_bucket_reso = 512
max_bucket_reso = 1536
bucket_no_upscale = false
$(bash /opt/tests/lora_datasets_toml.sh "/data/output/lora/$DATA_NAME" "" kohya)
EOF
/lora/venv_sd/bin/python -m accelerate.commands.launch --num_cpu_threads_per_process 1 --mixed_precision bf16 sdxl_train_network.py \
  --pretrained_model_name_or_path "$CKPT" --dataset_config /lora/$NAME.toml \
  --network_module networks.lora --network_dim 32 --network_alpha 16 --network_train_unet_only \
  --optimizer_type AdamW --learning_rate 1e-4 --lr_scheduler cosine --lr_warmup_steps 50 \
  --mixed_precision bf16 --save_precision fp16 --sdpa --gradient_checkpointing --cache_latents \
  --no_half_vae --max_token_length 225 --max_data_loader_n_workers 2 \
  --max_train_epochs "$EPOCHS" --save_every_n_epochs 2 --seed 42 \
  --output_dir "$OUT" --output_name "$NAME" --save_model_as safetensors 2>&1 | tee -a "$OUT/train_$NAME.log"
