"""My by-eye picks (2026-11-10; ep3 11, 14, 16-21 redone as set 3/4 after the owner: s15 costume, s11/s19 faces) of the ep3 and ep1 v3 keyframes, copied to fixed names for the clip drivers, + one sheet.
"k" = the final keyframe (after the face edit), "p" = the step-1 pose picture (kept where the face edit pulled the camera
into a close-up: ep3 2, 10, 12, 15, 16; ep1 v3 1, 5).
Run:  python3 /opt/tests/picks.py   (container with /data/output)
"""
import glob
import os
import shutil

from PIL import Image, ImageDraw

E3 = "/data/output/series/ep3"
E1 = "/data/output/series/elf_set2_arcane/v3"
EP3 = {1: "k18", 2: "p3", 3: "k1", 4: "k1", 5: "e2", 6: "k1", 7: "w3", 8: "w4", 9: "e1", 10: "p1", 11: "w3", 12: "p1",
       13: "k1", 14: "k5", 15: "p1", 16: "p14", 17: "w1", 18: "e1", 19: "e1", 20: "e4", 21: "e1", 22: "k1", 23: "k1"}
# ep1 v3 (the owner, 2026-11-10): s1 = the masked face repaint (her young face), s4 = the masked ear repaint ("f" = a
# file of inpaint_any.py: fix_s<k>_<w[1:]>_*.png)
EP1 = {1: "fface_2", 2: "k1", 3: "k2", 4: "fear_2", 5: "p1", 6: "k1"}


def one(pattern):
    return sorted(glob.glob(pattern))[-1]


def main():
    os.makedirs(f"{E3}/picks", exist_ok=True)
    items = []
    for k, w in EP3.items():
        src = one({"k": f"{E3}/keys/s{k:02d}_c{w[1:]}_*.png", "p": f"{E3}/keys/pose/s{k:02d}_c{w[1:]}_*.png",
                   "t": f"{E3}/keys/s{k:02d}_t{w[1:]}_*.png", "e": f"{E3}/keys/s{k:02d}_e{w[1:]}_*.png",
                   "w": f"{E3}/keys/s{k:02d}_w{w[1:]}_*.png"}[w[0]])  # t touchup.py, e inpaint_ears.py, w inpaint_sword.py
        shutil.copyfile(src, f"{E3}/picks/s{k:02d}.png")
        items.append((f"ep3 s{k:02d}", src))
    for k, w in EP1.items():
        src = one({"k": f"{E1}/key_s{k}_c{w[1:]}_*.png", "p": f"{E1}/pose/s{k}_c{w[1:]}_*.png",
                   "f": f"{E1}/fix_s{k}_{w[1:]}_*.png"}[w[0]])
        shutil.copyfile(src, f"{E1}/pick_s{k}.png")
        items.append((f"ep1 s{k}", src))
    W, H, cols = 384, 211, 6
    rows = (len(items) + cols - 1) // cols
    out = Image.new("RGB", (W * cols, H * rows), "black")
    d = ImageDraw.Draw(out)
    for i, (lab, f) in enumerate(items):
        x, y = i % cols, i // cols
        out.paste(Image.open(f).convert("RGB").resize((W, H)), (x * W, y * H))
        d.rectangle((x * W, y * H, x * W + 70, y * H + 16), fill="black")
        d.text((x * W + 3, y * H + 2), lab, fill="white")
    out.save("/data/output/series/PICKS_ep3_and_ep1v3.png")
    print(len(items), "picks")


if __name__ == "__main__":
    main()
