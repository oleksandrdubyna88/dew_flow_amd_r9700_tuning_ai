"""Episode 2, v3: the SAME face as episode 1's Arcane film. The owner (2026-11-08): in episode 2 the nose and face differ from
episode 1 — every keyframe had been drawn from text alone, then restyled (two places where a face drifts). Here each
keyframe is drawn by Qwen-Image-Edit-2511 (fp8, Lightning 4-step merged) from three reference frames of episode 1's Arcane
14B film (series/ep2/refs: ref_profile.png, ref_face.png, ref_body.png), directly in the Arcane look; no restyle step.
Shot 2's keyframe has the eyes closed (a sleeping shot drifts back toward an open-eyed keyframe). Shot 8 (no face) keeps
its clip. Clips by Wan 2.2 A14B + lightx2v with the gaze words, the server restarted before every clip.

Run inside the container:
  wslc exec comfyui python /opt/tests/ep2_edit.py keyframes
  wslc exec comfyui python /opt/tests/ep2_edit.py shot <k>        (k = 1..7, ONE clip per call; restart ComfyUI first)
  wslc exec comfyui python /opt/tests/ep2_edit.py join
Writes series/ep2/edit/key_s<k>_*.png, series/ep2/v3/clip_s<k>_*.mp4, series/ep2/ep2_arcane_14b_v3.mp4.
"""
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import episode2 as ep  # noqa: E402
from eyes_try import GAZE  # noqa: E402

EDIT_UNET = "qwen_image_edit_2511_fp8_e4m3fn_scaled_lightning_comfyui_4steps_v1.0.safetensors"
REFS = ("ref_profile.png", "ref_face.png", "ref_body.png")
SAME = ("The same young woman as in image 1 and image 2 — keep her face exactly the same: the same nose, eyes, eyebrows, "
        "lips, jaw and face shape — with the same long silver-white hair and the thin golden strand, wearing the same "
        "dark-green tunic with brown trim, brown belt and bracers as in image 3. Same painted Arcane animation style as the "
        "reference images: painterly textures, cinematic lighting. ")
SCENES = {
    1: "Inside a dry cave behind a waterfall, she kneels by a small campfire she has just lit, arranging a fur bedroll; "
       "the waterfall glows behind her, warm firelight on the cave walls.",
    2: "She lies asleep on a fur bedroll beside a dying campfire in the cave, her eyes CLOSED, peaceful sleeping face, "
       "warm glowing embers, close shot.",
    3: "At the mouth of the cave she stands looking out over a valley as huge black clouds roll in and blot out the sun, "
       "grey ash beginning to fall like snow, the forest below darkening; grim cold desaturated colours.",
    4: "She walks through a dead withered forest of bare black trees under a dark grey sky, grey ash covering the ground "
       "like dirty snow, her breath visible in the cold air; grim cold desaturated colours.",
    5: "She crouches hidden behind a fallen dead tree in the foreground while behind her a pack of gaunt mutated wolves "
       "with patchy grey fur, too many teeth and pale glowing eyes prowls between dead trees in the ash; grim, tense.",
    6: "At the cave entrance she stands with a packed leather travel bag on her shoulder, looking out over the grey dead "
       "valley with a determined face, ready to leave; grim cold desaturated colours.",
    7: "On a ruined cracked road among rusted wrecks she climbs into the driver's seat of the SAME vehicle as in image 3: "
       "the small low boxy four-wheeled military off-road car like a classic Humvee (four wheels, no cargo bed), without any "
       "logo, dusty with grey ash, its door open; grim cold colours.",
}
OUT = ep.OUT
# Shot 7 must show the SAME vehicle as shot 8 (kept from v2): its third reference is shot 8's Arcane keyframe of the truck.
REFS_BY_SHOT = {7: ("ref_profile.png", "ref_face.png", "ref_truck.png")}


def edit_graph(k):
    g = {
        "unet": {"class_type": "UNETLoader", "inputs": {"unet_name": EDIT_UNET, "weight_dtype": "default"}},
        "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_2.5_vl_7b_fp8_scaled.safetensors", "type": "qwen_image",
                                                         "device": "default"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
        "shift": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["unet", 0], "shift": 3.1}},
        "latent": {"class_type": "EmptySD3LatentImage", "inputs": {"width": 1280, "height": 704, "batch_size": 1}},
        "sampler": {"class_type": "KSampler", "inputs": {"model": ["shift", 0], "positive": ["pos", 0], "negative": ["neg", 0],
                    "latent_image": ["latent", 0], "seed": ep.SHOTS[k - 1]["seed"], "steps": 4, "cfg": 1.0,
                    "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0}},
        "decode": {"class_type": "VAEDecode", "inputs": {"samples": ["sampler", 0], "vae": ["vae", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": f"series/ep2/edit/key_s{k}"}},
    }
    images = {}
    refs = REFS_BY_SHOT.get(k, REFS)
    for i, ref in enumerate(refs, 1):
        g[f"ref{i}"] = {"class_type": "LoadImage", "inputs": {"image": f"ep2_{ref}"}}
        g[f"scale{i}"] = {"class_type": "ImageScaleToTotalPixels", "inputs": {"image": [f"ref{i}", 0], "upscale_method": "lanczos",
                                                                                "megapixels": 1.0, "resolution_steps": 1}}
        images[f"image{i}"] = [f"scale{i}", 0]
    g["pos"] = {"class_type": "TextEncodeQwenImageEditPlus", "inputs": {"clip": ["clip", 0], "prompt": SAME + SCENES[k],
                                                                         "vae": ["vae", 0], **images}}
    g["neg"] = {"class_type": "TextEncodeQwenImageEditPlus", "inputs": {"clip": ["clip", 0], "prompt": "", "vae": ["vae", 0],
                                                                         **images}}
    return g


def keyframes():
    shutil.copyfile(ep.newest(f"{OUT}/arc_s8_*.png"), f"{OUT}/refs/ref_truck.png")
    for ref in REFS + ("ref_truck.png",):
        shutil.copyfile(f"{OUT}/refs/{ref}", os.path.join("/data/input", f"ep2_{ref}"))
    for k in SCENES:
        if ep.newest(f"{OUT}/edit/key_s{k}_*.png"):
            continue
        secs, _ = ep.story.run(edit_graph(k), 900)
        print(f"shot {k}: edit keyframe {secs:.1f} s", flush=True)


def shot(k, prefix=None):
    if prefix is None and ep.newest(f"{OUT}/v3/clip_s{k}_*.mp4"):
        print(f"shot {k}: clip exists", flush=True)
        return
    s = ep.SHOTS[k - 1]
    ep.story.HERO = ep.HERO
    name = f"ep2_edit_s{k}.png"
    shutil.copyfile(ep.newest(f"{OUT}/edit/key_s{k}_*.png"), os.path.join("/data/input", name))
    motion = s["motion"]
    if k == 2:
        motion = ("She lies asleep on the fur bedroll with her eyes CLOSED the whole time, in deep peaceful sleep, breathing "
                  "slowly and evenly, her face relaxed and still; the embers glow and fade; a few sparks rise.")
    wf = ep.story.wan14b_video_wf(k, {"motion": f"{motion} {GAZE if k != 2 else ''} {ep.ARC_STYLE}", "seed": s["seed"]}, name)
    wf["save"]["inputs"]["filename_prefix"] = prefix or f"series/ep2/v3/clip_s{k}"
    secs, files = ep.story.run(wf, 7200)
    print(f"shot {k}: clip {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


def join():
    clips = [ep.newest(f"{OUT}/v3/clip_s{k}_*.mp4") for k in range(1, 8)] + [ep.newest(f"{OUT}/clip_s8_*.mp4")]
    if not all(clips):
        raise SystemExit(f"missing clips: {clips}")
    with open(f"{OUT}/concat_v3.txt", "w") as f:
        f.writelines(f"file '{c}'\n" for c in clips)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", f"{OUT}/concat_v3.txt",
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-movflags", "+faststart",
                    f"{OUT}/ep2_arcane_14b_v3.mp4"], check=True, timeout=600)
    print("joined:", f"{OUT}/ep2_arcane_14b_v3.mp4", flush=True)


if __name__ == "__main__":
    {"keyframes": lambda: keyframes(), "shot": lambda: shot(int(sys.argv[2])), "join": lambda: join(),
     # a memory-flag A/B (2026-11-09): the same clip again under another name, e.g. "ab 1 fastdisk"
     "ab": lambda: shot(int(sys.argv[2]), f"series/ep2/ab/{sys.argv[3]}_s{sys.argv[2]}")}[sys.argv[1]]()
