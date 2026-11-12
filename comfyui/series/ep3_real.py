"""Episode 3 REALISTIC with all 4 character LoRA v3 (the owner 2026-11-12 ~22:10: "make ep3 with all 4 LoRAs, I cannot
decide; only work on the light: the motion is already good, but the light flickers strongly").
Same 23 shots, motion, edit timing and sound as the painted ep3 (ep3_keys.py / ep3_clips.py / ep3_edit.py), but:
- keyframes from TEXT with the model's LoRA (the LoRA carries the face; no face edit), 2 candidates per shot, per model:
    qwen    Qwen-Image 2512 + slvrareal3 0.6        flux2   FLUX.2 klein 4B + slvrareal3_flux2k4b 0.8
    flux2k9 FLUX.2 klein 9B + slvrareal3_flux2k9b 0.8   sdxl  RealVisXL V5 + slvrareal3_sdxl 0.6
  scene shots without her use the same base model without the LoRA (strength 0), so each version has one look;
- LIGHT: (1) the painted ep3 motion texts ASKED for flicker ("torchlight flickers", "the crystal pulses", "a burst of
  light flashes", "violet lightning flickers", "the fire flickers", "red light blinking") - Wan did exactly that; here
  every light is described as steady / calm / even, positive words only; (2) one light per act in the keyframes;
  (3) the clip style asks for "steady even exposure, the same light throughout"; (4) post: ffmpeg deflicker on the FILM
  clips is tested A/B before the edit (ep3_real_deflicker in the runner).
- hero texts without "soft young face" (owner: adult face, ~20-25).
Run inside comfyui:  python /opt/tests/ep3_real.py keys <model> [k...]     -> series/ep3_real/<model>/keys/sNN_cN
                     python /opt/tests/ep3_real.py clip <model> <k> [label] -> series/ep3_real/<model>/clips/clip_sNN
Any container:       python3 /opt/tests/ep3_real.py keysheet <model>        -> series/ep3_real/<model>/keys.jpg
"""
import glob
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

ROOT = "series/ep3_real"
D = f"/data/output/{ROOT}"
MODELS = ("qwen", "flux2", "flux2k9", "sdxl")
STRENGTH = {"qwen": 0.6, "flux2": 0.8, "flux2k9": 0.8, "sdxl": 0.6}
SEEDS = (3711, 3712)
WHO = "slvrareal, an adult woman in her early twenties with long straight silver-white hair and one thin golden strand"
TUNIC = "wearing a dark-green wool tunic with brown trim, a brown leather belt, brown leather bracers and boots"
FUR = ("wearing a grey sleeveless knitted crop top with a laced neckline, a wide brown leather belt, a short brown fur "
       "skirt, brown leather bracers and tall brown leather boots with fur tops, bare midriff, bare arms")
PHOTO = "photorealistic cinematic film still, natural skin texture, 35mm, shallow depth of field"
DRAGON = "a large dragon with dark slate-grey scales, glowing amber eyes and torn leathery wings"
AUTOMATON = ("a tall training automaton of dark blued steel plates and brass joints with a smooth fencing-mask head and one "
             "glowing blue visor slit")
# one light per act (positive, steady)
L1 = "cold blue twilight, soft even light"
L2 = "a dim vaulted hall lit by one steady shaft of dusty daylight"
L3 = "warm steady golden dawn light"
L4 = "silver moonlight and the warm steady glow of a small campfire"
# shot: (kind, outfit, text) ; kind scene = no hero (LoRA strength 0), hero = with the LoRA
SHOTS = {
    1: ("scene", "", "Wide establishing shot at dusk: a gothic castle with many spires on a high cliff above a dark lake; a "
        "winding road leads up to its open gate; a wide low boxy military Humvee is small on the road just before the "
        "gate, seen from behind with two small red tail lights, driving toward the gate; light mist over the lake, cloudy "
        f"sky, {L1}"),
    2: ("hero", TUNIC, "Wide shot from behind and a little to the side, her whole body small in the frame: she walks away "
        "from the camera across an empty cobbled castle courtyard - a dry stone fountain, fallen torn banners, ivy - "
        f"looking up at a broken tower above her, {L1}"),
    3: ("hero", TUNIC, "Over-the-shoulder low angle: in the lower left foreground the dark silhouette of her shoulder and "
        f"silver hair seen from behind; above, on a broken stone tower of a gothic castle, {DRAGON} spreads its wings to "
        f"take off; roof slates fall, {L1}"),
    4: ("scene", "", f"Seen from a castle courtyard looking up: {DRAGON} flies in a wide banking turn around the broken "
        f"tower of a gothic castle with many spires, wings spread, {L1} with the last amber light on the horizon"),
    5: ("scene", "", f"Exactly one dragon in the sky. Seen from a castle courtyard looking up: {DRAGON} passes behind the "
        f"broken tower on its far side in a second wide circle, wings spread, smaller in the distance, {L1}"),
    6: ("hero", TUNIC, "Close-up of her face: she looks up at the sky with wide-open eyes and slightly parted lips, a few "
        f"strands of her hair lifted by the wind, the sky reflected in her eyes, {L1}"),
    7: ("hero", TUNIC, "A long sword with a dark blade and a short wooden staff topped with a violet crystal lie on a stone "
        f"altar; she stands close to the altar, three-quarter view, looking down at them, {L2}, the crystal glows softly"),
    8: ("hero", TUNIC, "Three-quarter waist-level view: her left hand rests on the sword's leather grip and her right hand on "
        f"the short staff with the violet crystal, both still lying on the stone altar; her face in profile, intent, {L2}"),
    9: ("hero", TUNIC, "Wide view of a vaulted gothic hall: she stands in the middle holding the sword in her left hand and "
        "the crystal staff in her right; a calm glow of cyan, gold and violet surrounds her and a dome of deep darkness "
        "closes over her, a thin coloured rim at its edge"),
    10: ("hero", TUNIC, "Low angle from the stone floor, full body: she floats a little above the floor, her boots a hand's "
         "width above it with a soft shadow below, inside a dark dome filled with a faint steady violet glow"),
    11: ("hero", TUNIC, "Medium shot: she floats in the air, her face seen from the front, eyes closed, calm, arms spread "
         "wide, the sword in her left hand and the crystal staff in her right, silver hair floating; a dark vaulted "
         "ceiling above; soft steady violet light"),
    12: ("hero", "", "Extreme close-up of her upper face: her eyes wide open, small orange embers glowing inside the irises, "
         "warm steady light on her face, darkness around"),
    13: ("scene", "", "Macro close-up of a human eye filling the whole frame: the iris glows like burning fire, orange and "
         "gold flames swirl around the black pupil"),
    14: ("hero", FUR, f"Low side view, full body: she does a push-up on the stone floor of a castle yard, body straight, "
         f"arms strong, {L3}"),
    15: ("hero", FUR, "Rear three-quarter view: she hangs from an iron beam under a wooden roof and pulls herself up, her "
         f"back and shoulders strong and toned, her face in profile at the top, {L3}"),
    16: ("hero", FUR, "Side view at sunrise, full body: she runs along the top of a castle wall; the low golden sun just above "
         "the horizon behind the castle spires, orange and pink clouds, golden morning light on her and on the stones, "
         "battlements beside her; the fur panels of her skirt part with her stride"),
    17: ("hero", FUR, f"Mid-action, full bodies: she lunges and strikes with her sword the raised round steel shield of "
         f"{AUTOMATON}, which holds the shield in its left hand and a long steel sword drawn back in its right hand; orange "
         "sparks where her blade hits the shield; above them a small black quad-rotor camera drone hovers, its lens "
         f"pointed at the fight; a castle yard, {L3}"),
    18: ("hero", FUR, "Wide view of a forest glade at night: she lies on her back on a flat brown bear-skin rug on the grass, "
         f"looking up at the stars; a small campfire burns beside her, a silver stream runs past; tall dark pines, {L4}"),
    19: ("hero", FUR, "The same glade seen from the other side: the silver stream in front, the campfire behind her; she lies "
         f"on the bear-skin rug, her boots toward the camera, {L4}"),
    20: ("hero", FUR, "High angle close view along her legs as she lies on the brown bear-skin rug: her fur-topped tall "
         f"boots, the edge of the fur skirt, warm firelight on the leather, night, {L4}"),
    21: ("hero", FUR, "Overhead view from straight above: she lies on her back on the bear-skin rug, silver hair spread on "
         f"the fur, looking up, a small campfire on the grass beside the rug; her whole body in the frame, {L4}"),
    22: ("scene", "", "High aerial view above the treetops at night: far below a tiny campfire glows in a small forest glade "
         "with a tiny figure lying beside it; dark pine forest all around; the sky full of stars above"),
    23: ("scene", "", "A night sky full of stars and a faint milky way above the dark tops of pine trees"),
}
# clips: Wan 2.2 14B I2V, the painted ep3 motion with every light steady (see the header)
LOOK = "an adult woman in her early twenties with long flowing silver-white hair with one thin golden strand, "
HERO_T = LOOK + ("wearing a dark-green tunic with brown trim, a brown leather belt, brown leather bracers and boots, "
                 "realistic human proportions")
HERO_C = LOOK + ("wearing a sleeveless grey knitted crop top, a short brown fur skirt on a wide leather belt, tall brown "
                 "boots with fur tops and leather bracers, her arms bare, realistic human proportions")
STYLE = ("Photorealistic live-action film, consistent with the first frame, steady even exposure, the same calm light "
         "throughout the shot.")
MOTION = {
    1: ("", False, "The camera slowly descends toward the spired castle on the cliff above the dark lake; the military 4x4 "
        "rolls up to the gate and in under the arch; clouds drift, light mist over the lake."),
    2: ("T", False, "Side tracking camera at waist height: she walks steadily across the empty cobbled courtyard toward "
        "the broken tower, looking up at it; at the end a huge dark shadow sweeps across the stones."),
    3: ("T", False, "The dragon on the broken tower opens its torn wings wide and launches into the air; slates and stones "
        "rain down from the tower; her dark silhouette in the foreground stays still, her hair moves in the downdraft."),
    4: ("", False, "The dragon banks in a wide circle around the broken tower against the cloudy sky, its wings beating "
        "powerfully; the camera tilts to follow it."),
    5: ("", False, "The dragon glides past above the battlements in a wide turn, its wings beating slowly, its amber eyes "
        "glowing steadily; the clouds drift behind it."),
    6: ("T", True, "Almost still camera with a very slow push-in on her face; her eyes stay wide open, looking up at the "
        "sky; she takes one small breath through parted lips; the wind lifts a few strands of her hair."),
    7: ("T", False, "Slow dolly-in between the pillars of the vaulted hall toward her at the altar; dust floats in the "
        "steady shaft of light; the crystal on the altar glows with a soft steady light; she stands still and looks down "
        "at the relics."),
    8: ("T", True, "Her hands, already on the grips, lift the sword and the staff a few centimetres from the stone; the "
        "crystal's many-coloured light grows slowly and smoothly brighter and lights her face."),
    9: ("T", True, "Still camera: the calm glow of cyan, gold and violet light around her slowly fades as a dome of "
        "darkness closes smoothly over her; a thin coloured rim stays at its edge; she stands still."),
    10: ("T", False, "The camera cranes slowly up from her boots to her torso; she hangs motionless in the air, her boots a "
         "hand's width above the stone floor with a soft shadow below them, her body still and upright; a faint steady "
         "violet glow fills the dark dome."),
    11: ("T", True, "The camera cranes slowly up from her torso toward the dark vault above; she floats still with her arms "
         "spread, the sword in one hand and the crystal staff in the other; her silver hair floats around her; the violet "
         "light stays soft and steady."),
    12: ("T", True, "Extreme close-up: the camera pushes in slowly toward her right eye; the small orange embers inside both "
         "irises grow smoothly brighter; her eyes stay wide open and steady."),
    13: ("", False, "Macro: the camera pushes slowly into the fiery iris toward the pupil; the orange and gold flames in the "
         "iris grow slowly until warm fire fills the frame."),
    14: ("C", False, "Low side view: she does two slow, strong push-ups on the stone floor, her body straight; the warm "
         "morning light stays calm and steady on the walls."),
    15: ("C", False, "She pulls herself up on the iron beam slowly and strongly, her back and shoulder muscles working, her "
         "chin rising to the beam."),
    16: ("C", False, "Side tracking camera: she runs fast along the top of the castle wall at sunrise, her silver hair and "
         "the fur panels of her skirt flowing with her stride; the camera keeps pace; the golden sun glows steadily "
         "behind the castle."),
    17: ("C", False, "Her sword strikes the automaton's round shield and orange sparks fly; the automaton swings its sword "
         "back and she ducks low under it; the camera drone hovers calmly above them."),
    18: ("C", True, "The camera orbits slowly around the moonlit glade by about ninety degrees, past a dark tree trunk in "
         "the foreground; she lies still on the bear skin looking up at the stars; the campfire burns with a calm steady "
         "glow, the stream flows."),
    19: ("C", True, "The camera keeps orbiting slowly around her by about ninety degrees toward the side of her boots; she "
         "lies on the bear skin looking up; the campfire glows calmly; the stream flows."),
    20: ("C", True, "High angle: the camera rises slowly along her legs from the fur-topped boots to her waist; warm steady "
         "firelight on the leather; at the end her hand clenches the fur."),
    21: ("C", True, "Overhead view: the camera pulls slowly up and back until her whole body, the bear skin and a small "
         "campfire on the grass beside the rug are in frame; her chest falls in a slow sigh; she looks up."),
    22: ("", False, "The camera rises slowly above the dark pine treetops; the small campfire glade below grows smaller; the "
         "canopy gives way to the starry sky."),
    23: ("", False, "Almost still: the camera tilts very slowly upward across the starry sky and the faint milky way above "
         "the dark pine tops."),
}
SHORT = {1, 2, 3, 14, 15, 16, 17}  # as in the painted ep3: 49 frames, the edit uses 2-3 s
SHORT_FRAMES = 49


def key_text(k):
    kind, outfit, text = SHOTS[k]
    if kind == "scene":
        return f"{text}, {PHOTO}"
    return f"{WHO}, {text}" + (f", {outfit}" if outfit else "") + f", {PHOTO}"


def keys(model, want):
    import episode2 as ep
    import she3_check as sc
    for k in want:
        kind = SHOTS[k][0]
        s = STRENGTH[model] if kind == "hero" else 0.0
        for n, seed in enumerate(SEEDS, 1):
            prefix = f"{ROOT}/{model}/keys/s{k:02d}_c{n}"
            if ep.newest(f"/data/output/{prefix}_*.png"):
                continue
            text, sd = key_text(k), seed + k * 10
            if model == "qwen":
                import real2_check as rc
                secs = rc.keyframe("slvrareal3", s, text, sd, prefix)
            elif model == "flux2k9":
                secs, _ = ep.story.run(sc.flux2_wf(text, sd, s, prefix, "9b"), 900)
            else:
                secs, _ = ep.story.run((sc.flux2_wf if model == "flux2" else sc.sdxl_wf)(text, sd, s, prefix), 900)
            print(f"ep3real {model} key s{k:02d} c{n} ({kind} {s}): {secs:.1f} s", flush=True)


def keysheet(model):
    """keys.jpg: one row per shot: c1 | c2, the shot number on each tile; 4 shots per row pair."""
    from PIL import Image, ImageDraw
    tw, th = 384, 216
    cols = 4  # 4 shots x 2 candidates per row
    rows = (len(SHOTS) + cols - 1) // cols
    out = Image.new("RGB", (cols * 2 * tw, rows * (th + 18)), "black")
    for i, k in enumerate(SHOTS):
        for n in (1, 2):
            f = sorted(glob.glob(f"{D}/{model}/keys/s{k:02d}_c{n}_*.png"))
            x, y = ((i % cols) * 2 + n - 1) * tw, (i // cols) * (th + 18)
            if f:
                out.paste(Image.open(f[-1]).convert("RGB").resize((tw, th)), (x, y))
            ImageDraw.Draw(out).text((x + 4, y + th + 2), f"s{k:02d} c{n} {SHOTS[k][0]}", fill="white")
    out.save(f"{D}/{model}/keys.jpg", quality=88)
    print(f"ep3real keysheet {model}", flush=True)


def clip(model, k, label=""):
    import episode2 as ep
    from eyes_try import GAZE
    story = ep.story
    who, eyes, motion = MOTION[k]
    name = f"ep3real_{model}_s{k:02d}.png"
    shutil.copyfile(f"{D}/{model}/picks/s{k:02d}.png", os.path.join("/data/input", name))
    story.HERO = {"T": HERO_T, "C": HERO_C}.get(who, "")
    seed = 3700 + k + (1000 if label == "b" else 0)
    wf = story.wan14b_video_wf(k, {"motion": f"{motion} {GAZE if eyes else ''} {STYLE}", "seed": seed}, name)
    if k in SHORT:
        wf["i2v"]["inputs"]["length"] = SHORT_FRAMES
    wf["save"]["inputs"]["filename_prefix"] = f"{ROOT}/{model}/clips/clip_s{k:02d}{label}"
    secs, files = story.run(wf, 7200)
    print(f"ep3real {model} clip s{k:02d}{label}: {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


def film(model):
    """FILM 16 -> 32 fps of every kept clip (one server session; FILM is light, the restart rule is for Wan 14B)."""
    import ep3_film as ef
    for k in SHOTS:
        files = sorted(glob.glob(f"{D}/{model}/clips/clip_s{k:02d}_0*.mp4"))
        if files:
            ef.film_file(files[-1], f"{ROOT}/{model}/film/clip_s{k:02d}_32fps", f"ep3real film {model} s{k:02d}")


def picks(model, choice):
    """picks/sNN.png from keys/sNN_<choice>; choice "c1" for all, or "c1,5:c2" for exceptions."""
    parts = choice.split(",")
    default, extra = parts[0], dict(p.split(":") for p in parts[1:])
    os.makedirs(f"{D}/{model}/picks", exist_ok=True)
    n = 0
    for k in SHOTS:
        c = extra.get(str(k), default)
        f = sorted(glob.glob(f"{D}/{model}/keys/s{k:02d}_{c}_*.png"))
        if f and not os.path.exists(f"{D}/{model}/picks/s{k:02d}.png"):
            shutil.copyfile(f[-1], f"{D}/{model}/picks/s{k:02d}.png")
            n += 1
    print(f"ep3real picks {model} {choice}: {n} new", flush=True)


if __name__ == "__main__":
    act, model = sys.argv[1], sys.argv[2]
    if act == "keys":
        keys(model, [int(a) for a in sys.argv[3:]] or list(SHOTS))
    elif act == "keysheet":
        keysheet(model)
    elif act == "film":
        film(model)
    elif act == "picks":
        picks(model, sys.argv[3])
    elif act == "clip":
        clip(model, int(sys.argv[3]), sys.argv[4] if len(sys.argv) > 4 else "")
