#!/usr/bin/env bash
# Start ComfyUI with all state in the volumes (/data, /models, /cache). Extra arguments go to main.py.
# Two test knobs, read from the environment only (tests/test_comfy.sh, IM3-IM5): R9700_TEST_COMFY_ROOT (default empty) is put in front of /data, /models and /cache everywhere,
# the main.py arguments included (the path of main.py is the image's and takes no root); R9700_TEST_ENTRY_DRY=1 prints the final argv, one word per line, instead of the exec.
set -euo pipefail

ROOT="${R9700_TEST_COMFY_ROOT:-}"
DATA="$ROOT/data" MODELS="$ROOT/models" CACHE="$ROOT/cache"

mkdir -p "$DATA/custom_nodes" "$DATA/user" "$DATA/input" "$DATA/output" "$DATA/temp" "$CACHE/miopen" "$CACHE/triton"
for d in checkpoints loras vae text_encoders diffusion_models clip_vision controlnet upscale_models embeddings \
         audio_encoders latent_upscale_models model_patches; do
  mkdir -p "$MODELS/$d"
done

# The venv for custom-node packages: it sees the image's packages (torch, ROCm, ComfyUI's own) and adds its own.
# If the image's Python changed since the venv was made, the old venv is moved aside (not deleted) and a new one made;
# the custom nodes' packages then need a reinstall (Manager: "Install missing" / "Fix").
want="$(python3 -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])')"
if [ -f "$DATA/venv/pyvenv.cfg" ]; then
  have="$(sed -n 's/^version *= *//p' "$DATA/venv/pyvenv.cfg")"
  if [ "$have" != "$want" ]; then
    aside="$DATA/venv.python-$have.$(date -u +%Y%m%dT%H%M%SZ)"
    echo "entrypoint: the venv was made with Python $have, the image has $want; moving it to $aside" >&2
    mv "$DATA/venv" "$aside"
  fi
fi
if [ ! -x "$DATA/venv/bin/python" ]; then
  echo "entrypoint: making $DATA/venv (--system-site-packages, Python $want)" >&2
  python3 -m venv --system-site-packages "$DATA/venv"
fi

# The Manager must use pip, not uv: `uv pip list` in a --system-site-packages venv lists only the venv, so the Manager
# then reports "PyTorch is not installed" and reinstalls the image's packages (comfyui-frontend-package) into the venv,
# where they would shadow the image's newer copies after a rebuild. Set on every start.
cfg="$DATA/user/__manager/config.ini"
mkdir -p "$(dirname "$cfg")"
if [ ! -f "$cfg" ]; then
  printf '[default]\nuse_uv = False\n' > "$cfg"
elif grep -q '^use_uv *=' "$cfg"; then
  sed -i 's/^use_uv *=.*/use_uv = False/' "$cfg"
else
  sed -i 's/^\[default\]$/[default]\nuse_uv = False/' "$cfg"
fi

argv=("$DATA/venv/bin/python" /opt/ComfyUI/main.py
  --listen 0.0.0.0 --port 8188
  --base-directory "$DATA"
  --models-directory "$MODELS"
  --enable-manager
  "$@")
if [ "${R9700_TEST_ENTRY_DRY:-}" = 1 ]; then
  printf '%s\n' "${argv[@]}"
  exit 0
fi
exec "${argv[@]}"
