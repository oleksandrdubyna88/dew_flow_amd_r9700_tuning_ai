"""A number for the "mesh": the mean absolute response of a 2x2 checkerboard kernel (a[i,j]-a[i+1,j]-a[i,j+1]+a[i+1,j+1])
on the luma, over sampled frames of a clip — high for a fine diagonal/checker hatching, low for smooth images. Compared
against the clip's own start keyframe (the clean reference). Same codec for every clip, so the comparison is fair.

Run inside the container:  wslc exec comfyui python /opt/tests/mesh_metric.py <clip.mp4>... [--png <image.png>...]
"""
import subprocess
import sys

import numpy as np

W, H = 1280, 704


def checker(luma):
    a = luma.astype(np.float64)
    return float(np.mean(np.abs(a[:-1, :-1] - a[1:, :-1] - a[:-1, 1:] + a[1:, 1:])))


def luma_frames(path, every=10):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-vf", f"select=not(mod(n\\,{every}))",
                          "-vsync", "0", "-f", "rawvideo", "-pix_fmt", "gray", "-"], capture_output=True, check=True,
                         timeout=600).stdout
    n = len(raw) // (W * H)
    return [np.frombuffer(raw[i * W * H:(i + 1) * W * H], dtype=np.uint8).reshape(H, W) for i in range(n)]


def main():
    args = sys.argv[1:]
    pngs = args[args.index("--png") + 1:] if "--png" in args else []
    clips = args[:args.index("--png")] if "--png" in args else args
    from PIL import Image
    for p in pngs:
        print(f"{checker(np.array(Image.open(p).convert('L'))):7.3f}  png   {p}")
    for c in clips:
        vals = [checker(f) for f in luma_frames(c)]
        print(f"{np.median(vals):7.3f}  clip  median of {len(vals)} frames (max {max(vals):.3f})  {c}", flush=True)


if __name__ == "__main__":
    main()
