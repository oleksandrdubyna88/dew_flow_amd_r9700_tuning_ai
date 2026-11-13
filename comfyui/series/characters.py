"""Test keyframes of original characters with set 2's image model (Qwen-Image 2512 fp8 + Lightning 4-step).

Run inside the container:  wslc exec comfyui python /opt/tests/characters.py [lyriel|kaelith ...] [--seeds 11,22,33,44]
Writes /data/output/series/characters/<name>_<view>_seed<seed>_*.png. The characters are ORIGINAL (inspired by the costume
world of a TV series), never a likeness of a real person.
"""
import argparse
import os
import sys

os.environ["SERIES"] = "elf_set2"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import series_elf as story  # noqa: E402

EARS = "small rounded human ears, partly covered by the hair, the upper rim of each ear ending in a tiny gentle point"
# The words "elf" and "elven" lengthen the ears (cfg 1: no negative prompt), so "lyriel_small_ears" never uses them.
WORLD = ("post-apocalyptic fantasy world, overgrown ruins of an ancient lost civilisation in a green forest, soft warm "
         "cinematic light, cinematic film still, photorealistic, highly detailed, 35mm, shallow depth of field")
CHARS = {
    "lyriel": ("a young elven princess with a soft oval face, a gently rounded chin, light high cheekbones, large almond-shaped "
               "warm hazel-green eyes, straight fine eyebrows, a small straight nose, full lips, a few faint freckles across the "
               f"nose, long chestnut-brown softly wavy hair with two thin braids from the temples tied back with a small silver "
               f"leaf clasp, {EARS}, slim light runner's build, wearing a fitted moss-green and cream travel tunic with leaf "
               "embroidery at the collar, a hooded grey-green cloak, a soft leather belt with a small pouch, leggings and "
               "knee-high boots"),
    "lyriel_small_ears": ("an adult princess, a grown woman in her mid-twenties with mature adult features, a soft oval face, a gently rounded chin, light high cheekbones, large almond-shaped "
                          "warm hazel-green eyes, straight fine eyebrows, a small straight nose, full lips, a few faint freckles across "
                          "the nose, a woman's figure, long chestnut-brown softly wavy hair with two thin braids from the temples tied back with a small "
                          f"silver leaf clasp, {EARS}, slim light runner's build, wearing a fitted moss-green and cream travel tunic with "
                          "leaf embroidery at the collar, a hooded grey-green cloak, a soft leather belt with a small pouch, leggings and "
                          "knee-high boots"),
    "kaelith": ("a young rover elf woman with a heart-shaped face, a narrow defined jaw, sharp high cheekbones, slightly hooded "
                "dark-brown eyes with a sly watchful look, thick dark expressive arched eyebrows, a straight slightly upturned "
                "nose, warm olive skin, a small old scar through one eyebrow, very dark almost black long hair with loose braids "
                f"woven with small bronze rings and beads, {EARS}, a small bronze cuff on one ear, athletic agile build, wearing a "
                "worn dark leather vest over a rust-red shirt, crossed belts with a knife sheath, fingerless gloves, a long "
                "patterned scarf, dark trousers and scuffed boots"),
}
VIEWS = {
    "portrait": "Medium close-up portrait of {c}, looking slightly past the camera with a calm determined expression. {w}",
    "run": "Wide shot of {c}, running toward the camera along a narrow overgrown forest path between mossy ruins. {w}",
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*", default=list(CHARS))
    ap.add_argument("--seeds", default="11,22,33,44")
    a = ap.parse_args()
    for name in a.names:
        for view, text in VIEWS.items():
            for seed in [int(s) for s in a.seeds.split(",")]:
                shot = {"key": text.format(c=CHARS[name], w=WORLD), "seed": seed}
                wf = story.qwen_keyframe_wf(1, shot)
                wf["save"]["inputs"]["filename_prefix"] = f"series/characters/{name}_{view}_seed{seed}"
                secs, files = story.run(wf, 900)
                print(f"{name} {view} seed {seed}: {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


if __name__ == "__main__":
    main()
