"""LoRA v3 dataset from the owner's Gemini pictures (2026-11-12 ~01:00: "finish what you started, then make a new LoRA from
these pictures" + "everything in the owner's picture folder"). 23 pictures 2048 px (copied to lora/she_gemini_src); one of them
(dvfmc0, 1568x2716) is a 4-panel collage -> 4 crops. All: sitting on the forest floor in a pine forest, the dark-green
tunic, bracers, many emotions. Resized to 1024 on the long side (the trainer bucket area is 1024x576 = 768x768 square).
Captions: the trigger + her look + the emotion/view of each picture (read by eye from she_gemini_sheet.jpg).
Run in any container with PIL:  python3 /opt/tests/she3_dataset.py   -> /data/output/lora/slvrareal3/*.png + *.txt
"""
import glob
import os

from PIL import Image

SRC = "/data/output/lora/she_gemini_src"
OUT = "/data/output/lora/slvrareal3"
LOOK = ("slvrareal, a young woman of about twenty-five with long silver-white hair pulled back from her face, a slim face "
        "with high cheekbones, grey-green eyes, thin dark eyebrows, pale skin")
WEAR = "wearing a dark-green wool tunic with a brown leather strap across her chest and brown leather bracers"
PLACE = "sitting on the forest floor in a pine forest with fallen leaves, soft daylight"
REAL = "photorealistic, natural skin texture, 35mm film still"
# file key -> (emotion/expression, view)
SHOTS = {
    "25xoej": ("a calm serious expression", "three-quarter view, looking to the left"),
    "2brjhz": ("a frowning, worried expression", "three-quarter view, looking to the right"),
    "2d6fcr": ("laughing playfully with her tongue out", "three-quarter view, looking to the left"),
    "34yeds": ("a wide happy smile", "three-quarter view, looking to the right"),
    "36z6oe": ("a surprised expression with her mouth open and raised eyebrows", "front view, looking at the camera"),
    "4vfjt7": ("a calm thoughtful expression", "three-quarter view, looking to the right"),
    "87ckvj": ("a big bright smile", "three-quarter view, looking to the left"),
    "eha88s": ("an angry expression with knitted eyebrows", "front view, looking at the camera"),
    "gsp9bp": ("a calm neutral expression", "front view, looking at the camera"),
    "jiq80r": ("a sly smile", "front view, leaning forward, looking at the camera, her hands clasped"),
    "jocbhr": ("a confident smirk", "front view, leaning forward, looking at the camera"),
    "ker9u2": ("laughing with her eyes squinting", "front view"),
    "m6rwzp": ("a soft gentle smile", "side view, looking to the right"),
    "p2v8ua": ("a shocked expression with her mouth open", "three-quarter view, looking to the left"),
    "pxsy47": ("laughing happily", "front view, looking at the camera"),
    "q8l9y2": ("a suspicious frowning expression", "three-quarter view, looking to the right"),
    "rct393": ("a slight smile", "side view, looking to the left"),
    "rzppta": ("laughing", "three-quarter view, looking to the left"),
    "tnl4xy": ("a serious focused expression", "side view, looking to the right"),
    "vqnz5o": ("a slight smile", "three-quarter view, looking to the left"),
    "wbneyd": ("a calm expression with a hint of a smile", "front view, looking at the camera"),
    "y049cu": ("a happy smile", "three-quarter view, looking to the right"),
}
# the collage dvfmc0 (1568x2716): two panels on top, two full-width panels below
COLLAGE = {
    "dvfmc0a": ((0, 0, 780, 896), "a calm serious expression", "three-quarter view, looking to the left"),
    "dvfmc0b": ((788, 0, 1568, 896), "a calm serious expression", "three-quarter view, looking to the right"),
    "dvfmc0c": ((0, 912, 1568, 1800), "an intense focused expression", "front view, leaning forward, looking at the camera"),
    "dvfmc0d": ((0, 1816, 1568, 2716), "a calm expression", "front view, looking slightly up past the camera"),
}


# 01:15 the owner pasted the paths of the 12 chat pictures (lora_v2_cand/c01_s5201 = lora/slvra_v2/c01_s5201, the same
# file -> 11). They keep their size (1280x704). key -> (path, words after LOOK: mood/view/hair, outfit, place, style)
GOLD = "one thin golden strand in her hair"
ART = "highly detailed realistic digital art, cinematic light"
O = "/data/output"
EXTRA = {
    "x_rf50_portrait": (f"{O}/series/lora_test/realface_slvra_v1_50_portrait_00001_.png",
                        f"a calm expression with a hint of a smile, front view, looking at the camera, {GOLD}, {WEAR}, "
                        f"sitting in a forest with her arms resting on her knees, {REAL}"),
    "x_rf70_portrait": (f"{O}/series/lora_test/realface_slvra_v1_70_portrait_00001_.png",
                        f"a calm serious expression, front view, looking at the camera, {GOLD}, {WEAR}, sitting in a forest "
                        f"with her arms resting on her knee, {REAL}"),
    "x_v150_portrait": (f"{O}/series/lora_test/slvra_v1_50_portrait_00001_.png",
                        f"a calm expression, front view, looking at the camera, {GOLD}, {WEAR}, sitting in a forest with "
                        f"her arms resting on her knees, {ART}"),
    "x_v170_campfire": (f"{O}/series/lora_test/slvra_v1_70_campfire_00001_.png",
                        f"a calm thoughtful expression, front view, {GOLD}, {WEAR}, sitting by a campfire in a dark forest "
                        f"at night, {ART}"),
    "x_c01_s5101": (f"{O}/series/lora_v2_cand/c01_s5101_00001_.png",
                    f"a soft smile, close-up, front view, looking at the camera, {GOLD}, {WEAR}, sunlit forest, {ART}"),
    "x_c01_s5201": (f"{O}/series/lora_v2_cand/c01_s5201_00001_.png",
                    f"a calm gentle smile, close-up, front view, looking at the camera, {GOLD}, {WEAR}, sunlit forest, "
                    f"{ART}"),
    "x_c04_s5204": (f"{O}/series/lora_v2_cand/c04_s5204_00001_.png",
                    f"a soft dreamy expression, side view, looking to the right, golden strands braided in her hair, "
                    f"{WEAR}, dark forest, {ART}"),
    "x_c05_s5105": (f"{O}/series/lora_v2_cand/c05_s5105_00001_.png",
                    f"a look of wonder, looking up, one hand raised, {GOLD}, {WEAR}, by a waterfall in falling snow, {ART}"),
    "x_c04_s5104": (f"{O}/lora/slvra_v2/c04_s5104.png",
                    f"a calm thoughtful expression, side view, looking to the right, {GOLD}, {WEAR}, dark forest, {ART}"),
    "x_tunic_back": (f"{O}/lora/slvrareal_tunic/tunic_back_l7_s6202.png",
                     f"full body seen from behind, walking toward a castle gate, {GOLD}, wearing a dark-green wool tunic "
                     f"with a brown leather belt and brown leather bracers, {REAL}"),
    "x_tunic_threeq": (f"{O}/lora/slvrareal_tunic/tunic_threeq_l7_s6101.png",
                       f"a calm expression, close-up, head turned three-quarters to the left, {GOLD}, {WEAR}, cool "
                       f"morning light, {REAL}"),
}


def save(im, key, mood, view, text=None, resize=True):
    im = im.convert("RGB")
    if resize:
        im.thumbnail((1024, 1024), Image.LANCZOS)
    im.save(f"{OUT}/she3_{key}.png")
    with open(f"{OUT}/she3_{key}.txt", "w") as f:
        f.write(text or f"{LOOK}, {mood}, {view}, {WEAR}, {PLACE}, {REAL}")


def main():
    os.makedirs(OUT, exist_ok=True)
    files = {os.path.basename(p)[23:29]: p for p in glob.glob(f"{SRC}/*.jpg")}
    n = 0
    for key, (mood, view) in SHOTS.items():
        save(Image.open(files[key]), key, mood, view)
        n += 1
    big = Image.open(files["dvfmc0"])
    for key, (box, mood, view) in COLLAGE.items():
        save(big.crop(box), key, mood, view)
        n += 1
    for key, (path, words) in EXTRA.items():
        if not os.path.exists(f"{OUT}/she3_{key}.png"):
            save(Image.open(path), key, "", "", text=f"{LOOK}, {words}", resize=False)
        n += 1
    print(f"she3 dataset: {n} pictures -> {OUT}", flush=True)


if __name__ == "__main__":
    main()
