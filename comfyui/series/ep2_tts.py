"""Episode 2's narration (eight lines, the storyteller voice of episode 1, cloned from the same references).

Run in a throwaway container with the model's venv and the GPU:
  ... --entrypoint /tts/venv/bin/python comfyui-r9700:local /opt/tests/ep2_tts.py <qwen|vox>
Writes /out/tts/ep2/<qwen|vox>_n<k>.wav (Qwen3-TTS Base clone, all lines in one batch; VoxCPM2 clone, 10 steps).
"""
import os
import sys
import time

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tts_samples import WIZARD_REF_TEXT  # noqa: E402
from tts_tune import patch_torchaudio_load  # noqa: E402

LINES = [
    "Она нашла приют за водопадом. Огонь, тишина... и впервые — сон.",
    "Но мир, который она знала, уже умирал.",
    "С севера пришли чёрные тучи. Солнце исчезло на долгие месяцы.",
    "Леса засохли. Пепел падал, как снег, и не таял.",
    "А в мёртвой чаще проснулись те, кого изменил огонь.",
    "Оставаться — значило погибнуть. И она ушла.",
    "Среди ржавых обломков старого мира её ждала последняя искра надежды.",
    "Мотор взревел... и дорога повела её туда, где ещё садилось солнце.",
]
OUT = "/out/tts/ep2"


def qwen():
    import torch
    from qwen_tts import Qwen3TTSModel
    m = Qwen3TTSModel.from_pretrained("/models/tts/Qwen3-TTS-1.7B-Base", device_map="cuda:0", dtype=torch.bfloat16,
                                      attn_implementation="sdpa")
    prompt = m.create_voice_clone_prompt(ref_audio="/out/tts/wizard_ref_qwen_t3.wav", ref_text=WIZARD_REF_TEXT)
    t0 = time.time()
    wavs, sr = m.generate_voice_clone(text=LINES, language=["Russian"] * len(LINES), non_streaming_mode=True,
                                      voice_clone_prompt=[prompt[0]] * len(LINES))
    for k, w in enumerate(wavs, 1):
        sf.write(os.path.join(OUT, f"qwen_n{k}.wav"), np.asarray(w, dtype=np.float32), sr)
    print(f"qwen: {time.time() - t0:.1f} s for {sum(len(w) for w in wavs) / sr:.1f} s of audio", flush=True)


def vox():
    patch_torchaudio_load()
    from voxcpm import VoxCPM
    m = VoxCPM.from_pretrained("/models/tts/VoxCPM2", load_denoiser=False, local_files_only=True, optimize=False)
    sr = getattr(getattr(m, "tts_model", m), "sample_rate", 48000)
    t0, total = time.time(), 0.0
    for k, text in enumerate(LINES, 1):
        wav = np.asarray(m.generate(text=text, prompt_wav_path="/out/tts/wizard_ref_vox_t2.wav", prompt_text=WIZARD_REF_TEXT,
                                    cfg_value=2.0, inference_timesteps=10), dtype=np.float32)
        sf.write(os.path.join(OUT, f"vox_n{k}.wav"), wav, sr)
        total += len(wav) / sr
    print(f"vox: {time.time() - t0:.1f} s for {total:.1f} s of audio", flush=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    {"qwen": qwen, "vox": vox}[sys.argv[1]]()
