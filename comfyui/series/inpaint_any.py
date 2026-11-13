"""Masked repaint of any keyframe (2026-11-10, episode 1 v3 re-check with the episode 3 rules): the same method as
inpaint_ears.py / inpaint_sword.py, for a picture given by path.
  ear  - a pointed ear -> hair: blur fill inside the mask, a hair-only prompt (positive words only), denoise 0.85
  face - an older/other face -> her approved young face: image 2 = the young face reference, no blur fill (the head
         angle and light stay), denoise 0.75
The result is pasted back onto the untouched picture (only the mask changes).
Run:  python3 /opt/tests/inpaint_any.py prep <mode> <src.png> <out prefix> <x0,y0,x1,y1>...   (preview only, any container)
      python  /opt/tests/inpaint_any.py run  <mode> <src.png> <out prefix> <x0,y0,x1,y1>...   (inside comfyui)
  -> <out prefix>_<n>_*.png (two seeds) ; the preview -> <out prefix>_mask_preview.png
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

MODES = {
    "ear": ("Long straight silver-white hair falls smoothly over the side of her head and down past her neck, the same hair "
            "as around it, the same light. Painted Arcane animation style.", 0.85, True, None),
    "face": ("Her face is exactly the young face of image 2: a young woman of about twenty, soft round cheeks, big eyes, a "
             "small straight nose; the same head angle, expression and light as in image 1. Painted Arcane animation style.",
             0.75, False, "ep2_ref_young_face_a.png"),
}
SEEDS = (4101, 4102)


def prep(mode, src, prefix, boxes, inp="/data/input"):
    from PIL import Image, ImageDraw, ImageFilter
    pic = Image.open(src).convert("RGB")
    w, h = pic.size
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    for x0, y0, x1, y1 in boxes:
        px, py = (x1 - x0) * 0.25, (y1 - y0) * 0.25
        d.ellipse(((x0 - px) * w, (y0 - py) * h, (x1 + px) * w, (y1 + py) * h), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(4))
    fill = pic.copy()
    if MODES[mode][2]:
        fill.paste(pic.filter(ImageFilter.GaussianBlur(18)), (0, 0), mask)
    tag = os.path.basename(prefix)
    os.makedirs(inp, exist_ok=True)
    pic.save(f"{inp}/any_pick_{tag}.png")
    fill.save(f"{inp}/any_fill_{tag}.png")
    Image.merge("RGB", (mask, mask, mask)).save(f"{inp}/any_mask_{tag}.png")
    prev = Image.composite(Image.new("RGB", (w, h), (255, 0, 0)), pic, mask.point(lambda v: v // 2))
    prev.save(f"/data/output/{prefix}_mask_preview.png")
    return tag


def graph(mode, tag, seed, prefix, n):
    import ep2_edit as e3
    prompt, denoise, _, ref = MODES[mode]
    g = e3.edit_graph(4)
    for i in ((3,) if ref else (2, 3)):
        g.pop(f"ref{i}", None)
        g.pop(f"scale{i}", None)
        for enc in ("pos", "neg"):
            g[enc]["inputs"].pop(f"image{i}", None)
    g["ref1"]["inputs"]["image"] = f"any_fill_{tag}.png"
    if ref:
        g["ref2"]["inputs"]["image"] = ref
    g["pos"]["inputs"]["prompt"] = prompt
    g["orig"] = {"class_type": "LoadImage", "inputs": {"image": f"any_pick_{tag}.png"}}
    g["mask"] = {"class_type": "LoadImageMask", "inputs": {"image": f"any_mask_{tag}.png", "channel": "red"}}
    g["enc"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["ref1", 0], "vae": ["vae", 0]}}
    g["latent"] = {"class_type": "SetLatentNoiseMask", "inputs": {"samples": ["enc", 0], "mask": ["mask", 0]}}
    g["sampler"]["inputs"].update({"seed": seed, "denoise": denoise})
    g["paste"] = {"class_type": "ImageCompositeMasked", "inputs": {"destination": ["orig", 0], "source": ["decode", 0],
                                                                     "x": 0, "y": 0, "resize_source": False,
                                                                     "mask": ["mask", 0]}}
    g["save"]["inputs"].update({"images": ["paste", 0], "filename_prefix": f"{prefix}_{n}"})
    return g


def main(args):
    action, mode, src, prefix = args[:4]
    boxes = [tuple(float(v) for v in b.split(",")) for b in args[4:]]
    if action == "prep":
        prep(mode, src, prefix, boxes, "/tmp/anyprep")
        print("preview", prefix)
        return
    import episode2 as ep
    tag = prep(mode, src, prefix, boxes)
    for n, seed in enumerate(SEEDS, 1):
        if ep.newest(f"/data/output/{prefix}_{n}_*.png"):
            continue
        secs, _ = ep.story.run(graph(mode, tag, seed, prefix, n), 900)
        print(f"repaint {mode} {tag} {n}: {secs:.1f} s", flush=True)


if __name__ == "__main__":
    main(sys.argv[1:])
