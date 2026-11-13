"""Sweep the tiled VAE decode of Wan 2.2 TI2V 5B (1280x704, 121 frames) with the sampler held in ComfyUI's cache.

The first prompt runs the sampler once (fixed seed); every later prompt changes only the decode node, so ComfyUI re-runs
the decode alone and its time is the decode's. A config that does not fit is reported as failed and the sweep goes on.
Run inside the container:  wslc exec comfyui python /opt/tests/vae_sweep.py
Prints one line per config and appends JSON lines to /data/output/_bench/vae_sweep.jsonl.
"""
import json
import os
import sys
import time
import urllib.request
import uuid

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bench  # noqa: E402  the wan5b workflow

API = "http://127.0.0.1:8188"
OUT = "/data/output/_bench/vae_sweep.jsonl"
CONFIGS = [  # tile_size, overlap, temporal_size, temporal_overlap
    (512, 64, 32, 8),     # the series' setting: the reference
    (512, 64, 64, 8),
    (768, 64, 32, 8),
    (768, 64, 64, 8),
    (1024, 64, 32, 8),
    (1024, 64, 64, 8),
    (512, 32, 32, 4),
    (1280, 64, 32, 8),
]


def post(path, body):
    req = urllib.request.Request(API + path, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def get(path):
    with urllib.request.urlopen(API + path, timeout=30) as r:
        return json.load(r)


def run(wf, ceiling):
    pid = post("/prompt", {"prompt": wf, "client_id": str(uuid.uuid4())})["prompt_id"]
    t0 = time.time()
    while time.time() - t0 < ceiling:
        h = get("/history/" + pid)
        if pid in h:
            return time.time() - t0, h[pid].get("status", {}).get("status_str"), h[pid].get("status", {})
        time.sleep(0.5)
    post("/interrupt", {})
    return time.time() - t0, "ceiling", {}


class A:  # the bench arguments bench.wan5b reads
    tag, width, height, length, steps, weight_dtype, model_src = "vae_sweep", None, None, None, None, "default", None


CONFIGS2 = [  # the second sweep: smaller tiles and overlaps (the first found larger tiles much slower)
    (512, 32, 32, 4),     # the first sweep's fastest: the reference
    (384, 32, 32, 4),
    (256, 32, 32, 4),
    (512, 32, 16, 4),
    (512, 32, 64, 4),
    (384, 32, 64, 4),
    (512, 16, 32, 4),
]


def main():
    configs = CONFIGS2 if "--second" in sys.argv else CONFIGS
    for i, (ts, ov, tt, to) in enumerate(configs):
        wf = bench.wan5b(A, seed=777)
        wf["vae"]["inputs"].update({"tile_size": ts, "overlap": ov, "temporal_size": tt, "temporal_overlap": to})
        wf["save"]["inputs"]["filename_prefix"] = f"_bench/vae_sweep/t{ts}_o{ov}_tt{tt}_to{to}"
        secs, status, st = run(wf, 1800)
        row = {"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "tile": ts, "overlap": ov, "temporal": tt,
               "temporal_overlap": to, "seconds": round(secs, 2), "status": status, "first": i == 0}
        with open(OUT, "a") as f:
            f.write(json.dumps(row) + "\n")
        note = " (includes the sampler: first prompt)" if i == 0 else " (decode + save only)"
        print(f"tile {ts} overlap {ov} temporal {tt}/{to}: {secs:.1f} s {status}{note}", flush=True)


if __name__ == "__main__":
    main()
