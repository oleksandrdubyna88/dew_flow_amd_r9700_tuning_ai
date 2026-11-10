"""Text-to-speech samples for the series' voice-over: the same narration lines with each model, built-in voices only.

Run in a throwaway container with the TTS venv (volume tts-env) and the GPU:
  wslc run --rm --gpus all -v tts-env:/tts -v comfy-models:/models:ro -v <output>:/out -v <tests>:/opt/tests:ro `
    --entrypoint /tts/venv/bin/python comfyui-r9700:local /opt/tests/tts_samples.py voxcpm2
Writes /out/tts/<model>_<line>.wav and prints the time and the real-time factor of each line.
"""
import os
import sys
import time

import numpy as np
import soundfile as sf

LINES = {
    "ru1": "Она бежала, не оглядываясь. За спиной поднимался огненный гриб, и лес наполнялся пеплом.",
    "ru2": "Ещё шаг. Ещё один. Река была уже близко, а за рекой — горы и шанс выжить.",
    "en1": "She ran without looking back. Behind her, a pillar of fire rose over the forest, and the air filled with ash.",
    "en2": "One more step. Then another. The river was close now, and beyond it, the mountains, and a chance to live.",
}
OUT = "/out/tts"
NARRATION = {  # the owner's story (2026-11-08), one line per ~5 s shot (set NARRATION=1 to render these instead)
    "n1": "В древние времена... никто уже не помнит, когда... случилась беда.",
    "n2": "От рассвета до заката небо покрылось огненными грибами.",
    "n3": "И свет их был ярче тысячи солнц.",
    "n4": "Горели леса, кипели реки, и бежали все, кто ещё мог бежать.",
    "n5": "Лишь немногие добрались до гор.",
    "n6": "А потом... наступила тишина. И с этой тишины началась наша история.",
}
# An ORIGINAL narrator voice (an archetype, never a clone of a real actor): designed once, then cloned for every line.
WIZARD_EN = ("An old wise male storyteller in his seventies, a deep, slightly hoarse and warm voice, slow solemn measured "
             "pace with long pauses, gentle gravitas, like the narrator of an ancient fantasy legend.")
WOMAN_EN = ("A mature woman in her forties, a warm low velvety voice, calm and slightly mysterious, slow measured pace with "
            "soft pauses, like the narrator of an ancient fantasy legend.")
WIZARD_REF_TEXT = "Слушай же, путник. Это было давно, так давно, что даже горы успели забыть."
if os.environ.get("NARRATION") == "1":
    LINES = NARRATION


def voxcpm2():
    from voxcpm import VoxCPM
    t0 = time.time()
    m = VoxCPM.from_pretrained("/models/tts/VoxCPM2", load_denoiser=False, local_files_only=True, optimize=False)
    print(f"voxcpm2: loaded in {time.time() - t0:.1f} s", flush=True)
    sr = getattr(getattr(m, "tts_model", m), "sample_rate", 48000)
    for name, text in LINES.items():
        t0 = time.time()
        wav = np.asarray(m.generate(text=text, cfg_value=2.0, inference_timesteps=10), dtype=np.float32)
        secs = time.time() - t0
        path = os.path.join(OUT, f"voxcpm2_{name}.wav")
        sf.write(path, wav, sr)
        dur = len(wav) / sr
        print(f"voxcpm2 {name}: {secs:.1f} s for {dur:.1f} s of audio (RTF {secs / dur:.2f}) -> {path}", flush=True)


NARRATOR = ("A calm, warm female narrator in her thirties, low and clear voice, slow measured pace, slightly tense, "
            "like the voice-over of a fantasy film.")
QWEN_LANG = {"ru": "Russian", "en": "English"}


def qwen3tts():
    import torch
    from qwen_tts import Qwen3TTSModel
    t0 = time.time()
    m = Qwen3TTSModel.from_pretrained("/models/tts/Qwen3-TTS-1.7B-VoiceDesign", device_map="cuda:0", dtype=torch.bfloat16,
                                      attn_implementation="sdpa")
    print(f"qwen3tts: loaded in {time.time() - t0:.1f} s", flush=True)
    for name, text in LINES.items():
        t0 = time.time()
        wavs, sr = m.generate_voice_design(text=text, instruct=NARRATOR, language=QWEN_LANG.get(name[:2], "Russian"))
        secs = time.time() - t0
        wav = np.asarray(wavs[0], dtype=np.float32)
        path = os.path.join(OUT, f"qwen3tts_{name}.wav")
        sf.write(path, wav, sr)
        dur = len(wav) / sr
        print(f"qwen3tts {name}: {secs:.1f} s for {dur:.1f} s of audio (RTF {secs / dur:.2f}) -> {path}", flush=True)


def f5ru():
    """F5-TTS with a Russian fine-tune (non-commercial weights). F5 has no built-in voice: the reference is the SYNTHETIC
    narrator of qwen3tts_ru2.wav (made by qwen3tts above), so no real person's voice is used."""
    import torch
    import torchaudio

    def _load(path, *args, **kwargs):  # torchaudio.load needs torchcodec, whose pip build is CUDA-only: read with soundfile
        data, sr = sf.read(path, dtype="float32", always_2d=True)
        return torch.from_numpy(data.T.copy()), sr

    torchaudio.load = _load
    from f5_tts.api import F5TTS
    t0 = time.time()
    m = F5TTS(model="F5TTS_v1_Base", ckpt_file="/models/tts/F5-TTS_RUSSIAN/F5TTS_v1_Base_v4_winter/model_212000.safetensors",
              vocab_file="/models/tts/F5-TTS_RUSSIAN/F5TTS_v1_Base/vocab.txt", vocoder_local_path="/models/tts/vocos-mel-24khz",
              device="cuda")
    print(f"f5ru: loaded in {time.time() - t0:.1f} s", flush=True)
    ref = os.path.join(OUT, "qwen3tts_ru2.wav")
    for name, text in LINES.items():
        t0 = time.time()
        wav, sr, _ = m.infer(ref_file=ref, ref_text=LINES["ru2"], gen_text=text, seed=1, show_info=lambda *a: None)
        secs = time.time() - t0
        wav = np.asarray(wav, dtype=np.float32)
        path = os.path.join(OUT, f"f5ru_{name}.wav")
        sf.write(path, wav, sr)
        dur = len(wav) / sr
        print(f"f5ru {name}: {secs:.1f} s for {dur:.1f} s of audio (RTF {secs / dur:.2f}) -> {path}", flush=True)


def wizard_ref_qwen():
    """V1's reference: the narrator designed ONCE by Qwen3-TTS VoiceDesign (three takes; the clone uses take 1 unless told)."""
    import torch
    from qwen_tts import Qwen3TTSModel
    m = Qwen3TTSModel.from_pretrained("/models/tts/Qwen3-TTS-1.7B-VoiceDesign", device_map="cuda:0", dtype=torch.bfloat16,
                                      attn_implementation="sdpa")
    for take in (1, 2, 3):
        t0 = time.time()
        wavs, sr = m.generate_voice_design(text=WIZARD_REF_TEXT, instruct=WIZARD_EN, language="Russian")
        wav = np.asarray(wavs[0], dtype=np.float32)
        path = os.path.join(OUT, f"wizard_ref_qwen_t{take}.wav")
        sf.write(path, wav, sr)
        print(f"wizard_ref_qwen take {take}: {time.time() - t0:.1f} s, {len(wav) / sr:.1f} s of audio -> {path}", flush=True)


def wizard_ref_vox():
    """V2's reference: the narrator designed ONCE by VoxCPM2 ("(description)text"), three takes."""
    from voxcpm import VoxCPM
    m = VoxCPM.from_pretrained("/models/tts/VoxCPM2", load_denoiser=False, local_files_only=True, optimize=False)
    sr = getattr(getattr(m, "tts_model", m), "sample_rate", 48000)
    for take in (1, 2, 3):
        t0 = time.time()
        wav = np.asarray(m.generate(text=f"({WIZARD_EN}){WIZARD_REF_TEXT}", cfg_value=2.0, inference_timesteps=10),
                         dtype=np.float32)
        path = os.path.join(OUT, f"wizard_ref_vox_t{take}.wav")
        sf.write(path, wav, sr)
        print(f"wizard_ref_vox take {take}: {time.time() - t0:.1f} s, {len(wav) / sr:.1f} s of audio -> {path}", flush=True)


def woman_ref_vox():
    """A FEMALE storyteller reference, designed once by VoxCPM2 ("(description)text"), three takes; CPU when VOX_DEVICE=cpu."""
    from voxcpm import VoxCPM
    m = VoxCPM.from_pretrained("/models/tts/VoxCPM2", load_denoiser=False, local_files_only=True, optimize=False,
                               device=os.environ.get("VOX_DEVICE") or None)
    sr = getattr(getattr(m, "tts_model", m), "sample_rate", 48000)
    for take in (1, 2, 3):
        t0 = time.time()
        wav = np.asarray(m.generate(text=f"({WOMAN_EN}){WIZARD_REF_TEXT}", cfg_value=2.0, inference_timesteps=10),
                         dtype=np.float32)
        path = os.path.join(OUT, f"woman_ref_vox_t{take}.wav")
        sf.write(path, wav, sr)
        print(f"woman_ref_vox take {take}: {time.time() - t0:.1f} s, {len(wav) / sr:.1f} s of audio -> {path}", flush=True)


MODELS = {"woman_ref_vox": woman_ref_vox, "voxcpm2": voxcpm2, "qwen3tts": qwen3tts, "f5ru": f5ru, "wizard_ref_qwen": wizard_ref_qwen,
          "wizard_ref_vox": wizard_ref_vox}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name in sys.argv[1:] or list(MODELS):
        MODELS[name]()
