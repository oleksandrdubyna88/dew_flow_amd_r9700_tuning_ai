"""Episode 3: HER own voice (she speaks for the first time; EP3_SCRIPT.md v2 "Her voice"): "a young woman of about twenty, a
soft velvety mid-low voice, warm, natural Russian". Designed once (takes to choose from), later cloned per line with an
emotion per take. Original voices only (no real person's voice).
Run on the GPU with the TTS venv of the model:
  /tts/venv/bin/python /opt/tests/ep3_voice.py vox    (volume tts-env)       -> /out/tts/ep3/her_vox_t<n>.wav
  /tts/venv/bin/python /opt/tests/ep3_voice.py qwen   (volume tts-qwen-env)  -> /out/tts/ep3/her_qwen_t<n>.wav
Prints per take: length, median F0 (ref_pick.median_f0).
"""
import os
import sys
import time

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ref_pick import median_f0  # noqa: E402

HER = ("A young woman of about twenty, a soft velvety mid-low voice, warm and natural, calm, slightly breathy, speaking "
       "Russian with quiet confidence.")
HER_REF_TEXT = "Я давно ни с кем не говорила. Странно слышать свой голос… будто он чужой."
OUT = "/out/tts/ep3"


def report(path, wav, sr, secs):
    print(f"{os.path.basename(path)}: {secs:.1f} s, {len(wav) / sr:.1f} s of audio, median F0 {median_f0(wav, sr):.0f} Hz",
          flush=True)


def vox():
    from voxcpm import VoxCPM
    m = VoxCPM.from_pretrained("/models/tts/VoxCPM2", load_denoiser=False, local_files_only=True, optimize=False)
    sr = getattr(getattr(m, "tts_model", m), "sample_rate", 48000)
    for take in range(1, 5):
        t0 = time.time()
        wav = np.asarray(m.generate(text=f"({HER}){HER_REF_TEXT}", cfg_value=2.0, inference_timesteps=10), dtype=np.float32)
        path = f"{OUT}/her_vox_t{take}.wav"
        sf.write(path, wav, sr)
        report(path, wav, sr, time.time() - t0)


def qwen():
    import torch
    from qwen_tts import Qwen3TTSModel
    m = Qwen3TTSModel.from_pretrained("/models/tts/Qwen3-TTS-1.7B-VoiceDesign", device_map="cuda:0", dtype=torch.bfloat16,
                                      attn_implementation="sdpa")
    for take in range(1, 5):
        t0 = time.time()
        wavs, sr = m.generate_voice_design(text=HER_REF_TEXT, instruct=HER, language="Russian")
        wav = np.asarray(wavs[0], dtype=np.float32)
        path = f"{OUT}/her_qwen_t{take}.wav"
        sf.write(path, wav, sr)
        report(path, wav, sr, time.time() - t0)


# Her lines (EP3_SCRIPT.md v2), each with the emotion for the VoiceDesign take. The owner (2026-11-10) chose her_qwen_t3.
LINES = [
    ("l1_first_words", "Ох… не может быть!", "breathy awe, a caught breath before the first word, disbelief, quiet, not a shout"),
    ("l2_song_spoken", "Столько лет прошло, всё о том же… гудят поезда…", "dreamy, almost to herself, half-sung, soft"),
    ("l3_outburst", "Блин! Да когда же уже всё встанет на места?!", "a sudden sharp angry outburst, then the question loses force"),
    ("l4_tired", "Я так устала быть сама.", "tired, quiet, close to the microphone, low energy"),
    ("l5_magic", "Магия — это прекрасно…", "warm, a small tender smile in the voice"),
    ("l6_wish", "…но я хочу встретить хоть кого-то, с кем можно поговорить.", "sad, quiet, vulnerable, addressed to nobody"),
]


def lines():
    """Two ways, for the owner to compare: (a) a clone of her_qwen_t3 (Qwen3-TTS Base; the same voice in every line,
    emotion only from the text); (b) VoiceDesign = her description + the line's emotion (more emotion, the voice may vary)."""
    import torch
    from qwen_tts import Qwen3TTSModel
    ref = f"{OUT}/her_qwen_t3.wav"
    base = Qwen3TTSModel.from_pretrained("/models/tts/Qwen3-TTS-1.7B-Base", device_map="cuda:0", dtype=torch.bfloat16,
                                         attn_implementation="sdpa")
    prompt = base.create_voice_clone_prompt(ref_audio=ref, ref_text=HER_REF_TEXT)
    texts = [t for _, t, _ in LINES]
    for take in (1, 2):
        t0 = time.time()
        wavs, sr = base.generate_voice_clone(text=texts, language=["Russian"] * len(texts), non_streaming_mode=True,
                                             voice_clone_prompt=[prompt[0]] * len(texts))
        for (name, _, _), w in zip(LINES, wavs):
            path = f"{OUT}/lines/clone_t{take}_{name}.wav"
            os.makedirs(os.path.dirname(path), exist_ok=True)
            sf.write(path, np.asarray(w, dtype=np.float32), sr)
        print(f"clone take {take}: {time.time() - t0:.1f} s", flush=True)
    del base
    torch.cuda.empty_cache()
    design = Qwen3TTSModel.from_pretrained("/models/tts/Qwen3-TTS-1.7B-VoiceDesign", device_map="cuda:0",
                                           dtype=torch.bfloat16, attn_implementation="sdpa")
    for name, text, emotion in LINES:
        for take in (1, 2):
            t0 = time.time()
            wavs, sr = design.generate_voice_design(text=text, instruct=f"{HER} Emotion: {emotion}.", language="Russian")
            wav = np.asarray(wavs[0], dtype=np.float32)
            path = f"{OUT}/lines/design_t{take}_{name}.wav"
            sf.write(path, wav, sr)
            report(path, wav, sr, time.time() - t0)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    {"vox": vox, "qwen": qwen, "lines": lines}[sys.argv[1]]()
