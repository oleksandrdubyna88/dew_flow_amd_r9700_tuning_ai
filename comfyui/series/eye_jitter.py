"""Eye jitter per clip (the owner, 2026-11-09: "the eyes dance — not often, but it still happens").
The first version found the face by skin colour and failed its own check (it rated the steady new shot 3 worse than the
blinking old one: the neck and hands joined the "face"). This one uses kornia's YuNet face detector (kornia 0.9.0 in the
image; weights yunet_final.pth, 396 kB, from huggingface.co/kornia/yunet, cached in the volume hf-cache), which also gives
the two eye points. Per frame, each eye is cut out around its point (size from the distance between the eyes, so scale
and head motion cancel) and resized to 32x20; e(t) = mean |eye patches(t) - eye patches(t-1)|. A dancing eye or a blink
is a step where e jumps above the clip's own calm level: a JUMP is e > JUMP x median(e) and e > E_MIN.
Prints per clip: jumps (frame, e/median), the score (sum of e/median over jumps), frames without a face.
Run (no GPU):  python3 /opt/tests/eye_jitter.py <clip.mp4>...   (with -v hf-cache:/root/.cache)
"""
import subprocess
import sys

import numpy as np
import torch
import torch.nn.functional as F
from kornia.contrib import FaceDetector, FaceDetectorResult, FaceKeypoint

W, H = 960, 528
JUMP, E_MIN, SCORE_MIN = 2.2, 4.0, 0.6


def frames(path):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-threads", "2", "-i", path, "-vf", f"scale={W}:{H}", "-f", "rawvideo",
                          "-pix_fmt", "rgb24", "-"], capture_output=True, check=True, timeout=300).stdout
    n = len(raw) // (W * H * 3)
    return torch.from_numpy(np.frombuffer(raw[:n * W * H * 3], dtype=np.uint8).reshape(n, H, W, 3).copy())


def eye_patch(gray, pt, d):
    w, h = max(4, int(0.55 * d)), max(3, int(0.35 * d))
    x, y = int(pt[0]), int(pt[1])
    y0, y1, x0, x1 = max(0, y - h // 2), min(H, y + h // 2 + 1), max(0, x - w // 2), min(W, x + w // 2 + 1)
    p = gray[y0:y1, x0:x1]
    if p.numel() == 0:
        return None
    return F.interpolate(p[None, None], size=(20, 32), mode="bilinear", align_corners=False)[0, 0]


def analyse(det, path):
    v = frames(path)
    patches, missing = [], 0
    with torch.no_grad():
        for t in range(len(v)):
            img = v[t].permute(2, 0, 1).float() / 255.0
            res = [FaceDetectorResult(o) for o in det(img[None])[0]]
            res = [r for r in res if float(r.score) > SCORE_MIN]
            if not res:
                patches.append(None); missing += 1
                continue
            r = max(res, key=lambda r: float(r.width * r.height))
            le, re_ = r.get_keypoint(FaceKeypoint.EYE_LEFT).tolist(), r.get_keypoint(FaceKeypoint.EYE_RIGHT).tolist()
            d = float(np.hypot(le[0] - re_[0], le[1] - re_[1]))
            gray = img.mean(0) * 255.0
            a, b = eye_patch(gray, le, d), eye_patch(gray, re_, d)
            patches.append(None if a is None or b is None or d < 6 else torch.cat([a, b], 1))
    es = []
    for t in range(1, len(v)):
        if patches[t] is None or patches[t - 1] is None:
            continue
        es.append((t, float((patches[t] - patches[t - 1]).abs().mean())))
    name = "/".join(path.split("/")[-3:])
    if len(es) < 5:
        print(f"{name}: too few frames with a face ({len(v) - missing}/{len(v)})", flush=True)
        return
    med = float(np.median([e for _, e in es])) + 1e-3
    jumps = [(t, round(e / med, 1)) for t, e in es if e > JUMP * med and e > E_MIN]
    score = sum(j for _, j in jumps)
    print(f"{name}: score {score:.1f}, {len(jumps)} jumps, calm level {med:.1f}, no face in {missing}/{len(v)}; "
          f"jumps (frame, x median): {jumps[:10]}", flush=True)


if __name__ == "__main__":
    det = FaceDetector()
    for p in sys.argv[1:]:
        analyse(det, p)
