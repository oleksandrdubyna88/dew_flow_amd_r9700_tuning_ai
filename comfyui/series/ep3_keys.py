"""Episode 3 keyframes (EP3_SCRIPT.md v2), look C (the owner, 2026-11-10): the Arcane reference method (Qwen-Image-Edit-2511,
the approved young face) + the character LoRA slvra_v1 at 0.5. Two candidates per shot, for review before any clip.

Kinds:
  scene  - no hero: Qwen-Image 2512 + Lightning from text (the approved designs' words)
  castle - the approved castle design + the Humvee added by the edit model (no face)
  copy   - an already approved picture (shot 6 = the look test C face)
  pose   - step 1: the pose from text (Qwen-Image 2512 + Lightning + slvra_v1 0.5 + the outfit words);
           step 2: the edit model (+ slvra_v1 0.5) keeps image 1 (= step 1) and gives her the approved face (image 2)
           and the outfit (image 3: the costume design in Acts 3-4) — exactly one woman.
Run inside the comfyui container:  python /opt/tests/ep3_keys.py [shot ids...]  -> series/ep3/keys/s<NN>_<cand>_*.png
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ep2_v4 as v4  # noqa: E402
import episode2 as ep  # noqa: E402

story = ep.story
OUT = "series/ep3/keys"
ARC = ", painted Arcane animation style: painterly textures, cinematic lighting"
LORA = ("slvra_v1.safetensors", 0.5)
TRIG = "slvra, a young woman of about twenty with long straight silver-white hair and one thin golden strand, "
TUNIC = "she wears a dark-green tunic with brown trim, a brown belt, brown leather bracers and boots. "
# Set 3 (the owner, 2026-11-10: "the clothes differ everywhere, they must be as on s15"): sleeveless, bare arms and
# midriff, nothing green — the set-1 edits turned the top green because v4.HAIR says "Her tunic is dark GREEN".
COSTUME = ("she wears a SLEEVELESS grey wool crop top that leaves her arms, shoulders and midriff bare, a short skirt of "
           "brown fur panels on a wide brown leather belt, brown leather thigh-high boots with thick fur cuffs and brown "
           "leather bracers; her arms are bare from the shoulder to the bracers. ")
# Positive words only (2026-11-10): the edit model draws what a prompt names, even after "no"/"NOT" — "no sleeves" gave
# sleeves, "covers her ears" and "NOT pointed" gave pointed ears (see inpaint_ears.py).
HAIR_ONLY = ("Her long silver-white hair is loose and falls smoothly over the sides of her head; one thin strand of her "
             "hair is dyed golden and hangs beside her cheek. ")
DRAGON = "a large dragon with dark slate-grey scales, glowing amber eyes and torn leathery wings"
AUTOMATON = ("a tall training automaton of dark blued steel plates and brass joints with a smooth fencing-mask head and one "
             "glowing blue visor slit")

SHOTS = {
    # 1: sets 8/9 (the owner, 2026-11-10: the car must drive INTO the castle; "with its headlights on" turned its front
    # to the camera, so the clip drove it out of the castle) — seen from behind, positive words only.
    1: ("castle", "Image 1 is the scene to keep: the castle, the lake, the road, the light and the camera. Add the vehicle from "
        "image 2 — a wide low boxy military Humvee — small on the winding road just before the castle gate, seen from "
        "BEHIND: its rear with two small red tail lights faces the camera and its front points at the open gate; it drives "
        "away from the camera into the castle. Keep everything else exactly as in image 1."),
    # v2 (2026-11-10): v1 became a face close-up -> "seen from behind, whole body small in the frame"
    2: ("pose", "Wide shot from BEHIND and a little to the side, her whole body small in the frame: she walks away from the camera across an empty cobbled castle courtyard at "
        "twilight — a dry stone fountain, fallen torn banners, ivy — looking up at a broken tower above her; cold blue "
        "twilight. " + TUNIC),
    3: ("scene_hero", "Over-the-shoulder low angle: in the lower left foreground the dark silhouette of her shoulder and silver "
        "hair, seen from behind; above, on a broken stone tower of a gothic castle, " + DRAGON + " spreads its wings to take "
        "off; roof slates fall; cold twilight sky."),
    4: ("scene", "Seen from a castle courtyard looking up: " + DRAGON + " flies in a wide banking turn around the broken tower "
        "of a gothic castle with many spires, wings spread; cold twilight sky with the last amber light."),
    # v2: v1 drew a second small dragon -> "exactly one dragon"
    5: ("scene", "Exactly ONE dragon in the sky, no other dragons and no birds. Seen from a castle courtyard looking up: " + DRAGON + " passes behind the broken tower on its far side in a "
        "second wide circle, wings spread, smaller in the distance; cold twilight sky."),
    6: ("copy", "series/ep3/look/C_s06_face"),
    7: ("pose", "In a dim vaulted gothic hall a shaft of dusty light falls on a stone altar with a long sword with a dark blade "
        "and a short wooden staff topped with a glowing violet crystal; she stands close to the altar, three-quarter view, "
        "looking down at them. " + TUNIC),
    8: ("pose", "Three-quarter waist-level view: her hands rest ON the grips — her LEFT hand on the sword's leather grip, her "
        "RIGHT hand on the short staff with the glowing violet crystal — both still lying on the stone altar; her face in "
        "profile above, intent; dim hall, dusty light. " + TUNIC),
    9: ("pose", "Wide view of a vaulted gothic hall: she stands in the middle holding the sword in her left hand and the crystal "
        "staff in her right; a glow of many colours (cyan, gold, violet) swirls around her and a dome of pure black darkness "
        "closes over her, a thin coloured rim at its edge. " + TUNIC),
    10: ("pose", "Low angle from the stone floor: she floats a little above the floor — her boots a hand's width above it with "
         "a soft shadow below — inside a black dome with faint violet lightning; full body. " + TUNIC),
    11: ("pose", "Medium shot: she floats in the air, her head tilted only slightly back so her whole face is seen from the "
         "front, eyes closed, calm, arms spread wide — the sword in her left "
         "hand, the crystal staff glowing violet in her right — silver hair floating; a dark vaulted ceiling above; violet "
         "light. " + TUNIC),
    12: ("pose", "Extreme close-up of her upper face: her eyes wide open, small orange embers of fire glowing inside the irises, "
         "warm light on her face, darkness around."),
    13: ("scene", "Macro close-up of an eye filling the whole frame: the iris glows like burning fire, orange and gold flames "
         "swirl around the black pupil."),
    14: ("pose_c", "Low side view: she does a push-up on the stone floor of a castle yard lit by torches at dawn, body "
         "straight, arms strong; full body. " + COSTUME),
    15: ("pose_c", "Rear three-quarter view: she hangs from an iron beam under a wooden roof and pulls herself up, her back "
         "and shoulders strong, her face in profile at the top. " + COSTUME),
    # 16: set 6/7 (the owner, 2026-11-10): the set-3 pick came out at night; the script says sunrise.
    16: ("pose_c", "Side view at SUNRISE: she runs along the top of a castle wall; the low golden sun just above the "
         "horizon behind the castle spires, a bright warm sky with orange and pink clouds, golden morning light on her "
         "and on the stones; battlements beside her; the fur panels of her skirt part with her stride; full body. "
         + COSTUME),
    # 17: the owner 2026-11-10: the automaton holds a sword in one hand and a shield in the other; a drone above records.
    17: ("pose_c", "Mid-action: she lunges and strikes with her sword the raised round steel shield of " + AUTOMATON +
         ", which holds the shield in its left hand and a long steel sword drawn back in its right hand; a shower of orange "
         "sparks where her blade hits the shield; above them a small black quad-rotor camera drone hovers, its red "
         "recording light on and its lens pointed at the fight; a castle yard at dawn; full bodies. " + COSTUME),
    18: ("pose_c", "Wide view of a moonlit forest glade: she lies on her back on a flat brown bear-skin rug on the grass, "
         "looking up at the stars; a small campfire burns beside her, a silver stream runs past; tall dark pines. " + COSTUME),
    19: ("pose_c", "The same moonlit glade seen from the other side, a quarter turn around: the silver stream in front, the "
         "campfire behind her; she lies on the bear-skin rug, her boots toward the camera. " + COSTUME),
    20: ("pose_c", "High angle close view along her legs as she lies on the brown bear-skin rug: her fur-topped thigh-high "
         "boots, the edge of the fur skirt, firelight flickering on the leather; night. " + COSTUME),
    21: ("pose_c", "Overhead view from straight above: she lies on her back on the bear-skin rug, silver hair spread on the "
         "fur, looking up, firelight on one side; her whole body in frame. " + COSTUME),
    22: ("scene", "High aerial view above the treetops at night: far below a tiny campfire glows in a small forest glade with a "
         "tiny figure lying beside it; dark pine forest all around; the sky full of stars above."),
    23: ("scene", "A night sky full of stars and a faint milky way above the dark tops of pine trees."),
}
SET = int(os.environ.get("EP3_SET", "1"))  # set n = seeds 3701+2(n-1).. and candidates c(2n-1), c(2n)
SEEDS = (3699 + 2 * SET, 3700 + 2 * SET)
C0 = 2 * (SET - 1)
# EP3_POSE_FROM=m: reuse the step-1 pose pictures of set m (the compositions already reviewed) and only redo the edit.
POSE_C0 = 2 * (int(os.environ["EP3_POSE_FROM"]) - 1) if os.environ.get("EP3_POSE_FROM") else C0


def add_lora(g, model_key="lora"):
    g["slvra"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": [model_key, 0], "lora_name": LORA[0],
                                                                   "strength_model": LORA[1]}}
    g["shift"]["inputs"]["model"] = ["slvra", 0]


def text_image(text, seed, prefix, hero):
    g = story.qwen_keyframe_wf(1, {"key": (TRIG if hero else "") + text + ARC, "seed": seed})
    if hero:
        add_lora(g, "lora")
    g["save"]["inputs"]["filename_prefix"] = prefix
    secs, _ = story.run(g, 900)
    return secs


def edit_image(images, prompt, seed, prefix, lora):
    g = v4.round2_graph(4, seed, images, "", prefix)
    g["pos"]["inputs"]["prompt"] = prompt
    if lora:
        add_lora(g, "unet")
    secs, _ = story.run(g, 900)
    return secs


def main():
    want = [int(a) for a in sys.argv[1:]] or list(SHOTS)
    shutil.copyfile(ep.newest("/data/output/series/ep3/design/castle_3102_*.png"), "/data/input/ep3_castle.png")
    shutil.copyfile(f"{ep.OUT}/refs/ref_truck.png", "/data/input/ep3_truck.png")
    shutil.copyfile(ep.newest("/data/output/series/ep3/design/costume_3102_*.png"), "/data/input/ep3_costume.png")
    for k in want:
        kind, text = SHOTS[k]
        for n, seed in enumerate(SEEDS, 1 + C0):
            prefix = f"{OUT}/s{k:02d}_c{n}"
            if ep.newest(f"/data/output/{prefix}_*.png"):
                continue
            # EP3_PHASE (2026-11-10): "text" = only the Qwen-Image steps, "edit" = only the Qwen-Image-Edit steps, so ONE
            # big image model is loaded per server session (both models + the text encoder exceed the 20 GB VM: it swapped
            # to its disk and the host's "modified" pages filled the RAM — the PC froze twice). Unset = both, as before.
            phase = os.environ.get("EP3_PHASE", "")
            if kind == "copy":
                os.makedirs(f"/data/output/{OUT}", exist_ok=True)
                shutil.copyfile(ep.newest(f"/data/output/{text}_*.png"), f"/data/output/{prefix}_00001_.png")
                secs = 0.0
            elif kind in ("scene", "scene_hero"):
                if phase == "edit":
                    continue
                secs = text_image(text, seed + k * 10, prefix, kind == "scene_hero")
            elif kind == "castle":
                if phase == "text":
                    continue
                secs = edit_image(("ep3_castle.png", "ep3_truck.png"), text + ARC, seed + k * 10, prefix, False)
            else:  # pose / pose_c: step 1 the pose, step 2 the approved face (+ the costume)
                pose_prefix = f"{OUT}/pose/s{k:02d}_c{n - C0 + POSE_C0}"
                secs = 0.0
                if phase != "edit" and not ep.newest(f"/data/output/{pose_prefix}_*.png"):
                    secs = text_image(text, seed + k * 10, pose_prefix, True)
                if phase == "text":
                    print(f"ep3 pose s{k:02d} c{n}: {secs:.1f} s", flush=True)
                    continue
                pose = f"ep3_pose_s{k:02d}_c{n}.png"
                shutil.copyfile(ep.newest(f"/data/output/{pose_prefix}_*.png"), f"/data/input/{pose}")
                third = "ep3_costume.png" if kind == "pose_c" else "ep2_ref_young_face_b.png"
                if kind == "pose_c":
                    outfit = ("take ONLY the face from image 2, NOT its clothes; her clothes are exactly the costume of "
                              "image 3: " + COSTUME)
                    hair = HAIR_ONLY
                else:
                    outfit, hair = "her clothes as in image 1. ", v4.HAIR
                prompt = ("Image 1 is the picture to keep: the same scene, the same pose and body, the same camera and light. "
                          "Exactly one woman in the picture; do not add any person. Her FACE becomes exactly the face of "
                          f"image 2 — young, about twenty, soft round cheeks, big eyes, the silver hair with one thin golden "
                          f"strand; {outfit}" + hair + "Painted Arcane animation style.")
                secs += edit_image((pose, "ep2_ref_young_face_a.png", third), prompt, seed + k * 10, prefix, True)
            print(f"ep3 key s{k:02d} c{n} ({kind}): {secs:.1f} s", flush=True)


if __name__ == "__main__":
    main()
