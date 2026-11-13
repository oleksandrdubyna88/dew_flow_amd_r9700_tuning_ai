"""Smoke test: queue one txt2img prompt on the local ComfyUI API and time it.

Run inside the container (stdlib only):
  wslc exec comfyui python /opt/tests/smoke_txt2img.py [checkpoint] [width] [height] [steps] [batch]
(the start script mounts this folder at /opt/tests). Prints the seconds per run and the output files.
"""
import json
import sys
import time
import urllib.request
import uuid

API = "http://127.0.0.1:8188"


def post(path, body):
    req = urllib.request.Request(API + path, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def get(path):
    with urllib.request.urlopen(API + path) as r:
        return json.load(r)


def workflow(ckpt, w, h, steps, batch, seed):
    return {
        "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": ckpt}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": w, "height": h, "batch_size": batch}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["4", 1],
              "text": "a cozy wooden cabin in a snowy forest at dusk, warm light in the windows, detailed"}},
        "7": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["4", 1], "text": "blurry, low quality"}},
        "3": {"class_type": "KSampler", "inputs": {"model": ["4", 0], "positive": ["6", 0], "negative": ["7", 0],
              "latent_image": ["5", 0], "seed": seed, "steps": steps, "cfg": 7.0,
              "sampler_name": "euler", "scheduler": "normal", "denoise": 1.0}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
        "9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": "smoke"}},
    }


def run_once(wf):
    pid = post("/prompt", {"prompt": wf, "client_id": str(uuid.uuid4())})["prompt_id"]
    t0 = time.time()
    while True:
        hist = get("/history/" + pid)
        if pid in hist:
            entry = hist[pid]
            status = entry.get("status", {})
            if status.get("status_str") == "error":
                raise SystemExit("prompt failed: " + json.dumps(status)[:2000])
            files = [img["filename"] for out in entry.get("outputs", {}).values() for img in out.get("images", [])]
            return time.time() - t0, files
        time.sleep(0.2)


def main():
    ckpt = sys.argv[1] if len(sys.argv) > 1 else "v1-5-pruned-emaonly-fp16.safetensors"
    w, h = int(sys.argv[2]) if len(sys.argv) > 2 else 512, int(sys.argv[3]) if len(sys.argv) > 3 else 512
    steps = int(sys.argv[4]) if len(sys.argv) > 4 else 20
    batch = int(sys.argv[5]) if len(sys.argv) > 5 else 1
    for i in range(3):  # run 1 includes model load and kernel compile; runs 2-3 are the steady speed
        secs, files = run_once(workflow(ckpt, w, h, steps, batch, seed=1000 + i))
        print(f"run {i + 1}: {secs:.2f} s  ({steps / secs:.2f} it/s incl. VAE)  {files}")


if __name__ == "__main__":
    main()
