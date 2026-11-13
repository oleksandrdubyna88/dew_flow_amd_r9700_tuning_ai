"""The realistic LoRAs v2, step B (the owner, 2026-11-11: "B, go ahead"): before training, repaint the FACE of every set-c
picture (lora_dataset_real2.py, lora/real2c_gen) with the owner's chosen face as the reference
(series/lora_test/realface_slvra_v1_70_portrait — slvra_v1 at 0.7 in the photo style). Text-only pictures give a face that
changes with the seed (heavy brows, older); training on them would teach a mixed face again (LoRA v1's fault).

Method = inpaint_any.py face mode (Qwen-Image-Edit 2511 Lightning, image 1 = the picture, image 2 = the face reference,
a masked latent, denoise 0.75, two seeds), with one change: the faces in full-body shots are small (40-60 px), so a
SQUARE CROP around the face is enlarged to 1024 x 1024 first, repainted, scaled back and pasted into the untouched picture
through the feathered mask (only the face changes; the crop's outside-mask pixels are never pasted).
Positive words only; the expression, head angle, hair and light come from image 1.

Run:  python3 /opt/tests/face_repaint_real.py prep          (any container: mask preview sheets -> real2c_face/prep_*.jpg)
      python  /opt/tests/face_repaint_real.py run [name...]  (inside comfyui: r1/r2 per picture -> real2c_face/full/)
      python3 /opt/tests/face_repaint_real.py sheet         (any container: original | r1 | r2 face crops -> cmp_*.jpg)
      python3 /opt/tests/face_repaint_real.py pick <name> <0|1|2> ...  (0 = keep the original) -> lora/real2cf_gen
"""
import glob
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

SRC = "/data/output/lora/real2c_gen"
OUT = "/data/output/lora/real2c_face"
PICKED = os.environ.get("FACE_PICKED", "/data/output/lora/real2cf_gen")  # REAL2_SET=cf (w12) / cy (y75 mix, 17:55)
REF_SRC = "/data/output/series/lora_test/realface_slvra_v1_70_portrait_00001_.png"
REF_BOX = (380, 20, 780, 420)  # the head of the chosen portrait (1280 x 704), a square
REF_NAME = "realface_ref_head.png"
SIDE = 1024
SEEDS = (4301, 4302)
PROMPT = ("Her face is exactly the face of the young woman in image 2: the same eyes, the same eyebrows, the same nose, the "
          "same lips, the same cheeks and the same face shape. The head angle, the expression, the hair and the light stay "
          "as in image 1. Photorealistic film still, natural skin texture.")
# 14:05: at 0.75 the faces move only a little toward the target (the heavy brows stay; seed 2 adds freckles). A test
# of stronger repaints: FACE_DENOISE=0.9 FACE_VAR=_d90 (the variant's files are <name>_r<n><VAR>), then `test`.
DENOISE = float(os.environ.get("FACE_DENOISE", "0.75"))
VAR = os.environ.get("FACE_VAR", "")
# 14:30 test_denoise.jpg: 0.9 and 1.0 BREAK the close-ups (double eyes, melted faces, an old woman); only small faces
# survive. Test 2 (the owner: "ok, do test 2"): FACE_METHOD=swap — a FULL edit of the head crop (an empty latent, no
# masked latent; image 1 = the crop, image 2 = the target head), the method of young_face.py that gave the approved
# ep2 young face; only the face mask is pasted back. FACE_VAR=_sw.
METHOD = os.environ.get("FACE_METHOD", "mask")
SWAP = ("Image 1 is the picture to keep. Redraw image 1 exactly: the same pose, the same head angle, the same expression, "
        "the same hair, the same clothes, the same framing and the same light. Change ONLY her face: it becomes the face "
        "of the young woman in image 2, with the same eyes, the same eyebrows, the same nose, the same lips and the same "
        "face shape. Photorealistic film still, natural skin texture, the same photo look as image 1.")
# 14:40 test_swap.jpg: the full edit COPIES image 2 (the reference's framing) — unusable. The owner: "ok, do InstantID".
# FACE_METHOD=iid: SDXL RealVisXL 5.0 + InstantID (cubiq/ComfyUI_InstantID; instantid_setup.sh) — the face embedding of
# the target head, the keypoints of the picture's own face (pose kept), a masked latent at FACE_DENOISE, only the mask
# pasted back. Variants _i60/_i80 (denoise 0.6/0.8).
TEST_VARS = tuple(os.environ.get("FACE_TEST_VARS", ",_sw").split(","))
IID_POS = ("photo of a young woman of about twenty with long silver-white hair, {mood}, natural skin texture, 35mm film "
           "still, cinematic natural light")
IID_NEG = "painting, cartoon, drawing, blurry, deformed face"
# 16:00 the owner: "on some pictures she is clearly older; I like the younger ones". The set-c originals have thick
# brows + contour makeup, and denoise 0.6 keeps them; the target portrait has thin straight brows and a soft face.
# FACE_YOUNG=1: a younger prompt (SDXL negative = avoid, it does not draw the named thing like the edit model does).
if os.environ.get("FACE_YOUNG") == "1":
    # 16:10 the owner: "not a really young girl; the younger ones of the w12 set are fine" -> the age words stay as
    # before (an adult woman of about twenty); only the brows and the makeup change.
    IID_POS = ("photo of a young woman of about twenty with long silver-white hair, thin straight natural eyebrows, "
               "light natural makeup, {mood}, natural skin texture, 35mm film still, cinematic natural light")
    IID_NEG = ("painting, cartoon, drawing, blurry, deformed face, heavy makeup, thick bushy eyebrows, contour makeup, "
               "older woman")
# 15:10 test_iid.jpg: InstantID works (no broken faces, pose/expression/cup kept, ONE face in all) but the face is slimmer,
# the nose and lips thinner than the target; 0.8 loses the golden strand -> 0.6. Test 2 (the owner): a stronger face
# weight — FACE_IPW 1.0 / 1.2 with FACE_CN 0.5 (variants _w10/_w12, denoise 0.6).
IID_IPW = float(os.environ.get("FACE_IPW", "0.8"))
IID_CN = float(os.environ.get("FACE_CN", "0.6"))
MOODS = {"laugh": "laughing", "smile": "gentle smile", "worried": "worried face"}

# Face boxes (fractions of the picture: x0, y0, x1, y1), placed by eye on real2c_face/grid_*.jpg, 20 moved after the
# first mask preview (prep_*.jpg). Not here: fur_back
# s6101 (seen from behind, no face) and fur_back s6202 (it faces the camera although its caption says "from behind" —
# dropped from the dataset).
BOXES = {
    "fur_climb_l7_s6101": (0.45, 0.06, 0.52, 0.21), "fur_climb_l7_s6202": (0.415, 0.08, 0.49, 0.23),
    "fur_drink_l7_s6101": (0.38, 0.10, 0.47, 0.29), "fur_drink_l7_s6202": (0.36, 0.10, 0.45, 0.29),
    "fur_front_l7_s6101": (0.40, 0.055, 0.465, 0.19), "fur_front_l7_s6202": (0.385, 0.06, 0.445, 0.19),
    "fur_hips_l7_s6101": (0.38, 0.04, 0.45, 0.16), "fur_hips_l7_s6202": (0.38, 0.04, 0.45, 0.17),
    "fur_laugh_l7_s6101": (0.40, 0.05, 0.515, 0.31), "fur_laugh_l7_s6202": (0.415, 0.05, 0.54, 0.33),
    "fur_portrait_l7_s6101": (0.375, 0.06, 0.50, 0.35), "fur_portrait_l7_s6202": (0.345, 0.06, 0.485, 0.36),
    "fur_pushup_l7_s6101": (0.645, 0.21, 0.735, 0.38), "fur_pushup_l7_s6202": (0.69, 0.18, 0.775, 0.37),
    "fur_rug_l7_s6101": (0.37, 0.08, 0.445, 0.25), "fur_rug_l7_s6202": (0.36, 0.07, 0.445, 0.25),
    "fur_runwall_l7_s6101": (0.4, 0.08, 0.475, 0.22), "fur_runwall_l7_s6202": (0.39, 0.07, 0.46, 0.22),
    "fur_stars_l7_s6101": (0.26, 0.13, 0.335, 0.3), "fur_stars_l7_s6202": (0.245, 0.115, 0.325, 0.29),
    "fur_stretch_l7_s6101": (0.375, 0.11, 0.455, 0.265), "fur_stretch_l7_s6202": (0.375, 0.10, 0.445, 0.25),
    "fur_sword_l7_s6101": (0.4, 0.08, 0.47, 0.25), "fur_sword_l7_s6202": (0.41, 0.08, 0.48, 0.25),
    "fur_threeq_l7_s6101": (0.375, 0.065, 0.485, 0.31), "fur_threeq_l7_s6202": (0.35, 0.065, 0.46, 0.32),
    "tunic_ash_l7_s6101": (0.40, 0.115, 0.50, 0.34), "tunic_ash_l7_s6202": (0.365, 0.115, 0.475, 0.35),
    "tunic_back_l7_s6101": (0.43, 0.08, 0.495, 0.265), "tunic_back_l7_s6202": (0.435, 0.095, 0.505, 0.27),
    "tunic_campfire_l7_s6101": (0.33, 0.11, 0.47, 0.41), "tunic_campfire_l7_s6202": (0.325, 0.1, 0.465, 0.41),
    "tunic_cave_l7_s6101": (0.38, 0.15, 0.50, 0.39), "tunic_cave_l7_s6202": (0.38, 0.14, 0.50, 0.40),
    "tunic_cloak_l7_s6101": (0.39, 0.145, 0.50, 0.385), "tunic_cloak_l7_s6202": (0.375, 0.13, 0.485, 0.40),
    "tunic_hall_l7_s6101": (0.38, 0.14, 0.49, 0.37), "tunic_hall_l7_s6202": (0.375, 0.125, 0.485, 0.37),
    "tunic_portrait_l7_s6101": (0.335, 0.09, 0.555, 0.57), "tunic_portrait_l7_s6202": (0.32, 0.09, 0.555, 0.57),
    "tunic_profile_l7_s6101": (0.34, 0.13, 0.555, 0.7), "tunic_profile_l7_s6202": (0.33, 0.12, 0.54, 0.7),
    "tunic_rain_l7_s6101": (0.335, 0.15, 0.555, 0.61), "tunic_rain_l7_s6202": (0.335, 0.15, 0.555, 0.61),
    "tunic_run_l7_s6101": (0.41, 0.12, 0.50, 0.35), "tunic_run_l7_s6202": (0.40, 0.11, 0.515, 0.36),
    "tunic_smile_l7_s6101": (0.335, 0.08, 0.57, 0.60), "tunic_smile_l7_s6202": (0.345, 0.08, 0.565, 0.60),
    "tunic_threeq_l7_s6101": (0.34, 0.11, 0.555, 0.65), "tunic_threeq_l7_s6202": (0.335, 0.12, 0.54, 0.65),
    "tunic_walk_l7_s6101": (0.39, 0.14, 0.485, 0.345), "tunic_walk_l7_s6202": (0.375, 0.14, 0.47, 0.345),
    "tunic_worried_l7_s6101": (0.335, 0.13, 0.56, 0.61), "tunic_worried_l7_s6202": (0.335, 0.12, 0.555, 0.61),
}
KEEP_AS_IS = ("fur_back_l7_s6101",)  # no face to repaint; goes to the dataset unchanged
DROP = ("fur_back_l7_s6202",)


def src_of(name):
    return f"{SRC}/{name}_00001_.png"


def geometry(name, w, h):
    """The face ellipse (pixels, the box padded by 25 % per side, as inpaint_any.py) and the square crop around it."""
    x0, y0, x1, y1 = BOXES[name]
    px, py = (x1 - x0) * 0.25, (y1 - y0) * 0.25
    ell = ((x0 - px) * w, (y0 - py) * h, (x1 + px) * w, (y1 + py) * h)
    side = int(min(h, w, max(256, 1.6 * max(ell[2] - ell[0], ell[3] - ell[1]))))
    cx, cy = (ell[0] + ell[2]) / 2, (ell[1] + ell[3]) / 2
    left = int(min(max(cx - side / 2, 0), w - side))
    top = int(min(max(cy - side / 2, 0), h - side))
    return ell, (left, top, left + side, top + side)


def full_mask(name, w, h):
    from PIL import Image, ImageDraw, ImageFilter
    ell, _ = geometry(name, w, h)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse(ell, fill=255)
    return mask.filter(ImageFilter.GaussianBlur(max(2, (ell[2] - ell[0]) / 40)))


def prep_one(name, inp="/data/input"):
    """Writes the enlarged crop, its mask (any_pick_/any_fill_/any_mask_<tag>.png, as inpaint_any.graph reads them)."""
    from PIL import Image
    pic = Image.open(src_of(name)).convert("RGB")
    w, h = pic.size
    _, crop = geometry(name, w, h)
    mask = full_mask(name, w, h).crop(crop).resize((SIDE, SIDE), Image.LANCZOS)
    tile = pic.crop(crop).resize((SIDE, SIDE), Image.LANCZOS)
    tag = f"rf_{name}"
    os.makedirs(inp, exist_ok=True)
    tile.save(f"{inp}/any_pick_{tag}.png")
    tile.save(f"{inp}/any_fill_{tag}.png")
    Image.merge("RGB", (mask, mask, mask)).save(f"{inp}/any_mask_{tag}.png")
    return tag


def prep():
    """Mask preview: every picture with its face ellipse in red and the crop square in yellow, 8 per sheet."""
    from PIL import Image, ImageDraw
    os.makedirs(OUT, exist_ok=True)
    tiles = []
    for name in BOXES:
        pic = Image.open(src_of(name)).convert("RGB")
        w, h = pic.size
        _, crop = geometry(name, w, h)
        mask = full_mask(name, w, h)
        prev = Image.composite(Image.new("RGB", (w, h), (255, 0, 0)), pic, mask.point(lambda v: v // 2))
        ImageDraw.Draw(prev).rectangle(crop, outline=(255, 255, 0), width=3)
        sub = prev.crop(crop).resize((320, 320))
        t = Image.new("RGB", (960, 352), "black")
        t.paste(prev.resize((640, 352)), (0, 0))
        t.paste(sub, (640, 16))
        ImageDraw.Draw(t).text((4, 338), name, fill="white")
        tiles.append(t)
    for n in range(0, len(tiles), 8):
        part = tiles[n:n + 8]
        sheet = Image.new("RGB", (1920, 352 * ((len(part) + 1) // 2)), "black")
        for i, t in enumerate(part):
            sheet.paste(t, (960 * (i % 2), 352 * (i // 2)))
        sheet.save(f"{OUT}/prep_{n // 8 + 1}.jpg", quality=90)
    print(f"prep sheets: {(len(tiles) + 7) // 8}", flush=True)


def paste_back(name, n):
    """The repainted 1024 crop -> scaled back to the crop size -> pasted into the untouched picture through the mask."""
    from PIL import Image
    import episode2 as ep
    rep = ep.newest(f"{OUT}/crop/{name}_r{n}{VAR}_*.png")
    pic = Image.open(src_of(name)).convert("RGB")
    w, h = pic.size
    _, crop = geometry(name, w, h)
    side = crop[2] - crop[0]
    small = Image.open(rep).convert("RGB").resize((side, side), Image.LANCZOS)
    layer = pic.copy()
    layer.paste(small, crop[:2])
    os.makedirs(f"{OUT}/full", exist_ok=True)
    Image.composite(layer, pic, full_mask(name, w, h)).save(f"{OUT}/full/{name}_r{n}{VAR}.png")


def swap_graph(tag, seed):
    """Full edit of the 1024 head crop: image 1 = the crop, image 2 = the target head, an empty 1024 latent, denoise 1."""
    import ep2_edit as e3
    g = e3.edit_graph(4)
    g.pop("ref3", None)
    g.pop("scale3", None)
    for enc in ("pos", "neg"):
        g[enc]["inputs"].pop("image3", None)
    g["ref1"]["inputs"]["image"] = f"any_pick_{tag}.png"
    g["ref2"]["inputs"]["image"] = REF_NAME
    g["pos"]["inputs"]["prompt"] = SWAP
    g["latent"]["inputs"].update({"width": SIDE, "height": SIDE})
    g["sampler"]["inputs"].update({"seed": seed, "denoise": 1.0})
    return g


def iid_graph(tag, seed, name, prefix):
    """SDXL + InstantID on the 1024 crop: face = the target head, keypoints = the crop's face, masked latent."""
    mood = MOODS.get(name.split("_")[1], "calm face")
    return {
        "ckpt": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "RealVisXL_V5.0_fp16.safetensors"}},
        "iid": {"class_type": "InstantIDModelLoader", "inputs": {"instantid_file": "ip-adapter.bin"}},
        "fa": {"class_type": "InstantIDFaceAnalysis", "inputs": {"provider": "CPU"}},
        "cn": {"class_type": "ControlNetLoader", "inputs": {"control_net_name": "instantid_controlnet.safetensors"}},
        "ref": {"class_type": "LoadImage", "inputs": {"image": REF_NAME}},
        "pick": {"class_type": "LoadImage", "inputs": {"image": f"any_pick_{tag}.png"}},
        "mask": {"class_type": "LoadImageMask", "inputs": {"image": f"any_mask_{tag}.png", "channel": "red"}},
        "pos": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["ckpt", 1], "text": IID_POS.format(mood=mood)}},
        "neg": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["ckpt", 1], "text": IID_NEG}},
        "apply": {"class_type": "ApplyInstantIDAdvanced", "inputs": {
            "instantid": ["iid", 0], "insightface": ["fa", 0], "control_net": ["cn", 0], "image": ["ref", 0],
            "model": ["ckpt", 0], "positive": ["pos", 0], "negative": ["neg", 0], "ip_weight": IID_IPW, "cn_strength": IID_CN,
            "start_at": 0.0, "end_at": 1.0, "noise": 0.0, "combine_embeds": "average", "image_kps": ["pick", 0],
            "mask": ["mask", 0]}},
        "enc": {"class_type": "VAEEncode", "inputs": {"pixels": ["pick", 0], "vae": ["ckpt", 2]}},
        "latent": {"class_type": "SetLatentNoiseMask", "inputs": {"samples": ["enc", 0], "mask": ["mask", 0]}},
        "sampler": {"class_type": "KSampler", "inputs": {
            "model": ["apply", 0], "positive": ["apply", 1], "negative": ["apply", 2], "latent_image": ["latent", 0],
            "seed": seed, "steps": 30, "cfg": 4.5, "sampler_name": "dpmpp_2m", "scheduler": "karras",
            "denoise": DENOISE}},
        "decode": {"class_type": "VAEDecode", "inputs": {"samples": ["sampler", 0], "vae": ["ckpt", 2]}},
        "paste": {"class_type": "ImageCompositeMasked", "inputs": {"destination": ["pick", 0], "source": ["decode", 0],
                                                                     "x": 0, "y": 0, "resize_source": False,
                                                                     "mask": ["mask", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["paste", 0], "filename_prefix": prefix}},
    }


def run(names):
    from PIL import Image
    import episode2 as ep
    import inpaint_any as ia
    os.makedirs("/data/input", exist_ok=True)
    Image.open(REF_SRC).convert("RGB").crop(REF_BOX).save(f"/data/input/{REF_NAME}")
    ia.MODES["realface"] = (PROMPT, DENOISE, False, REF_NAME)
    for name in names or BOXES:
        tag = prep_one(name)
        for n, seed in enumerate(SEEDS, 1):
            rn = f"r{n}{VAR}"
            if os.path.exists(f"{OUT}/full/{name}_{rn}.png"):
                continue
            if not ep.newest(f"{OUT}/crop/{name}_{rn}_*.png"):
                if METHOD == "swap":
                    g = swap_graph(tag, seed)
                elif METHOD == "iid":
                    g = iid_graph(tag, seed, name, f"lora/real2c_face/crop/{name}_{rn}")
                else:
                    g = ia.graph("realface", tag, seed, f"lora/real2c_face/crop/{name}_{rn}", "x")
                g["save"]["inputs"]["filename_prefix"] = f"lora/real2c_face/crop/{name}_{rn}"
                secs, _ = ep.story.run(g, 900)
                print(f"realface {name} {rn} d{DENOISE}: {secs:.1f} s", flush=True)
            paste_back(name, n)


def sheet():
    """Per picture one row: the original face crop | r1 | r2 (each 320 px), 8 rows per sheet."""
    from PIL import Image, ImageDraw
    rows = []
    for name in BOXES:
        files = [src_of(name)] + [f"{OUT}/full/{name}_r{n}{VAR}.png" for n in (1, 2)]
        if not all(os.path.exists(f) for f in files):
            continue
        row = Image.new("RGB", (960, 336), "black")
        for i, f in enumerate(files):
            pic = Image.open(f).convert("RGB")
            w, h = pic.size
            ell, _ = geometry(name, w, h)
            s = max(ell[2] - ell[0], ell[3] - ell[1]) * 1.1
            cx, cy = (ell[0] + ell[2]) / 2, (ell[1] + ell[3]) / 2
            row.paste(pic.crop((int(cx - s / 2), int(cy - s / 2), int(cx + s / 2), int(cy + s / 2))).resize((320, 320)),
                      (320 * i, 0))
        ImageDraw.Draw(row).text((4, 322), f"{name}   0 = original | 1 | 2", fill="white")
        rows.append(row)
    for n in range(0, len(rows), 8):
        part = rows[n:n + 8]
        out = Image.new("RGB", (1920, 336 * ((len(part) + 1) // 2)), "black")
        for i, r in enumerate(part):
            out.paste(r, (960 * (i % 2), 336 * (i // 2)))
        out.save(f"{OUT}/cmp{VAR}_{n // 8 + 1}.jpg", quality=92)
    print(f"compare sheets: {(len(rows) + 7) // 8} ({len(rows)} pictures)", flush=True)


def face_tile(f, name, size):
    from PIL import Image
    pic = Image.open(f).convert("RGB")
    w, h = pic.size
    ell, _ = geometry(name, w, h)
    s = max(ell[2] - ell[0], ell[3] - ell[1]) * 1.1
    cx, cy = (ell[0] + ell[2]) / 2, (ell[1] + ell[3]) / 2
    return pic.crop((int(cx - s / 2), int(cy - s / 2), int(cx + s / 2), int(cy + s / 2))).resize((size, size))


def test(names):
    """The denoise test: per picture one row — the TARGET head | the original | r1, r2 for each of TEST_VARS."""
    from PIL import Image, ImageDraw
    target = Image.open(REF_SRC).convert("RGB").crop(REF_BOX).resize((240, 240))
    rows = []
    for name in names:
        files = [src_of(name)] + [f"{OUT}/full/{name}_r{n}{v}.png" for v in TEST_VARS for n in (1, 2)]
        row = Image.new("RGB", (240 * (len(files) + 1), 256), "black")
        row.paste(target, (0, 0))
        for i, f in enumerate(files, 1):
            if os.path.exists(f):
                row.paste(face_tile(f, name, 240), (240 * i, 0))
        ImageDraw.Draw(row).text((4, 242), f"{name}: target | original | " + " | ".join(
            f"{v or 'mask 0.75'} r1 r2" for v in TEST_VARS), fill="white")
        rows.append(row)
    out = Image.new("RGB", (rows[0].width, 256 * len(rows)), "black")
    for i, r in enumerate(rows):
        out.paste(r, (0, 256 * i))
    out.save(f"{OUT}/test{os.environ.get('FACE_TEST_TAG', '_swap')}.jpg", quality=92)
    print(f"test sheet: {len(rows)} rows", flush=True)


def pick(pairs):
    """<name> <0|1|2> pairs -> lora/real2cf_gen/<name>_00001_.png (0 = the original). KEEP_AS_IS are copied too."""
    os.makedirs(PICKED, exist_ok=True)
    for name in KEEP_AS_IS:
        shutil.copyfile(src_of(name), f"{PICKED}/{name}_00001_.png")
    for name, n in zip(pairs[::2], pairs[1::2]):
        # n = 0 (original), 1/2 (r1/r2 of FACE_VAR) or e.g. 1_y75 / 2_w12 (that variant; the mixed picks of 17:55)
        src = src_of(name) if n == "0" else f"{OUT}/full/{name}_r{n}.png" if "_" in n else f"{OUT}/full/{name}_r{n}{VAR}.png"
        shutil.copyfile(src, f"{PICKED}/{name}_00001_.png")
    print(f"picked: {len(glob.glob(f'{PICKED}/*.png'))} pictures in {PICKED}", flush=True)


if __name__ == "__main__":
    act = sys.argv[1]
    {"prep": lambda: prep(), "run": lambda: run(sys.argv[2:]), "sheet": lambda: sheet(),
     "pick": lambda: pick(sys.argv[2:]), "test": lambda: test(sys.argv[2:])}[act]()
