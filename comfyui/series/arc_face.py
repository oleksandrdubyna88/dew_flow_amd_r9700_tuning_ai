"""Painted 360 start picture, the face (2026-11-12 01:00): arc360/paint1r_c3 (key c3 repainted in the Arcane style, image 1
only) has a hard face -> the ep1_s1_face.py S1_ADULT way: crop around the face enlarged to 1024, Qwen-Image-Edit 2511 "face"
mode with image 2 = the ep3 s19 head (the owner's ideal), masked latent, pasted back through the feathered ellipse.
Denoise 0.75 x 2 seeds -> arc360/face/full/c3_r<n>_a75.png, sheet arc360/FACE_compare.jpg.
Run:  python /opt/tests/arc_face.py run   (inside comfyui)   |   python3 /opt/tests/arc_face.py sheet
"""
import glob
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import face_repaint_real as frr  # noqa: E402
import ep1_s1_face as s1f  # noqa: E402

A = "/data/output/series/arc360"
PICK = sorted(glob.glob(f"{A}/paint1r_c3_*.png"))[-1]
frr.OUT = f"{A}/face"
frr.BOXES = {"c3": (0.387, 0.10, 0.465, 0.27)}
frr.src_of = lambda name: PICK


def run():
    import episode2 as ep
    import inpaint_any as ia
    tag = frr.prep_one("c3")
    _, _, blur, _ = ia.MODES["face"]
    shutil.copyfile(s1f.ADULT_REF_SRC, f"/data/input/{s1f.ADULT_REF}")
    # 01:05 at 0.75 the face kept the source's heavy brows and hard look -> ARC_D (e.g. 0.9)
    d = float(os.environ.get("ARC_D", "0.75"))
    ia.MODES["face"] = (s1f.ADULT_PROMPT, d, blur, s1f.ADULT_REF)
    frr.VAR = f"_a{int(round(d * 100))}"
    for n, seed in enumerate(ia.SEEDS, 1):
        if os.path.exists(f"{frr.OUT}/full/c3_r{n}{frr.VAR}.png"):
            continue
        if not ep.newest(f"{frr.OUT}/crop/c3_r{n}{frr.VAR}_*.png"):
            g = ia.graph("face", tag, seed, "x", "x")
            g["save"]["inputs"]["filename_prefix"] = f"series/arc360/face/crop/c3_r{n}{frr.VAR}"
            secs, _ = ep.story.run(g, 900)
            print(f"arc360 face r{n}: {secs:.1f} s", flush=True)
        frr.paste_back("c3", n)


def sheet():
    from PIL import Image, ImageDraw
    files = [PICK] + [f"{frr.OUT}/full/c3_r{n}_a{d}.png" for d in (75, 90) for n in (1, 2)]
    out = Image.new("RGB", (6 * 384, 384 + 24), "black")
    out.paste(Image.open(s1f.ADULT_REF_SRC).convert("RGB").resize((384, 384)), (0, 0))
    ImageDraw.Draw(out).text((4, 388), "ideal: ep3 s19", fill="white")
    for i, f in enumerate(files, 1):
        if os.path.exists(f):
            out.paste(frr.face_tile(f, "c3", 384), (384 * i, 0))
        ImageDraw.Draw(out).text((384 * i + 4, 388), ["", "now", "r1 0.75", "r2 0.75", "r1 0.9", "r2 0.9"][i], fill="white")
    out.save(f"{A}/FACE_compare.jpg", quality=92)
    print("arc360 face sheet written", flush=True)


if __name__ == "__main__":
    {"run": run, "sheet": sheet}[sys.argv[1]]()
