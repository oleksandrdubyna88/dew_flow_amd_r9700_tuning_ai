"""Test the character LoRA "slvra" (trained by lora_train.sh on Qwen-Image): keyframes from TEXT ONLY, no reference images,
with Qwen-Image 2512 fp8 + the Lightning 4-step LoRA + slvra, the same seeds once without slvra for comparison.
Run inside the comfyui container (the LoRA copied to /models/loras first):
  python /opt/tests/lora_test.py <lora file name in /models/loras> [strength]
Writes series/lora_test/<lora>_<s>_<scene>_*.png and series/lora_test/base_<scene>_*.png.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import series_elf as story  # noqa: E402

LOOK = ("slvra, a young woman of about twenty with long silver-white hair and one thin golden strand, a youthful smooth face, "
        "big eyes, wearing a dark-green tunic with brown trim, a brown belt and brown leather bracers, ")
STYLE = ", painted Arcane animation style, cinematic lighting"
SCENES = {
    "portrait": "close-up portrait, looking at the camera, soft daylight",
    "forest_run": "running along a sunlit path in a green summer forest, full body",
    "snow_cave": "standing at a cave mouth in falling grey ash, a leather bag on her shoulder, medium shot",
    "campfire": "sitting by a campfire at night, firelight on her face, medium close-up",
}


SOFT = ", soft delicate facial features, gentle face"
# candidates for the second LoRA (the owner, 2026-11-09: keep v1; train another that may keep softer facial features)
SOFT_SET = [
    "close-up portrait, looking at the camera, soft daylight", "close-up portrait, a gentle small smile, golden hour",
    "close-up portrait, head turned three-quarters to the left, forest light", "close-up portrait in profile, facing right",
    "close-up portrait, looking up at falling snow", "close-up portrait, lit by a campfire at night",
    "half-body, standing in a green summer forest", "half-body, by a waterfall in a cave, mist",
    "half-body, walking in a dead winter forest, grey sky", "half-body, sitting on a fur bedroll by a fire",
    "half-body, looking over her shoulder, sunset", "close-up, worried face, eyes wide, dark forest",
]


def softset(lora, strength):
    """Two seeds per prompt of SOFT_SET with the LoRA at a low strength and the soft words -> series/lora_v2_cand/."""
    for i, scene in enumerate(SOFT_SET, 1):
        for seed in (5100 + i, 5200 + i):
            g = story.qwen_keyframe_wf(1, {"key": LOOK + scene + SOFT + STYLE, "seed": seed})
            g["slvra"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["lora", 0], "lora_name": lora,
                                                                           "strength_model": strength}}
            g["shift"]["inputs"]["model"] = ["slvra", 0]
            g["save"]["inputs"]["filename_prefix"] = f"series/lora_v2_cand/c{i:02d}_s{seed}"
            secs, _ = story.run(g, 900)
            print(f"soft candidate {i} seed {seed}: {secs:.1f} s", flush=True)


def main():
    if sys.argv[1] == "softset":
        softset(sys.argv[2], float(sys.argv[3]))
        return
    soft = "--soft" in sys.argv
    args = [a for a in sys.argv[1:] if a != "--soft"]
    lora = args[0]
    strength = float(args[1]) if len(args) > 1 else 1.0
    tag = os.path.splitext(lora)[0] + ("_soft" if soft else "")
    for name, scene in SCENES.items():
        for use in (True, False):
            if not use and story.existing(f"/data/output/series/lora_test/base_{name}_*.png"):
                continue
            g = story.qwen_keyframe_wf(1, {"key": (LOOK if use else LOOK.replace("slvra, ", "")) + scene + (SOFT if soft else "") + STYLE,
                                           "seed": 4242})
            if use:
                g["slvra"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["lora", 0], "lora_name": lora,
                                                                               "strength_model": strength}}
                g["shift"]["inputs"]["model"] = ["slvra", 0]
            prefix = f"series/lora_test/{tag}_{int(strength * 100)}_{name}" if use else f"series/lora_test/base_{name}"
            g["save"]["inputs"]["filename_prefix"] = prefix
            secs, _ = story.run(g, 900)
            print(f"{'slvra' if use else 'base '} {name}: {secs:.1f} s", flush=True)


if __name__ == "__main__":
    main()
