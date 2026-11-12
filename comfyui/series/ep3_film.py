"""Episode 3: FILM frame interpolation 16 -> 32 fps of the chosen clips (smoother motion; the owner agreed 2026-11-10,
local tools only). Native nodes: LoadVideo -> GetVideoComponents -> FrameInterpolate (film_net_fp16, x2) -> CreateVideo
(32 fps) -> SaveVideo. The chosen clip per shot: CHOICE[k] label ("" = the first seed, "b"/"c" = rerolls), newest file.
Run inside the comfyui container:  python /opt/tests/ep3_film.py [k...]  -> series/ep3/film/clip_sNN_32fps_*.mp4
"""
import glob
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import episode2 as ep  # noqa: E402

CLIPS = "/data/output/series/ep3/clips"
CHOICE = {1: "n", 6: "b", 11: "b", 20: "b", 21: "f"}  # kept clip labels ("" = first seed); s01 c18 keyframe, s06 no blink, s11b (cut before its wink), s20b, s21 flame-free


def chosen(k):
    files = sorted(glob.glob(f"{CLIPS}/clip_s{k:02d}{CHOICE.get(k, '')}_0*.mp4"))
    return files[-1] if files else None


def film(k):
    src = chosen(k)
    if not src:
        print(f"ep3 film s{k:02d}: no clip", flush=True)
        return
    film_file(src, f"series/ep3/film/clip_s{k:02d}{CHOICE.get(k, '')}_32fps", f"ep3 film s{k:02d}")


def film_file(src, prefix, label):
    """FILM x2 of one clip file -> <prefix>_*.mp4 at 32 fps (skipped when it exists)."""
    if ep.newest(f"/data/output/{prefix}_*.mp4"):
        return
    name = f"film_{os.path.basename(prefix)}.mp4"
    shutil.copyfile(src, os.path.join("/data/input", name))
    wf = {
        "load": {"class_type": "LoadVideo", "inputs": {"file": name}},
        "parts": {"class_type": "GetVideoComponents", "inputs": {"video": ["load", 0]}},
        "model": {"class_type": "FrameInterpolationModelLoader", "inputs": {"model_name": "film_net_fp16.safetensors"}},
        "interp": {"class_type": "FrameInterpolate", "inputs": {"interp_model": ["model", 0], "images": ["parts", 0],
                                                                 "multiplier": 2}},
        "video": {"class_type": "CreateVideo", "inputs": {"images": ["interp", 0], "fps": 32.0}},
        "save": {"class_type": "SaveVideo", "inputs": {"video": ["video", 0], "filename_prefix": prefix, "format": "mp4",
                                                       "codec": "h264"}},
    }
    secs, _ = ep.story.run(wf, 1800)
    print(f"{label} <- {src.split('/')[-1]}: {secs:.1f} s", flush=True)


if __name__ == "__main__":
    # "file <src.mp4> <out prefix>..." (pairs) for any clip, e.g. episode 1 v3; else episode 3 shot numbers
    if sys.argv[1:2] == ["file"]:
        a = sys.argv[2:]
        for src, prefix in zip(a[0::2], a[1::2]):
            film_file(src, prefix, f"film {os.path.basename(prefix)}")
    else:
        for k in [int(a) for a in sys.argv[1:]] or range(1, 24):
            film(k)
