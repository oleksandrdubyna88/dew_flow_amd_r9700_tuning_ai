"""Narrate an episode with VoxCPM2 by cloning a designed reference voice (10 steps), one WAV per line.

The owner (2026-11-09) asked for a female narrator besides the old storyteller: the reference is woman_ref_vox_t1.wav
(ref_pick: CER 0, median F0 160 Hz, the lowest and slowest of three takes).
Run with the tts-env venv, on the GPU (the owner, 2026-11-09: no TTS on the CPU, it froze the PC):
  /tts/venv/bin/python /opt/tests/narrate.py <ep1|ep2> <ref.wav> <out prefix>
writes /out/tts/<out prefix>_n<k>.wav, which voiceover.py reads as <out prefix>.
  /tts/venv/bin/python /opt/tests/narrate.py qwen-woman <ep1|ep2> <out prefix>
the female voice by Qwen3-TTS (the owner asked for it next to the VoxCPM one): VoiceDesign with WOMAN_EN, three takes of
the reference sentence, each scored (Whisper CER, median F0); the take with CER <= 0.02 and the lowest F0 is the
reference; then the Base model clones it for all lines in one batch.
"""
import os
import sys
import time

import numpy as np
import soundfile as sf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ep2_tts import LINES as EP2  # noqa: E402
from tts_samples import NARRATION, WIZARD_REF_TEXT  # noqa: E402
from tts_tune import patch_torchaudio_load  # noqa: E402

EPISODES = {"ep1": list(NARRATION.values()), "ep2": EP2}


def main():
    episode, ref, prefix = sys.argv[1:4]
    patch_torchaudio_load()
    from voxcpm import VoxCPM
    m = VoxCPM.from_pretrained("/models/tts/VoxCPM2", load_denoiser=False, local_files_only=True, optimize=False,
                               device=os.environ.get("VOX_DEVICE") or None)
    sr = getattr(getattr(m, "tts_model", m), "sample_rate", 48000)
    os.makedirs(os.path.dirname(f"/out/tts/{prefix}"), exist_ok=True)
    for k, text in enumerate(EPISODES[episode], 1):
        t0 = time.time()
        wav = np.asarray(m.generate(text=text, prompt_wav_path=ref, prompt_text=WIZARD_REF_TEXT, cfg_value=2.0,
                                    inference_timesteps=10), dtype=np.float32)
        path = f"/out/tts/{prefix}_n{k}.wav"
        sf.write(path, wav, sr)
        print(f"{prefix} line {k}: {time.time() - t0:.1f} s for {len(wav) / sr:.1f} s of audio -> {path}", flush=True)


def qwen_woman(episode, prefix):
    import torch
    from qwen_tts import Qwen3TTSModel
    from transformers import pipeline

    from ref_pick import median_f0
    from tts_samples import WOMAN_EN
    from tts_score import cer
    os.makedirs(os.path.dirname(f"/out/tts/{prefix}"), exist_ok=True)
    design = Qwen3TTSModel.from_pretrained("/models/tts/Qwen3-TTS-1.7B-VoiceDesign", device_map="cuda:0",
                                           dtype=torch.bfloat16, attn_implementation="sdpa")
    takes = []
    for take in (1, 2, 3):
        wavs, sr = design.generate_voice_design(text=WIZARD_REF_TEXT, instruct=WOMAN_EN, language="Russian")
        path = f"/out/tts/woman_ref_qwen_t{take}.wav"
        sf.write(path, np.asarray(wavs[0], dtype=np.float32), sr)
        takes.append(path)
    del design
    torch.cuda.empty_cache()
    asr = pipeline("automatic-speech-recognition", model="/models/tts/whisper-large-v3-turbo", device="cuda:0")
    scored = []
    for path in takes:
        wav, sr = sf.read(path, dtype="float32", always_2d=True)
        wav = wav.mean(axis=1)
        hyp = asr({"raw": wav, "sampling_rate": sr}, generate_kwargs={"language": "russian", "task": "transcribe"})["text"]
        c, f0 = cer(WIZARD_REF_TEXT, hyp.strip()), median_f0(wav, sr)
        scored.append((c > 0.02, f0, path))
        print(f"{os.path.basename(path)}: {len(wav) / sr:.1f} s, median F0 {f0:.0f} Hz, CER {c:.3f}", flush=True)
    del asr
    torch.cuda.empty_cache()
    # a FEMALE voice: only takes with a median F0 >= 140 Hz count (the first run picked a take at 87 Hz, 95 % of its frames
    # under 140 Hz, the male storyteller's range); among those the lowest wins
    ref = sorted(x for x in scored if x[1] >= 140)[0][2]
    print(f"reference: {os.path.basename(ref)}", flush=True)
    qwen_clone(episode, ref, prefix)


def qwen_clone(episode, ref, prefix):
    import torch
    from qwen_tts import Qwen3TTSModel
    os.makedirs(os.path.dirname(f"/out/tts/{prefix}"), exist_ok=True)
    base = Qwen3TTSModel.from_pretrained("/models/tts/Qwen3-TTS-1.7B-Base", device_map="cuda:0", dtype=torch.bfloat16,
                                         attn_implementation="sdpa")
    prompt = base.create_voice_clone_prompt(ref_audio=ref, ref_text=WIZARD_REF_TEXT)
    lines = EPISODES[episode]
    t0 = time.time()
    wavs, sr = base.generate_voice_clone(text=lines, language=["Russian"] * len(lines), non_streaming_mode=True,
                                         voice_clone_prompt=[prompt[0]] * len(lines))
    for k, w in enumerate(wavs, 1):
        sf.write(f"/out/tts/{prefix}_n{k}.wav", np.asarray(w, dtype=np.float32), sr)
    print(f"{prefix}: {time.time() - t0:.1f} s for {sum(len(w) for w in wavs) / sr:.1f} s of audio", flush=True)


if __name__ == "__main__":
    if sys.argv[1] == "qwen-woman":
        qwen_woman(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == "qwen-clone":  # qwen-clone <ep1|ep2> <ref.wav> <out prefix>
        qwen_clone(sys.argv[2], sys.argv[3], sys.argv[4])
    else:
        main()
