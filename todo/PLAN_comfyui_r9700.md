# PLAN — ComfyUI on the R9700 in a wslc container, as verbs of this toolkit, with a measured tuning series

> Status: **epoch 2 approved 2026-11-08** (by reviewers, after the stop at entry 1.2 and the whole-plan re-review; the record
> under *Plan changes*). E1 is DONE except its
> three acceptance runs on the card (PR #18, squash-merged as 6be7a67: the fields, the adapter calls, `comfy
> build|start|stop|status|fetch`, the owner check in `supervise` and `step_run`). E2 has its stories document only
> rewritten for epoch 2 (d3bee61); its cornerstone spec E2.S2 is Fable's next. E3 is not started.
> Scope: a new `comfyui/` folder (the image recipe and the programs that run inside it), a `comfy` verb of
> `bin/r9700`, new optional fields of `machine.env`, new adapter calls, their tests and documents, and the GPU acceptance
> runs that measure ComfyUI arms on the R9700.

## Plan changes

> Epoch 1 · approved 2026-11-07 · by reviewers · state: closed

  (The approving round's seven findings, all accepted, are folded into the approved text; they are not entries.)

- 1.1 · 2026-11-07 · reviewer · contract — two fetches could share a part file; fetch takes a lock of its own
  (not the GPU lock), so a fetch still runs beside a series; E1 plan round, codex.
  (Same round, not counted, each only satisfying the plan as written: build passes the owner check before its GPU check
  container, which the one-owner rule already required; image retention fills the growth section planning-docs requires.)
- 1.2 · 2026-11-08 · agent · contract — `bench` cannot be refused before the lock: the toolkit's order is lock, restore,
  config (bin/r9700:7-9) and COMFY_CONTAINER comes from the config; the refusal moves to supervise's owner check (E1),
  so a held lock with ComfyUI listed gives exit 4, not 2; E2 stories open point OP2, consultant 4d95f354.
  (This second change stopped the plan.)

### Re-review for epoch 2

Narrowed: no — the goal, the Definition of Done and the three epics stand; the revision settles the eight open points of the E2 stories and takes in what the card taught on 2026-11-07/08 (a valid video workload, one arm replaced by the one that can act, the arm evidence split into activation and inertness, a lost run expected); nothing got smaller

| Work | Where | Verdict | Action |
|---|---|---|---|
| E1 — the fields, the adapter calls, `comfy build\|start\|stop\|status\|fetch`, the owner check in `supervise` and `step_run`; PR #18, 6be7a67 | main | fits | kept; the revised text names `supervise`'s owner check as the bench's refusal (entry 1.2) and E1's three acceptance runs stay owed |
| E2 stories document, 8814640 | pushed, unmerged (feat/comfyui-e2) | cut | fix forward, no revert: Opus rewrites it on feat/comfyui-e2 before E2's first code, because its text contradicts the revised plan (the epoch-1 arm `fp8mm`, `PLAN_comfyui_r9700_E2.md:412`; the 20-step `uni_pc` `wan5b`, `:149`, as the time basis, `:547`; OP1–OP8 still open, `:847-891`; the parent's epoch-1 line numbers); its split into S1–S3 and its cornerstone E2.S2 are kept |
| the stop commit 3bbbef2 (entry 1.2 and the status) | pushed, unmerged (feat/comfyui-e2) | fits | kept |

  (The Opus judge of plan-change-control step 5, 2026-11-08, confirmed rows 1 and 3 and corrected row 2 from `fits` to `cut`:
  a pushed document whose text contradicts the revised plan is cut and fixed forward, never reverted. Nothing in the revision
  below is a ledger entry: it is the baseline epoch 2 is approved on.)

> Epoch 2 · approved 2026-11-08 · by reviewers · state: open

  (The approving round, coai, two reviewers, verdict proceed: its six findings, all accepted, are folded into the text;
  they are not entries.)

## Goal

The operator runs vLLM on the R9700 through this toolkit's machine (Windows + WSL2, containers through `wslc`). They now
want ComfyUI on the same card — images, video and voice-over for series — **one at a time with vLLM, never both** (the
owner, 2026-11-07), and they want it TUNED for the R9700 the way vLLM was, with the result reusable on another PC from this
repository alone.

Before E1, ComfyUI ran on this PC from a hand-made folder outside any repository (built and checked 2026-11-07, below). The
symptom this plan removes: nothing of it is reusable, nothing is tested, the machine's paths are written into its scripts, and
the speed options it uses were taken from a vendor guide — one of which breaks the GPU here — rather than measured. E1 removed
the first three for the image, the model sets and the five modes; E2 and E3 remove the last one, for the two workloads the
operator actually renders with (a valid output, not a known-flawed one).

What must be true when it is done:

1. `bin/r9700 comfy build` makes the image from `comfyui/` on any PC this toolkit's `machine.env` describes; `comfy start` /
   `comfy stop` run the operator's ComfyUI; `comfy fetch <set>` puts a named model set where ComfyUI reads it, every file
   checked against the sha256 pinned in `comfyui/models.conf` (read once from what the source publishes). (E1, merged.)
2. `bin/r9700 comfy bench` measures ComfyUI arms (server flags, environment, and how the model is loaded or wrapped) under the
   same supervisor as every other GPU verb — one lock, the operator's vLLM stopped once and restored once, the guards — and
   records each arm-round only when it is complete; `bin/r9700 verdict` gives the ship test over those records for speed.
3. One acceptance series per workload (an image model and a video model) has run on the R9700, and its record says which
   arms are faster than the base by more than the base's own spread, with the conditions it was measured under.
4. No personal path, account name or machine name is in a tracked file; every machine value is a `machine.env` field.

## What exists today (observed 2026-11-07, not from memory)

Measured on this PC by hand, outside the repository, in `wslc` containers. Each line is an observation:

- **The GPU under `wslc run --gpus all`** is `/dev/dxg` plus `/usr/lib/wsl/lib` (`libdxcore.so`, `libd3d12*.so`); there is
  no `/dev/kfd`. An image reaches the card only if it carries `librocdxg` for its own ROCm. Both ROCm 10.1 images on this PC
  carry it: `rocm/vllm:rocm10.1.0_ubuntu24.04_py3.14-pytorch_2.13.0_vllm-0.29.0` and
  `rocm/pytorch:rocm10.1.0_ubuntu24.04_py3.12_pytorch_release_2.13.0` (`_rocm_sdk_devel/lib/librocdxg.so.1`).
  In both, `torch.cuda.is_available()` is True, the device is `AMD Radeon AI PRO R9700`, and a 2048² fp16 matmul runs.
- **AMD's own `rocm/comfyui` image is not usable here**: its newest tags (2026-05-05) are ROCm 7.2.0 / 7.1.0, it lists
  Instinct MI300X/MI325X/MI355X only, and ROCm before 7.13 needs `HSA_ENABLE_DXG_DETECTION=1` plus a host `librocdxg`,
  which `wslc` does not provide. Community RDNA4 images are written for `/dev/kfd`. Checked: Docker Hub tag lists of
  `rocm/comfyui`, `rocm/pytorch`, `rocm/vllm`; the ROCm ComfyUI install page; the `ROCm/librocdxg` README.
- **The base**: `rocm/pytorch` 10.1 with Python 3.12 (ComfyUI recommends 3.13, accepts 3.12; 3.14 breaks some custom
  nodes). It has `torch 2.13.0+rocm10.1.0`, `torchvision 0.28.0`, `torchaudio 2.11.0.2`, `triton 3.8.0`, and no `python`
  (only `python3`), no `git`, no `ffmpeg`.
- **ComfyUI v0.44.0** (released 2026-11-04) with its built-in Manager (`comfyui_manager==4.2.2`, `--enable-manager`)
  installs from its two requirement files with the base's ROCm packages as pip constraints, and the torch stays
  `2.13.0+rocm10.1.0`. A dry-run torch downgrade is refused (`ResolutionImpossible`).
- **Three traps, each seen and fixed** (E1 keeps the fixes: `research/module_comfyui.md` § *The three traps*, with the test
  IM1 that fails when a code line of the image names trap 1's variable):
  1. `PYTORCH_HIP_ALLOC_CONF=expandable_segments:True` — recommended by AMD's RX 9000 ComfyUI guide — makes the first GPU
     allocation fail under `wslc`/dxg (`hipErrorInvalidValue` on `torch.zeros(..., device="cuda")`), and ComfyUI then
     disables flash attention. Without it, SDPA flash and efficient attention both run on gfx1201, with or without
     `TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1`, and ComfyUI logs `Using pytorch attention`.
  2. The Manager defaults to `use_uv = True`; `uv pip list` inside a `--system-site-packages` venv lists only the venv, so the
     Manager reports `PyTorch is not installed` and re-installs the image's packages into the venv, where they would shadow
     a newer image after a rebuild. Forcing `use_uv = False` at every start removed both.
  3. `PIP_USER=1` (to keep node packages in a volume) has the same effect through `pip list --user`; a venv with
     `--system-site-packages` on the data volume is what works.
- **It generates**: SD 1.5 fp16, 512×512, 20 steps, euler: run 1 9.51 s (load and kernel compile), runs 2–3 2.05 s and
  2.24 s including the VAE; the image is correct. One run each, no arm comparison: this is a smoke result, not a speed
  claim.
- **The comfy-kitchen HIP backend** offers `int8_linear`, `dequantize_per_tensor_fp8`, `fp16_linear`, `convrot_w4a4_linear`,
  `gemv_awq_w4a16`; `nvfp4` and `mxfp8` are served only by the Triton or eager backends (dequantised, not native). So a model
  set for this card prefers bf16/fp16, int8 or fp8 weights and avoids nvfp4/mxfp8 ones (the owner asked for R9700-native
  choices, 2026-11-07).
- The hand-made folder keeps models in the volume `comfy-models`, with a master copy first on the operator's NAS share
  (the owner, 2026-11-07: download there first). Its download script resumes and checks each file's sha256 against the
  `X-Linked-ETag` header of Hugging Face before and after copying.

## What the card taught after the approval (hand runs, 2026-11-07/08)

Observed on the R9700 with the hand-made setup (the same image family, ComfyUI v0.44.0, torch 2.13.0+rocm10.1.0), one run or
one sweep each, outside the repository: prior observations that inform the plan, never a verdict. Each line says what it
changes below.

1. **Wan 2.2 TI2V 5B at 20 `uni_pc` steps leaves a diagonal hatching ("a mesh") in every frame.** It is in a lossless PNG of
   a decoded frame (not the codec), unchanged with `--fp32-vae`, with other tile sizes and with `--bf16-unet`, and the start
   keyframe is clean: incomplete denoising, not the decode. The model's official setting is 50 steps, shift 5, cfg 5, which
   removes it (a 2×2 checkerboard measure over 13 frames: 3.45 at 20 steps, 1.61 at 50, 2.53 for the keyframe) at about
   700 s per clip. The FastWan step-distillation LoRA (3 steps, `lcm`, cfg 1, shift 8) gives a clean clip (2.32, sharper by
   eye) in about 122–143 s against about 340 s for 20 steps; a second distillation LoRA (4 steps) gave 128.6 s and 2.62.
   → The `wan5b` workload is no longer 20 `uni_pc` steps (*Workloads*).
2. **The untiled VAE decode of a 121-frame clip stalled for more than 10 minutes**; the tiled decode is required. Two
   settings of `VAEDecodeTiled`, as NAMED fields (the order in `research/module_comfyui.md:106` is ambiguous and E2 corrects it):
   `tile_size 512, overlap 64, temporal_size 32, temporal_overlap 8` (used for every clip that was looked at, about 100 s)
   and `tile_size 512, overlap 32, temporal_size 64, temporal_overlap 4` (about 30 % faster, 70 s; a slight colour shift seen
   by eye, PSNR 24–44 dB per frame against the former). Larger tiles were 2–6 times slower.
   → The tiled decode is a workload constant, not a feasibility decision (*The tuning series*, OP4).
3. **`PYTORCH_HIP_ALLOC_CONF=expandable_segments:True` breaks allocation through `/dev/dxg`** — trap 1 again, and E1's image
   keeps it out (checked: `research/module_comfyui.md:19`, test IM1). → Nothing new; the arm table never sets it.
4. **A long-running server fails later work.** After about 3 h and several large models used in one process, a workflow
   failed with an out-of-memory in the sampler, and another time with a HIP "invalid argument"; a container restart cured
   both. → One fresh container per arm-round is correctness, not only isolation (*The bench's measurement contract*).
5. **With cfg 1 the negative prompt has no effect** (Z-Image Turbo, FastWan). → Both workloads pin an empty negative prompt
   and the record says it is inert.
6. **The host blue-screened under GPU load on 2026-11-02 and 2026-11-07** (the same driver offset). → A series expects a lost
   arm-round and continues the same experiment after a reboot (*The bench's measurement contract*, *Records and growth*).
7. **A screening of the arms on `zimage`** (one round each, one container per arm, the hand-made driver): `fp16acc` within
   noise of the base (inert on bf16 weights); fp8 WEIGHTS alone slower (cast up per layer); fp8 weights + `--fast
   fp8_matrix_mult` −15 % on the sampler with another composition at the same seed; `miopen` the VAE equal warm (cold VAE
   7.8 s); `tunableop` cold run: step 1 took 690 s and the VAE's tuning ran more than 37 minutes and was stopped; `compile`
   about −4 % on the sampler once compiled, with a recompile in two of three warm runs (17.5–18.4 s each). On `wan5b` (20
   steps) fp8 weights + `fp8_matrix_mult` −7 % on the sampler. → The arm table (*The tuning series*): the fp8 arm is the pair,
   `tunableop` is bounded, `compile`'s recompiles are flagged, and the predictions are informed by these numbers.

## Design

### Reuse first (the four questions answered)

| Need | Existing piece | Use |
|---|---|---|
| machine values | `lib/config.sh` field table (`_field`, `lib/config.sh:30`), `config_load` (`:473`) | the twelve `COMFY_*` fields with defaults (E1, `lib/config.sh:67-78`); E2 adds none |
| every `wslc` call | `lib/adapter.sh` (`wslc_run` `:291`, `wslc_exec` `:300`, `wslc_run_once` `:320`, `wslc_list` `:345`, `wslc_stop` `:356`, `wslc_logs` `:369`) | E1 widened it with `wslc_remove`, `wslc_inspect`, `wslc_build` (`:398`), `wslc_tag`, `wslc_rmi`, `wslc_image_list` (`:449`), `wslc_volume_list` (`:457`), `wslc_volume_create` (`:465`) and `comfy_probe`; E2 adds only what its spec needs (a readiness probe that also returns `vram_free` and `vram_total`) — the seam check (`tests/check_static.sh --seam`) keeps every call there |
| copy repository files to where a container can read them | `moe_place` (`lib/moe_verb.sh:35`) with an assets function (`moe_assets`, `lib/moe.sh:94`), hash-checked | `comfy_assets` (`lib/comfy.sh:435`, E1) places the three scripts; E2 places `bench.py` the same way |
| one GPU run with the operator's server stopped and restored | `supervise` (`lib/run_guarded.sh:503`), `step_run` (`lib/step.sh:238`), `cleanup_once` (`lib/run_guarded.sh:661`) | `comfy bench` is `supervise` around ONE `step_run`, exactly like `linear-bench`; the owner check is `supervise`'s (`_rg_card_free`, `lib/run_guarded.sh:43`, `:492`) and `step_run`'s (`lib/step.sh:117`) |
| an arm table | `arms_load` (`lib/config.sh:573`) and the four-field grammar of `config/arms.conf` (`_ARM_LEGAL`, `:545`) | a second table `comfyui/arms.conf` in the SAME grammar: name, ComfyUI arguments, environment, mounts; the arm evidence is a second, separate table keyed by arm name (OP6), so `arms_load` and `config/arms.conf` do not change |
| the ship test | `lib/verdict.py ship` and `bin/r9700 verdict` | the bench writes lines in the verdict grammar `<arm>-<round> <group> r=<n> <metric>: <value>`; `verdict.py` is widened with a comfy mode (metric list, direction, NOT DECIDED inside the spread), the vLLM mode and its tests unchanged |
| the identity of an experiment | `lib/fingerprint.py` (`compare`, `show`, `--merge` are generic) | widened with a build for the comfy identity, not copied |
| what is left of a series after an interruption | `series_left` (`lib/series.sh:55`) and the part sweep to `rejected/` as `INTERRUPTED` (`lib/series.sh:272`) | reused: a re-run of the same experiment continues from the first missing arm-round |
| test doubles | `tests/stubs/wslc`, `tests/run.mjs` | the stub learned `build`, `image list`, `volume list`, `volume create`, `tag`, `rmi` (E1); E2 adds the bench container, the `exec` of `bench.py` with scripted answers and the clear container |
| a model file per model, not a script | `models/*.env` | `comfyui/models.conf`: one model SET per block, lines `<set> <folder> <url> <sha256>` (E1); E2 adds the LoRA line of `wan5b` |
| the worker's file (OP1) | `lib/series.sh` (two faces: sourced and run as the worker) and `lib/kernels_verb.sh` (the verb half apart from the worker) | `lib/comfy.sh` is 747 lines; the bench's worker goes in `lib/comfy_bench.sh` (two faces) and the verb half in `lib/comfy_bench_verb.sh`, which defines `comfy_mode_bench` so `comfy_modes` (`lib/comfy.sh:44`) derives it. A file split for the 800-line limit of coding-style; no behaviour changes |

New code is written only where none of these fits; the summary of each epic names which widening was used.

### The `comfyui/` folder

| File | Role |
|---|---|
| `comfyui/Containerfile` | the image recipe (E1, as merged: `ARG BASE`, `ARG COMFYUI_REF`; `git ffmpeg curl ca-certificates python3.12-venv`; `/opt/rocm-constraints.txt` from the base's ROCm packages; ComfyUI and its Manager installed with those constraints; `PIP_CONSTRAINT`, `UV_CONSTRAINT`, `VIRTUAL_ENV=/data/venv`, the MIOpen and Triton cache paths; `PYTORCH_HIP_ALLOC_CONF` NOT set, with the observation in a comment) |
| `comfyui/entrypoint.sh` | E1, as merged: makes the folders of `/data`, `/models`, `/cache`; makes or keeps the `--system-site-packages` venv on `/data` (another Python minor version's venv moved aside, never deleted); forces the Manager's `use_uv = False`; `exec`s `main.py --listen 0.0.0.0 --port 8188 --base-directory /data --models-directory /models --enable-manager "$@"` |
| `comfyui/fetch_model.sh` | E1, as merged: per file the PINNED sha256 of `models.conf` is the authority; the source's `X-Linked-ETag` is a pre-flight cross-check; a resumable download to the store first when mounted, then a checked copy into `/models` |
| `comfyui/models.conf` | E1, as merged: the sets `sd15`, `zimage` (Z-Image Turbo bf16, `qwen_3_4b` text encoder, `ae` VAE), `wan5b` (Wan 2.2 TI2V 5B fp16, `umt5_xxl_fp8_e4m3fn_scaled`, `wan2.2_vae`), each line `<set> <folder> <url> <sha256>`. **E2 adds one line to `wan5b`**: the FastWan step-distillation LoRA of Wan 2.2 TI2V 5B (the full-attention distillation LoRA, rank 128, bf16, in the `loras` folder), its sha256 read once from the source's `X-Linked-ETag` at that commit and pinned like every other file; `fetch` refuses a source that publishes another hash, and the fingerprint carries the pin |
| `comfyui/bench.py` (E2) | inside the container, the image's `aiohttp` for the transport, `numpy` and `Pillow` for the output check and the drift, the standard library for everything else: queues one workflow on `127.0.0.1:8188`, times every node over the websocket (`executing` events), prints verdict-grammar lines and writes a JSON per run; the workflows `sd15`, `zimage`, `wan5b` with every input pinned (seed, steps, size, sampler, scheduler, cfg, shift, the length and the tiled decode of a video, an empty negative prompt, the LoRA and its strength); per workload a `run_max_s` (a measured run) and a `cold_max_s` (the cold run, larger: an arm may tune or compile in it) — both constants of the fingerprint; the commands `workflows` and `metrics` of the seam import nothing outside the standard library and run on the host |
| `comfyui/arms.conf` (E2) | the ComfyUI arms in the four-field grammar of `config/arms.conf` (names and contents in the series section) |
| `comfyui/arm_evidence.conf` (E2) | one row per arm, keyed by the arm name: what proves the arm was ACTIVE in the arm-round, and what proves it was INERT on a workload (the two are different questions; below) |

### The `machine.env` fields (E1, as merged; all optional, the defaults are what the hand-made setup used)

| Field | Type | Default | Meaning |
|---|---|---|---|
| `COMFY_IMAGE` | image | `comfyui-r9700:local` | the tag `comfy build` writes and every comfy container runs |
| `COMFY_BASE_IMAGE` | image | `rocm/pytorch:rocm10.1.0_ubuntu24.04_py3.12_pytorch_release_2.13.0` | the build's `BASE` |
| `COMFY_REF` | a git tag word (`ref`) | `v0.44.0` | the ComfyUI tag the build clones |
| `COMFY_CONTAINER` | name | `comfyui` | the operator's own ComfyUI container |
| `COMFY_PORT` | int 1024–65535 | `8188` | the Windows loopback port it is published on |
| `COMFY_MODELS_VOLUME`, `COMFY_DATA_VOLUME`, `COMFY_CACHE_VOLUME` | name | `comfy-models`, `comfy-data`, `comfy-cache` | the three volumes |
| `COMFY_OUTPUT_WIN` | `win?` | empty | when set, mounted at `/data/output`, so results appear in Windows |
| `COMFY_STORE_WIN` | `win?` | empty | the master model store `comfy fetch` writes first (a NAS share is fine: `wslc` mounts a mapped drive, observed) |
| `COMFY_BUILD_MAX_S` | int 600–14400 | `5400` | the ceiling of one `wslc build` |
| `COMFY_FETCH_MAX_S` | int 600–86400 | `21600` | the ceiling of one fetch container |

The type `win?` (an optional Windows path, checked like `win` when non-empty) is in the table (`lib/config.sh:28`). E2 adds no
field: the bench's ceilings are workload constants of `bench.py` (above), because they describe the workload, not the machine,
and they must be in the fingerprint.

### The verb `bin/r9700 comfy <mode>`

**One owner of the card at a time, decided under the lock.** The toolkit's lock (`lock_take`, `lib/run_guarded.sh:103`) is
what every GPU verb already takes, so it is what decides between ComfyUI and vLLM work too (E1.S2, the cornerstone of E1,
merged):

- `build` (its check container uses the GPU), `start` and `bench` take the lock; `start` holds it through the launch and
  the readiness wait and releases it once ComfyUI answers, so no check-then-start window is left.
- **Every verb under the supervisor refuses while `COMFY_CONTAINER` is listed** — exit 2, one line naming `bin/r9700 comfy
  stop` (`comfy_owner_check`, `lib/run_guarded.sh:446`) — checked in `supervise` after the lock, the restore-first and the
  prepare and before anything is stopped (`_rg_card_free`, `:43`, `:492`; a refused night run leaves the operator's vLLM as it
  was), and again at every admission (`step_run`, `lib/step.sh:117`), because a long run can outlive the first check: the
  operator's ComfyUI holds the card's memory and a series beside it would measure an out-of-memory. **The check cannot come
  before the lock** (entry 1.2): the order of every verb is lock, restore, config (`bin/r9700:7-9`) and `COMFY_CONTAINER` is a
  config value, so a lock held by another run answers exit 4 before the owner line. No verb ever stops the operator's ComfyUI
  by itself — it may hold a queue or unsaved work — so `comfy start` is a manual workstation mode, and an unattended plan that
  finds it running refuses and says what to run.
- `COMFY_CONTAINER` must not start with `CONTAINER_PREFIX` and must differ from `PROD_CONTAINER` — the same cross-field
  rule as `PROD_CONTAINER`'s (`lib/config.sh:385-404`), because `container_stop_all` (`lib/restore.sh:159`) stops every
  container with the prefix.
- `fetch` uses no GPU and does not take the GPU lock (it takes its own, entry 1.1), so its container is NOT prefixed
  (`<COMFY_CONTAINER>-fetch`): a prefixed one would be stopped by another run's cleanup halfway through a download.

| Mode | Lifecycle | What it does |
|---|---|---|
| `build [--no-cache]` (E1) | the lock (for the check container), no stop | as merged (`research/module_comfyui.md` § *The flows*): places `Containerfile`, `entrypoint.sh` and `fetch_model.sh` (hash-checked) under `$WORK_DIR/r9700/comfyui/`, builds to a STAMPED tag `<repository of COMFY_IMAGE>:<UTC stamp>` with `--build-arg BASE=… --build-arg COMFYUI_REF=…` under `COMFY_BUILD_MAX_S`; one throwaway container (`--gpus all`, `--rm`, prefixed name) must print a ROCm torch, a device and a finite fp16 matmul; only then `COMFY_IMAGE` is pointed at the stamp, and the newest four stamps are kept |
| `start [--stop-vllm] [-- <main.py args>]` (E1) | the lock, held through the launch and the readiness wait | as merged: refused (exit 4) while a toolkit run holds the lock, and refused (exit 2) while `PROD_CONTAINER` is listed unless `--stop-vllm` (then `wslc_stop` of it, marker first, logged); makes missing volumes; removes a stopped `COMFY_CONTAINER`; runs it detached with `--gpus all`, the volumes, the port on loopback, the optional output mount; waits until `GET /system_stats` answers (ceiling `READY_TIMEOUT_S`) and prints the device line. A start that does not become ready saves the container's last 200 log lines, stops it, restores the operator's vLLM when this invocation stopped it, and only then releases the lock: exit 5, one line naming the saved log |
| `stop` (E1) | no lock | `wslc_stop COMFY_CONTAINER`; a container that is not listed is not an error |
| `status` (E1) | no lock | the listed state of `COMFY_CONTAINER` and of `PROD_CONTAINER`, the image's creation time |
| `fetch <set>...` (E1) | its own lock (`<state dir>/comfy-fetch.lock`, not the GPU lock: exit 4 naming the holder when another fetch runs), no GPU | as merged: the set's lines from `comfyui/models.conf` → one throwaway container (`--rm`, the name `<COMFY_CONTAINER>-fetch`, not prefixed, no `--gpus`) running `fetch_model.sh` with `/store` mounted when `COMFY_STORE_WIN` is set; ceiling `COMFY_FETCH_MAX_S`; an unknown set is exit 2 naming the legal ones |
| `bench <workflow> <arm>... [--rounds N] [--out <name>] [--dry-run]` (E2) | `supervise comfy …` around ONE `step_run` | refused by `supervise`'s owner check while `COMFY_CONTAINER` is listed (exit 2, the one owner line, nothing stopped; after the lock, so a held lock is exit 4 first — entry 1.2) and again at `step_run`'s admission; the worker (`lib/comfy_bench.sh`) per round, per arm (alternating, like `series`): a prefixed ComfyUI test container with the arm's arguments and environment and the same volumes, ready-wait and free-card wait, `bench.py` through `wslc_exec` (one cold run, then the measured runs), the images or video kept, the container stopped, validation, ONE rename into `rounds/<arm>-<round>/`; a re-run of the same command continues the same experiment (below) |

`comfy` holds no second lifecycle: its lock, stop, guards, deadline and restore are the supervisor's, and the only server it
restores is the operator's vLLM (`PROD_CONTAINER`), as for every other verb. The operator's ComfyUI is never stopped or
started by a bench.

**The bench's measurement contract** (the consultants' first risk, 2026-11-07, and ComfyUI is not vLLM: it is a queue with an
execution cache and dynamic model offload; the cornerstone of E2):

- **Isolation, and it is correctness.** A bench container gets an EMPTY `/data` (`--tmpfs`, so no custom node, venv or
  Manager state of the operator's reaches a measurement), the models volume read-only, and its own cache volume
  `<CONTAINER_PREFIX>comfy-cache`, cleared before every arm-round (like the MoE cache clear) so every arm-round starts equally
  cold. One fresh container per arm-round: a server that has run for hours with several models fails later work (fact 4), so
  a measured run never follows another arm's models in the same process. Neither `--tmpfs` nor a read-only NAMED volume is
  used anywhere in the toolkit yet (only bind mounts take `:ro`: `lib/series.sh:103`, `lib/comfy.sh:737`). Both were observed
  with `wslc` on 2026-11-08 (OP8, the approving round): `--tmpfs /data:exec,size=8g` mounts a writable tmpfs, and the models
  volume with `:ro` refuses a write ("Read-only file system"). A plain `--tmpfs /data` is mounted `noexec`, and the image's
  entrypoint runs Python from a venv under `/data`, so the `exec` option is required. If a later `wslc` refuses either, the
  fallback (a prefixed empty data volume cleared like the bench cache, or the models volume mounted read-write) changes the
  isolation and is a plan change the owner approves — never a silent substitution.
- **Every ceiling ends the container.** A run past `run_max_s` or `cold_max_s`, the adapter's ceiling and every guard stop end
  the arm-round by stopping its container and checking it is no longer listed, before the next arm-round starts or the
  operator's server is restored; nothing that outlived a ceiling runs beside a measurement (the approving round).
- **A round** is ONE arm-round container: one untimed cold run (model load, kernel compile, TunableOp or MIOpen search,
  bounded by the workload's `cold_max_s`), then three measured runs (each bounded by `run_max_s`) with three seeds that are the
  SAME for every arm. The prompt does not change, so ComfyUI's cache keeps the text encoding after the cold run and the
  measured runs time the sampler and the VAE — the record says so, and it is why an arm that acts only on the text encoder is
  inert here (the fp8 flag alone, below). `total_s` (queue to the history entry) is the metric the verdict decides on; the
  per-node times are diagnostics. A cold run that exceeds `cold_max_s` rejects the arm-round as `COLD_TIMEOUT` with the time
  it reached, and the arm is reported as *not measurable within the cold-run ceiling* — never as slower.
  **Model offload and recompiles are part of the workload, and they are made visible**: ComfyUI may unload the text encoder or
  the DiT between nodes to make room, and a compiled model may recompile in a warm run (fact 7). Every arm runs with ComfyUI's
  default memory mode (pinned, the same for all arms); the server log's model load and unload lines, and the inductor's
  recompile lines, are cut per measured run and kept in the record; a measured run with a load or a recompile in it is flagged
  in `bench.txt`, so a reader sees whether a time includes a transfer or a compile.
- **Failure is fast.** An `execution_error` on the websocket or in `/history` fails the run at once; each run has its own
  ceiling inside `bench.py`; the worker's call has the adapter's.
- **The output is checked**, not trusted: the file exists, its dimensions are the workflow's `width` × `height`, and for a
  video its frame count equals the workflow's `length` (121 for `wan5b`), read by `ffprobe -count_frames` from the image's
  own `ffmpeg` (installed by the Containerfile: the base has none); its pixels are not constant (a NaN becomes a black or
  grey frame that finishes in normal time). A truncated video fixture and a constant image fixture are rejected in the tests.
- **The card is free at the start**: the ready check reads `vram_free` from `/system_stats` and waits (bounded) until it is
  at least 90 % of the total, because the previous container's memory may not be returned the instant it stops; the value
  is recorded.
- **The arm took effect — activation and inertness are two questions** (OP6; security.md: a flag passed is a request, not an
  effect). `comfyui/arm_evidence.conf` names, per arm, the ACTIVATION evidence — what in the arm-round's own record proves the
  option was in effect in this process (a line of ComfyUI's log, a non-empty results file holding the workload's shapes, a node
  in every measured run's node list, the inductor cache written in the cold run) — and the INERTNESS evidence — what proves
  the option could not act on this workload (the weight and compute dtype line ComfyUI logs for the model; a text encoder
  cached since the cold run). An arm-round without its activation evidence is rejected (measurement § 1: read back what was
  actually run); an arm whose inertness evidence is present is reported as *inert on <workload>*, with the evidence, never as
  "no gain". The argv read back from `/system_stats` `system.argv` says only that the flag was PASSED; it is never the
  activation evidence alone.
- **Order is balanced**: odd rounds run the arms in the table's order, even rounds in reverse (the existing series repeats one
  order, `lib/series.sh:475`).
- **A lost run is expected** (fact 6): an arm-round is in `rounds/` only when it is complete; a part left by a kill or a host
  crash is moved to `rejected/` as `INTERRUPTED` at the next worker start (the sweep `series` has, reused); the same `bench`
  command re-run continues the same experiment — the fingerprint admits it, completed arm-rounds are kept, the balanced order
  continues from the first missing arm-round (`series_left`, reused) — and refuses another experiment (a changed image, ref,
  workload constant, arm list, model pin or `bench.py`). The record names every lost arm-round and its cause when known.

### The tuning series

**What an arm is.** An arm changes the server's flags or environment, or how `bench.py` loads or wraps the model (the loader's
weight dtype, a compile node after the loader). An arm never changes the workflow's sampling or decode constants: those are
the workload's identity, and a change there (the faster tiled decode of fact 2) is a different workload, recorded as a
follow-up for the owner, not an arm.

**Arms** (`comfyui/arms.conf`), each one candidate against `base`:

| Arm | Change | Why it is a candidate on this card | Activation evidence | Inertness evidence |
|---|---|---|---|---|
| `base` | ComfyUI's own choice (pytorch attention, cudnn off on AMD) | the reference | the attention line `Using pytorch attention` | — |
| `fp16acc` | `--fast fp16_accumulation` | fp16 matmul accumulation; it acts only on fp16 matmuls | ComfyUI's `Enabled fp16 accumulation` line | the model's compute dtype line AND the VAE's dtype line are bf16 (`zimage`): only then reported inert, as the screening saw (fact 7); an fp16 VAE makes it an acting arm (the approving round) |
| `fp8wmm` | `COMFY_BENCH_WEIGHT_DTYPE=fp8_e4m3fn` (the loader's `weight_dtype`, set by `bench.py`) **and** `--fast fp8_matrix_mult` | RDNA4 has fp8 matrix hardware and ComfyUI sets `SUPPORT_FP8_OPS` for gfx1201; the flag acts only on fp8 WEIGHTS, and the pair measured −15 % (`zimage`) and −7 % (`wan5b`, 20 steps) on the sampler in the screening; fp8 weights alone were slower. It replaces the flag-only arm `fp8mm` of epoch 1: with bf16/fp16 model weights the flag can touch only the fp8 text encoder of `wan5b`, which the measured runs cache after the cold run, so the flag alone is inert in every measured run | the loader's weight dtype line (`float8_e4m3fn`) AND the flag in the argv | — (both DiTs are cast) |
| `tunableop` | `PYTORCH_TUNABLEOP_ENABLED=1`, its results file in the bench cache, and the per-shape tuning bounds of torch's TunableOp (`PYTORCH_TUNABLEOP_MAX_TUNING_DURATION_MS`, `PYTORCH_TUNABLEOP_MAX_TUNING_ITERATIONS`; the values are set in E2's spec from the image's torch documentation) | hipBLASLt GEMM tuning per shape; the cold run tunes, the measured runs read the file. Unbounded, the screening's cold run tuned the VAE for more than 37 minutes (fact 7), so the bounds and `cold_max_s` keep it inside one arm-round or reject it as `COLD_TIMEOUT` | the results file is not empty and holds the workload's shapes (the cold run and the measured runs are one process whose environment is fixed at its start, so no per-run tuning switch exists to read) | — |
| `miopen` | `COMFYUI_ENABLE_MIOPEN=1`, `MIOPEN_FIND_MODE=FAST` | ComfyUI turns cudnn/MIOpen off for every AMD arch after RDNA2; on these two DiT models it can only change the VAE, and FAST keeps the search out of a multi-minute stall (the screening: VAE equal warm, cold VAE 7.8 s) | the absence of ComfyUI's `cudnn.enabled = False` line and MIOpen's find lines in the cold run | the sampler has no convolution: `sampler_s` is reported as information only for this arm |
| `compile` | `COMFY_BENCH_COMPILE=1` and `TORCHINDUCTOR_CACHE_DIR=/cache/inductor` (so the inductor cache the evidence reads is in the bench cache, not the container's `/tmp`): `bench.py` inserts `TorchCompileModel` (inductor, no CUDA graphs) after the loader | the DiTs are full of pointwise chains between their GEMMs; the compile cost lands in the cold run and the record keeps it separately; a recompile in a measured run is flagged (fact 7: two of three warm runs recompiled) | the `TorchCompileModel` node in every measured run's node list AND the inductor cache written in the cold run with `TORCH_LOGS=recompiles` set (a recompile line is the flag above, not activation evidence) (a node's presence proves the wrapper ran, not that the compiled graph did) | — |

`--use-quad-cross-attention` was a planned arm and is dropped (both consultants, 2026-11-07): it replaces the fused SDPA
that now works with a chunked fallback made for cards without one, so it can only be slower, and on the video workload a
slower arm costs hours. Checked: the attention line ComfyUI logs (`Using pytorch attention`), not a timing. Trap 1's variable
is never an arm.

**Workloads** — the two model sets the owner asked for (images and video), with every input pinned in `bench.py` and in the
fingerprint:

- `zimage`: Z-Image Turbo bf16, 1024×1024, 8 steps, `res_multistep`, cfg 1, shift 3; an empty negative prompt (inert at
  cfg 1, fact 5).
- `wan5b`: Wan 2.2 TI2V 5B fp16 with the FastWan step-distillation LoRA (`LoraLoaderModelOnly`, strength 1.0), text-to-video
  at 1280×704, 121 frames, 3 steps, `lcm`, `simple`, cfg 1, shift 8; an empty negative prompt; the decode `VAEDecodeTiled` with
  `tile_size 512, overlap 64, temporal_size 32, temporal_overlap 8` (the setting every hand clip that was looked at used).
  **Why not 20 `uni_pc` steps (OP5)**: the output is known to carry the hatching (fact 1), so the owner's look and the drift
  numbers would judge a flawed picture, and the series would tune a workload the operator no longer renders with. **Why not
  50 steps**: about 700 s per clip, about 13 h for one series, on a host that has lost two GPU runs in a week. The 50-step
  official setting (shift 5, cfg 5) is recorded as the quality reference the owner can render by hand; it is not a series
  workload. **Why the tiled decode is a constant (OP4)**: the untiled decode stalled for more than 10 minutes (fact 2); there is
  no untiled variant to decide between. The faster setting of fact 2 changes the output (a colour shift) and waits for the
  owner's look as a follow-up. **Why text-to-video**: the bench workload needs no input file, so nothing outside `models.conf` is pinned into its identity. **What is not observed**: FastWan was run by hand image-to-video; the text-to-video form of
  this workload runs first in E2's acceptance, and its first clip is looked at for the hatching before any series.

Audio (voice-over) has no model set yet: which TTS model fits the card is a question for the owner, recorded, not guessed.

**Before any video series: the feasibility run** (E3). One `wan5b` arm-round with `base` is timed, with its peak card memory
and the Windows "shared GPU memory" counter read during it: a decode that spills into shared memory is a different workload
and is written into the record. The video series' round count is set from that time, written into the record before the series
starts, together with the GPU hours it costs (arms × rounds × four generations, the cold runs included); when the three rounds
of every arm do not fit the time the owner gives, the record says so and the series is deferred or narrowed — a narrowing is a
plan change and needs the owner (plan-change-control), never a silent cut. The projection this run checks: a `wan5b` arm-round
≈ 4 clips × 2.3 min + a model load ≈ 12 min, six arms × three rounds ≈ 3.5 h plus the long cold runs of `tunableop` and
`compile` in each of their arm-rounds (the bench cache is cleared before every arm-round: six per series); a `zimage`
arm-round ≈ 2–3 min, the series ≈ 1 h plus the same six cold runs. Those numbers come from the hand
runs of fact 1 and fact 7, one run each; the feasibility run replaces them.

**Prediction, recorded before any run** (rule: measurement § 4), informed by the screening of fact 7 (one round each, not a
verdict): `fp16acc` inert on `zimage` (bf16 weights) and acting on the `wan5b` sampler (fp16 DiT), which at 3 steps is a small
part of the clip; `fp8wmm` −10 to −20 % on the `zimage` sampler and −5 to −10 % on `wan5b`'s, with a visible drift (another
composition at the same seed on `zimage`); `tunableop` faster after its tuning run, 5–15 % on the sampler, or `COLD_TIMEOUT`
when the bounds do not hold it inside `cold_max_s`; `miopen` changes only `vae_s`, either way, and `sampler_s` not at all;
`compile` 0–10 % on the `zimage` sampler once compiled, with recompiles in measured runs flagged, and a cold run minutes longer;
on `wan5b` the tiled decode (≈ 100 s of ≈ 130 s) dominates `total_s`, so only `miopen` can move the deciding metric by more than
the base's spread there, and the sampler arms show on `sampler_s` as information. Each is reported against the observation.

**Rounds**: three for `base` and for every arm, the minimum the ship test reads as a provisional, workload-specific claim (both
consultants); a result inside the base's spread is reported as NOT DECIDED, never as "no difference".

**Speed verdict** (OP3): `bench.py` prints, per measured run, `<arm>-<round> <workload> r=<n> <metric>: <v>` for
`sampler_s`, `vae_s` and `total_s`. `lib/verdict.py ship` as it stands is about vLLM: it decides on the output-throughput
median at c=1 and c=4, higher is better, and an arm inside the base's spread is FAIL there (`fail_reasons`,
`lib/verdict.py:236-243`). Its RULE — an arm's median against the base's spread over all the base's values, exact decimals, an
incomplete arm never PASS or FAIL — is the one the comfy verdict needs, with the groups being the workload's metrics and lower
being better. So E2 widens `verdict.py` with a comfy mode that takes a metric list, the deciding metric and a direction (the
first widening move of reuse-first) and prints, for the deciding metric, PASS for a median beyond the base's spread in the
better direction, FAIL for one beyond it in the worse direction, and `NOT DECIDED (inside the base spread)` for one inside it;
the other metrics are printed as information; the vLLM mode keeps its FAIL inside the spread, and its tests stay unchanged.
This is what *Rounds* already required of the plan; the E2 Done-when of epoch 1 was silent inside the spread, and is not now.

**Quality**: a diffusion arm that changes arithmetic changes the image, and a pixel metric cannot say which image is
better. Three layers, none of them claiming more than it can:

1. **Validity, gating** — the output checks of the measurement contract (a broken kernel's black frame fails the run).
2. **Drift, recorded, never gating** — per seed, the mean absolute pixel difference and PSNR of the arm's output against the
   base's. The pairing key is (workflow fingerprint, seed); the reference of an arm-round is the base's ROUND 1 output of the
   same seed, and the base-against-itself numbers are base rounds 2 and 3 against base round 1; when the matching base
   output is missing or its arm-round was rejected, the drift is written `unavailable (<why>)`, never computed against
   another run; computed in the container with the image's numpy and Pillow, next to the same numbers for the base against
   ITSELF across rounds (the reference the vLLM series lacked, `dew_flow_benchmark · research/RESULTS_vllm_029_r9700_speed_options.md`
   § 8). A same-seed base is expected to be identical; an arm far outside that is pointed out to the reader (`fp8wmm` is
   predicted to be one).
3. **A person's look** — the outputs side by side under the record, with the arm names; the series document says which arms
   changed the output and that the owner looked. "Faster, outputs reviewed" is the strongest claim; "quality equal" is not
   made.

### Records and growth

- `<RESULTS_DIR>/comfy-<workflow>/` — `fingerprint.json` (`kind` = `comfy`, the image id, `COMFY_REF`, the arms, the workflow
  constants including the named fields of the tiled decode and the LoRA's strength, `run_max_s` and `cold_max_s`, the hash of
  `bench.py` and of the worker's modules, the PINNED sha256 of every model file the workflow loads — the LoRA among them —,
  `base`, `rounds`), `rounds/<arm>-<round>/` (`bench.txt` ≈ 2 KB, `runs/*.json` ≈ 5 KB each, `server.log` ≈ 100 KB — the container's whole log from its start, the cold run included, saved before the container stops and read by the evidence check (the approving round), the
  evidence lines, the outputs: `zimage` ≈ 1.5 MB per image × 3 runs, `wan5b` ≈ 5 MB per video × 3), `rejected/` (a reason file
  each: `INTERRUPTED`, `COLD_TIMEOUT`, an `execution_error`, an invalid output, missing evidence). A 6-arm × 3-round `zimage`
  series ≈ 6×3×(5 + 0.2) MB ≈ 95 MB; `wan5b` ≈ 6×3×15 MB ≈ 270 MB; a lost arm-round adds its part under `rejected/`. Collected
  data: append-only, kept forever, its owner is the operator (the same rule as every series here).
- The volumes: `comfy-models` holds what `fetch` put there (the three sets ≈ 41 GB measured by E1, plus the LoRA, its size
  recorded by the fetch); `comfy-data` the venv (≈ 0 until a custom node installs something), workflows and inputs;
  `comfy-cache` the operator's MIOpen, Triton and TunableOp caches: projected at most 2 GB (the nearest measured cousin, the
  Triton MoE caches of this toolkit, grew 0.5–1.3 GB per tuning chunk; TunableOp's results are a CSV of kilobytes), measured in
  E2's acceptance and the projection corrected in `research/module_comfyui.md`; retired by the operator, who removes the volume
  by hand (ComfyUI rebuilds the caches at the next start), and `comfy status` says whether it is present (the engine reports no volume size; E2's acceptance measures it once). The bench's own
  `<CONTAINER_PREFIX>comfy-cache` is cleared before every arm-round, so it never holds more than one arm-round's caches
  (the inductor cache of `compile` and the TunableOp file of `tunableop` included). The toolkit never removes a volume,
  because a model download costs hours.
- The images (E1, as merged): every build is tagged `<COMFY_IMAGE repository>:<UTC stamp>` and only after its check passes is
  `COMFY_IMAGE` pointed at it; the newest four stamped tags are kept (the current one plus three to roll back to,
  development-workflow's depth) and older ones are removed by their exact tag, never by pattern and never before the new image
  passed. Measured 2026-11-07: an image is 27.3 GB as listed, but the ROCm base layers are shared, so a kept build costs its
  own layers (≈ 2 GB) — four kept builds ≈ 8 GB beyond the base.
- The placed copies under `$WORK_DIR/r9700/comfyui/` are rewritten when the repository's file changes, like `moe_place`'s;
  E2 adds `bench.py` to them.
- A bench part `rounds/<arm>-<round>.part-<run id>/` left by a kill or a host crash is moved to `rejected/` as `INTERRUPTED`
  by the next worker start (the sweep `series` already has, reused).

### Tests

Bash tests through `tests/run.mjs` against `tests/stubs/wslc`: no container, no GPU. E1 (merged, `tests/test_comfy.sh` and
`tests/test_config.sh`): the field defaults and refusals, the two cross-field rules of `COMFY_CONTAINER`; the admission of an
EXISTING verb (`step`, and `series` through it) refused while `COMFY_CONTAINER` is listed, and unchanged when it is not;
`build` (the placed files and their hashes, the build argv, the refusal of a build whose check container reports no ROCm
device, the stamp, the promotion, the retention); `start` (refused while `vllm` is listed, `--stop-vllm` stops it, the lock
held → 4, the readiness wait and its ceiling); `stop`, `status`; `fetch` (an unknown set, the argv with and without a store,
the changed hash); `fetch_model.sh` against a local file server with and without `X-Linked-ETag`.

E2 (`tests/test_comfy_bench.sh`, `tests/test_comfy_bench_py.py`, `tests/fixtures/comfy/comfy_server.py` — an HTTP and
websocket stub of ComfyUI's `/prompt`, `/history`, `/ws` and `/system_stats`): `bench` refused by `supervise`'s owner check
while the operator's ComfyUI is listed (exit 2, nothing stopped) and exit 4 under a held lock; the dry run; one stubbed
arm-round recorded; a part swept to `rejected/`; a re-run continuing from the first missing arm-round and refusing another
experiment; an arm-round without its activation evidence rejected; an arm with its inertness evidence reported inert; a cold run
past `cold_max_s` rejected as `COLD_TIMEOUT`; a constant output and a truncated video rejected; a measured run with a model
load, and one with a recompile, flagged; the reversed order of an even round; the bench cache cleared before every arm-round;
the verdict over stubbed rounds — PASS, FAIL, NOT DECIDED inside the spread, INCOMPLETE — with every existing vLLM case
unchanged; `bench.py` against the fixture server (the lines for the measured runs only, the JSON per run, the
`execution_error`, the ceilings). **How `bench.py` is tested in CI (OP7)**: `tests/requirements.txt` gains exact pins of
`aiohttp`, `numpy` and `Pillow` (and their dependencies, as the file pins pytest's), the same major versions as the image's,
under the dependency rules — a standard-library rewrite of the transport and the pixel checks would be new code where a
library the image already ships does the job (reuse-first), and the drift must be tested on the host; the pure parts of
`bench.py` (`workflows`, `metrics`) still import nothing outside the standard library. The seam check over the new files.

Not covered by CI, each with its acceptance record: the real build, a real start on the card, a real fetch (E1); the first
bench run, the engine features the isolation assumes (OP8), the real log lines of the evidence, the TunableOp file, the
`/system_stats`, websocket and `/history` shapes (E2); the series (E3).

### Documents

`research/module_comfyui.md` (E1 wrote it: purpose, the three traps with their evidence, the flows, the Mermaid diagram, the
growth, the two facts of 2026-11-07/08 — E2 corrects the tile-field order at `:106` to the named fields of fact 2 and adds the
bench flow, the arms, the evidence table and the resume); `research/architecture.md` (a module row, a verb row);
`research/module_config.md` (the fields, E1); `research/module_tests.md` (the catalogue rows, covered and not covered);
`README.md` (a ComfyUI section); the acceptance record `research/ACCEPTANCE_comfy_<date>.md` (E3; E1's and E2's acceptance
runs are recorded in `research/module_comfyui.md` § *Acceptance on the R9700*, `:109-117`, as E1 decided); `POST_DEPLOY.md`
only if an item meets its two conditions.

## Build order

1. Config fields and the `win?` type; adapter calls; their tests. (E1, merged.)
2. `comfyui/` files moved in from the hand-made folder with the machine values taken out; `comfy build|start|stop|status|fetch`;
   tests; documents. (E1, merged.) A real build, start and fetch on this PC. (E1's acceptance, owed.)
3. The comfy mode of `verdict.py`; `bench.py` with its fixtures and tests; `comfyui/arms.conf` and `comfyui/arm_evidence.conf`;
   the LoRA line of `wan5b`; the worker and `comfy bench` under the supervisor; the verdict over a bench folder; tests;
   documents; the first bench run on the card. (E2.)
4. The feasibility run, the two series on the R9700 and the record. (E3.)

## Test plan

- Every test in `tests/run.mjs` green, in CI (`.github/workflows/tests.yml`) and locally under the runner's caps; the pinned
  test requirements installed by the same runner.
- Each new refusal has a test that was seen failing before its code existed.
- The acceptance runs: a build whose check container prints the R9700; `comfy start` then a `zimage` smoke from the
  browser's API port; `comfy fetch zimage wan5b` with the hashes printed (E1, owed); one `comfy bench zimage base fp16acc
  --rounds 1` as the first GPU run of the verb, then one `wan5b base --rounds 1` whose first clip is looked at for the
  hatching (E2); then the feasibility run and the full series (E3).

## Definition of Done

- [ ] `bin/r9700 comfy build|start|stop|status|fetch|bench` exist, `commands` lists `comfy`, and the architecture verb table
      has its row (the document test derives it).
- [ ] Every new `wslc` call is in `lib/adapter.sh`; `tests/check_static.sh` (seam, personal paths) passes.
- [ ] Every new field has its default, type and description in the table, `machine.env.example` and `module_config.md`.
- [ ] The tests above pass in CI; `module_tests.md` lists every comfy flow covered or not covered, with the reason.
- [ ] The image was built and started on the R9700 from the repository alone, and the check container printed the device.
- [ ] One `zimage` and one `wan5b` series ran; the acceptance record holds the prediction, the observation, the verdict, the
      conditions, the arms that changed the output, and what it does not settle.
- [ ] The hand-made folder's scripts are no longer needed to run ComfyUI on this PC (the operator decides whether to delete
      it).

## Epics

Three epics, in build order; each becomes stories when it starts (`todo/PLAN_comfyui_r9700_E<n>.md`, written then, linking
back here). The build order has four steps and this section three epics: steps 1 and 2 are one epic, because the fields and
adapter calls of step 1 show no behaviour until the verbs of step 2 use them, and the cross-field rules of `COMFY_CONTAINER`
mean nothing without the admission refusal beside them. Every design item lands in exactly one epic. The re-review of epoch 2
changed no epic boundary: E1 is what was merged, E2 keeps build-order step 3 with the open points settled, E3 keeps step 4.

### E1 — ComfyUI from the repository: fields, adapter, image, five verbs, one owner of the card

**Done except its acceptance runs.** Merged as PR #18 (6be7a67, 2026-11-08). The stories of this epic are
[PLAN_comfyui_r9700_E1.md](PLAN_comfyui_r9700_E1.md) (written 2026-11-07; E1.S2 is the cornerstone; its *Follow-ups found
while building E1* are outside this plan's scope and wait for their own change). What was merged: the twelve fields and the
`win?` and `ref` types; `wslc_remove`, `wslc_inspect`, `wslc_build`, `wslc_tag`, `wslc_rmi`, `wslc_image_list`, `wslc_volume_list`, `wslc_volume_create`, `comfy_probe` and the stub's answers;
`comfy_owner_check` and the owner check in `supervise` and `step_run`; `comfy start|stop|status`; `comfyui/Containerfile`,
`entrypoint.sh`, `fetch_model.sh`, `models.conf`; `comfy build` with the stamped tags and the retention; `comfy fetch` with its
own lock; the tests and the documents. **Owed**: the three acceptance runs on the card of `research/module_comfyui.md`
§ *Acceptance on the R9700 (E1)* (the build, the fetch, the start with the owner check seen on the real machine), and their
record there.

**Goal.** A person with a `machine.env` runs `bin/r9700 comfy build|start|stop|status|fetch <set>` on any PC this toolkit
describes, and while their ComfyUI is listed no GPU verb of the toolkit starts a run beside it. The hand-made folder is not
needed; no machine value is in a tracked file.

**Scope.** Build-order steps 1 and 2 whole: the field table (with `win?` and the two cross-field rules); the adapter
calls and the stub; `Containerfile`, `entrypoint.sh`, `fetch_model.sh`, `models.conf` moved in from the hand-made folder with
the machine values taken out, placed by `comfy_assets`; the five modes of the verb table in `lib/comfy.sh`; the owner check in
`supervise` and the admission refusal in `step_run` — the one change to the existing verbs; their tests and the
`fetch_model.sh` fixtures; the Documents section except the bench parts and the acceptance record; the growth rows of the
volumes, the images and the placed copies. The acceptance: the real build (its check container prints the R9700), the real
start with a `zimage` smoke, the real fetch.

**Depends on.** Nothing new: the shipped toolkit (`config_load`, the adapter seam, `lock_take`, `step_run`, `moe_place`).

**Done when.**
- Every field is in the table, `machine.env.example` and `module_config.md`; a `COMFY_CONTAINER` with the prefix or equal to
  `PROD_CONTAINER` is refused before any container is touched. (Merged.)
- The refusals of the Tests section — `step` (and `series` through it) exit 2 naming `comfy stop` while `COMFY_CONTAINER` is
  listed and unchanged when it is not, `start` under a held lock and beside a listed `PROD_CONTAINER`, `build` whose check
  container sees no ROCm device, `fetch` of an unknown set or a changed hash — each seen failing before its code existed.
  (Merged.)
- The seam check and the personal-path check pass over the new files; CI green (merged); the three acceptance runs are recorded
  (owed).

**Cornerstone area.** GPU ownership: one owner of the card decided under the toolkit's lock — the owner check in `supervise`
and the admission refusal in every existing GPU verb, `start` holding the lock through the readiness wait, the prefix and name
rules that keep `container_stop_all` away from the operator's ComfyUI and from a fetch in progress. A mistake here stops the
operator's work or records an out-of-memory as a result, and no later step catches it.

### E2 — `comfy bench` under the supervisor, and the verdict over its records

The stories of this epic are [PLAN_comfyui_r9700_E2.md](PLAN_comfyui_r9700_E2.md) (written 2026-11-08 under epoch 1; E2.S2 is
the cornerstone). **That document was rewritten by Opus for epoch 2 (d3bee61)**: its eight open points are settled in
this plan (OP1 the file split, OP2 entry 1.2, OP3 NOT DECIDED, OP4 the tiled decode as a constant with named fields, OP5 the
FastWan workload, OP6 the evidence table with activation and inertness, OP7 the pinned test requirements, OP8 built as written
and observed first), and the `wan5b` workload, the arm table, the evidence, the cold-run ceiling, the recompile flag and the
resume change its stories' text; its cornerstone stays E2.S2 (the measurement contract).

**Goal.** `bin/r9700 comfy bench <workflow> <arm>...` measures ComfyUI arms as one supervised step under the measurement
contract, every arm-round recorded only when complete, and `bin/r9700 verdict` gives the ship test over those records.

**Scope.** Build-order step 3 whole: the comfy mode of `lib/verdict.py` (metric list, deciding metric, direction, NOT DECIDED
inside the spread), the vLLM mode and its tests unchanged; `comfyui/bench.py` with its HTTP and websocket fixtures and the
two workloads' constants (the FastWan LoRA, the named tile fields, the ceilings); `comfyui/arms.conf` with the six arms and
`comfyui/arm_evidence.conf` with the activation and inertness evidence of each; the LoRA line of `wan5b` in `models.conf`,
pinned; the worker `lib/comfy_bench.sh` and the verb half `lib/comfy_bench_verb.sh` (OP1) as `supervise` around one
`step_run`, with every item of the measurement contract — the isolation built as written (OP8), the cold-run and run ceilings,
the evidence check, the model-load and recompile flags, the part sweep, the resume of the same experiment, the fingerprint
through `lib/fingerprint.py` widened; the drift numbers in the record, never gating; the pinned test requirements (OP7); the
`bench`, `bench.py` and verdict tests of the Tests section; the growth rows of the results folder and the bench cache; the bench
parts of the documents and the tile-field correction in `research/module_comfyui.md`. The acceptance, recorded in
`research/module_comfyui.md` § *Acceptance on the R9700 (E2)*: `comfy bench zimage base fp16acc --rounds 1` on the card with
`fp16acc` reported inert with its evidence; `comfy bench wan5b base --rounds 1` with its first clip looked at for the hatching;
`verdict` over each folder; the engine features of OP8 observed; the operator's cache volume measured once.

**Depends on.** E1 (the image, the volumes, the fields, the owner check, the model sets fetched — E1's acceptance runs 1 and 2
give E2's acceptance its image and its models; the FastWan LoRA line is E2's, so E2's acceptance fetches `wan5b` again first).

**Done when.**
- Against the stub, each `bench` case of the Tests section passes and each refusal was seen failing first; an
  `execution_error` fails the run at once; the bench cache is cleared before every arm-round; an even round runs reversed; a
  cold run past its ceiling is `COLD_TIMEOUT`; a re-run continues the same experiment and refuses another.
- `bench.py` against the fixtures prints `sampler_s`, `vae_s`, `total_s` per measured run and nothing for the cold run; a
  measured run with a model load or a recompile is flagged.
- The comfy mode of `verdict.py` passes an arm whose median is beyond the base's spread in the better direction, fails one
  beyond it in the worse direction, prints NOT DECIDED for one inside it, decides nothing for an incomplete arm and prints
  exact decimals; every existing vLLM case unchanged.
- The first bench runs on the R9700 are recorded with their `vram_free` values, cold-run times, evidence lines as found and
  outputs; the `wan5b` clip was looked at and the record says whether the hatching is there.

**Cornerstone area.** The measurement contract: what one arm-round is (the isolated container, the cleared cache, the cold
run under its ceiling, the three same-seed measured runs, the `vram_free` wait), what fails it (`execution_error`, an invalid
output, `COLD_TIMEOUT`, missing activation evidence) and what is recorded (the flags, the evidence, the identity that admits a
resume and refuses another experiment). ComfyUI's execution cache and model offload make a run that looks like a measurement
and is not one, and every claim of E3 rests on this record. The bench container's isolation and cleanup, which the consultants
named under GPU ownership, sit here, because the stub tests of this area are what exercise them.

The verdict widening is not a cornerstone: the rule exists and is pinned by the vLLM mode's test cases, and the comfy mode's
test is a table of numbers where a wrong direction or a lost decimal shows before any GPU time is spent.

### E3 — the acceptance series on the R9700 and its record

**Goal.** One `zimage` series and one `wan5b` series have run on the card, and `research/ACCEPTANCE_comfy_<date>.md` says
which arms are faster than the base by more than the base's own spread, under which conditions, with the prediction written
before and the observation after, the outputs looked at, and what it does not settle.

**Scope.** Build-order step 4 whole: the prediction copied into the record before any run; the `wan5b` feasibility run (one
`base` arm-round timed, memory and the shared-memory counter read, the round count and the GPU hours set from it and written
before the series); the two series and the verdict over each, with a lost arm-round expected and the series continued by the
same command after a reboot; the drift numbers and the outputs side by side under the record; the inert arms reported as inert
with their evidence; the arms rejected as `COLD_TIMEOUT` reported as not measurable within the ceiling; the owner's TTS
question and the faster tiled decode recorded as questions for the owner; the DoD ticks; `POST_DEPLOY.md` only if an item
meets its two conditions; the promotion of this plan and its stories documents with their deviations.

**Depends on.** E1 and E2, both with their acceptance runs recorded.

**Done when.**
- The feasibility run's time, memory readings and the round count are in the record before the video series starts.
- Both series completed under the supervisor with one restore of the operator's vLLM; every arm-round is in
  `rounds/` with its evidence or in `rejected/` with its reason; every lost arm-round is named with its cause when known.
  Decided (the approving round): a series continued after a lost run keeps its data in the record, but this line is met
  only by a series that one invocation completes; a continued one is re-run whole for it. Counting a continued series (one
  restore per invocation) would narrow this condition and needs the owner's approval first; it is asked, not assumed.
- The record holds, per arm and workload: prediction, observation, the verdict line, the drift numbers, the conditions
  (image id, `COMFY_REF`, model and LoRA hashes, the workload constants); the owner looked at the outputs and the record says
  so; a result inside the base's spread is written as NOT DECIDED; "quality equal" appears nowhere. The plan and its stories
  documents are promoted with their deviations.

**Cornerstone areas.** None. E3 runs E1's and E2's code and writes prose; an incomplete or unproven arm-round is what E2's
checks reject, and the reading of the numbers is what the measurement rule already governs.

Cornerstones: 2 of 2 — E1.S2 (GPU ownership, [PLAN_comfyui_r9700_E1.md](PLAN_comfyui_r9700_E1.md)), E2.S2 (the measurement
contract, [PLAN_comfyui_r9700_E2.md](PLAN_comfyui_r9700_E2.md)). Recounted at the re-review: three epics, Q = ⌈2·3/5⌉ = 2, both
marked, none added.
