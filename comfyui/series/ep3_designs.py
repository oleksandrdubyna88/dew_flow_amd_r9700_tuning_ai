"""Episode 3 design sheet (EP3_SCRIPT.md v2): the castle, the dragon, the relics, the training automaton, the night glade
(text to image: Qwen-Image 2512 fp8 + Lightning 4 steps) and her training costume (Qwen-Image-Edit-2511 with the approved
references, the method of ep2 v4: image 1 = the approved body keyframe, images 2-3 = the young face). 3 seeds each, for
the owner to approve before any clip. ORIGINAL designs only (no known castle, weapon or robot).
Run inside the comfyui container:  python /opt/tests/ep3_designs.py   -> series/ep3/design/<name>_<seed>_*.png
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ep2_v4 as v4  # noqa: E402
import episode2 as ep  # noqa: E402

ARC = ", painted Arcane animation style: painterly textures, cinematic lighting"
DESIGNS = {
    "castle": ("An abandoned gothic castle with many tall slender spires, stone bridges between towers and one broken tower, "
               "standing on a cliff above a dark lake; ivy, broken stained-glass windows, crows; cold twilight sky with the "
               "last amber light on the horizon; a winding road leads to the gate; wide aerial view"),
    "dragon": ("A large dragon with dark slate-grey scales, glowing amber eyes and torn leathery wings perched on top of a broken "
               "stone tower of a gothic castle, wings half open, about to take off, dust and falling roof slates, cold "
               "twilight sky; low angle"),
    "relics": ("On a stone altar in a dim vaulted gothic hall, under a shaft of dusty light: a long sword with a dark blade and a "
               "worn leather grip, and beside it a short wooden staff topped with a glowing violet crystal; stone pillars, "
               "dust in the air; medium shot"),
    # v2 (2026-11-10): v1 drew a skull face (too close to a known film robot) -> a visor head, no face, no skull
    "automaton": ("A tall slender training automaton of dark blued steel plates and brass joints: exposed cables and small pistons, a "
                  "smooth egg-shaped head like a fencing mask with ONE horizontal glowing blue visor slit, no face, no skull, no teeth, holding a "
                  "blunt practice sword, standing in a stone castle yard at dawn; full body"),
    # v2: v1 drew a LIVE bear -> a flat fur rug, no animal
    "glade": ("A small forest glade at night under a sky full of stars: a flat brown fur rug made from a bear pelt spread on the "
              "grass like a blanket (no living animal), a small campfire burns beside it, a silver stream runs past, tall dark "
              "pines around; moonlight and warm firelight; wide shot"),
}
COSTUME = ("Draw a NEW scene. The woman is the one from image 1, and her FACE is exactly the face of image 2 and image 3: a "
           "young woman of about twenty with long silver-white hair and one thin golden strand. Exactly one woman. She now "
           "wears a training outfit: a grey-brown wool top over one shoulder, a short skirt above the knee made of three "
           "pieces of brown fur, and thigh-high brown leather boots; a fit athletic figure with toned arms and light abs; "
           "tasteful, like a film. She stands in a stone castle yard at dawn holding a sword; full body; painted Arcane "
           "animation style. Take only the woman from image 1, not her clothes and not the background.")
SEEDS = tuple(int(s) for s in os.environ.get("EP3_SEEDS", "3101,3102,3103").split(","))


def main():
    out = "series/ep3/design"
    for name, text in DESIGNS.items():
        for seed in SEEDS:
            if ep.newest(f"/data/output/{out}/{name}_{seed}_*.png"):
                continue
            g = ep.story.qwen_keyframe_wf(1, {"key": text + ARC, "seed": seed})
            g["save"]["inputs"]["filename_prefix"] = f"{out}/{name}_{seed}"
            secs, _ = ep.story.run(g, 900)
            print(f"design {name} {seed}: {secs:.1f} s", flush=True)
    shutil.copyfile(f"{v4.V4}/pick4_s4.png", "/data/input/young_body_ref.png")
    refs = ("young_body_ref.png", "ep2_ref_young_face_a.png", "ep2_ref_young_face_b.png")
    for seed in SEEDS:
        if ep.newest(f"/data/output/{out}/costume_{seed}_*.png"):
            continue
        g = v4.round2_graph(4, seed, refs, "", f"{out}/costume_{seed}")
        g["pos"]["inputs"]["prompt"] = COSTUME
        secs, _ = ep.story.run(g, 900)
        print(f"design costume {seed}: {secs:.1f} s", flush=True)


if __name__ == "__main__":
    main()
