"""Prompt-adherence test for all character LoRAs (the owner 2026-11-12 ~21:50: "when we have all LoRAs, a test of how
well each follows prompts, to choose what is pleasant to work with"; "about 10 prompts, each checks one difficulty:
agreed, prepare detailed prompts"). Every model + LoRA at its best strength, and the base model without the LoRA,
2 seeds per prompt. The CHECK list per prompt is what is scored (1 point per item), plus face likeness and seconds.
Positive words only (no "not", "no", "without").
NOT run yet - the runner comes when all LoRAs exist.
"""
WHO = "slvrareal, an adult woman in her early twenties"
PHOTO = "photorealistic photograph, natural skin texture"
SEEDS = (5101, 5102)

PROMPTS = {
    "p01_outfit": (
        f"{WHO}, medium shot, standing in a softly lit ballroom, wearing an elegant floor-length dark-blue silk evening "
        f"gown with thin straps and a delicate silver necklace, her long silver-white hair loose over her shoulders, a "
        f"gentle smile, warm candlelight, {PHOTO}",
        ["dark-blue gown", "thin straps", "silver necklace", "hair loose", "ballroom", "candlelight", "gentle smile",
         "the tunic is gone"]),
    "p02_hair": (
        f"{WHO}, close-up portrait, front view, her silver-white hair tied in a high ponytail with a black ribbon and two "
        f"thin braids at her temples, wearing a simple white linen shirt, plain light-grey studio background, soft even "
        f"light, a calm expression, {PHOTO}",
        ["high ponytail", "black ribbon", "two temple braids", "white linen shirt", "grey studio background",
         "calm expression"]),
    "p03_place_light": (
        f"{WHO}, medium shot, standing on a busy modern city street at night in the rain, pink and blue neon signs "
        f"reflecting on the wet pavement, wearing a black raincoat with the hood down, holding a transparent umbrella, "
        f"looking at the camera, cinematic night photograph",
        ["night", "rain", "pink and blue neon", "reflections on the pavement", "black raincoat, hood down",
         "transparent umbrella", "looks at the camera", "modern city"]),
    "p04_pose": (
        f"{WHO}, full body, sitting sideways on a wide stone windowsill, hugging her knees to her chest with her chin "
        f"resting on her knees, bare feet, looking out of the window at a snowy landscape, wearing a long cream knitted "
        f"sweater, soft cold daylight from the window, {PHOTO}",
        ["on the windowsill", "hugs her knees", "chin on the knees", "bare feet", "looks out of the window",
         "snow outside", "cream knitted sweater", "full body"]),
    "p05_emotion": (
        f"{WHO}, close-up, a strong expression of surprise, eyebrows raised high, eyes wide open, mouth open in a round "
        f"O shape, both hands raised to her cheeks, wearing a dark-green wool tunic, in a sunny forest clearing, {PHOTO}",
        ["raised eyebrows", "wide-open eyes", "round open mouth", "hands on her cheeks", "dark-green tunic",
         "forest clearing"]),
    "p06_props_hands": (
        f"{WHO}, medium shot, three-quarter view, she holds a long steel sword in her left hand with the blade pointing "
        f"down to the ground and a burning torch raised in her right hand, wearing dark leather armour, in a dark stone "
        f"corridor, the torch lights her face warmly, a determined expression, {PHOTO}",
        ["sword in the LEFT hand", "blade points down", "torch in the RIGHT hand", "leather armour", "stone corridor",
         "torchlight on her face", "determined expression", "hands look right (5 fingers)"]),
    "p07_camera": (
        f"{WHO}, dramatic low-angle shot from the ground looking up at her, she stands on top of a rocky hill against a "
        f"stormy sky, her long silver-white hair and her dark-red cloak blowing in the wind, wearing the cloak over a "
        f"dark-green tunic, looking down at the camera, {PHOTO}",
        ["low angle from below", "rocky hilltop", "stormy sky", "hair and cloak in the wind", "dark-red cloak",
         "looks down at the camera"]),
    "p08_two_people": (
        f"{WHO}, medium shot, she stands on the left and an old man with a long grey beard in a brown monk robe stands "
        f"on the right, they smile and look at each other, in front of a wooden cottage door, warm evening light, "
        f"{PHOTO}",
        ["two people", "she is on the LEFT", "old man on the RIGHT", "long grey beard", "brown robe",
         "they look at each other", "both smile", "her face only on her (the man has his own face)"]),
    "p09_wide": (
        f"{WHO}, extreme wide shot, a small distant figure of her walks along a narrow mountain ridge, huge snowy "
        f"mountains and a green valley with a river far below, she wears a dark-green cloak, morning mist, epic "
        f"landscape photograph",
        ["extreme wide shot", "she is small in the frame (not a close-up)", "mountain ridge", "snowy mountains",
         "valley with a river", "dark-green cloak", "morning mist"]),
    "p10_long": (
        f"{WHO}, medium shot, she sits at a wooden table in a cosy library at night, reading an old leather-bound book "
        f"held open in both hands, round reading glasses on her nose, a steaming cup of tea and a lit candle on the "
        f"table, a black cat sleeping beside the book, tall bookshelves behind her, her silver-white hair in a loose "
        f"braid over her right shoulder, wearing a dark-blue knitted cardigan, warm candlelight, a small calm smile, "
        f"{PHOTO}",
        ["library at night", "book in both hands", "round glasses", "steaming tea", "lit candle", "black cat sleeping",
         "bookshelves", "braid over the RIGHT shoulder", "dark-blue cardigan", "small calm smile"]),
}
