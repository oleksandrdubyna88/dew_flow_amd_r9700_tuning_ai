"""Crop given boxes (fractions of the picture) from keyframes into one sheet, upscaled, to judge faces by eye.
Run:  python3 /opt/tests/face_crops.py <out.png> <file>:<x0>,<y0>,<x1>,<y1> ...
"""
import sys

from PIL import Image

tiles = []
for arg in sys.argv[2:]:
    f, box = arg.rsplit(":", 1)
    im = Image.open(f).convert("RGB")
    x0, y0, x1, y1 = (float(v) for v in box.split(","))
    w, h = im.size
    c = im.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))
    tiles.append(c.resize((512, int(512 * c.height / c.width))))
H = max(t.height for t in tiles)
out = Image.new("RGB", (512 * len(tiles), H), "black")
for i, t in enumerate(tiles):
    out.paste(t, (512 * i, 0))
out.save(sys.argv[1])
print(out.size)
