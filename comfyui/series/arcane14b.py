"""The Arcane film with steady eyes: set B's Arcane keyframes (LoRA 1.0, denoise 0.55) animated by Wan 2.2 A14B + lightx2v
4-step with the gaze words (the eye test of 2026-11-08 showed 14B holds the gaze and the painted look; 5B FastWan did not).

Run inside the container, ONE shot per call (the 14B pair fails with "out of memory" after ~3 clips on one server, so the
caller restarts ComfyUI between calls):  wslc exec comfyui python /opt/tests/arcane14b.py shot <k>
Then:  wslc exec comfyui python /opt/tests/arcane14b.py join
Writes series/elf_set2_arcane/film14b/clip_s<k>_*.mp4 and series/elf_set2_arcane/elf_set2_arcane_14b_30s.mp4.
"""
import glob
import os
import shutil
import subprocess
import sys

os.environ["SERIES"] = "elf_v5"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import series_elf as story  # noqa: E402
from eyes_try import GAZE, STYLE  # noqa: E402

BASE = "/data/output/series/elf_set2_arcane"
TAG = "l100_d55"


def newest(pattern):
    found = sorted(glob.glob(pattern))
    return found[-1] if found else None


def shot(k):
    if newest(f"{BASE}/film14b/clip_s{k}_*.mp4"):
        print(f"shot {k}: clip exists", flush=True)
        return
    s = story.SHOTS[k - 1]
    name = f"arcane14b_s{k}.png"
    shutil.copyfile(newest(f"{BASE}/key_s{k}_{TAG}_*.png"), os.path.join("/data/input", name))
    motion = f"{s['motion'].replace(story.STYLE_V2, '').strip()} {GAZE} {STYLE}"
    wf = story.wan14b_video_wf(k, dict(s, motion=motion), name)
    wf["save"]["inputs"]["filename_prefix"] = f"series/elf_set2_arcane/film14b/clip_s{k}"
    secs, files = story.run(wf, 7200)
    print(f"shot {k}: clip {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


def join():
    clips = [newest(f"{BASE}/film14b/clip_s{k}_*.mp4") for k in range(1, 7)]
    if not all(clips):
        raise SystemExit(f"missing clips: {clips}")
    with open(f"{BASE}/film14b/concat.txt", "w") as f:
        f.writelines(f"file '{c}'\n" for c in clips)
    dest = f"{BASE}/elf_set2_arcane_14b_30s.mp4"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", f"{BASE}/film14b/concat.txt",
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", dest], check=True, timeout=600)
    print("joined:", dest, flush=True)


if __name__ == "__main__":
    if sys.argv[1] == "shot":
        shot(int(sys.argv[2]))
    else:
        join()
