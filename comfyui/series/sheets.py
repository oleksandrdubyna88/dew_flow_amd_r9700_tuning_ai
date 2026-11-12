"""Review sheets for picking keyframes by eye: one row per shot, the old keyframe first, then the candidates, each labelled.
Run inside the comfyui container:  python /opt/tests/sheets.py
Writes series/elf_set2_arcane/young/sheet_ep1.png and series/ep2/v4/sheet_young_ep2.png.
"""
import glob
import os

from PIL import Image, ImageDraw

W = 480


def newest(pattern):
    found = sorted(glob.glob(pattern))
    return found[-1] if found else None


def sheet(rows, dest):
    cols = max(len(r) for r in rows)
    h = round(W * 704 / 1280)
    out = Image.new("RGB", (cols * W, len(rows) * h), "black")
    d = ImageDraw.Draw(out)
    for y, row in enumerate(rows):
        for x, (label, path) in enumerate(row):
            if path and os.path.exists(path):
                out.paste(Image.open(path).convert("RGB").resize((W, h)), (x * W, y * h))
            d.rectangle((x * W, y * h, x * W + 150, y * h + 22), fill="black")
            d.text((x * W + 4, y * h + 4), label, fill="white")
    out.save(dest)
    print("wrote", dest, flush=True)


E1 = "/data/output/series/elf_set2_arcane"
E2 = "/data/output/series/ep2"
sheet([[(f"ep1 s{k} old", newest(f"{E1}/key_s{k}_l100_d55_*.png"))] +
       [(f"s{k} c{n}", newest(f"{E1}/young/key_s{k}_c{n}_*.png")) for n in (31, 32)] for k in range(1, 7)],
      f"{E1}/young/sheet_ep1.png")
sheet([[(f"ep1 s{k} old", newest(f"{E1}/key_s{k}_l100_d55_*.png"))] +
       [(f"s{k} c{n}", newest(f"{E1}/young/key_s{k}_c{n}_*.png")) for n in (21, 22, 23)] for k in range(1, 7)],
      f"{E1}/young/sheet_ep1_r5.png")
sheet([[(f"ep1 s{k} old", newest(f"{E1}/key_s{k}_l100_d55_*.png"))] +
       [(f"s{k} c{n}", newest(f"{E1}/young/key_s{k}_c{n}_*.png")) for n in (41, 42, 43)] for k in range(1, 7)],
      f"{E1}/young/sheet_ep1_r6.png")
sheet([[(f"ep2 s{k} r5 pick", f"{E2}/v4/pick4_s{k}.png")] +
       [(f"s{k} c{n}", newest(f"{E2}/v4/key_s{k}_c{n}_*.png")) for n in (41, 42, 43)] for k in (3, 5, 6)] +
      [[("approved s4 (test)", f"{E2}/v4/pick4_s4.png")]], f"{E2}/v4/sheet_young_ep2_r6.png")
sheet([[(f"ep1 s{k} old", newest(f"{E1}/key_s{k}_l100_d55_*.png"))] +
       [(f"s{k} c{n}", newest(f"{E1}/young/key_s{k}_c{n}_*.png")) for n in (51, 52)] for k in range(1, 7)],
      f"{E1}/young/sheet_ep1_r7.png")
rows = []
for k in (3, 5, 6, 7):
    old = f"{E2}/v4/pick_s7.png" if k == 7 else newest(f"{E2}/edit/key_s{k}_*.png")
    rows.append([(f"ep2 s{k} old", old)] + [(f"s{k} c{n}", newest(f"{E2}/v4/key_s{k}_c{n}_*.png")) for n in (31, 32, 21, 22, 23)])
rows.append([("approved s4 (test)", f"{E2}/v4/pick4_s4.png"), ("young face a", f"{E2}/refs/ref_young_face_a.png")])
sheet(rows, f"{E2}/v4/sheet_young_ep2.png")
