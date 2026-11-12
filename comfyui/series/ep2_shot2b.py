"""Episode 2, shot 2 again: in the first clip her eyes open while she is meant to sleep (the narration says "sleep").
Same keyframe and seed, the motion says the eyes stay closed. Then the v2 film (shots 1, 2b, 3–8) is joined.

Run inside the container (restart ComfyUI first):  wslc exec comfyui python /opt/tests/ep2_shot2b.py [render|join]
Writes series/ep2/alt/clip_s2b_*.mp4 and series/ep2/ep2_arcane_14b_v2.mp4.
"""
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import episode2 as ep  # noqa: E402

MOTION = ("She lies asleep on the fur bedroll with her eyes CLOSED the whole time, in deep peaceful sleep, breathing slowly "
          "and evenly, her face relaxed and still; the embers glow and fade; a few sparks rise.")


def render():
    if ep.newest(f"{ep.OUT}/alt/clip_s2b_*.mp4"):
        print("shot 2b: clip exists", flush=True)
        return
    ep.story.HERO = ep.HERO
    name = "ep2_arc_s2b.png"
    shutil.copyfile(ep.newest(f"{ep.OUT}/arc_s2_*.png"), os.path.join("/data/input", name))
    wf = ep.story.wan14b_video_wf(2, {"motion": f"{MOTION} {ep.ARC_STYLE}", "seed": 302}, name)
    wf["save"]["inputs"]["filename_prefix"] = "series/ep2/alt/clip_s2b"
    secs, files = ep.story.run(wf, 7200)
    print(f"shot 2b: clip {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


def join():
    clips = [ep.newest(f"{ep.OUT}/clip_s{k}_*.mp4") for k in range(1, 9)]
    clips[1] = ep.newest(f"{ep.OUT}/alt/clip_s2b_*.mp4")
    if not all(clips):
        raise SystemExit(f"missing clips: {clips}")
    with open(f"{ep.OUT}/concat_v2.txt", "w") as f:
        f.writelines(f"file '{c}'\n" for c in clips)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", f"{ep.OUT}/concat_v2.txt",
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-movflags", "+faststart",
                    f"{ep.OUT}/ep2_arcane_14b_v2.mp4"], check=True, timeout=600)
    print("joined:", f"{ep.OUT}/ep2_arcane_14b_v2.mp4", flush=True)


if __name__ == "__main__":
    (join if sys.argv[1:] == ["join"] else render)()
