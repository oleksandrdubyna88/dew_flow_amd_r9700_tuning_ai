"""The 30 s story with Lyriel (an ORIGINAL character): the six shots of set 2 with her description instead of the heroine's,
keyframes by Qwen-Image 2512 (set 2's look), clips by Wan 2.2 TI2V 5B + FastWan 3-step, joined into a film.

Run inside the container:  wslc exec comfyui python /opt/tests/lyriel_film.py [keyframes|videos|all]
Writes /data/output/series/lyriel/key_s<k>_*.png, clip_s<k>_*.mp4 and lyriel_30s.mp4. Existing files are not redone.
"""
import glob
import os
import shutil
import subprocess
import sys

os.environ["SERIES"] = "elf_v5"  # FastWan video mode; the shot list is rebuilt below with Lyriel as the hero
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import series_elf as story  # noqa: E402  (first: characters.py sets SERIES=elf_set2, and the module is cached on import)
import characters  # noqa: E402

assert story.VIDEO, "series_elf was loaded without the FastWan video mode"

LYRIEL = characters.CHARS["lyriel_small_ears"]
SHOTS = []
for shot in story.shots_v3(LYRIEL, story.STYLE_V2):
    shot = dict(shot)
    for key in ("key", "motion"):
        shot[key] = shot[key].replace("The elf woman", "The woman").replace("the elf woman", "the woman")
    SHOTS.append(shot)
OUT = "/data/output/series/lyriel"


def newest(pattern):
    found = sorted(glob.glob(pattern))
    return found[-1] if found else None


def keyframes():
    for k, shot in enumerate(SHOTS, 1):
        if newest(f"{OUT}/key_s{k}_*.png"):
            continue
        wf = story.qwen_keyframe_wf(k, shot)
        wf["save"]["inputs"]["filename_prefix"] = f"series/lyriel/key_s{k}"
        secs, files = story.run(wf, 900)
        print(f"shot {k}: keyframe {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


def videos():
    story.HERO = LYRIEL  # video_wf puts the hero text after the motion text
    clips = []
    for k, shot in enumerate(SHOTS, 1):
        clip = newest(f"{OUT}/clip_s{k}_*.mp4")
        if not clip:
            name = f"lyriel_key_s{k}.png"
            shutil.copyfile(newest(f"{OUT}/key_s{k}_*.png"), os.path.join("/data/input", name))
            wf = story.with_video_mode(story.video_wf(k, shot, name))
            wf["save"]["inputs"]["filename_prefix"] = f"series/lyriel/clip_s{k}"
            secs, files = story.run(wf, 3600)
            print(f"shot {k}: clip {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)
            clip = newest(f"{OUT}/clip_s{k}_*.mp4")
        clips.append(clip)
    with open(f"{OUT}/concat.txt", "w") as f:
        f.writelines(f"file '{c}'\n" for c in clips)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", f"{OUT}/concat.txt",
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", f"{OUT}/lyriel_30s.mp4"], check=True, timeout=600)
    print("joined:", f"{OUT}/lyriel_30s.mp4", flush=True)


def shot14b(k):
    """One clip by Wan 2.2 A14B + lightx2v with the gaze words (holds faces and eyes; see the eye test), one per call."""
    from eyes_try import GAZE
    if newest(f"{OUT}/film14b/clip_s{k}_*.mp4"):
        print(f"shot {k}: clip exists", flush=True)
        return
    story.HERO = LYRIEL
    shot = SHOTS[k - 1]
    name = f"lyriel_key_s{k}.png"
    shutil.copyfile(newest(f"{OUT}/key_s{k}_*.png"), os.path.join("/data/input", name))
    wf = story.wan14b_video_wf(k, dict(shot, motion=f"{shot['motion']} {GAZE}"), name)
    wf["save"]["inputs"]["filename_prefix"] = f"series/lyriel/film14b/clip_s{k}"
    secs, files = story.run(wf, 7200)
    print(f"shot {k}: clip {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


def join14b():
    clips = [newest(f"{OUT}/film14b/clip_s{k}_*.mp4") for k in range(1, 7)]
    if not all(clips):
        raise SystemExit(f"missing clips: {clips}")
    with open(f"{OUT}/film14b/concat.txt", "w") as f:
        f.writelines(f"file '{c}'\n" for c in clips)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", f"{OUT}/film14b/concat.txt",
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", f"{OUT}/lyriel_14b_30s.mp4"], check=True, timeout=600)
    print("joined:", f"{OUT}/lyriel_14b_30s.mp4", flush=True)


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "shot14b":
        shot14b(int(sys.argv[2]))
        sys.exit(0)
    if len(sys.argv) > 1 and sys.argv[1] == "join14b":
        join14b()
        sys.exit(0)
    os.makedirs(OUT, exist_ok=True)
    phase = sys.argv[1] if len(sys.argv) > 1 else "all"
    if phase in ("keyframes", "all"):
        keyframes()
    if phase in ("videos", "all"):
        videos()
