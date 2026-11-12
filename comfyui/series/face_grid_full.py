"""Whole pictures with a coarse coordinate grid (fractions, a line every 0.05, labels every 0.1), to place face boxes by eye
on many pictures at once (2026-11-11, the realistic LoRA v2 face repaint). Tiles 640 px wide, COLS per row.
Run:  python3 grid_full.py <out.jpg> <cols> <file> ...
"""
import os
import sys

from PIL import Image, ImageDraw

out_path, cols, files = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
tiles = []
for f in files:
    im = Image.open(f).convert("RGB")
    t = im.resize((640, int(640 * im.height / im.width)))
    d = ImageDraw.Draw(t)
    for i in range(1, 20):
        x, y = t.width * i / 20, t.height * i / 20
        col = (0, 255, 0) if i % 2 == 0 else (0, 120, 0)
        d.line((x, 0, x, t.height), fill=col)
        d.line((0, y, t.width, y), fill=col)
        if i % 2 == 0:
            d.text((x + 2, 2), f"{i / 20:.1f}", fill="yellow")
            d.text((2, y + 2), f"{i / 20:.1f}", fill="yellow")
    d.rectangle((0, t.height - 16, 330, t.height), fill="black")
    d.text((4, t.height - 14), os.path.basename(f).replace("_00001_.png", ""), fill="white")
    tiles.append(t)
H = max(t.height for t in tiles)
rows = (len(tiles) + cols - 1) // cols
sheet = Image.new("RGB", (640 * cols, H * rows), "black")
for n, t in enumerate(tiles):
    sheet.paste(t, (640 * (n % cols), H * (n // cols)))
sheet.save(out_path, quality=92)
print(sheet.size)
