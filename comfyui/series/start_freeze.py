"""Is there a static start in the I2V clips? Mean |luma difference| between consecutive frames, per frame index, for the
first 16 frames against the clip's median; prints one line per clip.
Run in a container with ffmpeg and numpy:  python3 /opt/tests/start_freeze.py <clip.mp4>...
"""
import subprocess
import sys

import numpy as np


def frames(path, w=320, h=176):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-vf", f"scale={w}:{h}", "-f", "rawvideo", "-pix_fmt",
                          "gray", "-"], capture_output=True, check=True, timeout=300).stdout
    n = len(raw) // (w * h)
    return np.frombuffer(raw[:n * w * h], dtype=np.uint8).reshape(n, h, w).astype(np.float32)


for p in sys.argv[1:]:
    f = frames(p)
    d = np.abs(np.diff(f, axis=0)).mean(axis=(1, 2))
    med = float(np.median(d))
    first = " ".join(f"{x / med:.2f}" for x in d[:12])
    print(f"{p.split('/')[-1]}: median {med:.2f}; first 12 steps / median: {first}", flush=True)
