"""Motion per frame step (mean |luma difference| / the film's median), printed in rows of 8 steps (0.5 s at 16 fps), and the
duplicated frames (step < 0.02 x median). Run:  python3 /opt/tests/motion_profile.py <film.mp4> [from_s to_s]
"""
import sys

import numpy as np

sys.path.insert(0, "/opt/tests")
from freeze_scan import fps, frames  # noqa: E402

p = sys.argv[1]
f, r = frames(p), fps(p)
d = np.abs(np.diff(f, axis=0)).mean(axis=(1, 2))
med = float(np.median(d))
a = int(float(sys.argv[2]) * r) if len(sys.argv) > 2 else 0
b = int(float(sys.argv[3]) * r) if len(sys.argv) > 3 else len(d)
print(f"{p.split('/')[-1]}: median {med:.2f}; duplicates at s: {[round(i / r, 2) for i in np.where(d < 0.02 * med)[0]]}")
for i in range(a, min(b, len(d)), 8):
    print(f"{i / r:6.2f} s: " + " ".join(f"{x / med:4.2f}" for x in d[i:i + 8]))
