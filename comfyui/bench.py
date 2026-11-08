#!/usr/bin/env python3
"""The ComfyUI bench: queues ONE workflow on a ComfyUI server, times it, checks its output, and prints the verdict grammar (E2.S2).

  bench.py workflows                          the legal workflow names, one per line, sorted               (standard library only: runs on the host)
  bench.py metrics                            the metrics of a block, the deciding one first               (standard library only)
  bench.py words                              the two COMFY_BENCH_* words an arm may set, one per line                                  (standard library only)
  bench.py models <workflow>                  the model files the workflow loads, `<folder>/<file>` per line, sorted                      (standard library only)
  bench.py constants <workflow>               ONE JSON object: every pinned input of the graph, the seeds, the ceilings, the metrics, the timed nodes
  bench.py graph <workflow> --seed <n> [--run <label>]   the ComfyUI prompt JSON on stdout; COMFY_BENCH_WEIGHT_DTYPE and COMFY_BENCH_COMPILE shape it
  bench.py run <workflow> --tag <tag> --run <cold|1|2|3> --out <dir>   one queued run against the server (aiohttp)
  bench.py check <file> --workflow <workflow> an output is the workflow's: its size, its frame count, its pixels are not one colour (Pillow, numpy, ffprobe)
  bench.py drift <workflow> --out <dir> --ref <dir>   per measured seed the mean absolute difference and the PSNR against the reference of the same seed

THE ONE TABLE. `WORKFLOWS`, `SEEDS`, `CEILINGS` and `METRICS` below are the only place a seed, a ceiling, a tile value or a model name is typed: the graphs are
built from them, `constants` prints them, and lib/comfy_bench.sh records `constants` in the fingerprint of an experiment.

The output of a measured run is exactly the three lines of lib/verdict.py's comfy grammar, `<tag> <workflow> r=<n> <metric>: <value>` (three decimals), printed only
after the run, its output check and its cache check all passed; the cold run prints `cold: total <s> s` and nothing else. A failed run prints one last line that names
its kind: `EXECUTION_ERROR: node <id> (<type>): <message>`, `PROMPT: refused: <error>`, `CACHED: the sampler did not execute (cached: <ids>)` (or the decode node: an absent time is not zero), `OUTPUT: <why>`; a
ceiling prints `COLD_TIMEOUT <seconds reached>` or `RUN_TIMEOUT <seconds reached>`.
Time. `total_s` is the time from the POST of the prompt to the first poll of /history/<id> that finds the entry; a node's time runs from its `executing` message to the
next one (`sampler_s` and `vae_s` are the nodes named in `constants`).
Environment. `COMFY_BENCH_WEIGHT_DTYPE` (the loader's weight_dtype) and `COMFY_BENCH_COMPILE=1` (a TorchCompileModel node after the loader) are the two words an arm
sets; any other COMFY_BENCH_* name but the knobs below is refused. Knobs, the environment only: COMFY_BENCH_API (the server, default http://127.0.0.1:8188),
COMFY_BENCH_TEST_RUN_MAX_S and COMFY_BENCH_TEST_COLD_MAX_S (replace the table's ceilings).
Exit codes. 0 ok; 1 a failed run or check (the last line names the kind); 2 a bad argument or a COMFY_BENCH_* word that is not one; 3 a ceiling.
Python >= 3.10. The imports of aiohttp, numpy and PIL are inside the functions that need them, so `workflows`, `metrics`, `constants` and `graph` run with the
standard library alone (python3 -I -S).
"""
import argparse
import asyncio
import json
import math
import os
import subprocess
import sys
import time
import uuid

METRICS = ("total_s", "sampler_s", "vae_s")  # the deciding metric first: lib/verdict.py's block starts at its r=1 line
SEEDS = {"cold": 4242, "measured": (1, 2, 3)}  # the cold run's seed is the hand prototype's first; the measured seeds differ from it and from each other
LEGAL_WORDS = ("COMFY_BENCH_WEIGHT_DTYPE", "COMFY_BENCH_COMPILE")
KNOBS = ("COMFY_BENCH_API", "COMFY_BENCH_TEST_RUN_MAX_S", "COMFY_BENCH_TEST_COLD_MAX_S")
WEIGHT_DTYPES = ("default", "fp8_e4m3fn", "fp8_e4m3fn_fast", "fp8_e5m2")  # UNETLoader's own list
NODES = {"sampler": "sampler", "vae": "vae", "save": "save"}  # the graph's node ids the metrics time and the output is read from
CACHE_ROOT = "/cache"
POLL_S = 0.5
FFPROBE_TIMEOUT_S = 300  # one ffprobe -count_frames of a clip
FFMPEG_TIMEOUT_S = 300   # the decode of one frame of a clip
REQUEST_TIMEOUT_S = 60   # one HTTP request to the server (the run itself is under its own ceiling)
WS_CLOSE_TIMEOUT_S = 10  # the close handshake of the websocket
SILENCE_OF_CEILING = 0.5  # a server that sends no websocket message for this part of the run's ceiling is not working on the run: the run fails (HANG) before the ceiling

WAN_LORA = "Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors"
WORKFLOWS = {
    "sd15": {
        "ceilings": {"run_max_s": 120, "cold_max_s": 600},
        "models": {"checkpoints": "v1-5-pruned-emaonly-fp16.safetensors"},
        "prompt": "a photograph of a red fox sitting in a snowy forest, golden hour",
        "negative": "", "width": 512, "height": 512, "length": None, "steps": 20, "sampler": "euler", "scheduler": "normal", "cfg": 8.0, "shift": None,
    },
    "zimage": {
        "ceilings": {"run_max_s": 300, "cold_max_s": 1800},
        "models": {"diffusion_models": "z_image_turbo_bf16.safetensors", "text_encoders": "qwen_3_4b.safetensors", "vae": "ae.safetensors"},
        "prompt": "a photograph of a red fox sitting in a snowy forest, golden hour, detailed fur",
        "negative": "", "clip_type": "lumina2", "width": 1024, "height": 1024, "length": None, "steps": 8, "sampler": "res_multistep", "scheduler": "simple", "cfg": 1.0,
        "shift": 3.0,
    },
    "wan5b": {
        "ceilings": {"run_max_s": 600, "cold_max_s": 2700},
        "models": {"diffusion_models": "wan2.2_ti2v_5B_fp16.safetensors", "text_encoders": "umt5_xxl_fp8_e4m3fn_scaled.safetensors", "vae": "wan2.2_vae.safetensors",
                   "loras": WAN_LORA},
        "prompt": "a lighthouse on a rocky coast at sunset, waves breaking on the rocks, slow camera drift, cinematic",
        "negative": "", "clip_type": "wan", "width": 1280, "height": 704, "length": 121, "steps": 3, "sampler": "lcm", "scheduler": "simple", "cfg": 1.0, "shift": 8.0,
        "lora": {"file": WAN_LORA, "strength_model": 1.0},
        "tile": {"tile_size": 512, "overlap": 64, "temporal_size": 32, "temporal_overlap": 8},  # the NAMED fields of VAEDecodeTiled
        "fps": 24,
    },
}


class RunError(Exception):
    """A failed run or check: its text is the last line the program prints (exit 1)."""


class UsageError(Exception):
    """A bad argument: one line on stderr, exit 2."""


def spec_of(workflow):
    if workflow not in WORKFLOWS:
        raise UsageError(f'bench.py: "{workflow}" is not a workflow; legal: {" ".join(sorted(WORKFLOWS))}')
    return WORKFLOWS[workflow]


def constants_of(workflow):
    spec = spec_of(workflow)
    inputs = {key: value for key, value in spec.items() if key != "ceilings"}
    return {"workflow": workflow, "inputs": inputs, "seeds": {"cold": SEEDS["cold"], "measured": list(SEEDS["measured"])},
            "ceilings": dict(spec["ceilings"]), "metrics": list(METRICS), "nodes": dict(NODES)}


def arm_words(environ):
    """(weight dtype, compile) from the environment; a COMFY_BENCH_* name that is neither a word nor a knob is refused naming the legal words."""
    for name in sorted(environ):
        if name.startswith("COMFY_BENCH_") and name not in LEGAL_WORDS and name not in KNOBS:
            raise UsageError(f"{name} is not a bench word; legal: {', '.join(LEGAL_WORDS)}")
    dtype = environ.get("COMFY_BENCH_WEIGHT_DTYPE") or "default"
    if dtype not in WEIGHT_DTYPES:
        raise UsageError(f'COMFY_BENCH_WEIGHT_DTYPE "{dtype}" is not one of {" ".join(WEIGHT_DTYPES)}')
    compile_word = environ.get("COMFY_BENCH_COMPILE", "")
    if compile_word not in ("", "0", "1"):
        raise UsageError(f'COMFY_BENCH_COMPILE "{compile_word}" is not 1 (a compile node) or empty')
    return dtype, compile_word == "1"


def _loader_nodes(g, workflow, spec, dtype):
    """The loaders: g gets the model, the text encoder and the VAE loaders; returns (the model node, the clip source, the vae source)."""
    m = spec["models"]
    if workflow == "sd15":
        if dtype != "default":
            raise UsageError("COMFY_BENCH_WEIGHT_DTYPE does not apply to sd15 (its checkpoint loader has no weight_dtype)")
        g["unet"] = {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": m["checkpoints"]}}
        return "unet", ["unet", 1], ["unet", 2]
    g["unet"] = {"class_type": "UNETLoader", "inputs": {"unet_name": m["diffusion_models"], "weight_dtype": dtype}}
    g["clip"] = {"class_type": "CLIPLoader", "inputs": {"clip_name": m["text_encoders"], "type": spec["clip_type"], "device": "default"}}
    g["vaeload"] = {"class_type": "VAELoader", "inputs": {"vae_name": m["vae"]}}
    return "unet", ["clip", 0], ["vaeload", 0]


def _model_chain(g, workflow, spec, model, compiled):
    """The nodes between the loader and the sampler (the LoRA, the compile node, the shift node); returns the node the sampler takes its model from."""
    if workflow == "wan5b":
        g["lora"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["unet", 0], "lora_name": spec["lora"]["file"], "strength_model": spec["lora"]["strength_model"]}}
        model = "lora"
    if compiled:
        g["compile"] = {"class_type": "TorchCompileModel", "inputs": {"model": [model, 0], "backend": "inductor"}}
        model = "compile"
    if workflow in ("zimage", "wan5b"):
        shift_class = "ModelSamplingAuraFlow" if workflow == "zimage" else "ModelSamplingSD3"
        g["shift"] = {"class_type": shift_class, "inputs": {"model": [model, 0], "shift": spec["shift"]}}
        model = "shift"
    return model


def _conditioning_nodes(g, workflow, spec, clip):
    g["pos"] = {"class_type": "CLIPTextEncode", "inputs": {"text": spec["prompt"], "clip": clip}}
    if workflow == "zimage":
        g["neg"] = {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["pos", 0]}}
    else:
        g["neg"] = {"class_type": "CLIPTextEncode", "inputs": {"text": spec["negative"], "clip": clip}}


def _latent_node(g, workflow, spec, vae_source):
    size = {"width": spec["width"], "height": spec["height"], "batch_size": 1}
    if workflow == "wan5b":
        g["latent"] = {"class_type": "Wan22ImageToVideoLatent", "inputs": {"vae": vae_source, "width": spec["width"], "height": spec["height"], "length": spec["length"], "batch_size": 1}}
    else:
        g["latent"] = {"class_type": "EmptySD3LatentImage" if workflow == "zimage" else "EmptyLatentImage", "inputs": size}


def _decode_and_save(g, workflow, spec, vae_source, prefix):
    if workflow == "wan5b":
        g["vae"] = {"class_type": "VAEDecodeTiled", "inputs": {"samples": ["sampler", 0], "vae": vae_source, **spec["tile"]}}
        g["video"] = {"class_type": "CreateVideo", "inputs": {"images": ["vae", 0], "fps": spec["fps"]}}
        g["save"] = {"class_type": "SaveVideo", "inputs": {"video": ["video", 0], "filename_prefix": prefix, "format": "auto", "codec": "auto"}}
    else:
        g["vae"] = {"class_type": "VAEDecode", "inputs": {"samples": ["sampler", 0], "vae": vae_source}}
        g["save"] = {"class_type": "SaveImage", "inputs": {"images": ["vae", 0], "filename_prefix": prefix}}


def build_graph(workflow, seed, label="x", environ=None):
    """The ComfyUI prompt of a workflow: every input from the table, the arm's two words applied, nothing else free."""
    spec = spec_of(workflow)
    dtype, compiled = arm_words(os.environ if environ is None else environ)
    g = {}
    model, clip, vae_source = _loader_nodes(g, workflow, spec, dtype)
    model = _model_chain(g, workflow, spec, model, compiled)
    _conditioning_nodes(g, workflow, spec, clip)
    _latent_node(g, workflow, spec, vae_source)
    g["sampler"] = {"class_type": "KSampler", "inputs": {
        "model": [model, 0], "positive": ["pos", 0], "negative": ["neg", 0], "latent_image": ["latent", 0], "seed": seed, "steps": spec["steps"], "cfg": spec["cfg"],
        "sampler_name": spec["sampler"], "scheduler": spec["scheduler"], "denoise": 1.0}}
    _decode_and_save(g, workflow, spec, vae_source, f"{workflow}_r{label}")
    return g


# ---------- the output check (Pillow, numpy, ffprobe) ----------
IMAGE_EXTENSIONS = (".png", ".jpg", ".jpeg", ".webp")


def _constant_text(pixels):
    values = {int(v) for v in pixels}
    return str(values.pop()) if len(values) == 1 else ",".join(str(int(v)) for v in pixels)


def _video_info(path):
    """(width, height, frames) by `ffprobe -count_frames`; the program is the image's own (the Containerfile installs ffmpeg)."""
    command = ["ffprobe", "-v", "error", "-count_frames", "-select_streams", "v:0", "-show_entries", "stream=width,height,nb_read_frames", "-of", "csv=p=0", str(path)]
    try:
        answer = subprocess.run(command, capture_output=True, text=True, timeout=FFPROBE_TIMEOUT_S)
    except FileNotFoundError:
        raise RunError("OUTPUT: ffprobe is not installed (the check of a video needs it)")
    fields = answer.stdout.strip().split(",")
    if answer.returncode != 0 or len(fields) != 3 or not all(f.isdigit() for f in fields):
        raise RunError(f"OUTPUT: ffprobe could not read {os.path.basename(str(path))} (code {answer.returncode}): {(answer.stderr or answer.stdout).strip()[:200]}")
    return int(fields[0]), int(fields[1]), int(fields[2])


def _video_frame(path, index, width, height):
    """The raw rgb24 bytes of frame <index> (None when it cannot be decoded)."""
    command = ["ffmpeg", "-v", "error", "-i", str(path), "-vf", f"select=eq(n\\,{index})", "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    try:
        answer = subprocess.run(command, capture_output=True, timeout=FFMPEG_TIMEOUT_S)
    except FileNotFoundError:
        raise RunError("OUTPUT: ffmpeg is not installed (the check of a video needs it)")
    return answer.stdout if answer.returncode == 0 and len(answer.stdout) == width * height * 3 else None


def check_output(path, workflow):
    """The output of a run is the workflow's, or RunError('OUTPUT: <why>'). Returns {file, width, height, frames, constant} (constant is always false here)."""
    spec = spec_of(workflow)
    name = os.path.basename(str(path))
    if not os.path.isfile(path):
        raise RunError(f"OUTPUT: {name} does not exist")
    want = f"{spec['width']}x{spec['height']}"
    if str(path).lower().endswith(IMAGE_EXTENSIONS):
        import numpy
        from PIL import Image
        try:
            with Image.open(path) as image:
                size, array = image.size, numpy.asarray(image.convert("RGB"))
        except Exception as error:
            raise RunError(f"OUTPUT: {name} is not an image Pillow opens ({type(error).__name__})")
        if f"{size[0]}x{size[1]}" != want:
            raise RunError(f"OUTPUT: size {size[0]}x{size[1]}, expected {want}")
        pixels = array.reshape(-1, 3)
        if bool((pixels == pixels[0]).all()):
            raise RunError(f"OUTPUT: the image is constant (every pixel {_constant_text(pixels[0])})")
        return {"file": name, "width": size[0], "height": size[1], "frames": 1, "constant": False}
    width, height, frames = _video_info(path)
    if f"{width}x{height}" != want:
        raise RunError(f"OUTPUT: size {width}x{height}, expected {want}")
    if spec["length"] is not None and frames != spec["length"]:
        raise RunError(f"OUTPUT: {frames} frames, expected {spec['length']} (ffprobe -count_frames)")
    for index in (0, frames // 2, frames - 1):
        raw = _video_frame(path, index, width, height)
        if raw is None:
            raise RunError(f"OUTPUT: frame {index} of {name} cannot be decoded")
        if raw.count(raw[:3]) * 3 == len(raw) and all(raw[i:i + 3] == raw[:3] for i in range(0, len(raw), 3)):
            raise RunError("OUTPUT: the frames are constant")
    return {"file": name, "width": width, "height": height, "frames": frames, "constant": False}


# ---------- the drift (numpy, Pillow) ----------
def _find_output(folder, workflow, run):
    prefix = f"{workflow}_r{run}_"
    names = sorted(n for n in os.listdir(folder) if n.startswith(prefix)) if os.path.isdir(folder) else []
    return os.path.join(folder, names[0]) if names else None


def _pair_stats(a, b):
    """(sum of absolute differences, sum of squared differences, count) of two uint8 arrays."""
    import numpy
    d = a.astype(numpy.int16) - b.astype(numpy.int16)
    return float(numpy.abs(d).sum()), float((d.astype(numpy.float64) ** 2).sum()), d.size


def _frames(path):
    """One ffmpeg decoder of a clip: raw rgb24 frames on its stdout; it reads nothing and says nothing (no stdin to inherit, no stderr pipe to fill and block on)."""
    command = ["ffmpeg", "-v", "error", "-i", str(path), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    return subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)


def _next_pair_stats(left, right, size):
    """(sum of absolute differences, sum of squared differences, count) of the next frame of two decoders; None at the end. No frame outlives the call."""
    import numpy
    x, y = left.stdout.read(size), right.stdout.read(size)
    if len(x) != size or len(y) != size:
        if len(x) != len(y):
            raise RunError("the frame counts differ")
        return None
    return _pair_stats(numpy.frombuffer(x, numpy.uint8), numpy.frombuffer(y, numpy.uint8))


def _image_drift(path, ref):
    import numpy
    from PIL import Image
    with Image.open(path) as one, Image.open(ref) as two:
        a, b = numpy.asarray(one.convert("RGB")), numpy.asarray(two.convert("RGB"))
    if a.shape != b.shape:
        raise RunError(f"the size differs ({a.shape[1]}x{a.shape[0]} against {b.shape[1]}x{b.shape[0]})")
    total, squares, count = _pair_stats(a, b)
    return total / count, squares / count


def _drift_numbers(path, ref, workflow):
    """(mad, mse) of an output against its reference: an image directly, a video frame by frame (the mean over the frames of each frame's mad and mse)."""
    if str(path).lower().endswith(IMAGE_EXTENSIONS):
        return _image_drift(path, ref)
    width, height, _ = _video_info(path)
    mads, mses = [], []
    left, right = _frames(path), _frames(ref)
    try:
        while (stats := _next_pair_stats(left, right, width * height * 3)) is not None:
            mads.append(stats[0] / stats[2])
            mses.append(stats[1] / stats[2])
    finally:
        for proc in (left, right):
            proc.kill()
            proc.wait()
    if not mads:
        raise RunError("no frame could be decoded")
    return sum(mads) / len(mads), sum(mses) / len(mses)


def drift_lines(workflow, out, ref):
    """One line per measured seed: `drift r=<n>: mad <v> psnr <v|identical>` or `drift r=<n>: unavailable (<why>)`; a number is never made for an absent pair."""
    lines = []
    for run, seed in enumerate(SEEDS["measured"], 1):
        mine, theirs = _find_output(out, workflow, run), _find_output(ref, workflow, run)
        if mine is None:
            lines.append(f"drift r={run}: unavailable (the output of seed {seed} is missing)")
        elif theirs is None:
            lines.append(f"drift r={run}: unavailable (the reference of seed {seed} is missing)")
        else:
            try:
                mad, mse = _drift_numbers(mine, theirs, workflow)
            except RunError as error:
                lines.append(f"drift r={run}: unavailable ({error})")
                continue
            psnr = "identical" if mse == 0 else f"{10 * math.log10(255 ** 2 / mse):.3f}"
            lines.append(f"drift r={run}: mad {mad:.3f} psnr {psnr}")
    return lines


# ---------- one run against the server ----------
def _int_or_none(value):
    return value if isinstance(value, int) and not isinstance(value, bool) else None


async def _stats(session):
    async with session.get(f"{api()}/system_stats") as response:
        body = await response.json()
    card = (body.get("devices") or [{}])[0]
    return {"argv": (body.get("system") or {}).get("argv"), "vram_free": _int_or_none(card.get("vram_free")), "vram_total": _int_or_none(card.get("vram_total"))}


def api():
    return os.environ.get("COMFY_BENCH_API", "http://127.0.0.1:8188").rstrip("/")


def _error_text(data):
    return f"EXECUTION_ERROR: node {data.get('node_id')} ({data.get('node_type')}): {data.get('exception_message')}"


def _history_failure(entry):
    status = entry.get("status") or {}
    for name, data in status.get("messages") or []:
        if name == "execution_error":
            return _error_text(data)
    if status.get("status_str") not in (None, "success"):
        return f"EXECUTION_ERROR: the history says {status.get('status_str')}"
    return None


def _output_file(entry, out):
    for files in (entry.get("outputs") or {}).get(NODES["save"], {}).values():
        if isinstance(files, list) and files and isinstance(files[0], dict) and "filename" in files[0]:
            return os.path.join(out, files[0].get("subfolder") or "", files[0]["filename"])
    raise RunError("OUTPUT: the history names no output file of the save node")


def _cache_after():
    found = {}
    if os.path.isdir(CACHE_ROOT):
        for folder in sorted(os.listdir(CACHE_ROOT)):
            files = size = 0
            for root, _, names in os.walk(os.path.join(CACHE_ROOT, folder)):
                for name in names:
                    files += 1
                    try:
                        size += os.path.getsize(os.path.join(root, name))
                    except OSError:
                        pass
            found[folder] = {"files": files, "bytes": size}
    return found


async def _post_prompt(session, graph, client):
    """POST /prompt: the prompt id; a prompt the server refuses is RunError('PROMPT: refused: <error>') before any timing."""
    async with session.post(f"{api()}/prompt", json={"prompt": graph, "client_id": client}) as response:
        try:
            body = await response.json()
        except Exception:
            body = {}
    if not isinstance(body, dict) or "prompt_id" not in body:
        error = body.get("error") if isinstance(body, dict) else None
        raise RunError(f"PROMPT: refused: {error.get('message') if isinstance(error, dict) else error or f'HTTP {response.status}'}")
    return body["prompt_id"]


class Events:
    """What the websocket said about one prompt: the time of every executed node, their order and the nodes the cache reused."""

    def __init__(self, started):
        self.times, self.order, self.cached, self.current, self.since = {}, [], [], None, started

    def take(self, packet, prompt_id):
        """One message. True when the run is over (`executing` with node null); an execution_error raises."""
        data = packet.get("data") or {}
        if data.get("prompt_id") not in (None, prompt_id):
            return False
        if packet.get("type") == "execution_error":
            raise RunError(_error_text(data))
        if packet.get("type") == "execution_cached":
            self.cached.extend(data.get("nodes") or [])
        elif packet.get("type") == "executing":
            now = time.monotonic()
            if self.current is not None:
                self.times[self.current] = self.times.get(self.current, 0.0) + now - self.since
            if data.get("node") is None:
                return True
            self.current, self.since = data["node"], now
            self.order.append(self.current)
        return False


async def _watch(socket, prompt_id, started, silence, kind):
    """The messages of the run until it ends; a socket that goes quiet for `silence` seconds is a server that is not working on the run (HANG)."""
    import aiohttp
    events = Events(started)
    while True:
        try:
            message = await socket.receive(timeout=silence)
        except asyncio.TimeoutError:
            raise RunError(f"HANG: no websocket message for {silence:.0f} s (half of the {kind} ceiling): the server holds the run and sends nothing")
        if message.type in (aiohttp.WSMsgType.CLOSED, aiohttp.WSMsgType.CLOSING, aiohttp.WSMsgType.ERROR):
            return events
        if message.type == aiohttp.WSMsgType.TEXT and events.take(json.loads(message.data), prompt_id):
            return events


async def _history_entry(session, prompt_id):
    while True:
        async with session.get(f"{api()}/history/{prompt_id}") as response:
            history = await response.json()
        if isinstance(history, dict) and prompt_id in history:
            return history[prompt_id]
        await asyncio.sleep(POLL_S)


def _assemble(graph, events, before, after, entry, output, info):
    """The JSON of a run: the timings, the nodes (executed, and the class types of the cached ones), the argv and the card as the server reported them, the output and the cache."""
    return {"tag": info["tag"], "workflow": info["workflow"], "run": info["run"], "seed": info["seed"], "started_at": info["started"], "total_s": round(info["total"], 3),
            "nodes_s": {k: round(v, 3) for k, v in events.times.items()}, "node_order": events.order, "nodes": [graph[n]["class_type"] for n in events.order if n in graph],
            "cached_types": [graph[n]["class_type"] for n in events.cached if n in graph], "cached_nodes": events.cached, "server_argv": before["argv"],
            "env": {k: v for k, v in sorted(os.environ.items()) if k in LEGAL_WORDS}, "vram_free_before": before["vram_free"], "vram_total_before": before["vram_total"],
            "vram_free_after": after["vram_free"], "output": output, "cache_after": _cache_after(), "cold": info["run"] == "cold"}


def _require_executed(events):
    """A time that measured nothing is never printed; an absent time is not zero."""
    for what, node in (("sampler", NODES["sampler"]), ("decode node", NODES["vae"])):
        if node in events.cached or node not in events.times:
            raise RunError(f"CACHED: the {what} did not execute (cached: {','.join(map(str, events.cached)) or 'none'})")


async def _drive(workflow, tag, run, out, clock, ceiling):
    import aiohttp
    seed = SEEDS["cold"] if run == "cold" else SEEDS["measured"][int(run) - 1]
    graph = build_graph(workflow, seed, run)
    client = str(uuid.uuid4())
    started = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    print(f"run {run} started", file=sys.stderr, flush=True)
    async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=REQUEST_TIMEOUT_S)) as session:
        before = await _stats(session)
        async with session.ws_connect(f"{api()}/ws?clientId={client}", max_msg_size=0, timeout=aiohttp.ClientWSTimeout(ws_close=WS_CLOSE_TIMEOUT_S)) as socket:
            clock["t0"] = time.monotonic()
            prompt_id = await _post_prompt(session, graph, client)
            events = await _watch(socket, prompt_id, clock["t0"], ceiling * SILENCE_OF_CEILING, "cold" if run == "cold" else "run")
        entry = await _history_entry(session, prompt_id)
        total = time.monotonic() - clock["t0"]
        failure = _history_failure(entry)
        if failure:
            raise RunError(failure)
        after = await _stats(session)
    if run != "cold":
        _require_executed(events)
    output = await asyncio.to_thread(lambda: check_output(_output_file(entry, out), workflow))
    return _assemble(graph, events, before, after, entry, output, {"tag": tag, "workflow": workflow, "run": run, "seed": seed, "started": started, "total": total})


def _write_json(path, payload):
    part = f"{path}.part"
    with open(part, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=1, sort_keys=True)
        handle.write("\n")
    os.replace(part, path)


def run_once(workflow, tag, run, out):
    """0 and the lines of the run; 1 a failed run (its last line); 3 a ceiling."""
    spec = spec_of(workflow)
    cold = run == "cold"
    knob = os.environ.get("COMFY_BENCH_TEST_COLD_MAX_S" if cold else "COMFY_BENCH_TEST_RUN_MAX_S")
    ceiling = float(knob) if knob else float(spec["ceilings"]["cold_max_s" if cold else "run_max_s"])
    clock = {"t0": None}
    began = time.monotonic()
    try:
        result = asyncio.run(asyncio.wait_for(_drive(workflow, tag, run, out, clock, ceiling), ceiling))
    except asyncio.TimeoutError:
        print(f"{'COLD' if cold else 'RUN'}_TIMEOUT {time.monotonic() - began:.1f}")
        return 3
    except RunError as error:
        print(error)
        return 1
    except OSError as error:
        print(f"PROMPT: the server cannot be reached ({type(error).__name__}: {error})")
        return 1
    _write_json(os.path.join(out, f"run-{run}.json"), result)
    if cold:
        print(f"cold: total {result['total_s']:.3f} s")
    else:
        values = {"total_s": result["total_s"], "sampler_s": result["nodes_s"][NODES["sampler"]], "vae_s": result["nodes_s"][NODES["vae"]]}
        for metric in METRICS:
            print(f"{tag} {workflow} r={run} {metric}: {values[metric]:.3f}")
    return 0


# ---------- the command line ----------
def build_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("workflows")
    sub.add_parser("metrics")
    sub.add_parser("words")
    for name in ("constants", "models"):
        sub.add_parser(name).add_argument("workflow")
    graph = sub.add_parser("graph")
    graph.add_argument("workflow")
    graph.add_argument("--seed", type=int, required=True)
    graph.add_argument("--run", default="x")
    run = sub.add_parser("run")
    run.add_argument("workflow")
    run.add_argument("--tag", required=True)
    run.add_argument("--run", required=True, choices=["cold", "1", "2", "3"])
    run.add_argument("--out", required=True)
    check = sub.add_parser("check")
    check.add_argument("file")
    check.add_argument("--workflow", required=True)
    drift = sub.add_parser("drift")
    drift.add_argument("workflow")
    drift.add_argument("--out", required=True)
    drift.add_argument("--ref", required=True)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        if args.cmd == "workflows":
            print("\n".join(sorted(WORKFLOWS)))
        elif args.cmd == "metrics":
            print(" ".join(METRICS))
        elif args.cmd == "words":
            print("\n".join(LEGAL_WORDS))
        elif args.cmd == "models":
            print("\n".join(sorted(f"{folder}/{name}" for folder, name in spec_of(args.workflow)["models"].items())))
        elif args.cmd == "constants":
            print(json.dumps(constants_of(args.workflow), indent=1, sort_keys=True))
        elif args.cmd == "graph":
            print(json.dumps(build_graph(args.workflow, args.seed, args.run), indent=1, sort_keys=True))
        elif args.cmd == "run":
            spec_of(args.workflow)
            arm_words(os.environ)
            build_graph(args.workflow, 0, args.run)  # refuses a word that does not apply to the workflow before any request
            return run_once(args.workflow, args.tag, args.run, args.out)
        elif args.cmd == "check":
            info = check_output(args.file, args.workflow)
            print(f"OUTPUT ok: {info['width']}x{info['height']}, {info['frames']} frame(s)")
        else:
            spec_of(args.workflow)
            print("\n".join(drift_lines(args.workflow, args.out, args.ref)))
    except UsageError as error:
        print(error, file=sys.stderr)
        return 2
    except RunError as error:
        print(error)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
