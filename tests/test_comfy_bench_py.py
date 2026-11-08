"""comfyui/bench.py against the scripted ComfyUI stand-in (E2.S2): scenarios BP1-BP13 and BP12v (BP14 is folded into BP5).

Every test runs bench.py as a subprocess (`python -I`), the server of tests/fixtures/comfy/comfy_server.py as another one on a free port, and writes only below pytest's
`tmp_path`. The server's pid is recorded in a `containers/` folder below it, where tests/run.mjs finds and kills what a test left. ffmpeg and ffprobe are prerequisites of
the suite (research/module_tests.md, How it is run): a machine without them fails BP11 and BP12v with their names."""
import json
import math
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.request

import pytest

from conftest import FIXTURES, ROOT

BENCH = ROOT / "comfyui" / "bench.py"
SERVER = FIXTURES / "comfy" / "comfy_server.py"
VERDICT = ROOT / "lib" / "verdict.py"
METRICS = "total_s sampler_s vae_s"


def need(program):
    """ffmpeg and ffprobe are not skipped: a machine without them fails the test with one line naming the program."""
    if shutil.which(program) is None:
        pytest.fail(f"{program} is not installed: the suite needs ffmpeg and ffprobe (research/module_tests.md, How it is run)")


def clean_env(**extra):
    env = {k: v for k, v in os.environ.items() if not k.startswith("COMFY_BENCH_")}
    env.update(extra)
    return env


def bench(*args, port=None, timeout=60, isolated=True, **env):
    """(returncode, stdout, stderr, seconds) of one bench.py call."""
    if port is not None:
        env["COMFY_BENCH_API"] = f"http://127.0.0.1:{port}"
    command = [sys.executable, "-I", *(["-S"] if not isolated else []), str(BENCH), *map(str, args)]
    started = time.monotonic()
    done = subprocess.run(command, capture_output=True, text=True, timeout=timeout, env=clean_env(**env))
    return done.returncode, done.stdout, done.stderr, time.monotonic() - started


def own_ticks(pid):
    return open(f"/proc/{pid}/stat").read().rsplit(") ", 1)[1].split()[19]


@pytest.fixture
def server(tmp_path):
    """start(script) -> (port, folder the server writes into); every server is killed at the end of the test."""
    started = []

    def start(script):
        n = len(started) + 1
        script_file, port_file, out = tmp_path / f"script{n}.json", tmp_path / f"port{n}", tmp_path / f"out{n}"
        script_file.write_text(json.dumps(script))
        proc = subprocess.Popen([sys.executable, "-I", str(SERVER), "--script", str(script_file), "--out", str(out), "--port-file", str(port_file)],
                                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        started.append(proc)
        (tmp_path / "containers").mkdir(exist_ok=True)
        (tmp_path / "containers" / f"fixture-{n}.pid").write_text(f"{proc.pid} {own_ticks(proc.pid)}\n")
        for _ in range(100):
            if port_file.exists():
                return int(port_file.read_text()), out
            if proc.poll() is not None:
                pytest.fail(f"the fixture server ended: {proc.stderr.read()}")
            time.sleep(0.1)
        pytest.fail("the fixture server never wrote its port")

    yield start
    for proc in started:
        proc.kill()
        proc.wait()
        proc.stderr.close()


def prompt_script(gaps=(0, 0, 0, 0), history_delay=0.0, output=None, cached=None, before=(), **more):
    """One prompt: execution_start, [execution_cached], executing pos, sampler, vae, save with the gaps AFTER each, then executing null."""
    messages = [{"type": "execution_start", "data": {}}]
    if cached is not None:
        messages.append({"type": "execution_cached", "data": {"nodes": cached}})
    messages += list(before)
    for node, gap in zip(("pos", "sampler", "vae", "save"), gaps):
        if cached is not None and node in cached:
            continue
        messages.append({"type": "executing", "data": {"node": node}, "after": gap})
    messages.append({"type": "executing", "data": {"node": None}})
    script = {"messages": messages, "history_delay": history_delay,
              "output": output if output is not None else {"kind": "image", "width": 1024, "height": 1024, "fill": "noise"}}
    script.update(more)
    return script


def graph_of(workflow, seed=1, **env):
    rc, out, err, _ = bench("graph", workflow, "--seed", seed, **env)
    assert rc == 0, err
    return json.loads(out)


def nodes_of(graph, class_type):
    return [node for node in graph.values() if node["class_type"] == class_type]


def recorded(port):
    with urllib.request.urlopen(f"http://127.0.0.1:{port}/_recorded", timeout=10) as reply:
        return json.load(reply)


# BP1
def test_the_pure_commands_run_on_the_host_with_the_standard_library_only():
    rc, out, err, _ = bench("workflows", isolated=False)
    assert (rc, out.split()) == (0, ["sd15", "wan5b", "zimage"]), err
    rc, out, err, _ = bench("metrics", isolated=False)
    assert (rc, out.strip()) == (0, METRICS), err
    rc, out, err, _ = bench("models", "wan5b", isolated=False)
    assert (rc, out.split()) == (0, ["diffusion_models/wan2.2_ti2v_5B_fp16.safetensors", "loras/Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors", "text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors", "vae/wan2.2_vae.safetensors"]), err
    for command in (["constants", "zimage"], ["graph", "zimage", "--seed", "1"]):
        rc, out, err, _ = bench(*command, isolated=False)
        assert rc == 0, f"{command} needs a package outside the standard library: {err}"
    companion = subprocess.run([sys.executable, "-I", "-S", "-c", "import aiohttp"], capture_output=True)
    assert companion.returncode != 0, "the scan is alive: -S really hides the packages, so a module-level import of aiohttp would fail the runs above"


# BP2
def test_one_table_feeds_the_graphs_and_the_constants():
    for workflow, ceilings in (("zimage", {"run_max_s": 300, "cold_max_s": 1800}), ("wan5b", {"run_max_s": 600, "cold_max_s": 2700}), ("sd15", {"run_max_s": 120, "cold_max_s": 600})):
        rc, out, err, _ = bench("constants", workflow)
        assert rc == 0, err
        constants = json.loads(out)
        assert set(constants) >= {"seeds", "ceilings", "inputs", "nodes", "metrics"}
        assert constants["ceilings"] == ceilings
    z = json.loads(bench("constants", "zimage")[1])
    graph = graph_of("zimage")
    unet, = nodes_of(graph, "UNETLoader")
    clip, = nodes_of(graph, "CLIPLoader")
    vae, = nodes_of(graph, "VAELoader")
    assert (unet["inputs"]["unet_name"], clip["inputs"]["clip_name"], vae["inputs"]["vae_name"]) == tuple(z["inputs"]["models"][k] for k in ("diffusion_models", "text_encoders", "vae"))
    latent, = nodes_of(graph, "EmptySD3LatentImage")
    sampler, = nodes_of(graph, "KSampler")
    shift, = nodes_of(graph, "ModelSamplingAuraFlow")
    assert (latent["inputs"]["width"], latent["inputs"]["height"]) == (z["inputs"]["width"], z["inputs"]["height"]) == (1024, 1024)
    assert (sampler["inputs"]["steps"], sampler["inputs"]["sampler_name"], sampler["inputs"]["scheduler"], sampler["inputs"]["cfg"]) == (z["inputs"]["steps"], z["inputs"]["sampler"], z["inputs"]["scheduler"], z["inputs"]["cfg"]) == (8, "res_multistep", "simple", 1.0)
    assert shift["inputs"]["shift"] == z["inputs"]["shift"] == 3.0
    assert nodes_of(graph, "ConditioningZeroOut"), "the empty negative prompt of zimage is a ConditioningZeroOut"
    w = json.loads(bench("constants", "wan5b")[1])
    graph = graph_of("wan5b")
    lora, = nodes_of(graph, "LoraLoaderModelOnly")
    assert lora["inputs"]["model"] == ["unet", 0] and graph["shift"]["inputs"]["model"] == ["lora", 0], "the LoRA sits between the loader and the shift node"
    assert (lora["inputs"]["lora_name"], lora["inputs"]["strength_model"]) == (w["inputs"]["lora"]["file"], w["inputs"]["lora"]["strength_model"]) == ("Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors", 1.0)
    assert graph["shift"]["class_type"] == "ModelSamplingSD3" and graph["shift"]["inputs"]["shift"] == 8.0
    latent, = nodes_of(graph, "Wan22ImageToVideoLatent")
    assert (latent["inputs"]["length"], latent["inputs"]["width"], latent["inputs"]["height"]) == (121, 1280, 704) and "start_image" not in latent["inputs"]
    sampler, = nodes_of(graph, "KSampler")
    assert (sampler["inputs"]["steps"], sampler["inputs"]["sampler_name"], sampler["inputs"]["cfg"]) == (3, "lcm", 1.0)
    assert graph["neg"]["class_type"] == "CLIPTextEncode" and graph["neg"]["inputs"]["text"] == "" and graph["pos"]["inputs"]["text"] != "", "the negative prompt is the empty string"
    tile, = nodes_of(graph, "VAEDecodeTiled")
    assert {k: tile["inputs"][k] for k in ("tile_size", "overlap", "temporal_size", "temporal_overlap")} == w["inputs"]["tile"] == {"tile_size": 512, "overlap": 64, "temporal_size": 32, "temporal_overlap": 8}
    assert not [n for n in graph.values() if n["class_type"].startswith("LoadImage")], "text-to-video: no node takes an image file"


# BP3
def test_the_measured_seeds_are_the_same_for_every_arm_and_differ_from_each_other_and_the_cold_one(tmp_path, server):
    for workflow in ("sd15", "wan5b", "zimage"):
        seeds = json.loads(bench("constants", workflow)[1])["seeds"]
        assert (seeds["cold"], seeds["measured"]) == (4242, [1, 2, 3])
    assert nodes_of(graph_of("zimage", seed=7), "KSampler")[0]["inputs"]["seed"] == 7
    port, out = server({"prompts": [prompt_script()]})
    for run in ("cold", "1", "2", "3"):
        rc, text, err, _ = bench("run", "zimage", "--tag", "base-1", "--run", run, "--out", out, port=port)
        assert rc == 0, text + err
    assert [nodes_of(g, "KSampler")[0]["inputs"]["seed"] for g in recorded(port)] == [4242, 1, 2, 3]


# BP4
def test_a_measured_run_prints_exactly_the_three_lines_and_the_cold_run_none(tmp_path, server):
    port, out = server({"prompts": [prompt_script()]})
    rc, text, err, _ = bench("run", "zimage", "--tag", "base-1", "--run", "cold", "--out", out, port=port)
    assert rc == 0 and text.strip().splitlines() and len(text.strip().splitlines()) == 1, text + err
    assert re.fullmatch(r"cold: total \d+\.\d{3} s", text.strip()), text
    assert " r=" not in text, "the cold run prints no line of the verdict grammar"
    lines = []
    for run in ("1", "2", "3"):
        rc, text, err, _ = bench("run", "zimage", "--tag", "base-1", "--run", run, "--out", out, port=port)
        assert rc == 0, text + err
        got = text.strip().splitlines()
        assert [re.fullmatch(rf"base-1 zimage r={run} {m}: \d+\.\d{{3}}", line) is not None for line, m in zip(got, METRICS.split())] == [True] * 3 and len(got) == 3, text
        lines += got
    block = tmp_path / "bench.txt"
    block.write_text("\n".join(lines) + "\n")
    done = subprocess.run([sys.executable, "-I", str(VERDICT), "comfy-check-block", "--tag", "base-1", "--workflow", "zimage", "--metrics", METRICS, str(block)], capture_output=True, text=True)
    assert (done.returncode, done.stdout.strip()) == (0, "base-1: complete, 9 lines"), done.stdout + done.stderr


# BP5 (BP14 is folded in: the card readings)
def test_the_total_runs_from_the_queue_to_the_history_and_the_node_times_come_from_the_websocket(tmp_path, server):
    stats = {"argv": ["main.py", "--fast", "fp16_accumulation"], "vram_free": 31000000000, "vram_total": 34000000000}
    port, out = server({"system_stats": stats, "prompts": [prompt_script(gaps=(0.2, 0.5, 0.3, 0.1), history_delay=0.2, cached=["pos2"])]})
    rc, text, err, _ = bench("run", "zimage", "--tag", "base-1", "--run", "cold", "--out", out, port=port)
    assert rc == 0, text + err
    cold = json.loads((out / "run-cold.json").read_text())
    rc, text, err, _ = bench("run", "zimage", "--tag", "base-1", "--run", "1", "--out", out, port=port)
    assert rc == 0, text + err
    one = json.loads((out / "run-1.json").read_text())
    assert (cold["cold"], one["cold"]) == (True, False)
    assert abs(one["nodes_s"]["sampler"] - 0.5) < 0.1 and abs(one["nodes_s"]["vae"] - 0.3) < 0.1, one["nodes_s"]
    printed = {line.split()[3].rstrip(":"): float(line.split()[4]) for line in text.strip().splitlines()}
    assert (printed["sampler_s"], printed["vae_s"]) == (round(one["nodes_s"]["sampler"], 3), round(one["nodes_s"]["vae"], 3))
    assert 1.1 + 0.2 <= one["total_s"] <= 1.1 + 0.2 + 1.0 and printed["total_s"] == one["total_s"], one["total_s"]
    assert one["cached_nodes"] == ["pos2"] and one["seed"] == 1 and cold["seed"] == 4242
    assert one["node_order"] == ["pos", "sampler", "vae", "save"]
    assert one["nodes"] == ["CLIPTextEncode", "KSampler", "VAEDecode", "SaveImage"], "the class types of the executed nodes, which the evidence of `compile` reads"
    for doc in (cold, one):
        assert doc["server_argv"] == stats["argv"], "the argv ComfyUI reports in /system_stats"
        assert (doc["vram_free_before"], doc["vram_total_before"]) == (31000000000, 34000000000), "BP14: the card readings before the run"
        assert doc["output"]["width"] == 1024 and doc["output"]["frames"] == 1 and doc["output"]["constant"] is False


# BP6
def test_a_measured_run_whose_sampler_came_from_the_cache_is_not_a_measurement(tmp_path, server):
    port, out = server({"prompts": [prompt_script(cached=["sampler"])]})
    rc, text, err, _ = bench("run", "zimage", "--tag", "base-1", "--run", "1", "--out", out, port=port)
    assert rc == 1, text + err
    assert text.strip().splitlines()[-1] == "CACHED: the sampler did not execute (cached: sampler)"
    assert " r=" not in text, "a time that measured nothing is never printed"
    assert not (out / "run-1.json").exists()

# BP6b: a node ComfyUI's execution cache reused is not executed, and is still in the run (the loaders and the compile node are cached in a real measured run)
def test_a_node_the_cache_reused_is_in_the_run_json_as_a_cached_class_type(tmp_path, server):
    port, out = server({"prompts": [prompt_script(cached=["unet", "clip"])]})
    rc, text, err, _ = bench("run", "zimage", "--tag", "base-1", "--run", "1", "--out", out, port=port)
    assert rc == 0, text + err
    one = json.loads((out / "run-1.json").read_text())
    assert one["cached_nodes"] == ["unet", "clip"] and one["cached_types"] == ["UNETLoader", "CLIPLoader"], "the class types of the cached nodes of the submitted graph"
    assert "UNETLoader" not in one["nodes"] and one["nodes"] == ["CLIPTextEncode", "KSampler", "VAEDecode", "SaveImage"], "`nodes` stays the executed ones"


# BP6c: a measured run whose decode did not execute has no vae_s: absent is not zero
def test_a_measured_run_whose_decode_did_not_execute_is_not_a_measurement(tmp_path, server):
    port, out = server({"prompts": [prompt_script(cached=["vae"])]})
    rc, text, err, _ = bench("run", "zimage", "--tag", "base-1", "--run", "1", "--out", out, port=port)
    assert rc == 1, text + err
    assert text.strip().splitlines()[-1] == "CACHED: the decode node did not execute (cached: vae)"
    assert " r=" not in text and not (out / "run-1.json").exists()


# BP7
def test_an_execution_error_fails_the_run_at_once_and_the_historys_error_too(tmp_path, server):
    error = {"type": "execution_error", "data": {"node_id": "sampler", "node_type": "KSampler", "exception_message": "boom"}, "after": 8}
    port, out = server({"prompts": [prompt_script(before=[{"type": "executing", "data": {"node": "pos"}}, error])]})
    rc, text, err, seconds = bench("run", "zimage", "--tag", "base-1", "--run", "1", "--out", out, port=port)
    assert rc == 1 and text.strip().splitlines()[-1] == "EXECUTION_ERROR: node sampler (KSampler): boom", text + err
    assert seconds < 5, f"the run waited {seconds:.1f} s: the error message did not end it (the server held the next message for 8 s)"
    status = {"status_str": "error", "completed": False, "messages": [["execution_error", {"node_id": "sampler", "node_type": "KSampler", "exception_message": "boom"}]]}
    port, out = server({"prompts": [prompt_script(history={"status": status})]})
    rc, text, err, _ = bench("run", "zimage", "--tag", "base-1", "--run", "1", "--out", out, port=port)
    assert rc == 1 and text.strip().splitlines()[-1] == "EXECUTION_ERROR: node sampler (KSampler): boom", text + err


# BP8
def test_a_refused_prompt_fails_before_any_timing_and_a_run_past_its_ceiling_fails_at_it(tmp_path, server):
    port, out = server({"prompts": [{"refuse": {"status": 400, "body": {"error": {"message": "x"}, "node_errors": {}}}}]})
    rc, text, err, seconds = bench("run", "zimage", "--tag", "base-1", "--run", "1", "--out", out, port=port)
    assert rc == 1 and text.strip() == "PROMPT: refused: x", text + err
    assert " r=" not in text and seconds < 5
    port, out = server({"prompts": [prompt_script(gaps=(0, 0, 0, 3))]})
    rc, text, err, seconds = bench("run", "zimage", "--tag", "base-1", "--run", "1", "--out", out, port=port, COMFY_BENCH_TEST_RUN_MAX_S="1")
    assert rc == 3 and re.fullmatch(r"RUN_TIMEOUT 1\.\d", text.strip()), text + err
    assert 1.0 <= float(text.split()[1]) < 2.0 and seconds < 5, f"the ceiling ended the run after {seconds:.1f} s"
    assert " r=" not in text


# BP9
def test_a_cold_run_past_its_ceiling_is_cold_timeout(tmp_path, server):
    port, out = server({"prompts": [prompt_script(gaps=(0, 0, 0, 3))]})
    rc, text, err, seconds = bench("run", "zimage", "--tag", "base-1", "--run", "cold", "--out", out, port=port, COMFY_BENCH_TEST_COLD_MAX_S="1")
    assert rc == 3 and re.fullmatch(r"COLD_TIMEOUT 1\.\d", text.strip()), text + err
    assert 1.0 <= float(text.split()[1]) < 2.0 and seconds < 5
    assert not (out / "run-cold.json").exists()


def png(path, size, fill):
    import numpy
    from PIL import Image
    array = numpy.random.default_rng(3).integers(0, 256, size=(size[1], size[0], 3), dtype=numpy.uint8) if fill == "noise" else numpy.full((size[1], size[0], 3), fill, dtype=numpy.uint8)
    Image.fromarray(array).save(path)
    return path


# BP10
def test_the_image_check_passes_the_workflows_size_and_fails_a_wrong_size_and_a_constant_image(tmp_path, server):
    good, small, grey = png(tmp_path / "good.png", (1024, 1024), "noise"), png(tmp_path / "small.png", (512, 512), "noise"), png(tmp_path / "grey.png", (1024, 1024), 128)
    assert bench("check", good, "--workflow", "zimage")[0] == 0
    rc, text, _, _ = bench("check", small, "--workflow", "zimage")
    assert (rc, text.strip()) == (1, "OUTPUT: size 512x512, expected 1024x1024")
    rc, text, _, _ = bench("check", grey, "--workflow", "zimage")
    assert (rc, text.strip()) == (1, "OUTPUT: the image is constant (every pixel 128)")
    for output, rc_want, line in (({"kind": "image", "width": 1024, "height": 1024, "fill": "noise"}, 0, None), ({"kind": "image", "width": 512, "height": 512, "fill": "noise"}, 1, "OUTPUT: size 512x512, expected 1024x1024"),
                                  ({"kind": "image", "width": 1024, "height": 1024, "fill": [128, 128, 128]}, 1, "OUTPUT: the image is constant (every pixel 128)")):
        port, out = server({"prompts": [prompt_script(output=output)]})
        rc, text, err, _ = bench("run", "zimage", "--tag", "base-1", "--run", "1", "--out", out, port=port)
        assert rc == rc_want, text + err
        if line:
            assert text.strip().splitlines()[-1] == line and " r=" not in text


def clip(path, frames, source="testsrc", size="1280x704"):
    lavfi = f"testsrc=size={size}:rate=24" if source == "testsrc" else f"color=c=gray:size={size}:rate=24"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", lavfi, "-frames:v", str(frames), "-pix_fmt", "yuv420p", str(path)], check=True, timeout=120)
    return path


# BP11
def test_the_video_check_passes_the_workflows_length_and_fails_a_truncated_and_a_constant_clip(tmp_path):
    need("ffmpeg")
    need("ffprobe")
    assert bench("check", clip(tmp_path / "ok.mp4", 121), "--workflow", "wan5b")[0] == 0
    rc, text, _, _ = bench("check", clip(tmp_path / "short.mp4", 97), "--workflow", "wan5b")
    assert (rc, text.strip()) == (1, "OUTPUT: 97 frames, expected 121 (ffprobe -count_frames)")
    rc, text, _, _ = bench("check", clip(tmp_path / "gray.mp4", 121, source="color"), "--workflow", "wan5b")
    assert (rc, text.strip()) == (1, "OUTPUT: the frames are constant")


def psnr_of(mse):
    return f"{10 * math.log10(255 ** 2 / mse):.3f}"


# BP12
def test_the_drift_of_images_is_zero_for_identical_outputs_and_unavailable_for_a_missing_reference(tmp_path):
    mine, ref = tmp_path / "mine", tmp_path / "ref"
    mine.mkdir()
    ref.mkdir()
    import numpy
    from PIL import Image
    base = numpy.random.default_rng(5).integers(0, 200, size=(64, 64, 3), dtype=numpy.uint8)
    Image.fromarray(base).save(ref / "zimage_r1_00001_.png")
    Image.fromarray(base).save(mine / "zimage_r1_00001_.png")
    Image.fromarray(base + 1).save(mine / "zimage_r2_00001_.png")  # every pixel raised by 1 (no clipping: the values stay below 201)
    Image.fromarray(base).save(ref / "zimage_r3_00001_.png")
    Image.fromarray(base + 1).save(mine / "zimage_r3_00001_.png")
    (ref / "zimage_r3_00001_.png").unlink()  # the reference of seed 3 is missing; seed 2's too (never made)
    rc, text, err, _ = bench("drift", "zimage", "--out", mine, "--ref", ref)
    lines = text.strip().splitlines()
    assert rc == 0 and len(lines) == 3, text + err
    assert lines[0] == "drift r=1: mad 0.000 psnr identical"
    assert lines[1] == "drift r=2: unavailable (the reference of seed 2 is missing)"
    assert "mad" not in lines[1] and "psnr" not in lines[1], "the numbers never appear for that seed"
    shifted = tmp_path / "shifted"
    shifted.mkdir()
    Image.fromarray(base + 1).save(shifted / "zimage_r1_00001_.png")
    rc, text, err, _ = bench("drift", "zimage", "--out", shifted, "--ref", ref)
    first = text.strip().splitlines()[0]
    assert first.startswith("drift r=1: mad 1.000 psnr "), first
    assert first.split()[-1] == psnr_of(1.0) == "48.131", "the formula 10 log10(255^2 / mse), three places"


# BP12v
def test_the_drift_of_videos_is_the_mean_over_the_frames(tmp_path):
    need("ffmpeg")
    need("ffprobe")
    import numpy
    mine, ref = tmp_path / "mine", tmp_path / "ref"
    mine.mkdir()
    ref.mkdir()
    clip(ref / "wan5b_r1_00001_.mp4", 24, size="128x96")
    shutil.copy(ref / "wan5b_r1_00001_.mp4", mine / "wan5b_r1_00001_.mp4")
    rc, text, err, _ = bench("drift", "wan5b", "--out", mine, "--ref", ref)
    assert rc == 0 and text.strip().splitlines()[0] == "drift r=1: mad 0.000 psnr identical", text + err

    def frames(path):
        raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
        return numpy.frombuffer(raw, numpy.uint8).reshape(-1, 96, 128, 3)

    bright = frames(ref / "wan5b_r1_00001_.mp4").copy()
    bright[12] = numpy.minimum(bright[12].astype(numpy.float64) * 1.1, 255).astype(numpy.uint8)  # a 10 % brighter middle frame
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "128x96", "-r", "24", "-i", "-", "-pix_fmt", "yuv420p", str(mine / "wan5b_r1_00001_.mp4")],
                   input=bright.tobytes(), check=True, timeout=120)
    rc, text, err, _ = bench("drift", "wan5b", "--out", mine, "--ref", ref)
    first = text.strip().splitlines()[0]
    assert rc == 0 and first.startswith("drift r=1: mad "), text + err
    a, b = frames(mine / "wan5b_r1_00001_.mp4").astype(numpy.int16), frames(ref / "wan5b_r1_00001_.mp4").astype(numpy.int16)
    mad = float(numpy.mean([numpy.abs(x - y).mean() for x, y in zip(a, b)]))
    assert mad > 0 and abs(float(first.split()[3]) - mad) < 0.001, (first, mad)
    assert first.split()[-1] != "identical" and math.isfinite(float(first.split()[-1]))


# BP13
def test_the_arm_words_reach_the_graph_and_without_them_the_graph_is_the_bases():
    assert nodes_of(graph_of("zimage", COMFY_BENCH_WEIGHT_DTYPE="fp8_e4m3fn"), "UNETLoader")[0]["inputs"]["weight_dtype"] == "fp8_e4m3fn"
    assert nodes_of(graph_of("zimage"), "UNETLoader")[0]["inputs"]["weight_dtype"] == "default"
    wan = graph_of("wan5b", COMFY_BENCH_COMPILE="1")
    compile_node, = nodes_of(wan, "TorchCompileModel")
    assert compile_node["inputs"] == {"model": ["lora", 0], "backend": "inductor"} and wan["shift"]["inputs"]["model"] == ["compile", 0]
    zi = graph_of("zimage", COMFY_BENCH_COMPILE="1")
    assert zi["compile"]["inputs"]["model"] == ["unet", 0] and zi["shift"]["inputs"]["model"] == ["compile", 0]
    rc, out, err, _ = bench("graph", "zimage", "--seed", 1, COMFY_BENCH_FROB="1")
    assert rc == 2 and out == "" and err.strip() == "COMFY_BENCH_FROB is not a bench word; legal: COMFY_BENCH_WEIGHT_DTYPE, COMFY_BENCH_COMPILE"
    plain = bench("graph", "wan5b", "--seed", 1)[1]
    assert plain == bench("graph", "wan5b", "--seed", 1, COMFY_BENCH_WEIGHT_DTYPE="default", COMFY_BENCH_COMPILE="0")[1], "without a word the graph is base's, byte for byte"
    assert "TorchCompileModel" not in plain
    assert graph_of("wan5b")["save"]["inputs"] == {"video": ["video", 0], "filename_prefix": "wan5b_rx", "format": "auto", "codec": "auto"}, "SaveVideo: format and codec, both auto (both ran on the card, 2026-11-08)"
    rc, out, err, _ = bench("graph", "sd15", "--seed", 1, COMFY_BENCH_WEIGHT_DTYPE="fp8_e4m3fn")
    assert rc == 2 and "sd15" in err, "a word that cannot act on a workflow is refused, never ignored"
