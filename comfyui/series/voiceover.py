"""Mix a six-line voice-over into a 30 s film without rushing a slow narrator.

Line k starts at the later of (its shot's start + 0.2 s) and (the end of line k-1 + 0.3 s); a line longer than its shot is
sped up at most MAX_TEMPO (barely audible), never more — a solemn voice sped up 30 % loses its character. When the
narration ends after the film, the film's last frame is held (tpad) until the narration ends + 0.8 s.

Run inside a container with ffmpeg:  python3 /opt/tests/voiceover.py <film.mp4> <tts prefix> [--shot 5.04]
e.g.  voiceover.py /data/output/series/elf_set2/elf_set2_reroll_30s.mp4 tune/qwen_batch6 --shot 5.0625
Reads /data/output/tts/<prefix>_n1..n6.wav; writes <film>_vo_<basename of prefix>.mp4 and prints each line's timing.
"""
import argparse
import json
import os
import subprocess

MAX_TEMPO = 1.08
GAP_S = 0.3
TAIL_S = 0.8
FFMPEG_TIMEOUT_S = 600


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", path],
                         capture_output=True, text=True, check=True, timeout=60).stdout
    return float(json.loads(out)["format"]["duration"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("film")
    ap.add_argument("prefix")
    ap.add_argument("--shot", type=float, default=5.04)
    ap.add_argument("--end", choices=["hold", "slowmo"], default="hold", help="how the picture covers a longer narration")
    a = ap.parse_args()
    film_s = duration(a.film)
    inputs, chains, end = [], [], 0.0
    import glob
    count = len(glob.glob(f"/data/output/tts/{a.prefix}_n*.wav"))  # six lines in episode 1, eight in episode 2
    if count < 1:
        raise SystemExit(f"no narration files /data/output/tts/{a.prefix}_n*.wav")
    for k in range(1, count + 1):
        wav = f"/data/output/tts/{a.prefix}_n{k}.wav"
        d = duration(wav)
        tempo = min(MAX_TEMPO, max(1.0, d / (a.shot - 0.4)))
        start = max((k - 1) * a.shot + 0.2, end + GAP_S if k > 1 else 0.2)
        end = start + d / tempo
        inputs += ["-i", wav]
        ms = int(start * 1000)
        # every line from t=0 (asetpts), one channel, then delayed: the first version lost the timestamps (a 0.008 s track)
        chains.append(f"[{k - 1}:a]asetpts=PTS-STARTPTS,aresample=48000,aformat=channel_layouts=mono,"
                      f"atempo={tempo:.3f},adelay={ms}:all=1[a{k}]")
        print(f"line {k}: {d:.2f} s, tempo {tempo:.3f}, {start:.2f}-{end:.2f} s (shot starts {(k - 1) * a.shot:.2f})", flush=True)
    total = max(film_s, end + TAIL_S)
    # step 1: the narration alone, padded to the film's length, as a WAV that is checked before it is used
    track = a.film.replace(".mp4", f"_vo_{os.path.basename(a.prefix)}.wav")
    mix = ";".join(chains) + ";" + "".join(f"[a{k}]" for k in range(1, count + 1)) + \
        f"amix=inputs={count}:normalize=0:duration=longest,loudnorm=I=-16:TP=-1.5:LRA=11,aresample=48000,apad=whole_dur={total:.3f}[vo]"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *inputs, "-filter_complex", mix, "-map", "[vo]", "-ac", "2",
                    "-ar", "48000", "-t", f"{total:.3f}", track], check=True, timeout=FFMPEG_TIMEOUT_S)
    check_track(track, total)
    # step 2: the film and the track; the last frame held while the narrator finishes; faststart so a player can seek
    video = ["-map", "0:v", "-c:v", "copy"]
    vf = []
    if total > film_s + 0.05 and a.end == "slowmo":
        # the last shot plays slower until the narrator finishes, motion-interpolated (no frozen picture; the owner,
        # 2026-11-09: "the video has ended but the sound still goes on")
        fps = frame_rate(a.film)
        t0 = film_s - a.shot
        f = (total - t0) / a.shot
        vf = ["-filter_complex",
              f"[0:v]split[x][y];[x]trim=0:{t0:.4f},setpts=PTS-STARTPTS[p];"
              f"[y]trim=start={t0:.4f},setpts=(PTS-STARTPTS)*{f:.4f},"
              f"minterpolate=fps={fps}:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1[q];[p][q]concat=n=2:v=1[v]"]
        video = ["-map", "[v]", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18"]
        print(f"ending: the last shot slowed {f:.2f}x ({a.shot:.2f} s -> {total - t0:.2f} s) at {fps} fps", flush=True)
    elif total > film_s + 0.05:
        vf = ["-filter_complex", f"[0:v]tpad=stop_mode=clone:stop_duration={total - film_s:.3f}[v]"]
        video = ["-map", "[v]", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18"]
    suffix = "_slowmo" if a.end == "slowmo" else ""
    dest = a.film.replace(".mp4", f"_vo_{os.path.basename(a.prefix)}{suffix}.mp4")
    # two threads: the owner (2026-11-09) uses the PC while jobs run; full-CPU jobs froze it
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-threads", "2", "-filter_threads", "1", "-i", a.film, "-i", track, *vf, *video, "-map", "1:a",
                    "-c:a", "aac", "-b:a", "192k", "-t", f"{total:.3f}", "-threads", "2", "-movflags", "+faststart", dest],
                   check=True, timeout=FFMPEG_TIMEOUT_S)
    check_track(dest, total)
    print(f"written: {dest} ({total:.1f} s; film {film_s:.1f} s)", flush=True)


def frame_rate(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=r_frame_rate", "-of",
                          "csv=p=0", path], capture_output=True, text=True, check=True, timeout=60).stdout.strip()
    num, den = out.split("/")
    return round(int(num) / int(den))


def check_track(path, total):
    """Refuse a file whose audio is shorter than the film or silent (the first version wrote a 0.008 s, -91 dB track)."""
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=duration,start_time",
                          "-of", "json", path], capture_output=True, text=True, check=True, timeout=60).stdout
    s = json.loads(out)["streams"][0]
    dur, start = float(s.get("duration", 0)), float(s.get("start_time", 0))
    vol = subprocess.run(["ffmpeg", "-hide_banner", "-i", path, "-map", "0:a", "-af", "volumedetect", "-f", "null", "-"],
                         capture_output=True, text=True, timeout=FFMPEG_TIMEOUT_S).stderr
    mean = float(vol.split("mean_volume:")[1].split("dB")[0])
    if dur < total - 0.5 or abs(start) > 0.1 or mean < -50:
        raise SystemExit(f"{path}: bad audio: duration {dur:.3f} s (want {total:.1f}), start {start:.3f}, mean {mean:.1f} dB")
    print(f"audio ok: {os.path.basename(path)} {dur:.1f} s, start {start:.3f}, mean {mean:.1f} dB", flush=True)


if __name__ == "__main__":
    main()
