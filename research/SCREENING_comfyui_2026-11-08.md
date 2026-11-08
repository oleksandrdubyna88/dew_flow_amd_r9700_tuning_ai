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
