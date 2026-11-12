"""A sheet of every keyframe option (final keys and step-1 poses) for the given ep3 shots.
Run:  python3 /opt/tests/options_sheet.py <out.png> <shot>...
"""
import glob
import sys

from PIL import Image, ImageDraw

K = "/data/output/series/ep3/keys/"
items = []
for k in map(int, sys.argv[2:]):
    for f in sorted(glob.glob(f"{K}s{k:02d}_c*_00001_.png")):
        items.append(("key " + f.split("/")[-1][:6], f))
    for f in sorted(glob.glob(f"{K}pose/s{k:02d}_c*_00001_.png")):
        items.append(("pose " + f.split("/")[-1][:6], f))
W, H, cols = 640, 352, 4
rows = (len(items) + cols - 1) // cols
out = Image.new("RGB", (W * cols, H * rows), "black")
d = ImageDraw.Draw(out)
for i, (lab, f) in enumerate(items):
    x, y = i % cols, i // cols
    out.paste(Image.open(f).convert("RGB").resize((W, H)), (x * W, y * H))
    d.rectangle((x * W, y * H, x * W + 110, y * H + 16), fill="black")
    d.text((x * W + 3, y * H + 2), lab, fill="white")
out.save(sys.argv[1])
print(len(items))
