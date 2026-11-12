"""Test of ComfyUI's built-in LoRA training (TrainLoraNode) on our AMD R9700 (the owner 2026-11-12 ~23:59: "ComfyUI has
the built-in TrainLoraNode, so you can train in the UI - check it on our AMD card and set it up").
Graph (all core nodes): LoadImageTextDataSetFromFolder (input/<folder>: png + same-name txt captions) -> ImageScale to one
size (no bucket node here) -> MakeTrainingDataset (VAE + CLIP) -> TrainLoraNode on FLUX.2 klein BASE 4B (the training
base musubi used) -> SaveLoRA + LossGraphNode. Then one test picture with the new LoRA on the distilled klein 4B
(LoraLoaderModelOnly reads the saved file, as for the musubi LoRA).
Run inside comfyui:  python /opt/tests/comfy_train_test.py prep     (in a container with the output + input mounts:
                     copies lora/slvrareal5/r*/ into input/slvrareal5_flat)
                     python /opt/tests/comfy_train_test.py train [steps]
                     python /opt/tests/comfy_train_test.py dump  -> series/workflows/train_lora_flux2k4b_api.json (UI)
"""
import glob
import json
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

FOLDER = "slvrareal5_flat"
SIZE = 768
NAME = "comfytrain_slvrareal5_flux2k4b"


def prep():
    dst = f"/data/input/{FOLDER}"
    os.makedirs(dst, exist_ok=True)
    n = 0
    for f in sorted(glob.glob("/data/output/lora/slvrareal5/r*_*/*.png")):
        base = os.path.splitext(f)[0]
        for ext in (".png", ".txt"):
            out = os.path.join(dst, os.path.basename(base) + ext)
            if not os.path.exists(out):
                shutil.copyfile(base + ext, out)
        n += 1
    print(f"comfytrain prep: {n} pictures -> input/{FOLDER}", flush=True)


def train_wf(steps):
    return {
        "data": {"class_type": "LoadImageTextDataSetFromFolder", "inputs": {"folder": FOLDER}},
        "scale": {"class_type": "ImageScale", "inputs": {"image": ["data", 0], "upscale_method": "lanczos",
                                                         "width": SIZE, "height": SIZE, "crop": "center"}},
        "unet": {"class_type": "UNETLoader", "inputs": {"unet_name": "flux-2-klein-base-4b.safetensors", "weight_dtype": "default"}},
        "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_3_4b.safetensors", "type": "flux2", "device": "default"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "flux2-vae.safetensors"}},
        "ds": {"class_type": "MakeTrainingDataset", "inputs": {"images": ["scale", 0], "vae": ["vae", 0], "clip": ["clip", 0],
                                                               "texts": ["data", 1]}},
        "train": {"class_type": "TrainLoraNode", "inputs": {
            "model": ["unet", 0], "latents": ["ds", 0], "positive": ["ds", 1], "batch_size": 1,
            "grad_accumulation_steps": 1, "steps": steps, "learning_rate": 0.0001, "rank": 16, "optimizer": "AdamW",
            "loss_function": "MSE", "seed": 42, "training_dtype": "bf16", "lora_dtype": "bf16",
            "quantized_backward": False, "algorithm": "LoRA", "gradient_checkpointing": True, "checkpoint_depth": 1,
            "offloading": False, "existing_lora": "[None]", "bucket_mode": False, "bypass_mode": False}},
        "save": {"class_type": "SaveLoRA", "inputs": {"lora": ["train", 0], "prefix": f"loras/{NAME}", "steps": ["train", 2]}},
        "loss": {"class_type": "LossGraphNode", "inputs": {"loss": ["train", 1], "filename_prefix": f"lora/comfytrain/{NAME}_loss"}},
    }


def train(steps):
    import episode2 as ep
    secs, files = ep.story.run(train_wf(steps), 7200)
    print(f"comfytrain {steps} steps: {secs:.1f} s ({secs / steps:.2f} s/step) -> {[f['filename'] for f in files]}",
          flush=True)


def dump():
    os.makedirs("/data/output/series/workflows", exist_ok=True)
    with open("/data/output/series/workflows/train_lora_flux2k4b_api.json", "w") as f:
        json.dump(train_wf(1200), f, indent=1)
    print("comfytrain workflow dumped", flush=True)


if __name__ == "__main__":
    act = sys.argv[1]
    if act == "prep":
        prep()
    elif act == "train":
        train(int(sys.argv[2]) if len(sys.argv) > 2 else 100)
    else:
        dump()
