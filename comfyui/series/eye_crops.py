"""Eye close-ups for judging by EYE (the automatic jitter score failed its check, 2026-11-09): per clip, every 2nd frame of
the first 48, the face found by kornia's YuNet, a band around both eye points (size from the eye distance), enlarged to
256x64, tiled 6x4. Frames without a face are black.
Run (no GPU, -v hf-cache:/root/.cache):  python3 /opt/tests/eye_crops.py <out.png> <clip.mp4>...  (one row block per clip)
"""
import subprocess
import sys

import numpy as np
import torch
import torch.nn.functional as F
from kornia.contrib import FaceDetector, FaceDetectorResult, FaceKeypoint
from PIL import Image, ImageDraw

W, H = 1280, 704


def frames(path):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-threads", "2", "-i", path, "-vf", "select=lt(n\\,48)*not(mod(n\\,2))",
                          "-vsync", "0", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True,
                         timeout=300).stdout
    n = len(raw) // (W * H * 3)
    return np.frombuffer(raw[:n * W * H * 3], dtype=np.uint8).reshape(n, H, W, 3)


def band(det, img):
    t = torch.from_numpy(img.copy()).permute(2, 0, 1).float() / 255.0
    small = F.interpolate(t[None], size=(H // 2, W // 2), mode="bilinear", align_corners=False)
    res = [FaceDetectorResult(o) for o in det(small)[0]]
    res = [r for r in res if float(r.score) > 0.6]
    if not res:
        return None
    r = max(res, key=lambda r: float(r.width * r.height))
    le = r.get_keypoint(FaceKeypoint.EYE_LEFT).tolist()
    re_ = r.get_keypoint(FaceKeypoint.EYE_RIGHT).tolist()
    cx, cy = (le[0] + re_[0]), (le[1] + re_[1])  # x2 for full size, /2 for the mean
    d = 2 * abs(le[0] - re_[0]) + 1
    w, h = int(2.0 * d), int(0.5 * d)
    x0, y0 = max(0, int(cx - w / 2)), max(0, int(cy - h / 2))
    return Image.fromarray(img[y0:y0 + h, x0:x0 + w]).resize((256, 64))


def main():
    det = FaceDetector()
    out_path, clips = sys.argv[1], sys.argv[2:]
    sheet = Image.new("RGB", (6 * 256, len(clips) * (4 * 64 + 16)), "black")
    draw = ImageDraw.Draw(sheet)
    for ci, path in enumerate(clips):
        top = ci * (4 * 64 + 16)
        draw.text((4, top + 2), path.split("/")[-1], fill="white")
        for i, img in enumerate(frames(path)[:24]):
            b = band(det, img)
            if b is not None:
                sheet.paste(b, ((i % 6) * 256, top + 16 + (i // 6) * 64))
    sheet.save(out_path)
    print("wrote", out_path, flush=True)


if __name__ == "__main__":
    main()
