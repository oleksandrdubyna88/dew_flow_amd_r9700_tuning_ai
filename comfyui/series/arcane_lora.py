"""Restyle the set-2 keyframes with an Arcane style LoRA on Z-Image Turbo (img2img), as a grid of LoRA strength x denoise.

Run inside the container:  wslc exec comfyui python /opt/tests/arcane_lora.py [--shots 1,3] [--strengths 0.7,1.0] [--denoise 0.55,0.7]
Reads /data/input/elf_set2_key_s<k>.png (shot 2: the re-rolled seed-2202 keyframe); writes
/data/output/series/elf_set2_arcane/key_s<k>_l<strength>_d<denoise>_*.png. The set-2 prompts are used without their photo
style words, so the LoRA (no trigger word) sets the style.
"""
import argparse
import os
import sys

os.environ["SERIES"] = "elf_set2"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import series_elf as story  # noqa: E402

LORA = "z_image_arcane_v1.safetensors"
OUT = "series/elf_set2_arcane"


def source_name(k):
    return "elf_set2_reroll_s2_seed2202.png" if k == 2 else f"elf_set2_key_s{k}.png"


def graph(k, strength, denoise):
    shot = story.SHOTS[k - 1]
    prompt = shot["key"].replace(story.STYLE_V2, "").strip() + " Arcane style."
    wf = story._keyframe_wf(k, dict(shot, key=prompt))
    wf["lora"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["unet", 0], "lora_name": LORA, "strength_model": strength}}
    wf["shift"]["inputs"]["model"] = ["lora", 0]
    wf["src"] = {"class_type": "LoadImage", "inputs": {"image": source_name(k)}}
    wf["enc"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["src", 0], "vae": ["vae", 0]}}
    wf["sampler"]["inputs"].update({"latent_image": ["enc", 0], "denoise": denoise})
    wf["save"]["inputs"]["filename_prefix"] = f"{OUT}/key_s{k}_l{int(strength * 100)}_d{int(denoise * 100)}"
    return wf


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shots", default="1,3")
    ap.add_argument("--strengths", default="0.7,1.0")
    ap.add_argument("--denoise", default="0.55,0.7")
    a = ap.parse_args()
    for k in [int(x) for x in a.shots.split(",")]:
        for s in [float(x) for x in a.strengths.split(",")]:
            for d in [float(x) for x in a.denoise.split(",")]:
                secs, files = story.run(graph(k, s, d), 900)
                print(f"shot {k} lora {s} denoise {d}: {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


if __name__ == "__main__":
    main()
