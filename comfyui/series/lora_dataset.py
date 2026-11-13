"""The character LoRA dataset (the owner, 2026-11-09: "this is many times better — put it through a LoRA so we don't lose
it"): pictures of her with the APPROVED young face (ep2 v4), each with a caption that starts with the trigger word.

Sources: the picked keyframes and good alternatives of ep2 v4 (rounds 4-6), the two face references (v3 sleep shot,
frames 76/80, forehead dot cleaned), frames of the good clips (v3 shots 1-2 = the approved first 10 s; v4 shots 4-6),
later the ep1 young keyframes and clips (re-run to add them; existing files are kept). Bad frames are not taken: the
blinking v4 shot 3 is left out, and frames are taken at fixed points I checked on the sheets.
Run inside the comfyui container:  python /opt/tests/lora_dataset.py
Writes /data/output/lora/slvra/NNN_<name>.png + .txt and prints the count.
"""
import os
import subprocess

TRIGGER = "slvra"
LOOK = ("a young woman of about twenty with long silver-white hair and one thin golden strand, a youthful smooth face, "
        "big eyes, wearing a dark-green tunic with brown trim, a brown belt and brown leather bracers")
STYLE = "painted Arcane animation style"
OUT = "/data/output/lora/slvra"
E2 = "/data/output/series/ep2"
E1 = "/data/output/series/elf_set2_arcane"

# (name, source path, frame number for a video or None for an image, scene)
SOURCES = [
    ("face_a", f"{E2}/refs/ref_young_face_a.png", None, "close-up of her face, lying on a fur bedroll, looking up"),
    ("face_b", f"{E2}/refs/ref_young_face_b.png", None, "close-up of her face, lying on a fur bedroll, looking aside"),
    ("e2s3_pick", f"{E2}/v4/pick4_s3.png", None, "standing on a hill under black storm clouds over a pine forest valley"),
    ("e2s3_c41", f"{E2}/v4/key_s3_c41_00001_.png", None, "medium shot, standing under black storm clouds"),
    ("e2s4_pick", f"{E2}/v4/pick4_s4.png", None, "walking through a dead winter forest, grey sky"),
    ("e2s5_pick", f"{E2}/v4/pick4_s5.png", None, "crouching behind a fallen tree, wolves behind her in a dark forest"),
    ("e2s5_c43", f"{E2}/v4/key_s5_c43_00001_.png", None, "sitting behind a fallen tree, wolves behind her"),
    ("e2s6_pick", f"{E2}/v4/pick4_s6.png", None, "standing at a cave entrance with a leather bag on her shoulder"),
    ("e2s6_c43", f"{E2}/v4/key_s6_c43_00001_.png", None, "standing in a dead forest with a leather backpack"),
    ("e2v3s1_f16", f"{E2}/v3/clip_s1_00001_.mp4", 16, "kneeling by a campfire in a cave behind a waterfall"),
    ("e2v3s1_f64", f"{E2}/v3/clip_s1_00001_.mp4", 64, "kneeling by a campfire in a cave, firelight on her face"),
    ("e2v3s2_f72", f"{E2}/v3/clip_s2_00001_.mp4", 72, "lying on a fur bedroll by a campfire, eyes open"),
    ("e2v4s4_f40", f"{E2}/v4/clip_s4_00001_.mp4", 40, "walking through a dead winter forest"),
    ("e2v4s4_f80", f"{E2}/v4/clip_s4_00001_.mp4", 80, "walking toward the camera in a dead winter forest"),
    ("e2v4s5_f40", f"{E2}/v4/clip_s5_00001_.mp4", 40, "hiding behind a fallen tree from wolves"),
    ("e2v4s6_f40", f"{E2}/v4/clip_s6_00001_.mp4", 40, "at a cave entrance with a leather bag"),
]
# the ep1 young keyframes (round 7 picks) once they exist
for k, scene in ((1, "walking on a sunlit path in a green summer forest"), (2, "close-up of her worried face in a forest"),
                 (3, "running from a fiery mushroom cloud in a forest"), (4, "jumping over a mossy log in a forest"),
                 (5, "climbing by a river under a red burning sky"), (6, "standing in a cave in front of a waterfall")):
    SOURCES.append((f"e1s{k}_pick", f"{E1}/young/pick_s{k}.png", None, scene))


def main():
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for i, (name, src, frame, scene) in enumerate(SOURCES, 1):
        if not os.path.exists(src):
            print(f"skip {name}: no {src}", flush=True)
            continue
        dst = f"{OUT}/{i:03d}_{name}.png"
        if not os.path.exists(dst):
            if frame is None:
                subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-update", "1", dst], check=True, timeout=60)
            else:
                subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-threads", "2", "-i", src, "-vf",
                                f"select=eq(n\\,{frame})", "-frames:v", "1", "-update", "1", dst], check=True, timeout=120)
        with open(dst[:-4] + ".txt", "w") as f:
            f.write(f"{TRIGGER}, {LOOK}, {scene}, {STYLE}")
        n += 1
    print(f"dataset: {n} pictures in {OUT}", flush=True)


if __name__ == "__main__":
    main()
