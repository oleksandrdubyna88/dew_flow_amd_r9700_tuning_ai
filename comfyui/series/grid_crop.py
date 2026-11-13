"""Head crops with a coordinate grid (fractions of the full picture, every 0.02), to place inpaint masks by eye.
Run:  python3 grid_crop.py <out.png> <file>:<x0>,<y0>,<x1>,<y1> ...   (tiles 640 px wide, one row)
"""
import sys

from PIL import Image, ImageDraw

tiles = []
for arg in sys.argv[2:]:
    f, box = arg.rsplit(":", 1)
    im = Image.open(f).convert("RGB")
    w, h = im.size
    x0, y0, x1, y1 = (float(v) for v in box.split(","))
    c = im.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))
    s = 640 / c.width
    c = c.resize((640, int(c.height * s)))
    d = ImageDraw.Draw(c)
    for i in range(int(x0 * 50), int(x1 * 50) + 1):
        x = (i / 50 - x0) * w * s
        d.line((x, 0, x, c.height), fill=(0, 255, 0) if i % 5 == 0 else (0, 110, 0))
        if i % 5 == 0:
            d.text((x + 2, 2), f"{i / 50:.2f}", fill="yellow")
    for j in range(int(y0 * 50), int(y1 * 50) + 1):
        y = (j / 50 - y0) * h * s
        d.line((0, y, c.width, y), fill=(0, 255, 0) if j % 5 == 0 else (0, 110, 0))
        if j % 5 == 0:
            d.text((2, y + 2), f"{j / 50:.2f}", fill="yellow")
    d.text((5, c.height - 14), f.split("/")[-1], fill="white")
    tiles.append(c)
H = max(t.height for t in tiles)
out = Image.new("RGB", (640 * len(tiles), H), "black")
for i, t in enumerate(tiles):
    out.paste(t, (640 * i, 0))
out.save(sys.argv[1])
print(out.size)
