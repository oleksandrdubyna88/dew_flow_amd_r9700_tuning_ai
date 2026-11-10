"""Episode 2, REALISTIC (live-action look), with all of the owner's v4 fixes (2026-11-09: "episode 2 yes; no re-render of
episode 1"). Same story, shot texts and fixes as the Arcane v4 (ep2_v4.py); the face comes from episode 1's realistic
set-2 keyframes (the character the owner likes best):
  image1 = elf_set2_reroll_s2_seed2202.png (3/4 face, close), image2 = elf_set2_key_s5.png (front face),
  image3 = elf_set2_key_s6.png (whole body, cave) — for shot 7 image3 is the realistic Humvee (series/ep2/key_s8_00002_).
Shot 8 = the realistic Humvee keyframe from behind (no hero); shot 9 starts from shot 8's last frame (camera rises).

Run inside the container:
  wslc exec comfyui python /opt/tests/ep2_real.py keyframes        -> series/ep2_real/key_s<k>_c<n>_*.png (k 1..7)
  wslc exec comfyui python /opt/tests/ep2_real.py pick <k> <n>
  wslc exec comfyui python /opt/tests/ep2_real.py shot <k>          (k 1..9, ONE per call, restart ComfyUI first; 9 after 8)
  wslc exec comfyui python /opt/tests/ep2_real.py join              -> series/ep2_real/ep2_real_14b.mp4
"""
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ep2_edit as e3  # noqa: E402
import ep2_v4 as v4  # noqa: E402
import episode2 as ep  # noqa: E402
from eyes_try import GAZE  # noqa: E402

OUT = "/data/output/series/ep2_real"
REFS = ("elf_set2_reroll_s2_seed2202.png", "elf_set2_key_s5.png", "elf_set2_key_s6.png")
TRUCK = "ep2_real_truck.png"
SAME = ("The same young woman as in image 1 and image 2 — keep her face exactly the same: the same nose, eyes, eyebrows, "
        "lips, jaw and face shape — with the same long silver-white hair and the thin golden strand, wearing the same "
        "dark-green tunic with brown trim, brown belt and bracers as in image 3. Photorealistic cinematic live-action film "
        "still, a real person, natural skin texture, real light, 35mm film look; not a painting, not animation. ")
CLEAR = "Her forehead is smooth and clear, with nothing on it. "
REAL_STYLE = "Photorealistic live-action film, consistent with the first frame."
SCENES = {**{k: e3.SCENES[k] for k in (1, 2, 3, 6)}, **v4.SCENES}
SCENES[7] = SCENES[7].replace("red sunset light", "red sunset light, a real vehicle")
CANDIDATES = {1: (301, 1301), 2: (302, 1302), 3: (303, 1303), 4: (304, 1304), 5: (305, 1305), 6: (306, 1306),
              7: (307, 1307, 2307)}
MOTION = {1: ep.SHOTS[0]["motion"], 2: ("She sleeps peacefully with her eyes CLOSED the whole time, breathing slowly and "
                                         "evenly, her face relaxed and still; the embers glow and fade; a few sparks rise."),
          6: ep.SHOTS[5]["motion"], 8: ep.SHOTS[7]["motion"], **{k: v4.MOTION[k] for k in (3, 4, 5, 7, 9)}}
# the realistic shot 7 is seen from BEHIND (v4's round-2 pick is a front view): the rear lights, not the headlights
# (2026-11-10) the rear-view keyframe put her into the SECOND row (the owner); the new keyframe is a front view of the
# driver's door (keys7), so the headlights stay
# MOTION[7] = MOTION[7].replace("the headlights switch on", "the rear lights glow red")


def keyframes():
    os.makedirs(OUT, exist_ok=True)
    shutil.copyfile(f"{ep.OUT}/key_s8_00002_.png", os.path.join("/data/input", TRUCK))
    for k, seeds in CANDIDATES.items():
        for n, seed in enumerate(seeds, 1):
            if ep.newest(f"{OUT}/key_s{k}_c{n}_*.png"):
                continue
            g = e3.edit_graph(k)
            refs = REFS[:2] + ((TRUCK,) if k == 7 else REFS[2:])
            for i, ref in enumerate(refs, 1):
                g[f"ref{i}"]["inputs"]["image"] = ref
            g["pos"]["inputs"]["prompt"] = SAME + CLEAR + SCENES[k]
            g["sampler"]["inputs"]["seed"] = seed
            g["save"]["inputs"]["filename_prefix"] = f"series/ep2_real/key_s{k}_c{n}"
            secs, _ = ep.story.run(g, 900)
            print(f"real shot {k}: candidate {n} (seed {seed}) {secs:.1f} s", flush=True)


def keys7():
    """Shot 7 again (the owner, 2026-11-10: "she sits down in the second row of seats, but must sit behind the wheel"): the
    method of the Arcane v4 shot 7 the owner accepted — two references (her whole body, the realistic Humvee), the vehicle
    from the front-left three-quarter so the DRIVER's door is the one she climbs through. -> key_s7_c11..c13."""
    import ep2_v4 as v4
    shutil.copyfile(f"{ep.OUT}/key_s8_00002_.png", os.path.join("/data/input", TRUCK))
    shot7 = v4.SHOT7.replace("is seen from behind and from its left side at a three-quarter angle",
                             "is seen from the FRONT-LEFT at a three-quarter angle (the front of the vehicle toward the camera)")
    shot7 = shot7.replace("climbing in through that open door: one boot on the door sill",
                          "climbing in through that open front door to sit BEHIND THE STEERING WHEEL: one boot on the door sill")
    style = ("Photorealistic cinematic live-action film still, a real person, a real vehicle, natural skin texture, real light; "
             "not a painting, not animation.")
    for n, seed in ((11, 7011), (12, 7012), (13, 7013)):
        if ep.newest(f"{OUT}/key_s7_c{n}_*.png"):
            continue
        g = v4.round2_graph(7, seed, (REFS[2], TRUCK), "", f"series/ep2_real/key_s7_c{n}")
        g["pos"]["inputs"]["prompt"] = shot7 + style
        secs, _ = ep.story.run(g, 900)
        print(f"real shot 7: candidate {n} (seed {seed}) {secs:.1f} s", flush=True)


def pick(k, n):
    src = ep.newest(f"{OUT}/key_s{k}_c{n}_*.png")
    shutil.copyfile(src, f"{OUT}/pick_s{k}.png")
    print(f"real shot {k}: candidate {n} picked ({os.path.basename(src)})", flush=True)


def start_image(k):
    if k == 8:
        return f"{ep.OUT}/key_s8_00002_.png"
    if k == 9:
        last = f"{OUT}/last_of_s8.png"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-sseof", "-0.1", "-i", ep.newest(f"{OUT}/clip_s8_*.mp4"),
                        "-frames:v", "1", "-update", "1", last], check=True, timeout=120)
        return last
    return f"{OUT}/pick_s{k}.png"


def shot(k, reroll=False):
    """reroll=True: a second seed (seed + 1000) saved as reroll_s<k>_* (not picked up by join until chosen by eye) — the
    realistic shot 2 opened her eyes while sleeping and shot 6's hair turned dark at the end (2026-11-10)."""
    if not reroll and ep.newest(f"{OUT}/clip_s{k}_*.mp4"):
        print(f"real shot {k}: clip exists", flush=True)
        return
    name = f"ep2_real_s{k}.png"
    shutil.copyfile(start_image(k), os.path.join("/data/input", name))
    no_hero = k in (8, 9)
    ep.story.HERO = "" if no_hero else ep.HERO
    seed = {3: 3303, 9: 309}.get(k, ep.SHOTS[k - 1]["seed"] if k <= 8 else 309) + (1000 if reroll else 0)
    motion = f"{MOTION[k]} {'' if no_hero else GAZE} {REAL_STYLE}"
    wf = ep.story.wan14b_video_wf(k, {"motion": motion, "seed": seed}, name)
    wf["save"]["inputs"]["filename_prefix"] = f"series/ep2_real/{'reroll' if reroll else 'clip'}_s{k}"
    secs, files = ep.story.run(wf, 7200)
    print(f"real shot {k}: clip {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


def join():
    # the owner (2026-11-10) chose the second-seed versions (reroll_s<k>) where they exist
    clips = [ep.newest(f"{OUT}/reroll_s{k}_*.mp4") or ep.newest(f"{OUT}/clip_s{k}_*.mp4") for k in range(1, 10)]
    if not all(clips):
        raise SystemExit(f"missing clips: {clips}")
    with open(f"{OUT}/concat.txt", "w") as f:
        f.writelines(f"file '{c}'\n" for c in clips)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", f"{OUT}/concat.txt",
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-threads", "2", "-movflags", "+faststart",
                    "-color_range", "tv", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709",
                    f"{OUT}/ep2_real_14b.mp4"], check=True, timeout=900)
    print("joined:", f"{OUT}/ep2_real_14b.mp4", flush=True)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "keyframes":
        keyframes()
    elif cmd == "pick":
        pick(int(sys.argv[2]), int(sys.argv[3]))
    elif cmd == "shot":
        shot(int(sys.argv[2]))
    elif cmd == "keys7":
        keys7()
    elif cmd == "reroll":
        shot(int(sys.argv[2]), reroll=True)
    elif cmd == "join":
        join()
