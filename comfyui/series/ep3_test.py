"""Episode 3 feasibility tests on an idle GPU (EP3_SCRIPT.md v2; the consultants flagged the dragon's circling as risky):
clips WITHOUT her, from the design pictures (series/ep3/design), Wan 2.2 A14B + lightx2v 4 steps, one per call on a fresh
server.  python /opt/tests/ep3_test.py <name>   -> series/ep3/test/<name>_*.mp4
"""
import glob
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import episode2 as ep  # noqa: E402

D = "/data/output/series/ep3/design"
ARC = "Arcane style painted animation, consistent with the first frame."
TESTS = {
    "dragon_takeoff": ("dragon_3101", "The dragon spreads its torn wings wide, pushes off the broken tower and takes off into the "
                       "twilight sky, slates and dust falling from the tower; it rises and banks to the left around the "
                       "tower. Low angle, the camera tilts up to follow it."),
    "castle_aerial": ("castle_3102", "Slow aerial descent toward the castle gate along the winding road; crows circle the spires; "
                      "the last amber light fades on the lake. Smooth crane shot."),
}


def main():
    name = sys.argv[1]
    design, motion = TESTS[name]
    if ep.newest(f"/data/output/series/ep3/test/{name}_*.mp4"):
        print(f"ep3 test {name}: clip exists", flush=True)
        return
    src = sorted(glob.glob(f"{D}/{design}_*.png"))[-1]
    img = f"ep3_{name}.png"
    shutil.copyfile(src, os.path.join("/data/input", img))
    ep.story.HERO = ""  # no hero in these shots
    wf = ep.story.wan14b_video_wf(1, {"motion": f"{motion} {ARC}", "seed": 3301}, img)
    wf["save"]["inputs"]["filename_prefix"] = f"series/ep3/test/{name}"
    secs, files = ep.story.run(wf, 7200)
    print(f"ep3 test {name}: clip {secs:.1f} s -> {[f['filename'] for f in files]}", flush=True)


if __name__ == "__main__":
    main()
