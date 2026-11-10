"""Episode 2, v4: the owner's notes on v3 (2026-11-09), one fix per note.

1. 13 s, shot 3: the right eye half-closes and twists for a few frames (the video model; the keyframe is fine) -> the
   same keyframe, a new seed.
2. 16 s, shot 4: the breath is a big smoke puff, "as if she smokes" -> a keyframe without a breath cloud, and in the motion
   only a faint wisp at each exhale that vanishes at once.
3. 21 s, shot 5: a dark pin in the middle of her forehead, the gold strands start from it -> a keyframe with a clear
   forehead, the strands at the temples (the 16 s strands are right).
4. Shot 7: getting into the car "looks torn apart", she went in through the window -> she steps in through the open
   DRIVER's door; seen from the left rear three-quarter, the side of the driver's door.
5. 34 s is a jeep (a vertical-slot grille), shot 8 a Humvee -> shot 7 shows the vehicle like shot 8 (its rear view is
   image 3), described by its shape; drawn from behind so the jeep grille is not invented.
6. After 41 s the picture stops while the narrator goes on -> a new shot 9 after shot 8: from shot 8's last frame the
   camera rises into the sky and shows the nuclear winter.

Keyframes by Qwen-Image-Edit-2511 with the v3 references (ep2_edit.py), candidates per shot so the best can be picked by
eye before a clip is rendered. Clips by Wan 2.2 A14B + lightx2v, ONE per call on a freshly restarted server (§ 16).
Run inside the container:
  wslc exec comfyui python /opt/tests/ep2_v4.py keyframes          -> series/ep2/v4/key_s<k>_c<n>_*.png
  wslc exec comfyui python /opt/tests/ep2_v4.py pick <k> <n>        -> the candidate used for shot k
  wslc exec comfyui python /opt/tests/ep2_v4.py shot <k>            (k in 3 4 5 7 9) -> series/ep2/v4/clip_s<k>_*.mp4
  wslc exec comfyui python /opt/tests/ep2_v4.py join                -> series/ep2/ep2_arcane_14b_v4.mp4
"""
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ep2_edit as e3  # noqa: E402
import episode2 as ep  # noqa: E402
from eyes_try import GAZE  # noqa: E402

OUT = ep.OUT
V4 = f"{OUT}/v4"
CLEAR = ("Her forehead is smooth and clear, with no mark, no jewel and no pin on it; the two thin golden strands hang down "
         "at both sides of her face from the temples. ")
SCENES = {
    4: "She walks through a dead withered forest of bare black trees under a dark grey sky, grey ash covering the ground "
       "like dirty snow, cold still air; grim cold desaturated colours. No smoke and no breath cloud.",
    5: e3.SCENES[5],
    7: "Rear three-quarter view from the LEFT side, on a ruined cracked road among rusted wrecks at sunset: the SAME "
       "vehicle as in image 3, a wide low boxy military Humvee seen from behind and from its left side (a very wide body, "
       "square tail lights, a canvas-covered back, four doors with square windows), without any logo, dusty with grey "
       "ash. Its front LEFT door, the driver's door, is wide open; she stands beside it with one foot on the door sill and "
       "one hand on the door frame, stepping in through the open door toward the steering wheel. One whole person, "
       "natural body; grim cold colours, red sunset light.",
}
SEEDS = {3: 3303}  # shot 3 keeps its v3 keyframe; only the clip gets a new seed
CANDIDATES = {4: (304, 1304), 5: (305, 1305), 7: (307, 1307, 2307)}
MOTION = {
    # the owner (2026-11-09) on v4 clip 3: "the eyes twitch, close and open" — the blink sentence made her blink again
    # and again; now a steady open gaze
    3: ep.SHOTS[2]["motion"] + " Her eyes stay open with a steady, calm gaze the whole time.",
    4: ("She walks slowly through the dead forest wrapped in her cloak, ash falling; with each exhale only a faint thin "
        "wisp of breath mist appears at her lips and vanishes at once; dead branches sway."),
    5: ep.SHOTS[4]["motion"],
    7: ("She climbs in through the open driver's door: she steps up, sits down behind the steering wheel and pulls the door "
        "shut; then the engine starts with a puff of exhaust and the headlights switch on. Natural human movement, correct "
        "anatomy, her body stays whole, one person."),
    9: ("The camera slowly rises high up into the sky above the road and tilts down: the truck becomes a tiny dot on the "
        "endless road, and the view reveals the horror of the nuclear winter — a vast dead grey wasteland to the horizon, "
        "burned black forests, the ruins of a city, a huge dark column of ash on the horizon, black clouds swallowing the "
        "red sun, grey ash falling. Smooth crane shot."),
}


# Round 2 (the first candidates failed by eye, 2026-11-09): naming the forehead ("no mark, no jewel, no pin") made the
# model DRAW a circlet, a jewel or a pin, and "golden strands from the temples" became wires; the tunic turned black. Shot
# 7 with three references drew her twice or climbing over the back. Round 2 never names the forehead, calls the golden
# strand dyed HAIR, insists on the dark-GREEN tunic, and gives shot 7 only two references (the body, the vehicle).
HAIR = ("Her long silver-white hair is loose; one thin strand of her hair is dyed golden and hangs beside her cheek. Her "
        "tunic is dark GREEN (not black). ")
SHOT7 = ("Image 1 shows the young woman, image 2 shows the vehicle. Draw ONE single scene with exactly one woman in it. The "
         "vehicle from image 2 — a wide low boxy military Humvee, without any logo, dusty with grey ash — is seen from behind "
         "and from its left side at a three-quarter angle, on a ruined cracked road among rusted wrecks at a red sunset. Its "
         "front left door, the driver's door, is open. The woman from image 1 — long silver-white hair, a dark-green tunic, "
         "brown belt, bracers and boots — is climbing in through that open door: one boot on the door sill, one hand on the "
         "door frame, her body half inside the cab. Medium-wide shot: the whole vehicle and the whole woman in frame. ")
ROUND2 = {4: (2304, 3304, 4304, 5304), 5: (2305, 3305, 4305, 5305), 7: (3307, 4307, 5307, 6307)}


def round2_graph(k, seed, refs, style, prefix):
    g = e3.edit_graph(k)
    if k == 7:
        for key in ("ref3", "scale3"):
            g.pop(key)
        for enc in ("pos", "neg"):
            g[enc]["inputs"].pop("image3", None)
        g["pos"]["inputs"]["prompt"] = SHOT7 + style
    else:
        g["pos"]["inputs"]["prompt"] = e3.SAME + HAIR + SCENES.get(k, e3.SCENES[k])
    for i, ref in enumerate(refs, 1):
        g[f"ref{i}"]["inputs"]["image"] = ref
    g["sampler"]["inputs"]["seed"] = seed
    g["save"]["inputs"]["filename_prefix"] = prefix
    return g


def keyframes2():
    arcane = "Same painted Arcane animation style as image 1: painterly textures, cinematic lighting."
    for k, seeds in ROUND2.items():
        refs = ("ep2_ref_body.png", "ep2_ref_truck.png") if k == 7 else \
            tuple(f"ep2_{r}" for r in e3.REFS)
        for n, seed in enumerate(seeds, 3):
            if ep.newest(f"{V4}/key_s{k}_c{n}_*.png"):
                continue
            secs, _ = ep.story.run(round2_graph(k, seed, refs, arcane, f"series/ep2/v4/key_s{k}_c{n}"), 900)
            print(f"shot {k}: round-2 candidate {n} (seed {seed}) {secs:.1f} s", flush=True)


# Round 3: the pin came from the REFERENCES (episode 1's Arcane frames have a small dark pin above the brows; the edit
# model copies it). clean_refs.py fills it with forehead skin (ref_face_clean.png, ref_profile_clean.png). Shot 4's
# "grim cold desaturated colours" turned the tunic black: the cold light now stays on the scene, the green on the tunic.
SCENE4_R3 = ("She walks through a dead withered forest of bare black trees under a dark grey sky, grey ash covering the ground "
             "like dirty snow, cold blue-grey light on the forest; her tunic keeps its dark GREEN colour.")
ROUND3 = {4: (7304, 8304, 9304, 10304), 5: (7305, 8305, 9305, 10305)}


def keyframes3():
    for ref in ("ref_profile_clean.png", "ref_face_clean.png"):
        shutil.copyfile(f"{OUT}/refs/{ref}", os.path.join("/data/input", f"ep2_{ref}"))
    refs = ("ep2_ref_profile_clean.png", "ep2_ref_face_clean.png", "ep2_ref_body.png")
    for k, seeds in ROUND3.items():
        SCENES[4] = SCENE4_R3
        for n, seed in enumerate(seeds, 7):
            if ep.newest(f"{V4}/key_s{k}_c{n}_*.png"):
                continue
            g = round2_graph(k, seed, refs, "", f"series/ep2/v4/key_s{k}_c{n}")
            secs, _ = ep.story.run(g, 900)
            print(f"shot {k}: round-3 candidate {n} (seed {seed}) {secs:.1f} s", flush=True)


# Round 4 (the owner, 2026-11-09): "I want THIS face everywhere in Arcane" — the young face of v3's sleep shot (frames 76
# and 80, eyes open; young_refs.py, the forehead dot filled by clean_refs.py, enlarged crops ref_young_face_a/b.png) —
# "after 10 s she ages ~30 years": the episode-1 references have an older frowning face, and "grim cold desaturated
# colours" aged her and blackened the tunic. All shots 1-6 are drawn again from the young face; shot 7 keeps its pick
# (a small face). The cold mood stays in the light of the scene, never on her.
YOUNG = ("She is a young woman of about twenty, exactly as young as in image 1 and image 2: a youthful smooth face, soft "
         "round cheeks, big eyes. ")
COLD = "cold grey light on the scene; her tunic keeps its dark GREEN colour."


def scene4(k):
    if k == 4:
        return SCENE4_R3
    return e3.SCENES[k].replace("grim cold desaturated colours.", COLD).replace("grim, tense.", "tense, " + COLD)


# the owner: "the first 10 s are all good" — v3 shots 1 and 2 stay; round 4 draws shots 3-6
ROUND4 = {k: (k * 1000 + 11, k * 1000 + 12, k * 1000 + 13) for k in range(3, 7)}


def keyframes4():
    for ref in ("ref_young_face_a.png", "ref_young_face_b.png"):
        shutil.copyfile(f"{OUT}/refs/{ref}", os.path.join("/data/input", f"ep2_{ref}"))
    refs = ("ep2_ref_young_face_a.png", "ep2_ref_young_face_b.png", "ep2_ref_body.png")
    for k, seeds in ROUND4.items():
        for n, seed in enumerate(seeds, 11):
            if ep.newest(f"{V4}/key_s{k}_c{n}_*.png"):
                continue
            g = round2_graph(k, seed, refs, "", f"series/ep2/v4/key_s{k}_c{n}")
            g["pos"]["inputs"]["prompt"] = e3.SAME + YOUNG + HAIR + scene4(k)
            secs, _ = ep.story.run(g, 900)
            print(f"shot {k}: round-4 candidate {n} (seed {seed}) {secs:.1f} s", flush=True)


# Round 5: in round 4 the edit model copied image 1 — the enlarged face crop of her LYING — as the picture (close-ups of
# her lying in every scene; only shot 4 c11 drew the scene). The model builds on image 1, so image 1 is now the whole
# body standing (ep1 Arcane, sets the composition) and the young face comes second and third, for the face only.
SAME5 = ("Draw a NEW scene. The woman is the one from image 1 (her whole body, long silver-white hair, dark-green tunic "
         "with brown trim, brown belt and bracers), and her FACE is exactly the face of image 2 and image 3: a young woman "
         "of about twenty, a youthful smooth face, soft round cheeks, big eyes. Use image 2 and image 3 only for the face; "
         "she is not lying down and it is not a close-up unless the scene says so. Same painted Arcane animation style: "
         "painterly textures, cinematic lighting. ")
ROUND5 = {k: (k * 1000 + 21, k * 1000 + 22, k * 1000 + 23) for k in (3, 5, 6)}


def keyframes5():
    refs = ("ep2_ref_body.png", "ep2_ref_young_face_a.png", "ep2_ref_young_face_b.png")
    for k, seeds in ROUND5.items():
        for n, seed in enumerate(seeds, 21):
            if ep.newest(f"{V4}/key_s{k}_c{n}_*.png"):
                continue
            g = round2_graph(k, seed, refs, "", f"series/ep2/v4/key_s{k}_c{n}")
            g["pos"]["inputs"]["prompt"] = SAME5 + HAIR + scene4(k)
            secs, _ = ep.story.run(g, 900)
            print(f"shot {k}: round-5 candidate {n} (seed {seed}) {secs:.1f} s", flush=True)


def keyframes():
    os.makedirs(V4, exist_ok=True)
    for ref in e3.REFS + ("ref_truck.png",):
        shutil.copyfile(f"{OUT}/refs/{ref}", os.path.join("/data/input", f"ep2_{ref}"))
    for k, seeds in CANDIDATES.items():
        for n, seed in enumerate(seeds, 1):
            if ep.newest(f"{V4}/key_s{k}_c{n}_*.png"):
                continue
            e3.SCENES[k] = SCENES[k]
            g = e3.edit_graph(k)
            g["pos"]["inputs"]["prompt"] = e3.SAME + CLEAR + SCENES[k]
            g["sampler"]["inputs"]["seed"] = seed
            g["save"]["inputs"]["filename_prefix"] = f"series/ep2/v4/key_s{k}_c{n}"
            secs, _ = ep.story.run(g, 900)
            print(f"shot {k}: candidate {n} (seed {seed}) {secs:.1f} s", flush=True)
    # shot 9 starts from shot 8's last frame (the clip kept from v2)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-sseof", "-0.1", "-i", ep.newest(f"{OUT}/clip_s8_*.mp4"),
                    "-frames:v", "1", "-update", "1", f"{V4}/key_s9_c1_last_of_s8.png"], check=True, timeout=120)
    print("shot 9: start frame = the last frame of shot 8", flush=True)


def pick(k, n, name="pick"):
    src = ep.newest(f"{V4}/key_s{k}_c{n}_*.png")
    shutil.copyfile(src, f"{V4}/{name}_s{k}.png")
    print(f"shot {k}: candidate {n} picked ({os.path.basename(src)})", flush=True)


def start_image(k):
    if os.path.exists(f"{V4}/pick4_s{k}.png"):  # round 4 (the young face), shots 1-6
        return f"{V4}/pick4_s{k}.png"
    if k == 3:
        return ep.newest(f"{OUT}/edit/key_s3_*.png")
    if k == 9:
        return f"{V4}/key_s9_c1_last_of_s8.png"
    return f"{V4}/pick_s{k}.png"


def shot(k):
    if ep.newest(f"{V4}/clip_s{k}_*.mp4"):
        print(f"shot {k}: clip exists", flush=True)
        return
    name = f"ep2_v4_s{k}.png"
    shutil.copyfile(start_image(k), os.path.join("/data/input", name))
    ep.story.HERO = "" if k == 9 else ep.HERO  # the video graph appends the hero text; shot 9 has no hero in view
    seed = SEEDS.get(k, ep.SHOTS[k - 1]["seed"] if k <= 8 else 309)
    # shots without a v4 motion fix (1, 2, 6) keep their episode-2 motion (shot 6 failed with KeyError on 2026-11-09)
    motion = f"{MOTION.get(k, ep.SHOTS[k - 1]['motion'])} {'' if k == 9 else GAZE} {ep.ARC_STYLE}"
    wf = ep.story.wan14b_video_wf(k, {"motion": motion, "seed": seed}, name)
    wf["save"]["inputs"]["filename_prefix"] = f"series/ep2/v4/clip_s{k}"
    secs, files = ep.story.run(wf, 7200)
    print(f"shot {k}: clip {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


def join():
    clips = []
    for k in range(1, 10):
        v4 = ep.newest(f"{V4}/clip_s{k}_*.mp4")
        clips.append(v4 or (ep.newest(f"{OUT}/clip_s8_*.mp4") if k == 8 else ep.newest(f"{OUT}/v3/clip_s{k}_*.mp4")))
    if not all(clips):
        raise SystemExit(f"missing clips: {clips}")
    with open(f"{OUT}/concat_v4.txt", "w") as f:
        f.writelines(f"file '{c}'\n" for c in clips)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", f"{OUT}/concat_v4.txt",
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-threads", "2", "-movflags", "+faststart",
                    "-color_range", "tv", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709",
                    f"{OUT}/ep2_arcane_14b_v4.mp4"], check=True, timeout=900)
    print("joined:", f"{OUT}/ep2_arcane_14b_v4.mp4", "from", [os.path.relpath(c, OUT) for c in clips], flush=True)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "keyframes":
        keyframes()
    elif cmd == "keyframes2":
        keyframes2()
    elif cmd == "keyframes3":
        keyframes3()
    elif cmd == "keyframes4":
        keyframes4()
    elif cmd == "keyframes5":
        keyframes5()
    elif cmd == "pick4":
        pick(int(sys.argv[2]), int(sys.argv[3]), "pick4")
    elif cmd == "pick":
        pick(int(sys.argv[2]), int(sys.argv[3]))
    elif cmd == "shot":
        shot(int(sys.argv[2]))
    elif cmd == "join":
        join()
