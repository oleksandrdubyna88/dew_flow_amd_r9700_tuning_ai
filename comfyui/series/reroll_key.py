"""Re-roll one keyframe of a series with other seeds, to replace a keyframe with a bad pose.

Run inside the container:  wslc exec -e SERIES=elf_set2 -e SHOT=2 comfyui python /opt/tests/reroll_key.py 1202 2202 3202
Writes /data/output/series/<series>/reroll/key_s<k>_seed<seed>_*.png; the series' own keyframes are not touched.
Only for a series whose keyframes come from qwen_keyframe_wf (set 2).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import series_elf as story  # noqa: E402


def clip(k, seed):
    """Render the shot's clip from the re-rolled keyframe of <seed> (set 2's 14B workflow), into reroll/."""
    import glob
    import shutil
    src = sorted(glob.glob(f"{story.OUT}/reroll/key_s{k}_seed{seed}_*.png"))[-1]
    name = f"{story.NAME}_reroll_s{k}_seed{seed}.png"
    shutil.copyfile(src, os.path.join("/data/input", name))  # output is another mount: copy, never rename
    wf = story.wan14b_video_wf(k, story.SHOTS[k - 1], name)
    wf["save"]["inputs"]["filename_prefix"] = f"series/{story.NAME}/reroll/clip_s{k}_seed{seed}"
    secs, files = story.run(wf, 7200)
    print(f"shot {k} seed {seed}: clip {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


def main():
    k = int(os.environ.get("SHOT", "2"))
    if sys.argv[1:2] == ["clip"]:
        return clip(k, int(sys.argv[2]))
    seeds = [int(s) for s in sys.argv[1:]] or [1202, 2202, 3202, 4202]
    shot = story.SHOTS[k - 1]
    for seed in seeds:
        wf = story.qwen_keyframe_wf(k, dict(shot, seed=seed))
        wf["save"]["inputs"]["filename_prefix"] = f"series/{story.NAME}/reroll/key_s{k}_seed{seed}"
        secs, files = story.run(wf, 900)
        print(f"shot {k} seed {seed}: {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


if __name__ == "__main__":
    main()
