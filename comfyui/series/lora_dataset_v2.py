"""The second character LoRA "slvra_v2" (the owner, 2026-11-09: keep v1, train another that may keep softer facial
features). 16 picked soft candidates (LoRA v1 at 0.6 + "soft delicate facial features", series/lora_v2_cand/, picked by
eye on lora_v2_cand_sheet.png: c05 seed 5105 left out — a glitched hand), the two approved young-face references and 4
of v1's portraits. The captions do NOT name the softness (so it goes into the trigger), only the look and the scene.
Run inside the container:  python3 /opt/tests/lora_dataset_v2.py   -> /data/output/lora/slvra_v2/ + READY
"""
import glob
import os
import shutil

TRIGGER = "slvra"
LOOK = ("a young woman of about twenty with long straight silver-white hair and one thin golden strand, wearing a "
        "dark-green tunic with brown trim, a brown belt and brown leather bracers")
OUT = "/data/output/lora/slvra_v2"
C = "/data/output/series/lora_v2_cand"
PICKS = {
    "c01_s5101": "close-up portrait, looking at the camera, soft daylight in a forest",
    "c01_s5201": "close-up portrait, looking at the camera, forest light",
    "c02_s5102": "close-up portrait, a gentle small smile, golden hour",
    "c03_s5103": "close-up portrait, head turned three-quarters, forest light",
    "c03_s5203": "half-body portrait, head turned three-quarters, forest",
    "c04_s5104": "close-up portrait in profile, looking right",
    "c04_s5204": "close-up portrait in profile, looking right, forest",
    "c05_s5205": "close-up portrait, looking up at falling snow",
    "c06_s5106": "close-up portrait lit by a campfire at night",
    "c06_s5206": "close-up portrait lit by a campfire at night, sparks",
    "c07_s5107": "half-body, standing in a green summer forest",
    "c08_s5108": "half-body, standing by a waterfall in a cave",
    "c09_s5109": "half-body, standing in a dead winter forest, grey sky",
    "c10_s5110": "half-body, sitting on a fur by a campfire",
    "c11_s5111": "half-body, looking over her shoulder at a sunset",
    "c12_s5112": "close-up, a worried face, dark forest",
}
STYLE_SOFT = "painterly cinematic fantasy illustration"
STYLE_ARCANE = "painted Arcane animation style"


def put(src, name, caption):
    dst = f"{OUT}/{name}.png"
    shutil.copyfile(src, dst)
    with open(f"{OUT}/{name}.txt", "w") as f:
        f.write(f"{TRIGGER}, {LOOK}, {caption}")


def main():
    os.makedirs(OUT, exist_ok=True)
    for key, scene in PICKS.items():
        src = sorted(glob.glob(f"{C}/{key}_*.png"))[-1]
        put(src, key, f"{scene}, {STYLE_SOFT}")
    v1 = "/data/output/lora/slvra"
    put(f"{v1}/001_face_a.png", "face_a", f"close-up of her face, lying on a fur bedroll, looking up, {STYLE_ARCANE}")
    put(f"{v1}/002_face_b.png", "face_b", f"close-up of her face, lying on a fur bedroll, looking aside, {STYLE_ARCANE}")
    for p, scene in (("101_portrait_front", "close-up portrait, facing the camera"),
                     ("105_portrait_smile", "close-up portrait, a soft small smile"),
                     ("108_portrait_look_up", "close-up portrait, looking up at the sky"),
                     ("102_portrait_three_quarter_left", "close-up portrait, head turned three-quarters to the left")):
        put(f"{v1}/{p}.png", p, f"{scene}, {STYLE_ARCANE}")
    n = len(glob.glob(f"{OUT}/*.png"))
    open(f"{OUT}/READY", "w").write(f"{n} pictures\n")
    print(f"slvra_v2 dataset: {n} pictures, READY", flush=True)


if __name__ == "__main__":
    main()
