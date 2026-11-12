"""Episode 1 v3 edit and mix (the reviewer's critique, agreed 2026-11-10): picture from the FILM 32 fps clips (raw clips
when FILM is missing), the approved VoxCPM storyteller narration (tts/tune/vox_t10_n1..n6), Stable Audio 3 effects and a
quiet original music bed (audio/ep1). The picture follows the voice: s1 slowed for the long first line, s4 SPED UP 1.4x
(only with FILM, as agreed), the ending slowed (the owner likes the slow-motion end). At the start of s6 every effect and
the music CUT HARD to silence; the last line «А потом... наступила тишина...» comes in a cave echo, and the waterfall
returns softly after «тишина». Levels by loudness (ep3_edit.TARGET_LUFS idea), the music ducked under the narrator.
Run inside a container with ffmpeg:  python3 /opt/tests/ep1_edit.py [--out NAME]  -> series/elf_set2_arcane/v3/ep1_v3_<NAME>.mp4
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ep3_edit as e  # noqa: E402  (run, newest, duration, loudness, piece, T, FPS, W, H)

# EP1_DIR (2026-11-11): the realistic episode 1 (series/elf_real/ep1) uses this same edit and sound with its own clips
V3 = os.environ.get("EP1_DIR", "/data/output/series/elf_set2_arcane/v3")
AUD = "/data/output/audio/ep1"
NARR = "/data/output/tts/tune/vox_t10_n{}.wav"
TMP = f"{V3}/edit_tmp"
# shot -> clip label ("" = first seed); EP1_CHOICE="6:b,3:c" (2026-11-11) picks re-rolls without editing this file
CHOICE = {int(k): v for k, v in (p.split(":") for p in os.environ.get("EP1_CHOICE", "").split(",") if p)}
# shot: (source in-point s, output length s, speed); the source span is length * speed (<= the 5.06 s clip)
EDL = {1: (0.0, 7.0, 0.72), 2: (0.0, 5.0, 1.0), 3: (0.0, 4.0, 1.0), 4: (0.0, 3.6, 1.4), 5: (0.0, 5.5, 0.92),
       6: (0.0, 8.4, 0.6)}
LINE_AT = {1: 0.2, 2: 0.2, 3: 0.3, 4: 0.1, 5: 0.3, 6: 0.8}  # narration line k starts this long after shot k starts
GAP = 0.3
TARGET = {"voice": -18.0, "fx": -20.0, "bed": -27.0, "music": -26.0}
CAVE = "aecho=0.8:0.75:70|130|210:0.35|0.22|0.12"  # a small stone cave


def source(k):
    lab = CHOICE.get(k, "")
    return (e.newest(f"{V3}/film/clip_s{k}{lab}_32fps_*.mp4") or e.newest(f"{V3}/clip_s{k}{lab}_0*.mp4"))


def picture():
    os.makedirs(TMP, exist_ok=True)
    starts, t, parts = {}, 0.0, []
    for k, (start, length, speed) in EDL.items():
        src = source(k)
        if not src:
            raise SystemExit(f"no clip for s{k}")
        out = f"{TMP}/seg_{k}.mp4"
        e.piece(src, start, length * speed, speed, out)
        starts[k] = t
        t += e.duration(out)
        parts.append(out)
        print(f"  s{k}: {os.path.basename(src)} speed {speed}", flush=True)
    with open(f"{TMP}/all.txt", "w") as f:
        f.writelines(f"file '{p}'\n" for p in parts)
    e.run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", f"{TMP}/all.txt", "-c", "copy",
           f"{TMP}/picture.mp4"])
    return starts, t


def sound(starts, total):
    s6 = starts[6]
    inputs, chains, buckets = [], [], {"voice": [], "fx": [], "music": []}

    def add(path, at, kind, bucket, until=None, fade_in=0.0, fade_out=0.0, extra=""):
        if not path or not os.path.exists(path):
            print(f"  (missing, skipped) {path}")
            return None
        i = len(buckets["voice"]) + len(buckets["fx"]) + len(buckets["music"])
        if until is not None:
            inputs.extend(["-stream_loop", "-1"])
        inputs.extend(["-i", path])
        gain = 10 ** ((TARGET[kind] - e.loudness(path)) / 20)
        c = f"[{i}:a]aformat=sample_rates=48000:channel_layouts=stereo{extra}"
        length = (until - at) if until is not None else e.duration(path)
        if until is not None:
            c += f",atrim=0:{length:.3f}"
        if fade_in:
            c += f",afade=t=in:st=0:d={fade_in}"
        if fade_out:
            c += f",afade=t=out:st={max(0.0, length - fade_out):.3f}:d={fade_out}"
        c += f",volume={gain:.4f},adelay={int(at * 1000)}:all=1[a{i}]"
        chains.append(c)
        buckets[bucket].append(f"a{i}")
        print(f"  {at:6.2f} s  {os.path.basename(path)}  {kind}", flush=True)
        return at + length

    end_prev = 0.0
    for k in range(1, 7):
        at = max(starts[k] + LINE_AT[k], end_prev + GAP)
        end_prev = add(NARR.format(k), at, "voice", "voice", extra=f",{CAVE}" if k == 6 else "") or end_prev
    a = lambda n: e.newest(f"{AUD}/{n}_*.flac")  # noqa: E731
    add(a("dawn_forest"), 0.0, "bed", "fx", until=starts[2] + 0.5, fade_out=0.8)
    add(a("far_blasts"), starts[2], "fx", "fx", until=starts[3] + 0.3, fade_out=0.3)
    add(a("flash_blast"), starts[3] + 0.3, "fx", "fx", until=starts[4])
    add(a("forest_fire"), starts[4], "fx", "fx", until=starts[5] + 0.4, fade_out=0.4)
    add(a("boiling_river"), starts[5], "fx", "fx", until=s6)  # ends exactly at s6: the hard cut
    add(a("mus_bed"), 0.0, "music", "music", until=s6)  # the music too
    add(a("cave_waterfall"), s6 + 3.6, "bed", "fx", until=total, fade_in=1.5, fade_out=1.0)
    graph = list(chains)

    def mix(names, label):
        if not names:
            graph.append(f"anullsrc=r=48000:cl=stereo,atrim=0:{total:.3f}[{label}]")
            return
        ins = "".join(f"[{n}]" for n in names)
        graph.append(f"{ins}amix=inputs={len(names)}:normalize=0:dropout_transition=0,apad,atrim=0:{total:.3f}[{label}]")

    mix(buckets["voice"], "vo")
    mix(buckets["music"], "mu")
    mix(buckets["fx"], "fx")
    graph.append("[vo]asplit=2[vo1][vokey]")
    graph.append("[mu][vokey]sidechaincompress=threshold=0.03:ratio=8:attack=20:release=400[duck]")
    graph.append("[vo1][duck][fx]amix=inputs=3:normalize=0,alimiter=limit=0.95,loudnorm=I=-16:TP=-1.5:LRA=11[out]")
    out = f"{TMP}/sound.wav"
    e.run(["ffmpeg", "-y", "-v", "error", *e.T, *inputs, "-filter_complex", ";".join(graph), "-map", "[out]", "-ar",
           "48000", out], timeout=900)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="v1")
    a = ap.parse_args()
    starts, total = picture()
    print(f"picture {total:.2f} s; shot starts: " + ", ".join(f"s{k} {v:.2f}" for k, v in sorted(starts.items())))
    snd = sound(starts, total)
    final = f"{V3}/ep1_v3_{a.out}.mp4"
    e.run(["ffmpeg", "-y", "-v", "error", *e.T, "-i", f"{TMP}/picture.mp4", "-i", snd, "-map", "0:v", "-map", "1:a",
           "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", final])
    print(f"done {final} ({e.duration(final):.2f} s)")


if __name__ == "__main__":
    main()
