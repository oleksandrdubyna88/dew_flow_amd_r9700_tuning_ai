"""Pick a narrator reference take by measurement: Whisper's CER on the reference text (must be ~0), median pitch (lower is
deeper), duration (longer is slower). Run with the tts-env venv:  /tts/venv/bin/python /opt/tests/ref_pick.py <wav>...
"""
import os
import sys

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tts_samples import WIZARD_REF_TEXT  # noqa: E402
from tts_score import cer  # noqa: E402


def median_f0(wav, sr):
    hop, win, f0s = int(sr * 0.01), int(sr * 0.04), []
    for i in range(0, len(wav) - win, hop):
        x = wav[i:i + win] - wav[i:i + win].mean()
        if np.sqrt(np.mean(x * x)) < 0.02:
            continue
        ac = np.correlate(x, x, "full")[win - 1:]
        lo, hi = int(sr / 400), int(sr / 60)
        lag = lo + int(np.argmax(ac[lo:hi]))
        if ac[lag] > 0.3 * ac[0]:
            f0s.append(sr / lag)
    return float(np.median(f0s)) if f0s else float("nan")


def main():
    from transformers import pipeline
    asr = pipeline("automatic-speech-recognition", model="/models/tts/whisper-large-v3-turbo", device="cpu")
    for path in sys.argv[1:]:
        wav, sr = sf.read(path, dtype="float32", always_2d=True)
        wav = wav.mean(axis=1)
        hyp = asr({"raw": wav, "sampling_rate": sr}, generate_kwargs={"language": "russian", "task": "transcribe"})["text"].strip()
        print(f"{os.path.basename(path)}: {len(wav) / sr:.1f} s, median F0 {median_f0(wav, sr):.0f} Hz, "
              f"CER {cer(WIZARD_REF_TEXT, hyp):.3f} | {hyp}", flush=True)


if __name__ == "__main__":
    main()
