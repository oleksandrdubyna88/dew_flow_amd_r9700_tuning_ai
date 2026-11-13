"""Try step-distillation LoRAs on Wan 2.2 TI2V 5B: shot 1 of the elf series, same keyframe, prompt and seed as the
20-step clip, with the LoRA and few steps without CFG. One clip per variant, timed per node.

Run inside the container:  wslc exec comfyui python /opt/tests/lora_try.py [variant...]
Writes /data/output/series/elf/lora_try/<variant>_*.mp4 and appends JSON lines to /data/output/_bench/lora_try.jsonl.
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
OUT = "/data/output/_bench/lora_try.jsonl"
FASTWAN = "Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors"
TURBO = "Wan22_TI2V_5B_Turbo_lora_rank_64_fp16.safetensors"

# name: (lora file or None, steps, cfg, sampler, scheduler, shift)
VARIANTS = {
    "fastwan_lcm3_s8": (FASTWAN, 3, 1.0, "lcm", "simple", 8.0),
    "fastwan_lcm4_s8": (FASTWAN, 4, 1.0, "lcm", "simple", 8.0),
    "fastwan_lcm3_s5": (FASTWAN, 3, 1.0, "lcm", "simple", 5.0),
    "fastwan_euler4_s8": (FASTWAN, 4, 1.0, "euler", "simple", 8.0),
    "turbo_lcm4_s8": (TURBO, 4, 1.0, "lcm", "simple", 8.0),
    "turbo_euler4_s8": (TURBO, 4, 1.0, "euler", "simple", 8.0),
}


def post(path, body):
    req = urllib.request.Request(API + path, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def get(path):
    with urllib.request.urlopen(API + path, timeout=30) as r:
        return json.load(r)


def workflow(name, v):
    lora, steps, cfg, sampler, scheduler, shift = v
    k = int(os.environ.get("SHOT", "1"))  # which shot of the series, 1..6
    shot = story.SHOTS[k - 1]
    wf = story.video_wf(k, shot, f"{story.NAME}_key_s{k}.png")
    model_src = "unet"
    if lora:
        wf["lora"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["unet", 0], "lora_name": lora, "strength_model": 1.0}}
        model_src = "lora"
    wf["shift"]["inputs"].update({"model": [model_src, 0], "shift": shift})
    wf["sampler"]["inputs"].update({"steps": steps, "cfg": cfg, "sampler_name": sampler, "scheduler": scheduler})
    wf["save"]["inputs"]["filename_prefix"] = f"series/{story.NAME}/lora_try/s{k}_{name}"
    return wf


def run(wf, ceiling=3600):
    cid = str(uuid.uuid4())
    pid = post("/prompt", {"prompt": wf, "client_id": cid})["prompt_id"]
    t0 = time.time()
    while time.time() - t0 < ceiling:
        h = get("/history/" + pid)
        if pid in h:
            st = h[pid].get("status", {})
            msgs = {m[0]: m[1].get("timestamp") for m in st.get("messages", []) if isinstance(m, list) and len(m) == 2}
            return time.time() - t0, st.get("status_str"), msgs
        time.sleep(0.5)
    return time.time() - t0, "ceiling", {}


def main():
    names = sys.argv[1:] or list(VARIANTS)
    for name in names:
        secs, status, _ = run(workflow(name, VARIANTS[name]))
        row = {"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "variant": name, "settings": VARIANTS[name],
               "seconds": round(secs, 2), "status": status}
        with open(OUT, "a") as f:
            f.write(json.dumps(row) + "\n")
        print(f"{name}: {secs:.1f} s {status}", flush=True)


if __name__ == "__main__":
    main()
