"""Episode 2 upgrade (the owner, 2026-11-10: "add e2" = FILM + the new sound design, NO new clips, for BOTH approved
versions — Arcane v4 and realistic). The picture = the approved 9 clips (their concat lists) in the FILM 32 fps versions;
the narration = the approved VoxCPM lines tts/ep2/vox_n1..n8 placed by the approved rules of voiceover.py (line k at
shot k + 0.2 s or the previous line's end + 0.3 s, tempo <= 1.08); the slow-motion end is kept (the last shot slowed
until the narration ends + 0.8 s; the FILM clip makes it smooth without minterpolate). New: one effect per shot and a
music bed (audio/ep2), levels by loudness, the music ducked under the narrator.
Run inside a container with ffmpeg:  python3 /opt/tests/ep2_upgrade.py arcane|real
  -> series/ep2/ep2_arcane_v5_sound.mp4 | series/ep2_real/ep2_real_v2_sound.mp4
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ep3_edit as e  # noqa: E402

VERSIONS = {
    "arcane": ("/data/output/series/ep2/concat_v4.txt", "/data/output/series/ep2/film/a_s{}_32fps",
               "/data/output/series/ep2/ep2_arcane_v5_sound.mp4"),
    "real": ("/data/output/series/ep2_real/concat.txt", "/data/output/series/ep2_real/film/r_s{}_32fps",
             "/data/output/series/ep2_real/ep2_real_v2_sound.mp4"),
    # the episode 2 REDO (2026-11-11, the owner: "redo e2 in the same spirit"): new keyframes and clips (ep2_v6.py)
    "v6": ("/data/output/series/ep2/v6/concat.txt", "/data/output/series/ep2/v6/film/s{}_32fps",
           "/data/output/series/ep2/ep2_v6.mp4"),
}
NARR = "/data/output/tts/ep2/vox_n{}.wav"
AUD = "/data/output/audio/ep2"
SHOT = 5.0625
MAX_TEMPO, GAP, TAIL = 1.08, 0.3, 0.8
FX = ["cave_fire", "sleep_embers", "storm_clouds", "dead_forest", "wolves", "leave_cave", "truck_start", "drive",
      "rise_wind"]  # one per shot 1..9
TARGET = {"voice": -18.0, "fx": -22.0, "music": -25.0}


def clips(version):
    with open(VERSIONS[version][0]) as f:
        return [ln.split("'")[1] for ln in f if ln.startswith("file")]


def film_paths(version):
    """The FILM version of each clip when it exists, else the raw clip."""
    raw = clips(version)
    return [e.newest(VERSIONS[version][1].format(k) + "_*.mp4") or raw[k - 1] for k in range(1, len(raw) + 1)]


def narration():
    lines, end = [], 0.0
    k = 1
    while os.path.exists(NARR.format(k)):
        d = e.duration(NARR.format(k))
        tempo = min(MAX_TEMPO, max(1.0, d / (SHOT - 0.4)))
        start = max((k - 1) * SHOT + 0.2, end + GAP if k > 1 else 0.2)
        end = start + d / tempo
        lines.append((NARR.format(k), start, tempo))
        k += 1
    return lines, end


def picture(version, total, tmp):
    srcs = film_paths(version)
    os.makedirs(tmp, exist_ok=True)
    parts = []
    for k, src in enumerate(srcs, 1):
        out = f"{tmp}/seg_{k}.mp4"
        if k < len(srcs):
            e.piece(src, 0.0, SHOT, 1.0, out)
        else:  # the slow-motion end: the last shot covers the rest of the narration
            rest = max(SHOT, total - SHOT * (len(srcs) - 1))
            e.piece(src, 0.0, SHOT, SHOT / rest, out)
        parts.append(out)
        print(f"  s{k}: {os.path.basename(src)}", flush=True)
    with open(f"{tmp}/all.txt", "w") as f:
        f.writelines(f"file '{p}'\n" for p in parts)
    e.run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", f"{tmp}/all.txt", "-c", "copy",
           f"{tmp}/picture.mp4"])
    return e.duration(f"{tmp}/picture.mp4")


def sound(lines, total, tmp):
    inputs, chains, buckets = [], [], {"voice": [], "fx": [], "music": []}

    def add(path, at, kind, until=None, tempo=1.0, fade_out=0.0):
        if not path or not os.path.exists(path):
            print(f"  (missing, skipped) {path}")
            return
        i = sum(len(v) for v in buckets.values())
        inputs.extend(["-i", path])
        gain = 10 ** ((TARGET[kind] - e.loudness(path)) / 20)
        c = f"[{i}:a]asetpts=PTS-STARTPTS,aformat=sample_rates=48000:channel_layouts=stereo"
        if tempo != 1.0:
            c += f",atempo={tempo:.3f}"
        length = (until - at) if until is not None else e.duration(path) / tempo
        if until is not None:
            c += f",atrim=0:{length:.3f}"
        if fade_out:
            c += f",afade=t=out:st={max(0.0, length - fade_out):.3f}:d={fade_out}"
        c += f",volume={gain:.4f},adelay={int(at * 1000)}:all=1[a{i}]"
        chains.append(c)
        buckets[kind].append(f"a{i}")
        print(f"  {at:6.2f} s  {os.path.basename(path)}  {kind}", flush=True)

    for path, start, tempo in lines:
        add(path, start, "voice", tempo=tempo)
    for k, name in enumerate(FX, 1):
        at = (k - 1) * SHOT
        until = min(total, at + SHOT + 0.4) if k < len(FX) else total
        add(e.newest(f"{AUD}/{name}_*.flac"), at, "fx", until=until, fade_out=0.4 if k < len(FX) else 2.0)
    add(e.newest(f"{AUD}/mus_ep2_*.flac"), 0.0, "music", until=total, fade_out=3.0)
    graph = list(chains)
    for kind, label in (("voice", "vo"), ("music", "mu"), ("fx", "fx")):
        names = buckets[kind]
        if names:
            graph.append("".join(f"[{n}]" for n in names) +
                         f"amix=inputs={len(names)}:normalize=0:dropout_transition=0,apad,atrim=0:{total:.3f}[{label}]")
        else:
            graph.append(f"anullsrc=r=48000:cl=stereo,atrim=0:{total:.3f}[{label}]")
    graph.append("[vo]asplit=2[vo1][vokey]")
    graph.append("[mu][vokey]sidechaincompress=threshold=0.03:ratio=8:attack=20:release=400[duck]")
    graph.append("[vo1][duck][fx]amix=inputs=3:normalize=0,alimiter=limit=0.95,loudnorm=I=-16:TP=-1.5:LRA=11[out]")
    out = f"{tmp}/sound.wav"
    e.run(["ffmpeg", "-y", "-v", "error", *e.T, *inputs, "-filter_complex", ";".join(graph), "-map", "[out]", "-ar",
           "48000", out], timeout=900)
    return out


def main(version):
    lines, end = narration()
    n_clips = len(clips(version))
    total = max(SHOT * n_clips, end + TAIL)
    tmp = os.path.dirname(VERSIONS[version][2]) + f"/upgrade_tmp_{version}"
    pic = picture(version, total, tmp)
    print(f"{version}: picture {pic:.2f} s, narration ends {end:.2f} s, {len(lines)} lines", flush=True)
    snd = sound(lines, pic, tmp)
    final = VERSIONS[version][2]
    e.run(["ffmpeg", "-y", "-v", "error", *e.T, "-i", f"{tmp}/picture.mp4", "-i", snd, "-map", "0:v", "-map", "1:a",
           "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", final])
    print(f"done {final} ({e.duration(final):.2f} s)", flush=True)


if __name__ == "__main__":
    main(sys.argv[1])
