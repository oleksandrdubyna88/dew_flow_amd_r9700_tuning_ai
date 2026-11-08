# PLAN — ComfyUI on the R9700 in a wslc container, as verbs of this toolkit, with a measured tuning series

> Status: **plan only, nothing implemented yet, 2026-11-07.** Scope: a new `comfyui/` folder (the image recipe and the
> programs that run inside it), a `comfy` verb of `bin/r9700`, new optional fields of `machine.env`, three new adapter calls,
> their tests and documents, and the GPU acceptance runs that measure ComfyUI arms on the R9700.

## Plan changes

> Epoch 1 · approved 2026-11-07 · by reviewers · state: open

  (The approving round's seven findings, all accepted, are folded into the approved text; they are not entries.)

- 1.1 · 2026-11-07 · reviewer · contract — two fetches could share a part file; fetch takes a lock of its own
  (not the GPU lock), so a fetch still runs beside a series; E1 plan round, codex.
  (Same round, not counted, each only satisfying the plan as written: build passes the owner check before its GPU check
  container, which the one-owner rule already required; image retention fills the growth section planning-docs requires.)

## Goal

The operator runs vLLM on the R9700 through this toolkit's machine (Windows + WSL2, containers through `wslc`). They now
want ComfyUI on the same card — images, video and voice-over for series — **one at a time with vLLM, never both** (the
owner, 2026-11-07), and they want it TUNED for the R9700 the way vLLM was, with the result reusable on another PC from this
repository alone.

Today ComfyUI runs on this PC from a hand-made folder outside any repository (built and checked 2026-11-07, below). The
symptom this plan removes: nothing of it is reusable, nothing is tested, the machine's paths are written into its scripts, and
the speed options it uses were taken from a vendor guide — one of which breaks the GPU here — rather than measured.

What must be true when it is done:

1. `bin/r9700 comfy build` makes the image from `comfyui/` on any PC this toolkit's `machine.env` describes; `comfy start` /
   `comfy stop` run the operator's ComfyUI; `comfy fetch <set>` puts a named model set where ComfyUI reads it, every file
   checked against the sha256 pinned in `comfyui/models.conf` (read once from what the source publishes).
2. `bin/r9700 comfy bench` measures ComfyUI arms (server flags and environment) under the same supervisor as every other
   GPU verb — one lock, the operator's vLLM stopped once and restored once, the guards — and records each arm-round only
   when it is complete; `bin/r9700 verdict` gives the ship test over those records for speed.
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
- **Three traps, each seen and fixed:**
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

## Design

### Reuse first (the four questions answered)

| Need | Existing piece | Use |
|---|---|---|
| machine values | `lib/config.sh` field table (`_field`, `lib/config.sh:29`), `config_load` | new `machine` fields with defaults, so an existing `machine.env` stays valid |
| every `wslc` call | `lib/adapter.sh` (`wslc_run` `:251`, `wslc_exec` `:260`, `wslc_run_once` `:280`, `wslc_list` `:305`, `wslc_stop` `:316`, `wslc_logs` `:329`) | widen with `wslc_build`, `wslc_volume_list`, `wslc_volume_create` — the seam check (`tests/check_static.sh --seam`) keeps every call there |
| copy repository files to where a container can read them | `moe_place` (`lib/moe_verb.sh:35`) with an assets function (`moe_assets`, `lib/moe.sh:94`), hash-checked | a `comfy_assets` function: the build context and the in-container programs placed under `$WORK_DIR/r9700/comfyui/` (the build needs a Windows path, `WORK_DIR_WIN`) |
| one GPU run with the operator's server stopped and restored | `supervise` (`lib/run_guarded.sh:433`), `step_run` (`lib/step.sh:236`), `cleanup_once` (`lib/run_guarded.sh:590`) | `comfy bench` is `supervise` around ONE `step_run`, exactly like `linear-bench` |
| an arm table | `arms_load` (`lib/config.sh:492`) and the grammar of `config/arms.conf` | a second table `comfyui/arms.conf` in the same grammar: name, ComfyUI arguments, environment, mounts |
| the ship test | `lib/verdict.py ship` and `bin/r9700 verdict` | the bench writes lines in the verdict grammar `<arm>-<round> <group> r=<n> <metric>: <value>`; quality is not a GSM8K score here (below) |
| test doubles | `tests/stubs/wslc`, `tests/run.mjs` | the stub learns `build`, `volume list`, `volume create` and a scripted ComfyUI bench answer |
| a model file per model, not a script | `models/*.env` | `comfyui/models.conf`: one model SET per block, lines `<set> <folder> <url>` |

New code is written only where none of these fits; the summary of each epic names which widening was used.

### The `comfyui/` folder

| File | Role |
|---|---|
| `comfyui/Containerfile` | the image recipe (Docker build format, built by `wslc build`; named `Containerfile` because nothing here runs Docker). `ARG BASE`, `ARG COMFYUI_REF`; installs `git ffmpeg ca-certificates python3.12-venv`, writes `/opt/rocm-constraints.txt` from the base's ROCm packages, installs ComfyUI and its Manager with those constraints, sets `PIP_CONSTRAINT`, `UV_CONSTRAINT`, `VIRTUAL_ENV=/data/venv`, the MIOpen and Triton cache paths. Does NOT set `PYTORCH_HIP_ALLOC_CONF` (trap 1, with the observation in a comment) |
| `comfyui/entrypoint.sh` | makes the folders of `/data`, `/models`, `/cache`; makes or keeps the `--system-site-packages` venv on `/data` (a venv of another Python minor version is moved aside, never deleted); forces the Manager's `use_uv = False` (trap 2); `exec`s `main.py --listen 0.0.0.0 --port 8188 --base-directory /data --models-directory /models --enable-manager "$@"` |
| `comfyui/bench.py` | inside the container, stdlib + the image's `aiohttp`: queues one workflow on `127.0.0.1:8188`, times every node over the websocket (`executing` events), prints verdict-grammar lines and writes a JSON per run; workflows `sd15`, `zimage`, `wan5b`, each with every input pinned (seed, steps, size, sampler, scheduler, cfg, shift) |
| `comfyui/fetch_model.sh` | inside a throwaway container with no GPU: per file, the PINNED sha256 of `models.conf` is the authority — the download is accepted only when its own sha256 equals it; the source's `X-Linked-ETag`, when the source sends one, is a pre-flight cross-check (a different value refuses before downloading, an absent one is fine); a resumable download to the store first (`/store`, when mounted) and a checked copy into `/models`, or straight to `/models` without a store |
| `comfyui/arms.conf` | the ComfyUI arms (names and contents in the series section) |
| `comfyui/models.conf` | the model sets: `sd15`, `zimage` (Z-Image Turbo bf16, `qwen_3_4b` text encoder, `ae` VAE), `wan5b` (Wan 2.2 TI2V 5B fp16, `umt5_xxl_fp8_e4m3fn_scaled`, `wan2.2_vae`); each line `<set> <folder> <url> <sha256>`, the sha256 PINNED in the file (read once from the source's `X-Linked-ETag` and checked by the download): `fetch` refuses a source that now publishes another hash, and the bench fingerprint takes the model identity from these pinned hashes, never from names and sizes |

### New `machine.env` fields (all optional; the defaults are what the hand-made setup used)

| Field | Type | Default | Meaning |
|---|---|---|---|
| `COMFY_IMAGE` | image | `comfyui-r9700:local` | the tag `comfy build` writes and every comfy container runs |
| `COMFY_BASE_IMAGE` | image | `rocm/pytorch:rocm10.1.0_ubuntu24.04_py3.12_pytorch_release_2.13.0` | the build's `BASE` |
| `COMFY_REF` | a git tag word | `v0.44.0` | the ComfyUI tag the build clones |
| `COMFY_CONTAINER` | name | `comfyui` | the operator's own ComfyUI container |
| `COMFY_PORT` | int 1024–65535 | `8188` | the Windows loopback port it is published on |
| `COMFY_MODELS_VOLUME`, `COMFY_DATA_VOLUME`, `COMFY_CACHE_VOLUME` | name | `comfy-models`, `comfy-data`, `comfy-cache` | the three volumes |
| `COMFY_OUTPUT_WIN` | Windows path, optional | empty | when set, mounted at `/data/output`, so results appear in Windows |
| `COMFY_STORE_WIN` | Windows path, optional | empty | the master model store `comfy fetch` writes first (a NAS share is fine: `wslc` mounts a mapped drive, observed) |
| `COMFY_BUILD_MAX_S` | int 600–14400 | `5400` | the ceiling of one `wslc build` |
| `COMFY_FETCH_MAX_S` | int 600–86400 | `21600` | the ceiling of one fetch container |

An optional Windows path needs a type the table does not have yet (`win?`); it is added beside `win` with the same check
when non-empty.

### The verb `bin/r9700 comfy <mode>`

**One owner of the card at a time, decided under the lock.** The toolkit's lock (`lock_take`, `lib/run_guarded.sh:91`) is
what every GPU verb already takes, so it is what decides between ComfyUI and vLLM work too:

- `build` (its check container uses the GPU), `start` and `bench` take the lock; `start` holds it through the launch and
  the readiness wait and releases it once ComfyUI answers, so no check-then-start window is left.
- **Every GPU verb refuses while `COMFY_CONTAINER` is listed** — exit 2, one line naming `bin/r9700 comfy stop` — checked
  FIRST in the supervisor's prepare, before anything is stopped (so a refused night run leaves the operator's vLLM as it
  was), and again at every admission (`step_run`, `lib/step.sh:236`), because a long run can outlive the first check: the
  operator's ComfyUI holds the card's memory and a series beside it would measure an out-of-memory. No verb ever stops the
  operator's ComfyUI by itself — it may hold a queue or unsaved work — so `comfy start` is a manual workstation mode, and an
  unattended plan that finds it running refuses and says what to run. This is the one change to the existing verbs, and it
  is a cornerstone.
- `COMFY_CONTAINER` must not start with `CONTAINER_PREFIX` and must differ from `PROD_CONTAINER` — the same cross-field
  rule as `PROD_CONTAINER`'s (`lib/config.sh:375`), because `container_stop_all` (`lib/restore.sh:152`) stops every
  container with the prefix.
- `fetch` uses no GPU and does not take the GPU lock (it takes its own, entry 1.1), so its container is NOT prefixed
  (`<COMFY_CONTAINER>-fetch`): a prefixed one would be stopped by another run's cleanup halfway through a download.

| Mode | Lifecycle | What it does |
|---|---|---|
| `build [--no-cache]` | the lock (for the check container), no stop | places `Containerfile` and `entrypoint.sh` (hash-checked) under `$WORK_DIR/r9700/comfyui/`, runs `wslc_build` with `--build-arg BASE=… --build-arg COMFYUI_REF=…`, ceiling `COMFY_BUILD_MAX_S`; then one throwaway container (`--gpus all`, `--rm`, prefixed name) asserts the built image's torch is a ROCm build that sees a device, and prints the device name — the artefact is checked, not the build's exit code |
| `start [--stop-vllm] [-- <main.py args>]` | the lock, held through the launch and the readiness wait | refused (exit 4) while a toolkit run holds the lock, and refused (exit 2) while `PROD_CONTAINER` is listed unless `--stop-vllm` (then `wslc_stop` of it, logged); makes missing volumes; removes a stopped `COMFY_CONTAINER`; runs it detached with `--gpus all`, the volumes, the port on loopback, the optional output mount; waits until `GET /system_stats` answers (inside the container, through `wslc_exec`, ceiling `READY_TIMEOUT_S`) and prints the device line it reports. **A start that does not become ready** (the container exits, or the ceiling passes) saves the container's last 200 log lines to the state folder, stops it and checks it is no longer listed, restores the operator's vLLM through the existing restore (`restore_start` + `ready_wait`) when this invocation stopped it with `--stop-vllm`, and only then releases the lock: exit 5, one line naming the saved log |
| `stop` | no lock | `wslc_stop COMFY_CONTAINER`; a container that is not listed is not an error |
| `status` | no lock | the listed state of `COMFY_CONTAINER` and of `PROD_CONTAINER`, the image's creation time |
| `fetch <set>...` | its own lock (`<state dir>/comfy-fetch.lock`, not the GPU lock: exit 4 naming the holder when another fetch runs), no GPU | the set's lines from `comfyui/models.conf` → one throwaway container (`--rm`, the name `<COMFY_CONTAINER>-fetch`, not prefixed, no `--gpus`) running `fetch_model.sh` with `/store` mounted when `COMFY_STORE_WIN` is set; ceiling `COMFY_FETCH_MAX_S`; an unknown set is exit 2 naming the legal ones |
| `bench <workflow> <arm>... [--rounds N] [--out <name>] [--dry-run]` | `supervise comfy …` around ONE `step_run` | refused (exit 2) before the lock while `COMFY_CONTAINER` is listed (the operator's ComfyUI holds the card); the worker (`lib/comfy.sh bench`) per round, per arm (alternating, like `series`): a prefixed ComfyUI test container with the arm's arguments and environment and the same volumes, ready-wait, `bench.py` through `wslc_exec` (one cold run, then the measured runs), the images or video kept, the container stopped, validation, ONE rename into `rounds/<arm>-<round>/` |

`comfy` holds no second lifecycle: its lock, stop, guards, deadline and restore are the supervisor's, and the only server it
restores is the operator's vLLM (`PROD_CONTAINER`), as for every other verb. The operator's ComfyUI is never stopped or
started by a bench.

**The bench's measurement contract** (the consultants' first risk, 2026-11-07, and ComfyUI is not vLLM: it is a queue with an
execution cache and dynamic model offload):

- **Isolation.** A bench container gets an EMPTY `/data` (`--tmpfs`, so no custom node, venv or Manager state of the
  operator's reaches a measurement), the models volume read-only, and its own cache volume `<CONTAINER_PREFIX>comfy-cache`,
  cleared before every arm-round (like the MoE cache clear) so every arm-round starts equally cold.
- **A round** is ONE arm-round container: one untimed cold run (model load, kernel compile, TunableOp or MIOpen search), then
  three measured runs with three seeds that are the SAME for every arm. The prompt does not change, so ComfyUI's cache keeps
  the text encoding after the cold run and the measured runs time the sampler and the VAE — the record says so.
  `total_s` (queue to the history entry) is the metric the verdict decides on; the per-node times are diagnostics.
  **Model offload is part of the workload, and it is made visible**: ComfyUI may unload the text encoder or the DiT between
  nodes to make room. Every arm runs with ComfyUI's default memory mode (pinned, the same for all arms), the server log's
  model load and unload lines are cut per measured run and kept in the record, and a measured run with a load in it is
  flagged in `bench.txt`, so a reader sees whether a time includes a transfer.
- **Failure is fast.** An `execution_error` on the websocket or in `/history` fails the run at once; each run has its own
  ceiling inside `bench.py`; the worker's call has the adapter's.
- **The output is checked**, not trusted: the file exists, its dimensions are the workflow's `width` × `height`, and for a
  video its frame count equals the workflow's `length` (121 for `wan5b`), read by `ffprobe -count_frames` from the image's
  own `ffmpeg` (installed by the Containerfile: the base has none); its pixels are not constant (a NaN becomes a black or
  grey frame that finishes in normal time). A truncated video fixture and a constant image fixture are rejected in the tests.
- **The card is free at the start**: the ready check reads `vram_free` from `/system_stats` and waits (bounded) until it is
  at least 90 % of the total, because the previous container's memory may not be returned the instant it stops; the value
  is recorded.
- **The arm took effect**: each arm names the evidence that proves it differed from `base` — a line in ComfyUI's log
  (`Enabled fp16 accumulation`), a TunableOp results file that is not empty, the absence of `cudnn.enabled = False` — and an
  arm-round without its evidence is rejected (measurement § 1: read back what was actually run).
- **Order is balanced**: odd rounds run the arms in the table's order, even rounds in reverse (the existing series repeats one
  order, `lib/series.sh:465`).

### The tuning series

**Arms** (`comfyui/arms.conf`), each one change from `base`:

| Arm | Change | Why it is a candidate on this card |
|---|---|---|
| `base` | ComfyUI's own choice (pytorch attention, cudnn off on AMD) | the reference |
| `fp16acc` | `--fast fp16_accumulation` | fp16 matmul accumulation; it acts only on fp16 matmuls, so the record carries ComfyUI's weight and compute dtype line for the workload, and an arm that is inert on a bf16 model is reported as inert, not as "no gain" |
| `fp8mm` | `--fast fp8_matrix_mult` | RDNA4 has fp8 matrix hardware and ComfyUI sets `SUPPORT_FP8_OPS` for gfx1201; with bf16 weights it can touch only the fp8 text encoder of `wan5b`, so it is a screening arm (one round; a full series only if it moves) |
| `tunableop` | `PYTORCH_TUNABLEOP_ENABLED=1`, its results file in the bench cache | hipBLASLt GEMM tuning per shape; the cold run tunes, the measured runs must read the file (evidence: the file is not empty and holds the workload's shapes) |
| `miopen` | `COMFYUI_ENABLE_MIOPEN=1`, `MIOPEN_FIND_MODE=FAST` | ComfyUI turns cudnn/MIOpen off for every AMD arch after RDNA2; on these two DiT models it can only change the VAE, and FAST keeps the search out of a multi-minute stall |
| `compile` | `COMFY_BENCH_COMPILE=1`: `bench.py` inserts `TorchCompileModel` (inductor, no CUDA graphs) after the loader | the DiTs are full of pointwise chains between their GEMMs; the compile cost lands in the cold run and the record keeps it separately |

`--use-quad-cross-attention` was a planned arm and is dropped (both consultants, 2026-11-07): it replaces the fused SDPA
that now works with a chunked fallback made for cards without one, so it can only be slower, and on the video workload a
slower arm costs hours. Checked: the attention line ComfyUI logs (`Using pytorch attention`), not a timing.

**Before any video arm: the feasibility run.** One `wan5b` generation with `base` is timed, with its peak card memory and
the Windows "shared GPU memory" counter read during it: a VAE decode of 121 frames at 1280×704 that spills into shared
memory is a different workload, so the base workflow switches to tiled VAE decoding if it does, and that choice goes into
the workload's identity. The video series' round count is set from that time, written into the record before the series
starts, together with the GPU hours it costs (arms × rounds × four generations, the cold runs included); when the three
rounds of every non-screening arm do not fit the time the owner gives, the record says so and the series is deferred or
narrowed — a narrowing is a plan change and needs the owner (plan-change-control), never a silent cut. The plan's earlier
figure of hours per video run was a guess, not a measurement, and is withdrawn.

**Workloads**: `zimage` (1024×1024, 8 steps, `res_multistep`, cfg 1) and `wan5b` (1280×704, 121 frames, 20 steps,
`uni_pc`, cfg 5) — the two model sets the owner asked for (images and video). Audio (voice-over) has no model set yet:
which TTS model fits the card is a question for the owner, recorded, not guessed.

**Prediction, recorded before any run** (rule: measurement § 4): `fp16acc` inert on `zimage` (bf16 weights) and on the
`wan5b` sampler (fp16 weights: a gain there); `fp8mm` no faster on either; `tunableop` faster after its tuning run;
`miopen` changes only the VAE time; `compile` the largest sampler gain, with a cold run minutes longer. Each is reported
against the observation.

**Rounds**: three for `base` and for every arm that is not a screening arm, the minimum the ship test reads as a
provisional, workload-specific claim (both consultants); a result inside the base's spread is reported as not decided,
never as "no difference".

**Speed verdict**: `bench.py` prints, per measured run, `<arm>-<round> <workload> r=<n> <metric>: <v>` for
`sampler_s`, `vae_s` and `total_s`. `lib/verdict.py ship` as it stands (read 2026-11-07, `lib/verdict.py:8-10`, `:170-173`,
`:238-240`) is about vLLM: it decides on the output-throughput median at c=1 and c=4, higher is better. Its RULE — an
arm's median against the base's spread over all the base's values, exact decimals, an incomplete arm never PASS or FAIL —
is the one the comfy verdict needs, with the groups being the workload's metrics and lower being better. So the bench epic
widens `verdict.py` with a second mode that takes a metric list and a direction (the first widening move of reuse-first),
rather than copying the rule into a new file; the vLLM mode and its tests stay unchanged.

**Quality**: a diffusion arm that changes arithmetic changes the image, and a pixel metric cannot say which image is
better. Three layers, none of them claiming more than it can:

1. **Validity, gating** — the output checks of the measurement contract (a broken kernel's black frame fails the run).
2. **Drift, recorded, never gating** — per seed, the mean absolute pixel difference and PSNR of the arm's output against the
   base's. The pairing key is (workflow fingerprint, seed); the reference of an arm-round is the base's ROUND 1 output of the
   same seed, and the base-against-itself numbers are base rounds 2 and 3 against base round 1; when the matching base
   output is missing or its arm-round was rejected, the drift is written `unavailable (<why>)`, never computed against
   another run; computed in the container with the image's numpy and Pillow, next to the same numbers for the base against
   ITSELF across rounds (the reference the vLLM series lacked, `dew_flow_benchmark · research/RESULTS_vllm_029_r9700_speed_options.md`
   § 8). A same-seed base is expected to be identical; an arm far outside that is pointed out to the reader.
3. **A person's look** — the outputs side by side under the record, with the arm names; the series document says which arms
   changed the output and that the owner looked. "Faster, outputs reviewed" is the strongest claim; "quality equal" is not
   made.

### Records and growth

- `<RESULTS_DIR>/comfy-<workflow>/` — `fingerprint.json` (the image id, `COMFY_REF`, the arms, the workflow constants
  including a tiled VAE decode, the hash of `bench.py`, the pinned sha256 of every model file the workflow loads), `rounds/<arm>-<round>/` (`bench.txt` ≈ 2 KB, `runs/*.json`
  ≈ 5 KB each, `server.log` ≈ 100 KB, the outputs: `zimage` ≈ 1.5 MB per image × 3 runs, `wan5b` ≈ 5 MB per video × 3),
  `rejected/`. A 6-arm × 3-round `zimage` series ≈ 6×3×(5 + 0.2) MB ≈ 95 MB; `wan5b` ≈ 6×3×15 MB ≈ 270 MB. Collected data:
  append-only, kept forever, its owner is the operator (the same rule as every series here).
- The volumes: `comfy-models` holds what `fetch` put there (the two sets ≈ 21 GB + 18 GB); `comfy-data` the venv (≈ 0 until a
  custom node installs something), workflows and inputs; `comfy-cache` the operator's MIOpen, Triton and TunableOp caches:
  projected at most 2 GB (the nearest measured cousin, the Triton MoE caches of this toolkit, grew 0.5–1.3 GB per tuning
  chunk; TunableOp's results are a CSV of kilobytes), measured in E2 and the projection corrected in the record; retired by
  the operator, who removes the volume by hand (ComfyUI rebuilds the caches at the next start), and `comfy status` prints
  its size. The bench's own `<CONTAINER_PREFIX>comfy-cache` is cleared before
  every arm-round, so it never holds more than one arm-round's caches. Retired by the operator by hand (`wslc volume remove`); the toolkit never removes
  a volume, because a model download costs hours.
- The images: every build is tagged `<COMFY_IMAGE repository>:<UTC stamp>` and only after its check passes is `COMFY_IMAGE`
  pointed at it; the newest four stamped tags are kept (the current one plus three to roll back to, development-workflow's
  depth) and older ones are removed by their exact tag, never by pattern and never before the new image passed. Measured
  2026-11-07: an image is 27.3 GB as listed, but the ROCm base layers are shared, so a kept build costs its own layers
  (≈ 2 GB, the ComfyUI and pip layer) — four kept builds ≈ 8 GB beyond the base.
- The placed copies under `$WORK_DIR/r9700/comfyui/` are rewritten when the repository's file changes, like `moe_place`'s.
- A bench part `rounds/<arm>-<round>.part-<run id>/` left by a kill is moved to `rejected/` as `INTERRUPTED` by the next
  worker start (the sweep `series` already has, reused).

### Tests

Bash tests in `tests/test_comfy.sh` (and `tests/test_config.sh` for the fields), through `tests/run.mjs`, against
`tests/stubs/wslc`: no container, no GPU. Covered: the field defaults and refusals, the two cross-field rules of
`COMFY_CONTAINER`; the admission of an EXISTING verb (`step`, and `series` through it) refused while `COMFY_CONTAINER` is
listed, and unchanged when it is not; `build` (the placed files and their
hashes, the build argv, the refusal of a build whose check container reports no ROCm device); `start` (refused while
`vllm` is listed, `--stop-vllm` stops it, the lock held → 4, the readiness wait and its ceiling); `stop`, `status`; `fetch`
(an unknown set, the argv with and without a store); `bench` (refused while the operator's ComfyUI is listed, the dry run,
one stubbed arm-round recorded, a part swept to `rejected/`, an arm-round without its arm's evidence rejected, a constant
output rejected, the reversed order of an even round, the bench cache cleared before every arm-round, the verdict over
stubbed rounds; the vLLM ship test's existing cases unchanged); `bench.py` and
`fetch_model.sh` against local fixtures (an HTTP stub of ComfyUI's `/prompt`, `/history` and websocket; a local file server
with and without `X-Linked-ETag`); the seam check over the new files. Not covered by CI, each with its acceptance record: the
real build, a real start on the card, a real fetch, the series.

### Documents

`research/module_comfyui.md` (new: purpose, the three traps with their evidence, the flows, the Mermaid diagram, the
growth); `research/architecture.md` (a module row, a verb row); `research/module_config.md` (the fields);
`research/module_tests.md` (the catalogue rows, covered and not covered); `README.md` (a ComfyUI section); the acceptance
record `research/ACCEPTANCE_comfy_<date>.md`; `POST_DEPLOY.md` only if an item meets its two conditions.

## Build order

1. Config fields and the `win?` type; adapter calls; their tests.
2. `comfyui/` files moved in from the hand-made folder with the machine values taken out; `comfy build|start|stop|status|fetch`;
   tests; documents. A real build, start and fetch on this PC.
3. `bench.py` fixtures and tests; `comfy bench` under the supervisor; the verdict lines; tests; documents.
4. The acceptance series on the R9700 and its record.

## Test plan

- Every test in `tests/run.mjs` green, in CI (`.github/workflows/tests.yml`) and locally under the runner's caps.
- Each new refusal has a test that was seen failing before its code existed.
- The acceptance runs: a build whose check container prints the R9700; `comfy start` then a `zimage` smoke from the
  browser's API port; `comfy fetch zimage wan5b` with the hashes printed; one `comfy bench zimage base fp16acc --rounds 1`
  as the first GPU run of the verb, then the full series.

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
mean nothing without the admission refusal beside them. Every design item lands in exactly one epic.

### E1 — ComfyUI from the repository: fields, adapter, image, five verbs, one owner of the card

The stories of this epic are [PLAN_comfyui_r9700_E1.md](PLAN_comfyui_r9700_E1.md) (written 2026-11-07; E1.S2 is the cornerstone).

**Goal.** A person with a `machine.env` runs `bin/r9700 comfy build|start|stop|status|fetch <set>` on any PC this toolkit
describes, and while their ComfyUI is listed no GPU verb of the toolkit starts a run beside it. The hand-made folder is not
needed; no machine value is in a tracked file.

**Scope.** Build-order steps 1 and 2 whole: the field table (with `win?` and the two cross-field rules); the three adapter
calls and the stub; `Containerfile`, `entrypoint.sh`, `fetch_model.sh`, `models.conf` moved in from the hand-made folder with
the machine values taken out, placed by `comfy_assets`; the five modes of the verb table in `lib/comfy.sh`; the admission
refusal in `step_run` — the one change to the existing verbs; their tests and the `fetch_model.sh` fixtures; the Documents
section except the bench parts and the acceptance record; the growth rows of the volumes and the placed copies. The
acceptance: the real build (its check container prints the R9700), the real start with a `zimage` smoke, the real fetch.

**Depends on.** Nothing new: the shipped toolkit (`config_load`, the adapter seam, `lock_take`, `step_run`, `moe_place`).

**Done when.**
- Every field is in the table, `machine.env.example` and `module_config.md`; a `COMFY_CONTAINER` with the prefix or equal to
  `PROD_CONTAINER` is refused before any container is touched.
- The refusals of the Tests section — `step` (and `series` through it) exit 2 naming `comfy stop` while `COMFY_CONTAINER` is
  listed and unchanged when it is not, `start` under a held lock and beside a listed `PROD_CONTAINER`, `build` whose check
  container sees no ROCm device, `fetch` of an unknown set or a changed hash — each seen failing before its code existed.
- The seam check and the personal-path check pass over the new files; CI green; the three acceptance runs are recorded.

**Cornerstone area.** GPU ownership: one owner of the card decided under the toolkit's lock — the admission refusal added to
every existing GPU verb, `start` holding the lock through the readiness wait, the prefix and name rules that keep
`container_stop_all` away from the operator's ComfyUI and from a fetch in progress. A mistake here stops the operator's work
or records an out-of-memory as a result, and no later step catches it.

### E2 — `comfy bench` under the supervisor, and the verdict over its records

The stories of this epic are [PLAN_comfyui_r9700_E2.md](PLAN_comfyui_r9700_E2.md) (written 2026-11-08; E2.S2 is the cornerstone;
its *Open points for the plan owner* list what this section leaves open or what the code and the hand runs have shown since).

**Goal.** `bin/r9700 comfy bench <workflow> <arm>...` measures ComfyUI arms as one supervised step under the measurement
contract, every arm-round recorded only when complete, and `bin/r9700 verdict` gives the ship test over those records.

**Scope.** Build-order step 3 whole: `comfyui/bench.py` with its HTTP and websocket fixtures; `comfyui/arms.conf` with the
five arms and the evidence each names; the worker `lib/comfy.sh bench` as `supervise` around one `step_run`, with every item
of the measurement contract, the refusal while `COMFY_CONTAINER` is listed, the part sweep and the fingerprint; the drift
numbers in the record, never gating; `lib/verdict.py` widened with a second mode (metric list, direction), the vLLM mode and
its tests unchanged; the `bench`, `bench.py` and verdict tests of the Tests section; the growth rows of the results folder and
the bench cache; the bench parts of the documents. The acceptance: `comfy bench zimage base fp16acc --rounds 1` on the card.

**Depends on.** E1 (the image, the volumes, the fields, the admission refusal, the model sets fetched).

**Done when.**
- Against the stub, each `bench` case of the Tests section passes and each refusal was seen failing first; an
  `execution_error` fails the run at once; the bench cache is cleared before every arm-round; an even round runs reversed.
- `bench.py` against the fixtures prints `sampler_s`, `vae_s`, `total_s` per measured run and nothing for the cold run.
- The comfy mode of `verdict.py` passes an arm whose median is below the base's spread, fails one above it, decides nothing
  for an incomplete arm and prints exact decimals; every existing vLLM case unchanged.
- The first bench run on the R9700 is recorded with its `vram_free` value, its cold-run time and its outputs.

**Cornerstone area.** The measurement contract: what one arm-round is (the isolated container, the cleared cache, the cold
run, the three same-seed measured runs, the `vram_free` wait), what fails it (`execution_error`, an invalid output, missing
arm evidence) and what is recorded. ComfyUI's execution cache and model offload make a run that looks like a measurement and
is not one, and every claim of E3 rests on this record. The bench container's isolation and cleanup, which the consultants
named under GPU ownership, sit here, because the stub tests of this area are what exercise them.

The verdict widening is not a cornerstone: the rule exists and is pinned by the vLLM mode's test cases, and the comfy mode's
test is a table of numbers where a wrong direction or a lost decimal shows before any GPU time is spent.

### E3 — the acceptance series on the R9700 and its record

**Goal.** One `zimage` series and one `wan5b` series have run on the card, and `research/ACCEPTANCE_comfy_<date>.md` says
which arms are faster than the base by more than the base's own spread, under which conditions, with the prediction written
before and the observation after, the outputs looked at, and what it does not settle.

**Scope.** Build-order step 4 whole: the prediction copied into the record before any run; the `wan5b` feasibility run (timed,
memory read, the VAE choice into the workload identity, the video round count set from it); the two series and the verdict
over each; the drift numbers and the outputs side by side under the record; the inert arms reported as inert; the owner's
TTS question recorded; the DoD ticks; `POST_DEPLOY.md` only if an item meets its two conditions; the promotion of this plan.

**Depends on.** E1 and E2.

**Done when.**
- The feasibility run's time, memory readings and the VAE choice are in the record before the video series starts.
- Both series completed under the supervisor with one restore of the operator's vLLM; every arm-round is in `rounds/` with its
  evidence or in `rejected/` with its reason.
- The record holds, per arm and workload: prediction, observation, the verdict line, the drift numbers, the conditions
  (image id, `COMFY_REF`, model hashes, the VAE choice); the owner looked at the outputs and the record says so; a result
  inside the base's spread is written as not decided; "quality equal" appears nowhere. The plan is promoted with its deviations.

**Cornerstone areas.** None. E3 runs E1's and E2's code and writes prose; an incomplete or unproven arm-round is what E2's
checks reject, and the reading of the numbers is what the measurement rule already governs.

Cornerstones: 2 of 2 — E1.S2 (GPU ownership, [PLAN_comfyui_r9700_E1.md](PLAN_comfyui_r9700_E1.md)), E2.S2 (the measurement
contract, [PLAN_comfyui_r9700_E2.md](PLAN_comfyui_r9700_E2.md)).
