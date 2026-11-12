"""LoRA v4 dataset (the owner 2026-11-12 ~12:25): "I added more pictures to the owner's picture folder — full body, with emotions and
different views" + "I read that what is well described the LoRA does not bake in, and it can be changed later easily.
Let's describe the hairstyle, the clothes, the background so these can be changed".
Caption rule v4: the trigger + "a young woman" carry the IDENTITY (face) — NO face words (eyes, brows, cheekbones, skin)
any more; everything that must stay changeable is written out per picture: hairstyle, every piece of clothing, the
background and light, plus expression, framing/pose and view.
Pictures (49): the v3 set (22 Gemini + 4 collage crops + 11 owner picks; see she3_dataset.py) + 12 new full-body Gemini
pictures (lora/she_gemini_src2, 1536x2752: 7 forest path in the tunic, 5 castle courtyard in the fur outfit).
Run in any container with PIL:  python3 /opt/tests/she4_dataset.py   -> /data/output/lora/slvrareal4/*.png + *.txt
"""
import glob
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import she3_dataset as s3  # noqa: E402

SRC1 = s3.SRC
SRC2 = "/data/output/lora/she_gemini_src2"
OUT = "/data/output/lora/slvrareal4"
WHO = "slvrareal, a young woman"
REAL = s3.REAL
# hair: the v3 Gemini set has no golden strand; the new set has one thin golden strand
HAIR1 = "long straight silver-white hair with the top half pulled back from her face"
HAIR2 = f"{HAIR1}, one thin golden strand in her hair"
TUNIC1 = ("wearing a dark-green wool tunic with a brown leather strap across her chest and brown leather bracers")
TUNIC2 = ("wearing a dark-green wool tunic with a stand-up collar and a laced brown leather neckline, a brown leather belt, "
          "brown leather bracers, dark-brown trousers and tall brown leather boots")
FUR = ("wearing a grey sleeveless knitted crop top with a laced neckline, a wide brown leather belt, a short brown fur "
       "skirt, brown leather bracers and tall brown leather boots with fur tops, bare midriff")
PLACE1 = "sitting on the forest floor in a pine forest with fallen leaves, soft daylight"
FOREST2 = "on a sunlit forest path with fallen leaves between green trees, warm afternoon light"
CASTLE = "in a cobblestone castle courtyard with round stone towers, soft evening light"
# the 12 new pictures (read by eye from she_gemini_sheet2.jpg + she_gemini_faces2.jpg): key -> (outfit, place, text)
NEW = {
    "16z5dv": (TUNIC2, FOREST2, "sticking her tongue out playfully, full body, standing, side view, facing left"),
    "67d3j1": (TUNIC2, FOREST2, "a sad expression, close to tears, with worried raised eyebrows, full body, walking toward "
                                "the camera, front view"),
    "74ubnd": (FUR, CASTLE, "an annoyed serious expression, full body, standing, side view, looking to the right"),
    "8qm994": (FUR, CASTLE, "a wide happy smile, full body, standing, front view, looking at the camera"),
    "9l5uf7": (FUR, CASTLE, "laughing happily, full body, standing, three-quarter view, looking to the right"),
    "eb2n9n": (TUNIC2, FOREST2, "laughing happily, full body, walking toward the camera, front view"),
    "j6i507": (FUR, CASTLE, "laughing with her mouth wide open, full body, standing, three-quarter view, looking to the "
                            "right"),
    "jmaclg": (TUNIC2, FOREST2, "a doubtful frowning expression, full body, walking toward the camera, front view"),
    "o3u9uk": (FUR, CASTLE, "a sad worried expression with raised eyebrows, full body, standing, three-quarter view, "
                            "looking to the right"),
    "oqpox0": (FUR, CASTLE, "sticking her tongue out playfully, full body, standing, side view, facing right"),
    "w2p6m8": (TUNIC2, FOREST2, "a bright happy smile, full body, walking toward the camera, front view, looking at the "
                                "camera"),
    "wk9ej1": (TUNIC2, FOREST2, "full body, standing, seen from behind, her hands on her hips, her back to the camera"),
}


def save(im, key, text, resize=True):
    im = im.convert("RGB")
    if resize:
        im.thumbnail((1024, 1024), Image.LANCZOS)
    im.save(f"{OUT}/she4_{key}.png")
    with open(f"{OUT}/she4_{key}.txt", "w") as f:
        f.write(text)


def main():
    os.makedirs(OUT, exist_ok=True)
    n = 0
    files1 = {os.path.basename(p)[23:29]: p for p in glob.glob(f"{SRC1}/*.jpg")}
    for key, (mood, view) in s3.SHOTS.items():
        save(Image.open(files1[key]), key, f"{WHO}, {mood}, {view}, {HAIR1}, {TUNIC1}, {PLACE1}, {REAL}")
        n += 1
    big = Image.open(files1["dvfmc0"])
    for key, (box, mood, view) in s3.COLLAGE.items():
        save(big.crop(box), key, f"{WHO}, {mood}, {view}, {HAIR1}, {TUNIC1}, {PLACE1}, {REAL}")
        n += 1
    # the owner's 11 picks: their v3 words after the face part stay (they already name hair, outfit, place, style)
    for key, (path, words) in s3.EXTRA.items():
        save(Image.open(path), key, f"{WHO}, long silver-white hair, {words}", resize=False)
        n += 1
    files2 = {os.path.basename(p)[23:29]: p for p in glob.glob(f"{SRC2}/*.jpg")}
    for key, (outfit, place, text) in NEW.items():
        save(Image.open(files2[key]), key, f"{WHO}, {text}, {HAIR2}, {outfit}, {place}, {REAL}")
        n += 1
    print(f"she4 dataset: {n} pictures -> {OUT}", flush=True)


if __name__ == "__main__":
    main()
