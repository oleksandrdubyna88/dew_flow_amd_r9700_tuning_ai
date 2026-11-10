"""Tune the narration for long episodes: speed (RTF) per model and setting, the narrator CLONED from one designed reference.

Run in a throwaway container with the model's venv and the GPU (the GPU otherwise idle, or the times mean nothing):
  wslc run --rm --gpus all -v <venv volume>:/tts -v comfy-models:/models:ro -v <output>:/out -v <tests>:/opt/tests:ro `
    --entrypoint /tts/venv/bin/python comfyui-r9700:local /opt/tests/tts_tune.py <vox|qwen|f5> [--ref <wav>]
Writes /out/tts/tune/<model>_<setting>_n<k>.wav and appends one JSON line per line to /out/tts/tune/times.jsonl.
The quality of each file is measured afterwards by tts_score.py (Whisper transcription, character error rate).
"""
import argparse
import json
import os
import sys
import time

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tts_samples import NARRATION, WIZARD_REF_TEXT  # noqa: E402

OUT = "/out/tts/tune"


def patch_torchaudio_load():
    """torchaudio.load goes through torchcodec, whose pip build is CUDA-only (needs NVIDIA's libnvrtc): read with soundfile."""
    import torch
    import torchaudio

    def _load(path, *args, **kwargs):
        data, sr = sf.read(path, dtype="float32", always_2d=True)
        return torch.from_numpy(data.T.copy()), sr

    torchaudio.load = _load


def record(model, setting, k, secs, wav, sr, path):
    dur = len(wav) / sr
    row = {"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "model": model, "setting": setting, "line": k,
           "seconds": round(secs, 3), "audio_s": round(dur, 3), "rtf": round(secs / dur, 3) if dur else None, "file": path}
    with open(os.path.join(OUT, "times.jsonl"), "a") as f:
        f.write(json.dumps(row) + "\n")
    print(f"{model} {setting} {k}: {secs:.2f} s for {dur:.2f} s (RTF {secs / dur:.2f})", flush=True)


def vox(ref):
    patch_torchaudio_load()
    from voxcpm import VoxCPM
    m = VoxCPM.from_pretrained("/models/tts/VoxCPM2", load_denoiser=False, local_files_only=True, optimize=False)
    sr = getattr(getattr(m, "tts_model", m), "sample_rate", 48000)
    m.generate(text="Проверка.", prompt_wav_path=ref, prompt_text=WIZARD_REF_TEXT, inference_timesteps=10)  # warm-up
    for steps in (10, 6, 4):
        for k, text in NARRATION.items():
            t0 = time.time()
            wav = np.asarray(m.generate(text=text, prompt_wav_path=ref, prompt_text=WIZARD_REF_TEXT, cfg_value=2.0,
                                        inference_timesteps=steps), dtype=np.float32)
            secs = time.time() - t0
            path = os.path.join(OUT, f"vox_t{steps}_{k}.wav")
            sf.write(path, wav, sr)
            record("vox", f"t{steps}", k, secs, wav, sr, path)


def qwen(ref):
    import torch
    from qwen_tts import Qwen3TTSModel
    m = Qwen3TTSModel.from_pretrained("/models/tts/Qwen3-TTS-1.7B-Base", device_map="cuda:0", dtype=torch.bfloat16,
                                      attn_implementation="sdpa")
    prompt = m.create_voice_clone_prompt(ref_audio=ref, ref_text=WIZARD_REF_TEXT) if hasattr(m, "create_voice_clone_prompt") else None
    kw = {"voice_clone_prompt": prompt} if prompt is not None else {"ref_audio": ref, "ref_text": WIZARD_REF_TEXT}
    m.generate_voice_clone(text="Проверка.", language="Russian", non_streaming_mode=True, **kw)  # warm-up
    for k, text in NARRATION.items():  # one line per call
        t0 = time.time()
        wavs, sr = m.generate_voice_clone(text=text, language="Russian", non_streaming_mode=True, **kw)
        wav = np.asarray(wavs[0], dtype=np.float32)
        path = os.path.join(OUT, f"qwen_single_{k}.wav")
        sf.write(path, wav, sr)
        record("qwen", "single", k, time.time() - t0, wav, sr, path)
    keys, texts = list(NARRATION), list(NARRATION.values())  # all six lines in one batched call
    if prompt is not None:
        kwb = {"voice_clone_prompt": [prompt[0] if isinstance(prompt, list) else prompt] * len(texts)}
    else:
        kwb = {"ref_audio": [ref] * len(texts), "ref_text": [WIZARD_REF_TEXT] * len(texts)}
    t0 = time.time()
    wavs, sr = m.generate_voice_clone(text=texts, language=["Russian"] * len(texts), non_streaming_mode=True, **kwb)
    secs = time.time() - t0
    total = sum(len(w) for w in wavs) / sr
    for k, w in zip(keys, wavs):
        wav = np.asarray(w, dtype=np.float32)
        path = os.path.join(OUT, f"qwen_batch6_{k}.wav")
        sf.write(path, wav, sr)
        record("qwen", "batch6", k, secs * (len(wav) / sr) / total, wav, sr, path)  # the batch time shared by length
    print(f"qwen batch6: {secs:.2f} s for {total:.2f} s (RTF {secs / total:.2f})", flush=True)


def f5(ref):
    import torch
    import torchaudio

    def _load(path, *args, **kwargs):  # the pip torchcodec is CUDA-only: read with soundfile
        data, sr = sf.read(path, dtype="float32", always_2d=True)
        return torch.from_numpy(data.T.copy()), sr

    torchaudio.load = _load
    from f5_tts.api import F5TTS
    m = F5TTS(model="F5TTS_v1_Base", ckpt_file="/models/tts/F5-TTS_RUSSIAN/F5TTS_v1_Base_v4_winter/model_212000.safetensors",
              vocab_file="/models/tts/F5-TTS_RUSSIAN/F5TTS_v1_Base/vocab.txt", vocoder_local_path="/models/tts/vocos-mel-24khz",
              device="cuda")
    m.infer(ref_file=ref, ref_text=WIZARD_REF_TEXT, gen_text="Проверка.", seed=1, show_info=lambda *a: None)  # warm-up
    for nfe in (32, 16):
        for k, text in NARRATION.items():
            t0 = time.time()
            wav, sr, _ = m.infer(ref_file=ref, ref_text=WIZARD_REF_TEXT, gen_text=text, nfe_step=nfe, seed=1,
                                 show_info=lambda *a: None)
            secs = time.time() - t0
            wav = np.asarray(wav, dtype=np.float32)
            path = os.path.join(OUT, f"f5_nfe{nfe}_{k}.wav")
            sf.write(path, wav, sr)
            record("f5", f"nfe{nfe}", k, secs, wav, sr, path)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("model", choices=["vox", "qwen", "f5"])
    ap.add_argument("--ref", required=True)
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    {"vox": vox, "qwen": qwen, "f5": f5}[a.model](a.ref)
