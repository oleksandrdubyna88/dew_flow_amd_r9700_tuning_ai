"""Check the sung line of episode 3 by ear-free means: Whisper large-v3-turbo (Russian) transcribes each ACE-Step song
take, and the character error rate (CER) against the lyric «Столько лет прошло, всё о том же… гудят поезда…» picks the
take that sings the words. Run like tts_score.py (the tts-env venv, the GPU):
  wslc run --rm --gpus all -v tts-env:/tts -v comfy-models:/models:ro -v <output>:/out -v <tests>:/opt/tests:ro `
    --entrypoint /tts/venv/bin/python comfyui-r9700:local /opt/tests/song_asr.py /out/audio/ep3/song_*.flac
"""
import re
import sys

import torch
from transformers import pipeline

LYRIC = "Столько лет прошло, всё о том же… гудят поезда…"


def norm(s):
    s = s.lower().replace("ё", "е")
    return " ".join(re.sub(r"[^\w\s]", " ", s).split())


def cer(ref, hyp):
    r, h = norm(ref), norm(hyp)
    d = list(range(len(h) + 1))
    for i, rc in enumerate(r, 1):
        prev, d[0] = d[0], i
        for j, hc in enumerate(h, 1):
            prev, d[j] = d[j], min(d[j] + 1, d[j - 1] + 1, prev + (rc != hc))
    return d[len(h)] / max(1, len(r))


def main(files):
    asr = pipeline("automatic-speech-recognition", model="/models/tts/whisper-large-v3-turbo", torch_dtype=torch.float16,
                   device="cuda:0")
    for f in files:
        text = asr(f, generate_kwargs={"language": "russian", "task": "transcribe"})["text"].strip()
        print(f"{f.split('/')[-1]}  CER {cer(LYRIC, text):.2f}  «{text}»", flush=True)


if __name__ == "__main__":
    main(sys.argv[1:])
