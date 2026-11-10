#!/usr/bin/env python3
"""Masked repaint with an image-edit model (Qwen-Image-Edit-2511 by default): only the masked area of a picture is sampled again, and the result is pasted back
onto the untouched picture. research/SCREENING_comfyui_2026-11-08.md §30 is the record of why, and what it fixed.

  masked_repaint.py preview <spec.json>... --out <png>                 the masks in red over crops of the pictures, one tile per spec (Pillow only, no server)
  masked_repaint.py graph <spec.json> [--seed-index <n>]               the ComfyUI prompt JSON of one candidate on stdout (no server, no file written)
  masked_repaint.py run <spec.json> --input-dir <dir> [--ceiling-s <s>]   writes the prepared pictures into ComfyUI's input folder and queues one prompt per seed

THE SPEC is one JSON object; a key that is not below is refused, naming the legal keys:
  name           the stem of the prepared files in the input folder (letters, digits, `-`, `_`)
  picture        the picture to repair (a path the tool can read)
  shapes         a list of {"ellipse": [x0, y0, x1, y1]} and {"line": [x0, y0, x1, y1], "width": <px>}: fractions of the picture's width and height,
                 placed by eye on a `sheets.py grid` crop. An ellipse grows by `margin` of its box on every side; a line also gets a disc at its first point
                 (the end of a long object is often wider than its body)
  prompt         names ONLY what fills the place ("short green grass", "a cloudy sky above the wall") — never the thing to remove: the model draws what a
                 prompt names, even after "no" or "NOT"; and at cfg 1.0 a negative prompt has no effect at all
  denoise        (0, 1]; 0.85-0.95 to replace, about 0.6 to keep a shape and change its surface
  seeds          one candidate per seed
  output_prefix  ComfyUI's filename_prefix, words of letters, digits, `-` and `_` joined by `/` (a folder below ComfyUI's output folder, never `..`);
                 candidate n is saved as <output_prefix>_<n>
  optional: blur_fill (true: the mask is first filled with a blur of the picture, so the model no longer sees what is there; false keeps its shape),
            reference (a picture given to the model as image 2, e.g. the object to copy), margin (0.25), feather (4 px), fill_radius (18 px),
            models {"unet", "clip", "vae"} (file names in the models volume; the defaults are DEFAULT_MODELS),
            steps (4), cfg (1.0), shift (3.1): the defaults are the 4-step Lightning edit model's; another model needs its own schedule
The prepared pictures have fixed names per spec `name` (repaint_<name>_pick/fill/mask[/reference].png), so a second run of a name overwrites the first one's
inputs: run one spec name at a time.

Check the preview BEFORE any GPU time: a box placed a little off repaints the wrong place, and the paste then keeps that mistake perfectly."""
import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from comfy_client import ToolError, run  # noqa: E402

DEFAULT_MODELS = {"unet": "qwen_image_edit_2511_fp8_e4m3fn_scaled_lightning_comfyui_4steps_v1.0.safetensors",
                  "clip": "qwen_2.5_vl_7b_fp8_scaled.safetensors", "vae": "qwen_image_vae.safetensors"}
REQUIRED = ("name", "picture", "shapes", "prompt", "denoise", "seeds", "output_prefix")
OPTIONAL = {"blur_fill": True, "reference": None, "margin": 0.25, "feather": 4, "fill_radius": 18, "models": None,
            "steps": 4, "cfg": 1.0, "shift": 3.1}  # the schedule defaults are the 4-step Lightning edit model's
SAMPLER = {"sampler_name": "euler", "scheduler": "simple"}
PREFIX_RE = r"[A-Za-z0-9_-]{1,64}(/[A-Za-z0-9_-]{1,64}){0,4}"
COORD_RANGE = (-0.1, 1.1)  # a line may end a little outside the picture (a blade that leaves the frame)
PREVIEW_TILE = 400


def _legal():
    return ", ".join(REQUIRED + tuple(OPTIONAL))


def _check_shape(shape, i):
    kinds = [k for k in ("ellipse", "line") if k in shape]
    if len(kinds) != 1 or set(shape) - {"ellipse", "line", "width"}:
        raise ToolError(f"SPEC: shapes[{i}] is one of {{\"ellipse\": [x0, y0, x1, y1]}} or {{\"line\": [x0, y0, x1, y1], \"width\": <px>}}")
    box = shape[kinds[0]]
    if not (isinstance(box, list) and len(box) == 4 and all(_number(v) and COORD_RANGE[0] <= v <= COORD_RANGE[1] for v in box)):
        raise ToolError(f"SPEC: shapes[{i}].{kinds[0]} is four fractions of the picture between {COORD_RANGE[0]} and {COORD_RANGE[1]}")
    if kinds[0] == "ellipse" and not (box[0] < box[2] and box[1] < box[3]):
        raise ToolError(f"SPEC: shapes[{i}].ellipse needs x0 < x1 and y0 < y1")
    if kinds[0] == "line" and not (isinstance(shape.get("width"), int) and not isinstance(shape["width"], bool) and 0 < shape["width"] <= 2000):
        raise ToolError(f"SPEC: shapes[{i}].line needs a width in pixels (1-2000)")


def check_spec(spec):
    """The spec with its defaults filled in; ToolError naming the first problem."""
    if not isinstance(spec, dict):
        raise ToolError("SPEC: the spec is one JSON object")
    unknown = sorted(set(spec) - set(REQUIRED) - set(OPTIONAL))
    if unknown:
        raise ToolError(f"SPEC: unknown key {unknown[0]!r}; legal: {_legal()}")
    missing = [k for k in REQUIRED if k not in spec]
    if missing:
        raise ToolError(f"SPEC: missing key {missing[0]!r}; legal: {_legal()}")
    if not (isinstance(spec["name"], str) and re.fullmatch(r"[A-Za-z0-9_-]{1,64}", spec["name"])):
        raise ToolError("SPEC: name is 1-64 letters, digits, '-' or '_'")
    if not (isinstance(spec["picture"], str) and spec["picture"].strip()):
        raise ToolError("SPEC: picture is a non-empty text")
    if not (isinstance(spec["output_prefix"], str) and re.fullmatch(PREFIX_RE, spec["output_prefix"])):
        raise ToolError("SPEC: output_prefix is folder/name words of letters, digits, '-' or '_' joined by '/' (at most 5, never '..')")
    if not (spec.get("reference") is None or (isinstance(spec["reference"], str) and spec["reference"].strip())):
        raise ToolError("SPEC: reference is a picture path, or absent")
    if not (isinstance(spec["shapes"], list) and spec["shapes"]):
        raise ToolError("SPEC: shapes is a non-empty list")
    for i, shape in enumerate(spec["shapes"]):
        _check_shape(shape if isinstance(shape, dict) else {}, i)
    if not (_number(spec["denoise"]) and 0 < spec["denoise"] <= 1):
        raise ToolError("SPEC: denoise is a number in (0, 1]")
    if not (isinstance(spec["seeds"], list) and spec["seeds"] and all(isinstance(s, int) and not isinstance(s, bool) and s >= 0 for s in spec["seeds"])):
        raise ToolError("SPEC: seeds is a non-empty list of integers >= 0")
    if not (isinstance(spec["prompt"], str) and spec["prompt"].strip()):
        raise ToolError("SPEC: prompt is a non-empty text naming what fills the place")
    return _check_optional({**OPTIONAL, **spec})


def _number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _check_optional(checked):
    if not isinstance(checked["blur_fill"], bool):
        raise ToolError("SPEC: blur_fill is true or false")
    if not (_number(checked["margin"]) and 0 <= checked["margin"] <= 2):
        raise ToolError("SPEC: margin is a fraction of the box, 0-2")
    for key in ("feather", "fill_radius"):
        if not (_number(checked[key]) and 0 <= checked[key] <= 200):
            raise ToolError(f"SPEC: {key} is a number of pixels, 0-200")
    if not (isinstance(checked["steps"], int) and not isinstance(checked["steps"], bool) and 1 <= checked["steps"] <= 200):
        raise ToolError("SPEC: steps is a whole number 1-200")
    if not (_number(checked["cfg"]) and 0 <= checked["cfg"] <= 30):
        raise ToolError("SPEC: cfg is a number 0-30")
    if not (_number(checked["shift"]) and 0 <= checked["shift"] <= 20):
        raise ToolError("SPEC: shift is a number 0-20")
    models = checked["models"] or {}
    if not (isinstance(models, dict) and not set(models) - set(DEFAULT_MODELS) and all(isinstance(v, str) and v for v in models.values())):
        raise ToolError(f"SPEC: models is an object with any of {', '.join(DEFAULT_MODELS)} as file names")
    return {**checked, "models": {**DEFAULT_MODELS, **models}}


def load_spec(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return check_spec(json.load(handle))
    except (OSError, ValueError) as error:
        raise ToolError(f"SPEC: {path}: {error}") from None


def build_mask(size, spec):
    """The mask ("L", 255 = repaint) for a picture of `size`: the shapes, then a Gaussian feather."""
    from PIL import Image, ImageDraw, ImageFilter
    width, height = size
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    for shape in spec["shapes"]:
        if "ellipse" in shape:
            x0, y0, x1, y1 = shape["ellipse"]
            dx, dy = (x1 - x0) * spec["margin"], (y1 - y0) * spec["margin"]
            draw.ellipse(((x0 - dx) * width, (y0 - dy) * height, (x1 + dx) * width, (y1 + dy) * height), fill=255)
        else:
            x0, y0, x1, y1 = shape["line"]
            stroke, radius = shape["width"], shape["width"] * 1.1
            draw.line(((x0 * width, y0 * height), (x1 * width, y1 * height)), fill=255, width=stroke)
            draw.ellipse((x0 * width - radius, y0 * height - radius, x0 * width + radius, y0 * height + radius), fill=255)
    return mask.filter(ImageFilter.GaussianBlur(spec["feather"]))


def input_names(spec):
    stem = f"repaint_{spec['name']}"
    names = {"pick": f"{stem}_pick.png", "fill": f"{stem}_fill.png", "mask": f"{stem}_mask.png"}
    if spec["reference"]:
        names["reference"] = f"{stem}_reference.png"
    return names


def prepare(spec, input_dir):
    """Writes the prepared pictures into ComfyUI's input folder: the picture, the filled picture, the mask (RGB, read as the red channel) and the reference."""
    from PIL import Image, ImageFilter
    names = input_names(spec)
    picture = Image.open(spec["picture"]).convert("RGB")
    mask = build_mask(picture.size, spec)
    fill = picture.copy()
    box = mask.getbbox()
    if spec["blur_fill"] and box:
        # only the mask's box, grown by three blur radii (what the blur reads), is blurred: not the whole frame
        reach = int(3 * spec["fill_radius"]) + 1
        area = (max(0, box[0] - reach), max(0, box[1] - reach), min(picture.width, box[2] + reach), min(picture.height, box[3] + reach))
        fill.paste(picture.crop(area).filter(ImageFilter.GaussianBlur(spec["fill_radius"])), area[:2], mask.crop(area))
    os.makedirs(input_dir, exist_ok=True)
    picture.save(os.path.join(input_dir, names["pick"]))
    fill.save(os.path.join(input_dir, names["fill"]))
    Image.merge("RGB", (mask, mask, mask)).save(os.path.join(input_dir, names["mask"]))
    if spec["reference"]:
        Image.open(spec["reference"]).convert("RGB").save(os.path.join(input_dir, names["reference"]))
    return names


def _encoders(names, prompt):
    images = {"image1": ["scale1", 0]}
    graph = {"ref1": {"class_type": "LoadImage", "inputs": {"image": names["fill"]}},
             "scale1": {"class_type": "ImageScaleToTotalPixels", "inputs": {"image": ["ref1", 0], "upscale_method": "lanczos", "megapixels": 1.0,
                                                                             "resolution_steps": 1}}}
    if "reference" in names:
        graph["ref2"] = {"class_type": "LoadImage", "inputs": {"image": names["reference"]}}
        graph["scale2"] = {"class_type": "ImageScaleToTotalPixels", "inputs": {"image": ["ref2", 0], "upscale_method": "lanczos", "megapixels": 1.0,
                                                                                "resolution_steps": 1}}
        images["image2"] = ["scale2", 0]
    for key, text in (("pos", prompt), ("neg", "")):
        graph[key] = {"class_type": "TextEncodeQwenImageEditPlus", "inputs": {"clip": ["clip", 0], "prompt": text, "vae": ["vae", 0], **images}}
    return graph


def build_graph(spec, seed_index=0):
    """The ComfyUI prompt (API format) of candidate seed_index + 1. The edit model sees the filled picture (and the reference); only the mask is sampled
    (VAEEncode + SetLatentNoiseMask), and ImageCompositeMasked pastes the decoded result onto the untouched picture through the same mask."""
    names, models = input_names(spec), spec["models"]
    graph = {"unet": {"class_type": "UNETLoader", "inputs": {"unet_name": models["unet"], "weight_dtype": "default"}},
             "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": models["clip"], "type": "qwen_image", "device": "default"}},
             "vae": {"class_type": "VAELoader", "inputs": {"vae_name": models["vae"]}},
             "shift": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["unet", 0], "shift": float(spec["shift"])}},
             **_encoders(names, spec["prompt"]),
             "orig": {"class_type": "LoadImage", "inputs": {"image": names["pick"]}},
             "mask": {"class_type": "LoadImageMask", "inputs": {"image": names["mask"], "channel": "red"}},
             "enc": {"class_type": "VAEEncode", "inputs": {"pixels": ["ref1", 0], "vae": ["vae", 0]}},
             "latent": {"class_type": "SetLatentNoiseMask", "inputs": {"samples": ["enc", 0], "mask": ["mask", 0]}}}
    graph["sampler"] = {"class_type": "KSampler", "inputs": {
        "model": ["shift", 0], "positive": ["pos", 0], "negative": ["neg", 0], "latent_image": ["latent", 0], "seed": spec["seeds"][seed_index],
        "steps": spec["steps"], "cfg": float(spec["cfg"]), "sampler_name": SAMPLER["sampler_name"], "scheduler": SAMPLER["scheduler"],
        "denoise": float(spec["denoise"])}}
    graph["decode"] = {"class_type": "VAEDecode", "inputs": {"samples": ["sampler", 0], "vae": ["vae", 0]}}
    graph["paste"] = {"class_type": "ImageCompositeMasked", "inputs": {"destination": ["orig", 0], "source": ["decode", 0], "x": 0, "y": 0,
                                                                        "resize_source": False, "mask": ["mask", 0]}}
    graph["save"] = {"class_type": "SaveImage", "inputs": {"images": ["paste", 0], "filename_prefix": f"{spec['output_prefix']}_{seed_index + 1}"}}
    return graph


def _crop_box(spec, size):
    xs = [v for s in spec["shapes"] for v in (s.get("ellipse") or s["line"])[0::2]]
    ys = [v for s in spec["shapes"] for v in (s.get("ellipse") or s["line"])[1::2]]
    x0, y0 = max(0.0, min(xs) - 0.08), max(0.0, min(ys) - 0.12)
    x1, y1 = min(1.0, max(xs) + 0.08), min(1.0, max(ys) + 0.12)
    return int(x0 * size[0]), int(y0 * size[1]), max(int(x1 * size[0]), int(x0 * size[0]) + 1), max(int(y1 * size[1]), int(y0 * size[1]) + 1)


def preview(specs, out):
    """One PREVIEW_TILE square per spec: the area around its shapes, the mask in half-strength red."""
    from PIL import Image
    tiles = []
    for spec in specs:
        picture = Image.open(spec["picture"]).convert("RGB")
        mask = build_mask(picture.size, spec)
        shown = Image.composite(Image.new("RGB", picture.size, (255, 0, 0)), picture, mask.point(lambda v: v // 2))
        tiles.append(shown.crop(_crop_box(spec, picture.size)).resize((PREVIEW_TILE, PREVIEW_TILE)))
    sheet = Image.new("RGB", (PREVIEW_TILE * len(tiles), PREVIEW_TILE))
    for i, tile in enumerate(tiles):
        sheet.paste(tile, (PREVIEW_TILE * i, 0))
    sheet.save(out)
    return len(tiles)


def run_spec(spec, input_dir, ceiling_s):
    prepare(spec, input_dir)
    for i in range(len(spec["seeds"])):
        seconds, files = run(build_graph(spec, i), ceiling_s, say=lambda text: print(f"masked_repaint: {text}", flush=True))
        print(f"masked_repaint: {spec['name']} candidate {i + 1} (seed {spec['seeds'][i]}): {seconds:.1f} s -> "
              f"{', '.join(f['filename'] for f in files) or 'no file'}", flush=True)


def build_parser():
    parser = argparse.ArgumentParser(prog="masked_repaint.py", description="Masked repaint with an image-edit model, pasted back onto the untouched picture.")
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("preview", help="the masks in red over crops of the pictures")
    p.add_argument("specs", nargs="+")
    p.add_argument("--out", required=True)
    g = sub.add_parser("graph", help="the prompt JSON of one candidate")
    g.add_argument("spec")
    g.add_argument("--seed-index", type=int, default=0, help="0-based index into the spec's seeds (candidate n is index n-1)")
    r = sub.add_parser("run", help="prepare the pictures and queue one prompt per seed")
    r.add_argument("spec")
    r.add_argument("--input-dir", required=True, help="ComfyUI's input folder, as this process sees it")
    r.add_argument("--ceiling-s", type=int, default=900)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        if args.command == "preview":
            print(f"masked_repaint: preview of {preview([load_spec(p) for p in args.specs], args.out)} spec(s) -> {args.out}")
        elif args.command == "graph":
            spec = load_spec(args.spec)
            if not 0 <= args.seed_index < len(spec["seeds"]):
                count = len(spec["seeds"])
                raise ToolError(f"SPEC: --seed-index is 0-based: 0..{count - 1} for {count} seeds (candidate n is seed index n-1)")
            print(json.dumps(build_graph(spec, args.seed_index), indent=1))
        else:
            run_spec(load_spec(args.spec), args.input_dir, args.ceiling_s)
    except ToolError as error:
        print(f"masked_repaint: {error}", file=sys.stderr)
        return 1
    except OSError as error:  # a picture or a folder that cannot be read or written: one line, never a traceback
        print(f"masked_repaint: FILE: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
