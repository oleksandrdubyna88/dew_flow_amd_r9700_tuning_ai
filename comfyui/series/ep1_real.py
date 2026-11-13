"""Episode 1 REALISTIC (the owner, 2026-11-10 night: "then render the LoRAs for realism, and render the first episode"):
the episode 1 v3 shot list (ep1_v3.SHOTS — the reviewer's critique) in a live-action look with the new realistic LoRA
slvrareal (lora_dataset_real.py: identity trigger "slvrareal", outfit "tunicoutfit"). Keyframes = Qwen-Image 2512 +
Lightning + slvrareal from text (NO face edit: tonight the edit with full-frame references added a second person); two
candidates per shot. Clips = Wan 2.2 14B I2V with a realistic hero text. The sound and the edit are episode 1 v3's
(ep1_edit.py with EP1_DIR pointing here).
Run inside the comfyui container:
  python /opt/tests/ep1_real.py test            -> lora strength test: shots 1 and 3 at 0.6 / 0.8 / 1.0
  LREAL_STRENGTH=0.8 python /opt/tests/ep1_real.py keys <k>...
  python /opt/tests/ep1_real.py shot <k>
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ep1_v3  # noqa: E402
import episode2 as ep  # noqa: E402
from eyes_try import GAZE  # noqa: E402

OUT = "series/elf_real/ep1"
REAL = "cinematic film still, natural light, photorealistic, highly detailed, 35mm, shallow depth of field"
TRIG = ("slvrareal, a young woman of about twenty with long straight silver-white hair and one thin golden strand, a soft "
        "young face, big eyes, her long hair falling over the sides of her head, wearing tunicoutfit, a dark-green tunic "
        "with brown trim, a brown belt, brown leather bracers, ")
HERO_REAL = ("a young woman with long flowing silver-white hair with one thin golden strand and a soft young face, wearing "
             "a dark-green tunic with brown trim, a brown belt, brown leather bracers, boots and a long dark-green cloak, "
             "realistic human proportions")
STYLE = "photorealistic live-action film, consistent with the first frame."
SEEDS = (4401, 4402)


def keyframe(text, seed, prefix, strength, hero=True):
    story = ep.story
    g = story.qwen_keyframe_wf(1, {"key": (TRIG if hero else "") + text + " " + REAL, "seed": seed})
    if hero:
        g["slvrareal"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["lora", 0],
                                                                          "lora_name": "slvrareal.safetensors",
                                                                          "strength_model": strength}}
        g["shift"]["inputs"]["model"] = ["slvrareal", 0]
    g["save"]["inputs"]["filename_prefix"] = prefix
    secs, _ = story.run(g, 900)
    return secs


def test():
    for k in (1, 3):
        text = ep1_v3.SHOTS[k][1].replace(ep1_v3.CLOAK, "and a long dark-green cloak. ")
        for s in (0.6, 0.8, 1.0):
            prefix = f"{OUT}/test/s{k}_l{int(s * 10)}"
            if not ep.newest(f"/data/output/{prefix}_*.png"):
                secs = keyframe(text, SEEDS[0] + k * 10, prefix, s)
                print(f"ep1 real test s{k} strength {s}: {secs:.1f} s", flush=True)


def keys(k, strength):
    """LREAL_PLAIN=1 (2026-11-11): candidates c3/c4 WITHOUT the LoRA and its trigger, for the silhouette shots — with
    the identity trigger the wide shot 2 drew her big in the frame instead of "her small dark silhouette"."""
    kind, text, _ = ep1_v3.SHOTS[k]
    text = text.replace(ep1_v3.CLOAK, "and a long dark-green cloak. ")
    plain = os.environ.get("LREAL_PLAIN") == "1"
    for n, seed in enumerate(SEEDS, 3 if plain else 1):
        prefix = f"{OUT}/key_s{k}_c{n}"
        if not ep.newest(f"/data/output/{prefix}_*.png"):
            secs = keyframe(text, seed + k * 10, prefix, strength, hero=not plain)
            print(f"ep1 real key s{k} c{n}: {secs:.1f} s", flush=True)


# re-rolls (2026-11-11, the owner: in s6 "she folded in half backwards" — "sinks down" seen from behind made the model
# bend her body backwards): label -> (motion, seed offset). Positive words only: she STAYS kneeling upright.
REROLL = {
    (6, "b"): ("Behind the waterfall curtain she stays kneeling upright on the wet stone, seen from behind; her head bows "
               "slowly forward and her shoulders rise and fall as she breathes hard; her hands rest on her thighs; the "
               "falling water shimmers; the camera holds still.", 1000),
}


def shot(k, label=""):
    story = ep.story
    _, _, motion = ep1_v3.SHOTS[k]
    add = 0
    if label:
        motion, add = REROLL[(k, label)]
    name = f"ep1real_s{k}.png"
    shutil.copyfile(f"/data/output/{OUT}/pick_s{k}.png", os.path.join("/data/input", name))
    story.HERO = "" if k in (2, 6) else HERO_REAL
    wf = story.wan14b_video_wf(k, {"motion": f"{motion} {'' if k in (2, 6) else GAZE} {STYLE}", "seed": 4400 + k + add},
                               name)
    wf["save"]["inputs"]["filename_prefix"] = f"{OUT}/clip_s{k}{label}"
    secs, files = story.run(wf, 7200)
    print(f"ep1 real shot {k}: {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


if __name__ == "__main__":
    if sys.argv[1] == "test":
        test()
    elif sys.argv[1] == "keys":
        for a in sys.argv[2:]:
            keys(int(a), float(os.environ.get("LREAL_STRENGTH", "0.8")))
    elif sys.argv[1] == "shot":
        shot(int(sys.argv[2]), sys.argv[3] if len(sys.argv) > 3 else "")
