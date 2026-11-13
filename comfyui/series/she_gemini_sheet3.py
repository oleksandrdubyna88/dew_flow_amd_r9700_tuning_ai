"""Contact sheet of lora/she_gemini_src3 (2026-11-12 ~21:50: the owner added 15 new pictures to the owner's picture folder for
dataset v6 + 3 from 12:20 that were not in src2). Any container with PIL: python3 /opt/tests/she_gemini_sheet3.py"""
import glob
import os

from PIL import Image, ImageDraw

SRC = "/data/output/lora/she_gemini_src3"
files = sorted(glob.glob(f"{SRC}/*.jpg"), key=os.path.getmtime)
W, H, C = 300, 520, 6
rows = (len(files) + C - 1) // C
out = Image.new("RGB", (C * W, rows * (H + 18)), "black")
for i, f in enumerate(files):
    im = Image.open(f).convert("RGB")
    im.thumbnail((W, H))
    x, y = (i % C) * W, (i // C) * (H + 18)
    out.paste(im, (x + (W - im.width) // 2, y))
    ImageDraw.Draw(out).text((x + 4, y + H + 2), f"{i + 1:02d} {os.path.basename(f)[23:29]} {Image.open(f).size}", fill="white")
out.save("/data/output/lora/she_gemini_sheet3.jpg", quality=88)
print(f"sheet3: {len(files)} pictures", flush=True)
