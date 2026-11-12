"""LoRA v6 dataset = v5 (49 pictures, she5_dataset.py, same captions) + the 18 pictures the owner added on 2026-11-12
(lora/she_gemini_src3: 15 new for the gaps in v5 - studio heads, other outfits, hairstyles, light, angles, places - and
3 back views from 12:20 that were not in src2). For the HiDream LoRA first (the owner 2026-11-13 ~00:35: "train a LoRA
on HiDream too").
Caption rules as v5: trigger + "an adult woman in her early twenties" carry the identity; NO face, beauty or body words;
framing/pose/view -> expression -> hair -> clothes -> place + light -> medium; other people in the background are
written out so they are not baked into the trigger. Read by eye from lora/she_gemini_sheet3.jpg.
Subfolders: r2_gemini, r2_picks, r5_full (v5) + r3_new (18 x 3).
Run in any container with PIL:  python3 /opt/tests/she6_dataset.py   -> /data/output/lora/slvrareal6/r*_*/
"""
import glob
import os
import shutil
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import she4_dataset as s4  # noqa: E402
import she5_dataset as s5  # noqa: E402

V5 = "/data/output/lora/slvrareal5"
OUT = os.environ.get("SHE6_OUT", "/data/output/lora/slvrareal6")
# 6b (2026-11-13 00:45, consultants 9ea54851: gpt-6-astra + gemini-4-argon): less repeat weight on the narrow sets
# (the 26 sitting pictures in one outfit x1, the 12 full-body in two outfits x3; 138 samples per epoch instead of
# 188), and "bare arms" without "toned" (no body words). SHE6_OUT=/data/output/lora/slvrareal6b
SUBMAP = {"r2_gemini": "r1_gemini", "r5_full": "r3_full"} if OUT.endswith("6b") else {}
SRC3 = "/data/output/lora/she_gemini_src3"
WHO, REAL = s5.WHO, s5.REAL
# key -> (framing / pose / view, expression, hair, clothes, place + light)
NEW = {
    "1frop6": ("full body, standing, seen from behind, one hand raised to her hair, looking up", "",
               "long straight silver-white hair worn half-up", s4.FUR,
               "in a cobblestone castle courtyard with round stone towers, soft evening light"),
    "ci5z3a": ("full body, standing, seen from behind, one hand on her hip, the other arm pointing up at the trees", "",
               "long straight silver-white hair worn half-up", s4.TUNIC2, s4.FOREST2),
    "tphnv3": ("full body, standing, rear three-quarter view, both hands on her hips, looking up to the right", "",
               "long straight silver-white hair worn half-up", s4.FUR,
               "in a cobblestone castle courtyard with round stone towers, soft evening light"),
    "uzde7o": ("full body, standing, seen from behind, one hand on her head, looking to the right", "",
               "long straight silver-white hair worn half-up", s4.TUNIC2, s4.FOREST2),
    "q8povm": ("full body, walking, side view", "a determined expression",
               "long silver-white hair loose and blowing in the wind",
               "wearing a long dark cloak with a fur collar over dark clothes and tall leather boots",
               "in snowy mountains, wind, bright cold daylight"),
    "9lcpw6": ("full body, walking, side view", "a calm expression",
               "silver-white hair in a long braid",
               "wearing a long white sleeveless linen dress, bare arms",
               "in a golden wheat field at sunset, warm backlight"),
    "dx9y79": ("full body, walking, three-quarter view", "a soft smile",
               "long silver-white hair loose",
               "wearing a white linen shirt with a brown leather belt, dark trousers and tall leather boots",
               "on a grassy sea cliff above the ocean, overcast daylight"),
    "gy117t": ("medium shot, sitting at a wooden table, one hand raised", "laughing happily",
               "silver-white hair in a thick braid over one shoulder",
               "wearing a cream linen blouse",
               "in a busy tavern with other people in the background, warm candlelight"),
    "ntlevt": ("medium shot, three-quarter view", "a serious expression",
               "long silver-white hair loose",
               "wearing a dark hooded cloak with the hood down",
               "at night beside a castle wall, warm torchlight and cold moonlight"),
    "xcyasg": ("close-up, lying on her back in the grass, seen from above", "a dreamy smile, looking up",
               "long silver-white hair spread out on the grass",
               "wearing a white linen blouse",
               "in a meadow with wild flowers, soft daylight"),
    "5zss1f": ("medium close-up, low angle from below, front view", "a calm serious expression, looking down at the camera",
               "long silver-white hair loose",
               "wearing a dark-green tunic with a stand-up collar",
               "in front of a stone castle wall, overcast daylight"),
    "ovyvre": ("head and shoulders portrait, three-quarter view", "a small smile, looking at the camera",
               "silver-white hair tied back in a ponytail",
               "wearing a simple dark knitted top",
               "plain light-grey studio background, soft even studio light"),
    "6zq17v": ("head and shoulders portrait, left profile", "a calm neutral expression",
               "long straight silver-white hair loose",
               "wearing a simple dark knitted top",
               "plain light-grey studio background, soft even studio light"),
    "jp09e9": ("head and shoulders portrait, front view", "a calm expression with a hint of a smile, looking at the camera",
               "long straight silver-white hair loose",
               "wearing a simple dark knitted top",
               "plain light-grey studio background, soft even studio light"),
    "m31kah": ("medium shot, three-quarter view", "a focused expression",
               "wet silver-white hair worn half-up",
               "wearing dark leather armour",
               "on a rainy medieval town street with other people in the background, overcast light"),
    "74jv1c": ("full body, lunging forward with a wooden training sword", "a concentrated expression",
               "silver-white hair in a high ponytail",
               "wearing a grey sleeveless top, dark trousers and leather boots, bare arms",
               "in a castle training yard with wooden practice dummies and people in the background, daylight"),
    "5y862q": ("medium shot, kneeling, side view, washing her hands in the water", "a calm expression",
               "silver-white hair in a low ponytail",
               "wearing a dark-green tunic",
               "on a rocky river bank, morning fog over the water"),
    "5a5nbd": ("full body, standing, front view", "a soft elegant smile",
               "long silver-white hair",
               "wearing a long dark-blue velvet evening gown",
               "in a grand palace hall with marble floor and other people in the background, warm candlelight"),
}


def main():
    n = 0
    for f in sorted(glob.glob(f"{V5}/r*_*/she5_*.png")):  # v5 as it is (same pictures and captions)
        sub = os.path.basename(os.path.dirname(f))
        d = f"{OUT}/{SUBMAP.get(sub, sub)}"
        os.makedirs(d, exist_ok=True)
        for ext in (".png", ".txt"):
            src = os.path.splitext(f)[0] + ext
            dst = os.path.join(d, os.path.basename(src))
            if not os.path.exists(dst):
                shutil.copyfile(src, dst)
        n += 1
    d = f"{OUT}/r3_new"
    os.makedirs(d, exist_ok=True)
    files = {os.path.basename(p)[23:29]: p for p in glob.glob(f"{SRC3}/*.jpg")}
    for key, (frame, mood, hair, outfit, place) in NEW.items():
        im = Image.open(files[key]).convert("RGB")
        im.thumbnail((1024, 1024), Image.LANCZOS)
        im.save(f"{d}/she6_{key}.png")
        with open(f"{d}/she6_{key}.txt", "w") as t:
            t.write(", ".join(p for p in (WHO, frame, mood, hair, outfit, place, REAL) if p))
        n += 1
    with open(f"{OUT}_captions.txt", "w") as c:
        for t in sorted(glob.glob(f"{OUT}/r*_*/*.txt")):
            c.write(f"{os.path.relpath(t, OUT)}: {open(t).read()}\n")
    print(f"she6 dataset: {n} pictures -> {OUT}", flush=True)


if __name__ == "__main__":
    main()
