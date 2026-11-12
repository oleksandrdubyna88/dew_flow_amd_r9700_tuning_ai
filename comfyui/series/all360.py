"""360-degree check videos on ALL character LoRAs (the owner 2026-11-12 ~11:00: "now prepare a 360 video on all LoRAs,
we have 5 or 6"; then "make the 9B LoRA, then the 360 videos on all LoRAs").
New 360s for the LoRA v3 family (dataset lora/slvrareal3, 37 pictures):
  qwen    Qwen-Image 2512 + slvrareal3 0.6               (owner sheet: 0.6 best)
  flux2   FLUX.2 klein 4B + slvrareal3_flux2k4b 0.8
  sdxl    RealVisXL V5   + slvrareal3_sdxl 0.6            (0.8/1.0 add extra people)
  flux2k9 FLUX.2 klein 9B + slvrareal3_flux2k9b 0.8
The two older 360s are reused as they are: series/real2check/orbit_360_v2.mp4 (slvrareal2_tunic 0.6) and
series/arc360/orbit_360_v1.mp4 (painted slvra_v1). compare -> one 3x2 grid video of all six.
Start picture = the scene the owner picked for the realistic 360 (forest path, calm, medium shot), 4 seeds per model;
the orbit = real2_check's two Wan 2.2 14B half-orbits, half 2 always first-last frame (closes on the start face).
Run inside comfyui:  python /opt/tests/all360.py keys <model>
                     python /opt/tests/all360.py orbit <model> <1|2>   (needs all360/<model>/orbit_pick.png)
Any container:       python3 /opt/tests/all360.py keysheet
"""
import glob
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

OUT = "series/all360"
D = f"/data/output/{OUT}"
MODELS = ("qwen", "flux2", "sdxl", "flux2k9")
STRENGTH = {"qwen": 0.6, "flux2": 0.8, "sdxl": 0.6, "flux2k9": 0.8}
SCENE = "standing on a forest path, facing the camera, a calm expression, medium shot, morning light"
SEEDS = (4521, 4522, 4511, 4242)
LABEL = {"qwen": "Qwen v3 0.6", "flux2": "Flux klein 4B v3 0.8", "sdxl": "SDXL v3 0.6", "flux2k9": "Flux klein 9B v3 0.8"}


def keys(model):
    import episode2 as ep
    import she3_check as sc
    s = STRENGTH[model]
    text = sc.prompt(SCENE)
    for n, seed in enumerate(SEEDS, 1):
        prefix = f"{OUT}/{model}/key_c{n}"
        if ep.newest(f"/data/output/{prefix}_*.png"):
            continue
        if model == "qwen":
            import real2_check as rc
            secs = rc.keyframe("slvrareal3", s, text, seed, prefix)
        elif model == "flux2k9":
            secs, _ = ep.story.run(sc.flux2_wf(text, seed, s, prefix, "9b"), 900)
        else:
            secs, _ = ep.story.run((sc.flux2_wf if model == "flux2" else sc.sdxl_wf)(text, seed, s, prefix), 900)
        print(f"all360 {model} key c{n}: {secs:.1f} s", flush=True)


def orbit(model, half, pick=None):
    import episode2 as ep
    import real2_check as rc
    story = ep.story
    d = f"{D}/{model}"
    name = f"all360_{model}_h{half}.png"
    # the owner's pick "c<n>" -> orbit_pick.png (done here: the output folders are root-owned, the host shell cannot copy)
    if pick and not os.path.exists(f"{d}/orbit_pick.png"):
        shutil.copyfile(f"{d}/key_{pick}_00001_.png", f"{d}/orbit_pick.png")
    if half == 1:
        shutil.copyfile(f"{d}/orbit_pick.png", f"/data/input/{name}")
    else:  # ORBIT_H1 = the tag of the half 1 to continue from ("" = the first orbit_h1)
        clip1 = ep.newest(f"{d}/orbit_h1{os.environ.get('ORBIT_H1', '')}_*.mp4")
        subprocess.run(["ffmpeg", "-v", "error", "-threads", "2", "-y", "-sseof", "-0.1", "-i", clip1, "-frames:v", "1",
                        "-update", "1", f"/data/input/{name}"], check=True)
    story.HERO = rc.HERO
    # rerolls (the owner 2026-11-12 17:12: sdxl 360 "beautiful, but she twisted her neck, regenerate"): ORBIT_SEED,
    # ORBIT_TAG (new file names, append-only), ORBIT_EXTRA (positive motion words added to the half's prompt)
    seed = int(os.environ.get("ORBIT_SEED", 4530 + half))
    tag = os.environ.get("ORBIT_TAG", "")
    extra = os.environ.get("ORBIT_EXTRA", "")
    wf = story.wan14b_video_wf(half, {"motion": f"{rc.HALF[half]} {extra} {rc.STYLE}".replace("  ", " "), "seed": seed}, name)
    if half == 2:  # first-last frame: the circle closes on the start face (real2check v2 fix, 2026-11-12 00:40)
        shutil.copyfile(f"{d}/orbit_pick.png", f"/data/input/all360_{model}_end.png")
        wf["end_img"] = {"class_type": "LoadImage", "inputs": {"image": f"all360_{model}_end.png"}}
        wf["i2v"]["class_type"] = "WanFirstLastFrameToVideo"
        wf["i2v"]["inputs"]["end_image"] = ["end_img", 0]
    wf["save"]["inputs"]["filename_prefix"] = f"{OUT}/{model}/orbit_h{half}{'f' if half == 2 else ''}{tag}"
    secs, files = story.run(wf, 7200)
    print(f"all360 {model} orbit half {half}: {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


CTX = int(os.environ.get("ORBIT_CTX", "9"))  # v2v: half 2 sees the last CTX frames of half 1 (4k+1: 9 = 3 latent
# frames). 2026-11-12 19:10 agent check: the joint itself is continuous, but the arms drop in ~0.35 s right after it
# (half 2 must end on the start picture with the arms down) -> ORBIT_CTX=17 (~1 s of motion) + an arm phrase; the join
# then cuts 2*CTX-1 FILM frames


def orbit_v2v(model):
    """Version 2 of half 2 (the owner 2026-11-12 15:40: "I want all 360 videos in 2 versions: one as now, the second via
    v2v so it joins"). Same Wan 2.2 14B, same prompt + seed as half 2, first-last frame, but start_image = the LAST 9
    FRAMES of half 1 (WanFirstLastFrameToVideo takes an image batch; mask covers those frames), so the motion continues
    over the joint; length 89 = 9 context + 80 new frames. end_image = the start picture (circle closes). The first 9
    frames of the output repeat half 1 and are cut at the concat."""
    import episode2 as ep
    import real2_check as rc
    story = ep.story
    # source of half 1 + the start picture, hero, motion, seed: the same as that 360's own half 2
    if model == "arc":  # painted slvra_v1 (arc_orbit.py)
        import arc_orbit as ao
        import ep3_keys as k3
        d, hero, motion, seed = "/data/output/series/arc360", ao.HERO, f"{rc.HALF[2]} {k3.v4.ep.ARC_STYLE}", 4632
    elif model == "real2":  # realistic slvrareal2_tunic 0.6 (real2_check.py)
        d, hero, motion, seed = "/data/output/series/real2check", rc.HERO, f"{rc.HALF[2]} {rc.STYLE}", 4532
    else:
        d, hero, motion, seed = f"{D}/{model}", rc.HERO, f"{rc.HALF[2]} {rc.STYLE}", 4532
    os.makedirs(f"{D}/{model}", exist_ok=True)
    clip1 = sorted(glob.glob(f"{d}/orbit_h1{os.environ.get('ORBIT_H1', '')}_*.mp4"))[-1]  # ORBIT_H1: tag of half 1
    vname = f"all360_{model}_h1{os.environ.get('ORBIT_H1', '')}.mp4"
    shutil.copyfile(clip1, f"/data/input/{vname}")
    shutil.copyfile(f"{d}/orbit_pick.png", f"/data/input/all360_{model}_end.png")
    story.HERO = hero
    # 2026-11-12 18:40 (owner: sdxl b/c "her face turns into the back of her head at the joint", flux2k9 b/c "a small
    # problem at the joint"): v2v + the reroll's direction words; env ORBIT_SEED / ORBIT_TAG / ORBIT_EXTRA as in orbit()
    seed = int(os.environ.get("ORBIT_SEED", seed))
    tag = os.environ.get("ORBIT_TAG", "")
    if os.environ.get("ORBIT_EXTRA"):
        motion = f"{rc.HALF[2]} {os.environ['ORBIT_EXTRA']} {motion[len(rc.HALF[2]) + 1:]}"
    wf = story.wan14b_video_wf(2, {"motion": motion, "seed": seed}, f"all360_{model}_end.png")
    del wf["img"]
    wf["vid"] = {"class_type": "LoadVideo", "inputs": {"file": vname}}
    wf["comp"] = {"class_type": "GetVideoComponents", "inputs": {"video": ["vid", 0]}}
    wf["ctx"] = {"class_type": "ImageFromBatch", "inputs": {"image": ["comp", 0], "batch_index": -CTX, "length": CTX}}
    wf["end_img"] = {"class_type": "LoadImage", "inputs": {"image": f"all360_{model}_end.png"}}
    wf["i2v"]["class_type"] = "WanFirstLastFrameToVideo"
    wf["i2v"]["inputs"]["start_image"] = ["ctx", 0]
    wf["i2v"]["inputs"]["end_image"] = ["end_img", 0]
    wf["i2v"]["inputs"]["length"] = CTX + 80
    wf["save"]["inputs"]["filename_prefix"] = f"{OUT}/{model}/orbit_h2v{tag}"
    secs, files = story.run(wf, 7200)
    print(f"all360 {model} orbit v2v half 2: {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


def keysheet():
    """keys.jpg: one row per model, the 4 start pictures (c1..c4); the Gemini ref first."""
    from PIL import Image, ImageDraw
    import she3_check as sc
    ref = Image.open(sc.REF).convert("RGB")
    rows = []
    for model in MODELS:
        files = [sorted(glob.glob(f"{D}/{model}/key_c{n}_*.png")) for n in range(1, 5)]
        if not any(files):
            continue
        row = Image.new("RGB", (4 * 400 + 220, 220 + 20), "black")
        row.paste(ref.resize((220, 220)), (0, 0))
        for i, f in enumerate(files):
            if f:
                row.paste(Image.open(f[-1]).convert("RGB").resize((400, 220)), (220 + 400 * i, 0))
        ImageDraw.Draw(row).text((4, 224), f"{LABEL[model]}: Gemini ref | c1 | c2 | c3 | c4", fill="white")
        rows.append(row)
    out = Image.new("RGB", (rows[0].width, rows[0].height * len(rows)), "black")
    for i, r in enumerate(rows):
        out.paste(r, (0, r.height * i))
    out.save(f"{D}/keys.jpg", quality=90)
    print(f"all360 keysheet: {len(rows)} rows", flush=True)


if __name__ == "__main__":
    act = sys.argv[1]
    if act == "keys":
        keys(sys.argv[2])
    elif act == "orbit":
        orbit(sys.argv[2], int(sys.argv[3]), sys.argv[4] if len(sys.argv) > 4 else None)
    elif act == "v2v":
        orbit_v2v(sys.argv[2])
    else:
        keysheet()
