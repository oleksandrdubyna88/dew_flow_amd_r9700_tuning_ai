"""Episode 2 of the elf series (the owner's story, 2026-11-08): the cave, the nuclear winter, the dead forest, mutated
animals, she leaves, finds an old military 4x4 and races into the sunset. Set B's character, the Arcane look (Qwen-Image
keyframe → Z-Image Turbo + the Arcane LoRA img2img), clips by Wan 2.2 A14B + lightx2v with the gaze words.

Run inside the container:
  wslc exec comfyui python /opt/tests/episode2.py keyframes      (Qwen keyframes, then the Arcane restyle; fast)
  wslc exec comfyui python /opt/tests/episode2.py shot <k>       (ONE 14B clip; restart ComfyUI before every call)
  wslc exec comfyui python /opt/tests/episode2.py join
Writes /data/output/series/ep2/{key_s<k>_*.png, arc_s<k>_*.png, clip_s<k>_*.mp4, ep2_arcane_14b.mp4}.
"""
import glob
import os
import shutil
import subprocess
import sys

os.environ["SERIES"] = "elf_v5"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import series_elf as story  # noqa: E402
from eyes_try import GAZE  # noqa: E402

HERO = story.HERO_V5
PHOTO = story.STYLE_V2
GRIM = "grim cold desaturated colours, overcast gloom, " + PHOTO
ARC_STYLE = "Arcane style painted animation, consistent with the first frame."
LORA = "z_image_arcane_v1.safetensors"
OUT = "/data/output/series/ep2"
SHOTS = [
    {"seed": 301, "style": PHOTO,
     "key": f"Medium wide shot inside a dry cave behind a waterfall: {HERO} kneels by a small campfire she has just lit, "
            "arranging a bedroll of furs; the waterfall glows behind her, warm firelight on the cave walls.",
     "motion": "She feeds the small fire with a stick and settles down beside it, calm, warm firelight flickering on her "
               "face; the waterfall flows behind her."},
    {"seed": 302, "style": PHOTO,
     "key": f"Close shot of {HERO} asleep on a fur bedroll beside a dying campfire in the cave, peaceful face, warm embers.",
     "motion": "She sleeps peacefully, breathing slowly; the embers glow and fade; a few sparks rise."},
    {"seed": 303, "style": GRIM,
     "key": f"Wide shot from the cave mouth: {HERO} stands at the edge looking out over the valley as huge black clouds roll "
            "in and blot out the sun, grey ash beginning to fall like snow, the forest below darkening.",
     "motion": "Black clouds roll across the sky and swallow the sun; grey ash starts to fall; she pulls her cloak tighter."},
    {"seed": 304, "style": GRIM,
     "key": f"Wide shot of {HERO} walking through a dead withered forest of bare black trees under a dark grey sky, grey ash "
            "covering the ground like dirty snow, her breath visible in the cold air.",
     "motion": "She walks slowly through the dead forest wrapped in her cloak, ash falling, her breath steaming in the cold; "
               "dead branches sway."},
    {"seed": 305, "style": GRIM,
     "key": f"Tense shot: {HERO} crouches hidden behind a fallen dead tree in the foreground, while behind her a pack of "
            "gaunt mutated wolves with patchy grey fur and pale glowing eyes prowls between the dead trees in the ash.",
     "motion": "The mutated wolves prowl slowly between the dead trees, sniffing the air; she holds her breath and stays "
               "still behind the fallen tree."},
    {"seed": 306, "style": GRIM,
     "key": f"Medium shot of {HERO} at the cave entrance with a packed leather travel bag on her shoulder, looking out over "
            "the grey dead valley with a determined face, ready to leave.",
     "motion": "She tightens the strap of her bag, takes a last look back into the cave, then turns and walks out into the "
               "grey cold valley."},
    {"seed": 307, "style": GRIM,
     "key": f"Wide shot on a ruined cracked road among rusted wrecks of the old world: {HERO} climbs into the driver's seat "
            "of an old boxy wide military off-road truck like a classic Humvee, without any logo, dusty with grey ash, "
            "its door open.",
     "motion": "She climbs into the driver's seat and turns the key; the engine starts with a puff of exhaust, the "
               "headlights flicker on."},
    {"seed": 308, "style": PHOTO, "no_hero": True,
     "key": "Wide cinematic shot from behind: an old boxy military off-road truck like a classic Humvee, without any logo, "
            "races along an empty cracked road toward a blazing red-orange sunset breaking through dark clouds on the "
            "horizon, dust trailing behind it, dead trees along the road.",
     "motion": "The truck speeds away along the road toward the red sunset, dust and ash swirling behind it; the clouds "
               "part and golden light spreads over the road."},
]


def newest(pattern):
    found = sorted(glob.glob(pattern))
    return found[-1] if found else None


def keyframes():
    os.makedirs(OUT, exist_ok=True)
    for k, s in enumerate(SHOTS, 1):  # all Qwen keyframes first, then all restyles: each model loads once, not per shot
        if not newest(f"{OUT}/key_s{k}_*.png"):
            wf = story.qwen_keyframe_wf(k, {"key": f"{s['key']} {s['style']}", "seed": s["seed"]})
            wf["save"]["inputs"]["filename_prefix"] = f"series/ep2/key_s{k}"
            secs, _ = story.run(wf, 900)
            print(f"shot {k}: keyframe {secs:.1f} s", flush=True)
    for k, s in enumerate(SHOTS, 1):
        if not newest(f"{OUT}/arc_s{k}_*.png"):  # the Arcane restyle: Z-Image Turbo + the LoRA, img2img at 0.55
            name = f"ep2_key_s{k}.png"
            shutil.copyfile(newest(f"{OUT}/key_s{k}_*.png"), os.path.join("/data/input", name))
            wf = story._keyframe_wf(k, {"key": f"{s['key']} Arcane style.", "seed": s["seed"]})
            wf["lora"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["unet", 0], "lora_name": LORA,
                                                                           "strength_model": 1.0}}
            wf["shift"]["inputs"]["model"] = ["lora", 0]
            wf["src"] = {"class_type": "LoadImage", "inputs": {"image": name}}
            wf["enc"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["src", 0], "vae": ["vae", 0]}}
            wf["sampler"]["inputs"].update({"latent_image": ["enc", 0], "denoise": 0.55})
            wf["save"]["inputs"]["filename_prefix"] = f"series/ep2/arc_s{k}"
            secs, _ = story.run(wf, 900)
            print(f"shot {k}: arcane {secs:.1f} s", flush=True)


def shot(k):
    if newest(f"{OUT}/clip_s{k}_*.mp4"):
        print(f"shot {k}: clip exists", flush=True)
        return
    s = SHOTS[k - 1]
    story.HERO = "" if s.get("no_hero") else HERO  # the video graph appends the hero text to the motion
    name = f"ep2_arc_s{k}.png"
    shutil.copyfile(newest(f"{OUT}/arc_s{k}_*.png"), os.path.join("/data/input", name))
    motion = f"{s['motion']} {'' if s.get('no_hero') else GAZE} {ARC_STYLE}"
    wf = story.wan14b_video_wf(k, {"motion": motion, "seed": s["seed"]}, name)
    wf["save"]["inputs"]["filename_prefix"] = f"series/ep2/clip_s{k}"
    secs, files = story.run(wf, 7200)
    print(f"shot {k}: clip {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


def join():
    clips = [newest(f"{OUT}/clip_s{k}_*.mp4") for k in range(1, len(SHOTS) + 1)]
    if not all(clips):
        raise SystemExit(f"missing clips: {clips}")
    with open(f"{OUT}/concat.txt", "w") as f:
        f.writelines(f"file '{c}'\n" for c in clips)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", f"{OUT}/concat.txt",
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-movflags", "+faststart",
                    f"{OUT}/ep2_arcane_14b.mp4"], check=True, timeout=600)
    print("joined:", f"{OUT}/ep2_arcane_14b.mp4", flush=True)


if __name__ == "__main__":
    {"keyframes": lambda: keyframes(), "shot": lambda: shot(int(sys.argv[2])), "join": lambda: join()}[sys.argv[1]]()
