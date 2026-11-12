"""Test sheets for the two new base models (the owner 2026-11-12 ~16:05: "HiDream-I1 Full, HunyuanImage 2.1" + "queue
LoRAs on them and 360 videos"). The same 5 scenes and seeds as she3_check.py (so the sheets compare 1:1 with the other
LoRA families). Strength 0.0 = the base model without a LoRA (first step, before any training); later the LoRA strengths.
  hidream    HiDream-I1 Full fp8 (17B, MIT): QuadrupleCLIPLoader (clip_l, clip_g, t5xxl fp8, llama 3.1 8b fp8), shift 3.0,
             50 steps, cfg 5.0, uni_pc / simple (the ComfyUI example settings for "full"), Flux.1 ae VAE
  hunyuan21  HunyuanImage 2.1 fp8 (17B, Tencent licence, owner: not in the EU): DualCLIPLoader (qwen 2.5 vl 7b fp8, byt5)
             type hunyuan_image, 2K latent (2048x1152; the model is made for 2K, 1K gives faults), 20 steps, cfg 3.5
NOT run yet: node inputs are from the ComfyUI examples; the first run shows if a name differs.
Run inside comfyui:  SHE3_STRENGTHS=0.0 python /opt/tests/newmodel_check.py run <model>
Any container:       python3 /opt/tests/newmodel_check.py sheet <model>   -> series/she3check/base_<model>.jpg / sheet_<model>.jpg
"""
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import she3_check as sc  # noqa: E402

OUT, D = sc.OUT, sc.D
LORA = {"hidream": "slvrareal_hidream.safetensors", "hunyuan21": "slvrareal_hunyuan21.safetensors"}  # after training
NEG = "painting, cartoon, drawing, blurry, deformed face, extra fingers, extra people, watermark, text"


def _lora(wf, model, strength, src):
    if strength > 0:
        wf["lora"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": src, "lora_name": LORA[model],
                                                                       "strength_model": strength}}
        return ["lora", 0]
    return src


def hidream_wf(text, seed, strength, prefix):
    wf = {
        "unet": {"class_type": "UNETLoader", "inputs": {"unet_name": "hidream_i1_full_fp8.safetensors", "weight_dtype": "default"}},
        "clip": {"class_type": "QuadrupleCLIPLoader", "inputs": {
            "clip_name1": "clip_l_hidream.safetensors", "clip_name2": "clip_g_hidream.safetensors",
            "clip_name3": "t5xxl_fp8_e4m3fn_scaled.safetensors", "clip_name4": "llama_3.1_8b_instruct_fp8_scaled.safetensors"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "ae.safetensors"}},
        "pos": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": text}},
        "neg": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": NEG}},
        "latent": {"class_type": "EmptySD3LatentImage", "inputs": {"width": sc.W, "height": sc.H, "batch_size": 1}},
    }
    m = _lora(wf, "hidream", strength, ["unet", 0])
    wf["shift"] = {"class_type": "ModelSamplingSD3", "inputs": {"model": m, "shift": 3.0}}
    wf["sample"] = {"class_type": "KSampler", "inputs": {"model": ["shift", 0], "positive": ["pos", 0], "negative": ["neg", 0],
                    "latent_image": ["latent", 0], "seed": seed, "steps": 50, "cfg": 5.0, "sampler_name": "uni_pc",
                    "scheduler": "simple", "denoise": 1.0}}
    wf["decode"] = {"class_type": "VAEDecode", "inputs": {"samples": ["sample", 0], "vae": ["vae", 0]}}
    wf["save"] = {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": prefix}}
    return wf


def hunyuan21_wf(text, seed, strength, prefix):
    wf = {
        "unet": {"class_type": "UNETLoader", "inputs": {"unet_name": "hunyuanimage2.1_fp8_e4m3fn.safetensors", "weight_dtype": "default"}},
        "clip": {"class_type": "DualCLIPLoader", "inputs": {"clip_name1": "qwen_2.5_vl_7b_fp8_scaled.safetensors",
                 "clip_name2": "byt5_small_glyphxl_fp16.safetensors", "type": "hunyuan_image", "device": "default"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "hunyuan_image_2.1_vae_fp16.safetensors"}},
        "pos": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": text}},
        "neg": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": NEG}},
        "latent": {"class_type": "EmptyHunyuanImageLatent", "inputs": {"width": 2048, "height": 1152, "batch_size": 1}},
    }
    m = _lora(wf, "hunyuan21", strength, ["unet", 0])
    wf["sample"] = {"class_type": "KSampler", "inputs": {"model": m, "positive": ["pos", 0], "negative": ["neg", 0],
                    "latent_image": ["latent", 0], "seed": seed, "steps": 20, "cfg": 3.5, "sampler_name": "euler",
                    "scheduler": "simple", "denoise": 1.0}}
    wf["decode"] = {"class_type": "VAEDecode", "inputs": {"samples": ["sample", 0], "vae": ["vae", 0]}}
    wf["save"] = {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": prefix}}
    return wf


WF = {"hidream": hidream_wf, "hunyuan21": hunyuan21_wf}

# Hunyuan tune (the owner 2026-11-12 21:35 on base_hunyuan21.jpg: "she looks like Gollum - work on it, make it good").
# Seen: pale grey-blue skin, plastic smooth skin, big eyes, a wide child-like face. Suspects: "pale skin" in she3_check
# LOOK, 20 steps instead of the official 50 + shift 5, a short prompt (Hunyuan is made for long, detailed prompts).
# Positive words only. Variants: (prompt, steps, cfg, shift)
LOOK2 = ("slvrareal, a beautiful adult woman in her early twenties with long silver-white hair pulled back from her face, "
         "natural healthy skin tone with a warm complexion, soft natural features")
REAL2 = ("photorealistic photograph taken with a 50mm lens, natural skin texture with fine pores, soft natural light, "
         "true-to-life colours, cinematic film still")
TUNE = {"v1": ("old", 50, 3.5, 5.0), "v2": ("new", 20, 3.5, None), "v3": ("new", 50, 3.5, 5.0),
        "v4": ("new", 50, 5.0, 5.0), "v5": ("new", 30, 3.5, 3.0)}
TUNE_SCENES = ("portrait", "laugh", "angry")
# round 2 (22:55): the new prompt (v2-v5, "adult woman in her early twenties" + silver hair, no "young") drew a woman of
# 40-50 with wrinkles - Hunyuan reads silver hair as age; the old prompt (v1) is young but doll-like and pale.
LOOK3 = ("slvrareal, a beautiful young woman of about twenty-two with long dyed platinum silver-white hair pulled back from "
         "her face, smooth youthful skin with natural texture, natural healthy skin tone")
LOOK4 = sc.LOOK.replace(", pale skin", ", natural healthy skin tone")
PROMPTS2 = {"v6": LOOK3, "v7": LOOK4}
if os.environ.get("TUNE_ROUND") == "2":
    TUNE = {"v1": ("old", 50, 3.5, 5.0), "v6": ("v6", 50, 3.5, 5.0), "v7": ("v7", 50, 3.5, 5.0),
            "v8": ("v6", 50, 5.0, 5.0)}


def tune_prompt(kind, scene):
    if kind == "old":
        return sc.prompt(scene)
    return f"{PROMPTS2.get(kind, LOOK2)}, {scene}, {sc.WEAR}, {REAL2}"


def tune(model="hunyuan21"):
    import episode2 as ep
    for v, (kind, steps, cfg, shift) in TUNE.items():
        for name in TUNE_SCENES:
            scene, seed = sc.SCENES[name]
            prefix = f"{OUT}/{model}_tune/{v}_{name}"
            if ep.newest(f"/data/output/{prefix}_*.png"):
                continue
            wf = hunyuan21_wf(tune_prompt(kind, scene), seed, 0.0, prefix)
            wf["sample"]["inputs"].update({"steps": steps, "cfg": cfg})
            if shift:
                wf["shift"] = {"class_type": "ModelSamplingSD3", "inputs": {"model": ["unet", 0], "shift": shift}}
                wf["sample"]["inputs"]["model"] = ["shift", 0]
            secs, _ = ep.story.run(wf, 1800)
            print(f"newmodel tune {model} {v} {name}: {secs:.1f} s", flush=True)


def tune_sheet(model="hunyuan21"):
    from PIL import Image, ImageDraw
    rows = []
    for name in TUNE_SCENES:
        row = Image.new("RGB", (len(TUNE) * 400, 225 + 20), "black")
        for i, v in enumerate(TUNE):
            f = sorted(glob.glob(f"{D}/{model}_tune/{v}_{name}_*.png"))
            if f:
                row.paste(Image.open(f[-1]).convert("RGB").resize((400, 225)), (400 * i, 0))
        labels = " | ".join(f"{v}: {k} {st}st cfg{c} sh{sh}" for v, (k, st, c, sh) in TUNE.items())
        ImageDraw.Draw(row).text((4, 228), f"{name}: {labels}", fill="white")
        rows.append(row)
    out = Image.new("RGB", (rows[0].width, rows[0].height * len(rows)), "black")
    for i, r in enumerate(rows):
        out.paste(r, (0, r.height * i))
    out.save(f"{D}/tune_{model}{'_r2' if os.environ.get('TUNE_ROUND') == '2' else ''}.jpg", quality=90)
    print(f"newmodel tune sheet {model}", flush=True)


def run(model):
    import episode2 as ep
    for name, (scene, seed) in sc.SCENES.items():
        for s in sc.RUN_STRENGTHS:
            prefix = f"{OUT}/{model}/{name}_{int(s * 100)}"
            if ep.newest(f"/data/output/{prefix}_*.png"):
                continue
            secs, _ = ep.story.run(WF[model](sc.prompt(scene), seed, s, prefix), 1800)
            print(f"newmodel {model} {name} {s}: {secs:.1f} s", flush=True)


def sheet(model):
    """base_<model>.jpg when only strength 0 exists (Gemini ref | base), else sheet_<model>.jpg like she3_check."""
    if not glob.glob(f"{D}/{model}/*_60_*.png"):
        from PIL import Image, ImageDraw
        ref = Image.open(sc.REF).convert("RGB")
        rows = []
        for name in sc.SCENES:
            row = Image.new("RGB", (264 + 480, 264 + 20), "black")
            row.paste(ref.resize((264, 264)), (0, 0))
            f = sorted(glob.glob(f"{D}/{model}/{name}_0_*.png"))
            if f:
                row.paste(Image.open(f[-1]).convert("RGB").resize((480, 264)), (264, 0))
            ImageDraw.Draw(row).text((4, 268), f"{model} {name}: Gemini ref | base, no LoRA", fill="white")
            rows.append(row)
        out = Image.new("RGB", (rows[0].width, rows[0].height * len(rows)), "black")
        for i, r in enumerate(rows):
            out.paste(r, (0, r.height * i))
        out.save(f"{D}/base_{model}.jpg", quality=90)
        print(f"newmodel base sheet {model}", flush=True)
    else:
        sc.sheet(model)


if __name__ == "__main__":
    {"run": run, "sheet": sheet, "tune": tune, "tune_sheet": tune_sheet}[sys.argv[1]](sys.argv[2])
