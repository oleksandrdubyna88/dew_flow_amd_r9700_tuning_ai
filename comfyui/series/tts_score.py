"""Score narration files by intelligibility: Whisper large-v3-turbo transcribes each file, the character error rate (CER)
against the script line is computed on normalised text (lower case, no punctuation, ё→е, single spaces).

Run in a throwaway container with the TTS venv (tts-env has a recent transformers) and the GPU:
  wslc run --rm --gpus all -v tts-env:/tts -v comfy-models:/models:ro -v <output>:/out -v <tests>:/opt/tests:ro `
    --entrypoint /tts/venv/bin/python comfyui-r9700:local /opt/tests/tts_score.py [/out/tts/tune/*.wav ...]
Writes /out/tts/tune/scores.jsonl (file, text, transcript, cer) and prints one line per file.
"""
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tts_samples import NARRATION  # noqa: E402


def norm(s):
    s = s.lower().replace("ё", "е")
    s = re.sub(r"[^\w\s]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def cer(ref, hyp):
    a, b = norm(ref), norm(hyp)
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1] / max(1, len(a))


def main():
    import torch
    from transformers import pipeline
    files = sys.argv[1:] or sorted(glob.glob("/out/tts/tune/*.wav"))
    asr = pipeline("automatic-speech-recognition", model="/models/tts/whisper-large-v3-turbo", torch_dtype=torch.float16,
                   device="cuda:0")
    out = "/out/tts/tune/scores.jsonl"
    for path in files:
        key = re.search(r"_(n\d)\.wav$", path)
        if not key:
            continue
        text = NARRATION[key.group(1)]
        import soundfile as sf
        wav, sr = sf.read(path, dtype="float32", always_2d=True)
        hyp = asr({"raw": wav.mean(axis=1), "sampling_rate": sr}, generate_kwargs={"language": "russian", "task": "transcribe"})["text"]
        row = {"file": path, "text": text, "transcript": hyp.strip(), "cer": round(cer(text, hyp), 4)}
        with open(out, "a") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
        print(f"{row['cer']:.3f}  {os.path.basename(path)}  | {row['transcript']}", flush=True)


if __name__ == "__main__":
    main()
