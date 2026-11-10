"""Episodes 1 and 2 (Arcane) with the young face the owner approved (2026-11-09: "ep2_v4_test_shots124 — exactly what is
needed; re-render episodes 1 and 2 with this face").

The approved face: v3's sleep shot, frames 76 and 80 (refs/ref_young_face_a.png, ref_young_face_b.png; young_refs.py,
the forehead dot filled by clean_refs.py). A FACE SWAP keeps each existing keyframe: Qwen-Image-Edit-2511 gets the old
keyframe as image 1 (the scene, pose, clothes, camera and light to keep) and the young face as images 2 and 3, and is told
to change only the face. Episode 1: the six Arcane keyframes of the 14B film (key_s<k>_l100_d55). Episode 2: shots 3, 5,
6 from v3's keyframes and shot 7 from v4's pick; its shots 1-2 (v3) and 4 (the approved test) stay.

Run inside the container:
  wslc exec comfyui python /opt/tests/young_face.py keys <ep1|ep2>      -> candidates c31, c32 per shot
  wslc exec comfyui python /opt/tests/young_face.py pick ep1 <k> <n>    -> series/elf_set2_arcane/young/pick_s<k>.png
      (episode 2 picks: ep2_v4.py pick4 <k> <n>, which ep2_v4.py shot uses)
  wslc exec comfyui python /opt/tests/young_face.py shot ep1 <k>        (ONE clip per call, restart ComfyUI first)
  wslc exec comfyui python /opt/tests/young_face.py join ep1           -> series/elf_set2_arcane/elf_set2_arcane_14b_30s_young.mp4
"""
import glob
import os
import shutil
import subprocess
import sys

os.environ.setdefault("SERIES", "elf_v5")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ep2_edit as e3  # noqa: E402
import episode2 as ep  # noqa: E402
from eyes_try import GAZE, STYLE  # noqa: E402

EP1 = "/data/output/series/elf_set2_arcane"
YOUNG1 = f"{EP1}/young"
V4 = f"{ep.OUT}/v4"
FACES = ("ep2_ref_young_face_a.png", "ep2_ref_young_face_b.png")
SWAP = ("Image 1 is the picture to keep. Redraw image 1 exactly: the same scene, the same pose and body, the same clothes, "
        "the same camera, framing and light. Change ONLY her face: it becomes the face of image 2 and image 3, a young "
        "woman of about twenty with a youthful smooth face, soft round cheeks and big eyes. Same painted Arcane animation "
        "style as image 1.")
SEEDS = (31, 32)


def newest(pattern):
    found = sorted(glob.glob(pattern))
    return found[-1] if found else None


def sources(episode):
    if episode == "ep1":
        return {k: newest(f"{EP1}/key_s{k}_l100_d55_*.png") for k in range(1, 7)}
    return {3: newest(f"{ep.OUT}/edit/key_s3_*.png"), 5: newest(f"{ep.OUT}/edit/key_s5_*.png"),
            6: newest(f"{ep.OUT}/edit/key_s6_*.png"), 7: f"{V4}/pick_s7.png"}


def keys(episode):
    out_dir, prefix = (YOUNG1, "series/elf_set2_arcane/young") if episode == "ep1" else (V4, "series/ep2/v4")
    os.makedirs(out_dir, exist_ok=True)
    for ref in ("ref_young_face_a.png", "ref_young_face_b.png"):
        shutil.copyfile(f"{ep.OUT}/refs/{ref}", os.path.join("/data/input", f"ep2_{ref}"))
    for k, src in sources(episode).items():
        name = f"young_src_{episode}_s{k}.png"
        shutil.copyfile(src, os.path.join("/data/input", name))
        for n in SEEDS:
            if newest(f"{out_dir}/key_s{k}_c{n}_*.png"):
                continue
            g = e3.edit_graph(min(k, 7))
            for i, ref in enumerate((name,) + FACES, 1):
                g[f"ref{i}"]["inputs"]["image"] = ref
            g["pos"]["inputs"]["prompt"] = SWAP
            g["sampler"]["inputs"]["seed"] = k * 100 + n
            g["save"]["inputs"]["filename_prefix"] = f"{prefix}/key_s{k}_c{n}"
            secs, _ = ep.story.run(g, 900)
            print(f"{episode} shot {k}: face-swap candidate {n} {secs:.1f} s", flush=True)


def keys5_ep1():
    """The face swap failed by eye (extra people, cartoon faces; 2026-11-09). Episode 1 is drawn like the approved ep2
    shot 4 (ep2_v4.py round 5): the scene from its text, image 1 = the standing body, images 2-3 = the young face."""
    import ep2_v4 as v4
    story = ep.story
    os.makedirs(YOUNG1, exist_ok=True)
    refs = ("ep2_ref_body.png",) + FACES
    for k in range(1, 7):
        scene = story.SHOTS[k - 1]["key"].replace(story.STYLE_V2, "").replace(story.HERO, "the young woman").strip()
        for n in (21, 22, 23):
            if newest(f"{YOUNG1}/key_s{k}_c{n}_*.png"):
                continue
            g = v4.round2_graph(min(k, 6), k * 1000 + n, refs, "", f"series/elf_set2_arcane/young/key_s{k}_c{n}")
            g["pos"]["inputs"]["prompt"] = v4.SAME5 + v4.HAIR + scene
            secs, _ = story.run(g, 900)
            print(f"ep1 shot {k}: round-5 candidate {n} {secs:.1f} s", flush=True)


def keys6(episode):
    """Round 6: round 5's faces were right, but the tunic came out black, the body reference (ep1 at the cave waterfall)
    leaked a waterfall into other scenes, and ep1 shot 6 drew two women. Image 1 is now the APPROVED keyframe (ep2 v4
    shot 4: the young face, the green tunic, the whole body), with its background excluded in words."""
    import ep2_v4 as v4
    story = ep.story
    shutil.copyfile(f"{V4}/pick4_s4.png", "/data/input/young_body_ref.png")
    refs = ("young_body_ref.png",) + FACES
    keep = ("Her tunic is dark GREEN exactly as in image 1. Take only the woman from image 1, not its background. "
            "Exactly one woman in the picture. ")
    if episode == "ep1":
        shots = {k: story.SHOTS[k - 1]["key"].replace(story.STYLE_V2, "").replace(story.HERO, "the young woman").strip()
                 for k in range(1, 7)}
        out, prefix = YOUNG1, "series/elf_set2_arcane/young"
    else:
        shots = {k: v4.scene4(k) for k in (3, 5, 6)}
        out, prefix = V4, "series/ep2/v4"
    for k, scene in shots.items():
        for n in (41, 42, 43):
            if newest(f"{out}/key_s{k}_c{n}_*.png"):
                continue
            g = v4.round2_graph(min(k, 6), k * 1000 + n, refs, "", f"{prefix}/key_s{k}_c{n}")
            g["pos"]["inputs"]["prompt"] = v4.SAME5 + v4.HAIR + keep + scene
            secs, _ = story.run(g, 900)
            print(f"{episode} shot {k}: round-6 candidate {n} {secs:.1f} s", flush=True)


def keys7_ep1():
    """Round 7, episode 1 only: round 6 was right for ep2, but ep1's tunic stayed black and image 1's winter (snow, night
    light) leaked into ep1, a SUMMER day in a green forest. The season and the light are now said in the text."""
    import ep2_v4 as v4
    story = ep.story
    shutil.copyfile(f"{V4}/pick4_s4.png", "/data/input/young_body_ref.png")
    refs = ("young_body_ref.png",) + FACES
    keep = ("Her tunic is dark GREEN exactly as in image 1. Take only the woman from image 1, not its background, not its "
            "snow and not its light. Exactly one woman in the picture. A warm SUMMER day: a lush green living forest, "
            "bright natural daylight, no snow anywhere. ")
    for k in range(1, 7):
        scene = story.SHOTS[k - 1]["key"].replace(story.STYLE_V2, "").replace(story.HERO, "the young woman").strip()
        for n in (51, 52):
            if newest(f"{YOUNG1}/key_s{k}_c{n}_*.png"):
                continue
            g = v4.round2_graph(min(k, 6), k * 1000 + n, refs, "", f"series/elf_set2_arcane/young/key_s{k}_c{n}")
            g["pos"]["inputs"]["prompt"] = v4.SAME5 + v4.HAIR + keep + scene
            secs, _ = story.run(g, 900)
            print(f"ep1 shot {k}: round-7 candidate {n} {secs:.1f} s", flush=True)


PORTRAITS = [
    ("front", "a close-up portrait, facing the camera, calm face"),
    ("three_quarter_left", "a close-up portrait, her head turned three-quarters to the left"),
    ("three_quarter_right", "a close-up portrait, her head turned three-quarters to the right"),
    ("profile_left", "a close-up portrait in profile, facing left"),
    ("smile", "a close-up portrait, a soft small smile"),
    ("worried", "a close-up portrait, a worried face, eyes wide"),
    ("determined", "a close-up portrait, a determined face, slightly frowning"),
    ("look_up", "a close-up portrait, looking up at the sky"),
    ("half_body_forest", "a half-body portrait in a green summer forest, daylight"),
    ("half_body_fire", "a half-body portrait at night lit by a campfire"),
]


def portraits():
    """Close-ups for the LoRA dataset (a LoRA learns a face from close-ups; the first 22 pictures are mostly medium and wide
    shots). Image 1 = the approved ep2 v4 shot 4 keyframe, images 2-3 = the young face; written straight into the dataset
    folder with captions (lora_dataset.py's trigger and look)."""
    import ep2_v4 as v4
    import lora_dataset as ds
    story = ep.story
    shutil.copyfile(f"{V4}/pick4_s4.png", "/data/input/young_body_ref.png")
    refs = ("young_body_ref.png",) + FACES
    for i, (name, view) in enumerate(PORTRAITS, 101):
        dst = f"{ds.OUT}/{i:03d}_portrait_{name}.png"
        if os.path.exists(dst):
            continue
        g = v4.round2_graph(4, 9000 + i, refs, "", f"lora/tmp/portrait_{name}")
        g["pos"]["inputs"]["prompt"] = (v4.SAME5 + v4.HAIR + "Take only the woman from image 1, not its background. Exactly "
                                        f"one woman. {view}.")
        g["latent"]["inputs"].update({"width": 1024, "height": 1024})
        secs, files = story.run(g, 900)
        src = newest(f"/data/output/lora/tmp/portrait_{name}_*.png")
        shutil.copyfile(src, dst)
        with open(dst[:-4] + ".txt", "w") as f:
            f.write(f"{ds.TRIGGER}, {ds.LOOK}, {view}, {ds.STYLE}")
        print(f"portrait {name}: {secs:.1f} s -> {os.path.basename(dst)}", flush=True)


def pick(k, n):
    src = newest(f"{YOUNG1}/key_s{k}_c{n}_*.png")
    shutil.copyfile(src, f"{YOUNG1}/pick_s{k}.png")
    print(f"ep1 shot {k}: candidate {n} picked ({os.path.basename(src)})", flush=True)


def shot(k):
    """Episode 1, as arcane14b.py made it (the same motion, gaze words, seed), from the young-face keyframe."""
    if newest(f"{YOUNG1}/clip_s{k}_*.mp4"):
        print(f"ep1 shot {k}: clip exists", flush=True)
        return
    story = ep.story
    s = story.SHOTS[k - 1]
    name = f"young_ep1_s{k}.png"
    shutil.copyfile(f"{YOUNG1}/pick_s{k}.png", os.path.join("/data/input", name))
    motion = f"{s['motion'].replace(story.STYLE_V2, '').strip()} {GAZE} {STYLE}"
    wf = story.wan14b_video_wf(k, dict(s, motion=motion), name)
    wf["save"]["inputs"]["filename_prefix"] = f"series/elf_set2_arcane/young/clip_s{k}"
    secs, files = story.run(wf, 7200)
    print(f"ep1 shot {k}: clip {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


EYES = ("Her eyes stay perfectly steady, clear and symmetric the whole time: both eyes look in the same direction and move "
        "together smoothly, the irises keep their shape and size.")


def eyetest(k, label):
    """The owner (2026-11-09): "the eyes still jump sometimes; the eyes are the main thing, they must be flawless".
    Episode 1 shot k again from the same young-face keyframe, three ways: A = a new seed (4 steps); B = the same seed with
    8 sampling steps (4 high-noise + 4 low-noise; lightx2v kept); C = B + the EYES sentence. -> young/eyetest_<label>_s<k>."""
    story = ep.story
    s = story.SHOTS[k - 1]
    name = f"young_ep1_s{k}.png"
    shutil.copyfile(f"{YOUNG1}/pick_s{k}.png", os.path.join("/data/input", name))
    motion = f"{s['motion'].replace(story.STYLE_V2, '').strip()} {GAZE} {STYLE}"
    seed = s["seed"]
    if label == "A":
        seed += 1000
    if label == "C":
        motion = f"{motion} {EYES}"
    wf = story.wan14b_video_wf(k, dict(s, motion=motion, seed=seed), name)
    if label in ("B", "C"):
        wf["s_hi"]["inputs"].update({"steps": 8, "end_at_step": 4})
        wf["s_lo"]["inputs"].update({"steps": 8, "start_at_step": 4})
    wf["save"]["inputs"]["filename_prefix"] = f"series/elf_set2_arcane/young/eyetest_{label}_s{k}"
    secs, files = story.run(wf, 7200)
    print(f"eyetest {label} shot {k}: clip {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


def join():
    # the owner (2026-11-10) chose the new-seed versions (eyetest A) of all six shots for the eyes
    clips = [newest(f"{YOUNG1}/eyetest_A_s{k}_*.mp4") or newest(f"{YOUNG1}/clip_s{k}_*.mp4") for k in range(1, 7)]
    if not all(clips):
        raise SystemExit(f"missing clips: {clips}")
    with open(f"{YOUNG1}/concat.txt", "w") as f:
        f.writelines(f"file '{c}'\n" for c in clips)
    dest = f"{EP1}/elf_set2_arcane_14b_30s_young.mp4"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", f"{YOUNG1}/concat.txt",
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-threads", "2", "-movflags", "+faststart",
                    "-color_range", "tv", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", dest],
                   check=True, timeout=900)
    print("joined:", dest, flush=True)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "keys":
        keys(sys.argv[2])
    elif cmd == "keys5":
        keys5_ep1()
    elif cmd == "keys6":
        keys6(sys.argv[2])
    elif cmd == "keys7":
        keys7_ep1()
    elif cmd == "portraits":
        portraits()
    elif cmd == "eyetest":  # eyetest <k> <A|B|C>
        eyetest(int(sys.argv[2]), sys.argv[3])
    elif cmd == "pick":
        pick(int(sys.argv[3]), int(sys.argv[4]))
    elif cmd == "shot":
        shot(int(sys.argv[3]))
    elif cmd == "join":
        join()
