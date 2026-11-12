"""One sword everywhere (the owner, 2026-11-10: "the sword differs too; it must be this style everywhere" — the s09 sword:
a dark steel hilt with a curved, forward-bent crossguard, a long dark grip, a pommel, a straight blade with a dark
engraved fuller). Masked repaint like inpaint_ears.py: a thick line mask along each sword (hilt -> tip, placed by eye on
swords_grid.png), image 2 = a crop of the s09 sword, only the mask is repainted and pasted back onto the untouched pick.
No blur fill: the old sword keeps the position and angle; the denoise sets how much of its look is replaced.
Run:  python3 /opt/tests/inpaint_sword.py prep <shot>...  (any container: masks + preview sheet)
      python  /opt/tests/inpaint_sword.py run <shot>...   (inside comfyui) -> series/ep3/keys/s<NN>_w<n>_*.png
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

E3 = "/data/output/series/ep3"
REF = (9, (0.16, 0.6, 0.37, 1.0))  # the owner's reference sword: a crop of pick s09
# shot: (hilt point, tip point, mask width in px) as fractions of the picture
SWORDS = {
    7: ((0.125, 0.66), (0.53, 0.755), 34),
    8: ((0.255, 0.83), (0.72, 1.02), 62),
    11: ((0.195, 0.6), (-0.01, 1.0), 78),
    17: ((0.205, 0.522), (0.56, 0.452), 40),
}
PROMPT = ("Image 1 is the picture to keep. The sword in image 1 becomes exactly the sword of image 2: a dark steel hilt "
          "with a curved crossguard whose two arms bend forward toward the blade, a long dark grip and a dark pommel, and "
          "a straight double-edged steel blade with a dark engraved fuller. The same position, angle, length and size as "
          "the sword in image 1; her hand holds it the same way. Painted Arcane animation style.")
RUNS = ((3911, 0.8), (3912, 0.8), (3913, 0.95), (3914, 0.95))  # (seed, denoise) -> w1..w4


def prep(k, inp="/data/input"):
    from PIL import Image, ImageDraw, ImageFilter
    pick = Image.open(f"{E3}/picks/s{k:02d}.png").convert("RGB")
    w, h = pick.size
    (hx, hy), (tx, ty), width = SWORDS[k]
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.line(((hx * w, hy * h), (tx * w, ty * h)), fill=255, width=width)
    r = width * 1.1  # the crossguard and the pommel are wider than the blade
    d.ellipse((hx * w - r, hy * h - r, hx * w + r, hy * h + r), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(4))
    os.makedirs(inp, exist_ok=True)
    pick.save(f"{inp}/ep3_sw_pick_s{k:02d}.png")
    Image.merge("RGB", (mask, mask, mask)).save(f"{inp}/ep3_sw_mask_s{k:02d}.png")
    rk, (x0, y0, x1, y1) = REF
    ref = Image.open(f"{E3}/picks/s{rk:02d}.png").convert("RGB")
    rw, rh = ref.size
    ref.crop((int(x0 * rw), int(y0 * rh), int(x1 * rw), int(y1 * rh))).save(f"{inp}/ep3_sword_ref.png")
    return Image.composite(Image.new("RGB", (w, h), (255, 0, 0)), pick, mask.point(lambda v: v // 2))


def graph(k, seed, denoise, n):
    import ep2_edit as e3
    g = e3.edit_graph(4)
    g.pop("ref3", None)
    g.pop("scale3", None)
    for enc in ("pos", "neg"):
        g[enc]["inputs"].pop("image3", None)
    g["ref1"]["inputs"]["image"] = f"ep3_sw_pick_s{k:02d}.png"
    g["ref2"]["inputs"]["image"] = "ep3_sword_ref.png"
    g["pos"]["inputs"]["prompt"] = PROMPT
    g["mask"] = {"class_type": "LoadImageMask", "inputs": {"image": f"ep3_sw_mask_s{k:02d}.png", "channel": "red"}}
    g["enc"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["ref1", 0], "vae": ["vae", 0]}}
    g["latent"] = {"class_type": "SetLatentNoiseMask", "inputs": {"samples": ["enc", 0], "mask": ["mask", 0]}}
    g["sampler"]["inputs"].update({"seed": seed, "denoise": denoise})
    g["paste"] = {"class_type": "ImageCompositeMasked", "inputs": {"destination": ["ref1", 0], "source": ["decode", 0],
                                                                     "x": 0, "y": 0, "resize_source": False,
                                                                     "mask": ["mask", 0]}}
    g["save"]["inputs"].update({"images": ["paste", 0], "filename_prefix": f"series/ep3/keys/s{k:02d}_w{n}"})
    return g


def run(k):
    import episode2 as ep
    prep(k)
    for n, (seed, denoise) in enumerate(RUNS, 1):
        if ep.newest(f"{E3}/keys/s{k:02d}_w{n}_*.png"):
            continue
        secs, _ = ep.story.run(graph(k, seed + k, denoise, n), 900)
        print(f"ep3 sword s{k:02d} w{n} (denoise {denoise}): {secs:.1f} s", flush=True)


if __name__ == "__main__":
    shots = [int(a) for a in sys.argv[2:]]
    if sys.argv[1] == "prep":
        from PIL import Image
        tiles = [prep(k, "/tmp/swprep").resize((640, 352)) for k in shots]
        out = Image.new("RGB", (640 * len(tiles), 352))
        for i, t in enumerate(tiles):
            out.paste(t, (640 * i, 0))
        out.save(f"{E3}/swords_masks_preview.png")
        print("preview", len(tiles))
    else:
        for k in shots:
            run(k)
