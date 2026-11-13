#!/usr/bin/env bash
# InstantID for the realistic LoRA v2 dataset (the owner, 2026-11-11: "ok, do InstantID" — Qwen-Edit could not move the
# set-c faces to the chosen face: 0.75 = a small change, 0.9/1.0 break, a full edit copies the reference). InstantID copies
# one face photo onto SDXL pictures; here only for the face crop of each set-c picture (the LoRA stays a Qwen-Image LoRA).
# Installs into the volumes only (never the system): the custom node cubiq/ComfyUI_InstantID (pinned) into
# /data/custom_nodes, insightface + onnxruntime (CPU) into /data/venv (the image's torch constraints apply), and the models
# into /models. Hugging Face files are checked against their LFS sha256. Re-runnable (existing good files are kept).
# Run (no GPU, ComfyUI stopped):
#   wslc run --rm -v comfy-data:/data -v comfy-models:/models -v <tests>:/opt/tests:ro --entrypoint bash \
#     comfyui-r9700:local /opt/tests/instantid_setup.sh
set -euo pipefail
NODE_COMMIT=72495e806bc2ab9c41581e15ccaa1bcf83c477e8
HF=https://huggingface.co

fetch_hf() {  # <repo> <path in repo> <destination>
  local url="$HF/$1/resolve/main/$2" dst="$3" want have
  want="$(curl -sIL "$url" | tr -d '\r' | sed -n 's/^x-linked-etag: *"\{0,1\}\([0-9a-f]\{64\}\)"\{0,1\}$/\1/p' | tail -1)"
  [ -n "$want" ] || { echo "no sha256 for $url" >&2; exit 1; }
  if [ -f "$dst" ] && [ "$(sha256sum "$dst" | cut -d' ' -f1)" = "$want" ]; then echo "ok (kept) $dst"; return; fi
  curl -fL --retry 5 --retry-delay 10 -C - -o "$dst.part" "$url"
  have="$(sha256sum "$dst.part" | cut -d' ' -f1)"
  [ "$have" = "$want" ] || { echo "sha256 mismatch $dst: $have != $want" >&2; exit 1; }
  mv "$dst.part" "$dst"
  echo "ok $dst"
}

# 1. the custom node, pinned
if [ ! -d /data/custom_nodes/ComfyUI_InstantID/.git ]; then
  git clone https://github.com/cubiq/ComfyUI_InstantID /data/custom_nodes/ComfyUI_InstantID
fi
git -C /data/custom_nodes/ComfyUI_InstantID fetch -q origin
git -C /data/custom_nodes/ComfyUI_InstantID checkout -q "$NODE_COMMIT"
echo "node at $(git -C /data/custom_nodes/ComfyUI_InstantID rev-parse --short HEAD)"
cat /data/custom_nodes/ComfyUI_InstantID/requirements.txt

# 2. packages into the venv (CPU onnxruntime: the face detector only; the GPU does the diffusion)
/data/venv/bin/pip install --no-cache-dir insightface==0.7.3 onnxruntime==1.31.1
/data/venv/bin/python -c "import insightface, onnxruntime as o; print('insightface', insightface.__version__, 'onnxruntime', o.__version__, o.get_available_providers())"

# 3. models
mkdir -p /models/instantid /models/controlnet /models/checkpoints /models/insightface/models
fetch_hf InstantX/InstantID ip-adapter.bin /models/instantid/ip-adapter.bin
fetch_hf InstantX/InstantID ControlNetModel/diffusion_pytorch_model.safetensors /models/controlnet/instantid_controlnet.safetensors
fetch_hf SG161222/RealVisXL_V5.0 RealVisXL_V5.0_fp16.safetensors /models/checkpoints/RealVisXL_V5.0_fp16.safetensors
if [ ! -f /models/insightface/models/antelopev2/glintr100.onnx ]; then
  curl -fL --retry 5 --retry-delay 10 -o /tmp/antelopev2.zip \
    https://github.com/deepinsight/insightface/releases/download/v0.7/antelopev2.zip
  python3 -m zipfile -e /tmp/antelopev2.zip /models/insightface/models/
  # some copies of the zip hold antelopev2/antelopev2/*.onnx
  if [ -d /models/insightface/models/antelopev2/antelopev2 ]; then
    mv /models/insightface/models/antelopev2/antelopev2/* /models/insightface/models/antelopev2/
    rmdir /models/insightface/models/antelopev2/antelopev2
  fi
fi
ls -la /models/insightface/models/antelopev2
echo "INSTANTID SETUP DONE"
