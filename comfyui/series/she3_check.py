"""Test of the LoRA v3 family trained on lora/slvrareal3 (37 pictures: 26 Gemini + 11 chosen by the owner, 2026-11-12):
the same 5 scenes x strength 0.6 / 0.8 / 1.0 for each base model, so the owner can compare them in the morning.
  qwen  : Qwen-Image 2512 keyframe graph + slvrareal3.safetensors (story.qwen_keyframe_wf, as real2_check)
  flux2 : FLUX.2 klein 4B distilled (4 steps) + slvrareal3_flux2k4b.safetensors (trained on klein base 4B)
  sdxl  : RealVisXL V5.0 + slvrareal3_sdxl.safetensors
Scenes test the face, the emotions (the dataset is full of them) and how far the pose/forest of the Gemini set leaks.
Run inside comfyui:  python /opt/tests/she3_check.py <qwen|flux2|sdxl>
Any container:       python3 /opt/tests/she3_check.py sheet <qwen|flux2|sdxl>   -> series/she3check/sheet_<model>.jpg
"""
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

OUT = "series/she3check"
D = f"/data/output/{OUT}"
STRENGTHS = (0.6, 0.8, 1.0)
RUN_STRENGTHS = tuple(float(x) for x in os.environ.get("SHE3_STRENGTHS", "0.6,0.8,1.0").split(","))  # 0.0 = no-LoRA baseline
LOOK = ("slvrareal, a young woman of about twenty-five with long silver-white hair pulled back from her face, a slim face "
        "with high cheekbones, grey-green eyes, thin dark eyebrows, pale skin")
WEAR = "wearing a dark-green wool tunic with a brown leather strap across her chest and brown leather bracers"
REAL = "photorealistic, natural skin texture, 35mm film still"
SCENES = {
    "portrait": ("a calm expression, front view, looking at the camera, sitting on the forest floor in a pine forest", 4801),
    "laugh": ("laughing happily, close-up, standing in a sunlit meadow with flowers", 4802),
    "angry": ("an angry expression with knitted eyebrows, medium shot, standing in a rainy village street", 4803),
    "castle": ("full body, three-quarter view, walking through a stone castle hall lit by torches", 4804),
    "campfire": ("a thoughtful expression, three-quarter view, sitting by a campfire at night, looking into the fire", 4805),
}
REF = "/data/output/lora/slvrareal3/she3_gsp9bp.png"
LORA = {"qwen": "slvrareal3.safetensors", "flux2": "slvrareal3_flux2k4b.safetensors", "flux2k9": "slvrareal3_flux2k9b.safetensors", "sdxl": "slvrareal3_sdxl.safetensors"}
W, H = 1280, 704


def prompt(scene):
    return f"{LOOK}, {scene}, {WEAR}, {REAL}"


def flux2_wf(text, seed, strength, prefix, size="4b"):
    """size 9b = model flux2k9 (owner 2026-11-12: \"then the Flux 9B LoRA\"): klein 9B distilled + Qwen3 8B."""
    return {
        "unet": {"class_type": "UNETLoader", "inputs": {"unet_name": f"flux-2-klein-{size}.safetensors", "weight_dtype": "default"}},
        "lora": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["unet", 0], "lora_name": LORA["flux2k9" if size == "9b" else "flux2"],
                                                                  "strength_model": strength}},
        "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_3_8b.safetensors" if size == "9b" else "qwen_3_4b.safetensors", "type": "flux2",
                                                        "device": "default"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "flux2-vae.safetensors"}},
        "pos": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": text}},
        "guider": {"class_type": "BasicGuider", "inputs": {"model": ["lora", 0], "conditioning": ["pos", 0]}},
        "noise": {"class_type": "RandomNoise", "inputs": {"noise_seed": seed}},
        "ksel": {"class_type": "KSamplerSelect", "inputs": {"sampler_name": "euler"}},
        "sigmas": {"class_type": "Flux2Scheduler", "inputs": {"steps": 4, "width": W, "height": H}},
        "latent": {"class_type": "EmptyFlux2LatentImage", "inputs": {"width": W, "height": H, "batch_size": 1}},
        "sample": {"class_type": "SamplerCustomAdvanced", "inputs": {"noise": ["noise", 0], "guider": ["guider", 0],
                   "sampler": ["ksel", 0], "sigmas": ["sigmas", 0], "latent_image": ["latent", 0]}},
        "decode": {"class_type": "VAEDecode", "inputs": {"samples": ["sample", 0], "vae": ["vae", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": prefix}},
    }


def sdxl_wf(text, seed, strength, prefix):
    return {
        "ckpt": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "RealVisXL_V5.0_fp16.safetensors"}},
        "lora": {"class_type": "LoraLoader", "inputs": {"model": ["ckpt", 0], "clip": ["ckpt", 1], "lora_name": LORA["sdxl"],
                                                        "strength_model": strength, "strength_clip": strength}},
        "pos": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["lora", 1], "text": text}},
        "neg": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["lora", 1],
                "text": "painting, cartoon, drawing, blurry, deformed face, extra fingers, watermark, text"}},
        "latent": {"class_type": "EmptyLatentImage", "inputs": {"width": 1216, "height": 704, "batch_size": 1}},
        "sample": {"class_type": "KSampler", "inputs": {"model": ["lora", 0], "positive": ["pos", 0], "negative": ["neg", 0],
                   "latent_image": ["latent", 0], "seed": seed, "steps": 30, "cfg": 5.0, "sampler_name": "dpmpp_2m",
                   "scheduler": "karras", "denoise": 1.0}},
        "decode": {"class_type": "VAEDecode", "inputs": {"samples": ["sample", 0], "vae": ["ckpt", 2]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": prefix}},
    }


def run(model):
    import episode2 as ep
    for name, (scene, seed) in SCENES.items():
        for s in RUN_STRENGTHS:
            prefix = f"{OUT}/{model}/{name}_{int(s * 100)}"
            if ep.newest(f"/data/output/{prefix}_*.png"):
                continue
            if model == "qwen":
                import real2_check as rc
                secs = rc.keyframe("slvrareal3", s, prompt(scene), seed, prefix)
            else:
                if model == "flux2k9":
                    wf = flux2_wf(prompt(scene), seed, s, prefix, "9b")
                else:
                    wf = (flux2_wf if model == "flux2" else sdxl_wf)(prompt(scene), seed, s, prefix)
                secs, _ = ep.story.run(wf, 900)
            print(f"she3check {model} {name} {s}: {secs:.1f} s", flush=True)


def sheet(model):
    from PIL import Image, ImageDraw
    ref = Image.open(REF).convert("RGB")
    rows = []
    for name in SCENES:
        row = Image.new("RGB", (4 * 480, 264 + 20), "black")
        row.paste(ref.resize((264, 264)), (108, 0))
        for i, s in enumerate(STRENGTHS, 1):
            f = sorted(glob.glob(f"{D}/{model}/{name}_{int(s * 100)}_*.png"))
            if f:
                row.paste(Image.open(f[-1]).convert("RGB").resize((480, 264)), (480 * i, 0))
        ImageDraw.Draw(row).text((4, 268), f"{model} {name}: Gemini ref | 0.6 | 0.8 | 1.0", fill="white")
        rows.append(row)
    out = Image.new("RGB", (rows[0].width, rows[0].height * len(rows)), "black")
    for i, r in enumerate(rows):
        out.paste(r, (0, r.height * i))
    out.save(f"{D}/sheet_{model}.jpg", quality=90)
    print(f"she3check sheet {model}: {len(rows)} rows", flush=True)



def base_sheet(model):
    """No-LoRA check (04:25): strength 0.0 | 0.7 | 1.0 per scene -> series/she3check/base_<model>.jpg."""
    from PIL import Image, ImageDraw
    rows = []
    for name in SCENES:
        row = Image.new("RGB", (3 * 480, 264 + 20), "black")
        for i, s in enumerate((0.0, 0.7, 1.0)):
            f = sorted(glob.glob(f"{D}/{model}/{name}_{int(s * 100)}_*.png"))
            if f:
                row.paste(Image.open(f[-1]).convert("RGB").resize((480, 264)), (480 * i, 0))
        ImageDraw.Draw(row).text((4, 268), f"{model} {name}: no LoRA | 0.7 | 1.0", fill="white")
        rows.append(row)
    out = Image.new("RGB", (rows[0].width, rows[0].height * len(rows)), "black")
    for i, r in enumerate(rows):
        out.paste(r, (0, r.height * i))
    out.save(f"{D}/base_{model}.jpg", quality=90)
    print(f"she3check base sheet {model}", flush=True)


if __name__ == "__main__":
    if sys.argv[1] == "base":
        base_sheet(sys.argv[2])
    elif sys.argv[1] == "sheet":
        sheet(sys.argv[2])
    else:
        run(sys.argv[1])
