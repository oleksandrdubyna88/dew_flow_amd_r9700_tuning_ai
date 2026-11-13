"""Episode 2 v6 (the owner, 2026-11-10 ~23:45: "redo e1 and e2 in the same spirit" as episode 3): the same 8 narrator
lines (tts/ep2/vox_n1..n8) and 9 shots, a NEW shot list after two consultants (consult 00776266…): no compound actions,
the keyframe already holds the final pose/eye state, no door-opening or climbing (s7), no return-to-cave jump (s4-s6),
the sleep lands on «сон» (s1), the warm light drains to cold on «умирал» (s2). Look C like episode 3: the pose from text
(Qwen-Image 2512 + Lightning + slvra_v1 0.5), then — where her face is seen — the edit model gives her the approved young
face (images 2-3). Positive words only. Two candidates per shot.
Run inside the comfyui container:  python /opt/tests/ep2_v6.py keys <k>   (EP3_PHASE=text|edit as in ep3_keys)
                                   python /opt/tests/ep2_v6.py shot <k> [label]
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ep3_keys as k3  # noqa: E402
import episode2 as ep  # noqa: E402
from ep3_clips import HERO_T  # noqa: E402
from eyes_try import GAZE  # noqa: E402

OUT = "series/ep2/v6"
CLOAK = ("she wears a dark-green tunic with brown trim, a brown belt, brown leather bracers, boots and a long dark-green "
         "cloak. ")
CAR = ("an old wide low boxy military Humvee with a flat hood and square headlights, without any logo, dusty with grey ash")
CAR_BACK = ("an old wide low boxy military Humvee seen from behind: its square rear, a spare wheel on the back, two small red "
            "tail lights, without any logo, dusty with grey ash")
STYLE = "Arcane style painted animation, consistent with the first frame."
# shot: (kind, keyframe text, motion text, eyes seen?) ; kind: face = pose + the face step; hero = pose only (her face is
# not seen); scene = no hero
SHOTS = {
    1: ("hero", "Wide shot inside a dry cave behind a waterfall: she lies curled on a bedroll of furs beside a small "
        "campfire, wrapped in her long dark-green cloak, her head resting, seen from behind and a little to the side; "
        "warm orange firelight on the cloak and the stone, the falling water a glowing blue curtain behind. " + CLOAK,
        "The waterfall curtain flows and shimmers behind; the firelight flickers over her cloak; she lies still, "
        "resting, her shoulder rising slowly with each breath.", False),
    2: ("face", "Close-up of her sleeping face in the lower left of the frame, resting on dark furs, eyelids fully closed "
        "and relaxed, a peaceful face; dying embers glow in the soft foreground; warm orange light on her cheek, cold "
        "blue light from the cave behind. " + CLOAK,
        "Her eyes stay closed in deep peaceful sleep, slow calm breathing; the embers fade, the warm light on her cheek "
        "slowly gives way to cold grey-blue shadow; one grey flake of ash drifts down past her face.", False),
    3: ("hero", "Extreme wide shot from behind: her small dark silhouette stands at the mouth of a cave high above a "
        "wide valley of forests; a colossal wall of black clouds rolls in from the north over the valley and is about "
        "to swallow a low pale sun. " + CLOAK,
        "The wall of black clouds rolls across the sky and swallows the sun; the light over the valley dies to cold "
        "slate grey; she stands still; the camera holds.", False),
    4: ("hero", "Close shot from behind her shoulder: her silver hair with one thin golden strand, her dark-green cloak "
        "and her brown leather bracer; her open hand is held out palm up; thick grey ash falls like snow and lies "
        "unmelted on the wool of her cloak and on her palm; dead black pine branches behind, cold grey light. " + CLOAK,
        "Grey ash falls slowly like snow and gathers on her cloak and on her open palm without melting; she stands "
        "still; a few dead branches sway behind.", False),
    5: ("face", "Low tense shot: in the close foreground she crouches hidden behind a fallen dead tree, her face in sharp "
        "profile, eyes wide with fear, one hand pressed to her mouth; behind the trunk, in the dark dead thicket, two "
        "gaunt wolves with patchy grey fur and pale glowing eyes stand still, sniffing the air; ash in the air. " + CLOAK,
        "In the thicket behind, the two wolves slowly raise their heads and sniff the air, their pale eyes glowing, a "
        "breath of mist at their jaws; she stays perfectly still, holding her breath; ash drifts.", True),
    6: ("hero", "Medium-wide shot from behind and a little to the side: she walks away from the dark mouth of the cave "
        "down a rocky path, in mid-stride, a packed leather bag already slung across her back, her cloak swinging; the "
        "cave with the dead cold fireplace behind her; a grey dead valley ahead under a dark sky. " + CLOAK,
        "She walks steadily away down the rocky path toward the grey valley, her cloak swinging with each step; the "
        "camera follows slowly from behind; ash drifts.", False),
    7: ("hero", "Wide shot on a ruined cracked road among rusted car wrecks covered in grey ash: she stands, seen from "
        "behind and a little to the side, before " + CAR + "; its driver's door already stands open; she reaches one "
        "hand to the door frame. " + CLOAK,
        "Ash swirls around the tyres and the rusted wrecks; her cloak moves in the wind; she rests her hand on the door "
        "frame and looks at the vehicle; the camera slowly pushes in.", False),
    # 8, 9 (set 2, 2026-11-11): set 1 drew the vehicle's FRONT driving at the camera — "headlights" was named (in CAR
    # and in the shot), the same lesson as episode 3 shot 1 -> CAR_BACK names only the back (positive words)
    8: ("scene", "Low shot from BEHIND the vehicle: " + CAR_BACK + ", bursting away from the camera out of the shadow of "
        "rusted wrecks along a cracked road, grey ash and dust kicking up from its rear tyres; far ahead, beyond the "
        "vehicle, a narrow crimson-gold sunset breaks through a split in black clouds.",
        "The vehicle accelerates away from the camera along the cracked road toward the narrow sunset, dust and ash "
        "billowing behind it; the camera holds low.", False),
    9: ("scene", "High aerial view from behind and above: an endless straight road through a dead grey wasteland leads "
        "to a thin red line of sunset on the far horizon under black clouds; " + CAR_BACK + " is a tiny dot far down "
        "the road, driving away toward the horizon, a thin plume of dust behind it; the warm light reflected on the road.",
        "The camera rises slowly higher; the tiny vehicle moves along the road toward the red horizon, its dust plume "
        "trailing; the clouds drift.", False),
}
SEEDS = (4211, 4212) if os.environ.get("EP2V6_SET") == "2" else (4201, 4202)
C0 = 2 if os.environ.get("EP2V6_SET") == "2" else 0  # set 2 = candidates c3, c4


def keys(k):
    kind, text, _, _ = SHOTS[k]
    phase = os.environ.get("EP3_PHASE", "")
    for n, seed in enumerate(SEEDS, 1 + C0):
        prefix = f"{OUT}/key_s{k}_c{n}"
        if ep.newest(f"/data/output/{prefix}_*.png"):
            continue
        secs = 0.0
        if kind in ("hero", "scene"):
            if phase == "edit":
                continue
            secs = k3.text_image(text, seed + k * 10, prefix, kind == "hero")
        else:
            pose_prefix = f"{OUT}/pose/s{k}_c{n}"
            if phase != "edit" and not ep.newest(f"/data/output/{pose_prefix}_*.png"):
                secs = k3.text_image(text, seed + k * 10, pose_prefix, True)
            if phase == "text":
                print(f"ep2 v6 pose s{k} c{n}: {secs:.1f} s", flush=True)
                continue
            pose = f"ep2v6_pose_s{k}_c{n}.png"
            shutil.copyfile(ep.newest(f"/data/output/{pose_prefix}_*.png"), f"/data/input/{pose}")
            prompt = ("Image 1 is the picture to keep: the same scene, the same pose, expression and body, the same camera "
                      "and light. Exactly one woman in the picture; do not add any person. Her FACE becomes exactly the "
                      "face of image 2 — young, about twenty, soft round cheeks, big eyes, the silver hair with one thin "
                      "golden strand; her clothes as in image 1. " + k3.HAIR_ONLY + "Painted Arcane animation style.")
            secs += k3.edit_image((pose, "ep2_ref_young_face_a.png", "ep2_ref_young_face_b.png"), prompt, seed + k * 10,
                                  prefix, True)
        print(f"ep2 v6 key s{k} c{n} ({kind}): {secs:.1f} s", flush=True)


def shot(k, label=""):
    story = ep.story
    kind, _, motion, eyes = SHOTS[k]
    name = f"ep2v6_s{k}.png"
    shutil.copyfile(f"/data/output/{OUT}/pick_s{k}.png", os.path.join("/data/input", name))
    story.HERO = "" if kind == "scene" else HERO_T
    seed = 4200 + k + (1000 if label == "b" else 0)
    wf = story.wan14b_video_wf(k, {"motion": f"{motion} {GAZE if eyes else ''} {STYLE}", "seed": seed}, name)
    wf["save"]["inputs"]["filename_prefix"] = f"{OUT}/clip_s{k}{label}"
    secs, files = story.run(wf, 7200)
    print(f"ep2 v6 shot {k}{label}: {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


if __name__ == "__main__":
    if sys.argv[1] == "keys":
        for a in sys.argv[2:]:
            keys(int(a))
    elif sys.argv[1] == "shot":
        shot(int(sys.argv[2]), sys.argv[3] if len(sys.argv) > 3 else "")
