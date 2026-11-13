"""Painted episode 1 v3, scene 1 face (the owner, 2026-11-11 17:45: "e1 first scene must be redone, the face is very bad").
The keyframe elf_set2_arcane/v3/pick_s1.png is a wide shot: her face is ~50 x 60 px, and the 11-10 inpaint_any.py face
repaint ran at that size (a doll face, uneven eyes). Now the face_repaint_real.py way: a square crop around the face
enlarged to 1024, repainted with inpaint_any's "face" mode (Qwen-Image-Edit 2511, image 2 = the approved young painted
face ep2_ref_young_face_a.png, masked latent), scaled back and pasted through the feathered ellipse — only the face
changes. Two seeds x denoise 0.75 / 0.85 -> v3/s1face/s1_r<n>_d<dd>.png, and a sheet.
Run:  python  /opt/tests/ep1_s1_face.py run     (inside comfyui)
      python3 /opt/tests/ep1_s1_face.py sheet   (any container)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import face_repaint_real as frr  # noqa: E402

V = "/data/output/series/elf_set2_arcane/v3"
PICK = f"{V}/pick_s1.png"
frr.OUT = f"{V}/s1face"
frr.BOXES = {"s1": (0.406, 0.205, 0.446, 0.292)}  # the 11-10 box (fix_masks.png)
frr.src_of = lambda name: PICK
DENOISES = (0.75, 0.85)
# 18:25 the owner rejected the result hard: "a 10-year-old, not a beautiful 25-year-old girl" (the ep2 young-face ref +
# the words "soft round cheeks, big eyes"). 18:35 the owner: "ep3_castle_v2 60-65 s — she is ideal there" = ep3 s19 (the
# campfire). S1_ADULT=1: image 2 = the head of ep3/picks/s19.png (check_1111/ref_s19_head.png), adult words, variant
# prefix "a" (s1_r<n>_a75 / _a85; the d-files stay).
ADULT = os.environ.get("S1_ADULT") == "1"
PFX = "a" if ADULT else "d"
ADULT_REF_SRC = "/data/output/series/check_1111/ref_s19_head.png"
ADULT_REF = "ep3_ref_s19_head.png"
ADULT_PROMPT = ("Her face is exactly the face of the woman in image 2: a beautiful woman of about twenty-five, a slim face "
                "with defined cheekbones, the same eyes, the same eyebrows, the same nose and the same lips as in image 2, "
                "a calm expression; the same head angle and light as in image 1. Painted Arcane animation style.")


def run():
    import shutil
    import episode2 as ep
    import inpaint_any as ia
    tag = frr.prep_one("s1")
    prompt, _, blur, ref = ia.MODES["face"]
    if ADULT:
        shutil.copyfile(ADULT_REF_SRC, f"/data/input/{ADULT_REF}")
        prompt, ref = ADULT_PROMPT, ADULT_REF
    for d in DENOISES:
        ia.MODES["face"] = (prompt, d, blur, ref)
        for n, seed in enumerate(ia.SEEDS, 1):
            frr.VAR = f"_{PFX}{int(d * 100)}"
            if os.path.exists(f"{frr.OUT}/full/s1_r{n}{frr.VAR}.png"):
                continue
            if not ep.newest(f"{frr.OUT}/crop/s1_r{n}{frr.VAR}_*.png"):
                g = ia.graph("face", tag, seed, "x", "x")
                g["save"]["inputs"]["filename_prefix"] = f"series/elf_set2_arcane/v3/s1face/crop/s1_r{n}{frr.VAR}"
                secs, _ = ep.story.run(g, 900)
                print(f"s1face r{n} d{d}: {secs:.1f} s", flush=True)
            frr.paste_back("s1", n)


def sheet():
    """Row 1: the face crops (original | 4 variants); row 2: the whole frames at half size."""
    from PIL import Image, ImageDraw
    files = [PICK] + [f"{frr.OUT}/full/s1_r{n}_{PFX}{int(d * 100)}.png" for d in DENOISES for n in (1, 2)]
    labels = ["original (now)"] + [f"{'adult ' if ADULT else ''}d{d} r{n}" for d in DENOISES for n in (1, 2)]
    out = Image.new("RGB", (5 * 384, 384 + 24 + 5 * 0), "black")
    big = Image.new("RGB", (2 * 640, 3 * 352), "black")
    for i, (f, lab) in enumerate(zip(files, labels)):
        if not os.path.exists(f):
            continue
        out.paste(frr.face_tile(f, "s1", 384), (384 * i, 0))
        ImageDraw.Draw(out).text((384 * i + 4, 388), lab, fill="white")
        if i:
            big.paste(Image.open(f).convert("RGB").resize((640, 352)), (640 * ((i - 1) % 2), 352 * ((i - 1) // 2)))
    big.paste(Image.open(PICK).convert("RGB").resize((640, 352)), (0, 704))
    out.save(f"{V}/S1_FACE{'_adult' if ADULT else ''}_compare.jpg", quality=92)
    big.save(f"{V}/S1_FACE{'_adult' if ADULT else ''}_frames.jpg", quality=90)
    print("s1 face sheets written", flush=True)


if __name__ == "__main__":
    {"run": run, "sheet": sheet}[sys.argv[1]]()
