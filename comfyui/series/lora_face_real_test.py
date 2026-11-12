"""Can the owner's chosen face become realistic? (2026-11-11: the owner — the realistic LoRA "does not look as I chose":
series/lora_test/slvra_v1_50_portrait, then "slvra_v1_70_portrait is even better".) The lora_test.py prompt and seed
(4242) of those portraits with slvra_v1 at 0.7 and 0.5, but the PHOTO style instead of the Arcane style; the realistic
LoRA slvrareal at 1.0 on the same seed for comparison. If the face holds, these pictures become the identity source of
the next realistic LoRA dataset.
Run inside the comfyui container:  python /opt/tests/lora_face_real_test.py
-> series/lora_test/realface_<lora>_<s>_<scene>_*.png
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lora_test as lt  # noqa: E402

story = lt.story
REAL = (", photorealistic live-action film still, a real young woman, natural skin texture, 35mm photo, shallow depth of "
        "field, cinematic natural light")
RUNS = [("slvra_v1.safetensors", 0.7, lt.LOOK), ("slvra_v1.safetensors", 0.5, lt.LOOK),
        ("slvrareal.safetensors", 1.0, lt.LOOK.replace("slvra, ", "slvrareal, "))]


def main():
    for lora, strength, look in RUNS:
        tag = f"realface_{os.path.splitext(lora)[0]}_{int(strength * 100)}"
        for name, scene in lt.SCENES.items():
            prefix = f"series/lora_test/{tag}_{name}"
            if story.existing(f"/data/output/{prefix}_*.png"):
                continue
            g = story.qwen_keyframe_wf(1, {"key": look + scene + REAL, "seed": 4242})
            g["slvra"] = {"class_type": "LoraLoaderModelOnly", "inputs": {"model": ["lora", 0], "lora_name": lora,
                                                                           "strength_model": strength}}
            g["shift"]["inputs"]["model"] = ["slvra", 0]
            g["save"]["inputs"]["filename_prefix"] = prefix
            secs, _ = story.run(g, 900)
            print(f"realface {tag} {name}: {secs:.1f} s", flush=True)


if __name__ == "__main__":
    main()
