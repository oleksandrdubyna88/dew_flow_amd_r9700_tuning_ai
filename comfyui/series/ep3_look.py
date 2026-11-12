"""Episode 3 look test (the owner chose LoRA slvra_v1 at 0.5 and the costume costume_3102; which LOOK for ep3?):
option B = the Arcane reference method of ep1/ep2 (Qwen-Image-Edit-2511, image 1 = composition/body, images 2-3 = the
young face); option C = the same + LoRA slvra_v1 at 0.5 on the edit model. Three ep3 shots, same seed, B and C side by side:
6 (her face, surprise, the dragon above), 13 (push-ups in the costume), 17 (lying on the bear-skin rug, stars).
Run inside the comfyui container:  python /opt/tests/ep3_look.py   -> series/ep3/look/<B|C>_<shot>_*.png
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ep2_v4 as v4  # noqa: E402
import episode2 as ep  # noqa: E402

COSTUME = ("She wears her training outfit exactly as in image 1: a grey one-shoulder wool crop top, a short skirt of three "
           "brown fur panels with a brown belt, fur-topped thigh-high brown boots and leather bracers. ")
SHOTS = {
    "s06_face": ("young_body_ref.png", "A TIGHT close-up of her face, looking up in surprise, eyes wide, lips parted; behind her "
                 "a cold twilight sky and the dark silhouette of a dragon; she wears a dark-green tunic."),
    "s13_pushups": ("ep3_costume.png", COSTUME + "She does a push-up on the stone floor of a castle yard lit by torches, seen "
                    "from a low side angle; her body straight and strong; full body."),
    "s17_glade": ("ep3_costume.png", COSTUME + "She lies on her back on a brown bear-skin rug in a moonlit forest glade beside a "
                  "small campfire and a silver stream, looking up at the stars; seen from above at an angle; full body."),
}


def main():
    shutil.copyfile(f"{v4.V4}/pick4_s4.png", "/data/input/young_body_ref.png")
    shutil.copyfile(ep.newest("/data/output/series/ep3/design/costume_3102_*.png"), "/data/input/ep3_costume.png")
    for name, (body, scene) in SHOTS.items():
        refs = (body, "ep2_ref_young_face_a.png", "ep2_ref_young_face_b.png")
        for look in ("B", "C"):
            if ep.newest(f"/data/output/series/ep3/look/{look}_{name}_*.png"):
                continue
            g = v4.round2_graph(4, 3601, refs, "", f"series/ep3/look/{look}_{name}")
            g["pos"]["inputs"]["prompt"] = (v4.SAME5 + v4.HAIR + "Take only the woman from image 1, not its background. "
                                            "Exactly one woman. " + scene)
            if look == "C":
                g["slvra"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["unet", 0], "lora_name":
                                                                               "slvra_v1.safetensors", "strength_model": 0.5}}
                g["shift"]["inputs"]["model"] = ["slvra", 0]
            secs, _ = ep.story.run(g, 900)
            print(f"look {look} {name}: {secs:.1f} s", flush=True)


if __name__ == "__main__":
    main()
