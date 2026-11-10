"""Fix jumping / diverging eyes in the restyled (Arcane) clips: one shot, variants of the motion prompt, steps and model.

Run inside the container:  wslc exec comfyui python /opt/tests/eyes_try.py <variant>... [--shot 2] [--tag l100_d55]
Variants: gaze (gaze words, FastWan 3 steps), gaze4 (gaze words, FastWan 4 steps), gaze14b (gaze words, Wan 2.2 A14B +
lightx2v 4-step, set 2's graph). Reads series/elf_set2_arcane/key_s<k>_<tag>_*.png; writes
series/elf_set2_arcane/eyes/s<k>_<tag>_<variant>_*.mp4.
"""
import argparse
import glob
import os
import shutil
import sys

os.environ["SERIES"] = "elf_v5"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import series_elf as story  # noqa: E402

GAZE = ("Steady natural gaze: both eyes look in the same direction and move together, calm eye movement, no eye jitter, "
        "symmetric eyes, consistent eye shape through the whole shot.")
STYLE = "Arcane style painted animation, consistent with the first frame."
BASE = "/data/output/series/elf_set2_arcane"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("variants", nargs="+")
    ap.add_argument("--shot", type=int, default=2)
    ap.add_argument("--tag", default="l100_d55")
    a = ap.parse_args()
    k = a.shot
    shot = story.SHOTS[k - 1]
    key = sorted(glob.glob(f"{BASE}/key_s{k}_{a.tag}_*.png"))[-1]
    name = f"eyes_s{k}_{a.tag}.png"
    shutil.copyfile(key, os.path.join("/data/input", name))
    motion = f"{shot['motion'].replace(story.STYLE_V2, '').strip()} {GAZE} {STYLE}"
    for v in a.variants:
        if v == "gaze14b":
            wf = story.wan14b_video_wf(k, dict(shot, motion=motion), name)
        else:
            wf = story.with_video_mode(story.video_wf(k, dict(shot, motion=motion), name))
            if v == "gaze4":
                wf["sampler"]["inputs"]["steps"] = 4
        wf["save"]["inputs"]["filename_prefix"] = f"series/elf_set2_arcane/eyes/s{k}_{a.tag}_{v}"
        secs, files = story.run(wf, 7200)
        print(f"shot {k} {v}: {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


if __name__ == "__main__":
    main()
