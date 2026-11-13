#!/usr/bin/env bash
# Character LoRA on HiDream-I1 Full with diffusion-pipe (the owner 2026-11-13 ~00:35: "train a LoRA on HiDream too, its
# 3 pictures are fine"; consultants 9ea54851 (gpt-6-astra + gemini-4-argon) on the settings).
# Dataset lora/slvrareal6b (v6: v5 + the owner's 18 new pictures; r1_gemini, r2_picks, r3_full, r3_new -> 138 samples
# per epoch). Settings: rank 16, adamw_optimi lr 1e-4 (both consultants: rank 32 / 2e-4 too hot at batch 1), 1024
# buckets (HiDream degrades under 1024), max_llama3_sequence_length 160 (longest caption 86 words; CLIP sees 77),
# Llama 3.1 8B in bf16 (llama3_4bit needs bitsandbytes = CUDA only), transformer fp8, blocks_to_swap from DP_SWAP
# (default 12: 32 GB, measure; the docs' 20+ is for 24 GB cards), 8 epochs (~1100 steps), save every 2 epochs.
# Run (GPU, VM 40 GB, --shm-size 8G):
#   wslc run --rm --gpus all --shm-size 8G -v lora-env:/lora -v comfy-models:/models:ro -v <output>:/data/output \
#     -v <tests>:/opt/tests:ro --entrypoint bash comfyui-r9700:local /opt/tests/lora_train_hidream.sh [smoke|full]
# smoke = 10 steps + a save (does deepspeed start on ROCm/WSL, memory, s/step). Writes /data/output/lora/dp_runs/<run>/.
set -uo pipefail
MODE="${1:-smoke}"
DATA="${DP_DATA:-/data/output/lora/slvrareal6b}"
RUN="slvrareal6b_hidream_$MODE"
OUT=/data/output/lora/dp_runs
SWAP="${DP_SWAP:-12}"
mkdir -p "$OUT" /lora/dp_cfg
{
  echo "resolutions = [1024]"
  echo "enable_ar_bucket = true"
  echo "min_ar = 0.5"
  echo "max_ar = 2.0"
  echo "num_ar_buckets = 7"
  for d in "$DATA"/r[0-9]*_*; do
    [ -d "$d" ] || continue
    n=$(basename "$d" | sed -E 's/^r([0-9]+)_.*/\1/')
    printf "\n[[directory]]\npath = '%s'\nnum_repeats = %s\n" "$d" "$n"
  done
} > /lora/dp_cfg/$RUN.dataset.toml
if [ "$MODE" = smoke ]; then
  EXTRA=$'max_steps = 10\nsave_every_n_steps = 10'
  EPOCHS=1
else
  EXTRA="save_every_n_epochs = 2"
  EPOCHS=8
fi
cat > /lora/dp_cfg/$RUN.toml <<EOF
output_dir = '$OUT/$RUN'
dataset = '/lora/dp_cfg/$RUN.dataset.toml'
epochs = $EPOCHS
$EXTRA
micro_batch_size_per_gpu = 1
pipeline_stages = 1
gradient_accumulation_steps = 1
gradient_clipping = 1.0
warmup_steps = 50
checkpoint_every_n_minutes = 120
activation_checkpointing = true
partition_method = 'parameters'
save_dtype = 'bfloat16'
caching_batch_size = 1
steps_per_print = 1
blocks_to_swap = $SWAP

[model]
type = 'hidream'
diffusers_path = '/models/diffusers/HiDream-I1-Full'
llama3_path = '/models/llm/Meta-Llama-3.1-8B-Instruct'
llama3_4bit = false
dtype = 'bfloat16'
transformer_dtype = 'float8'
max_llama3_sequence_length = 160

[adapter]
type = 'lora'
rank = 16
dtype = 'bfloat16'

[optimizer]
type = 'adamw_optimi'
lr = 1e-4
betas = [0.9, 0.99]
weight_decay = 0.01
eps = 1e-8
EOF
echo "== config $RUN (swap $SWAP)"; cat /lora/dp_cfg/$RUN.dataset.toml
cd /lora/diffusion-pipe
export NCCL_P2P_DISABLE=1 NCCL_IB_DISABLE=1 DS_ACCELERATOR=cuda
# 2026-11-13 08:10: the latent-caching workers start torch_shm_manager, a separate binary with no rpath to the ROCm SDK
# libraries (librocm-openblas.so.0, libamdhip64.so.7, librocprofiler-sdk.so.1: "not found" in ldd); the worker then dies
# with "no response from torch_shm_manager" and the main process waits for ever (4 h on 03:53-08:08).
R_SDK=/usr/local/lib/python3.12/dist-packages/_rocm_sdk_core/lib
export LD_LIBRARY_PATH="$R_SDK:$R_SDK/host-math/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
[ "$(ldd /usr/local/lib/python3.12/dist-packages/torch/bin/torch_shm_manager | grep -c 'not found')" = 0 ] \
  || { echo "torch_shm_manager still misses libraries"; exit 3; }
/lora/venv_dp/bin/python -c "import torch, deepspeed; from deepspeed.accelerator import get_accelerator as g; print('accel', g()._name, 'cuda', torch.cuda.is_available(), torch.cuda.get_device_name(0) if torch.cuda.is_available() else '-')"
/lora/venv_dp/bin/deepspeed --num_gpus=1 train.py --deepspeed --config /lora/dp_cfg/$RUN.toml 2>&1 | tee -a "$OUT/train_$RUN.log"
echo "train exit ${PIPESTATUS[0]}"
