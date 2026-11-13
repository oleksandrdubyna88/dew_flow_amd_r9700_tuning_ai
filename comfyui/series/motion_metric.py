"""How much a clip moves: mean absolute luma difference between frames `gap` apart, median over the clip.
Run inside the container:  wslc exec comfyui python /opt/tests/motion_metric.py <clip.mp4>... [--gap 20]
"""
import subprocess
import sys

import numpy as np

W, H = 1280, 704


def frames(path):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", "gray", "-"],
                         capture_output=True, check=True, timeout=600).stdout
    n = len(raw) // (W * H)
    return np.frombuffer(raw[:n * W * H], dtype=np.uint8).reshape(n, H, W).astype(np.float32)


def main():
    args = sys.argv[1:]
    gap = int(args[args.index("--gap") + 1]) if "--gap" in args else 20
    clips = [a for a in args if a.endswith(".mp4")]
    for c in clips:
        f = frames(c)
        d = [float(np.mean(np.abs(f[i + gap] - f[i]))) for i in range(0, len(f) - gap, 5)]
        print(f"{np.median(d):6.2f}  motion (median |frame diff| at gap {gap}, {len(f)} frames)  {c}", flush=True)


if __name__ == "__main__":
    main()
