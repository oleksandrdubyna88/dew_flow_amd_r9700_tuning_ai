"""Episode 3 edit and mix (EP3_SCRIPT.md v2 timing): picture from the FILM 32 fps clips (raw 16 fps clips when a FILM
version is missing), sound from her lines (clone_t2), the ACE-Step song, Stable Audio 3 effects/beds/music.
Picture: one trimmed segment per shot (EDL), s19/s21/s23 slowed for the song/lines/ending, a speed ramp on the s17
strike, a short dissolve s12 -> s13 (the eye becomes fire), the airplane in the last 1.6 s of s23 drawn as blinking
navigation lights (the owner's request; a video model cannot time an event to the last second).
Sound: events placed relative to shot starts; music ducked under the voice (sidechain); beds span the cuts.
Run inside a container with ffmpeg:  python3 /opt/tests/ep3_edit.py [--song N] [--out NAME]
  -> series/ep3/ep3_castle_<NAME>.mp4 ; prints the timeline. ffmpeg uses -threads 2 (the owner: no heavy CPU jobs).
"""
import argparse
import glob
import json
import os
import subprocess

E3 = os.environ.get("EP3_DIR", "/data/output/series/ep3")  # 2026-11-13: the realistic ep3 sets EP3_DIR=series/ep3_real/<model>
AUD = "/data/output/audio/ep3"
LINES = "/data/output/tts/ep3/lines"
TMP = f"{E3}/edit_tmp"
FPS = 32
W, H = 1280, 704
T = ["-threads", "2"]
CHOICE = {} if os.environ.get("EP3_NO_CHOICE") else {1: "n", 6: "b", 11: "b", 20: "b", 21: "f"}  # kept clip labels; s01 c18 keyframe, s06 no blink, s11b cut before its wink at ~3.6 s, s20b, s21 flame-free
# shot: (source in-point s, output length s, speed) ; speed < 1 = slow motion. Script rows in EP3_SCRIPT.md.
EDL = {
    1: (0.0, 3.0, 1.0), 2: (0.0, 3.0, 1.0), 3: (0.0, 3.0, 1.0), 4: (0.0, 5.0, 1.0), 5: (0.0, 5.0, 1.0),
    6: (0.0, 4.0, 1.0), 7: (0.0, 3.0, 1.0), 8: (0.0, 2.6, 1.0), 9: (0.5, 4.0, 1.0), 10: (0.0, 5.0, 1.0),
    11: (0.0, 3.3, 1.0), 12: (0.5, 3.0, 1.0), 13: (2.5, 2.0, 1.0), 14: (0.5, 2.0, 1.0), 15: (1.0, 2.0, 1.0),
    16: (0.5, 2.0, 1.0), 17: (0.0, 3.0, 1.0), 18: (0.0, 5.0, 1.0), 19: (0.0, 7.0, 0.71), 20: (0.0, 5.0, 1.0),
    21: (0.0, 6.0, 0.83), 22: (0.0, 5.0, 1.0), 23: (0.0, 6.0, 0.83),
}
RAMP17 = [(0.0, 1.0, 1.0), (1.0, 0.5, 0.5), (1.5, 1.4, 1.0)]  # (src in, src length, speed): slow at the impact
DISSOLVE_12_13 = 0.15
PLANE_S = 1.6
# sound events: (file pattern, shot, offset from the shot start s, volume, kind) ; kind voice|music|fx ; bed = loops to
# its "until" shot end
VOICE = [
    (f"{LINES}/clone_t2_l1_first_words.wav", 6, 0.8, 1.0),
    ("SONG", 18, 0.5, 0.9),
    (f"{LINES}/clone_t2_l3_outburst.wav", 20, 0.4, 1.0),
    (f"{LINES}/clone_t2_l4_tired.wav", 21, 0.3, 1.0),
    (f"{LINES}/clone_t2_l5_magic.wav", 21, 2.6, 1.0),
    (f"{LINES}/clone_t2_l6_wish.wav", 22, 0.3, 1.0),
]
FX = [
    ("sfx_engine_gravel", 1, 0.0, 0.6), ("sfx_steps_courtyard", 2, 0.0, 0.6), ("sfx_wing_snap_roar", 3, 0.3, 0.8),
    ("sfx_wingbeats_pass", 4, 0.0, 0.7), ("sfx_wingbeats_pass", 5, 0.5, 0.6),
    ("sfx_relic_lift", 8, 0.2, 0.7), ("sfx_dome_close", 9, 0.0, 0.8), ("sfx_float_hum", 10, 0.0, 0.9),
    ("sfx_eye_ignite", 12, 1.0, 0.7), ("sfx_flame_roar", 13, 0.0, 0.8), ("sfx_pushups", 14, 0.0, 0.6),
    ("sfx_bar_creak", 15, 0.0, 0.6), ("sfx_run_wall", 16, 0.0, 0.6), ("sfx_clang_servo", 17, 0.9, 0.9),
    ("sfx_jet_far", 23, 3.0, 0.4),
]
# v2 (2026-11-10): Act 2 was nearly silent in v1 (LRA 15.8 LU) -> the hall tone is a bed under Act 2, louder hum, mus_act2
BEDS = [("sfx_wind_spires", 1, 6, 1.0), ("sfx_hall_tone", 7, 12, 1.0), ("sfx_glade_bed", 18, 23, 1.0)]  # (file, from, until shot end, vol)
MUSIC = [("mus_act1", 1, 0.0, 1.0), ("mus_act2", 7, 0.0, 1.0), ("mus_act3", 14, 0.0, 1.0), ("mus_cello", 22, 0.0, 1.0)]
# Loudness-based levels (2026-11-10): the generated files differ by ~30 LU (the forest bed -32 LUFS, the hall tone -44,
# the music -13), so a fixed volume factor made the beds inaudible. Each file is first brought to its kind's target
# loudness; the per-event factor above is then only a small relative tweak.
TARGET_LUFS = {"voice": -18.0, "fx": -18.0, "bed": -28.0, "music": -24.0}
_LOUD = {}


def loudness(path):
    """Integrated loudness (LUFS) of a file, measured once (ebur128)."""
    if path not in _LOUD:
        out = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", *T, "-i", path, "-af", "ebur128=framelog=quiet", "-f",
                              "null", "-"], capture_output=True, text=True, timeout=300).stderr
        vals = [ln.split("I:")[1].split("LUFS")[0].strip() for ln in out.splitlines() if ln.strip().startswith("I:")]
        try:
            _LOUD[path] = float(vals[-1])
        except (IndexError, ValueError):
            _LOUD[path] = -23.0
        if _LOUD[path] < -70:  # silence / "-inf": leave it alone
            _LOUD[path] = -23.0
    return _LOUD[path]


def run(cmd, timeout=900):
    subprocess.run(cmd, check=True, timeout=timeout, capture_output=True)


def newest(pattern):
    files = sorted(glob.glob(pattern))
    return files[-1] if files else None


def source(k):
    """The FILM 32 fps version of the kept clip, else the raw 16 fps clip."""
    lab = CHOICE.get(k, "")
    return newest(f"{E3}/film/clip_s{k:02d}{lab}_32fps_*.mp4") or newest(f"{E3}/clips/clip_s{k:02d}{lab}_0*.mp4")


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", path],
                         capture_output=True, text=True, check=True, timeout=60).stdout
    return float(json.loads(out)["format"]["duration"])


def piece(src, start, length, speed, out, extra=""):
    vf = f"setpts=(PTS-STARTPTS)/{speed},fps={FPS},scale={W}:{H}{extra}"
    run(["ffmpeg", "-y", "-v", "error", *T, "-ss", f"{start:.3f}", "-t", f"{length:.3f}", "-i", src, "-an", "-vf", vf,
         "-c:v", "libx264", "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p", out])


def plane(out_len):
    """Blinking navigation lights crossing the upper sky in the last PLANE_S s (t is the segment's own time)."""
    t0 = out_len - PLANE_S
    x = f"({W}*0.18+({W}*0.55)*(t-{t0:.3f})/{PLANE_S})"
    y = f"({H}*0.16-({H}*0.04)*(t-{t0:.3f})/{PLANE_S})"
    on = f"between(t,{t0:.3f},{out_len:.3f})"
    return (f",drawbox=x='{x}':y='{y}':w=3:h=3:color=white@0.95:t=fill:enable='{on}*lt(mod(t*1.6,1),0.18)'"
            f",drawbox=x='{x}-5':y='{y}+1':w=2:h=2:color=red@0.9:t=fill:enable='{on}'"
            f",drawbox=x='{x}+6':y='{y}+1':w=2:h=2:color=0x33ff66@0.9:t=fill:enable='{on}'")


def picture():
    os.makedirs(TMP, exist_ok=True)
    segs, starts, t = [], {}, 0.0
    for k, (start, length, speed) in EDL.items():
        src = source(k)
        if not src:
            raise SystemExit(f"no clip for s{k:02d}")
        out = f"{TMP}/seg_{k:02d}.mp4"
        if k == 17:
            parts = []
            for i, (s, ln, sp) in enumerate(RAMP17):
                p = f"{TMP}/seg_17_{i}.mp4"
                piece(src, s, ln, sp, p)
                parts.append(p)
            with open(f"{TMP}/r17.txt", "w") as f:
                f.writelines(f"file '{p}'\n" for p in parts)
            run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", f"{TMP}/r17.txt", "-c", "copy", out])
        else:
            piece(src, start, length * speed, speed, out, plane(length) if k == 23 else "")
        segs.append((k, out))
    # the dissolve s12 -> s13 makes one segment
    d12 = duration(f"{TMP}/seg_12.mp4")
    run(["ffmpeg", "-y", "-v", "error", *T, "-i", f"{TMP}/seg_12.mp4", "-i", f"{TMP}/seg_13.mp4", "-filter_complex",
         f"[0][1]xfade=transition=fade:duration={DISSOLVE_12_13}:offset={d12 - DISSOLVE_12_13:.3f},format=yuv420p",
         "-c:v", "libx264", "-preset", "medium", "-crf", "17", f"{TMP}/seg_12_13.mp4"])
    final = []
    for k, out in segs:
        if k == 13:
            continue
        if k == 12:
            out = f"{TMP}/seg_12_13.mp4"
        starts[k] = t
        if k == 12:
            starts[13] = t + d12 - DISSOLVE_12_13
        final.append(out)
        t += duration(out)
    with open(f"{TMP}/all.txt", "w") as f:
        f.writelines(f"file '{p}'\n" for p in final)
    run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", f"{TMP}/all.txt", "-c", "copy",
         f"{TMP}/picture.mp4"])
    return starts, t


def ends(starts, total):
    keys = sorted(starts)
    return {k: (starts[keys[i + 1]] if i + 1 < len(keys) else total) for i, k in enumerate(keys)}


def sound(starts, total, song):
    end = ends(starts, total)
    inputs, voice, music, fx = [], [], [], []
    count = [0]  # the ffmpeg input index (one per file; NOT len(inputs) — "-i path" and "-stream_loop -1" are 2 items)

    def add(path, at, vol, bucket, kind, loop_until=None, fade_out=0.0):
        if not path or not os.path.exists(path):
            print(f"  (missing, skipped) {path}")
            return
        gain_db = TARGET_LUFS[kind] - loudness(path)
        vol = vol * 10 ** (gain_db / 20)
        i = count[0]
        count[0] += 1
        if loop_until is not None:
            inputs.extend(["-stream_loop", "-1"])
        inputs.extend(["-i", path])
        chain = f"[{i}:a]aformat=sample_rates=48000:channel_layouts=stereo"
        if loop_until is not None:
            chain += f",atrim=0:{loop_until - at:.3f}"
        if fade_out:
            length = (loop_until - at) if loop_until is not None else duration(path)
            chain += f",afade=t=out:st={max(0.0, length - fade_out):.3f}:d={fade_out}"
        chain += f",volume={vol:.4f},adelay={int(at * 1000)}:all=1[a{i}]"
        bucket.append((f"a{i}", chain))
        print(f"  {at:6.2f} s  {os.path.basename(path)}  ({loudness(path):.1f} LUFS -> {kind} {gain_db:+.1f} dB)")

    song_file = newest(f"{AUD}/song_{song}_*.flac")
    for path, k, off, vol in VOICE:
        add(song_file if path == "SONG" else path, starts[k] + off, vol, voice, "voice")
    for name, k, off, vol in FX:
        add(newest(f"{AUD}/{name}_*.flac"), starts[k] + off, vol, fx, "fx")
    for name, k0, k1, vol in BEDS:
        add(newest(f"{AUD}/{name}_*.flac"), starts[k0], vol, fx, "bed", loop_until=end[k1], fade_out=2.5)
    for name, k, off, vol in MUSIC:
        add(newest(f"{AUD}/{name}_*.flac"), starts[k] + off, vol, music, "music", fade_out=2.0)
    graph = [c for _, c in voice + music + fx]

    def mix(bucket, label):
        if not bucket:
            graph.append(f"anullsrc=r=48000:cl=stereo,atrim=0:{total:.3f}[{label}]")
            return
        ins = "".join(f"[{n}]" for n, _ in bucket)
        graph.append(f"{ins}amix=inputs={len(bucket)}:normalize=0:dropout_transition=0,apad,atrim=0:{total:.3f}[{label}]")

    mix(voice, "vo")
    mix(music, "mu")
    mix(fx, "fx")
    graph.append("[vo]asplit=2[vo1][vokey]")
    graph.append("[mu][vokey]sidechaincompress=threshold=0.03:ratio=8:attack=20:release=400[duck]")
    graph.append("[vo1][duck][fx]amix=inputs=3:normalize=0,alimiter=limit=0.95,loudnorm=I=-16:TP=-1.5:LRA=11[out]")
    out = f"{TMP}/sound.wav"
    run(["ffmpeg", "-y", "-v", "error", *T, *inputs, "-filter_complex", ";".join(graph), "-map", "[out]", "-ar", "48000",
         out], timeout=900)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--song", type=int, default=1)
    ap.add_argument("--out", default="v1")
    ap.add_argument("--reuse-picture", action="store_true", help="keep edit_tmp/picture.mp4 and its timeline.json")
    a = ap.parse_args()
    if a.reuse_picture and os.path.exists(f"{TMP}/timeline.json"):
        with open(f"{TMP}/timeline.json") as f:
            saved = json.load(f)
        starts, total = {int(k): v for k, v in saved["starts"].items()}, saved["total"]
    else:
        starts, total = picture()
        with open(f"{TMP}/timeline.json", "w") as f:
            json.dump({"starts": starts, "total": total}, f)
    print(f"picture {total:.2f} s; shot starts: " + ", ".join(f"s{k:02d} {v:.2f}" for k, v in sorted(starts.items())))
    snd = sound(starts, total, a.song)
    final = f"{E3}/ep3_castle_{a.out}.mp4"
    run(["ffmpeg", "-y", "-v", "error", *T, "-i", f"{TMP}/picture.mp4", "-i", snd, "-map", "0:v", "-map", "1:a", "-c:v",
         "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", final])
    print(f"done {final} ({duration(final):.2f} s)")


if __name__ == "__main__":
    main()
