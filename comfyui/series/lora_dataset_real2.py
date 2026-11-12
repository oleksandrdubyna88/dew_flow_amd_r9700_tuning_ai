"""The REALISTIC LoRAs, version 2 (the owner, 2026-11-11): the first realistic LoRA (slvrareal, lora_dataset_real.py) took
its face from the set-2 realistic pictures — "it does not look as I chose": the owner's face is slvra_v1 at 0.7
(series/lora_test/slvra_v1_70_portrait, "even better" than 0.5). lora_face_real_test.py showed that face holds in the
photo style. And "there are 2 of them" — one LoRA per outfit, so the outfits cannot mix:
  slvrareal_tunic  her face + the dark-green tunic (episodes 1-2, episode 3 acts 1-2)
  slvrareal_fur    her face + the episode 3 s15 costume (acts 3-4)
Pictures from TEXT ONLY: Qwen-Image 2512 + Lightning + slvra_v1 (the chosen face) + the photo style; no edit step (the
edit with full-frame references added people). Two seeds per scene (fur also at 0.5 — the tunic of slvra_v1 may leak
into the fur costume); every picture checked by eye on a sheet, the bad ones get a DROP_<name> marker before collect.
Positive words only. Same caption face text for both LoRAs (one identity).
Run inside comfyui:   python /opt/tests/lora_dataset_real2.py gen tunic|fur
Any container:        python3 /opt/tests/lora_dataset_real2.py collect tunic|fur  -> /data/output/lora/slvrareal_<outfit>
"""
import glob
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# set b (2026-11-11 12:50): set a (lora/real2_gen) gave very thick eyebrows and a harsh, older face — MY description
# words ("strong dark straight eyebrows") drew them. Set b uses the EXACT words that made the chosen portrait
# (lora_test.LOOK); the fur costume held at 0.7 in all 28 set-a pictures, so 0.5 is dropped.
# set c (12:55): set b came out soft and generic with light eyebrows — the chosen portrait (seed 4242) lies between a
# and b; the face varies with the seed. Set c: the LOOK words + "dark eyebrows, grey-green eyes" (no "strong").
SETS = {
    "b": ("lora/real2b_gen", "a young woman of about twenty with long silver-white hair and one thin golden strand, a "
          "youthful smooth face, big eyes"),
    "c": ("lora/real2c_gen", "a young woman of about twenty with long silver-white hair and one thin golden strand, a "
          "youthful smooth face, big grey-green eyes, dark eyebrows"),
}
# set cf (13:30, the owner chose B): set c with the face repainted from the chosen portrait (face_repaint_real.py pick),
# same caption words as c. Only `collect` with REAL2_SET=cf; never `gen` (the pictures come from the repaint).
SETS["cf"] = ("lora/real2cf_gen", SETS["c"][1])
# 17:55 the owner wanted the younger-looking faces: the y75 (FACE_YOUNG) faces mixed with w12, picked per picture
# (face_picks_y75.txt) -> lora/real2cy_gen; collect with REAL2_SET=cy REAL2_OUT=slvrareal2 (new folders, append-only).
SETS["cy"] = ("lora/real2cy_gen", SETS["c"][1])
GEN, FACE = SETS[os.environ.get("REAL2_SET", "c")]
REAL = ("photorealistic live-action film still, a real young woman, natural skin texture, 35mm photo, shallow depth of "
        "field, cinematic natural light")
OUTFIT = {
    "tunic": "a dark-green wool tunic with brown trim, a brown leather belt and brown leather bracers",
    "fur": ("a sleeveless grey wool crop top that leaves her arms, shoulders and midriff bare, a short skirt of brown fur "
            "panels on a wide brown leather belt, brown leather thigh-high boots with thick fur cuffs and brown leather "
            "bracers"),
}
SCENES = {
    "tunic": [
        ("portrait", "close-up portrait, looking at the camera, soft daylight in a pine forest"),
        ("smile", "close-up, a gentle small smile, golden hour light"),
        ("threeq", "close-up, head turned three-quarters to the left, cool morning light"),
        ("profile", "close-up in profile facing right, overcast sky"),
        ("worried", "close-up, worried face, eyes wide, a dark forest at dusk"),
        ("campfire", "medium close-up, sitting by a campfire at night, warm firelight on her face"),
        ("cloak", "medium shot, standing on a rocky ridge in a long dark-green cloak, wind in her hair"),
        ("walk", "full body, walking along a misty forest path at dawn"),
        ("run", "full body, running through a forest, side view"),
        ("cave", "medium shot, kneeling in a cave behind a waterfall, cold blue light"),
        ("ash", "medium shot, standing in a dead grey forest with ash falling, a leather bag on her shoulder"),
        ("back", "full body seen from behind, walking toward a castle gate"),
        ("hall", "medium shot, standing in a vaulted stone hall, light beams from high windows"),
        ("rain", "close-up, rain on her face, dark clouds"),
    ],
    "fur": [
        ("portrait", "close-up portrait, looking at the camera, bare shoulders, soft daylight"),
        ("threeq", "medium close-up, three-quarter view, warm sunrise light"),
        ("front", "full body, front view, standing in a stone castle courtyard at dawn"),
        ("hips", "full body, three-quarter view, hands on her belt, by a castle wall at sunrise"),
        ("runwall", "full body, side view, running along the top of a castle wall at sunrise"),
        ("pushup", "full body, low side view, doing a push-up on a stone floor in torchlight"),
        ("sword", "full body, holding a longsword in a fighting stance in a castle yard"),
        ("stretch", "full body, stretching her arms above her head in a sunny meadow"),
        ("rug", "medium shot, sitting on a bear-skin rug by a small campfire in a forest glade at night"),
        ("back", "full body seen from behind, walking into a moonlit forest glade"),
        ("stars", "medium shot, lying on a bear-skin rug looking up at the night sky, firelight"),
        ("laugh", "close-up, laughing, morning light"),
        ("climb", "full body, climbing stone stairs of a tower, side view"),
        ("drink", "medium shot, drinking water from a wooden cup, castle kitchen, window light"),
    ],
}
STRENGTHS = {"tunic": (0.7,), "fur": (0.7,)}
SEEDS = (6101, 6202)


def gen(outfit):
    import episode2 as ep
    story = ep.story
    for i, (name, scene) in enumerate(SCENES[outfit]):
        for s in STRENGTHS[outfit]:
            for seed in SEEDS:
                prefix = f"{GEN}/{outfit}_{name}_l{int(s * 10)}_s{seed}"
                if ep.newest(f"/data/output/{prefix}_*.png"):
                    continue
                g = story.qwen_keyframe_wf(1, {"key": f"slvra, {FACE}, wearing {OUTFIT[outfit]}; {scene}. {REAL}",
                                               "seed": seed + i * 11})
                g["slvra"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["lora", 0],
                                                                               "lora_name": "slvra_v1.safetensors",
                                                                               "strength_model": s}}
                g["shift"]["inputs"]["model"] = ["slvra", 0]
                g["save"]["inputs"]["filename_prefix"] = prefix
                secs, _ = story.run(g, 900)
                print(f"real2 {outfit} {name} l{s} s{seed}: {secs:.1f} s", flush=True)


def collect(outfit):
    out = f"/data/output/lora/{os.environ.get('REAL2_OUT', 'slvrareal')}_{outfit}"
    os.makedirs(out, exist_ok=True)
    scenes = dict(SCENES[outfit])
    n = 0
    for src in sorted(glob.glob(f"/data/output/{GEN}/{outfit}_*.png")):
        base = os.path.basename(src).rsplit("_", 2)[0]  # <outfit>_<name>_l<s>_s<seed>
        if os.path.exists(f"/data/output/{GEN}/DROP_{base}"):
            print(f"drop {base}", flush=True)
            continue
        name = base.split("_")[1]
        dst = f"{out}/{base}.png"
        shutil.copyfile(src, dst)
        with open(dst[:-4] + ".txt", "w") as f:
            f.write(f"slvrareal, {FACE}, wearing {OUTFIT[outfit]}, {scenes[name]}, {REAL}")
        n += 1
    print(f"dataset {outfit}: {n} pictures in {out}", flush=True)


if __name__ == "__main__":
    {"gen": gen, "collect": collect}[sys.argv[1]](sys.argv[2])
