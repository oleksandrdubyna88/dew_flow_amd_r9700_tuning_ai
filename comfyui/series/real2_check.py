"""Check of the realistic LoRAs v2 (slvrareal2_tunic / slvrareal2_fur, trained 2026-11-11 evening from the y75 mix).
1. test: both LoRAs x strength 0.6 / 0.8 / 1.0 on three scenes; the portrait uses the seed of the owner's chosen face
   (4242, series/lora_test/realface_slvra_v1_70_portrait). Prompts = the training caption words (lora_dataset_real2).
2. orbit (the owner 18:05: "then record a 10 s video where she just stands and dances lightly, and the camera turns
   360 degrees around her, so I can judge the quality"): a full-body keyframe with the tunic LoRA (2 seeds), then two
   chained Wan 2.2 14B I2V clips of 81 frames at 16 fps (5 s each; the 2nd starts from the LAST frame of the 1st, each
   half-orbit 180 degrees) -> FILM 32 fps -> one 10 s file. Positive words only.
Run inside the comfyui container:
  python /opt/tests/real2_check.py test
  REAL2_S=0.8 python /opt/tests/real2_check.py keys
  python /opt/tests/real2_check.py orbit <half: 1|2>     (needs real2check/orbit_pick.png; half 2 needs half 1)
Any container:  python3 /opt/tests/real2_check.py sheet
"""
import glob
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

OUT = "series/real2check"
D = f"/data/output/{OUT}"
LORAS = ("slvrareal2_tunic", "slvrareal2_fur")
STRENGTHS = (0.6, 0.8, 1.0)
SCENES = {
    "portrait": ("close-up portrait, looking at the camera, soft daylight", 4242),
    "walk": ("walking along a forest path toward the camera, medium shot, morning light", 4511),
    "threeq": ("three-quarter view, head turned to the left, standing by a campfire at dusk, medium close-up", 4512),
}
ORBIT_SCENE = ("standing on a sunlit forest clearing, full body from head to boots, facing the camera, a calm small smile, "
               "soft morning light, green trees around")
# 00:10 the owner on orbit_key_c1 (0.8, sunlit clearing): "this is not it at all" -> the scene words of the "walk" test
# (that face matched the chosen portrait) + 4 seeds (4511 = the walk seed); the owner picks before any video
ORBIT_SCENE_WIDE = ("standing on a forest path, facing the camera, full body from head to boots, a calm small smile, "
                    "morning light")
ORBIT_SEEDS_WIDE = (4511, 4242, 4521, 4522)
ORBIT_SCENE_CALM = "standing on a forest path, facing the camera, a calm expression, medium shot, morning light"
ORBIT_SEEDS = (4521, 4522)
HALF = {
    1: ("She stands in place on the forest path and dances lightly: she sways her hips from side to side, shifts her "
        "weight from foot to foot and moves her shoulders and arms softly to a slow rhythm, smiling; her silver hair "
        "swings. The camera circles around her at the same distance, moving smoothly to the right, half a circle, from her "
        "front to her back."),
    2: ("She keeps dancing lightly in place on the forest path: she sways her hips from side to side and moves her "
        "shoulders and arms softly to a slow rhythm; her silver hair swings. The camera keeps circling around her at the "
        "same distance, moving smoothly to the right, the second half of the circle, from her back round to her front, "
        "and ends facing her smiling face."),
}
# 00:20 the owner picked orbit_key06m_c2 (a forest path, medium shot) -> the motion texts say "forest path"
HERO = ("a young woman with long flowing silver-white hair with one thin golden strand, wearing a dark-green tunic with "
        "brown trim, a brown belt, brown leather bracers and boots, realistic human proportions")
STYLE = "photorealistic live-action film, consistent with the first frame, the same face all the time."


def prompt(outfit, scene):
    import lora_dataset_real2 as ld
    return f"slvrareal, {ld.SETS['c'][1]}, wearing {ld.OUTFIT[outfit]}, {scene}, {ld.REAL}"


def keyframe(lora, strength, text, seed, prefix):
    import episode2 as ep
    story = ep.story
    g = story.qwen_keyframe_wf(1, {"key": text, "seed": seed})
    g["real2"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["lora", 0], "lora_name": f"{lora}.safetensors",
                                                                   "strength_model": strength}}
    g["shift"]["inputs"]["model"] = ["real2", 0]
    g["save"]["inputs"]["filename_prefix"] = prefix
    secs, _ = story.run(g, 900)
    return secs


def test():
    import episode2 as ep
    for lora in LORAS:
        outfit = lora.split("_")[1]
        for name, (scene, seed) in SCENES.items():
            for s in STRENGTHS:
                prefix = f"{OUT}/test/{lora}_{int(s * 100)}_{name}"
                if ep.newest(f"/data/output/{prefix}_*.png"):
                    continue
                secs = keyframe(lora, s, prompt(outfit, scene), seed, prefix)
                print(f"real2check {lora} {s} {name}: {secs:.1f} s", flush=True)


def keys():
    import episode2 as ep
    s = float(os.environ.get("REAL2_S", "0.8"))
    # 2026-11-12 the owner picked strength 0.6 from test_sheet.jpg; the 0.8 keys were waist-up. REAL2_KEYTAG (e.g. "06w")
    # = new file names orbit_key<TAG>_c<n> and the wide full-body scene text (the c1/c2 files stay)
    tag = os.environ.get("REAL2_KEYTAG", "")
    # 00:15 the 06w keys (smile, "full body") again gave the rounder smiling face -> "06m" = the walk-test words exactly,
    # standing, a calm expression as in the chosen portrait (no smile)
    scene = {"": ORBIT_SCENE, "06m": ORBIT_SCENE_CALM}.get(tag, ORBIT_SCENE_WIDE)
    for n, seed in enumerate(ORBIT_SEEDS_WIDE if tag else ORBIT_SEEDS, 1):
        prefix = f"{OUT}/orbit_key{tag}_c{n}"
        if not ep.newest(f"/data/output/{prefix}_*.png"):
            secs = keyframe("slvrareal2_tunic", s, prompt("tunic", scene), seed, prefix)
            print(f"real2check orbit key{tag} c{n} ({s}): {secs:.1f} s", flush=True)


def orbit(half):
    import episode2 as ep
    story = ep.story
    name = f"real2_orbit_h{half}.png"
    if half == 1:
        shutil.copyfile(f"{D}/orbit_pick.png", f"/data/input/{name}")
    else:
        clip1 = ep.newest(f"{D}/orbit_h1_*.mp4")
        subprocess.run(["ffmpeg", "-v", "error", "-threads", "2", "-y", "-sseof", "-0.1", "-i", clip1, "-frames:v", "1",
                        "-update", "1", f"/data/input/{name}"], check=True)
    story.HERO = HERO
    wf = story.wan14b_video_wf(half, {"motion": f"{HALF[half]} {STYLE}", "seed": 4530 + half}, name)
    # 2026-11-12 00:40: in real2check orbit_360_v1 half 2 (from a back view) the face came back as another, rounder
    # face and the tunic changed. ORBIT_FLF=1: half 2 = WanFirstLastFrameToVideo with end_image = the start picture,
    # so the circle closes on the approved face -> orbit_h2f
    flf = half == 2 and os.environ.get("ORBIT_FLF") == "1"
    if flf:
        shutil.copyfile(f"{D}/orbit_pick.png", "/data/input/orbit_end_real2_orbit_h.png")
        wf["end_img"] = {"class_type": "LoadImage", "inputs": {"image": "orbit_end_real2_orbit_h.png"}}
        wf["i2v"]["class_type"] = "WanFirstLastFrameToVideo"
        wf["i2v"]["inputs"]["end_image"] = ["end_img", 0]
    wf["save"]["inputs"]["filename_prefix"] = f"{OUT}/orbit_h{half}{'f' if flf else ''}"
    secs, files = story.run(wf, 7200)
    print(f"real2check orbit half {half}: {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


def sheet():
    """test_sheet.jpg: one row per LoRA x scene, columns = the strengths; the owner's chosen portrait first."""
    from PIL import Image, ImageDraw
    target = Image.open("/data/output/series/lora_test/realface_slvra_v1_70_portrait_00001_.png").convert("RGB")
    rows = []
    for lora in LORAS:
        for name in SCENES:
            row = Image.new("RGB", (4 * 480, 264 + 20), "black")
            row.paste(target.resize((480, 264)), (0, 0))
            for i, s in enumerate(STRENGTHS, 1):
                f = sorted(glob.glob(f"{D}/test/{lora}_{int(s * 100)}_{name}_*.png"))
                if f:
                    row.paste(Image.open(f[-1]).convert("RGB").resize((480, 264)), (480 * i, 0))
            ImageDraw.Draw(row).text((4, 268), f"{lora} {name}: chosen portrait | 0.6 | 0.8 | 1.0", fill="white")
            rows.append(row)
    out = Image.new("RGB", (rows[0].width, rows[0].height * len(rows)), "black")
    for i, r in enumerate(rows):
        out.paste(r, (0, r.height * i))
    out.save(f"{D}/test_sheet.jpg", quality=90)
    print(f"real2check sheet: {len(rows)} rows", flush=True)


if __name__ == "__main__":
    act = sys.argv[1]
    {"test": test, "keys": keys, "sheet": sheet, "orbit": lambda: orbit(int(sys.argv[2]))}[act]()
