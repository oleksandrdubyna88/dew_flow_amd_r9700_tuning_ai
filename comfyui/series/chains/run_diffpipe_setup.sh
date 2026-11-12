#!/usr/bin/env bash
# diffusion-pipe (tdrussell) for LoRAs on HiDream-I1 and HunyuanImage 2.1 (the owner 2026-11-12 ~16:05: "queue LoRAs on
# them and 360 videos"; "prepare what is needed in parallel"). musubi-tuner has neither (only HiDream-O1); diffusion-pipe
# lists both (models/hidream.py, models/hunyuan_image.py). Into the lora-env volume only (rule: pip only inside a wslc
# volume/venv): /lora/diffusion-pipe + /lora/venv_dp. Like venv_sd: system site packages (the image's ROCm torch) + a
# constraint that pins torch/torchvision to the installed ROCm build, so pip never pulls a CUDA torch. deepspeed with
# DS_BUILD_OPS=0 (no compiled ops; diffusion-pipe needs only its pipeline engine). bitsandbytes is skipped (CUDA build).
# NOT checked yet: deepspeed's single-GPU process group on ROCm under WSL (RCCL over dxg) — the first train run shows it.
# Network + pip only, no GPU. Logs to diffpipe_setup.log ("DPSETUP DONE").
set -u
DIR="$(dirname "$0")"; LOG="$DIR/diffpipe_setup.log"
echo "setup start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name dp-setup -v lora-env:/lora --entrypoint bash comfyui-r9700:local -c 'set -e; cd /lora
[ -d diffusion-pipe ] || git clone -q --recurse-submodules https://github.com/tdrussell/diffusion-pipe.git
cd diffusion-pipe; git log -1 --format=\"diffusion-pipe %h %cd\"
[ -d /lora/venv_dp ] || python3 -m venv --system-site-packages /lora/venv_dp
python3 -c \"import torch, torchvision; print(\\\"torch==\\\"+torch.__version__); print(\\\"torchvision==\\\"+torchvision.__version__)\" > /tmp/cons.txt
cat /tmp/cons.txt
grep -v -i -E \"^(torch|torchvision|bitsandbytes|wandb)([=<> ]|$)\" requirements.txt > /tmp/req.txt
DS_BUILD_OPS=0 /lora/venv_dp/bin/pip install -q --disable-pip-version-check -c /tmp/cons.txt -r /tmp/req.txt 2>&1 | tail -8
/lora/venv_dp/bin/python -c \"import torch, deepspeed, transformers, diffusers, peft; print(\\\"ok torch\\\", torch.__version__, torch.version.hip, \\\"deepspeed\\\", deepspeed.__version__, \\\"diffusers\\\", diffusers.__version__)\"
ls /lora/diffusion-pipe/train.py /lora/diffusion-pipe/models/hidream.py /lora/diffusion-pipe/models/hunyuan_image.py'" 2>&1 | tr -d '\r' >> "$LOG"
grep -q "hunyuan_image.py" "$LOG" && grep -q "ok torch" "$LOG" && echo "DPSETUP DONE $(date +%H:%M)" >> "$LOG" || echo "DPSETUP FAILED $(date +%H:%M)" >> "$LOG"
