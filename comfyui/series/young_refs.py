"""The owner (2026-11-09) wants the YOUNG face of episode 2 v3's sleep shot (around frame 76, eyes open, before 10 s)
in every Arcane shot; from shot 3 on she looked ~30 years older. Extract frames 76 and 80 of v3 clip 2 as references,
find the small forehead dot (the darkest spot above the brows) and print it for clean_refs.py.
Run inside the comfyui container:  python /opt/tests/young_refs.py
"""
import subprocess

import numpy as np
from PIL import Image

EP2 = "/data/output/series/ep2"
for n in (76, 80):
    out = f"{EP2}/refs/ref_young_{n}.png"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-threads", "2", "-i", f"{EP2}/v3/clip_s2_00001_.mp4", "-vf",
                    f"select=eq(n\\,{n})", "-frames:v", "1", "-update", "1", out], check=True, timeout=120)
    im = np.asarray(Image.open(out).convert("L")).astype(float)
    w = im[140:230, 190:300]
    y, x = np.unravel_index(np.argmin(w), w.shape)
    print(f"frame {n}: darkest spot at ({190 + x}, {140 + y}), value {w.min():.0f}, median {np.median(w):.0f}", flush=True)


def crop_face(src, dst, box=(170, 70, 630, 430), width=1024):
    """The face is small in the full frame (~150 px): a crop around it, enlarged, gives the edit model a clear face."""
    im = Image.open(src).convert("RGB").crop(box)
    im.resize((width, round(width * im.height / im.width)), Image.LANCZOS).save(dst)
