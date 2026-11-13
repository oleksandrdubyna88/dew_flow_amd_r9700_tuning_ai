"""Re-roll episode 2's shot 8 (the truck must drive AWAY from the camera into the sunset): four seeds, Qwen then Arcane."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import episode2 as ep  # noqa: E402

KEY = ("View from behind the vehicle, the camera following it: the rear of an old boxy military off-road truck like a classic "
       "Humvee, without any logo, seen from the back, driving away from the camera along an empty cracked road straight "
       "into a blazing red-orange sunset on the horizon ahead of it, dust trailing behind, dead trees along the road, "
       "its tail lights glowing; nobody on the roof or around the vehicle, the driver hidden inside, a plain tailgate with no emblem or lettering.")
for seed in (358, 368, 378, 388):
    wf = ep.story.qwen_keyframe_wf(8, {"key": f"{KEY} {ep.PHOTO}", "seed": seed})
    wf["save"]["inputs"]["filename_prefix"] = f"series/ep2/reroll8/key_seed{seed}"
    secs, _ = ep.story.run(wf, 900)
    print(f"seed {seed}: {secs:.1f} s", flush=True)
