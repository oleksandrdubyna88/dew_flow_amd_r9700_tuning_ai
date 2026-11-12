"""Find where the "mesh" seen on the elf clips comes from: the model/VAE, or the video encoding.

Renders shot 6 (bright waterfall) exactly as the series did, saves the LATENT, and from the same decode saves frame 60 as a
lossless PNG and the clip as MP4. Then decodes the saved latent again with other decode settings (each a PNG of frame 60).
Run inside the container:  wslc exec comfyui python /opt/tests/mesh_test.py [render|decode]
Outputs under /data/output/series/elf/mesh/.
"""
import json
import os
import sys
import time
import urllib.request
import uuid

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import series_elf as story  # noqa: E402

API = "http://127.0.0.1:8188"
P = "series/elf/mesh/"


def post(path, body):
    req = urllib.request.Request(API + path, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def get(path):
    with urllib.request.urlopen(API + path, timeout=30) as r:
        return json.load(r)


def run(wf, ceiling=3600):
    pid = post("/prompt", {"prompt": wf, "client_id": str(uuid.uuid4())})["prompt_id"]
    t0 = time.time()
    while time.time() - t0 < ceiling:
        h = get("/history/" + pid)
        if pid in h:
            return time.time() - t0, h[pid].get("status", {}).get("status_str")
        time.sleep(1)
    return time.time() - t0, "ceiling"


def frame_nodes(src, name):
    return {
        f"pick_{name}": {"class_type": "ImageFromBatch", "inputs": {"image": [src, 0], "batch_index": 60, "length": 1}},
        f"png_{name}": {"class_type": "SaveImage", "inputs": {"images": [f"pick_{name}", 0], "filename_prefix": P + f"f60_{name}"}},
    }


def render():
    wf = story.video_wf(6, story.SHOTS[5], "elf_key_s6.png")
    tag = os.environ.get("MESH_TAG", "")
    wf["save"]["inputs"]["filename_prefix"] = P + "clip_tiled_512_64_32_8" + (f"_{tag}" if tag else "")
    for k, v in (("steps", "MESH_STEPS"), ("sampler_name", "MESH_SAMPLER"), ("cfg", "MESH_CFG")):
        if os.environ.get(v):
            wf["sampler"]["inputs"][k] = type(wf["sampler"]["inputs"][k])(os.environ[v])
    wf["latent_out"] = {"class_type": "SaveLatent", "inputs": {"samples": ["sampler", 0], "filename_prefix": P + "s6" + (f"_{tag}" if tag else "")}}
    wf.update(frame_nodes("decode", "tiled_512_64_32_8" + (f"_{tag}" if tag else "")))
    print("render:", run(wf), flush=True)


def decode():
    lat = sorted(f for f in os.listdir("/data/output/" + P) if f.endswith(".latent"))[-1]
    os.makedirs("/data/input", exist_ok=True)
    import shutil
    shutil.copyfile("/data/output/" + P + lat, "/data/input/" + lat)  # output is another mount: copy, never rename
    base = {
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "wan2.2_vae.safetensors"}},
        "lat": {"class_type": "LoadLatent", "inputs": {"latent": lat}},
    }
    variants = {
        "tiled_512_32_64_4": {"class_type": "VAEDecodeTiled", "inputs": {"samples": ["lat", 0], "vae": ["vae", 0],
                              "tile_size": 512, "overlap": 32, "temporal_size": 64, "temporal_overlap": 4}},
        "tiled_768_128_32_8": {"class_type": "VAEDecodeTiled", "inputs": {"samples": ["lat", 0], "vae": ["vae", 0],
                               "tile_size": 768, "overlap": 128, "temporal_size": 32, "temporal_overlap": 8}},
    }
    tag = os.environ.get("MESH_TAG", "")
    if tag:  # the server runs with another VAE precision (e.g. --fp32-vae): decode once with the series' setting
        variants = {f"tiled_512_64_32_8_{tag}": {"class_type": "VAEDecodeTiled", "inputs": {"samples": ["lat", 0], "vae": ["vae", 0],
                    "tile_size": 512, "overlap": 64, "temporal_size": 32, "temporal_overlap": 8}}}
    for name, node in variants.items():
        wf = dict(base, dec=node)
        wf.update(frame_nodes("dec", name))
        print(name, run(wf), flush=True)


if __name__ == "__main__":
    (decode if "decode" in sys.argv[1:] else render)()
