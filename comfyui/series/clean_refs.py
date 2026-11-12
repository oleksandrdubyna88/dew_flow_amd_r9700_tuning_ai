"""Remove the small dark pin from the forehead of episode 1's Arcane reference frames (the owner, 2026-11-09: "it sticks out
of the middle of her forehead"; the edit model copied it from these references into every new keyframe).
The pin is found as the darkest thin vertical blob in a window above the brows and replaced by forehead skin taken from
just beside it, with a soft edge. Run inside the comfyui container:  python /opt/tests/clean_refs.py <in.png> <out.png> <x> <y>
(x, y = a point near the pin). Prints the box it replaced.
"""
import sys

import numpy as np
from PIL import Image

src, dst, cx, cy = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
im = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
# a small window around the point: the pin is the run of dark pixels in each row; each is replaced by the straight line
# between the skin just left and just right of the run (row by row), so the hair above is never touched
y0, y1, x0, x1 = cy - 12, cy + 12, cx - 9, cx + 9
lum = im[y0:y1, x0:x1].mean(axis=2)
skin = np.percentile(lum, 75)
done = 0
for r in range(y1 - y0):
    dark = np.nonzero(lum[r] < skin - 40)[0]
    if len(dark) == 0:
        continue
    a, b = x0 + dark.min() - 2, x0 + dark.max() + 2
    left, right = im[y0 + r, a - 1], im[y0 + r, b + 1]
    for x in range(a, b + 1):
        t = (x - a + 1) / (b - a + 2)
        im[y0 + r, x] = left * (1 - t) + right * t
    done += 1
Image.fromarray(np.clip(im, 0, 255).astype(np.uint8)).save(dst)
print(f"{src}: {done} rows filled near ({cx}, {cy})")
