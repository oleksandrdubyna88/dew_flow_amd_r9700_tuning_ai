#!/usr/bin/env python3
"""Frame interpolation of a clip with FILM, through ComfyUI's native nodes: a 16 fps clip becomes a 32 fps one of the same length (more in-between frames,
smoother motion; nothing is re-generated). The model is the `film` set of comfyui/models.conf (frame_interpolation/film_net_fp16.safetensors).

  film_interpolate.py graph <video name> --prefix <p> [--multiplier 2] [--fps 32]                      the ComfyUI prompt JSON on stdout (no server)
  film_interpolate.py run <video file> --input-dir <dir> --prefix <p> [--multiplier 2] [--fps 32] [--ceiling-s 1800]
                                                       copies the clip into ComfyUI's input folder and queues the prompt; prints the saved file

The graph: LoadVideo -> GetVideoComponents -> FrameInterpolate (FrameInterpolationModelLoader) -> CreateVideo (the new fps) -> SaveVideo (mp4, h264).
The output fps must be the input fps times the multiplier, or the clip's length changes: an --fps that is not --input-fps (default 16) x --multiplier is
refused, so a 24 fps clip is not silently made slower — give its --input-fps."""
import argparse
import json
import os
import re
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from comfy_client import ToolError, run  # noqa: E402

MODEL = "film_net_fp16.safetensors"
DEFAULT_INPUT_FPS = 16  # what the Wan 2.2 clips of this toolkit's ComfyUI work are made at


def build_graph(video_name, prefix, multiplier=2, fps=None, input_fps=DEFAULT_INPUT_FPS):
    if not re.fullmatch(r"[^/\\\x00-\x1f]{1,200}", video_name):
        raise ToolError("ARGS: the video name is a file name in ComfyUI's input folder, without a folder")
    if not (isinstance(multiplier, int) and 2 <= multiplier <= 8):
        raise ToolError("ARGS: --multiplier is 2-8")
    fps = input_fps * multiplier if fps is None else fps
    if abs(fps - input_fps * multiplier) > 1e-6:
        raise ToolError(f"ARGS: --fps {fps:g} is not --input-fps {input_fps:g} x --multiplier {multiplier}: the clip would change its length")
    return {
        "load": {"class_type": "LoadVideo", "inputs": {"file": video_name}},
        "parts": {"class_type": "GetVideoComponents", "inputs": {"video": ["load", 0]}},
        "model": {"class_type": "FrameInterpolationModelLoader", "inputs": {"model_name": MODEL}},
        "interp": {"class_type": "FrameInterpolate", "inputs": {"interp_model": ["model", 0], "images": ["parts", 0], "multiplier": multiplier}},
        "video": {"class_type": "CreateVideo", "inputs": {"images": ["interp", 0], "fps": float(fps)}},
        "save": {"class_type": "SaveVideo", "inputs": {"video": ["video", 0], "filename_prefix": prefix, "format": "mp4", "codec": "h264"}},
    }


def build_parser():
    parser = argparse.ArgumentParser(prog="film_interpolate.py", description="FILM frame interpolation of one clip through ComfyUI.")
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("graph", "run"):
        p = sub.add_parser(name)
        p.add_argument("video", help="graph: the file name in the input folder; run: the clip to copy there")
        p.add_argument("--prefix", required=True, help="ComfyUI's filename_prefix of the result")
        p.add_argument("--multiplier", type=int, default=2)
        p.add_argument("--fps", type=float, default=None)
        p.add_argument("--input-fps", type=float, default=DEFAULT_INPUT_FPS)
        if name == "run":
            p.add_argument("--input-dir", required=True, help="ComfyUI's input folder, as this process sees it")
            p.add_argument("--ceiling-s", type=int, default=1800)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        if args.command == "graph":
            print(json.dumps(build_graph(args.video, args.prefix, args.multiplier, args.fps, args.input_fps), indent=1))
            return 0
        name = f"film_{os.path.basename(args.video)}"
        graph = build_graph(name, args.prefix, args.multiplier, args.fps, args.input_fps)
        os.makedirs(args.input_dir, exist_ok=True)
        shutil.copyfile(args.video, os.path.join(args.input_dir, name))
        seconds, files = run(graph, args.ceiling_s, say=lambda text: print(f"film_interpolate: {text}", flush=True))
        print(f"film_interpolate: {args.video}: {seconds:.1f} s -> {', '.join(f['filename'] for f in files) or 'no file'}")
    except ToolError as error:
        print(f"film_interpolate: {error}", file=sys.stderr)
        return 1
    except OSError as error:
        print(f"film_interpolate: FILE: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
