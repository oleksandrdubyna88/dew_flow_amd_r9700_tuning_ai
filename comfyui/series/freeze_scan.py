"""Find frozen moments in a film: runs of consecutive frames whose mean |luma difference| is under FREEZE x the median.
The owner (2026-11-09) saw a half-second freeze at every cut of the light-bridge films.
Run in a container with ffmpeg and numpy:  python3 /opt/tests/freeze_scan.py <film.mp4>...
"""
import subprocess
import sys

import numpy as np

FREEZE = 0.15


def frames(path, w=320, h=176):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-vf", f"scale={w}:{h}", "-f", "rawvideo", "-pix_fmt",
                          "gray", "-"], capture_output=True, check=True, timeout=300).stdout
    n = len(raw) // (w * h)
    return np.frombuffer(raw[:n * w * h], dtype=np.uint8).reshape(n, h, w).astype(np.float32)


def fps(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=r_frame_rate", "-of",
                          "csv=p=0", path], capture_output=True, text=True, check=True, timeout=60).stdout.strip()
    num, den = out.split("/")
    return int(num) / int(den)


def main():
    for p in sys.argv[1:]:
        f, r = frames(p), fps(p)
        d = np.abs(np.diff(f, axis=0)).mean(axis=(1, 2))
        med = float(np.median(d))
        runs, start = [], None
        for i, x in enumerate(list(d) + [med]):
            if x < FREEZE * med and start is None:
                start = i
            elif x >= FREEZE * med and start is not None:
                if i - start >= 2:
                    runs.append((start, i))
                start = None
        txt = ", ".join(f"{a / r:.2f}-{(b + 1) / r:.2f} s ({b - a + 1} frames)" for a, b in runs) or "none"
        print(f"{p.split('/')[-1]}: {len(f)} frames at {r:g} fps, median step {med:.2f}; frozen: {txt}", flush=True)


if __name__ == "__main__":
    main()
