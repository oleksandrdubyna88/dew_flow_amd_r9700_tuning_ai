"""Draw red frames and a caption on pictures, stacked into one sheet (to show the owner where a problem is).
Run:  python3 mark.py <out.png> "<file>|<caption>|x0,y0,x1,y1;x0,y0,x1,y1" ...   (boxes as fractions; may be empty)
"""
import sys

from PIL import Image, ImageDraw

W = 1280
tiles = []
for arg in sys.argv[2:]:
    f, cap, boxes = arg.split("|")
    im = Image.open(f).convert("RGB").resize((W, 704))
    d = ImageDraw.Draw(im)
    for b in filter(None, boxes.split(";")):
        x0, y0, x1, y1 = (float(v) for v in b.split(","))
        d.rectangle((x0 * W, y0 * 704, x1 * W, y1 * 704), outline=(255, 30, 30), width=5)
    d.rectangle((0, 0, 9 * len(cap) + 20, 30), fill="black")
    d.text((10, 8), cap, fill="white")
    tiles.append(im)
out = Image.new("RGB", (W * 2, 704 * ((len(tiles) + 1) // 2)), "black")
for i, t in enumerate(tiles):
    out.paste(t, ((i % 2) * W, (i // 2) * 704))
out.save(sys.argv[1])
print(out.size)
