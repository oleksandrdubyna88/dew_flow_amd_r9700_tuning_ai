# ComfyUI on the R9700 — the hand screening of 2026-11-07/08 and what it found

A record of measurements made by hand on the R9700 (gfx1201, 32 GB) before the toolkit's bench (`comfy bench`, epic E2 of
[`../todo/PLAN_comfyui_r9700.md`](../todo/PLAN_comfyui_r9700.md)) exists. **Screening, not a verdict**: most rows are one
round, without the arms' own spread; a speed claim needs the bench's series (E3). Every prediction below was written before
its run. The runs used the operator's hand-made ComfyUI setup (outside every repository; image built from the same recipe as
`comfyui/`): ComfyUI v0.44.0, torch 2.13.0+rocm10.1.0, Python 3.12, inside `wslc` with `--gpus all` (`/dev/dxg`).

## 1. Arm screening on `zimage` (2026-11-07)

Workload: Z-Image Turbo bf16, 1024x1024, 8 steps, `res_multistep`, cfg 1, shift 3; one container per arm, one cold run and
three measured runs (seeds 4243–4245). Base observed before: ~5.4 s warm (sampler ~4.6 s, VAE ~0.5 s).

| Arm | Change | Prediction | Observed: sampler s (total s) | Against the prediction |
|---|---|---|---|---|
| base | none | ~5.4 s total | 4.77 (4.75–4.94) (5.89) | — |
| fp16acc | `--fast fp16_accumulation` | inert on bf16, ±3 % | 5.00 (6.05) | as predicted: inert |
| fp8w | UNETLoader `weight_dtype fp8_e4m3fn` | slower or equal | 5.29 (6.25) | as predicted: slower without fp8 compute |
| fp8w_mm | fp8w + `--fast fp8_matrix_mult` | 10–30 % faster sampler | **4.04 (4.78), −15 %** | as predicted; the same seed gives another composition; quality equal by eye on one seed |
| miopen | `COMFYUI_ENABLE_MIOPEN=1`, `MIOPEN_FIND_MODE=FAST` | sampler equal, VAE changes | 4.63 (5.35) | VAE equal warm (0.51 s); cold VAE 7.8 s (MIOpen find) |
| tunableop | `PYTORCH_TUNABLEOP_ENABLED=1` | cold much longer, warm 5–15 % faster | not measured | the cold run's step 1 took 690 s, then 1.78 it/s; the VAE's tuning ran > 37 min and was stopped; 36 shapes in the results file |
| compile | `TorchCompileModel` (inductor) | cold minutes longer, 10–25 % faster | 4.60 (5.75), ~−4 % | runs 2–3 recompiled (17.5–18.4 s); run 4 measured |

Not settled: one round each; fp8w_mm's quality on more seeds; tunableop's warm speed; compile's recompiles per seed.

## 2. Second screening: `wan5b` and compile (2026-11-07)

Workload `wan5b`: Wan 2.2 TI2V 5B, text-to-video 1280x704, 121 frames, 20 steps `uni_pc`, cfg 5, shift 8, tiled VAE decode
(tile_size 512, overlap 64, temporal_size 32, temporal_overlap 8); one cold and one measured run per arm.

| Arm | Prediction | sampler s | VAE s | total s |
|---|---|---|---|---|
| wan5b base | ~11.5 s/step, ~340 s per clip | 225.1 | 101.1 | 330.9 |
| wan5b fp8w_mm | sampler 10–20 % faster | 209.9 (−7 %) | 99.9 | 314.2 (−5 %), smaller than predicted |

The tiled decode is ~30 % of a clip, so it was the next target.

## 3. The tiled decode of Wan 2.2 (2026-11-08)

Named fields: `tile_size/overlap/temporal_size/temporal_overlap`; seconds of decode + save, the sampler cached.

- Prediction (third screening): larger spatial tiles faster (~20–30 %); 1280 (no spatial tiling) may stall.
- Observed: 512/64/32/8 ≈ 101 · 512/64/64/8 95.2 · 768/64/32/8 319.6 · 768/64/64/8 333.9 · 1024/64/32/8 215.8 ·
  1024/64/64/8 174.6 · **512/32/32/4 77.8** · 1280/64/32/8 626.3. Larger tiles were 2–6x SLOWER; a smaller overlap was 23 %
  faster. Cause not known (a spill out of fast memory is a guess, not checked).
- Prediction (fourth screening): 384 and 256 no slower than 512; temporal 16 slower than 32; overlap 16 slightly faster.
- Observed: 512/32/32/4 77.8 · 384/32/32/4 81.2 · 256/32/32/4 146.0 · 512/32/16/4 82.4 · **512/32/64/4 70.3** ·
  384/32/64/4 75.3 · 512/16/32/4 72.5. 256 much slower (against the prediction); temporal 64 faster than 32; overlap 16
  faster than 32 (as predicted).
- Drift against 512/64/32/8, same seed (PSNR at frames 0/31/60/95/120): 512/32/64/4 43.5/35.2/24.0/40.2/38.8 dB;
  512/16/32/4 42.6/28.6/30.1/39.0/36.3; 384/32/64/4 42.7/35.3/24.0/40.1/38.0. Frame 60 of 512/32/64/4 beside the reference:
  the same picture, no seam, slightly warmer and more contrasted (a colour shift from the other temporal chunking).
- The untiled decode of a 121-frame clip stalled for more than 10 minutes: the tiled decode is required.

Candidate: 512/32/64/4, −30 % decode (70 s instead of 101 s), ~−9 % per clip; the colour shift waits for the operator's look
(asked 2026-11-08: "try it, show me, I decide").

## 4. The "mesh" on the video (the operator's remark, diagnosed 2026-11-08)

A diagonal hatching over the clips, worst in bright areas. It is in a lossless PNG of the decoded frame (not the codec);
unchanged with `--fp32-vae`, other tiles and `--bf16-unet`; the keyframe is clean. A checker metric (mean |2x2 checker
kernel| on luma, median of 13 frames, checked by hand on zooms): shot-6 keyframe 2.53; 20 steps 3.45/3.49/3.59; 50 steps
1.61; FastWan 3-step 2.32; Wan22-Turbo 4-step 2.62. **Cause: incomplete denoising at 20 `uni_pc` steps** (the official setting
is 50 steps, shift 5, cfg 5) — a consultant's hypothesis, verified by the 50-step render.

## 5. Step-distillation LoRAs on Wan 2.2 TI2V 5B (2026-11-08)

Prediction: sampler 20–25 s, clip ~130 s (~2.5x faster). Observed (image-to-video, cfg 1, `lcm`, shift 8): FastWan 3-step
shot 1 142.8 s, shot 6 132.0 s; Wan22-Turbo 4-step shot 6 128.6 s — as predicted. FastWan frames sharper than the 20-step
ones, no mesh. **Production setting of the hand-made series: FastWan LoRA
(`Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors`), 3 steps, `lcm`, cfg 1, shift 8, ~122–143 s per 5 s clip**
(against ~340 s at 20 steps; ~700 s at the 50-step quality reference). At cfg 1 the negative prompt has no effect.

Motion (a frame-difference metric over ~0.8 s, includes camera motion, not hand-validated): shot 3 — 20 steps 22.4; FastWan
3-step 33.5; FastWan 4-step 39.0 (147.5 s vs ~122 s).

## 6. Two model sets compared on the same 30-second story (2026-11-08)

Same six shots, prompts and seeds. Set A ("v5"): Z-Image Turbo keyframes + Wan 2.2 TI2V 5B + FastWan 3-step. Set B ("set 2"):
Qwen-Image 2512 fp8 + Lightning 4-step keyframes + Wan 2.2 A14B I2V fp8 (two experts) + lightx2v 4-step (2+2 steps).

| | Set A | Set B |
|---|---|---|
| keyframe | ~5 s | 7–11 s warm (67.7 s with the load) |
| clip (~5 s) | 122–155 s, 121 frames at 24 fps | 995.6 / 1776.6 / 1326.9 / 1000.9 / 1778.1 / 1392.9 s (mean ~1378 s), 81 frames at 16 fps — ~10x slower |
| six clips | ~13–15 min | ~2.3 h and two container restarts |
| failures | none | "out of memory" in the low-noise sampler twice, each after 3 clips (once on a server up 3 h); a restart cures it |
| mesh metric, median per clip | 1.66–2.46 | 1.29–2.72 (both clean) |
| motion metric | 16–39 | 14–37 (calmer in shots 1–3) |
| by eye | clothing varies a little between shots | the same face and clothing in all six; natural running and climbing |

Set B's sampler runs at ~2.65 s/step after a ~75 s model initialisation; the time goes to moving the two 14 GB experts and
the 6.3 GB text encoder, which do not fit 32 GB together. Set B's shot 2 keyframe had a lifted-leg pose that turned into a
fall in the clip; a re-roll with seed 2202 (four seeds tried, all waist-up) gave a clean running shot (999.1 s).
**The operator's choice (2026-11-08): the set-B character is the one they like best**; set A stays the fast set for trying
ideas.

## 7. An "Arcane" style without a style LoRA (2026-11-08)

Try 1 (the series' name in the prompt) looked flat, like a Disney film; try 2 (style words) was a darker cartoon and brought
long elf ears back ("not elf ears" ADDS them at cfg 1). Try 3 restyled set A's photoreal keyframes by img2img (denoise grid
0.45/0.55/0.65 on one shot, 0.60 chosen) and animated them with FastWan (122–155 s per clip). The operator's verdict: it
looks like Elsa from Frozen, not like Arcane's painted look. Next: a real Arcane style LoRA on set B's keyframes (§ 9).

## 8. Facts about the stack found along the way

- `PYTORCH_HIP_ALLOC_CONF=expandable_segments:True` breaks allocation through `/dev/dxg` (`hipErrorInvalidValue`); the image
  does not set it.
- ComfyUI-Manager reports "PyTorch not installed" when it installs with `uv` or under `PIP_USER`; the image uses a venv with
  `--system-site-packages` and the Manager's `use_uv = False`.
- A long-running server can fail later work with "out of memory" or a HIP "invalid argument"; a container restart cures it
  (a fresh container per bench arm-round follows from this).
- `wslc` supports `--tmpfs` and a read-only named volume; a plain `--tmpfs` is mounted `noexec`, so a container whose
  entrypoint runs a venv from that folder needs `--tmpfs /data:exec`.
- TunableOp with `PYTORCH_TUNABLEOP_FILENAME=<dir>/tunableop_results.csv` writes `<dir>/tunableop_results0.csv` (the device
  number before the extension) at a normal process exit; `PYTORCH_TUNABLEOP_MAX_TUNING_ITERATIONS` and
  `PYTORCH_TUNABLEOP_MAX_TUNING_DURATION_MS` are accepted (torch 2.13.0+rocm10.1.0).
- `SaveVideo` (v0.44.0) accepts `format: "auto"` alone and with `codec: "auto"` through `/prompt`.
- The image's Python libraries: aiohttp 3.14.5, numpy 2.5.3, Pillow 12.3.0; ffmpeg 6.1.1.
- The host PC bugchecked under GPU load: 0x7E (c0000005) on 2026-11-02 (the operator's vLLM serving) and 2026-11-07
  (seconds after a ComfyUI image), both at the same offset `…4ec0`, so one function of one driver; also 0x7A (a disk in-page
  error, 2026-10-25) and 0x19C (a power watchdog, 2026-11-04); no GPU-timeout (4101) events. Both AMD GPUs of the machine use
  driver 32.0.31036.15 (2026-08-12). The dumps need admin rights to read; the driver is not identified yet.

## 9. Research for the next steps (2026-11-08; nothing downloaded yet)

Arcane style LoRAs (by base model): Z-Image Turbo — `DeverStyle/Z-Image-loras`, file `z_image_arcane_v1.safetensors`
(340 MB, sha256 `e596725e60f5ffe7b8cf074aaf0a70c6ef558ac480e43789b24d8cf1c743f40b`, no trigger word; the repository's README
says research and non-commercial use only); its sample sheet shows a painted look close to the series. Others: a Civitai
Z-Image LoRA (deleted on Civitai), a Qwen-Image LoRA trained before 2512 (unverified on 2512), Wan 2.2 A14B T2V LoRAs only
(no I2V, none for the 5B), Flux.1-dev and SDXL fallbacks. All licences found are non-commercial or research-only.

Text-to-speech for voice-over (Russian and English, cloning, ROCm): VoxCPM2 (Apache-2.0, ~5 GB, 48 kHz; ROCm needs
`optimize=False` and no torchcodec), Qwen3-TTS 1.7B Base (Apache-2.0, ~4.6 GB; `sdpa`, not flash-attn; pins an older
`transformers`, so a separate venv), F5-TTS with a Russian fine-tune (non-commercial; official RDNA4 notes). Chatterbox is
retired and pins torch 2.6.0, which has no RDNA4 support. None was tested on gfx1201; samples come next, built-in voices only.

## What this record does not settle

One round per arm (no spread); quality judged by eye on few seeds; the mesh and motion metrics are home-made and only
partly checked by hand; set B's out-of-memory cause (a leak or fragmentation) is not known; nothing here is a bench verdict.

## 10. The Arcane style LoRA on the set-B keyframes (2026-11-08)

Prediction (written before the run): the LoRA restyles set B's photoreal keyframes into a painted look; a higher denoise
paints more but loses the character's details; strength 1.0 paints more than 0.7.

Run: Z-Image Turbo bf16 + `z_image_arcane_v1.safetensors` (fetched to the store and the volume, its sha256 equal to the
published one), img2img from set B's keyframes of shots 1 and 3 (8 steps, `res_multistep`, cfg 1, the set-B prompt without
its photo-style words plus "Arcane style."), a grid of LoRA strength 0.7/1.0 x denoise 0.55/0.70: 5.0–7.2 s per image warm
(22.4 s for the first, with the loads).

Observed: all eight read as painted animation (painted backgrounds, drawn faces, matte painted cloth), far from the
"Frozen" look of § 7; the character (silver hair, golden strand, green tunic and belt) survives. Denoise 0.55 keeps the face
and pose closest to set B and the small ears; at 0.70 the ears grow into long elf ears again (against the operator's
remark), the painting is stronger. Strength 1.0 paints a little more than 0.7. Proposed: strength 1.0, denoise 0.55; the
operator's choice is asked. The LoRA's licence is research and non-commercial use only.

## 11. Two original characters on set B's image model (2026-11-08)

The operator asked for elves looking like two actresses of a TV series; a likeness of real people was declined, and two
ORIGINAL characters inspired by the series' costume world were written instead (a princess and a rover, each with her own
face). Prediction: Qwen-Image 2512 holds each face across seeds as it held set B's character; the word "elf" lengthens the
ears beyond the operator's rule (§ 7).

Run: Qwen-Image 2512 fp8 + Lightning 4-step, 1280x704, cfg 1, two views (portrait, running) x four seeds per character:
6.0–7.1 s per image warm (52.1 s for the first, with the loads).

Observed: each character keeps one face, hair and costume across all eight images; the costumes follow their descriptions
(embroidered tunic and cloak; vest, scarf, gloves and knife). The ears came out as clear elf ears, longer than "only the tip
pointed" — as predicted; the fix (drop the word "elf", describe the ears only) is offered to the operator.

## 12. Text-to-speech samples on the R9700 (2026-11-08)

Prediction (written before the runs): both models run on gfx1201 in plain PyTorch (VoxCPM2 with `optimize=False`, Qwen3-TTS
with `sdpa`), slower than real time; each needs its own venv (Qwen3-TTS pins `transformers` 4.57.3).

Setup: each model in its own venv on its own `wslc` volume (`--system-site-packages` over the image, so torch stays
2.13.0+rocm10.1.0), weights to the store first and then to the models volume, one throwaway container per run with
`--gpus all` (ComfyUI's models unloaded first through its `/free`). The same four narration lines (two Russian, two English).

| Model | Voice | Load | Per line (RTF = seconds per second of audio) | Audio |
|---|---|---|---|---|
| VoxCPM2 (`openbmb/VoxCPM2`, voxcpm 2.0.3, bf16, 4.7 GB) | the model's own (no reference) | 61.8 s | ru1 25.1 s / 5.4 s (RTF 4.61, warm-up), ru2 8.7 s / 4.3 s (2.02), en1 16.5 s / 7.7 s (2.15), en2 19.0 s / 8.6 s (2.20) | 48 kHz |
| Qwen3-TTS 1.7B VoiceDesign (`Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign`, qwen-tts 0.1.1, bf16, 4.3 GB) | one narrator described in text | 9.3 s | ru1 44.8 s / 7.0 s (6.37, warm-up), ru2 23.4 s / 7.0 s (3.36), en1 36.0 s / 10.6 s (3.41), en2 36.0 s / 10.8 s (3.33) | model rate |

Observed: both run on the card as predicted, 2–3.5x slower than real time warm. Qwen3-TTS speaks at a slower narration pace
(the Russian lines 7.0 s against VoxCPM2's 5.4 and 4.3 s; VoxCPM2's ru2 may be rushed or cut — to be heard). The quality is
the operator's call by ear; no real person's voice was used (no cloning).

F5-TTS with a Russian fine-tune (`Misha24-10/F5-TTS_RUSSIAN`, checkpoint `F5TTS_v1_Base_v4_winter/model_212000.safetensors`,
1.3 GB, cc-by-nc-4.0 — non-commercial; f5-tts 1.1.22; vocoder `charactr/vocos-mel-24khz`): F5 has no built-in voice, so the
reference clip was the SYNTHETIC narrator of Qwen3-TTS's ru2 line with its text (no real person's voice). First run failed:
`torchaudio.load` goes through `torchcodec`, whose pip build needs NVIDIA's `libnvrtc`; reading the clip with `soundfile`
instead fixed it. Load 4.3 s; ru1 21.2 s / 8.4 s (RTF 2.51, warm-up), ru2 1.7 s / 6.8 s (0.26), en1 1.7 s / 5.7 s (0.30),
en2 1.7 s / 5.5 s (0.30) — faster than real time once warm, the fastest of the three. The English lines are short (5.5–5.7 s
against Qwen3-TTS's 10.6–10.8 s): F5 takes the pace from the Russian reference, so English may sound rushed. By ear: the
operator's call.

## 13. The Arcane films, the eyes, and a narrator voice (2026-11-08)

Arcane films: set B's six keyframes restyled (Z-Image Turbo + the Arcane LoRA 1.0, denoise 0.55 and 0.70) and animated
with Wan 2.2 TI2V 5B + FastWan 3-step (122–143 s per clip). The operator: the 0.55 film is "closer to Arcane", but the
eyes jump and look in different directions. Observed by eye: the painted look weakens in motion (the 5B video model has
no Arcane LoRA and repaints the frames in its own style), most in the close-ups.

The eyes (shot 2, the close-up). Prediction: gaze words in the motion prompt and a fourth step steady the eyes; the 14B
model, which held faces best in § 6, steadies them most. Observed: the gaze words (503 s, the GPU shared with a TTS run)
and four steps (219.5 s) look the same as the original at frame-by-frame zoom — the jumping follows the head motion of the
same seed; the 14B variant failed with "out of memory" on a server that had run for hours beside TTS containers (as in
§ 6); it is re-run on a fresh server.

A narrator voice for the operator's story (the operator asked for a voice like a famous film wizard; an actor's voice is
not cloned — an ORIGINAL archetype was designed: an old wise male storyteller, deep, slightly hoarse, warm, slow). Method,
so one voice holds through a long episode: design ONE reference sentence per model (three takes), then clone it for every
line. The takes measured (Whisper large-v3-turbo transcript against the text; median pitch by autocorrelation):
Qwen3-TTS VoiceDesign 8.2/8.9/8.1 s, 130/92/78 Hz, CER 0/0/0; VoxCPM2 "(description)text" 5.6/7.0/5.4 s, 113/112/119 Hz,
CER 0/0/0. Chosen: the Qwen take at 78 Hz (deepest) and the VoxCPM take of 7.0 s (slowest). The pip `torchcodec` is a
CUDA build (needs NVIDIA's libnvrtc): it was removed from the TTS venvs, and audio is read with `soundfile`.

## 14. The eyes fixed by the 14B video model (2026-11-08)

On a freshly started server, the 14B variant of the eye test (Wan 2.2 A14B + lightx2v 4-step, the gaze words) rendered
shot 2 in 997.3 s and, frame by frame on the face, holds one gaze direction and keeps the painted colours of the Arcane
keyframe; the 5B FastWan variants (§ 13) turn the face, change colour and move the eyes between frames. Decision: the
Arcane film is rendered with 14B, one shot per call and the server restarted before every second clip (the 14B pair runs
out of memory after about three clips on one server, § 6).

## 15. Narration tuned for long episodes (2026-11-08)

Goal (the operator): 40-minute episodes, good and fast. Prediction (written before the run): fewer steps and batching
speed each model up; a faster setting costs intelligibility.

Run on an idle card, the narrator cloned from one designed reference (§ 13) for the six lines of the operator's story
(31 s of speech); intelligibility measured by Whisper large-v3-turbo against the script (character error rate, CER).

| Model, setting | Work s | Audio s | RTF | CER mean / max | 40 min of speech would take |
|---|---|---|---|---|---|
| F5-TTS RU, nfe 16 | 5.0 | 31.9 | 0.16 | 0.000 / 0.000 | ~6.5 min |
| F5-TTS RU, nfe 32 | 10.5 | 31.9 | 0.33 | 0.000 / 0.000 | ~13 min |
| VoxCPM2, 4 steps | 46.4 | 29.0 | 1.60 | 0.005 / 0.032 | ~64 min |
| VoxCPM2, 6 steps | 51.9 | 31.5 | 1.65 | 0.005 / 0.032 | ~66 min |
| VoxCPM2, 10 steps | 67.3 | 30.2 | 2.22 | 0.000 / 0.000 | ~89 min |
| Qwen3-TTS Base clone, six lines in one batch | 67.1 | 31.1 | 2.16 | 0.000 / 0.000 | ~86 min |
| Qwen3-TTS Base clone, one line per call | 130.0 | 29.0 | 4.48 | 0.000 / 0.000 | ~3 h |

Observed: batching halves Qwen3-TTS's time at no cost; VoxCPM2's diffusion steps are a small share of its time (10→4 steps
saves 28 %) and 4–6 steps start to drop a letter; F5-TTS is ~14x faster than the others and fully intelligible, but its
Russian weights are non-commercial. CER measures intelligibility only; the voice's character is judged by ear.

Mixing (voiceover.py): line k starts at its shot or 0.3 s after line k-1, a line is sped up at most 1.08x (a solemn voice
sped up 30 % loses its character), and when the narration outlasts the film the last frame is held. The slow narrator's
six lines start within ~1 s of their shots and end 1.4–2 s after the film.

## 16. The Arcane film on the 14B video model, and a restart rule for 14B (2026-11-08)

The full Arcane film (set B's keyframes, the Arcane LoRA 1.0 at denoise 0.55; Wan 2.2 A14B + lightx2v 4-step with the gaze
words; the server restarted before every second clip): clips of 1005.2 / 1796.7 / 1000.3 / 1781.0 / 1004.9 / 1777.9 s.
By eye on frames of every shot: the painted look and the character hold through the motion and the faces keep one gaze
(the operator's two remarks on the 5B film); in shot 5 the ears grow (the shot's motion text says "elf woman").

Observed pattern: every clip right after a restart took ~1000 s, every second clip on the same server ~1780–1800 s — the
14B pair is ~1.8x slower on its second clip (the server's memory fills; the "dynamic VRAM loading" moves the 14 GB experts
more). A restart costs ~30 s, so for the 14B workflow on this card **a restart before every clip** is faster (~1030 s per
clip against ~1400 s on average) and also avoids the "out of memory" of § 6. Lyriel's film is rendered with that rule (its
times verify the prediction: every clip ~1000 s).

## 17. Lyriel's film with the restart rule (2026-11-08)

Lyriel (the original princess of § 11 with small ears and a stated adult age) in the same six-shot story: keyframes by
Qwen-Image 2512 (7 s each warm, 47.5 s the first), clips by Wan 2.2 A14B + lightx2v 4-step with the gaze words, the server
restarted before EVERY clip. Prediction (§ 16): every clip ~1000 s. Observed: 1001.4 / 1005.4 / 1004.6 / 1008.5 / 1007.6 /
1005.2 s — as predicted (the old rule gave ~1790 s for every second clip). By eye on frames of every shot: one adult face,
braids and costume throughout; the ears small and mostly hidden by the hair; natural running and climbing. Both narrations
mixed in (the last frame held ~2 s while the narrator finishes).

## 18. The voiced films had no sound — the mixer fixed and made to check its output (2026-11-08)

The operator found every voiced film silent and not seekable. Observed (ffprobe): the audio stream was 0.008 s long with a
start time of ~1.9e14 s and a mean of −91 dB, while the source WAVs were fine (6.7 s of speech each). The one-step mix
(film + six WAVs, `adelay` + `amix` in one ffmpeg call) lost the audio timestamps; the broken start time also broke seeking.
The check had looked only at the script's own printout, never at the written file.

Fix (voiceover.py): step 1 renders the narration alone (every line reset to t=0 with `asetpts=PTS-STARTPTS`, one channel,
delayed with `adelay=…:all=1`, mixed, loudness-normalised to −16 LUFS, padded to the film's length) into a WAV; step 2 muxes
the film and that WAV with `-movflags +faststart`. Both files are checked: an audio stream shorter than the film by more
than 0.5 s, starting away from 0, or with a mean below −50 dB refuses the film. Re-made: eight voiced films, audio 32.4–33.0
s, start 0.000, mean −21.2 / −21.6 dB.

Also: the operator rated the Arcane 14B film (§ 16) as good ("came out really well").

## 19. Episode 2 (2026-11-08): keyframes, narration, and a model-swap slowdown

The operator's story for episode 2: she settles in the cave and rests; a nuclear winter comes (black clouds, a dead
forest, mutated animals); darker; at the end she leaves, finds an old military 4x4 ("a Hummer"), starts it and races into
the sunset; the narration in the episode-1 storyteller style. Eight shots of ~5 s: Qwen-Image 2512 keyframes of set B's
character (cold desaturated colours for the winter shots 3–7), restyled with the Arcane LoRA (1.0, denoise 0.55), then
Wan 2.2 A14B + lightx2v with the gaze words, the server restarted before every clip (§ 16–17). The truck is described
as "boxy military off-road truck like a classic Humvee, without any logo" so no brand mark is drawn.

Observed while making the keyframes:
- Alternating the two image models per shot (Qwen-Image 20 GB, then Z-Image for the restyle) made each image take 37–210 s
  instead of ~7 s on a server just restarted after the host's reboot, and one restyle failed with "RuntimeError: Fault
  failed: 2" in the text encoder. Rendering all Qwen keyframes first and all restyles after (each model loaded once) on a
  restarted server: 6–33 s per image and no fault.
- Shot 8 came out with the truck driving TOWARD the camera; eight re-rolls: "view from behind … driving away … into the
  sunset" gives the rear view, but two seeds added people on the roof and one a car-brand-like emblem; adding "nobody on the
  roof or around the vehicle, the driver hidden inside, a plain tailgate with no emblem" gave a clean rear view (seed 358).
- The mutated wolves read as ordinary wolves (only slightly gaunt); accepted for this episode.

Narration (eight lines, the same two cloned storyteller voices): Qwen3-TTS one batch 82.6 s for 42.5 s of audio (RTF 1.94);
VoxCPM2 10 steps 113.2 s for 44.0 s (RTF 2.57; the GPU had just been freed by ComfyUI). The mixer now counts the lines.

Episode 2 rendered (2026-11-08 19:28–21:51): eight 14B clips of 1002.2–1014.7 s each (the restart rule held for all
eight), joined into a 40.5 s film; the narrations mixed and checked (Qwen 43.4 s, VoxCPM 44.4 s; audio from 0.000 s,
−21.1 / −21.5 dB). By eye on frames of every clip: the Arcane look and the character hold; the clouds, the ash, the dead
forest, the wolves closing in, the departure, the truck and the drive into the sunset all as written. One fault: in shot 2
she is meant to sleep (the narration says so) but her eyes open mid-clip; re-rendered with "eyes closed the whole time"
as a v2 film beside the first.
Shot 2 again ("eyes CLOSED the whole time, deep peaceful sleep", same keyframe and seed, 1003.4 s): the eyes stay closed
through frame 63 and open again from frame 66 of 81 — the 14B model returns toward the keyframe's open-eyed face at the end
(the Arcane keyframe has open eyes). Fix without another render: frames 0–63 kept and frame 63 held for the last 17 frames
(the clip keeps its 81 frames, so the narration timing holds). The v2 film and its two voiced versions are checked as
before (audio from 0.000 s, −21.1 / −21.5 dB). A sleeping shot should start from a keyframe with closed eyes.

## 20. Episode 2's face made to match episode 1 by reference images (2026-11-09)

The operator compared episode 2's Arcane frames with a profile frame of episode 1's Arcane film: the nose and the face
differ. Cause: each episode-2 keyframe was drawn from text by Qwen-Image and then restyled by the Arcane LoRA, and both
steps redraw the face. Fix: Qwen-Image-Edit-2511 (fp8, the 4-step Lightning weights merged; 20 GB, sha256 16d03fd9…)
draws every keyframe directly in the Arcane look, given up to three reference images through `TextEncodeQwenImageEditPlus`
(image1..3, each scaled by `ImageScaleToTotalPixels`, which needs `resolution_steps`). The references are frames of
episode 1's Arcane 14B film: a profile (shot 2, frame 8), a front face (shot 2, frame 55) and the whole body (shot 6,
frame 78); no separate restyle.

- Keyframes 1–7: 30–50 s each (the first loads the model). By eye against the references: the nose, the brows and the face
  shape match episode 1 in shots 2–6; shot 2 is drawn with closed eyes (the sleep shot, § 19).
- Shot 7 first drew a six-wheeled cargo truck; with shot 8's truck frame as image3 instead of the body reference
  (a per-shot reference list) it drew the same four-wheeled military car as shot 8.
- Clips: Wan 2.2 A14B + lightx2v, the server restarted before every clip (§ 16): 997.3, 1164.4, 1171.6, 1094.9 and
  1129.5 s for clips 1–5 — about 10–17 % slower than episode 2's first run (1002–1015 s), with the CPU busy with the
  voice work below during clips 2–5.

## 21. The film's ending, static starts, and the frame rate (2026-11-09)

- **Ending.** When the narration ran past the film, the mixer held the last frame; the operator: "the picture does not
  move during the whole last phrase". `voiceover.py --end slowmo` now stretches the last shot to end with the narration,
  motion-interpolated (`minterpolate`, mci/aobmc/bidir): 1.43× (Qwen narration) and 1.51× (VoxCPM). Accepted by the
  operator: "the video and the sound end together".
- **No static start.** An advice found online says that image-to-video clips start with 4–8 near-still frames that should
  be cut. Measured on our six 14B clips (mean |luma step| per frame against the clip's median): the first steps are
  0.6–1.3× of the median from frame 1, so nothing to cut.
- **Frame rate.** Wan renders 16 fps. Motion interpolation to 32 fps on the CPU (3.5 min for the 33 s film); the operator:
  "many times better, almost all the blur is gone", and asked for 60 fps. 60 fps: 693 s on the CPU (shared with a TTS
  run), 1962 frames, 32.7 s; frames in the fast run at 12 s are clean. `minterpolate` repeats a frame 3 times (0.05 s) at
  three of the five cuts (its scene-change detection).
- **Motion pattern.** Inside every 14B clip the per-frame motion alternates large and small steps (about 1.2× and 0.7× of
  the median), a judder at 16 fps that interpolation smooths.

## 22. Softening the cuts between shots (2026-11-09)

The operator: between the running shots the light and the shadows on her face jump. `transitions.py` "light bridge": for
the first second of every shot after the first, each RGB channel's mean and spread are pulled toward the previous shot's
last frame, the weight easing from 1 to 0 (smoothstep); an optional 0.4 s dissolve. Two films for the operator: bridge,
and bridge + dissolve.

The operator's verdict on both: a freeze of about 0.5 s at every cut (and once between 3 and 4 s). Measured
(`freeze_scan.py`, steps under 0.15× of the median; `motion_profile.py` per frame): no still and no repeated frames in
either file, and the motion just after each cut is 0.9–2.1× of the median, as in the film without the bridge. The one
technical difference found: the bridge films carried no colour tags (the frames were encoded from raw RGB), so a player
must guess; the encoder now tags bt709/tv. The cause of what the operator saw is not settled; open questions to the
operator: which player, and whether the film without the bridge freezes too.

## 23. A female narrator (2026-11-09)

The operator asked for a female narration besides the old storyteller. An original voice (no real person's voice):
VoxCPM2 voice design, "a mature woman in her forties, a warm low velvety voice, calm and slightly mysterious, slow measured
pace…", three takes of the storyteller's reference sentence, on the CPU while the GPU rendered (612–1069 s per take).
Scored by `ref_pick.py` (Whisper large-v3-turbo CER, median pitch, length):

| take | length | median F0 | CER |
|---|---|---|---|
| 1 | 8.0 s | 160 Hz | 0.000 |
| 2 | 7.7 s | 190 Hz | 0.000 |
| 3 | 5.8 s | 223 Hz | 0.000 |

Take 1 (the lowest and slowest) is the reference; the narration is its VoxCPM2 clone at 10 steps (`narrate.py`), on the
CPU: 745.5 s for the first 5.9 s line (model load included), 298.2 s for the next 5.3 s line.

All six lines took 3620 s on the CPU for 34.4 s of audio. The operator then ruled: no heavy jobs on the CPU (the PC froze
while TTS and 60 fps interpolation shared the CPU); such work waits for the GPU.

A second female voice by Qwen3-TTS VoiceDesign (same description): takes at 162 / 87 / 163 Hz median F0, all CER 0. The
first selection rule ("lowest F0 wins", right for the male storyteller) chose the 87 Hz take; 95 % of its voiced frames
were under 140 Hz, the male storyteller's range (78–112 Hz) — not a female voice. The rule for a female voice is now
"median F0 ≥ 140 Hz, then the lowest"; the clone from the 162 Hz take speaks at 151–160 Hz (GPU, 60–270 s for 27 s).

## 24. The PC froze after every job: memory flags and the VM memory limit (2026-11-09)

The operator: "configure it so models are not offloaded from the GPU to RAM; read from disk each time instead — 3 s of disk
read is better than the whole PC freezing for a minute". Measured on one Wan 2.2 14B clip each, Windows counters every
5–10 s:

| | default | `--fast-disk --disable-pinned-memory` | + VM limited to 20 GB |
|---|---|---|---|
| clip time | 1067 s | 1008 s | 991 s |
| RAM used inside the ComfyUI VM | ~38 GB | ~4.5 GB | ~4.5 GB |
| Windows' lowest free/available RAM, job end | 51 MB free | 2.3 GB free | 20.6 GB available |

In every mode the GPU freed ~26 GB when a job ended and, within ~30 s, Windows lost ~20 GB of available memory while
committed bytes went DOWN (standby pages consumed by pages faulted back in): the host was overcommitted (~140–170 GB
committed on 91.6 GB RAM). The ComfyUI VM held ~42 GB of committed memory it never returned. Two consultants agreed on
host overcommit as the best-supported cause. Fixes kept:
- ComfyUI starts with `--fast-disk --disable-pinned-memory` by default (`-RamOffload` restores the old mode).
- The wslc VM memory: `session: memorySize: 20GB` in the wslc user settings file (`settings.yaml`, template printed by
  `wslc settings`; the default is half of the RAM). The setting is read when a SESSION is created — a VM that only
  idles down (30 s without containers) keeps the old size; `wslc system session terminate` (between jobs) applies it.
  The model volumes survive it. Training jobs raise it to 40 GB and set it back.

## 25. One face in every shot: from face swap to reference keyframes (2026-11-09)

The operator approved one face (frames 76/80 of episode 2 v3's sleep shot: "this face everywhere") and wanted it in every
Arcane shot ("after 10 s she ages ~30 years"). What was tried with Qwen-Image-Edit-2511 (each round 2–4 seeds per shot,
picked by eye):
1. Naming the forehead in the prompt ("no mark, no jewel, no pin") DREW a circlet, a jewel or a pin; "golden strands
   from the temples" became wires. The pin was in the REFERENCE frames themselves (episode 1's Arcane frames); the edit
   model copied it. Fix: fill it in the references (`clean_refs.py`, row by row with the skin beside it).
2. "grim cold desaturated colours" aged her and turned the green tunic black; the cold went into the scene's light only.
3. The enlarged face crop as image 1: the model copied its composition (a lying close-up) into every scene — **Qwen-Image-
   Edit builds the picture on image 1.** Image 1 must be the body/composition, the face references images 2–3.
4. A face swap (the old keyframe as image 1, "change only the face") drew extra people and cartoon faces — rejected.
5. Image 1 = the approved test keyframe (the face, the tunic, the whole body), "take only the woman from image 1, not its
   background, exactly one woman", the scene in words (+ "warm summer day, no snow" for episode 1): right in nearly all
   shots. Episodes 1 and 2 were re-rendered this way (Arcane ep2 v4: v3 shots 1–2 kept, 3–7 and a new shot 9 new; ep1:
   all six shots); the realistic episode 2 used the same method with episode 1's realistic keyframes as references.

Also: a sentence "she blinks naturally now and then" made her blink again and again (removed); a shot without an entry in
a per-shot table failed with KeyError and an old clip was joined silently (the joiner now has a fallback); files written by
the container are root-owned — moving them from WSL failed silently; they are moved inside a container.

## 26. Eyes: the sampling steps do not help, the seed does (2026-11-10)

The operator: "the eyes still jump sometimes; the eyes are the main thing". Episode 1 shot 2 (the face close-up) three
ways, judged by eye on enlarged consecutive frames 0–23: A = a new seed, 4 steps (1112 s); B = the same seed, 8 steps
(1283 s); C = B + a sentence about steady eyes (1261 s). A was the steadiest. B and C FLICKERED the iris colour (green
in frame 0, amber in frames 1–7, green again); the sentence did not help. Method kept: face shots at 4 steps, 2–3 seeds,
the steadiest kept by eye. Two automatic jitter scores (a skin-colour face box; kornia's YuNet eye points) both failed
their own check on a known pair and are not used.

## 27. A character LoRA on Qwen-Image (2026-11-09/10)

musubi-tuner (kohya-ss, commit f8a1b03; installed with the operator's approval into its own volume, venv over the image's
ROCm torch 2.13 with the ROCm constraints file) trained LoRAs of the approved character on Qwen-Image (bf16 DiT 40.9 GB +
the bf16 Qwen2.5-VL 7B text encoder 16.6 GB, both fetched with pinned sha256): `--fp8_base --fp8_scaled --blocks_to_swap
8`, adamw, dim/alpha 16, lr 5e-5, 1024x576 buckets, the VM at 40 GB.
- v1: 32 pictures (keyframes, clip frames, the face references, 10 generated portraits) x 4 repeats x 16 epochs = 2048
  steps, 4.57 s/step, 2 h 36 min, loss 0.124 -> 0.091.
- v2 (the operator: keep v1, try softer features): 22 pictures (16 picked from LoRA v1 at 0.6 + "soft delicate facial
  features", the face references, 4 portraits; the captions do not name the softness) x 4 x 8 epochs = 704 steps, ~54 min.
Tested text-only on Qwen-Image-2512 fp8 + Lightning (no reference images), seed 4242, 4 scenes: a LoRA trained on the
original Qwen-Image loads on 2512 with no unloaded keys. Without a LoRA: a different generic girl. v1: the same character
in every scene, stricter features; strength 0.5–0.7 brings back the base model's softness while keeping the look. v2:
softer, warmer faces; wavier hair and a fainter golden strand. The operator: the base model's faces are prettier, v1 is
"also very interesting" — both kept.

## 28. Episode 3 script, the ComfyUI image, workflows (2026-11-09/10)

- Episode 3 ("The Castle"): the operator's story as a 22-clip shot list (~85–95 s), reviewed with two consultants: her eyes
  only in tight close-ups or far away, every keyframe already in its final state (eyes, hands on the grips, boots off the
  floor), one motion per clip, long camera moves as several clips with motivated cuts or first-last-frame clips, the
  pupil dive as two clips plus a zoom in the edit, her voice recorded first, no lip-sync shots, original designs only.
- The ComfyUI image (27.3 GB: the ROCm/PyTorch base, ComfyUI v0.44.0, the entrypoint; audited: no secrets, no personal
  paths; models and the data volume are not in it) was pushed to the GitHub Container Registry (1407 s).
- The pipelines were exported as ComfyUI UI workflows (`ui_workflows.py`: the drivers' API graphs converted with the widget
  order read from the live `/object_info`, titled nodes, an explaining note).

## 29. The PC ran out of RAM again: one big model per server session, a RAM guard (2026-11-10)

Two to three minutes after the episode 3 keyframe job resumed, Windows' "modified" page list grew from 0.9 GB to 85 GB
and available memory fell to 10–14 MB; WSL died (exit 137). It happened even with the model download to the NAS store
already stopped. The job was switching Qwen-Image (~20 GB), Qwen-Image-Edit (~20 GB), the text encoder (~8 GB) and a
LoRA inside ONE ComfyUI server while the wslc VM was limited to 20 GB (§24): the VM swapped to its own disk and the host
write cache filled; writing the download to the NAS store through the Windows cache added to it earlier.

Fixes kept:
- **One big image model per server session.** The keyframe drivers take a phase: `text` runs only the Qwen-Image steps
  (the poses), `edit` only the Qwen-Image-Edit steps, with a server restart between the two phases.
- **A RAM guard** (`guard_ram.sh`): every 5 s it reads Windows' available memory and stops the ComfyUI container below
  6 GB (the GPU job dies, the PC survives); every run since has started it and stopped it at the end.
- **Downloads go to the local model volume only**; the NAS copy is made later. A large download is not run during a
  14B clip run (it writes into the VM's disk through the same host cache).

Measured with the two phases: 44 keyframe images (poses, scenes and edits) in 20 min — ~1.5 min per shot, against 3–4 min
when both models shared a server — Windows' lowest available memory 25 GB, the highest modified list 22 GB, the guard
never fired. The later runs of the day (28 edits + 16 poses in 20 min; the masked repaints of §30) were the same: the
guard never fired.

## 30. Episode 3 keyframes: one costume, normal ears, one sword — the edit model and the masked repaint (2026-11-10)

The operator reviewed the 23 picks over several rounds: the faces in two shots ("something is wrong with the face"), then
"the clothes differ everywhere — they must be as on shot 15", "the ears differ on half the shots — they must be
ordinary", "the sword must be this style everywhere", and three scene errors. What was found:

1. **The green top was our own prompt.** Every face edit appended episode 2's hair sentence, which ends "Her tunic is dark
   GREEN" — so every Act 3–4 shot that went through the edit got a green top; only the shots kept as step-1 pose pictures
   did not. The costume shots now use a hair-only sentence and "take only the face from image 2, not its clothes".
2. **The edit model draws what a prompt names, even after "no" or "NOT"** (the forehead mark of §25 again):
   "her hair covers her ears" still gave pointed ears; a whole-picture touch-up asking for "small rounded human ears, NOT
   pointed, NOT elf ears" made the ears LONGER, and gave pointed ears to a shot that had none; "no green clothes, no
   sleeves" was followed by candidates with one long sleeve. Rewritten as positive words only ("her arms are bare from
   the shoulder to the bracers"; "her hair falls smoothly over the sides of her head"), the next four poses were all
   sleeveless. The edit graph runs at cfg 1.0, so a negative prompt has no effect at all.
3. **Whole-picture touch-ups of an approved picture drift.** Asked to remove one small object, the edit shifted all the
   colours to blue, or added a person; asked to add a shield and a drone, it removed her sword and drew pointed ears.
4. **The masked repaint works.** A box or a line is placed by eye on a crop with a 0.02 coordinate grid, the mask is
   previewed in red before any GPU time, the area inside the mask is first filled with a blur of the picture (so the
   model no longer sees the thing), only the mask is sampled (VAEEncode + SetLatentNoiseMask, denoise 0.85–0.95), and
   the result is pasted back onto the untouched pick with ImageCompositeMasked. The prompt names only what fills the
   place. Used for: pointed ears in four shots (both ears in one; "long straight silver-white hair falls over the side of
   her head"), a nose shadow (no blur fill, denoise 0.6, the nose keeps its shape), a second small dragon (two masks, wings
   and body, so the big dragon's leg beside it stays), and flames burning on a fur rug (four masks; "lit by warm orange
   light" in the prompt left two orange streaks, a second pass with "fur in soft shadow" removed them). Two candidates
   per mask; outside the (softened) mask the paste keeps the pick's own pixels.
5. **One sword style by a line mask and a reference crop.** A thick line mask from hilt to tip, the reference sword cut
   out of the approved shot as image 2, no blur fill (the old sword keeps the position and angle), denoise 0.8 and 0.95,
   four candidates per shot. The result is the same TYPE of sword (a steel hilt, a curved crossguard, a straight blade),
   not an exact copy — the pommel differs; two candidates drew a gold double guard. The operator accepted it ("perfect").
   An exact object in every shot would need its own LoRA.
6. **The edit step takes the LIGHT of its reference images.** A detailed sunrise text gave four correct sunrise poses;
   the edit step, with the costume design (a night picture) as image 3, turned all four into night and drew a second,
   ghost face in two. The pose picture itself was used (as for the operator's reference shot), so its face is the pose
   step's adult profile.
7. **A new prop is a new pose, not a touch-up.** "The automaton holds a sword and a shield; a camera drone above records
   the fight" came out right from a new pose text + the edit in one of two candidates (in the other she held the
   shield).

## 31. Episode 3 clips: own hero texts, short clips, and frames that do not cost the time (2026-11-10)

The clips are Wan 2.2 14B I2V at 1280x704, 16 fps, lightx2v 4 steps, shift 5, a fresh server per clip (§17), each from the
approved pick.
- **Own hero texts.** The video prompt of episodes 1–2 describes her with "a matte dark-green wool tunic" and ears "with
  only a tiny point at the very top" — in Act 3–4 clips that would pull back the errors fixed in §30. Episode 3 has two
  texts, one per costume, positive words only and no ears; the steady-gaze sentence only where her eyes are seen; no blink
  words (§25).
- **Short clips.** Rows where the edit uses only 2–3 s get 49 frames (3.06 s) instead of 81.
- **Test clips, judged frame by frame:** the tight face close-up (81 frames, 1034 s): the face and the eyes stable, the
  expression moves naturally from awe to a stunned look, ONE blink at ~1.2 s where the script wants the eyes wide — a
  second seed is planned. The fight (49 frames, 1135 s): the strike on the shield, the automaton's sword and shield and
  the drone stay stable. The sunrise run (49 frames, 1085 s): clean. Frame counts checked with ffprobe.
- **The 49-frame clips took as long as the 81-frame one**, so most of a clip's ~17–19 min is not spent on frames; model
  loading and moving the two 14B experts' weights are the suspects. A per-phase timeline of one clip is being recorded;
  the answer is **open** here and goes into the next section once measured.
- The operator moved better facial expression and more natural motion to episode 4: an A/B there of shift 8, a split
  sampler (the first high-noise steps without the speed LoRA) and expression words in the motion text, before any
  clip batch. Frame interpolation 16 -> 32 fps (FILM, native nodes) is part of episode 3.

## 32. MIOpen is off by default in ComfyUI on this GPU: the VAE decode took two thirds of every 14B clip (2026-11-10)

The open item of §31. A per-phase timeline of one Wan 2.2 14B clip (`bin/r9700 comfy timeline`, the time a log line
first appears) showed where the ~17 min of a clip went. One clip, 81 frames before the change (prompt executed in
16 min 39 s):
- the server was up 16 s after the container start (ComfyUI-Manager fetches its node lists for ~2.5 min per restart,
  but in the background — it does not block a prompt);
- text encoder and VAE load: ~30 s;
- high-noise expert, 2 steps: ~2 min; low-noise expert, 2 steps: ~2 min;
- **VAE decode: 11.7 min** (of the 16 min 39 s).

So the time was not in the frames, and that is why the 49-frame clips of §31 took as long as the 81-frame one. The
sweep of 2026-11-07 had measured the decode alone at 70–95 s; the new memory flags and the tile setting were the first
suspects.

**Cause (read in the code).** ComfyUI's `model_management.py` sets `torch.backends.cudnn.enabled = False` on this GPU
("for better AMD performance", it says in the log) unless the environment has `COMFYUI_ENABLE_MIOPEN=1`. The video
VAE is made of 3D convolutions; with the switch off they run without MIOpen. The comfy-cache volume held only a 20 KB
MIOpen user kernel database from 2026-11-07 and no find database.

**Test without sampling again.** The clip driver now saves the latent (SaveLatent), and a small driver decodes a saved
latent with VAEDecodeTiled and times it. The latent of one shot (s07), decoded with MIOpen on:

| decode of one saved latent | time |
|---|---|
| in the normal clip, MIOpen off | ~700 s |
| MIOpen on, tiles 512/64, temporal 32/8 (production tiles), first run: VAE load + kernel search | 78.3 s |
| MIOpen on, tiles 512/16, temporal 64/4 | 39.4 s |

The picture is the same: PSNR 45.78 dB against the normal clip's decode (the limit set before the test was 35 dB).
The decode is ~9 times faster.

**Trap: the cache.** The second run of the production tiles was logged as 4.0 s. That is NOT a measurement: an
identical graph run twice is answered by ComfyUI's cache of the first result, and nothing is decoded. The decision
rests on the first run (78 s against ~700 s). To time a graph twice, change a value in it (a seed, a tile size).

**Result.** The operator's start script now turns MIOpen on by default (an opt-out switch keeps the old behaviour).
The MIOpen kernel database lives in the comfy-cache volume, so it survives container restarts: it grew from 20 KB to
200 KB in the first runs. Wall times per clip (shot 1 is the same shot with 49
frames both times; the later rows hold clips of 49 and 81 frames):

| clip | wall time per clip |
|---|---|
| shot 1 before (MIOpen off) | 1093 s |
| shot 1 again, new keyframe (MIOpen on) | 367 s |
| episode 3, shots 8–23 (MIOpen on) | 319–345 s each |
| the rerolls of episode 3 (MIOpen on, §34) | 341–359 s each |

About three times faster per clip, and ALL of it is the decode. The phase timeline of two 81-frame clips, one before
the change (shot 5) and one after it (shot 8), shows the two samplers unchanged: high-noise 2 steps 79 s and
low-noise 2 steps 79 s in both (each with its model load); the prompt took ~1000 s before and 347.8 s after. (A
first estimate of "~25 % faster sampling" compared the 49-frame shot 1 with an 81-frame clip — fewer frames sample
faster — and was wrong; the same-length comparison corrects it.) The question why the same decode took ~700 s in the clips and
70–95 s in the sweep of 2026-11-07 was not tested further (the start settings of that sweep are not kept here): with
MIOpen on the decode is back at the sweep's level.

## 33. The RAM guard: a restart makes a harmless spike, so one low reading is not a crisis (2026-11-10)

The guard of §29 stopped the ComfyUI container when Windows' available memory fell below 6 GB in ONE reading. During
the episode 3 clip run it fired on healthy jobs. A sample of available memory and the "modified" page list every
10 s (during the post-production run of §34) shows why:

(a) **Every container stop between two clips is a short spike.** Windows holds the VM's memory as "modified" pages
for ~10 s: the modified list jumped from ~9 GB to ~35 GB (35 060 MB in the first dip sampled, 35 343 MB in a later one) while the available memory fell from ~23 GB to 3.5 GB (3532 MB, the lowest sample), and one sample
(11 s) later 38 GB were free again. The two stops of that evening (4241 MB and 4373 MB available) were dips of this size. The crises of §24 and §29 were
different: sustained, below 150 MB.

(b) **Two low readings in a row (~10 s) are needed to stop.** One low reading is logged ("one low reading … waiting for
a second") and forgotten when the next one is fine. Since the change two single low readings at clip restarts (5272 MB
and 3372 MB) were correctly not stopped, and no guard stop came after it.

(c) **Two bugs in the hand scripts, found because a run ended early after one clip:**
1. *A shared stop file left older guards running.* A new guard deletes the stop file at its start, so an older guard
   kept running beside it; one of those fired (4373 MB available, one clip-end dip) in the middle of a run. Fix: the guard
   takes the stop file as an argument, each run uses its own file and a trap that ends its guard when the run ends.
   Result: no leftover guard in the runs after it (guard log: one "on" per run).
2. *A check read stale `GUARD STOP` lines.* The run script asked "did the guard stop ComfyUI?" by looking for the
   words in the shared guard log, found a stop from 18:36 and ended the run after its first clip as if the guard had just
   fired. Fix: the check counts only the stops written since its own run began. Result: the restarted run went through
   to its end. The older clip-run script has the same pattern and is to be fixed before it is used again.

The limit was kept at 6000 MB with the two-readings rule (it was lowered to 3500 MB for one restart as a stop-gap and
put back).

**Follow-up (open, a code change, NOT part of this change of the record):** the repository's own `bin/r9700 comfy
guard` mode (`lib/comfy_watch.sh`) still stops on ONE low reading below its limit (and after three unreadable reads).
It should get the same two-readings logic, with a test (a single low reading is logged, two in a row stop), and
`research/module_comfyui.md` and `research/module_tests.md` (the CW cases) should say so.

## 34. Episode 3 post-production: rerolls, a song picked by speech recognition, a mixer bug, loudness-based mixing (2026-11-10)

All 23 clips of episode 3 were done (from shot 8 on with MIOpen, 319–345 s each; §32) and every one was reviewed on frame
sheets. Good as they were: shots 2, 3, 5, 7, 9, 12–19, 22, 23 and the new shot 1. Faults and what was done:

**Rerolls** (a second clip of the same shot, new seed or new text; the label of the clip is a letter after the shot):
- *Shot 1 went the wrong way.* The first clip (1093 s) drove the vehicle OUT of the castle toward the camera. The
  keyframe showed its front ("with its headlights on" was in the prompt). The shot text now says "seen from behind, the
  rear and red tail lights to the camera, the front toward the open gate" (positive words, §30), four new keyframes
  were made, and the new clip (367 s) drives into the lit gate.
- *Shot 6* (one blink at ~1.2 s where the script wants the eyes wide): the reroll was clean.
- *Shot 10: she walks instead of floating.* The reroll walks again. The KEYFRAME shows her in the middle of a step, and
  an image-to-video clip continues the pose of its first frame whatever the text says. Only a new keyframe with her
  floating fixes it (the operator's option); the film keeps the first clip.
- *Shot 11: one eye closes briefly.* The reroll winks at ~3.6 s. It was handled by trimming: the shot is cut to 0–3.3 s,
  and the picture is 1.7 s shorter (91.0 s → 89.3 s).
- *Shot 20: the eyes close twice during the angry line.* The reroll has one frustrated eye-close, then open.
- *Shot 21: flames burn on the edges of the rug.* This keyframe had never been through the masked repaint of §30. It was
  repainted ("fur in soft shadow" in the prompt, clean), and the clip text now names "a small campfire on the grass
  beside the rug". The reroll shows two small fires on the ground beside the rug, not on it.
- *Shot 8:* the sword shrinks to a dagger after ~2.6 s; the shot is cut to 0–2.6 s.

**The song chosen by speech recognition.** Three songs were generated for the sung line and each was transcribed with
Whisper and compared with the lyric: character error rate 0.09, 0.41 and 0.80. Song 1 (0.09) is in the film; the
sung words are the lyric.

**A mixer bug, found because the run said "done" and the mix had failed.** The first post-production run ended with
"POST DONE" after a traceback. The mixer (`ep3_edit.py`) gave each sound file an ffmpeg input number taken from the
length of the argument list, which also holds option words (`-y`, `-v`, `-threads`, …), so the filter graph pointed at
inputs that did not exist and ffmpeg refused it. Fix: a counter of the inputs. The run script had printed "POST DONE" although its
last step had failed (the failure was found in the log, not from the end line; a failed step must stop the run, as in
§18), and the mixer gained `--reuse-picture` and a `timeline.json` so
that a mix can be redone without building the picture.

**Loudness-based mixing.** The first complete film (v1: 91.0 s, 1280x704 at 32 fps) measured −16.1 LUFS in total, but its
loudness range (LRA) was 15.8 LU: all of Act 2 was nearly silent. The cause: the generated files differ by ~30 LU
(measured with ebur128): the glade bed −32, the hall tone −44, the float hum −35.5, the music −13 LUFS. A mix with
fixed per-event gains cannot be right for files that far apart. The mixer now measures each file and brings it to the
target of its KIND before any tweak: voice −18, effect −18, bed −28, music −24 (before it is ducked under the voice); the
per-event factors are only relative tweaks (beds and music 1.0). Act 2 also got the hall tone as a bed, the float hum at
0.9 and a new music piece (a glassy chord over a drone).

**Result (v2, the operator's review copy):** 89.3 s (89.31 s), 1280x704 at 32 fps (FILM, §31), −16.3 LUFS, LRA 5.6 LU
against 15.8 LU in v1.

## 35. Episode 1 v3 and the episode 2 upgrade: keyframe re-check, a masked face repaint, MIOpen clips, a new sound design (2026-11-10)

**Episode 1: the keyframes were re-checked with the rules of §30.** Contact sheets of the six picks showed: shots 2, 3
and 5 good; shot 6 with normal ears (good); shot 4 with a POINTED ear; and shot 1 a pose picture with an OLDER, harder
face than the character's (the consistency problem of §25). The clip text of episode 1 described the ears with "a tiny
point" (the old hero text of §31); it now uses episode 3's hero text.

**A masked repaint of any picture** (one driver, two modes) with the masks previewed in red before any GPU time:
- *ear:* the hair-only prompt ("hair falls smoothly over the side of her head") with the blur fill of §30, the box kept
  off the cheek. Two candidates: the first a blurry patch, the second clean hair — the second was chosen.
- *face:* the young face of the approved shot as **reference image 2**, NO blur fill (the old face keeps its position
  and angle), denoise 0.75. Two candidates: the first startled with eyes too wide, the second her young face, calm —
  the second was chosen. Each repaint took 9–34 s (the first of each mode was the slower).

**The clips with MIOpen:** the four approved shots (2, 3, 5, 6) took 339.9–341.0 s each (§32), all good: shot 3 shows
real fear with the scripted flinch, shot 6 she sinks down exhausted. Shots 1 and 4 are NOT yet animated: they wait for
the operator's look at the two repaints (and an agreed test of shift 8 on shot 4). Four clips were interpolated from 16
to 32 fps (FILM, 17–20 s each). The episode's sound (seven sound files, the narration of six lines) and its
edit list (33.5 s in all, a hard cut of all effects and music at the last shot, a cave echo on the last line) are
ready; the film itself waits for those two clips.

**Episode 2 upgrade (no new clips).** Both approved versions of episode 2 (the Arcane-style one and the realistic one,
nine clips each) got: FILM interpolation of all 18 clips from 16 to 32 fps (17–20 s each), a new sound design — nine
shot effects and a music bed — and the music bed ducked under the narrator's eight lines, with the loudness targets of
§34. The whole run took 8 min (22:43 to 22:51, the guard of §33 never stopped it). Both films measure the same:
**45.28 s, −16.3 LUFS, LRA 4.0 LU, 32 fps**; the narration ends at 43.63 s, so the slow-motion end of §21 was not
needed.

## 36. The realistic track: a LoRA with the wrong face, a masked face repaint, and InstantID (2026-11-11)

**The second realistic LoRA had the wrong face.** The first realistic character LoRA (`slvrareal`, 1792 steps in 2 h 13 min,
average loss 0.0715) was trained on 32 pictures. The strength test (0.6, 0.8, 1.0) showed almost no difference between the
strengths, so 1.0 was used. In the film the thin golden strand of hair often became a thick gold braid, and the face looked
older than twenty. The operator chose the face of the painted LoRA `slvra_v1` at strength 0.7 plus photo words as the
reference face, and asked for two LoRAs, one per outfit (tunic and fur), made from text only.

**Three sets of training pictures, three faces.** The pictures for the new LoRAs were made from text with that face. Set a
(the words "strong dark straight eyebrows") gave heavy brows and a harsh, older face. Set b (the exact words of the test
that had made the chosen face) gave a soft, generic face with light brows. Set c (those words plus "big grey-green eyes,
dark eyebrows") was closest to the target. The face still varied with the seed, because only text was used.

**A masked face repaint before training.** A square crop around the face was enlarged to 1024 pixels (small faces), repainted
with the edit model, and pasted back through a mask. All 54 pictures were done; the face boxes were read off grid sheets and
the mask previews were checked (21 boxes were moved after the preview). The results, in order of what was tried:
- *Denoise 0.75 with the head of the target as reference image 2:* the faces move only a little toward the target; heavy
  brows stay; seed 2 often adds freckles that the target does not have. Denoise 0.9 and 1.0 break close-ups (double eyes,
  melted faces, an old woman); only small faces survive.
- *Full edit of the head crop (the "swap" method):* the edit model copies the reference head with its framing, which is
  unusable.
- *InstantID* (`ComfyUI_InstantID`, insightface 0.7.3, onnxruntime 1.31.1 on the CPU, RealVisXL V5.0, antelopev2): no broken
  faces, pose, expression, cup and side view kept, one face in all pictures. Face weight 0.8 loses the golden strand, so 0.6
  at first; a second test with weights 1.0 and 1.2 was a little closer to the target (fuller lips, warmer) and nothing broke;
  1.2 was used for all 54.
- The masked repaint keeps the geometry of the SOURCE face: the InstantID keypoints come from the source face and a denoise
  of 0.6 to 0.75 keeps its structure, so the nose and face shape follow the source picture, not the target. A whole row of
  one picture (a front portrait) was broken this way and was dropped from the set.

**Too old, then too young.** The first full run gave pictures that were "clearly older" in places, because the source
pictures have thick brows and contour make-up. A younger prompt ("thin straight natural eyebrows, light natural makeup",
negative "heavy makeup, thick bushy eyebrows, contour makeup, older woman") at denoise 0.75 gave thinner, lighter brows and a
softer face, still an adult, but weakened the golden strand in some pictures. The operator did not want a really young girl;
the goal was to make the older-looking pictures look like the younger ones of the set, not younger than that. Two datasets
of 27 pictures each (tunic and fur) were made; the older datasets were kept (append-only). Both LoRAs trained one after the
other (tunic finished 19:51, fur 21:37).

**An episode-1 face that was rejected.** A first attempt to repaint the face of the painted episode 1, shot 1, with a young
reference and the words "soft round cheeks, big eyes, small straight nose" was rejected hard by the operator: it looked
like a ten-year-old, not a beautiful woman of twenty-five. The cause was both the reference and the face words. The
reference was replaced by a head cut from an approved painted frame (the adult face the operator calls ideal), and the
words became "a beautiful woman of about twenty-five, slim face, defined cheekbones, calm". Rule for later episodes: never
use "young face", "big eyes" or "soft cheeks" for her.

**Two more rules from the same days.**
- Never name the front parts of a vehicle that must be seen from behind ("headlights" drew the vehicle driving at the
  camera): the lesson of the episode 3 car shot came back in episode 2.
- A face step copies the EYE STATE of its reference (a reference with open eyes opened the eyes of a sleeping woman); for
  closed eyes use the pose picture, not the face-edited one.

## 37. Character LoRA v3 on four base models: Qwen-Image, FLUX.2 klein 4B and 9B, SDXL (2026-11-12)

All four were trained on the same dataset `slvrareal3`: 37 pictures, namely 26 pictures made with another image generator
(sitting on a forest floor in the dark-green tunic, many emotions; one collage was cut into four crops) and 11 chosen by the
operator from earlier tests, each with a caption (trigger, her look, emotion and view). Each LoRA was then tried on the same 5
scenes (portrait, laugh, angry, castle walking, campfire) at strengths 0.6, 0.8 and 1.0, one contact sheet per model.

| Base | Trainer and settings | Steps, time, loss | Test |
|---|---|---|---|
| Qwen-Image 2512 | musubi-tuner, bf16 weights quantized to fp8 at load (`--fp8_base --fp8_scaled`), `--blocks_to_swap 8`, rank 16 alpha 16, `adamw` (torch; bitsandbytes on ROCm was not checked) at 5e-5, `discrete_flow_shift 2.2`, gradient checkpointing, a checkpoint every 2 epochs; the wslc VM at 40 GB for the run | 1776 steps, 2 h 14 min, 4.54 s per step, average loss 0.0636 | 14 s per picture |
| FLUX.2 klein 4B | musubi-tuner `flux_2`, trained on the BASE model (`klein-base-4b`, bf16, about 8 GB, no fp8), rank 32 alpha 32, `adamw` at 1e-4, 12 epochs, repeats 4 | 1776 steps, 03:38 to 04:15 (1.21 s per step, four times faster than Qwen), loss about 0.47 (another loss scale) | 3 to 5 s per picture (the distilled model, 4 steps) |
| SDXL (RealVisXL V5.0) | kohya sd-scripts, U-Net only, rank 32 alpha 16, `AdamW` at 1e-4 with a cosine schedule and 50 warm-up steps, bf16, `--no_half_vae` (the fp16 SDXL VAE gives NaNs), `--max_token_length 225` for the long captions, 10 epochs | 1480 steps, 23 min 10 s (1.06 steps per second), average loss 0.112 | 9 s per picture |
| FLUX.2 klein 9B | the same script as the 4B with `FLUX2_SIZE=9b`, text encoder `qwen_3_8b`, `--shm-size 8G` | 1776 steps, 3 h 36 min 24 s (7.32 s per step), average loss 0.444 | 111 s per picture (see §42) |

**What the sheets showed.**
- *Qwen:* one face in all scenes and strengths, costume stable, strong emotions. Compared with the reference the face is
  older, harder and more angular (thinner cheeks, stronger jaw and brows), most at 1.0; 0.6 is closest. The sitting pose of
  the training set leaks into portrait, laugh and angry even when "standing" is asked. Full-body castle and campfire are fine.
- *FLUX.2 klein 4B:* the face is CLOSER to the reference than Qwen's (younger, softer, rounder); 0.6, 0.8 and 1.0 differ
  little; emotions are clear; less pose leak (only the portrait sits with forearms on knees); the campfire hair turns a
  little blue in the dark. Without the LoRA (strength 0.0, a separate test) the model draws thin tied-back hair, crossed
  straps and another face; with it, long loose silver hair, the tunic of the dataset, bracers and the reference face. So
  the LoRA does load and work (the first check, a log grep for "lora key not loaded", printed nothing because ComfyUI's log
  had no lora lines at all).
- *SDXL:* young face close to the reference (soft, light brows), strong emotions; but at 0.8 and 1.0 EXTRA PEOPLE appear
  (a man walking in "angry" at 0.8, a dark-haired second woman at 1.0, two copies of her at the campfire at 1.0, a man behind
  her at 0.8), yellow strands in the hair, and the castle shot is not a walking full body. 0.6 is the cleanest.
- *FLUX.2 klein 9B:* the face is close to the reference in all 5 scenes and all 3 strengths, expressions work (laugh, angry),
  differences between 0.6 and 1.0 are small; one small extra person far away in the castle background.

**Failures on the way, and the fixes.**
- *The first SDXL training failed* because the virtual environment of sd-scripts had no `accelerate` launcher
  (`bin/accelerate`); the script now calls `python -m accelerate.commands.launch`. Before that the set-up itself had failed
  (the environment had no system packages, so no torch); it needs `--system-site-packages`.
- *The first 9B training crashed at step 3* with "unable to allocate shared memory (shm) … No space left on device": the
  data-loader workers use `/dev/shm`, which is small in a one-off container. The container then HUNG for 57 minutes without
  exiting. **Fix: `--shm-size 8G` on `wslc run`**; the chain also restarts the VM at 40 GB and back to 20 GB afterwards. The
  second run was clean (started 10:54, finished 14:33).
- *The first 9B download got 403:* the two gated model files need the operator to accept the licence on the model page.
  After that they answered 206 and the download resumed with `curl -C -`.
- *Licences:* FLUX.2 klein 4B is Apache-2.0 and its LoRA could be released; klein 9B is under the FLUX Non-Commercial License,
  which allows derivatives only for non-commercial purposes with a copy of the licence, the attribution notice and a
  "modified" statement, and never under Apache-2.0. A release of the 9B LoRA therefore needs its own notice files and the
  operator's confirmation that the series is non-commercial; it was not released.
- *Release:* the Qwen LoRA (590153672 bytes) and the 4B LoRA (184842024 bytes) were released on the public repository's
  release page after the operator saw the exact text and files; the digests GitHub shows equal the local sha256.
  Both were accepted by the operator on 2026-11-12 08:25.

## 38. Caption rules v4 and v5, and repeats balanced by subfolder (2026-11-12)

**Rule v4** (49 pictures: the 37 of v3 plus 12 new full-body pictures with emotions and views). The operator had read that
what is well described in a caption is not baked into the LoRA and so stays changeable, and asked that the hairstyle, the
clothes and the background be described. So the trigger plus "a young woman" carry the IDENTITY only; there are NO face words
any more (eyes, brows, cheekbones, skin), and everything that must stay changeable is written out per picture: hairstyle,
every piece of clothing, background and light, expression, framing and view. The v3 captions had carried "high cheekbones,
thin dark eyebrows, about twenty-five" and Qwen had drawn an older, harder face.

**Rule v5, after two consultants** (two other vendors' models, asked through the question consultant; the operator wanted
her "beautiful, a bit sexy, adult, about twenty to twenty-five, the body moderately toned"). Both said: no beauty, sexy or
face words in the training captions (add them at inference); avoid "young face", "big eyes" and "soft cheeks" (they draw a
child); front-load the framing and pose ("medium shot, sitting with her forearms on her knees") so the sitting pose is a
caption and not part of the trigger; put the golden strand next to the hair; balance repeats by subfolder. They differed on
the class word: one said "an adult woman in her early twenties" in every caption, the other only "a woman". The choice:
**trigger + "an adult woman in her early twenties"** (an adult anchor, the operator's explicit age wish), and NO body or
beauty words, because the pictures carry her look and her toned body, so the trigger learns them. At inference one adds, when
wanted, "beautiful, subtle allure, confident gaze, a slim moderately athletic build with toned arms". Caption order: trigger and
class, framing, pose, view, expression and gaze, hair, clothing from top to bottom, place and light, medium.

**Repeats by subfolder.** The v4 set had 26 sitting pictures against 12 standing full-body pictures, so the sitting set
outweighed the full-body set (about 5 to 1, by the comment of the v5 script). `lora_datasets_toml.sh` writes the dataset blocks of the trainer file: if the data
folder has subfolders named `r<N>_<name>`, one block per subfolder with `num_repeats = N` (musubi: its own cache folder per
subfolder; kohya: one subset per folder); otherwise one block with 4 repeats, as before. Dataset v5 = `r2_gemini` (26 × 2),
`r2_picks` (11 × 2) and `r5_full` (12 × 5), 134 steps per epoch. The Qwen and SDXL trainers use the helper; the FLUX.2
trainer was left on the old block while its 9B run was reading the file. v5 is trained FROM SCRATCH on every model, not
continued from v3 (the operator's order of 2026-11-12 14:08); the base model for v5 is chosen after the operator has seen all
360-degree videos (§39). Dataset v6 = v5 plus 18 more pictures the operator added the same evening (15 for the gaps: studio
heads, other outfits, hairstyles, light, angles, places; 3 back views), with a third repeat block `r3_new`, 138 samples per
epoch. Other people in the background of a training picture are written into its caption so that they are not baked into the
trigger.

**Ten prompts to judge each LoRA.** `adherence_prompts.py` holds ten fixed prompts, each testing one difficulty (an outfit
change, a hairstyle change, place and light, expression, a prop in the hand, camera angle, two people, full body, …), 2
seeds each, with a check list per prompt scored one point per item, plus face likeness and seconds per picture; it is
written, not run, because it waits until all LoRAs exist.

## 39. The 360-degree orbit video: two Wan halves, first-last frame, and the joint (2026-11-11/12)

**The request:** a 10-second video in which she stands and moves lightly while the camera turns 360 degrees around her, to
judge the quality of a LoRA. Done with the Wan 2.2 14B image-to-video model in TWO halves of 81 frames at 16 fps (5 s each, a
half circle each), then FILM interpolation to 32 fps and a concatenation.

**What the first versions showed.**
- The camera does not orbit: she spins in place and the background stays; all angles are seen anyway.
- Half 1 (front to back) was good. Half 2, started from a back view as an ordinary image-to-video clip, brought the face back
  as ANOTHER, rounder face, changed the tunic (front lacing, buttons) and lost the golden strand.
- **Fix: half 2 as first-last frame** (`WanFirstLastFrameToVideo` with the start picture as the last frame, a core node of
  our ComfyUI): after the back view the face returns as the face of the start picture, the tunic stays the same; the circle
  closes on it. This worked for the realistic version and the painted one.

**The same check on every LoRA.** `all360.py` makes a start picture per model (4 seeds, the operator picks), then the two
halves. Start pictures picked: Qwen c1, FLUX.2 4B c4, SDXL c2, FLUX.2 9B c3. Strengths: Qwen 0.6, FLUX.2 4B 0.8, SDXL 0.6,
FLUX.2 9B 0.8. Results by eye on 2 fps and 1 fps frame sheets:
- *Qwen:* the first version came out well (the operator). Its v2v half 2 (below) took 465.7 s for 89 frames.
- *FLUX.2 9B:* a full orbit including the back view that closes on the face (the best); later "a turn of 180 degrees and back,
  not 360" (half 2 reversed the camera).
- *SDXL:* a full orbit; the start is a close-up; "she twisted her neck" (head to the camera while the body faces away, at
  about 8 s).
- *FLUX.2 4B:* she never shows her back, she looks over her shoulder, so it is not a full 360.

**Rerolls and the joint.** Half 2 was redone with extra positive words (the camera keeps the direction of the first half,
passes her other side; head, shoulders and body turn together) and new seeds. By eye: FLUX.2 9B steady in both rerolls; SDXL
c back held 5.5 to 8 s then the face (acceptable), SDXL b back, face, back, face (not steady); FLUX.2 4B half 1 now reaches the
back, but half 2 reaches the face at about 7 s and spins once more at about 8.5 s (not steady). One 4B take was rejected by
the operator because the body twisted 180 degrees. A 4B take was trimmed to frames 0 to 238 of 320 (7.47 s), cut before the
second turn. A second kind of fault was at the JOINT of the halves: "a small problem at the joint", and "her face turns into
the back of her head".

**v2v: half 2 sees the last frames of half 1.** `WanFirstLastFrameToVideo` and `WanImageToVideo` take an image BATCH as the
start image, so no new model was needed. Half 2 is run again with `start_image` = the last 9 frames of half 1 (a count of the
form 4k+1: 9 frames are 3 latent frames), `end_image` = the start picture, length 89 (9 context + 80 new frames); the first 9
output frames repeat half 1 and are cut at the join. A separate agent checked the joint by images: it is CONTINUOUS (the 9
context frames are reproduced, PSNR 27 to 37 dB against 22 to 26 dB for a normal step between frames; no colour jump). Frame
counts add up: FILM of half 1 = 161 frames, FILM of half 2 = 177, joined = 161 + 177 − 17 = 321.

**The arm-drop finding.** What the operator saw was a different fault: the arms drop from wide-out to her sides in about 0.35 s
right AFTER the joint (joined frames about 164 to 176), because half 2 has to END on the start picture, which has her arms
down. The first-last-frame version (one frame of half 1) has no arm jump but its trim removed 2 FILM frames where 1 is
right (one double step). Fix agreed with the operator: **17 context frames** (about 1 s of motion, `ORBIT_CTX=17`, length
97, the join cuts 2 × CTX − 1 = 33 FILM frames) plus a phrase in the half-2 text: "Her arms stay held out to her sides as the
camera circles, and lower slowly only near the end"; the first-last-frame version re-cut with a trim of 1 (321 frames each,
no GPU). The run took about 11 minutes per video for SDXL and FLUX.2 9B. By eye at 2 fps all six final videos are one steady
circle; the arms stay held out through half 2 and lower only at about 9 to 9.5 s; no second spin; SDXL ends in a close-up
(its start picture is a close-up). A joint cannot be judged from stills; the operator watches.

**A painted version** with the painted LoRA: keys from the realistic scene looked like photographs; pasting a reference head
into the paint step gave a giant head (rejected); style words only (one reference picture) gave the painted look; two
references copied the scene of the reference. A face repaint with a reference at 0.75 changed almost nothing, at 0.9 gave a
flat cartoon face, so the pick was used as it was; little dancing, very saturated colours.

**Two script bugs of the batch.** (1) The orbit batch made only the first model and then wrote its "done" line: `pwsh.exe`
inside a `while read` loop read the rest of the picks file from the loop's standard input; the fix reads the list on another
file descriptor. (2) The output folders are owned by root (made by the container), so the host could not write the picks
file there; the pick is passed as an argument and copied inside the container, and the compare lists live next to the scripts.

## 40. Steady light: the motion texts asked for flicker (2026-11-12)

**The request:** a realistic episode 3 with all four LoRAs, because the operator could not decide between them; the motion
was good, but "the light flickers strongly".

**The cause was our own text.** The motion texts of the painted episode 3 asked for flicker: "torchlight flickers", "the
crystal pulses", "a burst of light flashes", "violet lightning flickers", "the fire flickers", "red light blinking". Wan did
exactly that. `ep3_real.py` therefore describes every light as steady, calm and even, with positive words only; has one light
per act in the keyframes; and the clip style says "steady even exposure, the same light throughout". The hero text no longer
has "soft young face" (the operator wants an adult face of about twenty to twenty-five). Shots without her use the same base
model at LoRA strength 0, so each version has one look.

**The deflicker measurement.** A post filter (ffmpeg `deflicker`) was tried on three clips (shots 14, 18 and 20) side by side
with the originals. The global brightness steps between frames are already small (mean 0.25 to 0.34, maximum about 1.2 of
255), and the filter changes little. So the flicker is LOCAL (fire and torch light on part of the picture), and the fix is the
prompt, not a global post filter.

**Keyframes and picks.** 23 shots, 2 candidates each, one sheet per model (FLUX.2 9B, Qwen, FLUX.2 4B, SDXL); no clips until the
operator picks. The estimate given was 11 to 12 hours of GPU for all four models (13 to 14 with rerolls). The operator picked
the FLUX.2 9B keys, candidate 1 for all 23 shots (shot 5 has a small second dragon, shot 10 she floats a little low; both
accepted), and ordered the film with them; the clips are queued behind a short test of ComfyUI's built-in LoRA training node (`TrainLoraNode` on FLUX.2 klein base 4B, rank 16, learning rate 1e-4, 100 steps, then `SaveLoRA` and a loss graph).

**ComfyUI's own LoRA training on the R9700** (2026-11-13, `comfy_train_test.py`, all core nodes:
`LoadImageTextDataSetFromFolder` → `ImageScale` 768 × 768 → `MakeTrainingDataset` → `TrainLoraNode` → `SaveLoRA` +
`LossGraphNode`, the v5 dataset of 49 pictures, batch 1, bf16, gradient checkpointing). It works with no error and saves a
49 MB LoRA, but **100 steps took 1817 s, 17.5 s per step**: about 14 times slower than musubi-tuner on the same base model
(1.21 s per step, §37). 1200 steps would take about 6 hours. The loss graph is only a temporary preview. Verdict: the scripts
stay the trainers; the UI workflow `9_train_lora_in_comfyui` is for small experiments (a few hundred steps), and its note
gives these numbers. The cause of the slowness was not looked into (the server log kept only the progress lines).

## 41. Two more base models: HiDream-I1 Full and HunyuanImage 2.1 (2026-11-12)

**What was set up.** HiDream-I1 Full (17B, MIT licence, files from the open `Comfy-Org/HiDream` repository: fp16 34.2 GB, fp8
17.1 GB, clip_g, clip_l, Llama 3.1 8B fp8, t5xxl fp8, the Flux.1 VAE) and HunyuanImage 2.1 (Tencent licence that excludes the
EU, the UK and South Korea, so the operator confirmed first that they are outside that territory; bf16 34.9 GB, fp8 17.4 GB,
byt5, VAE; the Qwen 2.5 VL 7B encoder was already present). ComfyUI has `QuadrupleCLIPLoader` (HiDream) and
`EmptyHunyuanImageLatent` with the `hunyuan_image` clip type. For training: musubi has neither model; ai-toolkit has HiDream;
diffusion-pipe has both (DeepSpeed is a hard requirement; ROCm on WSL was not checked, and its set-up script was run by the
operator after an automatic safety check stopped the agent's own start).

**Base tests** (the same 5 scenes and seeds as the LoRA sheets, no LoRA): HiDream settings from the official example (50
steps, cfg 5, `uni_pc`, `simple`, shift 3): 397.6 s for the first picture, about 6.6 min per picture, and **it hangs**: the
second test left the "castle" prompt unfinished after 1800 s (3 of 5 pictures: portrait, laugh, angry; castle and campfire
missing), the second time such a hang was seen, with no error in the filtered log. The operator judged the portrait
"something new, a very interesting picture": a very sharp photo look, not her face (no LoRA), pointed ears, slightly heavy
make-up. HunyuanImage 2.1 (fp8, 2K latent 2048 × 1152 because 1K gives faults, 20 steps, cfg 3.5): 5 of 5, about 33 s per 2K
picture, but pale grey-blue plastic skin, big eyes and a wide childlike face.

**Tuning Hunyuan.** Five variants (the old prompt against a new long photo prompt without "pale skin"; 20, 30 and 50 steps;
cfg 3.5 and 5; shift 3 and 5): the new prompt ("an adult woman in her early twenties", silver hair, no "young") gave a woman
of 40 to 50 with wrinkles in all four variants, because **Hunyuan reads silver hair as old age**; the old prompt at 50 steps
was young but doll-like. A second round (a young woman of about twenty-two with dyed platinum hair and youthful skin; the old
look without "pale skin"; the first at cfg 5) was queued behind the episode 3 keys. The operator's verdict on the first sheet: it
exaggerates everything, which is interesting and ideal for caricatures. **Round 2 result** (2026-11-13 00:42, about 81 s per
2K picture at 50 steps, `tune_hunyuan21_r2.jpg`): the "Gollum" face and the age of 40 to 50 are gone in all three new
variants. The old look without "pale skin" (v7, cfg 3.5) gives the most natural adult face; the dyed-platinum variant (v6,
v8) reads as a teenager. Expressions stay strong (the angry face is a grimace), so the caricature verdict still holds. No ComfyUI workflow template for HunyuanImage 2.1
existed in the templates repository at that time. A refiner was not downloaded.

**Language models for the encoders.** HiDream training needs Llama 3.1 8B Instruct in Hugging Face format (the Meta repository
is gated, so the open `unsloth` copy of the same weights, 16.1 GB, was chosen) and the diffusers format of HiDream-I1-Full
(about 47 GB); Hunyuan training uses the ComfyUI files. A first HiDream LoRA script exists (`lora_train_hidream.sh`: diffusion-pipe,
rank 16, `adamw_optimi` at 1e-4 on the advice of two consultants, 1024 buckets because HiDream degrades under 1024, Llama in
bf16 because the 4-bit loader needs bitsandbytes which is CUDA only, fp8 transformer, `blocks_to_swap` 12, `--shm-size 8G`);
its smoke test was not yet run when this was written.

## 42. The VM page cache: why a new picture took 100 seconds (2026-11-12/13)

The FLUX.2 9B keyframes of episode 3 ran about **100 s per picture** while the same model made the 360-degree start pictures
in about 5 s. The cause is memory: the 9B transformer (17.3 GB) and its text encoder, Qwen3 8B (15.6 GB), together do not fit
the 20 GB page cache of the wslc VM, so every picture with a NEW prompt re-reads both files from disk (about 100 s); when the text
is the same, the encoder output is cached and only the transformer is needed (5 s). In the same way the 9B test pictures of the LoRA took 111 s
each (§37). At first the NAS copy that ran at the same time was suspected and the save of the
vLLM image was stopped; the page cache is the explanation, not the NAS copy. The same limit explains the rule of §29 (one big model per server
session).

## 43. Backing up to the NAS: root-only files, a path bug in the verification, and the weights master (2026-11-11/12)

**The rule:** the NAS folder for model weights is the MASTER copy, the wslc volume `comfy-models` is the local working copy
(loading 20 GB over the network at every start would be slow). From 2026-11-11 the weights were downloaded straight into the
volume, so on 2026-11-12 85 files (293.9 GB) were only in the volume. A chain copies every volume file that is missing on the
NAS (or has another size) through `<name>.part` and a rename, then compares the sha256 of the volume file and of the NAS copy;
it never deletes. Result: 85 of 85 correct by sha256. The two container images were saved as tar files with a sha256 file
(the ComfyUI image 26 GB; the vLLM image was stopped part-way, see §42; an empty `.part` on the NAS that a process still locked
was left to be removed later).

**The picture and LoRA backup.** The NAS mirror had 16 GB of the 32 GB of the output folder. `rsync -rt --no-perms` with no
`--delete` (the backup only adds and updates, never deletes on the NAS), excluding `secrets/` and `__pycache__`, at the lowest
CPU and disk priority, then a sha256 check of every copied file inside the NAS folder. Three lessons:
1. **Root-only files.** The output folders are written by containers running as root. rsync as a normal user exited 23 with
   35 "Permission denied" files (LoRA checkpoints in `lora/out`), and an earlier whole-folder copy had missed 1429 files
   (7 GB), among them 28 root-only ones (latents and so on). A one-off container (root) copies those files to the NAS folder
   (or `chmod a+r` first in a container), then the same sha256 check runs for all of them.
2. **A verification that hashed nothing.** The first check read the file list with relative paths from the wrong folder: it
   said it had hashed 0 files and still ended "done". A verification must report how many files it checked and fail when that
   number is not the number it was asked to check; the repaired run hashed all 1621 copied files, 1620 correct and 1 different —
   a contact sheet that had been re-made after the copy, as expected.
3. **A secret that had travelled.** An earlier whole-folder copy had put a copy of a read token (37 bytes) from the `secrets`
   folder onto the NAS. It was found by listing, deleted at the operator's request, and no other token file was found under
   depth 4 of that drive; the backup now excludes `secrets/`, and the token should be revoked at its source because it had been
   typed into a chat. The `secrets` folder is only ever mounted read-only into a download container.

## 44. Chains that wait on a marker: old lines, `pgrep -f`, and a "done" that was not (2026-11-11/12)

The nights ran as chains of shell scripts, each waiting for the line a previous chain writes ("… DONE"). Five failures, each of
which wasted hours or stopped a job:
1. **A marker that matches an old line.** A chain waited on `^NEWBASE DONE` with `grep`, but the log already had that line from
   18:24; it started at 20:05 and its first act (restart ComfyUI) stopped the server in the middle of the HiDream base test
   (one picture done, the other four failed with "connection refused"). Fix: wait for the n-th occurrence (count the lines
   before the wait), or give every run its own marker, and never anchor on a log that survives the run.
2. **A marker that is written before the job ends.** A chain skipped two models because it saw "DL FAILED" from before a rename
   of the marker; another printed "POST DONE" after a traceback; a third ended "EP2 V6 DONE" although its edit had failed
   because the host could not write into a folder owned by root and the error text was not logged. A "done" line is written
   only when the last step has produced its file, and a step's standard error goes to the log.
3. **`pgrep -f <name>` matches its own launcher.** A chain that waited with `pgrep -f run_klein9b_download.sh` matched the
   `bash -c` line that had started it and waited one hour; the same mistake had been made at 00:10 with another script name
   and in a third chain. **Never `pgrep -f` a name that appears in the command line that launched the waiter**: write a pid
   file (`$!`) and test `kill -0`. Also, `pkill -f "bash …/script.sh"` inside a script can kill its own shell.
4. **`pwsh.exe` reads standard input.** In a `while read … done < file` loop the call to `pwsh.exe` swallowed the rest of the
   file (§39). Read the list on another file descriptor.
5. **The wslc session got stuck** (2026-11-11 01:55 to 08:42): a memory change that restarts the VM (`wslc system session
   terminate`) hung while an edit container started during the stop; afterwards every `wslc` command answered
   `ERROR_INVALID_STATE` ("The group or resource is not in the correct state"). Waiting, killing the hung client and terminating
   again did not help; only the operator's restart of the session (or the PC) did. Rule: never start a container while a
   memory restart is running, put a timeout on the terminate (300 s), and write the "done" line only when the file exists.
   One further smaller trap: a memory limit set in the settings file applies only to a NEW session.
