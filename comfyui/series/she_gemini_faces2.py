"""Face crops (upper 40 %) of the 12 new Gemini pictures, larger, to read the expressions for the v4 captions."""
import glob, os
from PIL import Image, ImageDraw
fs = sorted(glob.glob("/data/output/lora/she_gemini_src2/*.jpg"))
W, H = 480, 420
out = Image.new("RGB", (4 * W, 3 * (H + 16)), "black")
for i, f in enumerate(fs):
    im = Image.open(f).convert("RGB")
    im = im.crop((int(im.width * 0.2), int(im.height * 0.08), int(im.width * 0.8), int(im.height * 0.42))).resize((W, H))
    x, y = (i % 4) * W, (i // 4) * (H + 16)
    out.paste(im, (x, y)); ImageDraw.Draw(out).text((x + 4, y + H + 2), os.path.basename(f)[23:29], fill="white")
out.save("/data/output/lora/she_gemini_faces2.jpg", quality=88)
