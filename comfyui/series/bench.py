"""Benchmark one ComfyUI workflow on the local server, with the time of each node (encoder, sampler, VAE).

Run inside the container:
  wslc exec comfyui python /opt/tests/bench.py <workflow> --tag <name> [--runs 3] [--steps N] [--width W --height H]
                                                       [--length FRAMES] [--weight-dtype default|fp8_e4m3fn] [--compile]
Workflows: sd15, zimage (Z-Image Turbo, 1024x1024, 8 steps), wan5b (Wan 2.2 TI2V 5B, 1280x704, 121 frames, 20 steps).
Run 1 is cold (model load, kernel compile, tuning); later runs use a new seed, so nothing is cached.
Appends one JSON line per run to /data/output/_bench/results.jsonl (the output folder of the operator's ComfyUI folder, COMFY_HOME_WIN).
"""
import argparse
import asyncio
import json
import os
import time
import uuid

import aiohttp

API = "http://127.0.0.1:8188"
OUT = "/data/output/_bench"


def sd15(a, seed):
    return {
        "ckpt": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "v1-5-pruned-emaonly-fp16.safetensors"}},
        "latent": {"class_type": "EmptyLatentImage", "inputs": {"width": a.width or 512, "height": a.height or 512, "batch_size": 1}},
        "pos": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["ckpt", 1], "text": "a cozy wooden cabin in a snowy forest at dusk"}},
        "neg": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["ckpt", 1], "text": "blurry, low quality"}},
        "sampler": {"class_type": "KSampler", "inputs": {"model": ["ckpt", 0], "positive": ["pos", 0], "negative": ["neg", 0],
                    "latent_image": ["latent", 0], "seed": seed, "steps": a.steps or 20, "cfg": 7.0,
                    "sampler_name": "euler", "scheduler": "normal", "denoise": 1.0}},
        "vae": {"class_type": "VAEDecode", "inputs": {"samples": ["sampler", 0], "vae": ["ckpt", 2]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["vae", 0], "filename_prefix": f"_bench/{a.tag}/sd15"}},
    }


def zimage(a, seed):
    return {
        "unet": {"class_type": "UNETLoader", "inputs": {"unet_name": "z_image_turbo_bf16.safetensors", "weight_dtype": a.weight_dtype}},
        "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_3_4b.safetensors", "type": "lumina2", "device": "default"}},
        "vaeload": {"class_type": "VAELoader", "inputs": {"vae_name": "ae.safetensors"}},
        "shift": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": [a.model_src or "unet", 0], "shift": 3.0}},
        "pos": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text":
                "A lighthouse keeper in a yellow raincoat on wet rocks at sunset, waves crashing, cinematic, detailed, 35mm photo"}},
        "neg": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["pos", 0]}},
        "latent": {"class_type": "EmptySD3LatentImage", "inputs": {"width": a.width or 1024, "height": a.height or 1024, "batch_size": 1}},
        "sampler": {"class_type": "KSampler", "inputs": {"model": ["shift", 0], "positive": ["pos", 0], "negative": ["neg", 0],
                    "latent_image": ["latent", 0], "seed": seed, "steps": a.steps or 8, "cfg": 1.0,
                    "sampler_name": "res_multistep", "scheduler": "simple", "denoise": 1.0}},
        "vae": {"class_type": "VAEDecode", "inputs": {"samples": ["sampler", 0], "vae": ["vaeload", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["vae", 0], "filename_prefix": f"_bench/{a.tag}/zimage"}},
    }


def wan5b(a, seed):
    return {
        "unet": {"class_type": "UNETLoader", "inputs": {"unet_name": "wan2.2_ti2v_5B_fp16.safetensors", "weight_dtype": a.weight_dtype}},
        "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": "umt5_xxl_fp8_e4m3fn_scaled.safetensors", "type": "wan", "device": "default"}},
        "vaeload": {"class_type": "VAELoader", "inputs": {"vae_name": "wan2.2_vae.safetensors"}},
        "shift": {"class_type": "ModelSamplingSD3", "inputs": {"model": [a.model_src or "unet", 0], "shift": 8.0}},
        "pos": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text":
                "In a retro 1970s subway station, a street musician plays guitar with focus while commuters hurry by. "
                "The camera slowly moves right, old subway signs and mottled walls in the background."}},
        "neg": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text":
                "static, blurry details, subtitles, worst quality, low quality, JPEG artifacts, deformed, extra fingers"}},
        "latent": {"class_type": "Wan22ImageToVideoLatent", "inputs": {"vae": ["vaeload", 0], "width": a.width or 1280,
                   "height": a.height or 704, "length": a.length or 121, "batch_size": 1}},
        "sampler": {"class_type": "KSampler", "inputs": {"model": ["shift", 0], "positive": ["pos", 0], "negative": ["neg", 0],
                    "latent_image": ["latent", 0], "seed": seed, "steps": a.steps or 20, "cfg": 5.0,
                    "sampler_name": "uni_pc", "scheduler": "simple", "denoise": 1.0}},
        # tiled: the untiled decode of 121 frames at 1280x704 stalled on the R9700 (2026-11-07)
        "vae": {"class_type": "VAEDecodeTiled", "inputs": {"samples": ["sampler", 0], "vae": ["vaeload", 0], "tile_size": 512,
                "overlap": 64, "temporal_size": 32, "temporal_overlap": 8}},
        "video": {"class_type": "CreateVideo", "inputs": {"images": ["vae", 0], "fps": 24.0}},
        "save": {"class_type": "SaveVideo", "inputs": {"video": ["video", 0], "filename_prefix": f"_bench/{a.tag}/wan5b",
                 "format": "auto", "codec": "auto"}},
    }


WORKFLOWS = {"sd15": sd15, "zimage": zimage, "wan5b": wan5b}


def add_compile(wf):
    """Insert TorchCompileModel between the loader and the sampling-shift node (inductor backend)."""
    wf["compile"] = {"class_type": "TorchCompileModel", "inputs": {"model": ["unet", 0], "backend": "inductor"}}
    return wf


async def run_once(session, wf):
    client_id = str(uuid.uuid4())
    times, order = {}, []
    async with session.ws_connect(f"{API}/ws?clientId={client_id}", max_msg_size=0) as ws:
        async with session.post(f"{API}/prompt", json={"prompt": wf, "client_id": client_id}) as r:
            body = await r.json()
            if "prompt_id" not in body:
                raise SystemExit("prompt refused: " + json.dumps(body)[:3000])
            pid = body["prompt_id"]
        t0 = time.perf_counter()
        current, started = None, t0
        async for msg in ws:
            if msg.type != aiohttp.WSMsgType.TEXT:
                continue
            m = json.loads(msg.data)
            data = m.get("data", {})
            if data.get("prompt_id") not in (None, pid):
                continue
            now = time.perf_counter()
            if m["type"] == "executing":
                if current is not None:
                    times[current] = times.get(current, 0.0) + (now - started)
                current, started = data.get("node"), now
                if current is not None and current not in order:
                    order.append(current)
                if current is None:
                    break
            elif m["type"] == "execution_error":
                raise SystemExit("execution error: " + json.dumps(data)[:3000])
        total = time.perf_counter() - t0
    async with session.get(f"{API}/system_stats") as r:
        stats = await r.json()
    return total, {k: round(times[k], 3) for k in order if k in times}, stats["devices"][0]


async def main():
    p = argparse.ArgumentParser()
    p.add_argument("workflow", choices=sorted(WORKFLOWS))
    p.add_argument("--tag", required=True)
    p.add_argument("--runs", type=int, default=3)
    p.add_argument("--steps", type=int)
    p.add_argument("--width", type=int)
    p.add_argument("--height", type=int)
    p.add_argument("--length", type=int)
    p.add_argument("--weight-dtype", default="default")
    p.add_argument("--compile", action="store_true")
    p.add_argument("--note", default="")
    a = p.parse_args()
    a.model_src = "compile" if a.compile else None
    os.makedirs(OUT, exist_ok=True)
    async with aiohttp.ClientSession() as session:
        async with session.get(f"{API}/system_stats") as r:
            argv = (await r.json())["system"]["argv"]
        for i in range(a.runs):
            wf = WORKFLOWS[a.workflow](a, seed=4242 + i)
            if a.compile:
                wf = add_compile(wf)
            total, nodes, dev = await run_once(session, wf)
            row = {"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "tag": a.tag, "workflow": a.workflow, "run": i + 1,
                   "total_s": round(total, 3), "nodes_s": nodes, "steps": a.steps, "weight_dtype": a.weight_dtype,
                   "compile": a.compile, "width": a.width, "height": a.height, "length": a.length, "note": a.note,
                   "server_argv": argv[1:], "env": {k: v for k, v in os.environ.items() if k.startswith(
                       ("PYTORCH_", "MIOPEN_", "COMFYUI_", "TORCH_", "HIP", "HSA_", "TRITON_"))},
                   "vram_free_after": dev.get("vram_free")}
            with open(f"{OUT}/results.jsonl", "a") as f:
                f.write(json.dumps(row) + "\n")
            main_nodes = {k: v for k, v in nodes.items() if k in ("pos", "sampler", "vae", "save", "unet", "clip", "compile")}
            print(f"{a.tag} {a.workflow} run {i + 1}: {total:.2f} s  {main_nodes}", flush=True)


if __name__ == "__main__":
    asyncio.run(main())
