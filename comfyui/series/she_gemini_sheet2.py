import glob, os
from PIL import Image, ImageDraw
fs = sorted(glob.glob("/data/output/lora/she_gemini_src2/*.jpg"))
W = 320
cells = []
for f in fs:
    im = Image.open(f).convert("RGB"); im.thumbnail((W, W))
    c = Image.new("RGB", (W, W + 16), "black"); c.paste(im, ((W - im.width) // 2, 0))
    ImageDraw.Draw(c).text((4, W + 2), os.path.basename(f)[23:29] + f" {Image.open(f).size}", fill="white")
    cells.append(c)
cols = 6; rows = (len(cells) + cols - 1) // cols
out = Image.new("RGB", (cols * W, rows * (W + 16)), "black")
for i, c in enumerate(cells):
    out.paste(c, ((i % cols) * W, (i // cols) * (W + 16)))
out.save("/data/output/lora/she_gemini_sheet2.jpg", quality=88)
print(len(cells))
