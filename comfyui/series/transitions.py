"""Soften the cuts between shots: the owner (2026-11-09) sees the light and shadows on her face jump at a cut.

"Light bridge": for the first BRIDGE_S seconds of every shot after the first, each RGB channel's mean and spread are pulled
toward those of the previous shot's last frame, with a weight that eases from 1 to 0 (smoothstep), so the new shot starts
in the old light and settles into its own; each shot keeps its mood after the bridge. Optional dissolve: the last DISSOLVE_S
of a shot is blended into the start of the next (the film gets shorter by that much per cut).

Run in a container with ffmpeg and numpy:
  python3 /opt/tests/transitions.py <out.mp4> <clip1.mp4> <clip2.mp4> ... [--dissolve 0.4] [--bridge 1.0]
"""
import argparse
import json
import subprocess

import numpy as np


def probe(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height,r_frame_rate",
                          "-of", "json", path], capture_output=True, text=True, check=True, timeout=60).stdout
    s = json.loads(out)["streams"][0]
    num, den = s["r_frame_rate"].split("/")
    return s["width"], s["height"], round(int(num) / int(den))


def read(path, w, h):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                         capture_output=True, check=True, timeout=600).stdout
    n = len(raw) // (w * h * 3)
    return np.frombuffer(raw[:n * w * h * 3], dtype=np.uint8).reshape(n, h, w, 3).astype(np.float32)


def stats(frame):
    return frame.reshape(-1, 3).mean(axis=0), frame.reshape(-1, 3).std(axis=0) + 1e-3


def bridge(clip, prev_last, fps, seconds):
    """Pull the first frames of `clip` toward the light of `prev_last`, easing out."""
    n = min(len(clip), int(round(seconds * fps)))
    m_to, s_to = stats(prev_last)
    m_from, s_from = stats(clip[0])
    for i in range(n):
        t = i / max(1, n - 1)
        w = 1.0 - (t * t * (3 - 2 * t))  # smoothstep from 1 to 0
        mapped = (clip[i] - m_from) / s_from * s_to + m_to
        clip[i] = np.clip(clip[i] * (1 - w) + mapped * w, 0, 255)
    return clip


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("clips", nargs="+")
    ap.add_argument("--bridge", type=float, default=1.0)
    ap.add_argument("--dissolve", type=float, default=0.0)
    a = ap.parse_args()
    w, h, fps = probe(a.clips[0])
    enc = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{w}x{h}",
                            "-r", str(fps), "-i", "-", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18",
                            # tag the colours like the plain films (the first bridge films were untagged; a player may guess)
                            "-color_range", "tv", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709",
                            "-movflags", "+faststart", a.out], stdin=subprocess.PIPE)
    d = int(round(a.dissolve * fps))
    tail = None  # the frames of the previous clip held back for the dissolve
    total = 0
    for k, path in enumerate(a.clips):
        clip = read(path, w, h)
        if k > 0 and a.bridge > 0:
            clip = bridge(clip, prev_last, fps, a.bridge)
        if tail is not None and d > 0:
            for i in range(d):
                alpha = (i + 1) / (d + 1)
                clip[i] = tail[i] * (1 - alpha) + clip[i] * alpha
        prev_last = clip[-1].copy()
        keep = clip[:-d] if (d > 0 and k < len(a.clips) - 1) else clip
        tail = clip[-d:].copy() if (d > 0 and k < len(a.clips) - 1) else None
        enc.stdin.write(keep.astype(np.uint8).tobytes())
        total += len(keep)
        print(f"clip {k + 1}: {len(clip)} frames, {len(keep)} written", flush=True)
    enc.stdin.close()
    enc.wait(timeout=600)
    print(f"written: {a.out} ({total} frames, {total / fps:.2f} s at {fps} fps)", flush=True)


if __name__ == "__main__":
    main()
