# PLAN — E2 stories: `comfy bench` under the supervisor, and the verdict over its records

> Status: **plan only, nothing implemented yet; the epoch-2 version, 2026-11-08** (rewritten after the parent's re-review,
> which cut the epoch-1 version 8814640 and kept its split; written against the parent at bd36c56). Scope: the three stories of
> epic E2 of [PLAN_comfyui_r9700.md](PLAN_comfyui_r9700.md), section
> [E2 — `comfy bench` under the supervisor, and the verdict over its records](PLAN_comfyui_r9700.md#e2--comfy-bench-under-the-supervisor-and-the-verdict-over-its-records):
> the comfy mode of the ship test, the arm-round and its measurement contract, the verb `comfy bench` with the verdict over its
> folder, the documents and the first bench runs on the R9700. Cornerstone: E2.S2 (`model: fable`), recorded in the parent's
> ledger line (`PLAN_comfyui_r9700.md:614–616`).

This document splits E2 into stories. It adds no scope to E2 and removes none. Every line number of the parent below is of
the parent at bd36c56. The eight open points of the epoch-1 version are settled in the parent (*Settled in epoch 2*, at the
end); what this rewrite found that is still open is under *Open points*. The parent plan keeps the change ledger; this document
has none of its own (plan-change-control: a stories document keeps no ledger).

## Stories at a glance

| Story | Title | Spec by | Code by | Depends on | Cornerstone |
|---|---|---|---|---|---|
| E2.S1 | The comfy mode of the ship test: `lib/verdict.py comfy` and `comfy-check-block` | Opus (this document) | Sonnet | nothing in E2 | no |
| E2.S2 | The arm-round and its measurement contract: `comfyui/bench.py`, `comfyui/arms.conf`, `comfyui/arm_evidence.conf`, the `wan5b` LoRA pin, the worker `lib/comfy_bench.sh`, the record, the resume and the identity | **Fable** — `model: fable` | Sonnet | E2.S1 (the line grammar and the block check) | **yes** — the parent's area *the measurement contract* (`:573–578`) |
| E2.S3 | The verb `comfy bench` under the supervisor, `verdict` over a bench folder, the documents, the first bench runs on the R9700 | Opus (this document) | Sonnet | E2.S2 (the seam below); for the runs on the card, E1's acceptance runs 1 and 2 (`:558–559`) | no |

Order: S1, then S2, then S3. Fable may write the S2 spec at once: it needs only S1's line grammar (this document), the
parent at bd36c56 and E1's merged code. S2 is coded after S1 is merged (its validation calls S1's block check). S3 is coded
after S2 is merged (it calls the seam S2 provides). Every story is reviewed by Opus and fixed by Sonnet (subagent-models,
per-story pipeline).

**The cut** (kept from the epoch-1 version; the re-review kept it, `:34`). The parent's cornerstone area is the measurement
contract: what one arm-round is (the isolated container, the cleared cache, the cold run under its ceiling, the three same-seed
measured runs, the `vram_free` wait), what fails it (`execution_error`, an invalid output, `COLD_TIMEOUT`, missing activation
evidence) and what is recorded (the flags, the evidence, the identity that admits a resume and refuses another experiment)
(`:573–578`). Most of that contract runs inside the container, in `bench.py` (the run sequence, the seeds, the ceilings, the
fast failure, the output check), and the rest in the worker (the container, the cache, the evidence, the validation, the
record, the resume, the identity). A cut between `bench.py` and the worker would give one contract two authors, so S2 holds
both, with the arm and evidence tables and the `wan5b` LoRA pin (the workload's identity). S1 is the verdict widening, which
the parent says is not a cornerstone (`:580–581`). S3 is the wiring every other GPU verb already has (the grammar,
`supervise`, the resume count, the dry run), the verdict over a bench folder, the documents and the runs on the card.

## Coverage — every E2 item is in exactly one story

The parent's E2 *Scope* (`:544–556`), *Done when* (`:561–571`), the measurement contract (`:235–288`), the tuning series
(`:290–364`), the records and growth (`:382–409`), the tests (`:421–438`) and the documents (`:440–448`), item by item. Where a
later story extends a file an earlier one creates, the row says which part each writes. Nothing below is in two stories.

| E2 item (parent plan) | Story | The other stories' part |
|---|---|---|
| The comfy mode of `lib/verdict.py`: a metric list, the deciding metric, a direction, NOT DECIDED inside the spread; the vLLM mode and its tests unchanged (`:159`, `:355–364`, `:544–545`) | S1 | S2's validation calls its block check; S3's verdict calls its mode |
| PASS beyond the spread in the better direction, FAIL beyond it in the worse one, NOT DECIDED inside, nothing for an incomplete arm, exact decimals (`:567–569`) | S1 | — |
| `comfyui/bench.py`: the workflows with every input pinned, the queue, the node times over the websocket, the verdict-grammar lines, a JSON per run, `run_max_s` and `cold_max_s` per workload, `workflows` and `metrics` on the host (`:176`) | S2 | — |
| The two workloads' constants: `zimage` (`:316–317`) and the FastWan 3-step text-to-video `wan5b` with its LoRA, its named tile fields and an empty negative prompt (`:318–328`) | S2 | — |
| The LoRA line of `wan5b` in `comfyui/models.conf`, its sha256 pinned (`:163`, `:175`, `:547–548`) | S2 | S3's acceptance fetches it on the card |
| `bench.py` against local fixtures: an HTTP and websocket stub of `/prompt`, `/history`, `/ws`, `/system_stats` (`:421–422`, `:429–430`); the lines for the measured runs only, a load or a recompile flagged (`:565–566`) | S2 | — |
| `comfyui/arms.conf` with the six arms in the four-field grammar, and `comfyui/arm_evidence.conf` with the activation and inertness evidence of each (`:158`, `:177–178`, `:297–306`) | S2 | — |
| The measurement contract: isolation with `--tmpfs /data:exec,size=8g` and the read-only models volume, one fresh container per arm-round, every ceiling ends the container, the round, `COLD_TIMEOUT`, the load and recompile flags, failure is fast, the output check, the free card, the evidence, the balanced order, a lost run expected (`:235–288`) | S2 | — |
| The worker `lib/comfy_bench.sh` (two faces) as ONE step (`:164`, `:229`, `:548–549`) | S2 (the worker) | S3 (`supervise` around one `step_run`, in `lib/comfy_bench_verb.sh`) |
| The part sweep and the resume of the same experiment; another experiment refused (`:161`, `:284–288`, `:408–409`, `:563–564`) | S2 | S3's end-to-end resume scenario |
| The fingerprint through `lib/fingerprint.py` widened (`:160`, `:384–387`, `:551`) | S2 (its components, build, compare) | S3 calls it before admission |
| The drift numbers in the record, never gating (`:370–377`) | S2 | — |
| The refusal while `COMFY_CONTAINER` is listed: `supervise`'s owner check, after the lock (entry 1.2, `:22–25`, `:207–215`, `:229`) | S3 (it adds no check of its own) | — |
| `bin/r9700 verdict` over a bench folder (`:542`, `:159`) | S3 | uses S1's mode |
| The pinned test requirements (`:430–434`, `:551`, `:462–463`) | S2 (its tests are the first to need them) | — |
| The stub learns the bench container, the `exec` of `bench.py` and the clear container (`:162`) | S2 | S3 uses it |
| The bench cases of the Tests section: refused beside ComfyUI and exit 4 under a held lock, the dry run, one arm-round end to end, a re-run that continues, the verdict over stubbed rounds (`:422–429`) | S3 | the worker cases (one stubbed arm-round recorded, a part swept, missing activation evidence rejected, an inert arm reported, `COLD_TIMEOUT`, a constant output and a truncated video rejected, the load and recompile flags, the reversed order, the cache cleared) are S2's |
| The growth rows of the results folder and the bench cache (`:382–409`, `:552`) | S2 (the sizes and the sweeps, in this document's growth table) | S3 writes them into `research/module_comfyui.md` |
| The bench parts of the documents and the tile-field correction at `research/module_comfyui.md:106` (`:126`, `:442–444`, `:552–553`) | S3 | — |
| `research/module_tests.md` | each story its own rows | — |
| The acceptance: `comfy bench zimage base fp16acc --rounds 1` with `fp16acc` reported inert with its evidence; `comfy bench wan5b base --rounds 1` with its first clip looked at for the hatching; `verdict` over each folder; the engine features of OP8 observed; the operator's cache volume measured once (`:553–556`, `:570–571`) | S3 | run by the operator's session after S2 and S3 are merged and after E1's acceptance runs 1 and 2 |
| The seam check and the personal-path check over the new files; CI green | every story | — |

Out of E2 (E3; not built here, `:589–595`): the `wan5b` feasibility run (`:332–341`), the two series and their verdicts, the
owner's look at the series' outputs, the TTS question and the faster tiled decode as questions for the owner,
`research/ACCEPTANCE_comfy_<date>.md`, `POST_DEPLOY.md`, the promotion of the plan. Also out (in no epic of the plan): `comfy
bench` as a step of `bin/r9700 run` (`lib/run_plan.sh` keeps its list of steps), any change of `comfy start`, `stop`,
`status`, `build` or `fetch`, and any new `machine.env` field (`:195–197`).

## Facts every story uses (read 2026-11-08, code at 6be7a67, the parent at bd36c56)

**What E1 left (merged as PR #18).**

- `lib/comfy.sh` is **747 lines** (the house limit is 800, coding-style): hence the file split of `:164`. It holds the modes
  `start`, `stop`, `status`, `build`, `fetch`; `comfy_modes` (`:44`) derives the legal modes from the functions
  `comfy_mode_<mode>` with `declare -F`, so a mode defined in another sourced file is a mode too; `comfy_locked` (`:50`),
  `comfy_volume_ensure <name> <listing> [<mode>]` (`:76`, list first, create only a missing volume), `comfy_models_load`
  (`:459`, every line four words, folder `^[a-z_]+$`, an https URL, a 64-hex pin), `comfy_assets` (`:435`, the three placed
  files), `comfy_win_dir` (`:442`), `_COMFY_CONTAINER_DIR=/work/r9700/comfyui` (`:410`), the placement call `local
  _MOE_PLACED_BY=comfy; moe_place comfy_assets` (`:578–579`).
- `bin/r9700` sources its libraries in one list (`:43`), ending with `comfy`. `verb_comfy` (`:589–603`) dispatches to
  `comfy_mode_<mode>`. `verb_verdict` (`:172–180`) runs `restore_first` under the lock when a marker exists, then
  `series_verdict "$@"` — it knows one kind of results folder.
- `supervise <verb> <prepare> <body>` (`lib/run_guarded.sh:503`): `lock_take` (`:508`), `restore_first` (`:509`), the prepare
  (`:510`), E1's owner check `_rg_card_free` (`:511`, defined at `:487–493`: the container list, then `comfy_owner_check`; exit
  2 with the one owner line naming `bin/r9700 comfy stop`), `deadline_compute` (`:512`), `run_dir_new` (`:513`), the traps, the
  body, `cleanup_once`. `cleanup_once` (`:661`) stops every prefixed container (`container_stop_all`, `lib/restore.sh:159`, the
  prefix match at `:167`) and runs at most ONE registered hook (`cleanup_hook_set`, `:619`). A lock held by another run is exit
  4 at `:508`, before the owner check: entry 1.2.
- `step_run <label> -- <command...>` (`lib/step.sh:238`) admits the worker (`_step_admit`, `:111`: the disk gate, the list, E1's
  `comfy_owner_check` at `:117`, the stop cap, the marker, the stop of the operator's server, the worker in its own session) and
  settles its outcome (`_step_settle`, `:199`): worker exit 0 done; 3 not quiet (wait, no try counted); 4 nothing more fits (the
  deadline); an outcome `KIND=refused` is a refusal (exit 2, no retry); anything else is a failed try, retried up to
  `MAX_FAILED_TRIES`. A guard's stop (`ram_guard`, `deadline`) stops every prefixed container before a retry (`:189`, `:193–196`).
- `bin/r9700 step [--model <m>] <label> -- <command...>` (`:195–224`) runs ANY command as one guarded step. S2's worker can be
  tested through it before S3's verb exists.
- `config_load_machine` (`lib/config.sh:484`) loads the machine file alone. No verb under `supervise` uses it yet: every
  `supervise` user loads a model file (`prepare_run`, `bin/r9700:184`). Whether a function under `supervise` reads a model key is
  not known; S3's first end-to-end test shows it.

**The patterns E2 reuses** (the parent's reuse table, `:150–166`).

- A two-faced library: SOURCED it defines the supervisor's half, RUN as `bash lib/<x>.sh <args>` it is the worker
  (`lib/series.sh:2–5`, `:534–541`; `lib/kernels.sh:3–5`, `:352–358`). The worker sets no trap, takes no lock, never stops the
  operator's server.
- The arm-round record of a series (`lib/series.sh:17–21`): `rounds/<arm>-<round>.part-<run id>/` while it is built, ONE rename
  to `rounds/<arm>-<round>/` after the validation, `rejected/<tag>-<UTC stamp>/` with a `reason` file (`_series_reject`, `:256`),
  the sweep of a part a killed worker left (`series_sweep_parts`, `:267–274`), the count of what is left (`series_left`, `:55`),
  `record.env` (`:401`), the identity re-checked at the start of every arm-round (`_series_recheck`, `:413`), the gate before
  every arm-round (the disk gate, the quiet check, the time fit with `R9700_ARM_SECONDS`, `_series_gate`, `:287–296`). The series
  runs the arms in ONE order every round (`series_main`, `:474–480`); the bench reverses even rounds (`:282–283`).
- The fingerprint (`lib/fingerprint.py`): `compare`, `compare --merge` (a new arm or more rounds is an extension) and `show`
  are generic over a version-1 document `{"version", "sha256", "components"}` (`:188–298`); `show` of a leaf that is not there
  exits 2 (`:283`); a document whose digest does not match is refused (`:199–200`). `build` is vLLM-only (`MODEL_KEYS`,
  `:39–43`, `build_components`, `:129`). `series_fingerprint` (`lib/series.sh:148`) builds before admission and refuses a
  fingerprint over records whose identity is lost (`:152–155`).
- The cache clear of the MoE units (`lib/moe.sh:69–90`): a prefixed throwaway container with only the cache volume, which
  prints the sizes (`du -sh`) and removes; a clear that fails before a unit refuses the unit (`KIND=refused`), the clear in the
  cleanup is best effort.
- The verb half of a measurement (`lib/kernels_verb.sh:164–188`): the placement, the dry run, the same-experiment check and the
  recorded count before admission, then ONE `step_run`. The series grammar (`bin/r9700:228–265`): `--rounds` 1..20, `--out`
  matched by `_SERIES_OUT_RE` (`:229`), an arm name `_RE_ARM` (`lib/config.sh:102`), an arm given twice refused.
- The adapter calls (`lib/adapter.sh`): `wslc_run <name> <args...>` is always `run -d --rm --name` (`:291–298`); `wslc_exec`
  (`:300`), `wslc_run_once` (`:320`), `wslc_stop` (`:356`), `wslc_logs` (`:369`); `comfy_probe` (`:521`) runs `_COMFY_PROBE_PY`
  (`:87–107`), which reads `devices[0].name` of `/system_stats` and prints `device <name>` and `ready`; the parent asks for a
  probe that also returns `vram_free` and `vram_total` (`:155`). `container_name <label>` (`lib/serve.sh:104`) prefixes a label
  `^[a-z0-9][a-z0-9-]{0,39}$` (`:102`); `container_host_path` (`:93`) maps `/work/...` to `$WORK_DIR/...`.
- The arm grammar (`lib/config.sh:545–571`): four fields `name | serve arguments | environment | mounts`, exactly three `|`;
  `arms_load` (`:573`), `arm_args`, `arm_env`, `arm_mounts` (`:622–624`), `_arm_known` (`:607–611`), `arms_check` (`:626`,
  mounts under `PATCH_DIR`). The evidence is NOT in it: `comfyui/arm_evidence.conf` is a second table (`:158`, `:178`), so
  `arms_load` and `config/arms.conf` do not change.

**The image the bench runs** (`comfyui/`).

- `entrypoint.sh` makes the folders of `/data`, `/models` (the `loras` folder among them), `/cache` (`:10–14`), makes a
  `--system-site-packages` venv on `/data` at the first start (`:28–31`) — so `/data` must allow exec, hence
  `--tmpfs /data:exec,size=8g` (`:243–246`) — and starts `main.py --listen 0.0.0.0 --port 8188 --base-directory /data
  --models-directory /models --enable-manager "$@"` (`:46–51`): ComfyUI's arguments after the image are appended. ComfyUI's
  outputs go to `/data/output` unless an argument says otherwise.
- `Containerfile` installs `ffmpeg` (`:17`, so `ffprobe` is there); `MIOPEN_USER_DB_PATH` and `MIOPEN_CUSTOM_CACHE_DIR` are
  `/cache/miopen`, `TRITON_CACHE_DIR` is `/cache/triton` (`:48–50`); it does NOT set `PYTORCH_HIP_ALLOC_CONF` (trap 1, `:41–43`).
  ComfyUI's own requirements are installed with the base's ROCm packages as constraints (`:27–29`).
- `comfyui/models.conf` pins the files of `zimage` (`:16–18`) and `wan5b` (`:19–21`) with their sha256; E2 adds one `wan5b` line
  in the `loras` folder (`:175`).
- The volumes the bench must NOT touch: `COMFY_DATA_VOLUME` and `COMFY_CACHE_VOLUME` (the operator's). The models volume
  `COMFY_MODELS_VOLUME` is mounted read-only (`:239`).

**What the card taught after the approval** (the parent's facts 1–7, `:112–146`; hand runs, one run or one sweep each): the
20-step `wan5b` output carries a hatching, FastWan 3 steps is clean at about 122–143 s (`:118–124`); the untiled decode stalls,
two named tile settings (`:125–130`); a long-running server fails later work, so one fresh container per arm-round (`:133–135`);
the negative prompt is inert at cfg 1 (`:136–137`); the host lost two GPU runs, so a lost arm-round is expected (`:138–139`); the
screening of the arms on `zimage` (`:140–146`). `research/module_comfyui.md:106` (the tile fields, in an ambiguous order) and
`:107` (the hatching) are the repository's record of facts 1 and 2; E2.S3 corrects the field order at `:106` (`:126`).

**What the hand-made scripts show** (the operator's hand-made folder, outside every repository; the main session gives its
location; nothing of its paths or names goes into a tracked file). They ran on the R9700 on 2026-11-07/08:

- The bench prototype `bench.py` runs inside the container through `wslc exec` with the image's `python` and `aiohttp` (`:4`,
  `:17`). One run (`:89–121`): open the websocket `/ws?clientId=<uuid>`, `POST /prompt` with the graph and the client id, time
  from the POST until the `executing` message with `node: null`; a node's time is from its `executing` message to the next one;
  an `execution_error` message ends the run at once; after the run `GET /system_stats` gives `devices[0]` (its `vram_free`).
  Seeds are `4242 + i` for run `i` (`:143`), run 1 the cold run. It reads ComfyUI's own argv from `/system_stats` `system.argv`
  (`:140–141`). The `zimage` graph (`:37–52`): `UNETLoader` + `CLIPLoader lumina2` + `VAELoader`, `ModelSamplingAuraFlow`
  shift 3.0, `EmptySD3LatentImage` 1024×1024, `KSampler` 8 steps `res_multistep` `simple` cfg 1.0, `VAEDecode`, `SaveImage`.
  The `wan5b` graph (`:55–77`, the 20-step image-to-video form the parent replaced): `UNETLoader` + `CLIPLoader wan` +
  `VAELoader`, `ModelSamplingSD3`, `Wan22ImageToVideoLatent`, `KSampler`, `VAEDecodeTiled` with the four named fields,
  `CreateVideo` 24 fps, `SaveVideo`. `compile` puts `TorchCompileModel` (backend `inductor`) between the loader and the shift
  node (`:83–86`). The prototype does NOT check the output, wait for free memory, keep the log per run, or know arms.
- The LoRA trial `lora_try.py` puts `LoraLoaderModelOnly` (`strength_model` 1.0) between `UNETLoader` and `ModelSamplingSD3`
  (`:46–52`); the FastWan file it loaded is `Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors` (`:21`), run at 3 steps,
  `lcm`, `simple`, cfg 1, shift 8 (`:25`). Its source URL is not in the script. It polls `/history/<prompt id>` and reads
  `status.status_str` and `status.messages` as `[name, {"timestamp": …}]` pairs (`:60–69`): the shape of a `/history` entry's
  status was seen by hand there, nowhere in the repository.

**The tests and the checks.**

- `tests/run.mjs` runs `test_*.py` with the repository's `.venv` python and pytest (`:319–329`); `tests/requirements.txt` holds
  `pytest` and its four dependencies only. The parent pins `aiohttp`, `numpy` and `Pillow` there in E2, "the same major versions
  as the image's" (`:430–434`); CI installs the file (`.github/workflows/tests.yml:34`).
- `tests/test_comfy.sh` OC1 derives the verbs under `supervise` from the code lines (`supervised_verbs`, `:25–27`) and holds one
  legal command line per verb (`OC1_ROWS`, `:31`; `oc1_run`, `:34–43`): a new `supervise comfy …` call without a row fails it.
- `tests/test_comfy_start.sh:40–46` (CS1) compares the mode line with `comfy_modes` in the test shell, and
  `tests/lib/comfycase.sh:21` sources `lib/comfy.sh` only: a mode defined in a new file is missing from the test's list unless
  `comfycase.sh` sources that file too.
- `tests/test_comfy.sh` MC1 checks every line of the real `comfyui/models.conf` (E1): the LoRA line must pass it.
- `tests/test_verdict.py` (47 tests) pins the vLLM ship test; `tests/test_series_verdict.sh` pins `bin/r9700 verdict` over a
  series folder.
- `tests/check_static.sh`: every tracked `*.sh` gets `bash -n` and every `*.py` a compile; the personal-path scan (`:19–28`); the
  seam (only `lib/adapter.sh` names `wslc` as a command word or expands `$R9700_WSLC` — a message in `lib/*.sh` says "the engine",
  never `wslc`); `README.md` and the research documents may not hold `planned`, `E3 will` or `not built yet` (`:32–41`).
- `tests/test_docs.sh`: every test file has a row in `research/module_tests.md` (DOC7, `:131`); every file of `lib/` and `bin/` is
  named in `research/architecture.md` (DOC8, `:141`); every verb is in the README and the architecture verb table (DOC9, `:154`).
  `tests/test_lifecycle.sh:432`: the three exit tables agree.
- Test knobs come from the environment only, each with a row in *Test knobs* of `research/module_tests.md` (`:125`); stub answers
  live under `$R9700_STUB_DIR` and are listed in the header of `tests/stubs/stub_common.sh` (`:5–46`). A test writes only below
  `$R9700_TEST_ROOT`; no `mktemp`, `mkdtemp` or `TMPDIR`; a process a test starts is recorded so the runner kills it.

**Observed with `wslc` on 2026-11-08** (the parent, `:243–246`): `--tmpfs /data:exec,size=8g` mounts a writable tmpfs; a plain
`--tmpfs /data` is `noexec`; the models volume with `:ro` refuses a write ("Read-only file system").

**Not verified anywhere in this repository** (each is ComfyUI's, PyTorch's or the engine's behaviour by their documentation or
by the parent's text, not an observation here; S2's spec decides how each is checked, and S3's acceptance observes each on the
card):

1. Whether `wslc run -v <volume>:<path>` makes a missing named volume, or fails (E1 always lists, then creates: `lib/comfy.sh:76`).
2. Whether a process started by `wslc exec` sees the environment the container was started with (`-e`): `bench.py` runs through
   `exec` and reads `COMFY_BENCH_WEIGHT_DTYPE` (`fp8w_mm`) and `COMFY_BENCH_COMPILE` (`compile`) (`:303`, `:306`).
3. `/system_stats` `devices[0].vram_total` (the prototype reads only `vram_free`; E1's probe only `name`).
4. ComfyUI's websocket messages other than `executing` and `execution_error` (`execution_start`, `execution_cached`,
   `execution_success`), and a `/history/<prompt id>` entry's `outputs` (its `status` was seen by hand, above).
5. The log lines the evidence table names (`:301–306`): `Using pytorch attention`, `Enabled fp16 accumulation`, the model's and
   the VAE's dtype lines, the loader's `float8_e4m3fn` weight dtype line, `cudnn.enabled = False`, MIOpen's find lines; ComfyUI's
   model load and unload lines; the line `TORCH_LOGS=recompiles` prints.
6. When PyTorch's TunableOp writes `PYTORCH_TUNABLEOP_FILENAME`, and the names and meaning of
   `PYTORCH_TUNABLEOP_MAX_TUNING_DURATION_MS` and `PYTORCH_TUNABLEOP_MAX_TUNING_ITERATIONS` in the image's torch (`:304`; open
   point N2).
7. Where the inductor writes its cache inside the container (open point N3).
8. The versions of `aiohttp`, `numpy` and `Pillow` in the image (the pins of `:430–434` follow them; the repository's image is
   built first by E1's acceptance run 1).

## The seam between S2 and S3

S3 is written in full against this seam; S2 provides it. Fable may rename a name or add an argument: the S2 spec then says so in
one line, and S3's coder follows the spec. What may not change is what each one is for.

| Name | Provided by S2 (`lib/comfy_bench.sh`, sourced) | Used by S3 |
|---|---|---|
| `bash lib/comfy_bench.sh <outdir> <workflow> <rounds> <arm>...` | the worker: the arm-rounds of the invocation not yet recorded, in the balanced order, continuing from the first missing one; exit 0 done, 1 an arm-round was rejected or the disk gate stopped, 3 not quiet, 4 nothing more fits before the deadline, a refusal as `KIND=refused` (the series worker's codes, `lib/series.sh:23–24`) | `step_run comfy-bench -- bash …` |
| `comfy_bench_workflows` | the legal workflow names, one per line, sorted, derived from `bench.py` (never typed twice); the standard library only | the grammar check before the lock |
| `comfy_bench_metrics` | the metrics of a block, one line, space-separated, the deciding one first (`total_s sampler_s vae_s`), from the same place `bench.py` prints them | the verdict's `--metrics` and `--decide` |
| `comfy_bench_arms_conf`, `comfy_bench_evidence_conf` | `${R9700_COMFY_ARMS_CONF:-<repository>/comfyui/arms.conf}` and `${R9700_COMFY_EVIDENCE_CONF:-<repository>/comfyui/arm_evidence.conf}` (test knobs, the shape of `series_arms_conf`) | S3's tests point them at copies |
| `comfy_bench_check <workflow> <rounds> <arm>...` | after the machine config: both tables load, every arm is in the arm table AND has an evidence row, every container label the worker will use fits; 2 and one line per problem | the prepare |
| `comfy_bench_assets` | `<placed name> <repository source> <required\|optional>` per line: at least `comfyui/bench.py` | `moe_place comfy_bench_assets` before admission |
| `comfy_bench_fingerprint <outdir> <workflow> <rounds> <real\|dry> <arm>...` | build `<outdir>/fingerprint.json`, or compare and merge an extension (a new arm, more rounds); another experiment: `fingerprint differs: …` lines on stderr and 2; a missing `COMFY_IMAGE`: 2 naming `bin/r9700 comfy build`; `dry` writes nothing | before admission |
| `comfy_bench_left` / `comfy_bench_recorded <outdir> <rounds> <arm>...` | the counts of arm-rounds with no final record / with one | the resume count before admission |
| `comfy_bench_dry_run <outdir> <workflow> <rounds> <arm>...` | prints `dry-run: <command>` lines of the first arm-round, starts nothing | `--dry-run` |
| The folder | `<outdir>/fingerprint.json` with the leaves `kind` (= `comfy`), `workflow`, `base`, `rounds`, `arms` (`:384`); `<outdir>/rounds/<arm>-<round>/bench.txt` holding exactly one complete block of S1's grammar | the verdict and its dispatch |

## E2.S1 — The comfy mode of the ship test: `lib/verdict.py comfy` and `comfy-check-block`

**Cornerstone:** no (`:580–581`). **Depends on:** nothing in E2. **Spec:** this section (Opus). **Code:** one Sonnet coder.

### Goal

`lib/verdict.py` gets a second mode that applies the RULE of the first (`lib/verdict.py:8–11`; the parent `:358–360`): an arm's
median against the base's spread over ALL the base's values (rounds × runs), exact decimals, and an arm with a missing arm-round
is never PASS or FAIL. The groups are one workflow's metrics, one metric decides, and the direction is a parameter (seconds:
lower is better). A median inside the spread is `NOT DECIDED`, never FAIL (`:352–353`, `:361–364`). A block check for the same
grammar lets S2's worker validate one arm-round before its record becomes final. The vLLM mode, its grammar, its output and its
47 tests do not change.

### The line grammar (S2's `bench.py` prints it; this story owns it)

```text
<arm>-<round> <workflow> r=<n> <metric>: <value>
fp16acc-2 zimage r=3 total_s: 12.345
```

`<arm>` `[a-z0-9]+`, `<round>` `[1-9][0-9]*`, `<workflow>` `[a-z0-9]+`, `<n>` one of the three measured runs `1 2 3`, `<metric>`
`[a-z][a-z0-9_]*`, `<value>` a non-negative decimal `[0-9]+(\.[0-9]+)?` (seconds). The arm names of the parent (`base`,
`fp16acc`, `fp8w_mm`, `tunableop`, `miopen`, `compile`, `:301–306`) hold an `_` in one case: **`fp8w_mm` does not match
`[a-z0-9]+`** — open point N1. Until it is settled, this story's grammar is the parent's arm grammar (`_RE_ARM`,
`lib/config.sh:102`, `[a-z0-9]+`) and N1 names the one place that changes. A COMPLETE block of a tag is exactly one line for every
pair (run 1..3, metric of `--metrics`): 9 lines for the three metrics. A block starts at its `r=1 <first metric>` line (the vLLM
mode's `split_blocks` rule, `:117–125`, with another start key). The three runs are one constant, `COMFY_RUNS = (1, 2, 3)`,
beside `REPEATS` (`:35`), with a comment naming the parent's contract (`:252–254`).

### The rule

For the deciding metric `d` (`--decide`) and each judged arm: the arm's values are `d` of every run of every round
`1..--rounds`; the base's the same. `stat_of` (`:163`) gives the median, the base median, delta = median − base median and the
spread = max − min of the base's values; `word_of` (`:168`) gives one of `higher`, `within, not lower`, `within, lower`, `lower`.
Then, with `--direction lower`:

| word | verdict | reason printed |
|---|---|---|
| `lower` | PASS | — |
| `higher` | FAIL | `<d> higher than the base by more than its spread` |
| `within, lower`, `within, not lower` | NOT DECIDED | `inside the base spread` |

`--direction higher` mirrors it (`higher` passes, `lower` fails with `<d> lower than the base by more than its spread`). A missing
arm-round of the arm or of the base is INCOMPLETE with the vLLM mode's reasons (`missing_tags`, `:246`; `evaluate`, `:255–266`).
The other metrics of `--metrics` are computed the same way and printed as information; they never decide (`:362–363`).

### Files

| File | Change |
|---|---|
| `lib/verdict.py` | the commands `comfy` and `comfy-check-block`; the docstring; shared code widened, not copied (brief) |
| `tests/test_verdict_comfy.py` | new: VC1–VC13 |
| `research/module_tests.md` | the row of `tests/test_verdict_comfy.py` with the scenario ids; the `lib/verdict.py` line of *What it does not prove* says the comfy grammar is the one this story fixed and is checked against a real `bench.py` output first by E2.S3's acceptance |

`tests/test_verdict.py` is NOT edited.

### Test scenarios

All in `tests/test_verdict_comfy.py`, calling `lib/verdict.py` as a subprocess (`python3 -I`, the shape of `run`,
`tests/test_verdict.py:22–26`) on bench files the test writes below pytest's `tmp_path`. "The three metrics" are
`--metrics "total_s sampler_s vae_s" --decide total_s --workflow zimage`. "Base B" is: `total_s` of rounds 1, 2, 3 =
`12.000 12.010 12.020`, `12.030 12.040 12.050`, `12.060 12.080 12.100` (median 12.040, spread 0.100), `sampler_s` all `10.000`,
`vae_s` all `1.500`. An arm is written the same way with its own values. RED first means: the test is written and run before the
code, the failure is the real symptom (here: argparse's `invalid choice: 'comfy'`, exit 2), and the coder's summary records it.

- VC1 *An arm below the base's spread passes, and the lines are exact.* Base B; arm `fp16acc` with `total_s` all `11.900`,
  `sampler_s` all `9.800`, `vae_s` all `1.500`; `comfy --base base --arm fp16acc`, `--direction lower`, `--rounds 3`: exit 0;
  stdout holds exactly `arm fp16acc vs base: 3 rounds, 9 values per metric`, `  total_s: median 11.900 vs 12.040, delta -0.140,
  base spread 0.100 -> lower`, `  sampler_s: median 9.800 vs 10.000, delta -0.200, base spread 0.000 (information)`, `  vae_s:
  median 1.500 vs 1.500, delta +0.000, base spread 0.000 (information)`, `verdict fp16acc: PASS`. RED first.
- VC2 *An arm above the base's spread fails.* Arm `slow`, `total_s` all `12.200`: `verdict slow: FAIL (total_s higher than the
  base by more than its spread)`, the `total_s` line ends `-> higher`; exit 0.
- VC3 *An arm inside the spread is NOT DECIDED, never FAIL.* `total_s` all `12.050` (`-> within, not lower`) and all `12.000`
  (`-> within, lower`): each `verdict <arm>: NOT DECIDED (inside the base spread)`; exit 0.
- VC4 *Exactly one spread below is inside, by exact decimals.* Base `total_s`: four values `1.100`, one `1.200`, four `1.400`
  (median 1.200, spread 0.300); arm all `0.900` (delta −0.300): `-> within, lower`, NOT DECIDED. Companion (the trap is alive):
  in the test, `0.9 - 1.2 < -(1.4 - 1.1)` in binary floats is True — a float version would have said PASS. RED first: a first
  version that computes in float passes the arm.
- VC5 *A missing arm-round decides nothing.* `--rounds 3`, arm `fp16acc` with rounds 1 and 3 only: `arm fp16acc vs base: 2 of 3
  rounds complete`, `verdict fp16acc: INCOMPLETE (missing complete arm-rounds: fp16acc-2)`, exit 1, no `total_s` line. A block of
  `fp16acc-2` without its `r=3 vae_s` line: the note `ignored incomplete block: fp16acc-2, 8 lines from <file>:<line>` and the
  same INCOMPLETE. Base without round 3: the reason holds `base base missing complete arm-rounds: base-3`. A later complete block
  of the same tag wins with the note `superseded complete block: …` (the vLLM rule, `pick_blocks`, `:137`).
- VC6 *The direction is a parameter.* VC1's files with `--direction higher`: `verdict fp16acc: FAIL (total_s lower than the base
  by more than its spread)`; VC2's `slow` passes.
- VC7 *Three places, half-even, from exact decimals.* `--rounds 2` (six values each): an arm whose sorted `total_s` has `11.900`
  and `11.905` in the middle prints `median 11.902` (11.9025, half-even); the head line says `2 rounds, 6 values per metric`; the
  `--json` value is the string `"11.902"`.
- VC8 *Only the deciding metric decides.* Arm with `total_s` all `11.900` and `sampler_s` all `12.000` (far slower): PASS; the
  `sampler_s` line ends `(information)`.
- VC9 *Bad input is exit 2 with one stderr line and no verdict line.* A vLLM line (`a-1 c=1 r=1 Output token throughput (tok/s):
  5.0`) in a comfy file: `<file>:<line>: not a bench line`; a line of another workflow: `<file>:<line>: workflow "wan5b" is not
  the expected "zimage"`; `--decide x`: `--decide "x" is not one of --metrics "total_s sampler_s vae_s"`; `--metrics ""` and
  `--metrics "total_s total_s"`: one line each naming `--metrics`; `--direction sideways`: argparse's exit 2; a base with no
  complete block: `base arm "base" has no complete arm-round in the inputs` (the vLLM text, `:364–365`); `--rounds 0`:
  `--rounds must be at least 1`.
- VC10 *The block check.* `comfy-check-block --tag fp16acc-1 --workflow zimage --metrics "total_s sampler_s vae_s" <file>`: a
  complete block → stdout `fp16acc-1: complete, 9 lines`, exit 0; one line missing → `expected 9 lines, found 8` and `missing:
  r=3 vae_s`, exit 1; a line twice → `expected 9 lines, found 10 (duplicate: r=1 total_s)`, exit 1; an empty file → nine
  `missing:` lines, exit 1; a line of tag `fp16acc-2` → exit 2, `tag "fp16acc-2" is not the expected "fp16acc-1"`; a line of
  another workflow → exit 2. RED first.
- VC11 *The vLLM mode is unchanged.* `tests/test_verdict.py` passes with no edit (`git diff --stat -- tests/test_verdict.py` is
  empty in the commit); `ship` and `check-block` keep their grammar (VC13).
- VC12 *`--json` writes every arm, atomically.* The file is a list, one object per arm: `arm`, `base`, `workflow`, `rounds`,
  `direction`, `decide` (`metric`, `median`, `base_median`, `delta`, `spread`, `n`, `word`; numbers as strings with three
  places), `information` (the same per metric, `word` `information`), `verdict`, `reason`; an INCOMPLETE arm has `decide: null`;
  no `.part` is left; an unwritable path is exit 2 (`write_json`, `:330`).
- VC13 *The two grammars do not mix.* `ship --bench <a comfy file>` → exit 2, `not a bench line`; `comfy --bench <the vLLM fixture
  tests/fixtures/ship_test/bench_final_ab.txt>` → exit 2, `not a bench line`.

### Brief for the Sonnet coder

Read first: this section and *Facts every story uses*; `lib/verdict.py` whole; `tests/test_verdict.py:1–80` (the helpers:
`run` at `:22`, `write_bench` at `:63`); `tests/conftest.py`. Do not change any line of the `ship` or `check-block` paths'
behaviour.

1. **Widen, do not copy** (reuse-first). `read_lines(path, parser=parse_line)`: the parser becomes an argument with today's
   default. `split_blocks(lines, start_key=START_KEY)`: the same. `stat_of`, `word_of`, `pick_blocks`, `missing_tags`,
   `write_json`, `InputError`, `arm_name` are used as they are.
2. **The comfy grammar.** `COMFY_LINE` (the regular expression of the grammar above, anchored, `\s+` after the colon; its arm
   part one named group, so N1's answer changes one line), `COMFY_RUNS = (1, 2, 3)`. `comfy_parser(workflow)` returns a
   function `(text, file, number) -> Line` with `tag = <arm>-<round>`, `key = "r=<n> <metric>"`: no match →
   `InputError(f"{file}:{number}: not a bench line")`; another workflow → the VC9 line. `comfy_keys(metrics)` →
   `[f"r={r} {m}" for r in COMFY_RUNS for m in metrics]`. `metrics_of(text)` → the list, refusing an empty one, a word that is
   not `[a-z][a-z0-9_]*` and a repeated word, each with one `InputError` line naming `--metrics`. A type function
   `workflow_name` beside `arm_name` (`[a-z0-9]+`, its own message).
3. **`cmd_comfy`.** The metrics; `--decide` in them; all lines of all `--bench` files through the comfy parser;
   `pick_blocks(split_blocks(lines, f"r=1 {metrics[0]}"), comfy_keys(metrics))`; the base check of `cmd_ship` (`:364–365`); per
   arm `evaluate_comfy`; print the notes, then each arm's lines; `--json`; exit 1 when any arm is INCOMPLETE, else 0.
   `evaluate_comfy` mirrors `evaluate` (`:250`): the gaps, then per metric `stat_of` over `[usable[tag].values()[f"r={r}
   {metric}"] for tag in tags for r in COMFY_RUNS]`, then the table of *The rule*. Number printing: `plain3` and `signed3`,
   `Decimal("0.001")`, `ROUND_HALF_EVEN` (beside `plain`, `:155`).
4. **The output** (VC1, VC5): head `arm <a> vs <b>: <r> round[s], <3·r> values per metric` or `arm <a> vs <b>: <have> of <r>
   rounds complete`; the deciding line `  <d>: median <m> vs <bm>, delta <±δ>, base spread <s> -> <word>`; each information line
   the same ending `(information)`; the verdict line `verdict <a>: PASS`, `verdict <a>: FAIL (<reason>)`, `verdict <a>: NOT
   DECIDED (inside the base spread)`, `verdict <a>: INCOMPLETE (<reason>)`.
5. **`cmd_comfy_check_block`**: the shape of `cmd_check_block` (`:377–392`) with the comfy parser, `comfy_keys` and the
   `--tag` check; its lines as VC10.
6. **The parser.** Two subparsers after `check-block`: `comfy` (`--workflow` required, `--metrics` required, `--decide`
   required, `--direction` required with choices `lower higher`, `--base` required, `--arm` append required, `--bench` append
   required, `--rounds` default 3, `--json`) and `comfy-check-block` (`--tag`, `--workflow`, `--metrics`, `file`). `main` is
   unchanged (its `--rounds` check covers the new mode).
7. **The docstring** names both new commands, the comfy rule (one paragraph: the direction, the three words, NOT DECIDED inside
   the spread) and the exit codes (comfy: 0 every arm PASS, FAIL or NOT DECIDED; 1 at least one INCOMPLETE; 2 an input error).
8. **`research/module_tests.md`**: the row and the sentence of *Files*.

**Commands.**

```bash
node tests/run.mjs tests/test_verdict_comfy.py tests/test_verdict.py
node tests/run.mjs
bash tests/check_static.sh
node .agents/conventions/tools/plan-lifecycle.mjs
```

Report the runner's PASS line per file and its total, the static check's exit code, and each RED observation (the failing line,
then the pass).

### Done when

- VC1–VC13 pass through `node tests/run.mjs`; `tests/test_verdict.py` passes with no edit; each RED observation is in the summary.
- `lib/verdict.py` stays under 800 lines and holds one copy of the rule (`stat_of`, `word_of`, `pick_blocks` shared).
- `bash tests/check_static.sh` exits 0; CI green.

---

## E2.S2 — The arm-round and its measurement contract: `comfyui/bench.py`, the arm and evidence tables, the `wan5b` LoRA pin, the worker `lib/comfy_bench.sh`, the record, the resume and the identity (cornerstone, `model: fable`)

**Cornerstone:** **yes** — the parent's E2 area *the measurement contract* (`:573–578`). **Depends on:** E2.S1 (the line grammar
and `comfy-check-block`). **Spec:** written by Fable (below). **Code:** one Sonnet coder; review Opus.

### Goal

One arm-round of a ComfyUI arm on the R9700 is measured the same way every time and is recorded only when it is a measurement:
one fresh, isolated, prefixed container started with the arm's arguments and environment, on a card whose memory is free, with
a bench cache cleared before it; one cold run under the workload's `cold_max_s`, then three measured runs under its
`run_max_s` whose seeds are the same for every arm; every ceiling and every guard stop ends the container before anything else
happens; a run fails fast on an `execution_error`, an output that is not the workflow's, or its ceiling; a cold run past its
ceiling is `COLD_TIMEOUT`, never "slower"; the arm-round is rejected when the ACTIVATION evidence of its arm is missing, and an
arm whose INERTNESS evidence is present is reported inert; the model loads and the recompiles inside a measured run are flagged;
the record holds the timings in S1's grammar, the per-run JSON, the whole server log, the outputs, the evidence, the drift
numbers against the base, and an identity (`fingerprint.json`) that admits a re-run of the same experiment — which continues
from the first missing arm-round — and refuses another. ComfyUI is a queue with an execution cache and a dynamic model offload,
and the host has lost GPU runs: a run can look like a measurement and not be one, and every claim of E3 rests on this record.

### Scope

In (the parent's *The bench's measurement contract*, `:235–288`; *The tuning series* arms, workloads and evidence, `:292–328`;
*Quality* layers 1 and 2, `:369–377`; *Records and growth*, `:382–409`; the `comfyui/` rows of E2, `:175–178`; the worker half of
the verb row `bench`, `:229`; the tests of `:421–434`):

- `comfyui/bench.py` (new, run inside the container through `wslc_exec`): the workflows `sd15`, `zimage`, `wan5b` with every input
  pinned — seed, steps, size, sampler, scheduler, cfg, shift, an empty negative prompt, `wan5b`'s length, its LoRA and strength
  (`LoraLoaderModelOnly` 1.0 between the loader and the shift node) and its tiled decode as the NAMED fields `tile_size 512,
  overlap 64, temporal_size 32, temporal_overlap 8` (`:316–328`); per workload `run_max_s` and `cold_max_s` (`:176`); the loader's
  weight dtype from `COMFY_BENCH_WEIGHT_DTYPE` and the compile node from `COMFY_BENCH_COMPILE` (`:303`, `:306`); the run sequence
  (the cold run, the three measured runs, the seeds); `total_s` from the queue to the history entry, the node times from the
  websocket; S1's lines for the measured runs only; one JSON per run; the fast failures and both ceilings; the output check
  (dimensions, frame count by `ffprobe -count_frames`, pixels not constant); the drift (mean absolute pixel difference and PSNR,
  per seed, with `numpy` and `Pillow`); the commands `workflows` and `metrics` of the seam, standard library only (`:176`).
- `comfyui/arms.conf` (new): `base`, `fp16acc`, `fp8w_mm`, `tunableop`, `miopen`, `compile` in the four-field grammar of
  `config/arms.conf` (`:177`, `:299–306`), with `tunableop`'s two tuning bounds set from the image's torch documentation (`:304`).
- `comfyui/arm_evidence.conf` (new): one row per arm, keyed by its name, with its ACTIVATION evidence and its INERTNESS evidence as
  the parent's table gives them (`:178`, `:273–281`, `:299–306`): `fp16acc` inert only when the model's compute dtype line AND
  the VAE's dtype line are bf16; `fp8w_mm` active only with the loader's `float8_e4m3fn` line AND the flag in the argv;
  `tunableop` active only with a non-empty results file holding the workload's shapes; `miopen` by the absence of
  `cudnn.enabled = False` and MIOpen's find lines in the cold run; `compile` by the node in every measured run AND the inductor
  cache written in the cold run; the argv alone never activation evidence (`:280–281`).
- `comfyui/models.conf`: the FastWan LoRA line of `wan5b` in the `loras` folder, its sha256 read once from the source's
  `X-Linked-ETag` at that commit and pinned (`:175`); E1's MC1 passes over it and gains its parity row.
- `lib/comfy_bench.sh` (new, two faces: sourced for the seam above, run as the worker, `:164`): the gate before every arm-round,
  the identity re-check, the bench cache clear (a prefixed throwaway container, its size recorded; a failed clear refuses), the
  bench container (`--tmpfs /data:exec,size=8g`, the models volume `:ro`, the bench cache volume made when missing, the arm's
  arguments and environment, ComfyUI's default memory mode), the readiness and the free-card wait (a probe that also returns
  `vram_free` and `vram_total`, `:155`, `:270–272`), `bench.py` through `exec`, **every ceiling ends the container** (a run past
  `run_max_s` or `cold_max_s`, the adapter's ceiling, a guard stop: stop it and see it no longer listed before the next
  arm-round or the restore, `:249–251`), the whole server log saved before the container stops (`:387`), the load and recompile
  flags per measured run (`:259–263`), the evidence check, `COLD_TIMEOUT` (`:257–258`), the validation (S1's
  `comfy-check-block` among it), ONE rename into `rounds/<arm>-<round>/`, `rejected/` with a reason (`INTERRUPTED`,
  `COLD_TIMEOUT`, an `execution_error`, an invalid output, missing evidence, `:389`), the part sweep, the balanced order (odd
  rounds as given, even rounds reversed), **the resume** (the same command continues from the first missing arm-round in the
  balanced order, the record names every lost arm-round and its cause when known, `:284–288`), the drift pairing (the base's
  round-1 output of the same seed; base rounds 2 and 3 against base round 1; `unavailable (<why>)` when the reference is missing
  or rejected, `:370–374`), the deadline and the quiet check as a series has them.
- The fingerprint: its components (`kind` = `comfy`, the image id, `COMFY_REF`, the arms, the workflow constants including the
  named tile fields and the LoRA's strength, `run_max_s` and `cold_max_s`, the hash of `bench.py`, of the two tables and of the
  worker's modules, the PINNED sha256 of every model file the workflow loads — the LoRA among them —, `base`, `rounds`,
  `:384–387`), built and compared before admission, re-checked at every arm-round; `lib/fingerprint.py` widened (`:160`).
- The pinned test requirements (`:430–434`): `tests/requirements.txt` gains exact pins of `aiohttp`, `numpy` and `Pillow` and
  their dependencies, the same major versions as the image's, under the dependency rules.
- The stub (`tests/stubs/wslc`, `stub_common.sh`): the bench container (its `--tmpfs` and `:ro` words logged), the `exec` of
  `bench.py` with scripted answers (good lines and JSON, an `execution_error`, a constant output, a slow run, a cold run past its
  ceiling, a run that outlives its ceiling), the clear container with its size line, the server log with the evidence lines,
  load lines and recompile lines as scripted (`:162`).
- The fixture server `tests/fixtures/comfy/comfy_server.py`: ComfyUI's `/prompt`, `/history/<id>`, `/ws`, `/system_stats`, with
  scripted messages, timings, errors and output files (`:421–422`).
- The placed `bench.py` under `$WORK_DIR/r9700/comfyui/` (`moe_place comfy_bench_assets`, `:156`, `:406–407`).
- The rows of its own test files in `research/module_tests.md`, its knobs and stub files in *Test knobs*, and its lines in *What
  it does not prove* (the eight unverified facts above that the stub stands in for).

Out: the verb's grammar, `supervise`, the dry-run printing call site, the verdict over a folder, the documents other than
`module_tests.md`, the acceptance (S3); the verdict rule (S1); the feasibility run and the series (E3).

### Files

| File | Change |
|---|---|
| `comfyui/bench.py` | new |
| `comfyui/arms.conf` | new |
| `comfyui/arm_evidence.conf` | new |
| `comfyui/models.conf` | one `wan5b` line: the FastWan LoRA, pinned |
| `lib/comfy_bench.sh` | new |
| `lib/fingerprint.py` | a build for the comfy identity beside `build`; `compare`, `show`, `--merge` unchanged |
| `lib/adapter.sh` | the readiness probe that also returns `vram_free` and `vram_total` (`:155`); every `wslc` call stays here |
| `tests/requirements.txt` | the exact pins of `aiohttp`, `numpy`, `Pillow` and their dependencies |
| `tests/stubs/wslc`, `tests/stubs/stub_common.sh` | the bench answers |
| `tests/fixtures/comfy/comfy_server.py` | new |
| `tests/test_comfy_bench_py.py` | new: the `BP` scenarios |
| `tests/test_comfy_bench.sh` | new: the `BW`, `BA`, `BE`, `BF` scenarios |
| `tests/test_comfy.sh` | MC1's parity row for the LoRA line |
| `tests/test_stubs.sh` | the `SC` scenarios |
| `tests/test_fingerprint.py` | the `BF` cases of the Python half |
| `tests/test_adapter_comfy.sh` | the probe's cases |
| `research/module_tests.md` | the rows, knobs and lines of *Scope* |

`lib/config.sh` and `config/arms.conf` do not change (`:158`).

### Test scenario IDs (one line each; the scenarios themselves are in Fable's spec)

**`bench.py` against the fixture server (`tests/test_comfy_bench_py.py`)**

- BP1 `bench.py workflows` and `bench.py metrics` run on the host with the standard library only and print the three workflows and the three metrics.
- BP2 Each workflow's graph has every input pinned, and the constants are the ones the fingerprint records (one table, read by both): `wan5b`'s LoRA node and strength, its named tile fields, the empty negative prompt, `run_max_s` and `cold_max_s`.
- BP3 One cold run, then three measured runs; the measured seeds are the same for every arm, differ from each other, and differ from the cold run's seed.
- BP4 Per measured run exactly the three lines of S1's grammar and none for the cold run; the block passes `comfy-check-block`.
- BP5 `total_s` runs from the queue to the history entry; the node times come from the websocket; a JSON per run (the cold run's marked cold) holds them with the seed and the cached nodes.
- BP6 A measured run in which the sampler did not execute (its output taken from ComfyUI's cache) fails: a time that measured nothing is never printed.
- BP7 An `execution_error` on the websocket fails the run at once, one line with the node and the message; the same error found only in `/history` fails it too.
- BP8 A prompt that `/prompt` refuses fails before any timing; a measured run past `run_max_s` fails at that ceiling.
- BP9 A cold run past `cold_max_s` ends with the `COLD_TIMEOUT` word and the time it reached, and no measured run follows.
- BP10 The image check: the workflow's width × height passes; a wrong size fails; a constant image fails.
- BP11 The video check: the workflow's `length` frames pass; a truncated video fixture fails (`ffprobe -count_frames`).
- BP12 The drift: per seed the mean absolute pixel difference and the PSNR; identical outputs give 0 and the spec's word for an infinite PSNR; a missing reference gives `unavailable (<why>)`, never a number.
- BP13 `COMFY_BENCH_WEIGHT_DTYPE` sets the loader's `weight_dtype`, `COMFY_BENCH_COMPILE` inserts `TorchCompileModel` after the loader (and after the LoRA for `wan5b`); without them the graph is `base`'s.
- BP14 The card readings `vram_free` and `vram_total` before the cold run are in the cold run's JSON.

**The worker and the arm-round (`tests/test_comfy_bench.sh`, the stub world, the worker run through `bin/r9700 step`)**

- BW1 One arm-round is one fresh prefixed container: `--tmpfs /data:exec,size=8g` (a plain `--tmpfs /data` is refused by the test), the models volume `:ro`, the bench cache volume, the arm's arguments and environment, ComfyUI's default memory mode — never the operator's data or cache volume, never two arm-rounds in one container.
- BW2 The bench cache is cleared before every arm-round by a prefixed throwaway container, its size before the clear is recorded, and a clear that fails refuses the arm-round (`KIND=refused`).
- BW3 The bench cache volume is made when it is missing (list first, `comfy_volume_ensure`), and only then.
- BW4 The free-card wait: `vram_free` at least 90 % of `vram_total` before the cold run, bounded; the value is recorded; a card that does not free in time fails the arm-round with the readings.
- BW5 A bench container that does not become ready is stopped by name before the worker exits, and the attempt goes to `rejected/`.
- BW6 Every ceiling ends the container: a run past `run_max_s`, a cold run past `cold_max_s`, the adapter's ceiling of the `exec`, and a guard stop each stop the container and see it no longer listed before the next arm-round starts or the worker exits.
- BW7 A `COLD_TIMEOUT` rejects the arm-round with that word and the time reached; the arm is not reported slower.
- BW8 A complete arm-round becomes `rounds/<arm>-<round>/` by ONE rename after the validation, with `record.env`, `bench.txt`, the run JSONs, the whole `server.log` (saved before the container stops), the outputs, the evidence and the drift.
- BW9 An `execution_error`, an invalid output, or a `bench.txt` that fails `comfy-check-block` rejects the arm-round to `rejected/<arm>-<round>-<stamp>/` with a `reason`; the worker exits 1.
- BW10 A model load or unload inside a measured run is flagged in `bench.txt` for that run; a run without one is not.
- BW11 A recompile line inside a measured run (`compile`) is flagged in `bench.txt` for that run, and it is never the activation evidence.
- BW12 Odd rounds run the arms as given, even rounds reversed.
- BW13 A part a killed worker left is moved to `rejected/` as `INTERRUPTED` at the next start.
- BW14 The resume: after a lost arm-round the same invocation continues from the first missing arm-round in the balanced order, keeps every completed one, and the record names the lost arm-round and its cause when known.
- BW15 The identity is re-checked at the start of every arm-round; an edit of `arms.conf`, `arm_evidence.conf`, `bench.py` or the image between arm-rounds refuses (`KIND=refused`) before the next container.
- BW16 The gate before every arm-round: the disk gate stops (`KIND=disk_gate`), a PC that is not quiet is exit 3, an arm-round that no longer fits before the deadline is exit 4.
- BW17 The drift pairing: an arm's output against the base's round-1 output of the same seed; base rounds 2 and 3 against base round 1; a missing or rejected base round 1 gives `unavailable (<why>)`.
- BW18 The worker never stops or starts the operator's ComfyUI or vLLM, and every container it starts is prefixed (the cleanup can stop it).

**The evidence (`tests/test_comfy_bench.sh`)**

- BE1 Each arm's ACTIVATION evidence present → recorded beside the timings; absent → the arm-round rejected with an `EVIDENCE:` reason naming what is missing.
- BE2 The argv alone (`/system_stats` `system.argv` holding the flag) is never activation evidence: `fp8w_mm` with the flag and no `float8_e4m3fn` line is rejected.
- BE3 `fp16acc` is reported *inert on <workload>* only when the model's compute dtype line AND the VAE's dtype line are bf16; with an fp16 VAE line it is an acting arm.
- BE4 `tunableop`'s results file must be non-empty and hold the workload's shapes; an empty file or one without them rejects.
- BE5 `miopen` is active only when the cold run has no `cudnn.enabled = False` line and has MIOpen's find lines.
- BE6 `compile` is active only with the node in every measured run AND the inductor cache written in the cold run.
- BE7 `base` is accepted with its attention line `Using pytorch attention`.

**The tables (`tests/test_comfy_bench.sh`)**

- BA1 The six rows of `comfyui/arms.conf` load with `arms_load`, the names are the parent's, and each row differs from `base` in exactly the change its table row names.
- BA2 Every arm of `arms.conf` has exactly one row in `arm_evidence.conf` and the other way round (derived over both files).
- BA3 No row sets `PYTORCH_HIP_ALLOC_CONF` (trap 1) or mounts a host path; `tunableop` carries both tuning bounds.

**The identity (`tests/test_comfy_bench.sh`, `tests/test_fingerprint.py`)**

- BF1 `fingerprint.json` is a version-1 document that `fingerprint.py show` and `compare` read, with `kind` = `comfy` and every component of *Scope*.
- BF2 A change of any component refuses the re-run with `fingerprint differs: <leaf>: <old> -> <new>` before anything is stopped; a new arm or more rounds is an extension.
- BF3 No new fingerprint is built over `rounds/` or `rejected/` whose identity is lost.
- BF4 A `COMFY_IMAGE` that does not exist refuses (2) naming `bin/r9700 comfy build`.
- BF5 The model identity is the pinned sha256 of `models.conf` for exactly the files the workflow loads (the LoRA for `wan5b`); a changed pin is a difference.

**The stub and the probe (`tests/test_stubs.sh`, `tests/test_adapter_comfy.sh`)**

- SC1 The stub answers the bench container's readiness (with `vram_free` and `vram_total`) and the `exec` of `bench.py` from scripted files (lines, JSON, outputs, an `execution_error`, a constant output, a slow run, a `COLD_TIMEOUT`).
- SC2 The stub's clear container prints a size line and empties the stub's bench cache; its failure is scriptable.
- SC3 The stub's `logs` of a bench container holds the scripted evidence, load and recompile lines.
- SC4 The stub logs the bench container's `--tmpfs` and `-v …:ro` words as given, so BW1 can read them.
- AP1 The widened probe prints the device, `vram_free`, `vram_total` and `ready`, and names the failing step otherwise (the shape of E1's AW5).

### Spec: written by Fable

> **This section is Fable's.** Fable writes, in this file, under this heading: the scenarios BP1–BP14, BW1–BW18, BE1–BE7,
> BA1–BA3, BF1–BF5, SC1–SC4 and AP1 in the detail of E2.S1's (each with its setup, its exact lines, its RED-first mark where it
> has one), the brief for the Sonnet coder (read first, steps, commands, what to report) and the *Done when* of this story. Fable
> may add a scenario, merge two or split one, and says so in one line. The cornerstone ledger line of the parent already names
> this story (`:614–616`).

What the spec must still settle after epoch 2 (the parent settled the eight open points of the epoch-1 version; these are left,
and Opus has decided none of them):

1. **The open points N1–N3 below.** Until they are answered, the spec builds the smallest fix of each and names the one line
   that changes with the answer.
2. **The seeds.** The three measured seeds are the same for every arm; the cold run's seed must differ from them, because
   ComfyUI takes a node from its cache when its inputs are equal, and a measured run with the cold run's seed would time nothing
   (BP3, BP6). The spec names the seeds and where they are written once.
3. **Where the outputs go.** `/data` is a tmpfs; the outputs must reach the record, and the drift needs the base's round-1
   outputs inside the container. The toolkit's existing way is an exchange folder under `$WORK_DIR/r9700/` mounted at `/work`
   and read on the host with `container_host_path` (`lib/kernels.sh:46`, `kernels_exchange_dir`; `lib/series.sh:366–371`);
   ComfyUI takes an `--output-directory` argument. The spec names the folder, its sweep and its growth row.
4. **Cutting the log per measured run.** The whole log is saved before the container stops (`:387`); the load and recompile
   flags need it cut per run (`:261–263`). The worker can read `wslc_logs` between runs (one `exec` of `bench.py` per run) or mark
   the runs in the log; the spec picks the one the stub can prove and the acceptance can observe.
5. **The values the parent leaves to the spec**: `run_max_s` and `cold_max_s` per workload (the parent's projections:
   a `zimage` arm-round ≈ 2–3 min, a `wan5b` arm-round ≈ 12 min, the screening's `tunableop` cold run > 37 min, `:337–341`,
   `:143`); the two TunableOp bounds (`:304`); the time an arm-round may need for the fit check before the deadline (the series
   uses `R9700_ARM_SECONDS`, `lib/series.sh:291`); the bound of the free-card wait.
6. **The grammar of `comfyui/arm_evidence.conf`** (`:178` says one row per arm keyed by name, activation and inertness): how a
   log line, the absence of a line, a file with content, a node in every run's node list and a written cache are written, and
   how the worker reads each from the arm-round's own record.
7. **The environment of `exec`** (fact 2): whether `bench.py` reads `COMFY_BENCH_WEIGHT_DTYPE` and `COMFY_BENCH_COMPILE` from
   its own environment (then the worker passes them on the `exec`), or from the container's.
8. **An arm whose container does not start.** The series marks `unsupported/` after two failed starts (`lib/series.sh:326–350`);
   the parent is silent for ComfyUI. The spec says whether a bench container that does not become ready is a failed try only,
   or also an unsupported mark, and what the verdict then sees.
9. **Missing model files.** A file of the workflow that is not in the models volume (the LoRA before its fetch, for one) fails
   every try after the operator's server was stopped. The spec says whether the supervisor's half checks, before admission,
   that the workflow's files are present (a throwaway container without the card, the shape of `_series_probe`,
   `lib/series.sh:99`), or why not.
10. **The LoRA's source and the test pins.** The LoRA's URL (the hand-made trial names the file
    `Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors`, not its source) and the exact versions of the test requirements
    "the same major versions as the image's" (fact 8: the repository's image is first built by E1's acceptance run 1; until
    then the spec reads the majors from ComfyUI v0.44.0's requirements and the hand-made image, and says which).

---

## E2.S3 — The verb `comfy bench` under the supervisor, `verdict` over a bench folder, the documents, the first bench runs on the R9700

**Cornerstone:** no. **Depends on:** E2.S2 merged (the seam); E2.S1 merged (the verdict mode); for the runs on the card, E1's
acceptance runs 1 and 2 (the built image, the sets fetched, `:558–559`) and one `comfy fetch wan5b` after E2 is merged (the
LoRA, open point N4). **Spec:** this section (Opus). **Code:** one Sonnet coder; the acceptance run by the operator's session.

### Goal

`bin/r9700 comfy bench <workflow> <arm>... [--rounds N] [--out <name>] [--dry-run]` runs S2's worker as ONE step under
`supervise` (`:229`): one lock, the restore first, the operator's vLLM stopped once at the admission and restored once at the
end, the guards, the deadline, and E1's owner check — after the lock, so a held lock is exit 4 first (entry 1.2, `:22–25`,
`:207–215`). The identity is built or compared before anything is stopped, and the same command again continues the same
experiment from the first missing arm-round and refuses another (`:284–288`). `bin/r9700 verdict <folder>` gives the comfy ship
test over a bench folder and the vLLM one over a series folder, unchanged. The documents describe `bench`, and the first bench
runs on the R9700 are recorded.

### Files

| File | Change |
|---|---|
| `lib/comfy_bench_verb.sh` | new (`:164`): `comfy_bench_args`, `comfy_mode_bench`, `comfy_bench_prepare`, `comfy_bench_body`, `comfy_bench_verdict`, `verdict_is_comfy` |
| `bin/r9700` | the library list (`:43`) gains `comfy_bench comfy_bench_verb` after `comfy`; `verb_verdict` (`:172–180`) dispatches; the header's verb list (`:2–5`) names `bench`; the exit comment row 2 (brief step 5) |
| `tests/test_comfy_bench_verb.sh` | new: CV1–CV14, VD1–VD5 |
| `tests/test_comfy.sh` | OC1's row `comfy` (`:31`, `:34–43`) |
| `tests/lib/comfycase.sh` | sources `lib/comfy_bench.sh` and `lib/comfy_bench_verb.sh` after `lib/comfy.sh` (`:21`), so CS1's derived mode list holds `bench` |
| `tests/test_lifecycle.sh` | no edit: its exit-table test (`:432`) checks that brief step 5's words are the same in the three places |
| `research/module_comfyui.md`, `research/architecture.md`, `research/module_tests.md`, `README.md` | brief step 7 |

### Test scenarios

All in `tests/test_comfy_bench_verb.sh` (OC1 in `tests/test_comfy.sh`), through `tests/run.mjs`, in the stub world:
`bench_setup` is `comfy_setup` (`tests/lib/comfycase.sh`) with the operator's server running, the three volumes present, S2's
default stub answers for a good arm-round of any arm (its activation evidence included), and `R9700_COMFY_ARMS_CONF` and
`R9700_COMFY_EVIDENCE_CONF` unset (the real tables); `bench <args>` is `r9700 comfy bench "$@"`; `bench_bg` / `bench_end` are
`comfy_bg` / `comfy_end` for `bench`. The call log is `$STUB/calls.log` (`stop_lines`, `log_count`, `argv_of`). "Nothing
happened" means: no lock file was made, no `wslc` call was logged. RED first as in E2.S1.

- CV1 *The grammar is refused before the lock, and the workflows are derived.* `bench` (no word): exit 2, `r9700: comfy: bench:
  usage: bench <workflow> <arm>... [--rounds <1..20>] [--out <name>] [--dry-run]`; `bench nosuch base`: exit 2, `r9700: comfy:
  bench: unknown workflow "nosuch"; legal: <comfy_bench_workflows, space-separated>` (the test reads the list from the function,
  and asserts it holds `zimage` and `wan5b`); `bench zimage` (no arm): exit 2, `at least one arm is needed`; `bench zimage Base`:
  `"Base" is not an arm name (…)` (the legal text of N1's answer); `bench zimage base base`: `the arm "base" is given twice`;
  `--rounds 0`, `--rounds 21`, `--rounds x`: `--rounds "<v>" is not a whole number from 1 to 20`; `--out ../x`: the `--out`
  line; `--rounds` with no value: `--rounds needs a value`; `--frob`: `unknown option "--frob"; legal: --rounds <1..20>, --out
  <name>, --dry-run`. Each: exactly one stderr line, nothing happened. RED first (the mode does not exist: `unknown mode
  "bench"`).
- CV2 *The prepare refuses after the restore and before any stop, and needs no model file.* `bench zimage base nosuch`: exit 2,
  the arm line of `_arm_known` (`config: arm "nosuch" is not in …; legal: …`, `lib/config.sh:607–611`) through S2's
  `comfy_bench_check`; an evidence table copy without the `fp16acc` row: `bench zimage base fp16acc` exit 2 with S2's line naming
  `fp16acc` and `arm_evidence.conf`; in both: no `stop`, no run folder under `RESULTS_DIR/runs`, the lock free afterwards. With a
  recovery marker left (vLLM was running, down now): the restore ran first (one `pwsh.exe -Detach`), then the same refusal. Two
  model files in `models/` and no `--model`: CV5 passes (the machine config alone, `config_load_machine`). A machine file with
  `COMFY_CONTAINER=r9700tune-comfy`: exit 2, E1's NR1 line, no stop.
- CV3 *Refused while the operator's ComfyUI is listed, before anything is stopped* (entry 1.2). `comfyui` listed: exit 2;
  exactly one stderr line, E1's owner line `r9700: the operator's ComfyUI (comfyui) is listed and holds the card; run bin/r9700
  comfy stop first`; no `stop`; no run folder; no `fingerprint.json` under `RESULTS_DIR/comfy-zimage`; `comfyui` and `vllm` still
  listed. A container named `comfyuix` listed instead: the run goes on (a whole name).
- CV4 *The lock comes first.* A `step_bg … worker.sh child` holds the lock: `bench zimage base` → exit 4, the holder line `pid
  <pid>, step`, no call; the same with `comfyui` ALSO listed → still exit 4, and no owner line (entry 1.2: the owner check is
  after the lock). While a bench holds it (`bench_bg zimage base` with S2's slow-run answer; wait for the first `exec` call):
  `r9700 step --model <35B> t -- worker.sh ok` → 4, the holder line names `comfy`; `bench_end` → 0.
- CV5 *One arm-round end to end: one stop, one restore, one record.* `bench zimage base --rounds 1`, the server running: exit 0;
  exactly one `stop vllm`; one `pwsh.exe -Detach` after it; `vllm` listed at the end; no marker; the lock free; no prefixed
  container listed at the end; `RESULTS_DIR/comfy-zimage/fingerprint.json` with `kind` `comfy` (`fingerprint.py show`);
  `rounds/base-1/bench.txt` passes `verdict.py comfy-check-block`; the bench container's run argv holds `--tmpfs
  /data:exec,size=8g` and the models volume with `:ro`; stdout holds `comfy: bench: outdir <RESULTS_DIR>/comfy-zimage` and
  `comfy: bench: 1 of 1 arm-rounds recorded; read them with bin/r9700 verdict <RESULTS_DIR>/comfy-zimage`. RED first.
- CV6 *Two arms, two rounds: still one stop and one restore, and the order alternates.* `bench zimage base fp16acc --rounds 2`:
  exit 0; one `stop vllm`, one `pwsh.exe -Detach`; four records; the bench containers' run calls, in log order, are base, fp16acc
  (round 1), fp16acc, base (round 2) — the test reads the arm from each container name; four clear-container calls, one before
  each bench container.
- CV7 *The same command again does nothing and stops nothing.* After CV6, the same command: exit 0, stdout `comfy: bench: 4 of 4
  arm-rounds recorded, nothing to do`, no `stop`, no `run` call of a bench or clear container (the count is made before the
  admission).
- CV8 *Another experiment is refused before anything is stopped.* After CV5, an arm table copy (`R9700_COMFY_ARMS_CONF`) whose
  `base` row has one more ComfyUI argument: exit 2; stderr holds a `fingerprint differs: arms.base` line; no `stop`; no new
  record; the stored `fingerprint.json` byte-for-byte unchanged.
- CV9 *More rounds and a new arm are extensions that run only what is new.* After CV5: `bench zimage base --rounds 2` runs
  `base-2` only (one bench container); then `bench zimage base fp16acc --rounds 2` prints `fingerprint: arm fp16acc added` and
  runs `fp16acc-1` and `fp16acc-2` only; each invocation one stop and one restore.
- CV10 *The dry run prints and changes nothing.* `bench zimage base fp16acc --dry-run`: exit 0; stdout lines starting
  `dry-run:` (S2's `comfy_bench_dry_run`: at least the clear container, the bench container's run with its `--tmpfs` word and
  the `exec` of `bench.py`); no `stop`; no `run` call; no `fingerprint.json`, no `rounds/`; the placed `bench.py` exists (the
  placement is before the dry run, as in `lib/kernels_verb.sh:169–173`). Like `moe-tune --dry-run` it takes the lock and
  restores first: with a marker left, one `pwsh.exe -Detach`, then the dry run.
- CV11 *An arm-round rejected on every try ends at `MAX_FAILED_TRIES` with the server restored once.* S2's stub answer for an
  `execution_error` on every run, `MAX_FAILED_TRIES=3`: exit 7; three attempts in `rejected/` each with a `reason`; no
  `rounds/base-1`; one `pwsh.exe -Detach` at the end; stderr holds `step failed 3 times`. With S2's `COLD_TIMEOUT` answer
  instead: the reasons say `COLD_TIMEOUT`, and no bench container is listed at the end (every ceiling ended its container).
- CV12 *The folder name.* No `--out`: `comfy-zimage`; `--out zt1`: `RESULTS_DIR/zt1`; `bench wan5b base --dry-run` names
  `comfy-wan5b`.
- CV13 *A signal during the bench ends it cleanly.* `bench_bg zimage base` with S2's slow-run answer; wait for the first `exec`
  of `bench.py`; `kill -TERM $SUP`: exit 143; every prefixed container stopped (the cleanup's `container_stop_all`); `vllm`
  listed again; no marker; the lock free; `rounds/` holds no final `base-1`.
- CV14 *A lost run is continued by the same command* (`:284–288`). `bench_bg zimage base fp16acc --rounds 2`; wait until
  `rounds/base-1` and `rounds/fp16acc-1` are final and the `exec` of the third arm-round has begun; `kill -KILL $SUP` (a host
  crash as the toolkit sees it: no cleanup ran). Then the same command: the restore from the marker ran first (one `pwsh.exe
  -Detach`), the part went to `rejected/` as `INTERRUPTED`, the run continues with `fp16acc-2` then `base-2` (round 2 reversed),
  exit 0, four records, the two kept records byte-for-byte unchanged, and stdout or the record names the lost arm-round. The
  same command with `--out` of that folder but another arm list order is still the same experiment; one with a changed arm
  table is CV8's refusal.

**`bin/r9700 verdict` over a bench folder** (`tests/test_comfy_bench_verb.sh`; the folders are made by a stub run of the verb, or
built by the test from S1's grammar with a fingerprint written through S2's `comfy_bench_fingerprint`)

- VD1 *A bench folder gets the comfy ship test.* After CV6 with the stub's timings scripted so that `fp16acc`'s `total_s` is
  below the base's spread: `r9700 verdict <RESULTS_DIR>/comfy-zimage` → exit 0; stdout holds `comfy bench <dir>: workflow
  zimage, base base, 2 rounds, fingerprint <12 hex>`, an `invoking: python3 …/verdict.py comfy --workflow zimage --metrics
  "total_s sampler_s vae_s" …` line naming `--decide total_s --direction lower`, and `verdict fp16acc: PASS`. Timings inside the
  spread: `verdict fp16acc: NOT DECIDED (inside the base spread)`, exit 0. A folder with `fp16acc-2` missing: exit 1 and
  `INCOMPLETE`. RED first.
- VD2 *A series folder is read exactly as before.* `tests/test_series_verdict.sh` passes with no edit; a series fingerprint has
  no `kind` leaf (`fingerprint.py show` exits 2), and the dispatch then calls `series_verdict` with the same arguments.
- VD3 *The options.* `--base fp16acc` judges `base` against `fp16acc`; `--json <file>` writes S1's JSON; `--no-quality` on a
  bench folder: exit 2, one line `r9700: verdict: --no-quality is for a series of vLLM arms; a comfy bench has no quality gate
  (its drift numbers are in each record)`.
- VD4 *An untrusted bench fingerprint is never judged as a bench.* A bench folder whose `fingerprint.json` was edited by hand (the
  digest no longer matches): exit 2 with the fingerprint's own line (`the stored digest does not match …`), no `verdict.py`
  call.
- VD5 *A one-round bench says so.* After CV5: stdout holds `note: 1 round, 3 values per arm; the ship test of a series uses 3
  rounds`, then `verdict: no arm besides the base to judge` (one arm only), exit 0.

**The owner check of every verb under `supervise` (`tests/test_comfy.sh`)**

- OC1 (E1's, extended) *The derived set gains `comfy`, and its row is refused like every other.* `OC1_ROWS` gains `comfy`;
  `oc1_run comfy` is `r9700 comfy bench zimage base`; the scenario's assertions (exit 2, the owner line, no stop, no run folder,
  the operator's server still running) hold for it unchanged. RED first: OC1 fails with `add a row for: comfy` as soon as
  `supervise comfy` exists.

**Documents (DC)** — no new test: DOC7, DOC8, DOC9 (`tests/test_docs.sh:131`, `:141`, `:154`), CS1's derived mode line
(`tests/test_comfy_start.sh:40–46`, after `comfycase.sh` sources the new files) and the exit-table test for brief step 5's words
(`tests/test_lifecycle.sh:432`) are each seen RED after the code exists and before the rows are written, then green.

### Brief for the Sonnet coder

Read first: this section, *Facts every story uses* and *The seam between S2 and S3*; S2's merged `lib/comfy_bench.sh` and its
spec section above; `bin/r9700:172–180`, `:226–310` (the series verb: the grammar, the prepare, the body), `:586–603`;
`lib/kernels_verb.sh` whole; `lib/series.sh:485–531` (`series_verdict`); `lib/run_guarded.sh:503–525`; `tests/lib/comfycase.sh`;
`tests/lib/seriescase.sh:1–40`; `tests/test_series_verdict.sh:1–60`; `tests/test_comfy.sh:20–75`. Reuse, never copy:
`supervise`, `step_run`, `config_load_machine`, `moe_place`, `_SERIES_OUT_RE`, `_RE_ARM` (or N1's answer), `fingerprint.py
show`, S2's seam. No line of the new file or of `bin/r9700` names `wslc` as a word (the seam).

**1. `lib/comfy_bench_verb.sh`** (new; header in the style of `lib/kernels_verb.sh:1–13`: the verb half of `comfy bench`,
SOURCED after `lib/comfy_bench.sh`, takes no lock and sets no trap itself). Messages `r9700: comfy: bench: <text>` (stderr) and
`comfy: bench: <text>` (stdout).

- `_CB_USAGE` the CV1 usage line. `comfy_bench_args <args...>`: sets `_CB_WORKFLOW`, `_CB_ARMS` (array), `_CB_ROUNDS` (default
  3, `:352`), `_CB_OUT`, `_CB_DRY` (`yes|no`); the option loop of `series_args` (`bin/r9700:233–265`) with `--rounds`, `--out`,
  `--dry-run`; the first word that is not an option is the workflow, the others are arms; the checks in CV1's order: usage,
  workflow in `comfy_bench_workflows` (a whole line), at least one arm, `--rounds` `^([1-9]|1[0-9]|20)$`, each arm by the arm-name
  rule and once, `--out` default `comfy-<workflow>` (`:384`) and `_SERIES_OUT_RE`. 2 and one line each.
- `comfy_mode_bench`: `comfy_bench_args "$@" || return 2`, then `supervise comfy comfy_bench_prepare comfy_bench_body` and its
  code. The lock holder word is `comfy`, the same as `comfy start` and `build` (`:229`: `supervise comfy …`).
- `comfy_bench_prepare`: `config_load_machine "${R9700_MACHINE_ENV:-./machine.env}" || return 2`, then `comfy_bench_check
  "$_CB_WORKFLOW" "$_CB_ROUNDS" "${_CB_ARMS[@]}" || return 2`. Nothing else: `supervise` runs E1's owner check right after it
  (CV3); no check of its own before the lock (entry 1.2).
- `comfy_bench_body` (the order of `_kern_body` and `series_body`): `outdir="$R9700_RESULTS_DIR/$_CB_OUT"`; stdout `outdir
  <outdir>`; `local _MOE_PLACED_BY=comfy`; `moe_place comfy_bench_assets || return 2`; with `--dry-run`: `comfy_bench_fingerprint
  "$outdir" "$_CB_WORKFLOW" "$_CB_ROUNDS" dry "${_CB_ARMS[@]}" || return 2`, `comfy_bench_dry_run … ; return $?`; else the same
  call with `real`; `left` and `recorded` from S2's counts, the total `_CB_ROUNDS × arms`; `left` 0 → the CV7 line, return 0;
  `step_run comfy-bench -- bash "$R9700_ROOT/lib/comfy_bench.sh" "$outdir" "$_CB_WORKFLOW" "$_CB_ROUNDS" "${_CB_ARMS[@]}"`; its
  code non-zero → return it; else the CV5 summary line with the recounted `recorded`. No `cleanup_hook_set`: the cache clear is
  the worker's, before every arm-round (S2); the cleanup stops the prefixed containers as it does for every verb.
- `comfy_bench_verdict <outdir> [--base <arm>] [--json <file>]`: the argument loop of `series_verdict` (`lib/series.sh:492–500`)
  with `--no-quality` refused by the VD3 line; the reads through `python3 "$R9700_ROOT/lib/fingerprint.py" show
  "$outdir/fingerprint.json" <leaf>` for `workflow`, `base` (unless `--base`), `rounds`, `sha256`, `arms` (2 with the program's
  own line on failure); the head line of VD1; the VD5 note for one round; the `--bench` files `rounds/<arm>-<r>/bench.txt` that
  exist, for every arm and round; no base file → `r9700: verdict: base arm "<b>" has no complete arm-round in the inputs`, 2; no
  judged arm → `verdict: no arm besides the base to judge`, 0; then `metrics="$(comfy_bench_metrics)"`, `cmd=(python3
  "$R9700_ROOT/lib/verdict.py" comfy --workflow "$workflow" --metrics "$metrics" --decide "${metrics%% *}" --direction lower
  --base "$base" --arm … --bench … --rounds "$rounds" [--json "$json"])`; `echo "invoking: ${cmd[*]}"`; run it; its code.
  `lower` is a named constant `_COMFY_BENCH_DIRECTION=lower` with the comment "every metric of a bench is seconds".
- `verdict_is_comfy <args...>`: the outdir is the first word that is not an option and not the value of `--base` or `--json`; 0
  when `<outdir>/fingerprint.json` is a file and `fingerprint.py show <it> kind 2> /dev/null` prints exactly `comfy`; else 1 (a
  series folder, a missing file and an untrusted file all go to `series_verdict`, which reports them as it does today — VD4's
  line is the fingerprint program's own).

**2. `bin/r9700`.** The library list (`:43`): `… comfy comfy_bench comfy_bench_verb`. `verb_verdict`: after the restore-first
block, `if verdict_is_comfy "$@"; then comfy_bench_verdict "$@"; else series_verdict "$@"; fi; exit $?`. The header's verb
list (`:4–5`) gains `bench` among the comfy modes with `(E2 of the ComfyUI plan: measure ComfyUI arms as one supervised step)`;
`verb_comfy`'s comment (`:586–588`) gains `bench <workflow> <arm>... runs under the supervisor (one lock, one stop and one restore
of the operator's server)`.

**3. `tests/lib/comfycase.sh`** sources the two new files after `lib/comfy.sh`. **4. `tests/test_comfy.sh`**: `OC1_ROWS`
gains `comfy`, `oc1_run` the line of OC1.

**5. The exit table.** No new code. Row 2 of the three places (`bin/r9700:17–24`, `research/architecture.md` exit table,
`README.md` exit list) gains `comfy bench: an unknown workflow or arm, an arm without an evidence row, a bench whose identity
changed (fingerprint differs: …), or the image COMFY_IMAGE does not exist` in the same words; row 4 gains `(a bench holds it
through its run; with ComfyUI listed, a held lock is still 4)`; row 1's `verdict` words cover a bench folder already (no change).
The three places must agree (`tests/test_lifecycle.sh:432`).

**6. Tests** as *Test scenarios*: every wait a bounded `wait_for` on a call-log line or a file, never a fixed sleep; every started
process recorded (`guard_pid`), `kill_recorded_pids "$CASE"` at the end of a test that leaves containers.

**7. Documents.** None of the four documents of `check_static.sh --unfinished` may hold `planned`, `E3 will` or `not built yet`.

- `research/module_comfyui.md`: the title says six modes; *Purpose* adds the bench in one sentence; the tile fields at `:106`
  written as the NAMED fields of the parent's fact 2 (`:126–129`: `tile_size 512, overlap 64, temporal_size 32,
  temporal_overlap 8` and `tile_size 512, overlap 32, temporal_size 64, temporal_overlap 4`); a section *The bench* from S2's
  MERGED code (not from this plan): the verb, the arm table and the evidence table (activation and inertness), the two
  workloads (FastWan 3-step text-to-video `wan5b` and why, `:321–328`), the arm-round (the fresh container with
  `--tmpfs /data:exec,size=8g` and why `exec`, the cache clear, the free-card wait, the cold run and `COLD_TIMEOUT`, the three
  measured runs, the seeds, every ceiling ending the container, the failures, the output check, the load and recompile flags,
  the order, the record, the drift, the identity, the resume of a lost run), the verdict over a bench folder; the flow `bench`
  in *The flows*; the Mermaid diagram gains the bench container, the bench cache volume and the supervisor; *Growth* gains the
  rows of this document's growth table that are S2's; *What is not proven* gains the facts the stub stands in for (S2's lines)
  until the acceptance observes them; *Acceptance on the R9700 (E2)* (below).
- `research/architecture.md`: the ComfyUI module row (`:23`) names `lib/comfy_bench.sh`, `lib/comfy_bench_verb.sh`,
  `comfyui/bench.py`, `comfyui/arms.conf`, `comfyui/arm_evidence.conf` and `lib/fingerprint.py`'s comfy build; the verb row
  (`:41`) names `bench` (`supervise comfy`, one step, one stop and one restore of the operator's server; refused by the owner
  check after the lock); the `verdict` row and the sentence of `:5` say that `verdict` reads a series folder or a bench folder;
  the exit table rows 2 and 4 (step 5).
- `research/module_tests.md`: the row of `tests/test_comfy_bench_verb.sh` (CV1–CV14, VD1–VD5), OC1's extended row; the flow
  catalogue row `| \`bin/r9700 comfy bench\` and \`verdict\` over a bench folder | covered | …ids… |` and one `not covered` row
  `the bench on the card` naming the acceptance section; the knobs S3 adds (none expected).
- `README.md`: *The commands* line of `bin/r9700 comfy <mode>` names `bench`; the ComfyUI section gains a paragraph *Bench* (the
  command, the arms of `comfyui/arms.conf` and what their evidence means, one stop and one restore of the operator's server, the
  first arm is the base, the folder `comfy-<workflow>`, the same command continues a lost run, `bin/r9700 verdict <folder>` and
  what PASS, FAIL, NOT DECIDED and INCOMPLETE mean, that a series is three rounds, that a `COLD_TIMEOUT` arm is not measurable
  within its ceiling); the exit list rows 2 and 4 (step 5).

**Commands.**

```bash
node tests/run.mjs tests/test_comfy_bench_verb.sh tests/test_comfy.sh tests/test_comfy_start.sh tests/test_series_verdict.sh tests/test_lifecycle.sh tests/test_docs.sh
node tests/run.mjs
bash tests/check_static.sh
node .agents/conventions/tools/leftovers-check.mjs --repo . --token r9700 --identity "the R9700 vLLM tuning toolkit" --profile node
node .agents/conventions/tools/plan-lifecycle.mjs
```

Report the runner's PASS line per file and its total, the static check's exit code, and each RED observation (the failing line,
then the pass); for CV2 say whether any function under `supervise` needed a model key (the fact above that is not known).

### Acceptance on the R9700 (the operator's session, after S2 and S3 are merged and E1's acceptance runs 1 and 2 are recorded)

Recorded in `research/module_comfyui.md` § *Acceptance on the R9700 (E2)* (`:447`, `:553–556`), the prediction written there
BEFORE the first command; each command with its output in a fenced block, the commit it ran at, the date, the image id, and what
the record does not settle. Not an `ACCEPTANCE_*.md` file: the parent gives its one acceptance record to E3 (`:446`).

0. `bin/r9700 comfy fetch wan5b` — the LoRA line is E2's, so E1's acceptance run 2 fetched `wan5b` without it (open point N4);
   the other files are already right and are not downloaded again. Recorded: the LoRA's `fetch: done` line with its pin.
1. `bin/r9700 comfy bench zimage base fp16acc --rounds 1`, the operator's vLLM running. Prediction (the parent's, `:343–350`):
   `fp16acc` is reported *inert on zimage* with its evidence (the model's and the VAE's bf16 lines, `:302`); one stop and one
   restore of vLLM; two arm-rounds recorded. Recorded: the lines; per arm-round the `vram_free` and `vram_total` before the cold
   run, the cold run's time, the three measured runs' `sampler_s`, `vae_s`, `total_s`, the load flags, the evidence lines as
   found, the bench cache's size before each clear; the outputs, looked at by the operator (the record says so); the drift
   numbers of `fp16acc` against `base`.
2. `bin/r9700 comfy bench wan5b base --rounds 1`. Prediction: one arm-round of about 12 min (`:337–339`); the FastWan
   text-to-video clip has no hatching (`:327–328`). Recorded: as run 1, and the operator's look at the FIRST clip for the
   hatching — the record says whether it is there (`:571`). A clip with the hatching stops E3's video series until the owner
   decides.
3. `bin/r9700 verdict <RESULTS_DIR>/comfy-zimage` and `… /comfy-wan5b`. Prediction: the one-round note, then for `zimage`
   `verdict fp16acc: NOT DECIDED` or a word the record explains; for `wan5b` no arm to judge; no speed claim from one round.
4. The facts the stub stands in for, each observed once and written down: `--tmpfs /data:exec,size=8g` and the read-only models
   volume in the bench's own containers (OP8, `:243–248`), a named volume made or refused by `run` (fact 1), the environment of an
   `exec` (fact 2), the `/system_stats` fields (fact 3), the websocket messages and the `/history` fields (fact 4), the log lines
   of the evidence and of a load (fact 5), the image's `aiohttp`, `numpy` and `Pillow` versions against the test pins (fact 8).
   The TunableOp file (fact 6) and the inductor cache (fact 7) are observed by one by-hand `--rounds 1` run of `tunableop` and of
   `compile` on `zimage` only if the operator agrees to the GPU time; else the record says they are not observed. A shape that
   differs from S2's parse is a fix and a deviation.
5. The operator's cache volume `COMFY_CACHE_VOLUME`, measured once (a throwaway container that runs `du -sh /cache`, by hand),
   and the growth row of `research/module_comfyui.md` corrected from "projected, not measured" to the measured value with its
   date (`:394–397`).

### Done when

- CV1–CV14, VD1–VD5 and OC1 pass through `node tests/run.mjs`; every other test passes unchanged (`tests/test_series_verdict.sh`
  and `tests/test_verdict.py` with no edit); each RED observation is in the summary.
- `comfy bench` is refused with E1's owner line while the operator's ComfyUI is listed, with nothing stopped, and is exit 4
  under a held lock even then; a bench stops the operator's vLLM once and restores it once however many arm-rounds it runs; the
  same command continues a lost run and runs nothing when all is recorded; another experiment is refused before anything is
  stopped.
- `bin/r9700 verdict` gives the comfy ship test over a bench folder and the unchanged vLLM one over a series folder.
- `bin/r9700 commands` is unchanged; `comfy_modes` lists `bench`; the module row, the verb row, the README line and section and
  the exit rows exist; the tile fields of `research/module_comfyui.md:106` are named; `bash tests/check_static.sh` exits 0 (the
  seam is still exactly `lib/adapter.sh`); CI green.
- The acceptance on the R9700 is recorded as above, the `wan5b` clip looked at.

---

## Growth surfaces of these stories

| Surface | Story | Size | Who retires it | Interrupted |
|---|---|---|---|---|
| The results folder `<RESULTS_DIR>/comfy-<workflow>/` (`fingerprint.json`, `rounds/`, `rejected/`) | S2 (the worker writes it), S3 (names it) | per arm-round: `bench.txt` ≈ 2 KB, four run JSONs ≈ 20 KB, `server.log` ≈ 100 KB, the outputs (`zimage` 3 × ≈ 1.5 MB; `wan5b` 3 × ≈ 5 MB; plus the cold run's if S2 keeps it): ≈ 5 MB (`zimage`) and ≈ 15 MB (`wan5b`); a 6-arm × 3-round series ≈ 95 MB (`zimage`) and ≈ 270 MB (`wan5b`), the parent's figures (`:390`); E2's acceptance ≈ 25 MB; each rejected attempt or lost arm-round adds up to one arm-round's size, at most `MAX_FAILED_TRIES` per arm-round per invocation | kept forever: collected data is append-only and the operator's (`:390–391`); the toolkit deletes nothing under `RESULTS_DIR` | a part left by a kill or a host crash is moved to `rejected/` as `INTERRUPTED` at the next worker start (BW13); a fingerprint input folder left by a kill is removed by the next build (the series' rule) |
| The bench cache volume `<CONTAINER_PREFIX>comfy-cache` | S2 | one arm-round's MIOpen, Triton, TunableOp and inductor caches: at most 2 GB projected (`:394–399`); measured by the size line of every clear and recorded in the arm-round | its CONTENT: the worker, cleared before every arm-round (never more than one arm-round's caches); the volume itself: the operator, by hand — the toolkit never removes a volume (`:399–400`) | a killed arm-round leaves its caches until the next arm-round's clear |
| The bench container's `/data` (`--tmpfs /data:exec,size=8g`) | S2 | the venv `entrypoint.sh` makes at each start and ComfyUI's temp files: tens of MB of RAM expected, at most 8 GB by its own size option; measured by the acceptance; the outputs do not go there (S2's spec, question 3) | gone with the container (`--rm`) | every ceiling and the cleanup stop the prefixed container (BW6) |
| The exchange folder under `$WORK_DIR/r9700/` that S2's spec names (question 3) | S2 | at most one arm-round's outputs plus the base's round-1 references: ≤ 20 MB (`zimage`), ≤ 35 MB (`wan5b`) | the worker, once the outputs are in the record; S2's spec names the sweep | a kill leaves it; the next worker start sweeps it (S2's spec) |
| The models volume, one more file | S2 (the pin), S3 (the fetch on the card) | the FastWan LoRA (rank 128, bf16), its size recorded by the fetch (`:392–393`) | the operator, by hand, with the volume (E1's row) | E1's fetch rules (resume, the pin) |
| The placed `bench.py` under `$WORK_DIR/r9700/comfyui/` | S2 | one file, ≈ 15 KB | rewritten when the repository's file changes (`moe_place`, `:406–407`) | a `.part` left by a kill is replaced by the next placement |
| Run folders `<RESULTS_DIR>/runs/<id>/` | S3 (through `supervise`) | one per invocation, as for every verb under the supervisor (the supervisor log, the step's logs, the guards' logs: KB) | unchanged: as every verb under the supervisor | unchanged |
| Test files | S1, S2, S3 | a few KB per run (bench files, fixture outputs, the fixture server's log) | the runner removes its run folder | the runner's sweep |

## Build order

1. **E2.S1** — Sonnet codes the S1 section; Opus reviews; Sonnet fixes. It touches nothing the others write. (N1's answer
   changes one line of its grammar if it comes after the merge.)
2. **E2.S2** — Fable writes the spec into this file (it may start at once); the ledger line names it (`:614–616`); the answers to
   N1–N3 are read before the spec is final when they have come, else the spec uses the smallest fixes; Sonnet codes after S1 is
   merged; Opus reviews; Sonnet fixes.
3. **E2.S3** — Sonnet codes after S2 is merged; Opus reviews; Sonnet fixes. Then, after E1's acceptance runs 1 and 2, the
   operator's session runs the E2 acceptance (its step 0 first) and records it.

## Definition of Done (E2, by story)

- [ ] S1: VC1–VC13 pass in CI; `tests/test_verdict.py` passes with no edit; the RED observations are in the summary.
- [ ] S2: the scenarios of Fable's spec pass in CI with the stub and the fixture server, each refusal seen failing first; every
      item of the parent's measurement contract (`:235–288`) is a scenario; the eight unverified facts are in *What it does not
      prove*; the test pins are in `tests/requirements.txt` and CI installs them.
- [ ] S3: CV1–CV14, VD1–VD5 and OC1 pass in CI; a bench stops and restores the operator's vLLM once; `verdict` reads both kinds of
      folder; the documents describe `bench` and name the tile fields; the E2 acceptance on the R9700 is recorded with its
      `vram_free` values, its cold-run times, its evidence lines and its outputs, the `wan5b` clip looked at, and the operator's
      cache volume measured.
- [ ] Every story: the seam and personal-path checks pass; `research/architecture.md` and `research/module_tests.md` describe what
      exists; `node .agents/conventions/tools/plan-lifecycle.mjs` is clean.

## Open points

New after epoch 2: each is a conflict between the parent at bd36c56 and the code, or within the parent, found while this
document was rewritten. Each names the line, what is wrong and the smallest fix. None is applied to the parent here; a change of
the approved contract goes through the parent's ledger after a review.

- **N1 — `fp8w_mm` is not a legal arm name.** The parent names the arm `fp8w_mm` (`:303`, `:345`, `:376`). Every arm name in the
  toolkit is `^[a-z0-9]+$` (`_RE_ARM`, `lib/config.sh:102`): `arms_load` refuses a row named `fp8w_mm`, the series grammar
  refuses the word, `verdict.py`'s `arm_name` type refuses it (`lib/verdict.py:395–398`), and the bench line grammar of E2.S1
  (`<arm>-<round>`) could not tell it apart with an `_` either way. Smallest fix: the owner renames the arm `fp8wmm` (one word in
  the parent's table and prediction); the other fix — widening `_RE_ARM` to allow `_` — changes the grammar of `config/arms.conf`,
  the series and the vLLM verdict, which no epic of this plan owns. Until the answer, S1 keeps `[a-z0-9]+` and S2 cannot load
  the row as written.
- **N2 — `tunableop`'s activation evidence may never be readable.** The evidence is "the results file is not empty and holds the
  workload's shapes" (`:304`). By PyTorch's documentation (not read in this repository, fact 6) TunableOp keeps its results in
  memory and writes the file when the process ends; the bench stops its container with a signal, and ComfyUI is not known to
  run Python's exit handlers on one. If the file is not written, every `tunableop` arm-round is rejected for missing evidence: a
  false rejection, not a measurement. Smallest fix: none until it is observed; S2's spec checks the file's moment in the
  fixture's terms and the acceptance (or the by-hand run of its item 4) observes it before E3. If the file is written only on a
  clean exit, the evidence row changes (for example to TunableOp's own verbose lines in the cold run) — a change of the
  evidence table, the owner's.
- **N3 — `compile`'s activation evidence needs the inductor cache in `/cache`.** The evidence is "the inductor cache written in
  the cold run" (`:306`), and the bench cache is said to hold "the inductor cache of `compile`" (`:399`). The arm's environment
  names only `COMFY_BENCH_COMPILE=1` and `TORCH_LOGS=recompiles` (`:306`); by PyTorch's documentation the inductor writes its
  cache under `/tmp` in the container unless `TORCHINDUCTOR_CACHE_DIR` says otherwise (fact 7), so neither the clear nor the
  evidence check would see it. Smallest fix: the `compile` row of `comfyui/arms.conf` also sets `TORCHINDUCTOR_CACHE_DIR` under
  `/cache` (`/cache/inductor`). This only makes the parent's own two sentences true (plan-change-control: "a fix that only
  satisfies the plan as written" is not a change); S2's spec applies it unless the owner says otherwise.
- **N4 — the LoRA is not in E1's fetch.** E2's acceptance takes its models from E1's acceptance run 2 (`:558–559`), but the
  `wan5b` LoRA line is added by E2 (`:175`), so that fetch cannot hold it, and a `wan5b` bench before a second fetch fails at its
  cold run. Smallest fix, applied in this document without a parent change: S3's acceptance step 0 runs `bin/r9700 comfy fetch
  wan5b` after E2 is merged (only the LoRA downloads). Listed so the parent's *Depends on* can say so at its next edit.

## Settled in epoch 2

The eight open points of the epoch-1 version (8814640) are settled in the parent; the stories above follow it.

- **OP1 — the worker's file:** `lib/comfy_bench.sh` (two faces) and `lib/comfy_bench_verb.sh` (`:164`, `:548`).
- **OP2 — the refusal before the lock:** ledger entry 1.2 (`:22–25`) — the refusal is `supervise`'s owner check, after the lock;
  a held lock is exit 4 first (`:207–215`, `:229`).
- **OP3 — the verdict word inside the spread:** `NOT DECIDED (inside the base spread)` (`:352–353`, `:361–364`, `:567–569`).
- **OP4 — the `wan5b` decode:** a workload constant, `VAEDecodeTiled` with the named fields `tile_size 512, overlap 64,
  temporal_size 32, temporal_overlap 8`; the faster setting is a follow-up for the owner (`:125–130`, `:319–320`, `:325–327`).
- **OP5 — the `wan5b` steps:** the FastWan 3-step `lcm` text-to-video workload with its pinned LoRA; 50 steps a quality reference
  by hand (`:118–124`, `:318–328`, `:175`).
- **OP6 — the arm evidence:** `comfyui/arm_evidence.conf`, activation and inertness, keyed by arm; `fp8mm` replaced by the pair
  `fp8w_mm`; the argv never activation evidence alone (`:158`, `:178`, `:273–281`, `:299–306`).
- **OP7 — the test dependency:** exact pins of `aiohttp`, `numpy` and `Pillow` in `tests/requirements.txt` (`:430–434`).
- **OP8 — `--tmpfs` and the read-only volume:** built as written, `--tmpfs /data:exec,size=8g` (a plain one is `noexec`),
  observed 2026-11-08; a fallback is the owner's (`:238–248`).
