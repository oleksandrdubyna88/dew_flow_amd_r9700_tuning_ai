#!/usr/bin/env bash
# Install musubi-tuner (kohya-ss, Apache-2.0; the owner approved it 2026-11-09) for the character LoRA into the volume
# lora-env, mounted at /lora: a venv with --system-site-packages over the ComfyUI image's ROCm PyTorch 2.13; the image's
# constraints file (/opt/rocm-constraints.txt) keeps torch/ROCm packages exactly as they are. Nothing is installed on
# Windows or in WSL.
# Run:  wslc run --rm -v lora-env:/lora -v <tests>:/opt/tests:ro --entrypoint bash comfyui-r9700:local /opt/tests/lora_setup.sh
set -euo pipefail
REF="${MUSUBI_REF:-main}"
cd /lora
if [ ! -d musubi-tuner ]; then
  git clone https://github.com/kohya-ss/musubi-tuner.git
fi
cd musubi-tuner && git fetch -q origin && git checkout -q "$REF" && echo "musubi-tuner at $(git rev-parse --short HEAD)"
[ -x /lora/venv/bin/python ] || python3 -m venv --system-site-packages /lora/venv
/lora/venv/bin/pip install -q --no-cache-dir -c /opt/rocm-constraints.txt -e /lora/musubi-tuner
/lora/venv/bin/python - <<'PY'
import torch, transformers, diffusers, accelerate
print("torch", torch.__version__, "hip", torch.version.hip, "| transformers", transformers.__version__,
      "| diffusers", diffusers.__version__, "| accelerate", accelerate.__version__)
PY
