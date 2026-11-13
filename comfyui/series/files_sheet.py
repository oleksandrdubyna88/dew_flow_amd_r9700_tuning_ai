"""A labelled sheet of the given pictures (label = file name start).  Run:  python3 files_sheet.py <out.png> <cols> <file>...
"""
import os
import sys

from PIL import Image, ImageDraw

files, cols = sys.argv[3:], int(sys.argv[2])
W = int(os.environ.get("SHEET_W", "512")); H = W * 9 // 16
rows = (len(files) + cols - 1) // cols
out = Image.new("RGB", (W * cols, H * rows), "black")
d = ImageDraw.Draw(out)
for i, f in enumerate(files):
    x, y = i % cols, i // cols
    im = Image.open(f).convert("RGB")
    im.thumbnail((W, H))
    out.paste(im, (x * W + (W - im.width) // 2, y * H))
    d.rectangle((x * W, y * H, x * W + 150, y * H + 16), fill="black")
    d.text((x * W + 3, y * H + 2), f.split("/")[-1][:20], fill="white")
out.save(sys.argv[1])
