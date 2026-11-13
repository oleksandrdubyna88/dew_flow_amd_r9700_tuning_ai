#!/usr/bin/env bash
# kohya sd-scripts for an SDXL LoRA (the owner 2026-11-12 ~01:30: "Stable Diffusion too"; "you may install in WSL what is
# needed"). Into the lora-env volume only (rule: pip only inside a wslc volume/venv): /lora/sd-scripts + /lora/venv_sd.
# venv_sd reuses the ROCm torch of /lora/venv through a .pth file (no second 4 GB torch download); sd-scripts' own pinned
# packages go into venv_sd and win over /lora/venv's. 01:10: the 1st run failed — torch is in the image's system packages
# (/usr/local/lib/python3.12/dist-packages), so venv_sd needs system site packages like /lora/venv. My 2nd run was denied
# by the auto-mode check ("Code from External"); the owner runs it. Network + pip only, no GPU. Logs to sdscripts_setup.log.
set -u
DIR="$(dirname "$0")"; LOG="$DIR/sdscripts_setup.log"
echo "setup start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name sd-setup -v lora-env:/lora --entrypoint bash comfyui-r9700:local -c 'set -e; cd /lora
[ -d sd-scripts ] || git clone -q --depth 1 https://github.com/kohya-ss/sd-scripts.git
cd sd-scripts; git log -1 --format=\"sd-scripts %h %cd\"
[ -d /lora/venv_sd ] || python3 -m venv --system-site-packages /lora/venv_sd
sed -i \"s/^include-system-site-packages = false/include-system-site-packages = true/\" /lora/venv_sd/pyvenv.cfg
echo /lora/venv/lib/python3.12/site-packages > /lora/venv_sd/lib/python3.12/site-packages/zz_lora_venv.pth
grep -v -i -E \"^(torch|torchvision|xformers)\" requirements.txt > /tmp/req.txt
/lora/venv_sd/bin/pip install -q --disable-pip-version-check -r /tmp/req.txt 2>&1 | tail -5
/lora/venv_sd/bin/python -c \"import torch, transformers, diffusers, accelerate; print(\\\"ok torch\\\", torch.__version__, torch.version.hip, \\\"transformers\\\", transformers.__version__, \\\"diffusers\\\", diffusers.__version__)\"
ls /lora/sd-scripts/sdxl_train_network.py'" 2>&1 | tr -d '\r' >> "$LOG"
grep -q "sdxl_train_network.py" "$LOG" && grep -q "ok torch" "$LOG" && echo "SDSETUP DONE $(date +%H:%M)" >> "$LOG" || echo "SDSETUP FAILED $(date +%H:%M)" >> "$LOG"
