"""The ComfyUI tools of comfyui/tools/ (scenarios TL1-TL12): masked_repaint.py, film_interpolate.py, sheets.py, workflow_dump.py and their client comfy_client.py.

The tools that queue prompts run end to end against the scripted ComfyUI stand-in of tests/fixtures/comfy/comfy_server.py (the `server` fixture of conftest.py), which records
every graph it was sent. The graphs are asserted in their PARSED form: the executor of a graph is a GPU ComfyUI with the image-edit and FILM models, which CI does not have
(common/generated-code-tests.md: an artefact whose execution limits cannot be enforced here is asserted over its parsed form). What runs for real: the tools' own processes,
the mask and fill pictures they prepare, the sheets they draw, the client's refusal, error and ceiling paths. Every test writes only below pytest's `tmp_path`."""
import importlib.util
import json
import subprocess
import sys
import urllib.request

import pytest

from conftest import ROOT, catalogue_rows

TOOLS = ROOT / "comfyui" / "tools"


def load(name):
    """The tool module itself (its pure functions are called in-process; the commands run as subprocesses below)."""
    sys.path.insert(0, str(TOOLS))
    try:
        spec = importlib.util.spec_from_file_location(name, TOOLS / f"{name}.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    finally:
        sys.path.remove(str(TOOLS))


def tool(name, *args, port=None, timeout=60):
    """(returncode, stdout, stderr) of one tool call, as the operator runs it (python -I, a clean COMFY_TOOLS_API)."""
    env = {"PATH": "/usr/bin:/bin"}
    if port is not None:
        env["COMFY_TOOLS_API"] = f"http://127.0.0.1:{port}"
    done = subprocess.run([sys.executable, "-I", str(TOOLS / f"{name}.py"), *map(str, args)], capture_output=True, text=True, timeout=timeout, env=env)
    return done.returncode, done.stdout, done.stderr


def recorded(port):
    with urllib.request.urlopen(f"http://127.0.0.1:{port}/_recorded", timeout=10) as reply:
        return json.load(reply)


def picture(path, size=(200, 100), colour=(40, 90, 160)):
    from PIL import Image, ImageDraw
    image = Image.new("RGB", size, colour)
    ImageDraw.Draw(image).rectangle((size[0] // 2, 0, size[0], size[1]), fill=(200, 200, 40))  # two colours, so a blur changes the pixels near the edge
    image.save(path)
    return path


def spec_file(tmp_path, **override):
    spec = {"name": "pic1", "picture": str(picture(tmp_path / "pick.png")), "shapes": [{"ellipse": [0.4, 0.3, 0.6, 0.7]}],
            "prompt": "a plain grey stone wall in soft even light", "denoise": 0.85, "seeds": [11, 12], "output_prefix": "rp_pic1"}
    spec.update(override)
    path = tmp_path / f"spec{len(list(tmp_path.glob('spec*.json')))}.json"
    path.write_text(json.dumps(spec))
    return path


def edit_script(**more):
    return {"messages": [{"type": "executing", "data": {"node": None}}], "output": {"kind": "image", "width": 200, "height": 100, "fill": [9, 9, 9]}, **more}


# TL1
def test_every_command_of_every_tool_is_in_the_flow_catalogue():
    for name in ("masked_repaint", "film_interpolate", "sheets"):
        module = load(name)
        rows = catalogue_rows(f"comfyui/tools/{name}.py", module.build_parser())
        assert rows, f"the scan is alive: {name}.py has commands"
        assert all(rows.values()), f"{name}.py: a command without a row in research/module_tests.md: {[c for c, r in rows.items() if not r]}"
    doc = (ROOT / "research" / "module_tests.md").read_text().splitlines()
    assert [row for row in doc if row.startswith("| `comfyui/tools/workflow_dump.py")], "workflow_dump.py (no subcommands) has its row"


# TL2
def test_the_repaint_graph_samples_only_the_mask_and_pastes_onto_the_untouched_picture(tmp_path):
    rc, out, err = tool("masked_repaint", "graph", spec_file(tmp_path), "--seed-index", 1)
    assert rc == 0, err
    graph = json.loads(out)
    assert graph["latent"] == {"class_type": "SetLatentNoiseMask", "inputs": {"samples": ["enc", 0], "mask": ["mask", 0]}}
    assert graph["enc"]["inputs"]["pixels"] == ["ref1", 0] and graph["ref1"]["inputs"]["image"] == "repaint_pic1_fill.png", "the model sees the FILLED picture"
    assert graph["paste"]["class_type"] == "ImageCompositeMasked"
    assert (graph["paste"]["inputs"]["destination"], graph["paste"]["inputs"]["source"], graph["paste"]["inputs"]["mask"]) == (["orig", 0], ["decode", 0], ["mask", 0])
    assert graph["orig"]["inputs"]["image"] == "repaint_pic1_pick.png", "the paste goes onto the untouched picture"
    assert graph["save"]["inputs"] == {"images": ["paste", 0], "filename_prefix": "rp_pic1_2"}
    assert (graph["sampler"]["inputs"]["seed"], graph["sampler"]["inputs"]["denoise"], graph["sampler"]["inputs"]["latent_image"]) == (12, 0.85, ["latent", 0])
    assert graph["pos"]["inputs"]["prompt"].startswith("a plain grey stone wall") and graph["neg"]["inputs"]["prompt"] == ""
    assert "image2" not in graph["pos"]["inputs"], "no reference: one image"
    rc, out, err = tool("masked_repaint", "graph", spec_file(tmp_path, reference=str(picture(tmp_path / "ref.png"))))
    graph = json.loads(out)
    assert graph["pos"]["inputs"]["image2"] == ["scale2", 0] and graph["ref2"]["inputs"]["image"] == "repaint_pic1_reference.png", "a reference is image 2"
    assert (graph["sampler"]["inputs"]["steps"], graph["sampler"]["inputs"]["cfg"], graph["shift"]["inputs"]["shift"]) == (4, 1.0, 3.1), "the 4-step defaults"
    rc, out, err = tool("masked_repaint", "graph", spec_file(tmp_path, steps=20, cfg=4.0, shift=3.0))
    graph = json.loads(out)
    assert (graph["sampler"]["inputs"]["steps"], graph["sampler"]["inputs"]["cfg"], graph["shift"]["inputs"]["shift"]) == (20, 4.0, 3.0), \
        "a model that is not a 4-step one gets its own schedule from the spec"


# TL3
@pytest.mark.parametrize("override, says", [
    ({"color": 1}, "unknown key 'color'; legal: name, picture, shapes"),
    ({"shapes": [{"ellipse": [0.6, 0.3, 0.4, 0.7]}]}, "needs x0 < x1"),
    ({"shapes": [{"ellipse": [0.4, 0.3, 1.5, 0.7]}]}, "four fractions of the picture"),
    ({"shapes": [{"line": [0.1, 0.1, 0.9, 0.9]}]}, "needs a width in pixels"),
    ({"denoise": 0}, "denoise is a number in (0, 1]"),
    ({"seeds": []}, "seeds is a non-empty list"),
    ({"seeds": [True]}, "seeds is a non-empty list"),
    ({"prompt": " "}, "prompt is a non-empty text"),
    ({"name": "../x"}, "name is 1-64 letters"),
    ({"models": {"lora": "x"}}, "models is an object with any of unet, clip, vae"),
    ({"output_prefix": "../x"}, "output_prefix is folder/name words"),
    ({"output_prefix": "a//b"}, "output_prefix is folder/name words"),
    ({"steps": 0}, "steps is a whole number 1-200"),
    ({"cfg": -1}, "cfg is a number 0-30"),
])
def test_a_bad_spec_is_refused_with_one_line_naming_the_problem(tmp_path, override, says):
    rc, out, err = tool("masked_repaint", "graph", spec_file(tmp_path, **override))
    assert (rc, out) == (1, ""), err
    assert err.startswith("masked_repaint: SPEC: ") and err.count("\n") == 1 and says in err, err


# TL4
def test_the_mask_grows_an_ellipse_by_its_margin_and_puts_a_disc_at_a_lines_first_point(tmp_path):
    repaint = load("masked_repaint")
    spec = repaint.check_spec(json.loads(spec_file(tmp_path, feather=0).read_text()))
    mask = repaint.build_mask((200, 100), spec)
    assert mask.getpixel((100, 50)) == 255, "the box's centre"
    assert mask.getpixel((79, 50)) == 255, "inside the 25 % margin, outside the box (x 80-120)"
    assert mask.getpixel((5, 5)) == 0, "far outside"
    assert repaint.build_mask((200, 100), {**spec, "margin": 0}).getpixel((79, 50)) == 0, "the same point with no margin"
    line = repaint.check_spec(json.loads(spec_file(tmp_path, feather=0, shapes=[{"line": [0.1, 0.5, 0.9, 0.5], "width": 4}]).read_text()))
    mask = repaint.build_mask((200, 100), line)
    assert mask.getpixel((100, 50)) == 255 and mask.getpixel((100, 30)) == 0, "on the line, and off it"
    assert mask.getpixel((20, 46)) == 255, "the disc at the first point is wider than the stroke"


# TL5
def test_the_preview_draws_each_mask_in_red_over_a_crop(tmp_path):
    out = tmp_path / "preview.png"
    rc, stdout, err = tool("masked_repaint", "preview", spec_file(tmp_path), spec_file(tmp_path, name="pic2"), "--out", out)
    assert rc == 0, err
    from PIL import Image
    sheet = Image.open(out).convert("RGB")
    assert sheet.size == (800, 400), "one 400-pixel tile per spec"
    red, green, blue = sheet.getpixel((200, 200))
    assert red > 120 and green < red and blue < red, f"the mask's centre is red-tinted: {(red, green, blue)}"


# TL6
def test_run_prepares_the_pictures_and_queues_one_prompt_per_seed(server, tmp_path):
    port, _ = server({"prompts": [edit_script()]})
    inputs = tmp_path / "input"
    rc, out, err = tool("masked_repaint", "run", spec_file(tmp_path), "--input-dir", inputs, port=port)
    assert rc == 0, err
    assert sorted(p.name for p in inputs.iterdir()) == ["repaint_pic1_fill.png", "repaint_pic1_mask.png", "repaint_pic1_pick.png"]
    graphs = recorded(port)
    assert [g["sampler"]["inputs"]["seed"] for g in graphs] == [11, 12] and [g["save"]["inputs"]["filename_prefix"] for g in graphs] == ["rp_pic1_1", "rp_pic1_2"]
    assert out.count("masked_repaint: pic1 candidate ") == 2 and "rp_pic1_1_00001_.png" in out, out
    assert out.count("masked_repaint: queued prompt ") == 2, f"each prompt says it was queued, with its id, before the wait: {out}"
    from PIL import Image
    pick, fill = Image.open(inputs / "repaint_pic1_pick.png"), Image.open(inputs / "repaint_pic1_fill.png")
    assert pick.getpixel((100, 50)) != fill.getpixel((100, 50)), "inside the mask the fill is the blur: the colour edge at x 100 is smeared"
    assert pick.getpixel((5, 5)) == fill.getpixel((5, 5)), "outside the mask the fill is the picture"
    rc, _, err = tool("masked_repaint", "run", spec_file(tmp_path, blur_fill=False, name="keep"), "--input-dir", inputs, port=port)
    assert rc == 0, err
    assert Image.open(inputs / "repaint_keep_fill.png").tobytes() == Image.open(inputs / "repaint_keep_pick.png").tobytes(), "blur_fill false keeps the shape"


# TL7
def test_a_refused_prompt_an_execution_error_and_the_ceiling_each_end_with_one_line(server, tmp_path):
    port, _ = server({"prompts": [{"refuse": {"status": 400, "body": {"error": {"message": "the model file is missing"}}}}]})
    rc, out, err = tool("masked_repaint", "run", spec_file(tmp_path), "--input-dir", tmp_path / "in", port=port)
    assert (rc, err) == (1, "masked_repaint: PROMPT: refused: the model file is missing\n"), err
    port, _ = server({"prompts": [edit_script(history={"status": {"status_str": "error", "messages": [["execution_error", {"node_id": "sampler", "node_type": "KSampler",
                                                                                                                       "exception_message": "out of memory"}]]}})]})
    rc, out, err = tool("masked_repaint", "run", spec_file(tmp_path), "--input-dir", tmp_path / "in", port=port)
    assert (rc, err) == (1, "masked_repaint: EXECUTION_ERROR: node sampler (KSampler): out of memory\n"), err
    port, _ = server({"prompts": [edit_script(history_delay=30)]})
    rc, out, err = tool("masked_repaint", "run", spec_file(tmp_path), "--input-dir", tmp_path / "in", "--ceiling-s", 1, port=port)
    assert rc == 1 and err.startswith("masked_repaint: RUN_TIMEOUT: prompt ") and err.count("\n") == 1, err
    prompt_id = err.split()[3]
    assert f"not finished after 1 s; it may still run on the server: GET /history/{prompt_id} names its output" in err, "the line keeps the prompt id"
    assert len(recorded(port)) == 1, "the ceiling ends the wait: the first candidate's prompt is not queued twice"


# TL8
def test_a_picture_that_cannot_be_read_is_one_line(tmp_path):
    rc, out, err = tool("masked_repaint", "preview", spec_file(tmp_path, picture=str(tmp_path / "missing.png")), "--out", tmp_path / "p.png")
    assert rc == 1 and err.startswith("masked_repaint: FILE: ") and err.count("\n") == 1, err
    rc, out, err = tool("masked_repaint", "graph", spec_file(tmp_path), "--seed-index", 2)
    assert (rc, err) == (1, "masked_repaint: SPEC: --seed-index is 0-based: 0..1 for 2 seeds (candidate n is seed index n-1)\n"), err


# TL13
def test_a_server_that_cannot_be_reached_is_one_network_line_never_a_traceback(tmp_path):
    import socket
    with socket.socket() as probe:  # a port that was free a moment ago and is closed now: nothing listens there
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    rc, out, err = tool("masked_repaint", "run", spec_file(tmp_path), "--input-dir", tmp_path / "in", port=port)
    assert rc == 1 and err.startswith(f"masked_repaint: NETWORK: http://127.0.0.1:{port}/prompt: ") and err.count("\n") == 1, err
    assert "Traceback" not in err


# TL9
def test_film_doubles_the_frames_at_twice_the_fps_and_refuses_a_rate_that_changes_the_length(server, tmp_path):
    rc, out, err = tool("film_interpolate", "graph", "clip.mp4", "--prefix", "film/clip")
    assert rc == 0, err
    graph = json.loads(out)
    assert graph["interp"]["inputs"] == {"interp_model": ["model", 0], "images": ["parts", 0], "multiplier": 2}
    assert graph["video"]["inputs"]["fps"] == 32.0 and graph["model"]["inputs"]["model_name"] == "film_net_fp16.safetensors"
    rc, out, err = tool("film_interpolate", "graph", "clip.mp4", "--prefix", "film/clip", "--fps", 30)
    assert rc == 1 and "--fps 30 is not --input-fps 16 x --multiplier 2" in err, err
    rc, out, err = tool("film_interpolate", "graph", "clip.mp4", "--prefix", "p", "--input-fps", 24, "--multiplier", 3)
    assert rc == 0 and json.loads(out)["video"]["inputs"]["fps"] == 72.0, err
    port, _ = server({"prompts": [{"messages": [{"type": "executing", "data": {"node": None}}]}]})
    clip = tmp_path / "s01.mp4"
    clip.write_bytes(b"not decoded by the stand-in")
    rc, out, err = tool("film_interpolate", "run", clip, "--input-dir", tmp_path / "in", "--prefix", "film/s01", port=port)
    assert rc == 0, err
    assert (tmp_path / "in" / "film_s01.mp4").read_bytes() == clip.read_bytes(), "the clip is copied into the input folder"
    assert recorded(port)[0]["load"]["inputs"]["file"] == "film_s01.mp4", "and the graph loads that copy"


# TL10
def test_the_sheets_have_the_sizes_frames_and_grid_they_promise(tmp_path):
    from PIL import Image
    a, b = picture(tmp_path / "a.png", (400, 200)), picture(tmp_path / "b.png", (400, 200))
    rc, out, err = tool("sheets", "contact", tmp_path / "c.png", a, b, a, "--cols", 2, "--tile-width", 320)
    assert rc == 0 and Image.open(tmp_path / "c.png").size == (640, 360), err
    rc, out, err = tool("sheets", "crops", tmp_path / "r.png", f"{a}:0,0,0.5,0.5", f"{b}:0.5,0.5,1,1", "--tile-width", 100)
    assert rc == 0 and Image.open(tmp_path / "r.png").size == (200, 50), err
    rc, out, err = tool("sheets", "grid", tmp_path / "g.png", f"{a}:0,0,0.5,0.5", "--tile-width", 200)
    grid = Image.open(tmp_path / "g.png").convert("RGB")
    assert rc == 0 and grid.getpixel((80, 60)) == (0, 255, 0), f"the bright 0.20 lines of the whole picture cross at x = 0.20 x 400 = 80, y = 0.30 x 200 = 60: {err}"
    rc, out, err = tool("sheets", "mark", tmp_path / "m.png", f"{a}|a problem|0.25,0.25,0.75,0.75", f"{b}|fine|")
    marked = Image.open(tmp_path / "m.png").convert("RGB")
    assert rc == 0 and marked.size == (2560, 640), err
    assert marked.getpixel((320, 400)) == (255, 30, 30), "the frame's left edge at x = 0.25 x 1280"
    rc, out, err = tool("sheets", "crops", tmp_path / "x.png", f"{a}:0.5,0,0.4,1")
    assert (rc, err) == (1, f"sheets: a box is four fractions 0-1 with x0 < x1 and y0 < y1; got '0.5,0,0.4,1'\n")
    rc, out, err = tool("sheets", "contact", tmp_path / "big.png", *[tmp_path / f"p{i}.png" for i in range(201)])
    assert (rc, err) == (1, "sheets: at most 200 pictures per sheet (one canvas holds them all); got 201: split them\n"), \
        "refused before a picture is opened (none of the 201 exists)"


# TL11
def test_workflow_dump_prints_the_nodes_links_and_subgraphs_of_a_ui_workflow(tmp_path):
    workflow = {"nodes": [{"id": 3, "type": "KSampler", "widgets_values": [31, "fixed", 8]}], "links": [[1, 3, 0, 18, 0, "LATENT"]],
                "definitions": {"subgraphs": [{"name": "Audio", "nodes": [{"id": 7, "type": "CLIPTextEncode", "widgets_values": [""]}],
                                               "links": [{"origin_id": 26, "origin_slot": 0, "target_id": 7, "target_slot": 0, "type": "CLIP"}]}]}}
    path = tmp_path / "w.json"
    path.write_text(json.dumps(workflow))
    rc, out, err = tool("workflow_dump", path)
    assert rc == 0, err
    assert out.splitlines()[1:] == ['node 3 KSampler [31, "fixed", 8]', "link 3:0 -> 18:0 LATENT", "subgraph Audio", '  node 7 CLIPTextEncode [""]',
                                    "  link 26:0 -> 7:0 CLIP"]
    path.write_text("[1, 2]")
    rc, out, err = tool("workflow_dump", path)
    assert rc == 1 and "not a UI-format workflow" in err


# TL12
def test_the_tools_run_with_the_standard_library_and_pillow_only():
    for name in ("comfy_client", "masked_repaint", "film_interpolate", "sheets", "workflow_dump"):
        text = (TOOLS / f"{name}.py").read_text()
        imports = {line.split()[1].split(".")[0] for line in text.splitlines() if line.startswith(("import ", "from ")) and not line.startswith("from __future__")}
        assert imports, f"the scan is alive: {name}.py has imports"
        assert imports <= {"argparse", "importlib", "json", "os", "re", "shutil", "sys", "time", "urllib", "uuid", "comfy_client", "PIL"}, f"{name}.py: {imports}"
