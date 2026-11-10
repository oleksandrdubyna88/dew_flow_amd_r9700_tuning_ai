"""Episode 3 clips (the owner approved all 23 picks, 2026-11-10): one Wan 2.2 14B I2V clip (81 frames, 16 fps, 4 steps)
from each picked keyframe series/ep3/picks/sNN.png. Motion per EP3_SCRIPT.md v2 rows (keyframe sNN -> script row):
1-3 -> 1-3, 4-5 -> 4-5, 6 -> 6, 7-9 -> 7-9, 10-11 -> 10-11, 12 -> 12a, 13 -> 12b, 14-17 -> 13-16, 18-19 -> 17-18,
20 -> 19, 21 -> 20, 22 -> 21, 23 -> 22 (the airplane in its last 1-2 s is added in post, timed).
Rules kept: one motion per clip; the keyframe already has the final eye state — no blink words; positive words only
(the hero text of episodes 1-2 says "dark-green tunic" and "a tiny point" on the ears, so episode 3 has its own two
hero texts without ears); GAZE on shots where her eyes are seen.
Run inside the comfyui container (a fresh server per clip):  python /opt/tests/ep3_clips.py <k> [label] [shift]
  -> series/ep3/clips/clip_sNN<label>_*.mp4  (label "b" = another seed)
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import episode2 as ep  # noqa: E402
from eyes_try import GAZE  # noqa: E402

OUT = "series/ep3/clips"
STYLE = "Arcane style painted animation, consistent with the first frame."
LOOK = "a young woman with long flowing silver-white hair with one thin golden strand and a soft young face, "
HERO_T = LOOK + ("wearing a dark-green tunic with brown trim, a brown leather belt, brown leather bracers and boots, "
                 "realistic human proportions")
HERO_C = LOOK + ("wearing a sleeveless grey wool crop top, a short brown fur skirt on a wide leather belt, thigh-high "
                 "brown boots with fur cuffs and leather bracers, her arms bare, realistic human proportions")
# shot: (hero text or "" when she is not in the frame, eyes seen?, motion)
SHOTS = {
    1: ("", False, "The camera slowly descends toward the spired castle on the cliff above the dark lake; the old military "
        "4x4 with its headlights on rolls up to the gate and in under the arch; clouds drift, light mist over the lake."),
    2: (HERO_T, False, "Side tracking camera at waist height: she walks steadily across the empty cobbled courtyard toward "
        "the broken tower, looking up at it; at the end a huge dark shadow sweeps across the stones."),
    3: (HERO_T, False, "The dragon on the broken tower opens its torn wings wide and launches into the air; slates and "
        "stones rain down from the tower; her dark silhouette in the foreground stays still, her hair moves in the "
        "downdraft."),
    4: ("", False, "The dragon banks in a wide circle around the broken tower against the cloudy sky, its wings beating "
        "powerfully; the camera tilts to follow it."),
    5: ("", False, "The dragon glides past above the battlements in a wide turn, its wings beating slowly, its amber eyes "
        "glowing; the clouds drift behind it."),
    6: (HERO_T, True, "Almost still camera with a very slow push-in on her face; her eyes stay wide open, looking up at the "
        "sky; she takes one small breath through parted lips; the wind lifts a few strands of her hair; the sky is "
        "reflected in her eyes."),
    7: (HERO_T, False, "Slow dolly-in between the pillars of the vaulted hall toward her at the altar; dust floats in the "
        "shaft of light; the crystal on the altar glows and pulses softly; she stands still and looks down at the relics."),
    8: (HERO_T, True, "Her hands, already on the grips, lift the sword and the staff a few centimetres from the stone; a "
        "burst of many-coloured light flashes from the crystal and lights her face."),
    9: (HERO_T, True, "Still camera: the swirling glow of cyan, gold and violet light around her slowly darkens as a dome of "
        "black darkness closes over her and swallows the colours; a thin coloured rim stays at its edge; she stands "
        "still."),
    10: (HERO_T, False, "The camera cranes slowly up from her boots, which float a hand's width above the stone floor with "
         "a soft shadow below, to her torso; faint violet lightning flickers in the dark dome; she floats still."),
    11: (HERO_T, True, "The camera cranes slowly up from her torso toward the dark vault above; she floats still with her "
         "arms spread, the sword in one hand and the glowing crystal staff in the other; her silver hair floats around "
         "her; violet light pulses."),
    12: (HERO_T, True, "Extreme close-up: the camera pushes in slowly toward her right eye; small orange embers glow "
         "brighter inside both irises; her eyes stay wide open and steady."),
    13: ("", False, "Macro: the camera pushes slowly into the fiery iris toward the pupil; the orange and gold flames in the "
         "iris flicker and grow until fire fills the frame."),
    14: (HERO_C, False, "Low side view: she does two slow, strong push-ups on the stone floor, her body straight; torchlight "
         "flickers on the walls."),
    15: (HERO_C, False, "She pulls herself up on the iron beam slowly and strongly, her back and shoulder muscles working, "
         "her chin rising to the beam."),
    16: (HERO_C, False, "Side tracking camera: she runs fast along the top of the castle wall at sunrise, her silver hair "
         "and the fur panels of her skirt flowing with her stride; the camera keeps pace; the golden sun glows behind the "
         "castle."),
    17: (HERO_C, False, "Her sword strikes the automaton's round shield in a burst of orange sparks; the automaton swings "
         "its sword back and she ducks low under it; the camera drone hovers above them, its red light blinking."),
    18: (HERO_C, True, "The camera orbits slowly around the moonlit glade by about ninety degrees, past a dark tree trunk in "
         "the foreground; she lies still on the bear skin looking up at the stars; the campfire flickers, the stream "
         "flows."),
    19: (HERO_C, True, "The camera keeps orbiting slowly around her by about ninety degrees toward the side of her boots; "
         "she lies on the bear skin looking up; the fire flickers; the stream flows."),
    20: (HERO_C, True, "High angle: the camera rises slowly along her legs from the fur-topped boots to her waist; "
         "firelight flickers on the leather; at the end her hand clenches the fur."),
    21: (HERO_C, True, "Overhead view: the camera pulls slowly up and back until her whole body, the bear skin and the fire "
         "are in frame; her chest falls in a slow sigh; she looks up."),
    22: ("", False, "The camera rises slowly above the dark pine treetops; the small campfire glade below grows smaller; "
         "the canopy gives way to the starry sky."),
    23: ("", False, "Almost still: the camera tilts very slowly upward across the starry sky and the faint milky way above "
         "the dark pine tops."),
}


# The owner, 2026-11-10: short clips where the edit uses only 2-3 s (Act 1 arrival rows 1-3, Act 3 training rows 13-16):
# 49 frames = 3.06 s at 16 fps (~40 % less GPU time); the action must happen early in the clip.
SHORT = {1, 2, 3, 14, 15, 16, 17}
SHORT_FRAMES = 49


def shot(k, label="", shift=None):
    story = ep.story
    hero, eyes, motion = SHOTS[k]
    name = f"ep3_clip_s{k:02d}.png"
    shutil.copyfile(f"/data/output/series/ep3/picks/s{k:02d}.png", os.path.join("/data/input", name))
    story.HERO = hero
    seed = 3700 + k + (1000 if label == "b" else 0) + (2000 if label == "c" else 0)
    wf = story.wan14b_video_wf(k, {"motion": f"{motion} {GAZE if eyes else ''} {STYLE}", "seed": seed}, name)
    if k in SHORT:
        wf["i2v"]["inputs"]["length"] = SHORT_FRAMES
    if shift:
        wf["shift_hi"]["inputs"]["shift"] = shift
        wf["shift_lo"]["inputs"]["shift"] = shift
    tag = f"_shift{int(shift)}" if shift else ""
    wf["save"]["inputs"]["filename_prefix"] = f"{OUT}/clip_s{k:02d}{label}{tag}"
    # 2026-11-10: the timeline showed the VAE decode takes ~11.7 of ~17 min (a 2026-11-07 sweep measured 70-95 s): keep
    # the latent, so decode settings can be tested on it without sampling again
    wf["keep_latent"] = {"class_type": "SaveLatent", "inputs": {"samples": ["s_lo", 0],
                                                                "filename_prefix": f"latents/ep3/s{k:02d}{label}{tag}"}}
    secs, files = story.run(wf, 7200)
    print(f"ep3 clip s{k:02d}{label}: {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


if __name__ == "__main__":
    shot(int(sys.argv[1]), sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != "-" else "",
         float(sys.argv[3]) if len(sys.argv) > 3 else None)
