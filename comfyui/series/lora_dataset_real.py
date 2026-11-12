"""The REALISTIC character LoRA dataset (the owner, 2026-11-10: "all 3 episodes realistic too, with new LoRAs"; at night:
"then render the LoRAs for realism, and render the first episode"). One LoRA with separate trigger phrases, so later
episodes call each part: slvrareal (her realistic face — the set-2 character the owner likes best), tunicoutfit (the
dark-green tunic), furoutfit (the episode 3 s15 costume), silversword (the s09 sword).
Sources: the realistic set-2 keyframes and clip frames (episode 1 realistic, the tunic), the approved realistic episode 2
picks and clip frames (the tunic), and NEW realistic pictures of the fur costume and the sword: a realistic pose from
text (Qwen-Image 2512 + Lightning, NO Arcane LoRA, a photo style), then the edit model gives her the realistic face of
the set-2 references (images 2-3). Positive words only. Every picture is checked by eye on a sheet before training.
Run:  python /opt/tests/lora_dataset_real.py gen        (inside comfyui; EP3_PHASE=text|edit for one model per session)
      python3 /opt/tests/lora_dataset_real.py collect   (any container with ffmpeg) -> /data/output/lora/slvrareal
"""
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

OUT = "/data/output/lora/slvrareal"
GEN = "lora/real_gen"
S2 = "/data/output/series/elf_set2"
R2 = "/data/output/series/ep2_real"
REAL = "cinematic film still, natural light, photorealistic, highly detailed, 35mm, shallow depth of field"
FACE = ("a young woman of about twenty with long straight silver-white hair and one thin golden strand, a soft young "
        "face, big eyes, her long hair falling over the sides of her head")
TUNIC = "tunicoutfit, a dark-green tunic with brown trim, a brown belt, brown leather bracers"
FUR = ("furoutfit, a sleeveless grey wool crop top, a short skirt of brown fur panels on a wide brown leather belt, brown "
       "thigh-high boots with thick fur cuffs, brown leather bracers, bare arms")
SWORD = ("silversword, a longsword with a dark steel hilt, a curved crossguard whose two arms bend toward the blade, a "
         "long dark grip, a dark pommel and a straight blade with a dark engraved fuller")
# (name, outfit, sword?, scene) — the new realistic pictures
NEW = [
    ("fur_front", FUR, False, "standing in a stone castle courtyard at dawn, full body, front view, calm face"),
    ("fur_threequarter", FUR, False, "three-quarter view, standing by a castle wall at sunrise, hands on her belt"),
    ("fur_run", FUR, False, "running along the top of a castle wall at sunrise, side view, full body"),
    ("fur_pushup", FUR, False, "doing a push-up on a stone floor in torchlight, low side view, full body"),
    ("fur_fire", FUR, False, "sitting on a bear-skin rug by a small campfire in a forest at night, three-quarter view"),
    ("fur_back", FUR, False, "seen from behind, full body, walking into a moonlit forest glade"),
    ("fur_closeup", FUR, False, "medium close-up of her face and bare shoulders, warm firelight, calm"),
    ("fur_sword", FUR, True, "holding the sword in a fighting stance in a castle yard at dawn, full body"),
    ("tunic_sword_up", TUNIC, True, "holding the sword upright before her, medium shot, a vaulted stone hall, light beams"),
    ("tunic_sword_altar", TUNIC, True, "her hand on the grip of the sword lying on a stone altar, medium shot, a dim hall"),
    ("tunic_sword_walk", TUNIC, True, "walking with the sword at her side through a dead grey forest, full body"),
    ("tunic_cloak", TUNIC, False, "standing on a rocky ridge in a long dark-green cloak, wind in her hair, medium shot"),
]
# (name, source, frame or None, outfit, scene) — the realistic pictures that exist (episode 1 set-2, realistic ep 2)
OLD = [
    ("s2ref_a", f"{S2}/reroll/key_s2_seed2202_00001_.png", None, TUNIC, "close three-quarter view of her face"),
    ("s2key1", f"{S2}/key_s1_00001_.png", None, TUNIC, "walking on a forest path at dawn"),
    ("s2key3", f"{S2}/key_s3_00001_.png", None, TUNIC, "in a burning forest"),
    ("s2key4", f"{S2}/key_s4_00001_.png", None, TUNIC, "in a burning forest, running"),
    ("s2key5", f"{S2}/key_s5_00001_.png", None, TUNIC, "front view of her face"),
    ("s2key6", f"{S2}/key_s6_00001_.png", None, TUNIC, "whole body in a cave"),
    ("s2c1_f40", f"{S2}/clip_s1_00001_.mp4", 40, TUNIC, "walking through a forest"),
    ("s2r2_f40", f"{S2}/reroll/clip_s2_seed2202_00001_.mp4", 40, TUNIC, "close view of her face, worried"),
    ("s2c5_f40", f"{S2}/clip_s5_00001_.mp4", 40, TUNIC, "climbing by a river"),
    ("r2p1", f"{R2}/pick_s1.png", None, TUNIC, "kneeling by a campfire in a cave behind a waterfall"),
    ("r2p2", f"{R2}/pick_s2.png", None, TUNIC, "lying on a fur bedroll by a campfire"),
    ("r2p3", f"{R2}/pick_s3.png", None, TUNIC, "standing under black storm clouds"),
    ("r2p4", f"{R2}/pick_s4.png", None, TUNIC, "walking through a dead winter forest, grey ash falling"),
    ("r2p5", f"{R2}/pick_s5.png", None, TUNIC, "hiding behind a fallen tree, wolves behind her"),
    ("r2p6", f"{R2}/pick_s6.png", None, TUNIC, "at a cave entrance with a leather bag on her shoulder"),
    ("r2p7", f"{R2}/pick_s7.png", None, TUNIC, "climbing into an old military truck on a ruined road"),
    ("r2c1_f60", f"{R2}/clip_s1_00001_.mp4", 60, TUNIC, "by a campfire in a cave, firelight on her face"),
    ("r2c3_f40", f"{R2}/clip_s3_00001_.mp4", 40, TUNIC, "standing under black storm clouds, cloak in the wind"),
    ("r2c4_f60", f"{R2}/clip_s4_00001_.mp4", 60, TUNIC, "walking through a dead forest"),
    ("r2c5_f40", f"{R2}/clip_s5_00001_.mp4", 40, TUNIC, "crouching behind a fallen tree"),
    ("r2r6_f40", f"{R2}/reroll_s6_00001_.mp4", 40, TUNIC, "at a cave entrance, determined"),
]
SEEDS = (4301,)


def caption(outfit, sword, scene, identity=True):
    """identity=False for the NEW pictures (2026-11-11 00:35): their faces are the pose step's realistic young women, not
    her exact set-2 face, so they teach only the outfit/sword triggers; her identity trigger comes from the OLD pictures."""
    hair = "a young woman of about twenty with long straight silver-white hair and one thin golden strand"
    s = f"slvrareal, {FACE}, wearing {outfit}" if identity else f"{hair}, wearing {outfit}"
    if sword:
        s += f", holding {SWORD}"
    return f"{s}, {scene}, {REAL}"


def gen():
    import ep3_keys as k3
    import episode2 as ep
    story = ep.story
    phase = os.environ.get("EP3_PHASE", "")
    for ref, src in (("real_ref_a.png", f"{S2}/reroll/key_s2_seed2202_00001_.png"), ("real_ref_b.png", f"{S2}/key_s5_00001_.png")):
        shutil.copyfile(src, f"/data/input/{ref}")
    for i, (name, outfit, sword, scene) in enumerate(NEW):
        seed = SEEDS[0] + i * 7
        pose_prefix, prefix = f"{GEN}/pose_{name}", f"{GEN}/{name}"
        if ep.newest(f"/data/output/{prefix}_*.png"):
            continue
        text = (f"A young woman of about twenty with long straight silver-white hair and one thin golden strand, her hair "
                f"falling over the sides of her head, wearing {outfit.split(', ', 1)[1]}"
                + (f", holding {SWORD.split(', ', 1)[1]}" if sword else "") + f"; {scene}. {REAL}")
        secs = 0.0
        if phase != "edit" and not ep.newest(f"/data/output/{pose_prefix}_*.png"):
            g = story.qwen_keyframe_wf(1, {"key": text, "seed": seed})
            g["save"]["inputs"]["filename_prefix"] = pose_prefix
            secs, _ = story.run(g, 900)
        if phase == "text":
            print(f"lora real pose {name}: {secs:.1f} s", flush=True)
            continue
        if name == "fur_back":  # her face is not seen: the pose picture is the picture
            shutil.copyfile(ep.newest(f"/data/output/{pose_prefix}_*.png"), f"/data/output/{prefix}_00001_.png")
            continue
        pose = f"lora_real_pose_{name}.png"
        shutil.copyfile(ep.newest(f"/data/output/{pose_prefix}_*.png"), f"/data/input/{pose}")
        prompt = ("Image 1 is the picture to keep: the same scene, pose, body, clothes, sword, camera and light. Exactly one "
                  "woman in the picture. Her FACE becomes exactly the face of images 2 and 3 — the same young woman, the "
                  "silver hair with one thin golden strand. Photorealistic cinematic film still.")
        secs += k3.edit_image((pose, "real_ref_a.png", "real_ref_b.png"), prompt, seed, prefix, False)
        print(f"lora real {name}: {secs:.1f} s", flush=True)


def collect():
    os.makedirs(OUT, exist_ok=True)
    import glob
    n = 0
    # NEW = the step-1 POSE pictures (2026-11-11 00:35: the face edit with full-frame references ADDED A SECOND PERSON in
    # 10 of 11 pictures and put the tunic on fur-outfit ones; the poses are clean: one person, the right outfit, the
    # sword) with identity-free captions; OLD = her realistic face (identity trigger)
    items = [(name, (sorted(glob.glob(f"/data/output/{GEN}/pose_{name}_*.png"))[-1:] or [None])[0], None, outfit, scene,
              sword, False) for name, outfit, sword, scene in NEW]
    items += [(name, src, frame, outfit, scene, False, True) for name, src, frame, outfit, scene in OLD]
    for i, (name, src, frame, outfit, scene, sword, identity) in enumerate(items, 1):
        if not src or not os.path.exists(src) or os.path.exists(f"/data/output/{GEN}/DROP_{name}"):
            print(f"skip {name}", flush=True)
            continue
        dst = f"{OUT}/{i:03d}_{name}.png"
        if frame is None:
            cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-update", "1", dst]
        else:
            cmd = ["ffmpeg", "-y", "-loglevel", "error", "-threads", "2", "-i", src, "-vf", f"select=eq(n\\,{frame})",
                   "-frames:v", "1", "-update", "1", dst]
        subprocess.run(cmd, check=True, timeout=120)
        with open(dst[:-4] + ".txt", "w") as f:
            f.write(caption(outfit, sword, scene, identity))
        n += 1
    print(f"dataset: {n} pictures in {OUT}", flush=True)


if __name__ == "__main__":
    {"gen": gen, "collect": collect}[sys.argv[1]]()
