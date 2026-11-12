"""Compare two clips frame by frame (same seed, different decode): mean absolute difference and PSNR per sampled frame.

Run inside the container:  wslc exec comfyui python /opt/tests/frame_diff.py <a.mp4> <b.mp4> [frames...]
Uses ffmpeg to dump raw RGB frames and numpy to compare; prints one line per frame and the worst.
"""
import subprocess
import sys

import numpy as np


def frame(path, n, w=1280, h=704):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-vf", f"select=eq(n\\,{n})", "-vframes", "1",
                          "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True, timeout=120).stdout
    return np.frombuffer(raw, dtype=np.uint8).reshape(h, w, 3).astype(np.float64)


def main():
    a, b = sys.argv[1], sys.argv[2]
    frames = [int(x) for x in sys.argv[3:]] or [0, 30, 60, 90, 120]
    worst = 99.0
    for n in frames:
        fa, fb = frame(a, n), frame(b, n)
        mse = float(np.mean((fa - fb) ** 2))
        psnr = 99.0 if mse == 0 else 10 * np.log10(255.0 ** 2 / mse)
        worst = min(worst, psnr)
        print(f"frame {n}: mean abs diff {np.mean(np.abs(fa - fb)):.3f}, PSNR {psnr:.2f} dB", flush=True)
    print(f"worst PSNR {worst:.2f} dB")


if __name__ == "__main__":
    main()
