"""Episode 1 v3 (the owner, 2026-11-10: apply a reviewer's critique — composition, emotion, environment that matches the
narration, the jump without morphing; consultant 229b6310…). Look C like episode 3: the pose from text (Qwen-Image 2512 +
Lightning + slvra_v1 0.5), then the edit model (+ LoRA) keeps the pose and gives her the approved face. Shots where her face
is not seen (2, 6) stay text + LoRA only. Two candidates per shot; ONE shot per call (a fresh server per shot).

Shot per narration line: 1 «В древние времена… случилась беда» wide crane through the dawn forest; 2 «небо покрылось огненными
грибами» extreme wide, her small silhouette from behind on a ridge before a horizon of mushroom clouds; 3 «свет их был ярче
тысячи солнц» tight close-up, terrified, looking OFF-camera, lit by the flash, ash on her face; 4 «Горели леса, кипели реки, и
бежали…» low tracking shot, burning forest, at the apex of a jump, the cloak one solid shape; 5 «Лишь немногие добрались до
гор» a BOILING river (steam, foam, ash) with mountains ahead; 6 «А потом… наступила тишина» from inside the cave through the
waterfall, her exhausted silhouette from behind.
Run inside the comfyui container:  python /opt/tests/ep1_v3.py keys <k>   |   python /opt/tests/ep1_v3.py shot <k> [shift]
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ep3_keys as k3  # noqa: E402
import episode2 as ep  # noqa: E402
from eyes_try import GAZE  # noqa: E402

OUT = "series/elf_set2_arcane/v3"
CLOAK = ("she wears a dark-green tunic with brown trim, a brown belt, brown leather bracers, boots and a long dark-green "
         "cloak. ")
SHOTS = {
    1: ("pose", "Wide low-angle shot through ancient giant trees at dawn, mist between the trunks, soft golden light; she walks "
        "along a forest path in the middle distance, calm, small in the frame. " + CLOAK,
        "Slow crane shot rising through the ancient trees at dawn; mist drifts between the trunks; she walks along the path, "
        "calm; birds fly up."),
    2: ("scene_hero", "Extreme wide shot: her small dark silhouette seen from behind stands on a rocky ridge, her cloak and "
        "silver hair blowing; before her the whole horizon is filled with several colossal fiery mushroom clouds, the sky "
        "burning orange and red from dawn to dusk, ash in the air. " + CLOAK,
        "The mushroom clouds swell and rise on the horizon, the sky flickers orange; ash begins to fall; the wind blows her "
        "cloak and hair; she stands still, small against the fire."),
    3: ("pose", "Tight close-up of her face, three-quarter view, TERRIFIED: eyes wide, looking off-camera up to the right at a "
        "blinding light, lips parted gasping, brow furrowed; a white-orange flash lights her face, smudges of grey ash and soot "
        "on her cheek and forehead, wind-blown strands of silver hair across her face. " + CLOAK,
        "A blinding white-orange flash grows on her face; she flinches and narrows her eyes against the light, both eyes "
        "together; a shockwave wind whips her hair, ash flies past; handheld camera shake."),
    4: ("pose", "Low-angle tracking shot in a BURNING forest: crown fires, thick black smoke, big orange embers in the air; she "
        "is at the apex of a jump over a fallen burning log, leaning forward, front foot already past the log, one hand "
        "clutching her cloak at her chest; the long dark-green cloak billows behind her as one solid shape, clearly darker "
        "than the orange fire behind; profile view, she looks ahead. " + CLOAK,
        "She lands from the jump and sprints on through the burning forest, fast and frantic; embers streak past with motion "
        "blur; the cloak whips behind her; fast handheld tracking camera with shake; flying debris."),
    5: ("pose", "Wide water-level shot of a BOILING river: white foaming rapids, thick clouds of steam rising from the surface, "
        "charred black trees on the banks, grey ash falling, the red sky reflected on the churning water; she climbs over the "
        "wet rocks along the river, three-quarter back view, toward dark mountains ahead. " + CLOAK,
        "Steam billows up from the boiling river, the foam churns, ash falls; she climbs fast over the wet rocks toward the "
        "mountains; the camera follows."),
    6: ("scene_hero", "From inside a dark cave looking out through the shimmering curtain of a waterfall: her exhausted silhouette "
        "seen from behind, kneeling on the wet stone at the cave mouth, catching her breath; cold blue light through the "
        "falling water. " + CLOAK,
        "Behind the waterfall curtain she sinks down, exhausted, breathing hard; the falling water shimmers; the camera holds "
        "still."),
}


def keys(k):
    kind, text, _ = SHOTS[k]
    for n, seed in enumerate((3901, 3902), 1):
        prefix = f"{OUT}/key_s{k}_c{n}"
        if ep.newest(f"/data/output/{prefix}_*.png"):
            continue
        phase = os.environ.get("EP3_PHASE", "")  # "text" / "edit": one big image model per server session (see ep3_keys)
        if kind == "scene_hero":
            if phase == "edit":
                continue
            secs = k3.text_image(text, seed + k * 10, prefix, True)
        else:
            pose_prefix = f"{OUT}/pose/s{k}_c{n}"
            secs = 0.0
            if phase != "edit" and not ep.newest(f"/data/output/{pose_prefix}_*.png"):
                secs = k3.text_image(text, seed + k * 10, pose_prefix, True)
            if phase == "text":
                print(f"ep1 v3 pose s{k} c{n}: {secs:.1f} s", flush=True)
                continue
            pose = f"ep1v3_pose_s{k}_c{n}.png"
            shutil.copyfile(ep.newest(f"/data/output/{pose_prefix}_*.png"), f"/data/input/{pose}")
            prompt = ("Image 1 is the picture to keep: the same scene, the same pose, expression and body, the same camera and "
                      "light. Exactly one woman in the picture; do not add any person. Her FACE becomes exactly the face of "
                      "image 2 — young, about twenty, soft round cheeks, big eyes, the silver hair with one thin golden strand; "
                      "her clothes as in image 1. " + k3.v4.HAIR + "Painted Arcane animation style.")
            secs += k3.edit_image((pose, "ep2_ref_young_face_a.png", "ep2_ref_young_face_b.png"), prompt, seed + k * 10,
                                  prefix, True)
        print(f"ep1 v3 key s{k} c{n} ({kind}): {secs:.1f} s", flush=True)


def shot(k, shift=None, label=""):
    """The clip from the picked keyframe v3/pick_s<k>.png (4 steps; seed per label; optional Wan shift, default 5)."""
    story = ep.story
    _, _, motion = SHOTS[k]
    name = f"ep1v3_s{k}.png"
    # 2026-11-12 the owner picked the adult face s1face/full/s1_r2_a75.png for s1: EP1_PICK = another start picture
    # (pick_s<k>.png stays as it is — append-only)
    shutil.copyfile(os.environ.get("EP1_PICK") or f"/data/output/{OUT}/pick_s{k}.png", os.path.join("/data/input", name))
    # 2026-11-10: HERO_V5 says "small round human ears with only a tiny point" (the owner: ordinary ears, never pointed)
    # -> episode 3's tunic text, which names no ears (positive words only)
    from ep3_clips import HERO_T
    story.HERO = "" if k in (2, 6) else HERO_T
    seed = 3900 + k + (1000 if label == "b" else 0)
    wf = story.wan14b_video_wf(k, {"motion": f"{motion} {'' if k in (2, 6) else GAZE} {k3.v4.ep.ARC_STYLE}",
                                   "seed": seed}, name)
    if shift:
        wf["shift_hi"]["inputs"]["shift"] = shift
        wf["shift_lo"]["inputs"]["shift"] = shift
    tag = f"_shift{int(shift)}" if shift else ""
    wf["save"]["inputs"]["filename_prefix"] = f"{OUT}/clip_s{k}{label}{tag}"
    secs, files = story.run(wf, 7200)
    print(f"ep1 v3 shot {k}: clip {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


if __name__ == "__main__":
    if sys.argv[1] == "keys":
        keys(int(sys.argv[2]))
    elif sys.argv[1] == "shot":
        shot(int(sys.argv[2]), float(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] != "-" else None,
             sys.argv[4] if len(sys.argv) > 4 else "")
