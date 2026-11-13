"""A 30-second mini series on the local ComfyUI: 6 shots x ~5 s (Wan 2.2 TI2V 5B, 121 frames at 24 fps, 1280x704).

Phase 1: one keyframe per shot with Z-Image Turbo (same character text in every prompt, fixed seeds).
Phase 2: each keyframe animated by Wan 2.2 image-to-video.
Phase 3: the six clips joined with ffmpeg into one file.
Resumable: a shot whose keyframe or clip already exists is skipped. Run inside the container:
  wslc exec comfyui python /opt/tests/series_elf.py [keyframes|videos|concat|all]
Outputs: /data/output/series/elf/ (Windows: the comfyui output folder).
"""
import glob
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.request
import uuid

API = "http://127.0.0.1:8188"
W, H, FRAMES, FPS = 1280, 704, 121, 24
TILED = {"tile_size": 512, "overlap": 64, "temporal_size": 32, "temporal_overlap": 8}

# ---- version 1 (2026-11-07), kept as rendered ------------------------------------------------------------------------
HERO_V1 = ("a young elf woman with long flowing silver-white hair, pointed ears, bright emerald-green eyes, "
           "wearing a dark green leather tunic, a brown belt and brown leather boots")
STYLE_V1 = "cinematic film still, dramatic lighting, highly detailed, 35mm, shallow depth of field"


def shots_v1(HERO, STYLE):
    return [
        {"key": f"Wide shot of {HERO}, running through an ancient misty forest of giant oak trees toward the camera, "
                f"behind her on the horizon a blinding white flash lights the sky through the trees, {STYLE}",
         "motion": "The elf woman runs fast toward the camera through the misty forest, her hair streaming behind her; "
                   "a blinding white flash grows on the horizon behind her and the light floods between the trees. "
                   "Camera tracks backward with her.",
         "seed": 101},
        {"key": f"Close-up of the face of {HERO}, looking back over her shoulder in terror while running, "
                f"intense orange light reflecting on her face and hair, forest blurred behind, {STYLE}",
         "motion": "Close-up: she glances back over her shoulder in terror while running, breathing hard, "
                   "orange light flickering across her face, leaves rushing past.",
         "seed": 102},
        {"key": f"View from behind of {HERO}, running away from the camera along a forest path, "
                f"in the distance a gigantic nuclear mushroom cloud rises above the treetops, glowing orange and black, {STYLE}",
         "motion": "She sprints away from the camera along the forest path while a gigantic mushroom cloud rises and "
                   "billows above the treetops in the distance, glowing and expanding.",
         "seed": 103},
        {"key": f"{HERO} leaping over a fallen mossy tree trunk in a forest, a violent shockwave of dust and flying leaves "
                f"tearing through the trees behind her, branches breaking, {STYLE}",
         "motion": "She leaps over the fallen trunk as a violent shockwave tears through the forest behind her, "
                   "trees bending, leaves and dust blasting forward, branches snapping.",
         "seed": 104},
        {"key": f"{HERO} sliding down a steep rocky ravine toward a rushing river, the sky above glowing red and orange "
                f"with fire, embers falling like snow, {STYLE}",
         "motion": "She slides down the steep ravine toward the rushing river, stones tumbling, glowing embers "
                   "falling from a red burning sky.",
         "seed": 105},
        {"key": f"{HERO} diving behind a waterfall into a dark rock cave, the bright blast light outside, water spray "
                f"glowing, safe in the shadow, {STYLE}",
         "motion": "She dives through the waterfall into the dark cave; outside the bright blast wave rolls past and "
                   "the light slowly fades; she turns, breathing, safe in the shadow behind the falling water.",
         "seed": 106},
    ]


# ---- version 2 (2026-11-08): the owner's eight remarks on version 1 --------------------------------------------------
# 1 shot 3 ran TOWARD the cloud -> front view, she runs at the camera, the cloud behind her; 2 eyes -> natural human
# hazel-green; 3 a broken-looking leg -> a lower, natural jump and "anatomically correct legs"; 4 the mesh -> FastWan
# 3-step (incomplete denoising at 20 steps, diagnosed 2026-11-08); 5 clothing shiny vs rag -> one fixed material; 6 inhuman
# motion -> natural human running described in every motion prompt; 7 a thin golden strand; 8 small human ears with only
# slightly pointed tips. cfg is 1 for both models, so a negative prompt does nothing: every fix lives in the positive text.
HERO_V2 = ("a young woman of elven descent with long flowing silver-white hair with one thin golden strand, "
           "small human-sized ears with only slightly pointed tips, natural hazel-green human eyes, a calm realistic face, "
           "wearing a matte dark-green wool tunic with brown suede trim, a brown leather belt, dark trousers and brown "
           "leather boots, realistic human proportions and anatomically correct arms and legs")
STYLE_V2 = "cinematic film still, natural light, photorealistic, highly detailed, 35mm, shallow depth of field"
MOVE = "natural realistic human running motion, smooth and grounded, correct anatomy"


def shots_v2(HERO, STYLE, MOVE=MOVE):
    return [
        {"key": f"Wide shot of {HERO}, running through an ancient misty forest of giant oak trees toward the camera, "
                f"behind her on the horizon a blinding white flash lights the sky through the trees, {STYLE}",
         "motion": f"The woman runs toward the camera through the misty forest, {MOVE}, her hair streaming behind her; "
                   "a blinding white flash grows on the horizon behind her and the light floods between the trees. "
                   "The camera tracks backward in front of her.",
         "seed": 201},
        {"key": f"Close-up of the face of {HERO}, glancing back over her shoulder in fear while running, "
                f"warm orange light from behind her reflecting on her hair, forest blurred behind, {STYLE}",
         "motion": f"Close-up: she glances back over her shoulder in fear while running, breathing hard, {MOVE}, "
                   "warm light flickering on her hair, leaves rushing past.",
         "seed": 202},
        {"key": f"Front view of {HERO}, running toward the camera along a forest road, fleeing; far behind her in the "
                f"background a gigantic nuclear mushroom cloud rises above the treetops, glowing orange and black, {STYLE}",
         "motion": f"She runs toward the camera along the forest road, away from the explosion behind her, {MOVE}; "
                   "behind her the gigantic mushroom cloud rises and billows above the treetops. The camera tracks "
                   "backward in front of her.",
         "seed": 203},
        {"key": f"{HERO} jumping over a low fallen mossy log mid-stride in a forest, both feet clearly visible, a "
                f"shockwave of dust and flying leaves rolling through the trees far behind her, {STYLE}",
         "motion": f"She jumps over the low log mid-stride and lands running, {MOVE}; behind her a shockwave of dust and "
                   "leaves rolls through the trees, branches bending.",
         "seed": 204},
        {"key": f"{HERO} carefully climbing down a steep rocky slope toward a rushing river, the sky above glowing red and "
                f"orange with fire, embers drifting down, {STYLE}",
         "motion": "She climbs down the rocky slope toward the rushing river, steady natural steps, using her hands on "
                   "the rocks, small stones rolling, embers drifting down from a red sky.",
         "seed": 205},
        {"key": f"{HERO} standing in the shadow of a rock cave behind a waterfall, looking out, the bright blast light "
                f"beyond the falling water, she is clearly visible and safe, {STYLE}",
         "motion": "She steps behind the waterfall into the cave and turns to look out, breathing; outside the bright "
                   "blast wave rolls past and the light slowly fades; she stays clearly visible in the shadow.",
         "seed": 206},
    ]


# ---- version 3 (2026-11-08): v2's keyframes looked at — ears still long elf ears ("elven" pulls them), the golden strand
# hardly visible, shot 3's road was asphalt with lane markings. Same seeds; only the text changes.
HERO_V3 = ("a young woman with long flowing silver-white hair and one distinct bright golden-blonde streak framing her face, "
           "ordinary human ears whose upper tip is only very slightly pointed, natural hazel-green human eyes, a calm "
           "realistic face, wearing a matte dark-green wool tunic with brown suede trim, a brown leather belt, dark trousers "
           "and brown leather boots, realistic human proportions and anatomically correct arms and legs")


def shots_v3(HERO, STYLE):
    out = []
    for shot in shots_v2(HERO, STYLE):
        shot = dict(shot)
        for k in ("key", "motion"):
            shot[k] = shot[k].replace("forest road", "narrow forest dirt path").replace("The woman", "The young woman")
        out.append(shot)
    return out


# ---- version 4 (2026-11-08): v3's golden hair was far too much (wide blonde sections) and shots 2 and 6 still showed long
# pointed ears. The strand: one thin strand at the temple; the ears: round human ears, a tiny point only at the top.
HERO_V4 = ("a young woman with long flowing silver-white hair with a single thin golden strand at her left temple, "
           "small round human ears with only a tiny point at the very top, natural hazel-green human eyes, a calm realistic "
           "face, wearing a matte dark-green wool tunic with brown suede trim, a brown leather belt, dark trousers and brown "
           "leather boots, realistic human proportions and anatomically correct arms and legs")


# ---- version 5 (2026-11-08): v4's strand vanished in most shots (v3 had far too much). A middle: one noticeable thin
# golden strand from the left temple down to the chin, clearly visible against the silver.
HERO_V5 = HERO_V4.replace("with a single thin golden strand at her left temple",
                          "with one noticeable thin golden strand from her left temple down to her chin, clearly visible "
                          "against the silver")


# ---- Arcane style (the owner, 2026-11-08: "the same film in the style of Arcane"): v5's shots and heroine, the style
# text swapped for a painterly animated look; the clips animate the stylised keyframes, so the style carries over.
STYLE_ARCANE = ("in the style of the animated series Arcane: painterly stylised 3D animation with hand-painted textures, "
                "visible brush strokes, bold rim lighting, rich saturated colours, dramatic cinematic composition, "
                "graphic shapes, high detail")


def shots_arcane(HERO, STYLE):
    out = []
    for shot in shots_v3(HERO, STYLE):
        shot = dict(shot)
        shot["motion"] = shot["motion"] + " Painterly animated style, hand-painted textures, consistent with the first frame."
        out.append(shot)
    return out


# Arcane v2 (2026-11-08): the first try came out as soft Disney-like flat 2D, not Arcane, and the ears grew long again in
# shots 5-6. The look is described in words, not by the show's name: mature semi-realistic faces with sharp angular
# features, oil-painted textures with visible brush strokes, gritty dark atmosphere, hard chiaroscuro, cool rim light.
STYLE_ARCANE2 = ("stylised semi-realistic animated film look like Fortiche's Arcane: mature face with sharp angular features "
                 "and strong cheekbones, oil-painted hand-painted textures with visible brush strokes on skin, clothes and "
                 "background, gritty dark moody atmosphere, hard chiaroscuro lighting, cool cyan rim light against warm "
                 "orange fire light, painted concept-art backgrounds, cinematic composition")
HERO_ARCANE2 = HERO_V5.replace("small round human ears with only a tiny point at the very top",
                               "small round human ears with only a tiny point at the very top, not long elf ears")


# Arcane v3 (2026-11-08, after the question consultants): text alone pulls the anatomy toward cartoon proportions in the
# first steps, so restyle the accepted photoreal v5 keyframes instead (img2img: VAE-encode, partial denoise) — anatomy, ears
# and the strand stay from v5, the late steps repaint the surfaces. The style block describes construction, not the show.
STYLE_ARCANE3 = ("cinematic frame of a hand-painted three-dimensional animated film: sculptural adult facial anatomy, natural-sized "
                 "eyes, angular cheek and brow planes, subtle asymmetry, facial volume built from distinct painted colour and "
                 "shadow shapes, selective broken contour accents on eyelids, lips and hair, directional brush marks following "
                 "the surfaces, rough painted highlights, sculpted hair locks, tactile matte wool, gouache overpaint with a "
                 "matte chalky finish and no skin shine, strong directional light with crisp painted shadow shapes, muted local "
                 "colours, blue-violet shadows and selective amber highlights, painted concept-art background")


# ---- the second model set (2026-11-08, the owner: "pick another set of models the GPU supports well, to compare"):
# keyframes by Qwen-Image 2512 fp8 + Lightning 4-step LoRA; clips by Wan 2.2 A14B I2V fp8 (high- and low-noise experts)
# + lightx2v 4-step LoRAs; both from ComfyUI's own templates (image_qwen_Image_2512, video_wan2_2_14B_i2v). The 14B model
# runs natively at 16 fps: 81 frames = 5.06 s, as the 5B's 121 frames at 24 fps.
SET2_FRAMES, SET2_FPS = 81, 16


def qwen_keyframe_wf(i, shot):
    return {
        "unet": {"class_type": "UNETLoader", "inputs": {"unet_name": "qwen_image_2512_fp8_e4m3fn.safetensors", "weight_dtype": "default"}},
        "lora": {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["unet", 0], "lora_name":
                 "Qwen-Image-2512-Lightning-4steps-V1.0-fp32.safetensors", "strength_model": 1.0}},
        "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_2.5_vl_7b_fp8_scaled.safetensors", "type": "qwen_image", "device": "default"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
        "shift": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["lora", 0], "shift": 3.1}},
        "pos": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": shot["key"]}},
        "neg": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": ""}},
        "latent": {"class_type": "EmptySD3LatentImage", "inputs": {"width": W, "height": H, "batch_size": 1}},
        "sampler": {"class_type": "KSampler", "inputs": {"model": ["shift", 0], "positive": ["pos", 0], "negative": ["neg", 0],
                    "latent_image": ["latent", 0], "seed": shot["seed"], "steps": 4, "cfg": 1.0,
                    "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0}},
        "decode": {"class_type": "VAEDecode", "inputs": {"samples": ["sampler", 0], "vae": ["vae", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": f"series/{NAME}/key_s{i}"}},
    }


def wan14b_video_wf(i, shot, image_name):
    expert = {}
    for k, f in (("hi", "high"), ("lo", "low")):
        expert[f"unet_{k}"] = {"class_type": "UNETLoader", "inputs": {"unet_name": f"wan2.2_i2v_{f}_noise_14B_fp8_scaled.safetensors", "weight_dtype": "default"}}
        expert[f"lora_{k}"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": [f"unet_{k}", 0], "lora_name":
                               f"wan2.2_i2v_lightx2v_4steps_lora_v1_{f}_noise.safetensors", "strength_model": 1.0}}
        expert[f"shift_{k}"] = {"class_type": "ModelSamplingSD3", "inputs": {"model": [f"lora_{k}", 0], "shift": 5.0}}
    return {**expert,
        "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": "umt5_xxl_fp8_e4m3fn_scaled.safetensors", "type": "wan", "device": "default"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "wan_2.1_vae.safetensors"}},
        "img": {"class_type": "LoadImage", "inputs": {"image": image_name}},
        "pos": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": shot["motion"] + " " + HERO + ". Cinematic."}},
        "neg": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": NEG_WAN}},
        "i2v": {"class_type": "WanImageToVideo", "inputs": {"positive": ["pos", 0], "negative": ["neg", 0], "vae": ["vae", 0],
                "start_image": ["img", 0], "width": W, "height": H, "length": SET2_FRAMES, "batch_size": 1}},
        "s_hi": {"class_type": "KSamplerAdvanced", "inputs": {"model": ["shift_hi", 0], "positive": ["i2v", 0], "negative": ["i2v", 1],
                 "latent_image": ["i2v", 2], "add_noise": "enable", "noise_seed": shot["seed"], "steps": 4, "cfg": 1.0,
                 "sampler_name": "euler", "scheduler": "simple", "start_at_step": 0, "end_at_step": 2,
                 "return_with_leftover_noise": "enable"}},
        "s_lo": {"class_type": "KSamplerAdvanced", "inputs": {"model": ["shift_lo", 0], "positive": ["i2v", 0], "negative": ["i2v", 1],
                 "latent_image": ["s_hi", 0], "add_noise": "disable", "noise_seed": 0, "steps": 4, "cfg": 1.0,
                 "sampler_name": "euler", "scheduler": "simple", "start_at_step": 2, "end_at_step": 10000,
                 "return_with_leftover_noise": "disable"}},
        "decode": {"class_type": "VAEDecodeTiled", "inputs": {"samples": ["s_lo", 0], "vae": ["vae", 0], **TILED}},
        "video": {"class_type": "CreateVideo", "inputs": {"images": ["decode", 0], "fps": float(SET2_FPS)}},
        "save": {"class_type": "SaveVideo", "inputs": {"video": ["video", 0], "filename_prefix": f"series/{NAME}/clip_s{i}",
                 "format": "mp4", "codec": "h264"}},
    }


SERIES = {
    "elf": {"hero": HERO_V1, "style": STYLE_V1, "shots": shots_v1, "video": None},
    "elf_v2": {"hero": HERO_V2, "style": STYLE_V2, "shots": shots_v2,
               "video": {"lora": "Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors", "steps": 3, "cfg": 1.0,
                         "sampler": "lcm", "scheduler": "simple", "shift": 8.0}},
    "elf_set2": {"hero": HERO_V5, "style": STYLE_V2, "shots": shots_v3, "video": None, "set2": True},
    "elf_arcane3": {"hero": HERO_V5, "style": STYLE_ARCANE3, "shots": shots_arcane, "from": "elf_v5",
                    "denoise": float(os.environ.get("DENOISE", "0.55")),
                    "video": {"lora": "Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors", "steps": 3, "cfg": 1.0,
                              "sampler": "lcm", "scheduler": "simple", "shift": 8.0}},
    "elf_arcane2": {"hero": HERO_ARCANE2.replace(", realistic human proportions", ", natural proportions"),
                    "style": STYLE_ARCANE2, "shots": shots_arcane,
                    "video": {"lora": "Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors", "steps": 3, "cfg": 1.0,
                              "sampler": "lcm", "scheduler": "simple", "shift": 8.0}},
    "elf_arcane": {"hero": HERO_V5.replace(", realistic human proportions", ", natural proportions"),
                   "style": STYLE_ARCANE, "shots": shots_arcane,
                   "video": {"lora": "Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors", "steps": 3, "cfg": 1.0,
                             "sampler": "lcm", "scheduler": "simple", "shift": 8.0}},
    "elf_v5": {"hero": HERO_V5, "style": STYLE_V2, "shots": shots_v3,
               "video": {"lora": "Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors", "steps": 3, "cfg": 1.0,
                         "sampler": "lcm", "scheduler": "simple", "shift": 8.0}},
    "elf_v4": {"hero": HERO_V4, "style": STYLE_V2, "shots": shots_v3,
               "video": {"lora": "Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors", "steps": 3, "cfg": 1.0,
                         "sampler": "lcm", "scheduler": "simple", "shift": 8.0}},
    "elf_v3": {"hero": HERO_V3, "style": STYLE_V2, "shots": shots_v3,
               "video": {"lora": "Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors", "steps": 3, "cfg": 1.0,
                         "sampler": "lcm", "scheduler": "simple", "shift": 8.0}},
}
NAME = os.environ.get("SERIES", "elf")
_S = SERIES[NAME]
HERO, STYLE, VIDEO = _S["hero"], _S["style"], _S["video"]
SHOTS = _S["shots"](HERO, STYLE)
OUT = f"/data/output/series/{NAME}"
NEG_WAN = ("static, frozen, blurry details, subtitles, text, watermark, worst quality, low quality, JPEG artifacts, "
           "deformed, extra fingers, extra limbs, morphing face")


def post(path, body):
    req = urllib.request.Request(API + path, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def get(path):
    with urllib.request.urlopen(API + path, timeout=30) as r:
        return json.load(r)


def run(wf, ceiling_s):
    pid = post("/prompt", {"prompt": wf, "client_id": str(uuid.uuid4())})["prompt_id"]
    t0 = time.time()
    while time.time() - t0 < ceiling_s:
        hist = get("/history/" + pid)
        if pid in hist:
            entry = hist[pid]
            if entry.get("status", {}).get("status_str") == "error":
                raise SystemExit("prompt failed: " + json.dumps(entry["status"])[:3000])
            files = []
            for out in entry.get("outputs", {}).values():
                for v in out.values():
                    if isinstance(v, list):
                        files += [f for f in v if isinstance(f, dict) and "filename" in f]
            return time.time() - t0, files
        time.sleep(1)
    raise SystemExit(f"prompt {pid} not finished after {ceiling_s} s")


def path_of(f):
    return os.path.join("/data/output", f.get("subfolder", ""), f["filename"])


def keyframe_wf(i, shot):
    if _S.get("set2"):
        return qwen_keyframe_wf(i, shot)
    wf = _keyframe_wf(i, shot)
    src = _S.get("from")
    if src:  # img2img: restyle the accepted keyframe of another version instead of starting from noise
        wf["src"] = {"class_type": "LoadImage", "inputs": {"image": f"{src}_key_s{i}.png"}}
        wf["enc"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["src", 0], "vae": ["vae", 0]}}
        wf["sampler"]["inputs"].update({"latent_image": ["enc", 0], "denoise": _S["denoise"]})
        wf["save"]["inputs"]["filename_prefix"] = f"series/{NAME}/key_s{i}_d{int(_S['denoise'] * 100)}"
    return wf


def _keyframe_wf(i, shot):
    return {
        "unet": {"class_type": "UNETLoader", "inputs": {"unet_name": "z_image_turbo_bf16.safetensors", "weight_dtype": "default"}},
        "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen_3_4b.safetensors", "type": "lumina2", "device": "default"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "ae.safetensors"}},
        "shift": {"class_type": "ModelSamplingAuraFlow", "inputs": {"model": ["unet", 0], "shift": 3.0}},
        "pos": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": shot["key"]}},
        "neg": {"class_type": "ConditioningZeroOut", "inputs": {"conditioning": ["pos", 0]}},
        "latent": {"class_type": "EmptySD3LatentImage", "inputs": {"width": W, "height": H, "batch_size": 1}},
        "sampler": {"class_type": "KSampler", "inputs": {"model": ["shift", 0], "positive": ["pos", 0], "negative": ["neg", 0],
                    "latent_image": ["latent", 0], "seed": shot["seed"], "steps": 8, "cfg": 1.0,
                    "sampler_name": "res_multistep", "scheduler": "simple", "denoise": 1.0}},
        "decode": {"class_type": "VAEDecode", "inputs": {"samples": ["sampler", 0], "vae": ["vae", 0]}},
        "save": {"class_type": "SaveImage", "inputs": {"images": ["decode", 0], "filename_prefix": f"series/{NAME}/key_s{i}"}},
    }


def video_wf(i, shot, image_name):
    return {
        "unet": {"class_type": "UNETLoader", "inputs": {"unet_name": "wan2.2_ti2v_5B_fp16.safetensors", "weight_dtype": "default"}},
        "clip": {"class_type": "CLIPLoader", "inputs": {"clip_name": "umt5_xxl_fp8_e4m3fn_scaled.safetensors", "type": "wan", "device": "default"}},
        "vae": {"class_type": "VAELoader", "inputs": {"vae_name": "wan2.2_vae.safetensors"}},
        "shift": {"class_type": "ModelSamplingSD3", "inputs": {"model": ["unet", 0], "shift": 8.0}},
        "img": {"class_type": "LoadImage", "inputs": {"image": image_name}},
        "pos": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": shot["motion"] + " " + HERO + ". Cinematic."}},
        "neg": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["clip", 0], "text": NEG_WAN}},
        "latent": {"class_type": "Wan22ImageToVideoLatent", "inputs": {"vae": ["vae", 0], "width": W, "height": H,
                   "length": FRAMES, "batch_size": 1, "start_image": ["img", 0]}},
        "sampler": {"class_type": "KSampler", "inputs": {"model": ["shift", 0], "positive": ["pos", 0], "negative": ["neg", 0],
                    "latent_image": ["latent", 0], "seed": shot["seed"], "steps": 20, "cfg": 5.0,
                    "sampler_name": "uni_pc", "scheduler": "simple", "denoise": 1.0}},
        # Tiled: an untiled decode of 121 frames at 1280x704 spilled 33 GB into shared GPU memory on the R9700
        # (observed 2026-11-07) and crawled; 512 px tiles and 32-frame chunks keep it in the card's 32 GB.
        "decode": {"class_type": "VAEDecodeTiled", "inputs": {"samples": ["sampler", 0], "vae": ["vae", 0], **TILED}},
        "video": {"class_type": "CreateVideo", "inputs": {"images": ["decode", 0], "fps": float(FPS)}},
        "save": {"class_type": "SaveVideo", "inputs": {"video": ["video", 0], "filename_prefix": f"series/{NAME}/clip_s{i}",
                 "format": "mp4", "codec": "h264"}},
    }


def with_video_mode(wf):
    """Apply the series' video mode (a step-distill LoRA, its steps, cfg, sampler and shift) to a video workflow."""
    if not VIDEO:
        return wf
    wf["lora"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["unet", 0], "lora_name": VIDEO["lora"],
                  "strength_model": 1.0}}
    wf["shift"]["inputs"].update({"model": ["lora", 0], "shift": VIDEO["shift"]})
    wf["sampler"]["inputs"].update({"steps": VIDEO["steps"], "cfg": VIDEO["cfg"], "sampler_name": VIDEO["sampler"],
                                    "scheduler": VIDEO["scheduler"]})
    return wf


def existing(pattern):
    found = sorted(glob.glob(os.path.join(OUT, pattern)))
    return found[-1] if found else None


def keyframes():
    for i, shot in enumerate(SHOTS, 1):
        if existing(f"key_s{i}_*.png"):
            print(f"shot {i}: keyframe exists", flush=True)
            continue
        secs, files = run(keyframe_wf(i, shot), 900)
        print(f"shot {i}: keyframe {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


def videos():
    for i, shot in enumerate(SHOTS, 1):
        if existing(f"clip_s{i}_*.mp4"):
            print(f"shot {i}: clip exists", flush=True)
            continue
        key = existing(f"key_s{i}_*.png")
        if not key:
            raise SystemExit(f"shot {i}: no keyframe; run the keyframes phase first")
        name = f"{NAME}_key_s{i}.png"
        shutil.copyfile(key, os.path.join("/data/input", name))
        wf = wan14b_video_wf(i, shot, name) if _S.get("set2") else with_video_mode(video_wf(i, shot, name))
        secs, files = run(wf, 7200)
        print(f"shot {i}: clip {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


def concat():
    clips = [existing(f"clip_s{i}_*.mp4") for i in range(1, len(SHOTS) + 1)]
    if not all(clips):
        raise SystemExit("not every shot has a clip: " + str(clips))
    lst = os.path.join(OUT, "concat.txt")
    with open(lst, "w") as f:
        f.writelines(f"file '{c}'\n" for c in clips)
    dest = os.path.join(OUT, f"{NAME}_30s.mp4" if NAME != "elf" else "elf_escape_30s.mp4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst,
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", dest], check=True, timeout=600)
    probe = subprocess.run(["ffprobe", "-v", "error", "-count_frames", "-select_streams", "v:0", "-show_entries",
                            "stream=nb_read_frames,width,height:format=duration", "-of", "json", dest],
                           capture_output=True, text=True, timeout=300)
    print("joined:", dest, probe.stdout.replace("\n", " "), flush=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    phase = sys.argv[1] if len(sys.argv) > 1 else "all"
    if phase in ("keyframes", "all"):
        keyframes()
    if phase in ("videos", "all"):
        videos()
    if phase in ("concat", "all"):
        concat()
