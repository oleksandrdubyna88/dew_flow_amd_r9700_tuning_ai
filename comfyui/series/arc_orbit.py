"""The same 360-degree check video with the painted ("cartoon") character LoRA (the owner 2026-11-12 00:30: "I will be
back in the morning. I want you to make one more 360 with the cartoon LoRA").
Painted look = episode 3 (ep3_keys.py: Qwen-Image 2512 + slvra_v1 0.5 + its trigger words + the Arcane style words);
the owner's ideal painted face = ep3 s19 (check_1111/ref_s19_head.png). Scene words = the realistic pick
(orbit_key06m_c2: a forest path, a calm expression, medium shot), the tunic. Motion = real2_check.HALF. Positive words.
Run inside the comfyui container:
  python /opt/tests/arc_orbit.py keys            -> series/arc360/key_c<n> (4 seeds)
  python /opt/tests/arc_orbit.py orbit <1|2>     (needs series/arc360/orbit_pick.png; half 2 needs half 1)
Any container:  python3 /opt/tests/arc_orbit.py sheet   -> series/arc360/keys.jpg (ref s19 head + the 4 keys)
"""
import glob
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

OUT = "series/arc360"
D = f"/data/output/{OUT}"
SEEDS = (4611, 4612, 4613, 4614)
SCENE = ("standing on a forest path, facing the camera, a calm expression, medium shot, morning light; she wears a "
         "dark-green tunic with brown trim, a brown leather belt, brown leather bracers and boots")
# ep3_clips.LOOK says "a soft young face" — child-coded (memory owner-wants-adult-face) -> own adult text
HERO = ("a beautiful woman of about twenty-five with long flowing silver-white hair with one thin golden strand, a slim "
        "face with defined cheekbones, wearing a dark-green tunic with brown trim, a brown leather belt, brown leather "
        "bracers and boots, realistic human proportions")


def keys():
    import ep3_keys as k3
    import episode2 as ep
    for n, seed in enumerate(SEEDS, 1):
        prefix = f"{OUT}/key_c{n}"
        if not ep.newest(f"/data/output/{prefix}_*.png"):
            secs = k3.text_image(SCENE, seed, prefix, True)
            print(f"arc360 key c{n}: {secs:.1f} s", flush=True)


# 00:50 the text keys (step 1 of ep3_keys) look almost like photos -> step 2 as in ep3: the edit model + slvra_v1 keeps
# the pose and paints her with the owner's ideal face (image 2 = check_1111/ref_s19_head.png, image 3 = the whole ep3
# s19 frame for the painted style). Adult words only, positive words only (memory owner-wants-adult-face).
PAINT_PROMPT = ("Image 1 is the picture to keep: the same forest path, the same pose and body, the same camera and light, "
                "her dark-green tunic, belt and bracers as in image 1. Exactly one woman in the picture. Her face becomes "
                "exactly the face of the woman in image 2: a beautiful woman of about twenty-five, a slim face with defined "
                "cheekbones, the same eyes, eyebrows, nose and lips as in image 2, a calm expression. Her long silver-white "
                "hair is loose, with one thin golden strand beside her cheek. The whole picture is painted in the same "
                "Arcane animation style as image 3: painterly textures, visible brush strokes, cinematic lighting.")


def paint():
    import ep3_keys as k3
    import episode2 as ep
    shutil.copyfile("/data/output/series/check_1111/ref_s19_head.png", "/data/input/ep3_ref_s19_head.png")
    shutil.copyfile(ep.newest("/data/output/series/ep3/picks/s19*.png"), "/data/input/ep3_s19_full.png")
    for n, seed in enumerate(SEEDS, 1):
        prefix = f"{OUT}/paint_c{n}"
        if ep.newest(f"/data/output/{prefix}_*.png"):
            continue
        key = f"arc360_key_c{n}.png"
        shutil.copyfile(ep.newest(f"{D}/key_c{n}_*.png"), f"/data/input/{key}")
        secs = k3.edit_image((key, "ep3_ref_s19_head.png", "ep3_s19_full.png"), PAINT_PROMPT, seed, prefix, True)
        print(f"arc360 paint c{n}: {secs:.1f} s", flush=True)


# 00:55 paint_c* failed: the edit model pasted the big s19 head (image 2) into the forest as a second giant face.
# paint2: no head crop. ARC_REFS=1: image 1 only, style words; ARC_REFS=2: image 2 = the whole ep3 s19 frame (style + face
# from a complete scene). Keys c2, c3 (the best text keys) -> paint<R>r_c<n>.
PAINT2 = {
    1: ("Repaint this picture in the painted Arcane animation style: painterly textures, visible brush strokes, stylised "
        "painted shapes, cinematic lighting. Keep everything else: the same forest path, the same pose, body, camera and "
        "light, the same dark-green tunic, belt and bracers, the same long silver-white hair with one thin golden strand, "
        "the same face of a beautiful woman of about twenty-five with a calm expression. Exactly one woman."),
    2: ("Repaint image 1 in the painted Arcane animation style of image 2: painterly textures, visible brush strokes, "
        "cinematic lighting. Keep the composition of image 1: the same forest path, the same pose, body and camera, the same "
        "dark-green tunic, belt and bracers. Exactly one woman, the woman of image 1. Her face is the face of the woman in "
        "image 2: a beautiful woman of about twenty-five, a slim face with defined cheekbones, a calm expression, her long "
        "silver-white hair with one thin golden strand."),
}


def paint2():
    import ep2_v4 as v4
    import episode2 as ep
    r = int(os.environ.get("ARC_REFS", "1"))
    shutil.copyfile(ep.newest("/data/output/series/ep3/picks/s19*.png"), "/data/input/ep3_s19_full.png")
    for n in (2, 3):
        prefix = f"{OUT}/paint{r}r_c{n}"
        if ep.newest(f"/data/output/{prefix}_*.png"):
            continue
        key = f"arc360_key_c{n}.png"
        shutil.copyfile(ep.newest(f"{D}/key_c{n}_*.png"), f"/data/input/{key}")
        refs = (key,) if r == 1 else (key, "ep3_s19_full.png")
        g = v4.round2_graph(4, SEEDS[n - 1], refs, "", prefix)
        for i in range(len(refs) + 1, 4):
            for k in (f"ref{i}", f"scale{i}"):
                g.pop(k, None)
            for enc in ("pos", "neg"):
                g[enc]["inputs"].pop(f"image{i}", None)
        g["pos"]["inputs"]["prompt"] = PAINT2[r]
        import ep3_keys as k3
        k3.add_lora(g, "unet")
        secs, _ = ep.story.run(g, 900)
        print(f"arc360 paint{r}r c{n}: {secs:.1f} s", flush=True)


def orbit(half):
    import ep3_keys as k3
    import episode2 as ep
    import real2_check as rc
    story = ep.story
    name = f"arc360_h{half}.png"
    if half == 1:
        shutil.copyfile(f"{D}/orbit_pick.png", f"/data/input/{name}")
    else:
        clip1 = ep.newest(f"{D}/orbit_h1_*.mp4")
        subprocess.run(["ffmpeg", "-v", "error", "-threads", "2", "-y", "-sseof", "-0.1", "-i", clip1, "-frames:v", "1",
                        "-update", "1", f"/data/input/{name}"], check=True)
    story.HERO = HERO
    wf = story.wan14b_video_wf(half, {"motion": f"{rc.HALF[half]} {k3.v4.ep.ARC_STYLE}", "seed": 4630 + half}, name)
    # 2026-11-12 00:40: in real2check orbit_360_v1 half 2 (from a back view) the face came back as another, rounder
    # face and the tunic changed. ORBIT_FLF=1: half 2 = WanFirstLastFrameToVideo with end_image = the start picture,
    # so the circle closes on the approved face -> orbit_h2f
    flf = half == 2 and os.environ.get("ORBIT_FLF") == "1"
    if flf:
        shutil.copyfile(f"{D}/orbit_pick.png", "/data/input/orbit_end_arc360_h.png")
        wf["end_img"] = {"class_type": "LoadImage", "inputs": {"image": "orbit_end_arc360_h.png"}}
        wf["i2v"]["class_type"] = "WanFirstLastFrameToVideo"
        wf["i2v"]["inputs"]["end_image"] = ["end_img", 0]
    wf["save"]["inputs"]["filename_prefix"] = f"{OUT}/orbit_h{half}{'f' if flf else ''}"
    secs, files = story.run(wf, 7200)
    print(f"arc360 orbit half {half}: {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


def sheet():
    from PIL import Image, ImageDraw
    fs = ["/data/output/series/check_1111/ref_s19_head.png"] + [
        (sorted(glob.glob(f"{D}/{os.environ.get('ARC_SHEET', 'key')}_c{n}_*.png")) or [None])[-1] for n in range(1, 5)]
    out = Image.new("RGB", (5 * 640, 352 + 20), "black")
    for i, f in enumerate(fs):
        if f:
            im = Image.open(f).convert("RGB")
            im = im.resize((352, 352)) if i == 0 else im.resize((640, 352))
            out.paste(im, (640 * i + (144 if i == 0 else 0), 0))
        ImageDraw.Draw(out).text((640 * i + 4, 356), "ideal: ep3 s19" if i == 0 else f"c{i}", fill="white")
    out.save(f"{D}/{os.environ.get('ARC_SHEET', 'key')}s.jpg", quality=92)
    print("arc360 sheet written", flush=True)


if __name__ == "__main__":
    {"keys": keys, "paint": paint, "paint2": paint2, "sheet": sheet, "orbit": lambda: orbit(int(sys.argv[2]))}[sys.argv[1]]()
