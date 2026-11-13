"""Animate a folder of restyled keyframes with Wan 2.2 TI2V 5B + FastWan 3-step (v5's tested graph) and join a 30 s film.

Run inside the container:
  wslc exec comfyui python /opt/tests/restyle_video.py <folder under series/> <keyframe tag> [--style "<words>"]
e.g.  restyle_video.py elf_set2_arcane l100_d55 --style "Arcane style painted animation."
Reads series/<folder>/key_s<k>_<tag>_*.png (the newest of each), writes series/<folder>/clip_<tag>_s<k>_*.mp4 and
series/<folder>/<folder>_<tag>_30s.mp4. A clip that exists is not rendered again.
"""
import argparse
import glob
import os
import shutil
import subprocess
import sys

os.environ["SERIES"] = "elf_v5"  # the FastWan video mode and the same six shot prompts as set 2 (HERO_V5, shots_v3)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import series_elf as story  # noqa: E402


def newest(pattern):
    found = sorted(glob.glob(pattern))
    return found[-1] if found else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("tag")
    ap.add_argument("--style", default="")
    a = ap.parse_args()
    base = f"/data/output/series/{a.folder}"
    clips = []
    for k, shot in enumerate(story.SHOTS, 1):
        clip = newest(f"{base}/clip_{a.tag}_s{k}_*.mp4")
        if not clip:
            key = newest(f"{base}/key_s{k}_{a.tag}_*.png")
            if not key:
                raise SystemExit(f"shot {k}: no keyframe key_s{k}_{a.tag}_*.png in {base}")
            name = f"{a.folder}_{a.tag}_s{k}.png"
            shutil.copyfile(key, os.path.join("/data/input", name))  # output is another mount: copy, never rename
            motion = shot["motion"].replace(story.STYLE_V2, "").strip()
            wf = story.with_video_mode(story.video_wf(k, dict(shot, motion=f"{motion} {a.style}".strip()), name))
            wf["save"]["inputs"]["filename_prefix"] = f"series/{a.folder}/clip_{a.tag}_s{k}"
            secs, files = story.run(wf, 3600)
            print(f"shot {k}: clip {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)
            clip = newest(f"{base}/clip_{a.tag}_s{k}_*.mp4")
        clips.append(clip)
    lst = f"{base}/concat_{a.tag}.txt"
    with open(lst, "w") as f:
        f.writelines(f"file '{c}'\n" for c in clips)
    dest = f"{base}/{a.folder}_{a.tag}_30s.mp4"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-c:v", "libx264",
                    "-pix_fmt", "yuv420p", "-crf", "18", dest], check=True, timeout=600)
    print("joined:", dest, flush=True)


if __name__ == "__main__":
    main()
