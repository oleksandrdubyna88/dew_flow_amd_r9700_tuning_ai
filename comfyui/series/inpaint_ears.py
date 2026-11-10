"""Masked repaint of the pointed ears in ep3 picks (the owner, 2026-11-10: "ordinary ears, as on s14 s15").
Why masks: a whole-picture edit that says "not pointed, not elf ears" DRAWS pointed ears (touchup.py t1/t2 made them
longer) — the model draws what the prompt names. Here the ear area (boxes placed by eye on grid_crop.py sheets) is first
filled with a blur of the picture (the model no longer sees the ear), then only that area is repainted as hair by the
edit model, with a prompt that does not name ears, and pasted back onto the untouched pick.
Run:  python3 /opt/tests/inpaint_ears.py prep <shot>...   (any container: masks, fills, preview sheet)
      python  /opt/tests/inpaint_ears.py run <shot>...    (inside comfyui) -> series/ep3/keys/s<NN>_e<n>_*.png
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

E3 = "/data/output/series/ep3"
# ear boxes as fractions of the picture (x0, y0, x1, y1), read from ears_grid1/2.png
BOXES = {
    8: [(0.37, 0.18, 0.405, 0.26)],
    9: [(0.376, 0.255, 0.408, 0.31), (0.465, 0.255, 0.497, 0.31)],
    16: [(0.424, 0.07, 0.454, 0.13)],
    17: [(0.314, 0.16, 0.35, 0.24)],
    18: [(0.172, 0.26, 0.235, 0.32)],
    19: [(0.19, 0.145, 0.222, 0.215)],
    11: [(0.43, 0.255, 0.468, 0.293)],  # not an ear: the dark reddish shadow beside and under her nose (the owner)
    # not ears either (the owner, 2026-11-10, OPEN_s05_s16_s20.png): s05 the small second dragon, s20 four small flames
    # burning on the fur rug
    5: [(0.354, 0.772, 0.488, 0.846), (0.4017, 0.8183, 0.4483, 0.8917)],  # wings, body (the big dragon leg at x>0.51)
    20: [(0.585, 0.2, 0.623, 0.28), (0.722, 0.255, 0.77, 0.368), (0.817, 0.516, 0.846, 0.628), (0.418, 0.94, 0.456, 1.0)],
}
PROMPT = ("Long straight silver-white hair falls smoothly over the side of her head and down past her neck, the same hair "
          "as around it, the same light. Painted Arcane animation style.")
# per shot: (prompt, denoise, blur-fill first?) — s11 keeps its nose shape, so no blur fill and a lower denoise
SPECIAL = {11: ("Her small straight nose and the clean, even, smooth skin of a young face around it, soft even light, no "
                "shadow. Painted Arcane animation style.", 0.6, False),
           # positive words only: name what fills the place, never the thing to remove
           5: ("A grey cloudy evening sky above the dark stone castle wall with its square battlements, the same light. "
               "Painted Arcane animation style.", 0.9, True),
           20: ("Thick dark-brown bear fur, soft and shaggy, lit by warm orange light from the side, the same fur as "
                "around it. Painted Arcane animation style.", 0.9, True)}
SEEDS = (3901, 3902)
DENOISE = 0.85
# EAR_PASS=2: a second pass on the current pick (which is already a pass-1 result) -> candidates e3/e4. s20: two thin
# orange streaks were left (the pass-1 prompt said "lit by warm orange light"), one above the third mask.
if os.environ.get("EAR_PASS") == "2":
    BOXES = {20: [(0.73, 0.247, 0.787, 0.36), (0.806, 0.472, 0.835, 0.576)]}
    SPECIAL = {20: ("Thick dark-brown bear fur in soft shadow, the same fur as around it. Painted Arcane animation style.",
                    0.9, True)}
    SEEDS = (3921, 3922)
FIRST = 3 if os.environ.get("EAR_PASS") == "2" else 1


def prep(k, inp="/data/input"):
    from PIL import Image, ImageDraw, ImageFilter
    pick = Image.open(f"{E3}/picks/s{k:02d}.png").convert("RGB")
    w, h = pick.size
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    for x0, y0, x1, y1 in BOXES[k]:
        px, py = (x1 - x0) * 0.25, (y1 - y0) * 0.25  # a 25 % margin around the ear
        d.ellipse(((x0 - px) * w, (y0 - py) * h, (x1 + px) * w, (y1 + py) * h), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(4))
    fill = pick.copy()
    if SPECIAL.get(k, (None, None, True))[2]:
        fill.paste(pick.filter(ImageFilter.GaussianBlur(18)), (0, 0), mask)
    os.makedirs(inp, exist_ok=True)
    pick.save(f"{inp}/ep3_ear_pick_s{k:02d}.png")
    fill.save(f"{inp}/ep3_ear_fill_s{k:02d}.png")
    Image.merge("RGB", (mask, mask, mask)).save(f"{inp}/ep3_ear_mask_s{k:02d}.png")
    red = Image.new("RGB", (w, h), (255, 0, 0))
    preview = Image.composite(red, pick, mask.point(lambda v: v // 2))
    return preview


def graph(k, seed, n):
    import ep2_edit as e3
    g = e3.edit_graph(4)
    for i in (2, 3):
        g.pop(f"ref{i}", None)
        g.pop(f"scale{i}", None)
        for enc in ("pos", "neg"):
            g[enc]["inputs"].pop(f"image{i}", None)
    g["ref1"]["inputs"]["image"] = f"ep3_ear_fill_s{k:02d}.png"
    prompt, denoise, _ = SPECIAL.get(k, (PROMPT, DENOISE, True))
    g["pos"]["inputs"]["prompt"] = prompt
    g["orig"] = {"class_type": "LoadImage", "inputs": {"image": f"ep3_ear_pick_s{k:02d}.png"}}
    g["mask"] = {"class_type": "LoadImageMask", "inputs": {"image": f"ep3_ear_mask_s{k:02d}.png", "channel": "red"}}
    g["enc"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["ref1", 0], "vae": ["vae", 0]}}
    g["latent"] = {"class_type": "SetLatentNoiseMask", "inputs": {"samples": ["enc", 0], "mask": ["mask", 0]}}
    g["sampler"]["inputs"].update({"seed": seed, "denoise": denoise})
    g["paste"] = {"class_type": "ImageCompositeMasked", "inputs": {"destination": ["orig", 0], "source": ["decode", 0],
                                                                     "x": 0, "y": 0, "resize_source": False,
                                                                     "mask": ["mask", 0]}}
    g["save"]["inputs"].update({"images": ["paste", 0], "filename_prefix": f"series/ep3/keys/s{k:02d}_e{n}"})
    return g


def run(k):
    import episode2 as ep
    prep(k)
    for n, seed in enumerate(SEEDS, FIRST):
        if ep.newest(f"{E3}/keys/s{k:02d}_e{n}_*.png"):
            continue
        secs, _ = ep.story.run(graph(k, seed + k, n), 900)
        print(f"ep3 ears s{k:02d} e{n}: {secs:.1f} s", flush=True)


if __name__ == "__main__":
    shots = [int(a) for a in sys.argv[2:]]
    if sys.argv[1] == "prep":
        from PIL import Image
        tiles = []
        for k in shots:
            p = prep(k, "/tmp/earprep")
            w, h = p.size
            x0 = max(0.0, min(b[0] for b in BOXES[k]) - 0.08)
            y0 = max(0.0, min(b[1] for b in BOXES[k]) - 0.12)
            x1 = min(1.0, max(b[2] for b in BOXES[k]) + 0.08)
            y1 = min(1.0, max(b[3] for b in BOXES[k]) + 0.12)
            tiles.append(p.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h))).resize((400, 400)))
        out = Image.new("RGB", (400 * len(tiles), 400))
        for i, t in enumerate(tiles):
            out.paste(t, (400 * i, 0))
        out.save(f"{E3}/ears_masks_preview.png")
        print("preview", len(tiles))
    else:
        for k in shots:
            run(k)
