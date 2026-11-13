"""Touch-ups of approved ep3 picks (the owner, 2026-11-10: "the clothes are great; the shadow by the nose on s11 is in the
way; the ears differ on half the shots — they must be ordinary, as on s14 and s15"). The edit model keeps the pick
(image 1) and changes only the named detail; images 2-3 are the approved young face (normal human ears). No LoRA: the
pointed ears may come from slvra_v1. Two candidates per shot -> series/ep3/keys/s<NN>_t<n>_*.png.
Run inside the comfyui container:  python /opt/tests/touchup.py <shot>...
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ep3_keys as k3  # noqa: E402
import episode2 as ep  # noqa: E402

KEEP = ("Image 1 is the picture to keep EXACTLY: the same scene, pose, body, clothes, colours, camera, framing, light and "
        "the same face. Exactly the same people as in image 1; do not add any person or creature. ")
EARS = ("Change ONLY her ears: small, rounded, ordinary HUMAN ears like the face in image 2 — NOT pointed, NOT elf ears; "
        "where her hair covers her ears, it keeps covering them. ")
FIX = {
    5: ("Image 1 is the picture to keep EXACTLY: the same castle, sky, light, camera and the one large dragon. Change ONLY "
        "this: remove the small second dragon low in the picture and fill its place with the castle wall and the sky "
        "behind it. Only ONE dragon in the picture."),
    11: KEEP + ("Change ONLY her skin by her nose: remove the dark reddish shadow beside and under her nose; the skin there "
                "is clean, even and smooth like the face in image 2. Her ears stay ordinary human ears."),
}
# Named touch-ups ("<shot>:<name>" on the command line): (prompt, first candidate number, seed offset).
NAMED = {
    # the owner 2026-11-10: the automaton holds a sword and a shield; a drone above records the fight
    "robot": (("Image 1 is the picture to keep: the same castle yard, the same woman with the same face, pose and clothes, "
               "the same automaton body, camera and light. Exactly one woman and one automaton. Change: the automaton holds "
               "a round steel shield in its left hand, raised, and her sword strikes the shield in the shower of orange "
               "sparks; in its right hand it holds a long steel sword drawn back to swing. Add above them in the sky a small "
               "black quad-rotor camera drone hovering, its red recording light on and its lens pointed at the fight. "
               "Her ears are small, rounded, ordinary HUMAN ears like the face in image 2, NOT pointed."), 3, 500),
}
SEEDS = (3801, 3802)


def touch(arg):
    k, _, named = arg.partition(":")
    k = int(k)
    src = f"/data/output/series/ep3/picks/s{k:02d}.png"
    name = f"ep3_touch_s{k:02d}.png"
    shutil.copyfile(src, f"/data/input/{name}")
    text, first, off = NAMED[named] if named else (FIX.get(k, KEEP + EARS), 1, 0)
    prompt = text + " Painted Arcane animation style."
    for n, seed in enumerate((s + off for s in SEEDS), first):
        prefix = f"{k3.OUT}/s{k:02d}_t{n}"
        if ep.newest(f"/data/output/{prefix}_*.png"):
            continue
        secs = k3.edit_image((name, "ep2_ref_young_face_a.png", "ep2_ref_young_face_b.png"), prompt, seed + k * 10,
                             prefix, False)
        print(f"ep3 touch s{k:02d} t{n}: {secs:.1f} s", flush=True)


if __name__ == "__main__":
    for a in sys.argv[1:]:
        touch(a)
