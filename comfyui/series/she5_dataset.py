"""LoRA v5 dataset = the v4 pictures (49) with captions reviewed by the consultants (2026-11-12 ~12:45, consultId
88a661a4…; the owner: "run the descriptions through a consultant; she must look beautiful, a bit sexy, young, about
20-25" + "the body moderately toned, as for a girl").
What changed vs v4 (lora/slvrareal4 stays as it is):
- class words "an adult woman in her early twenties" in every caption (adult anchor; no "young", no face words —
  "young face / big eyes / soft cheeks" drew a child, "high cheekbones / thin brows / about twenty-five" drew an older,
  harder face on Qwen in v3)
- NO beauty / sexy / body words in the captions: the pictures carry her look and her moderately toned body, so the
  trigger learns them; at inference add e.g. "beautiful, subtle allure, confident gaze, a slim moderately athletic
  build with toned arms" when wanted
- order: trigger + class -> framing + pose + view -> expression + gaze -> hair (golden strand next to the hair) ->
  clothing top to bottom -> place + light -> medium. The 26 Gemini pictures say "medium shot, sitting with her forearms
  on her knees" right at the front, so the sitting pose is captioned, not baked into the trigger
- repeats balance by subfolder: r2_gemini (26 x 2), r2_picks (11 x 2), r5_full (12 x 5) — the full-body standing set
  is no longer outweighed 5:1 by the sitting set (the trainer scripts read r<N>_* subfolders)
Run in any container with PIL:  python3 /opt/tests/she5_dataset.py   -> /data/output/lora/slvrareal5/r*_*/
"""
import glob
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import she3_dataset as s3  # noqa: E402
import she4_dataset as s4  # noqa: E402

OUT = "/data/output/lora/slvrareal5"
WHO = "slvrareal, an adult woman in her early twenties"
REAL = "photorealistic photograph, natural skin texture"
ART = "highly detailed realistic digital art, illustration, cinematic light"
HAIR1 = "long straight silver-white hair worn half-up"
HAIR2 = "long straight silver-white hair worn half-up with one thin golden strand"
TUNIC1 = s4.TUNIC1
SIT = "medium shot, sitting with her forearms resting on her knees"
PLACE1 = "on the forest floor in a pine forest with fallen leaves, soft daylight"
# the owner's 11 picks: framing/pose/view, expression, hair, outfit, place, medium (rewritten in the v5 order)
GOLDH = "long silver-white hair with one thin golden strand"
PICKS = {
    "x_rf50_portrait": f"medium shot, sitting with her arms resting on her knees, front view, a calm expression with a hint "
                       f"of a smile, looking at the camera, {GOLDH}, {TUNIC1}, in a forest, {REAL}",
    "x_rf70_portrait": f"medium shot, sitting with her arms resting on her knee, front view, a calm serious expression, "
                       f"looking at the camera, {GOLDH}, {TUNIC1}, in a forest, {REAL}",
    "x_v150_portrait": f"medium shot, sitting with her arms resting on her knees, front view, a calm expression, looking at "
                       f"the camera, {GOLDH}, {TUNIC1}, in a forest, {ART}",
    "x_v170_campfire": f"medium shot, sitting, front view, a calm thoughtful expression, {GOLDH}, {TUNIC1}, by a campfire "
                       f"in a dark forest at night, {ART}",
    "x_c01_s5101": f"close-up, front view, a soft smile, looking at the camera, {GOLDH}, {TUNIC1}, in a sunlit forest, {ART}",
    "x_c01_s5201": f"close-up, front view, a calm gentle smile, looking at the camera, {GOLDH}, {TUNIC1}, in a sunlit "
                   f"forest, {ART}",
    "x_c04_s5204": f"close-up, side view, a soft dreamy expression, looking to the right, long silver-white hair with golden "
                   f"strands braided in, {TUNIC1}, in a dark forest, {ART}",
    "x_c05_s5105": f"medium close-up, one hand raised, a look of wonder, looking up, {GOLDH}, {TUNIC1}, by a waterfall in "
                   f"falling snow, {ART}",
    "x_c04_s5104": f"close-up, side view, a calm thoughtful expression, looking to the right, {GOLDH}, {TUNIC1}, in a dark "
                   f"forest, {ART}",
    "x_tunic_back": f"full body, walking, seen from behind, {GOLDH}, wearing a dark-green wool tunic with a brown leather "
                    f"belt and brown leather bracers, toward a castle gate, {REAL}",
    "x_tunic_threeq": f"close-up, head turned three-quarters to the left, a calm expression, {GOLDH}, {TUNIC1}, cool "
                      f"morning light, {REAL}",
}
# the 12 full-body pictures: (outfit, place, framing/pose/view, expression)
FULL = {
    "16z5dv": (s4.TUNIC2, s4.FOREST2, "full body, standing, side view, facing left", "sticking her tongue out playfully"),
    "67d3j1": (s4.TUNIC2, s4.FOREST2, "full body, walking toward the camera, front view",
               "a sad expression, close to tears, with worried raised eyebrows"),
    "74ubnd": (s4.FUR, s4.CASTLE, "full body, standing, side view", "an annoyed expression, looking to the right"),
    "8qm994": (s4.FUR, s4.CASTLE, "full body, standing, front view", "a wide happy smile, looking at the camera"),
    "9l5uf7": (s4.FUR, s4.CASTLE, "full body, standing, three-quarter view", "laughing happily, looking to the right"),
    "eb2n9n": (s4.TUNIC2, s4.FOREST2, "full body, walking toward the camera, front view", "laughing happily"),
    "j6i507": (s4.FUR, s4.CASTLE, "full body, standing, three-quarter view",
               "laughing with her mouth wide open, looking to the right"),
    "jmaclg": (s4.TUNIC2, s4.FOREST2, "full body, walking toward the camera, front view", "a doubtful frowning expression"),
    "o3u9uk": (s4.FUR, s4.CASTLE, "full body, standing, three-quarter view",
               "a sad worried expression with raised eyebrows, looking to the right"),
    "oqpox0": (s4.FUR, s4.CASTLE, "full body, standing, side view, facing right", "sticking her tongue out playfully"),
    "w2p6m8": (s4.TUNIC2, s4.FOREST2, "full body, walking toward the camera, front view",
               "a bright happy smile, looking at the camera"),
    "wk9ej1": (s4.TUNIC2, s4.FOREST2, "full body, standing, seen from behind, her hands on her hips, her back to the camera",
               ""),
}
SUB = {"gemini": "r2_gemini", "picks": "r2_picks", "full": "r5_full"}


def save(im, sub, key, text, resize=True):
    d = f"{OUT}/{SUB[sub]}"
    os.makedirs(d, exist_ok=True)
    im = im.convert("RGB")
    if resize:
        im.thumbnail((1024, 1024), Image.LANCZOS)
    im.save(f"{d}/she5_{key}.png")
    with open(f"{d}/she5_{key}.txt", "w") as f:
        f.write(", ".join(p for p in text if p))


def main():
    n = 0
    files1 = {os.path.basename(p)[23:29]: p for p in glob.glob(f"{s3.SRC}/*.jpg")}
    for key, (mood, view) in s3.SHOTS.items():
        save(Image.open(files1[key]), "gemini", key, [WHO, SIT, view, mood, HAIR1, TUNIC1, PLACE1, REAL])
        n += 1
    big = Image.open(files1["dvfmc0"])
    for key, (box, mood, view) in s3.COLLAGE.items():
        save(big.crop(box), "gemini", key, [WHO, SIT, view, mood, HAIR1, TUNIC1, PLACE1, REAL])
        n += 1
    for key, (path, _) in s3.EXTRA.items():
        save(Image.open(path), "picks", key, [WHO, PICKS[key]], resize=False)
        n += 1
    files2 = {os.path.basename(p)[23:29]: p for p in glob.glob(f"{s4.SRC2}/*.jpg")}
    for key, (outfit, place, frame, mood) in FULL.items():
        save(Image.open(files2[key]), "full", key, [WHO, frame, mood, HAIR2, outfit, place, REAL])
        n += 1
    print(f"she5 dataset: {n} pictures -> {OUT}", flush=True)


if __name__ == "__main__":
    main()
