# PLAN — E2 stories: `comfy bench` under the supervisor, and the verdict over its records

> Status: **S1–S3 merged in PR #20 (0e05147, 2026-11-08); the acceptance on the card is owed; the epoch-2 version** (rewritten after the parent's re-review,
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
   `exec` and reads `COMFY_BENCH_WEIGHT_DTYPE` (`fp8wmm`) and `COMFY_BENCH_COMPILE` (`compile`) (`:303`, `:306`).
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
`fp16acc`, `fp8wmm`, `tunableop`, `miopen`, `compile`, `:301–306`) all match the parent's arm grammar (`_RE_ARM`,
`lib/config.sh:102`, `[a-z0-9]+`; open point N1 settled the one name that held an `_`). A COMPLETE block of a tag is exactly one line for every
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
- `comfyui/arms.conf` (new): `base`, `fp16acc`, `fp8wmm`, `tunableop`, `miopen`, `compile` in the four-field grammar of
  `config/arms.conf` (`:177`, `:299–306`), with `tunableop`'s two tuning bounds set from the image's torch documentation (`:304`).
- `comfyui/arm_evidence.conf` (new): one row per arm, keyed by its name, with its ACTIVATION evidence and its INERTNESS evidence as
  the parent's table gives them (`:178`, `:273–281`, `:299–306`): `fp16acc` inert only when the model's compute dtype line AND
  the VAE's dtype line are bf16; `fp8wmm` active only with the loader's `float8_e4m3fn` line AND the flag in the argv;
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
- BE2 The argv alone (`/system_stats` `system.argv` holding the flag) is never activation evidence: `fp8wmm` with the flag and no `float8_e4m3fn` line is rejected.
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

> Written by Fable, 2026-11-08, against the parent at 025cbff (its text is bd36c56's with the epoch-2 wording of 025cbff: `fp8wmm`,
> `TORCHINDUCTOR_CACHE_DIR=/cache/inductor`, E2 fetches the LoRA) and the code at 6be7a67. Sources read for it, each named where it
> decides something: the parent whole; this document whole; E1.S2 as the model of depth; `lib/run_guarded.sh`, `lib/step.sh`,
> `lib/series.sh`, `lib/comfy.sh`, `lib/adapter.sh`, `lib/fingerprint.py`, `lib/moe.sh:1–100`, `lib/moe_verb.sh:30–50`,
> `lib/kernels.sh:30–70`, `lib/config.sh:95–110` and `:540–644`, `tests/stubs/wslc`, `tests/stubs/stub_common.sh:1–60`,
> `comfyui/Containerfile`, `comfyui/entrypoint.sh`, `comfyui/models.conf`; the operator's hand-made `bench.py` and `lora_try.py` (read
> only; nothing of their paths is here); PyTorch's TunableOp page (docs 2.15, read 2026-11-08); ComfyUI v0.44.0's `requirements.txt`,
> `comfy/model_management.py` and `execution.py` (read 2026-11-08); the file list of the LoRA's repository (the Hugging Face API,
> 2026-11-08). The ten questions are answered first, in their order; N2's design follows; then the contract as text, the scenarios,
> the brief and the Done when. Two scenarios are added (BW19, BE8) and one is split (BP12 into BP12 and BP12v); each says so.

#### The ten questions, answered

1. **N1–N3.** N1 and N3 are settled in the parent (`fp8wmm`; `TORCHINDUCTOR_CACHE_DIR=/cache/inductor` in the `compile` row). N2 is
   designed below (*N2: the TunableOp file*) and stays open for the owner only for what the card must show.
2. **The seeds.** ONE table in `comfyui/bench.py`, `SEEDS = {"cold": 4242, "measured": (1, 2, 3)}`: the cold run's seed is the hand
   prototype's first seed; the measured seeds are the toolkit's (`WORKLOAD_BENCH["seeds"]`, `lib/fingerprint.py:38`). They differ
   from each other and from the cold seed, so ComfyUI's cache re-executes the sampler in every measured run (its cache key is the
   node's inputs; the text encoding, whose inputs do not change, stays cached after the cold run — the parent's `:252–256`). The
   fingerprint records the table (question 5's `constants`); nothing else types a seed.
3. **Where the outputs go.** The exchange folder `$WORK_DIR/r9700/comfyui/bench/<outdir name>/` (the toolkit's one way: `/work` is
   `$WORK_DIR_WIN` mounted read-write, read on the host through `container_host_path`, `lib/serve.sh:93`; the MoE units' scratch
   folder has the same life, `lib/moe.sh:19`). The bench container is started with `--output-directory
   /work/r9700/comfyui/bench/<outdir name>/<arm>-<round>` (ComfyUI's own argument; `entrypoint.sh` appends it after the image's
   words), so `/data` (the tmpfs) never holds an output; `bench.py` writes its run JSONs beside them. After the arm-round the worker
   MOVES the folder's files into the record and removes the folder; before every arm-round it removes a folder of that tag left by a
   kill (ours, scratch: the MoE rule). The drift's references are copied by the worker from `rounds/base-1/outputs/` into
   `<exchange>/ref/` before the measured runs and removed after the drift. The growth row is this document's *The exchange folder*
   row: at most one arm-round's outputs plus the base's round-1 references, swept by the worker, and by the next worker start after a
   kill.
4. **Cutting the log per measured run.** One `exec` of `bench.py` per run (four per arm-round: `cold`, `1`, `2`, `3`); after each the
   worker saves the WHOLE log again (`wslc_logs` into `server.log`, replaced atomically) and the cut of run k is the lines the log
   gained since the save before it (the log is append-only; a cut is a line range, `runs/<k>.log`). The stub proves it (its `exec`
   of `bench.py` appends scripted lines to its log answer per run, SC3) and the acceptance observes it (the real log grows per
   run). Not chosen: marks written into ComfyUI's log — the bench cannot write into the server's log, and `got prompt` /
   `Prompt executed in` are ComfyUI's lines to change.
5. **The values the parent leaves to the spec.** All are constants of `bench.py` (`CEILINGS` and `SEEDS` are in `constants`, which the
   fingerprint records) or of the worker, none a `machine.env` field (the parent, `:195–197`):

   | Value | `zimage` | `wan5b` | `sd15` | Basis |
   |---|---|---|---|---|
   | `run_max_s` | 300 | 600 | 120 | a measured run that the screening put at tens of seconds (`zimage`: fact 7; `sd15`: 2–2.3 s, the parent `:101`) and at 122–143 s for the FastWan clip (fact 1) is not a measurement of this workload past ten times that; for `wan5b` 600 s also catches the stall of fact 2 (the untiled decode: more than 10 min) |
   | `cold_max_s` | 1800 | 2700 | 600 | the cold run holds the model load, the compile of `compile` (minutes, fact 7) and the bounded tuning of `tunableop`; 30 min is the bound the series' time budget can carry six times per `zimage` series (the parent `:337–341`: the series ≈ 1 h plus the six cold runs); `wan5b` adds the clip itself (≈ 2.5 min) and its load; `sd15` is the smoke workload |
   | `PYTORCH_TUNABLEOP_MAX_TUNING_DURATION_MS` | 10 | 10 | 10 | torch's default is 30 ms and 100 iterations per solution, the smaller honoured (the TunableOp page); the screening's unbounded cold run tuned for more than 37 min (fact 7), so the bounds are a third of the duration and a tenth of the iterations, and `cold_max_s` is the real ceiling |
   | `PYTORCH_TUNABLEOP_MAX_TUNING_ITERATIONS` | 10 | 10 | 10 | the same row; the two words are the `tunableop` row of `comfyui/arms.conf` (one place) |
   | the arm-round's time for the fit check | `cold_max_s + 3 × run_max_s + 600` (`zimage` 3300 s, `wan5b` 5100 s) | | | derived from the ceilings, never typed twice: the 600 s cover the cache clear, the container start and readiness, the free-card wait and the cache report; the test knob `R9700_COMFY_ARM_SECONDS` replaces the sum (the shape of `R9700_ARM_SECONDS`, `lib/series.sh:291`) |
   | the free-card wait | 300 s, probes `t_scale 10` apart, `vram_free × 10 ≥ vram_total × 9` | | | a stopped container's memory comes back within seconds on a healthy driver; five minutes is what a driver recovering from a lost run may need; longer is a fault to record, not to wait out |

   **What cannot be known before the card**: the real cold times of `tunableop` and `compile`, and the clip's time under the bench.
   E2's acceptance measures them (its runs 1 and 2, and item 4's by-hand `tunableop` and `compile` arm-rounds when the operator
   agrees) and records them; until then the table stands. A corrected value is a new experiment (the fingerprint differs) and
   not a plan change: the parent leaves the values to this spec.
6. **The grammar of `comfyui/arm_evidence.conf`.** One row per arm, three fields, exactly two `|`: `<arm> | <activation> |
   <inertness>`. A field is `-` (nothing) or checks separated by ` ; ` (a `;` never appears inside a check), ALL required (an AND).
   A check is `<kind>=<argument>`; the argument runs to the separator or the field's end and is never a regular expression with a
   space trimmed. The kinds, and how the worker reads each from the arm-round's OWN record:

   | Kind | Argument | True when | Read from |
   |---|---|---|---|
   | `log` | an extended regular expression (`grep -E`) | a line of the whole server log matches | `server.log` (the container's log from its start, the cold run included) |
   | `nolog` | the same | NO line of the whole server log matches | `server.log` |
   | `coldlog` | the same | a line of the COLD run's cut matches | `runs/cold.log` |
   | `node` | a ComfyUI `class_type` | every MEASURED run's node list holds a node of that class that executed (not cached) | `runs/1.json` … `3.json`, `nodes` |
   | `cache` | a folder name under `/cache` | the cold run's JSON reports at least one file under it after the cold run | `runs/cold.json`, `cache_after` |
   | `tunable` | a file name under `/cache/tunableop` | the file the cache report copied into the record is non-empty, has at least one `Validator` line and at least one result row (four comma-separated fields, the operator name first) | `<file>` in the record (copied after the clean stop, below) |
   | `argv` | one word | ComfyUI's `system.argv` (the cold run's JSON) holds the word; **never alone**: an activation field whose checks are all `argv` is refused by `comfy_bench_check` (the parent `:280–281`) | `runs/cold.json`, `server_argv` |

   Activation absent → the arm-round is rejected, the reason `EVIDENCE: activation <check>: missing (<file>)` per missing check;
   inertness fully present → the record says `inert on <workflow>` with every check's matched line, and the worker prints it. The
   rows, with the exact ComfyUI strings (`comfy/model_management.py` v0.44.0 prints `Enabled fp16 accumulation.` and
   `Set: torch.backends.cudnn.enabled = False for better AMD performance.` — read 2026-11-08; `Using pytorch attention` is
   `comfy/ldm/modules/attention.py`'s, observed 2026-11-07, the parent `:95`; the model's and the VAE's dtype lines are
   `comfy/model_base.py`'s `model weight dtype …, manual cast: …` and `comfy/sd.py`'s `VAE load device: …, dtype: …` — the coder
   re-reads all five files at `COMFY_REF` and keeps the regular expressions as short as the lines allow):

   ```text
   # arm       | activation                                                                       | inertness
   base        | log=Using pytorch attention                                                      | -
   fp16acc     | log=Enabled fp16 accumulation                                                    | log=model weight dtype torch\.bfloat16 ; log=VAE load device.*dtype: torch\.bfloat16
   fp8wmm      | log=model weight dtype torch\.float8_e4m3fn ; argv=fp8_matrix_mult                | -
   tunableop   | tunable=tunableop_results.csv                                                    | -
   miopen      | nolog=cudnn\.enabled = False ; coldlog=MIOpen\(HIP\): Info.*[Ff]ind                 | -
   compile     | node=TorchCompileModel ; cache=inductor                                          | -
   ```

   `base`'s inertness is `-` (the reference is never inert). A recompile line is NEVER a check (the parent `:306`): it is the flag of
   question 4's cut. The `tunable` check's "holds the workload's shapes" (`:304`) is read as "at least one result row": the GEMM shapes
   of a workload are not known before the card (open point N6 below records what the acceptance adds).
7. **The environment of `exec`.** `bench.py` reads `COMFY_BENCH_WEIGHT_DTYPE` and `COMFY_BENCH_COMPILE` from ITS OWN environment and
   nowhere else, and refuses any other `COMFY_BENCH_*` name it finds (one line naming the legal two). The worker passes every
   `COMFY_BENCH_*` word of the arm's environment field on the `exec` line as `env <word>... python3 …` (coreutils' `env`, in the
   image), so the answer to fact 2 changes nothing: the container's `-e` words stay (the identity and the dry run show them), and
   the program sees them either way. The acceptance still observes fact 2 (S3's item 4) and the record says what it saw.
8. **An arm whose container does not start.** ONE try per worker start, no `unsupported/` mark: the arm-round goes to `rejected/` as
   `UNSTARTED: <name> did not become ready (<ready_wait's reason>)` with the log tail, the container is stopped and seen gone, the
   worker exits 1 — the supervisor counts a failed try and retries after its quiet wait, up to `MAX_FAILED_TRIES` (exit 7). Why not
   the series' mark (`lib/series.sh:305–316`): the image passed its check and every arm's words are ComfyUI's own, so a start that
   fails is a machine fault to retry, not an arm to skip for ever; and the bench folder's reader (S3's verdict) knows `rounds/` and
   `rejected/` only (the parent *Records and growth*). The verdict then sees a missing arm-round: `INCOMPLETE`. An arm that refuses
   its flags on every try stops the invocation at exit 7 with its three reasons; the operator runs the same command without that arm
   (an arm left out is not a fingerprint difference, `lib/fingerprint.py:236`) and the other arms go on. The dry run shows the words.
9. **Missing model files.** Checked BEFORE admission, in `comfy_bench_fingerprint` (the shape of `_series_probe`, `lib/series.sh:99`,
   which the series' fingerprint already runs): one throwaway container (`wslc_run_once 120`, `--name <prefix>comfy-fp-<pid>`, the
   models volume `:ro`, no `--gpus`, `--entrypoint sh`, the image) lists `<folder>/<file> <size>` for every file of the workflow
   (its names come from `bench.py constants <workflow>`, the folders from `models.conf`); a file that is not there refuses with exit
   2: `r9700: comfy: bench: /models/<folder>/<file> is not in the models volume (<set> of comfyui/models.conf); run bin/r9700 comfy
   fetch <set> first` — before anything is stopped. The listing is kept in `record.env`-style words of the fingerprint's inputs
   (`models_listing`) but the IDENTITY of a model file is its pin (question 10 and `:386`), never its size.
10. **The LoRA's source and the test pins.** The LoRA is `Kijai/WanVideo_comfy`'s
    `FastWan/Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors` (the file name the hand-made trial loaded, in that
    repository's file list, read 2026-11-08 through the Hugging Face API: 660 874 456 bytes, LFS sha256
    `79290493711b022e1c6e655d803715cd8a91a75cdb139856cad46f354e2f681c`). The `models.conf` line:
    `wan5b loras https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/FastWan/Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors <sha256>`,
    where `<sha256>` is what the coder reads ONCE from the source's `X-Linked-ETag` at the commit (`curl -sI -L`), the parent's
    rule for every pin (`:175`); it is expected to equal the LFS hash above, and a difference is reported, not resolved. The test
    pins: ComfyUI v0.44.0 requires `aiohttp>=3.11.8`, `numpy>=1.25.0`, `Pillow>=10.1.0` (its `requirements.txt`, read 2026-11-08);
    the image's exact versions are not known before E1's acceptance run 1 (fact 8). The coder pins, in `tests/requirements.txt`,
    the newest release on PyPI at coding time of `aiohttp` major 3, `numpy` major 2 (the base's torch 2.13 is built against
    NumPy 2) and `Pillow`'s current major, with their dependencies as the file pins pytest's (`pip download --no-deps` per name,
    then the dependency closure, each `==`), and the summary names the versions. S3's acceptance item 4 reads the image's three
    versions; a differing MAJOR is a fix of the pins and a deviation, a differing minor is recorded.

#### N2: the TunableOp file

PyTorch's TunableOp page (docs 2.15, read 2026-11-08) says: "The output file is automatically created when the application
terminates." and "This behavior can be controlled by the C++ and Python APIs but not the environment variables." The file is a CSV
with `Validator` lines and rows of four comma-separated fields. So the premise of N2 holds: a container stopped by a signal that
Python does not turn into a normal exit leaves no file, and every `tunableop` arm-round would be rejected for missing evidence. **The
design keeps the parent's evidence row as it is and makes the file readable:**

- **The clean stop.** Every arm-round that reaches its validation ends its container with a CLEAN STOP before the hard stop: the
  worker runs `wslc_exec 30 <name> python3 -c '<_CB_SIGINT_PY>'`, a program of the standard library that sends `SIGINT` to pid 1
  (`entrypoint.sh` `exec`s ComfyUI, so pid 1 is the server: `comfyui/entrypoint.sh:114`). ComfyUI's `main.py` catches
  `KeyboardInterrupt` and returns normally; the interpreter then runs its exit handlers, which is when TunableOp writes
  `PYTORCH_TUNABLEOP_FILENAME`. The worker then waits (`t_scale 60`, the list `t_scale 10` apart) until the container is no longer
  listed (`--rm` removes it at exit); a container still listed after the wait gets the hard stop (`wslc_stop`, the list again) and
  the record says `STOP=forced` in `record.env` — for every arm but `tunableop` a forced stop changes nothing; for `tunableop` the
  file is then absent and the arm-round is rejected for missing evidence, which the reason names as the forced stop.
- **The cache report.** After the container is gone, one throwaway container (`wslc_run_once 120`, `--name
  <prefix>comfy-report-<pid>`, the bench cache volume read-write, no `--gpus`, `--entrypoint sh`, the image, the program
  `_CB_REPORT_SH`: `du -s` of `/cache/miopen /cache/triton /cache/tunableop /cache/inductor`, then `--- tunableop_results.csv`
  and the file's content) prints what the arm-round left in the bench cache; the worker writes its lines to `cache.txt` and the CSV
  part to `tunableop_results.csv` in the record (empty when the file is absent; the `tunable` check reads this copy).
- **Where the file goes.** The `tunableop` row sets `PYTORCH_TUNABLEOP_FILENAME=/cache/tunableop/tunableop_results.csv`; TunableOp
  makes no folder, so the clear program (`_CB_CLEAR_SH`, question 6 of the worker below) makes `/cache/tunableop` and
  `/cache/inductor` empty after it cleared them.
- **The observation the card owes.** Whether `SIGINT` to pid 1 ends ComfyUI normally on the real engine, and whether the file is
  written by the exit (the acceptance's item 4, `tunableop` by hand, `--rounds 1` on `zimage`: the record keeps `cache.txt`,
  `tunableop_results.csv` and the `STOP=` word). If the stop is not clean there, the fallback that keeps the evidence row is
  `PYTORCH_TUNABLEOP_VERBOSE=1` in the arm's row (TunableOp's own lines in the cold run, a `coldlog=` check): that is a change of
  the evidence row and the owner's — N2 stays open for exactly that decision, and the stub cannot settle it (SC6 scripts both
  outcomes so the worker's two paths are proven).

The parent's "every ceiling ends the container" (`:249–251`) is untouched: a ceiling, a guard stop and a failed validation use the
hard stop; only an arm-round that is being recorded ends cleanly, and it is still stopped and seen gone before the next arm-round.

#### The contract as text

**One arm-round, in order** (the worker, `bash lib/comfy_bench.sh <outdir> <workflow> <rounds> <arm>...`, `comfy_bench_main`):

1. The worker sources its modules (`_CB_UNIT_SH`: `config run_guarded adapter serve restore wait_ready disk_gate guard_quiet series
   comfy`; `_CB_UNIT_PY`: `fingerprint verdict`; both lists are also the fingerprint's `tools`, the A24 rule of `lib/series.sh:38–42`),
   loads both tables (`arms_load "$(comfy_bench_arms_conf)"`, `comfy_evidence_load "$(comfy_bench_evidence_conf)"`), reads the
   constants (`python3 bench.py constants <workflow>`), sweeps parts (`_cb_sweep_parts`: every `rounds/*.part-*` to `rejected/` as
   `INTERRUPTED: <name> was left by run <run id> (its status: <the status file of RESULTS_DIR/runs/<run id>, or "not found">)`, the
   cause when known) and removes the exchange folders of tags that have no final record.
2. Per round `1..rounds`, the arms in the table's order given on the command line for an odd round and reversed for an even one
   (`_cb_order`); a tag with a final record is skipped; so a re-run continues from the first missing arm-round in the balanced order.
3. `_cb_gate <arm> <round>` (the series' `_series_gate` shape): the disk gate (`KIND=disk_gate`, exit 1), the quiet check (exit 3), the
   fit (`_cb_round_seconds` = question 5, exit 4 with the count of what no longer fits).
4. `_cb_recheck`: the identity re-built from the cheap components (both tables, the constants, `bench.py`'s and the modules' hashes,
   the pins, the image id through `wslc_inspect`) and compared with `fingerprint.json`; a difference is `KIND=refused RC=2` with the
   lines (BW15).
5. The part folder `rounds/<tag>.part-<run id>/` and `record.env` (ARM, ROUND, RUN_ID, CONTAINER, STARTED_AT, FINGERPRINT, WORKFLOW,
   IMAGE_ID; later VRAM_FREE_BEFORE, VRAM_TOTAL_BEFORE, STOP, INERT, INERT_EVIDENCE, FLAGS_RUN_1..3, FINISHED_AT).
6. The bench cache: `wslc_volume_list`, `comfy_volume_ensure "<prefix>comfy-cache" <listing> bench` (list first, create only when
   missing; its line reads `comfy: bench: created volume …`); then the clear, one throwaway container (`wslc_run_once 90`,
   `--name <prefix>comfy-clear-<pid>`, the bench cache volume at `/cache`, `--entrypoint sh`, the image, `_CB_CLEAR_SH` = `du -s
   /cache/miopen /cache/triton /cache/tunableop /cache/inductor 2> /dev/null; rm -rf /cache/miopen /cache/triton /cache/tunableop
   /cache/inductor; mkdir -p /cache/miopen /cache/triton /cache/tunableop /cache/inductor`, no variable in it); its lines go to
   `cache.txt` as `before clear: …`; a non-zero code refuses the arm-round (`KIND=refused`: "the bench cache could not be cleared
   before the arm-round: a stale cache would be measured", the MoE rule `lib/moe.sh:286–292`).
7. The exchange folder of the tag made empty; for an arm other than `base`, or for `base` in a round other than 1, the references
   copied from `rounds/base-1/outputs/` into `<exchange>/ref/` when that record exists (else the drift is `unavailable`).
8. The container: `wslc_run <name>` with `--gpus all --tmpfs /data:exec,size=8g -v <COMFY_MODELS_VOLUME>:/models:ro -v
   <prefix>comfy-cache:/cache -v <WORK_DIR_WIN>:/work --shm-size 8g`, `-e <word>` per word of the arm's environment field, the image,
   then `--output-directory /work/r9700/comfyui/bench/<outdir name>/<tag>` and the arm's argument words; `<name>` is
   `container_name comfy-<arm>-<round>` (the label fits `^[a-z0-9][a-z0-9-]{0,39}$` for every arm name of the grammar up to 29
   characters; `comfy_bench_check` refuses a longer one). No `-p`: the bench talks to the server from inside through `exec`. A run
   call that fails: the list decides (E1's lesson, `lib/comfy.sh:253–258`): listed → stopped and seen gone; the attempt is
   `rejected/` as `UNSTARTED`, exit 1.
9. Readiness and the free card: `ready_wait <name> <READY_TIMEOUT_S> comfy_probe ready "comfy: bench:"` (E1's wait, the widened probe:
   AP1); then `_cb_card_free <name>`: the probe every `t_scale 10` for at most `t_scale 300` until `vram_free × 10 ≥ vram_total × 9`;
   the first and the last readings go to `record.env`; not free in time, or a probe without the two numbers → `UNSTARTED: the card is
   not free (vram_free <f> of <t> after <n> s)` / `CARD: vram not reported by /system_stats`, the container stopped, exit 1.
10. The runs, each one `wslc_exec <ceiling> <name> env <COMFY_BENCH_* words> python3 /work/r9700/comfyui/bench.py run <workflow> --tag
    <tag> --run <cold|1|2|3> --out /work/r9700/comfyui/bench/<outdir name>/<tag>` with the ceiling `cold_max_s + 60` for the cold run
    and `run_max_s + 60` for a measured one (the program's own ceiling is the inner one; the adapter's is the outer: a program that
    does not return is ended by it, 124/137). After each: the log saved again and the cut written (`runs/<k>.log`); the program's
    stdout appended to `bench.txt` (the measured runs print S1's three lines, the cold run prints `cold: <total_s> s` lines that the
    worker keeps in `runs/cold.txt`, never in `bench.txt`); its code: 0 go on; 3 with `COLD_TIMEOUT <s>` → the arm-round rejected
    `COLD_TIMEOUT: the cold run reached <s> s of cold_max_s <c>`, the container hard-stopped and seen gone, exit 1, nothing more runs;
    3 with `RUN_TIMEOUT <s>` → `CEILING: run <k> reached <s> s of run_max_s <r>`; 1 → the program's last line as the reason
    (`EXECUTION_ERROR: …`, `OUTPUT: …`, `CACHED: …`, `PROMPT: …`); 124/137 → `CEILING: the exec of run <k> was ended by the adapter`.
    Every rejection here hard-stops the container first.
11. The flags: per measured run the cut is searched for `_CB_LOAD_RE` (`Requested to load|loaded completely|loaded partially|
    Unloading|models unloaded`) and `_CB_RECOMPILE_RE` (`[Rr]ecompil`); the counts go to `flags.txt` (`run 1: load 2, recompile 0`)
    and `record.env` (`FLAGS_RUN_1=load=2,recompile=0`); never into `bench.txt` (S1's grammar admits no other line; open point N5).
12. The drift: `wslc_exec 300 <name> python3 …/bench.py drift <workflow> --out <the tag's folder> --ref /work/…/ref` when the references
    were copied: per measured seed `drift r=<n>: mad <v> psnr <v|identical>`; without references `drift: unavailable (<why>)` written
    by the worker (`no base-1 record`, `base-1 rejected`, `the reference of seed <s> is missing`). Both to `drift.txt`.
13. The validation, in this order: the container is still listed (`_cb_alive`; else `LOST: server alive 0` as the series says it);
    the log saved a last time; `comfy-check-block --tag <tag> --workflow <workflow> --metrics "$(comfy_bench_metrics)" bench.txt`
    (its lines as problems); four run JSONs and four outputs present (the cold run's output is kept too: `outputs/`); then the CLEAN
    STOP and the cache report (N2); then the evidence (`_cb_evidence <arm>`: question 6; the activation problems and the inertness
    word); `server.log` not empty. Any problem → `rejected/<tag>-<UTC stamp>/` with `reason` (the first line the kind, the others the
    problems), exit 1.
14. `FINISHED_AT`, ONE `mv -T` into `rounds/<tag>/`, the exchange folder of the tag removed, `recorded <tag>` (and `<tag>: inert on
    <workflow> (<evidence>)` when inert), `sleep t_scale 10`.

**What the worker never does**: stop or start `COMFY_CONTAINER` or `PROD_CONTAINER` (its stops name only containers it started,
all prefixed), write outside `<outdir>`, `<RESULTS_DIR>/runs/<run id>` and the exchange folder, set a trap, take a lock, remove a
volume, name `wslc` (the seam).

**Exit codes of the worker**: 0 every arm-round of the invocation recorded; 1 an arm-round was rejected (kept in `rejected/`), the
disk gate stopped (`KIND=disk_gate`) or a container could not be started; 2 a refusal (`KIND=refused`: the identity, a failed cache
clear, a bench container that could not be stopped — `the container <name> is still listed after the stop; stop it by hand`); 3 not
quiet; 4 the next arm-round no longer fits before the deadline.

**`comfyui/bench.py`**, inside the container through `exec` (the image's Python; `aiohttp` for the transport as the prototype;
`numpy` and `Pillow` only in `drift` and `check`), and on the host for the pure commands:

- `workflows` → `sd15 wan5b zimage`, one per line, sorted; `metrics` → `total_s sampler_s vae_s`; `constants <workflow>` → one JSON
  object: every pinned input of the graph (the model file names by folder, the prompt text, the empty negative prompt, width,
  height, length, steps, sampler, scheduler, cfg, shift, the LoRA name and `strength_model`, the four named tile fields, the fps),
  `seeds`, `ceilings` (`run_max_s`, `cold_max_s`), `metrics`, `nodes` (`sampler`, `vae`: the node ids the metrics time). These three
  import nothing outside the standard library (BP1) and are the ONE table the graphs and the fingerprint read (BP2).
- `graph <workflow> --seed <n> [--tag <t>]` → the ComfyUI prompt JSON on stdout (standard library; the fixture tests read the graph
  without a server): `zimage` as the prototype's (`UNETLoader` with `weight_dtype` from `COMFY_BENCH_WEIGHT_DTYPE`, default
  `default`; `CLIPLoader lumina2`; `VAELoader`; `ModelSamplingAuraFlow` shift 3.0; `ConditioningZeroOut` for the empty negative
  prompt; `EmptySD3LatentImage` 1024×1024; `KSampler` 8 steps `res_multistep` `simple` cfg 1.0; `VAEDecode`; `SaveImage` with
  `filename_prefix <tag>/<workflow>_r<run>`); `wan5b` text-to-video: `UNETLoader` (`wan2.2_ti2v_5B_fp16.safetensors`),
  `LoraLoaderModelOnly` (the LoRA, `strength_model 1.0`) between the loader and `ModelSamplingSD3` shift 8.0, `CLIPLoader wan`,
  `VAELoader`, `CLIPTextEncode` with the prototype's positive prompt and an EMPTY string for the negative, `Wan22ImageToVideoLatent`
  WITHOUT an image input (text-to-video: the node's `start_image` is left unset; the coder confirms the node accepts it in v0.44.0
  and else uses `EmptyHunyuanLatentVideo`-style empty latent that ComfyUI's Wan 2.2 template uses, and the summary says which),
  1280×704, length 121, `KSampler` 3 steps `lcm` `simple` cfg 1.0, `VAEDecodeTiled` with `tile_size 512, overlap 64,
  temporal_size 32, temporal_overlap 8` as named fields, `CreateVideo` 24 fps, `SaveVideo`; `sd15` as the prototype's with an
  empty negative. `COMFY_BENCH_COMPILE=1` inserts `TorchCompileModel` (`backend inductor`) after the loader — after the LoRA for
  `wan5b` — and points the shift node at it (BP13).
- `run <workflow> --tag <tag> --run <cold|1|2|3> --out <dir>`: `GET /system_stats` (the argv, `vram_free`, `vram_total` before the
  run); the websocket `/ws?clientId=<uuid>`; `POST /prompt`; `t0` at the POST; the node times from `executing` (the prototype's
  loop; a node's time runs from its `executing` message to the next); `execution_cached` remembered (its `nodes`); an
  `execution_error` ends the run at once with `EXECUTION_ERROR: node <node_id> (<node_type>): <exception_message>` and exit 1;
  `executing` with `node: null` ends the loop; then `/history/<prompt id>` polled (0.5 s) until the entry exists; `total_s` is the
  time from the POST to the first poll that finds it; a `status.status_str` that is not `success`, or a `status.messages` entry
  named `execution_error`, fails the run the same way (BP7); the output's file name from `outputs[<save node>]` (`images` or
  `video`: `filename`, `subfolder`), checked (below); the JSON written to `<out>/run-<k>.json` (`tag`, `workflow`, `run`, `seed`,
  `started_at`, `total_s`, `nodes_s`, `node_order`, `cached_nodes`, `server_argv`, `env` (the `COMFY_BENCH_*` words), `vram_free_before`,
  `vram_total_before`, `vram_free_after`, `output` (`file`, `width`, `height`, `frames`, `constant`), `cache_after` (per folder of
  `/cache`: `files`, `bytes`, read with `os.walk`), `cold` true/false); for a measured run the three lines `<tag> <workflow> r=<n>
  <metric>: <value>` (three decimals, `sampler_s` the sampler node's time, `vae_s` the decode node's, `total_s` as above) and
  nothing for the cold run but `cold: total <s> s`. A measured run whose sampler node is in `cached_nodes` or missing from the
  executed nodes exits 1 with `CACHED: the sampler did not execute (cached: …)` before any line is printed (BP6). A refused prompt
  (`/prompt` without `prompt_id`) is `PROMPT: refused: <the body's error>`, exit 1, no timing (BP8). The whole run is under
  `asyncio.wait_for` with `cold_max_s` or `run_max_s`: on the timeout the program prints `COLD_TIMEOUT <reached s>` or `RUN_TIMEOUT
  <reached s>` and exits 3 (BP8, BP9).
- `check <file> --workflow <workflow>` (run by `run` after every run, also usable alone): an image opens with Pillow, its size is
  `width × height`, its pixels are not constant (`numpy`: the array's min equals its max → constant); a video's frame count by
  `ffprobe -v error -count_frames -select_streams v:0 -show_entries stream=nb_read_frames -of csv=p=0 <file>` equals `length`, and
  its first, middle and last frame (decoded by `ffmpeg -f rawvideo -pix_fmt rgb24`) are not constant. A failure is `OUTPUT: <why>`,
  exit 1 (BP10, BP11).
- `drift <workflow> --out <dir> --ref <dir>`: per measured seed, the arm's output against the reference of the same seed (the file
  names carry the run number, and the seed is the run's): images as `uint8` arrays, `mad` = the mean absolute difference, `psnr` =
  `10·log10(255² / mse)` with three decimals, or the word `identical` when the mse is 0; a video frame by frame (decoded as above),
  the mean of the frames' values; a missing reference → `drift r=<n>: unavailable (the reference of seed <s> is missing)`; never a
  number for an absent pair (BP12, BP12v).

The program's exit codes: 0; 1 a failed run or check (the last line names the kind); 2 a bad argument or an unknown `COMFY_BENCH_*`
word; 3 a ceiling.

**`comfyui/arms.conf`** (the four-field grammar; the mounts field empty in every row; the tests derive BA1 from this text):

```text
# arm       | ComfyUI arguments           | environment                                                                                                                                                              | mounts
base        |                             |                                                                                                                                                                          |
fp16acc     | --fast fp16_accumulation    |                                                                                                                                                                          |
fp8wmm      | --fast fp8_matrix_mult      | COMFY_BENCH_WEIGHT_DTYPE=fp8_e4m3fn                                                                                                                                      |
tunableop   |                             | PYTORCH_TUNABLEOP_ENABLED=1 PYTORCH_TUNABLEOP_FILENAME=/cache/tunableop/tunableop_results.csv PYTORCH_TUNABLEOP_MAX_TUNING_DURATION_MS=10 PYTORCH_TUNABLEOP_MAX_TUNING_ITERATIONS=10 |
miopen      |                             | COMFYUI_ENABLE_MIOPEN=1 MIOPEN_FIND_MODE=FAST MIOPEN_LOG_LEVEL=5                                                                                                         |
compile     |                             | COMFY_BENCH_COMPILE=1 TORCHINDUCTOR_CACHE_DIR=/cache/inductor TORCH_LOGS=recompiles                                                                                      |
```

`MIOPEN_LOG_LEVEL=5` is the one word the parent's `miopen` row does not name: without a log level MIOpen prints no find line, and
the parent's evidence row needs those lines (open point N7: a fix that makes the row's lines exist, the N3 precedent). The two
TunableOp env names are torch's (`aten/src/ATen/cuda/tunable/README.md`; the docs page documents the Python setters with the same
meanings and the 30 ms / 100 defaults); the coder confirms both names in the image's torch (`python3 -c "import torch.cuda.tunable"`
and the README of the installed version) and the summary says so.

**The identity** (`fingerprint.py build-comfy <inputs> --out <file>`, the components): `kind` (`comfy`), `workflow`, `image`
(`{"ref": COMFY_IMAGE, "id": <Id from wslc_inspect>}`), `comfy_ref`, `arms` (as the vLLM build reads them: `read_arms`), `base`,
`rounds`, `constants` (the `constants` JSON, whole), `models` (`{"<folder>/<file>": <pinned sha256>}` for the workflow's files, from
`models.conf`), `tools` (`<module>_sh|_py <hash>` of `_CB_UNIT_SH`, `comfy_bench`, `comfy_bench_evidence` when it exists,
`_CB_UNIT_PY`, and `bench_py`, `arms_conf`, `evidence_conf`), `machine` (`{"container_prefix": …}`). The inputs folder:
`comfy.env` (`KIND= WORKFLOW= IMAGE_REF= IMAGE_ID= COMFY_REF= BASE= ROUNDS= CONTAINER_PREFIX=`), `arms/`, `constants.json`,
`models` and `tools` (hex pairs). `compare`, `compare --merge`, `show` and `rounds_extended` are reused unchanged (a new arm and more
rounds are extensions; `show kind` prints `comfy`). The build is refused over `rounds/` or `rejected/` without a stored file
(`comfy_bench_fingerprint`'s line, the series' text with `bench` for `series`).

#### Test scenarios

RED first means what E2.S1 says. The worker scenarios run the worker through `bin/r9700 step --model <35B> comfy-bench -- bash
lib/comfy_bench.sh <outdir> zimage <rounds> <arm>...` in `bench_setup` (`comfy_setup` + `step_setup`'s machine file, the operator's
server running, the fingerprint built in the test shell by `comfy_bench_fingerprint <outdir> zimage <rounds> real <arm>...` with
`RUN_DIR` set, the stub's default answers: readiness `ok`, the vram answer free, the bench answer `ok` for every run with the
activation lines of every arm appended to the log at the cold run, the clear and the report answering). `R9700_COMFY_ARMS_CONF` and
`R9700_COMFY_EVIDENCE_CONF` point at the REAL tables unless a scenario copies one. `R9700_TIME_SCALE=100`, `R9700_CEILING_SCALE=1`
as the lifecycle tests. The exchange root is `$R9700_WORK_DIR/r9700/comfyui/bench`. `argv_of_verb run <n>` gives a container's
argv; the bench container's name is `r9700tune-comfy-<arm>-<round>`.

**`bench.py` against the fixture server (`tests/test_comfy_bench_py.py`)** — `tests/fixtures/comfy/comfy_server.py` is an `aiohttp`
server on `127.0.0.1:<free port>` started per test (recorded for the runner's killer), scripted by a JSON the test writes: per
prompt the websocket messages to send with delays, the history entry, the output file to write into `--output-directory` (a
PNG of the asked size made with Pillow, or a video made by `ffmpeg -f lavfi -i testsrc=size=1280x704:rate=24 -frames:v <n>`),
the `/system_stats` answer. `ffmpeg` and `ffprobe` are prerequisites of the suite (GitHub's Ubuntu runner carries them; a local
machine without them fails BP11 and BP12v with their names: `research/module_tests.md` *How it is run* says so).

- BP1 *The pure commands run on the host with the standard library.* `python3 -I -S comfyui/bench.py workflows` prints exactly
  `sd15`, `wan5b`, `zimage`; `metrics` prints `total_s sampler_s vae_s`; both exit 0 with `-S` (no site packages: an import of
  `aiohttp`, `numpy` or `PIL` at module level would fail here — the companion: `python3 -I -S -c "import aiohttp"` fails on the
  runner). RED first (the file does not exist).
- BP2 *One table.* `constants zimage` is JSON with `seeds`, `ceilings`, `inputs`, `nodes`, `metrics`; `graph zimage --seed 1` holds
  every value of `constants.inputs` at its node (the test walks the graph and asserts each: 1024, 1024, 8, `res_multistep`,
  `simple`, 1.0, 3.0, the three model file names, the empty negative as `ConditioningZeroOut`); `graph wan5b --seed 1`: the
  `LoraLoaderModelOnly` node with the LoRA name and `strength_model` 1.0 between `unet` and `shift`, `shift` 8.0, 121, 1280×704,
  3 steps `lcm`, cfg 1.0, the negative `CLIPTextEncode` text `""`, `VAEDecodeTiled` with the four named fields and their values, and
  no node of a class that takes an image file (`LoadImage`); `constants wan5b` names `lora` and `tile` fields with those values and
  `ceilings` `{"run_max_s": 600, "cold_max_s": 2700}`; `zimage` `{300, 1800}`; `sd15` `{120, 600}`.
- BP3 *The seeds.* `constants <w>` has `seeds.cold` 4242 and `seeds.measured` `[1, 2, 3]` for every workflow; `graph zimage --seed 7`
  puts 7 in the `KSampler`; the fixture's recorded prompts of `run --run cold` then `--run 1 2 3` carry the seeds 4242, 1, 2, 3.
- BP4 *The lines.* Four `run` calls against the fixture (each a success): the cold run prints no `r=` line and one `cold: total
  <s> s` line; each measured run prints exactly `<tag> zimage r=<n> total_s: <v>`, `… sampler_s: …`, `… vae_s: …`, in that
  order, three decimals; the nine `r=` lines (the cold run's line is not a bench line) written to a file pass `python3 lib/verdict.py comfy-check-block --tag base-1 --workflow
  zimage --metrics "total_s sampler_s vae_s"` (S1's command: this test needs S1 merged). RED first.
- BP5 *What is timed.* The fixture sends `executing` for `pos`, `sampler`, `vae`, `save`, then `null`, with scripted gaps (0.2,
  0.5, 0.3, 0.1 s) and writes the history 0.2 s after the last message: the JSON's `nodes_s.sampler` is within 0.1 of 0.5 and
  `nodes_s.vae` of 0.3; the printed `sampler_s` and `vae_s` equal them; `total_s` is at least the sum plus the history delay and at
  most that plus 1 s; `cached_nodes` is the fixture's `execution_cached` list; `cold` is true only for `--run cold`; `seed`,
  `server_argv` (the fixture's `system.argv`) and `vram_free_before`/`vram_total_before` are the fixture's numbers (BP14 folds in here).
- BP6 *A cached sampler is not a measurement.* The fixture lists `sampler` in `execution_cached` and sends no `executing` for it: exit
  1, the last line `CACHED: the sampler did not execute (cached: sampler)`, no `r=` line. RED first.
- BP7 *An execution error fails at once, and the history's error too.* `execution_error` with `node_id sampler`, `node_type KSampler`,
  `exception_message "boom"` after `pos`: exit 1 within 1 s of the message, the last line `EXECUTION_ERROR: node sampler
  (KSampler): boom`; a run whose websocket shows no error but whose history has `status.status_str` `error` and a message
  `["execution_error", {...}]`: exit 1 with the same kind. RED first.
- BP8 *A refused prompt and a run past its ceiling.* `/prompt` answering `{"error": {"message": "x"}}` with 400: exit 1, `PROMPT:
  refused: x`, no timing line, no websocket message waited for; a measured run whose fixture delays the final `executing` by 3 s under
  `COMFY_BENCH_TEST_RUN_MAX_S=1` (a test knob of `bench.py`, the environment only, replacing the table's `run_max_s`; its row in
  *Test knobs*): exit 3, `RUN_TIMEOUT 1.0` (one decimal, at least 1.0, under 2.0), within 2 s. RED first (the ceiling).
- BP9 *`COLD_TIMEOUT`.* `--run cold` under `COMFY_BENCH_TEST_COLD_MAX_S=1` with the same delay: exit 3, `COLD_TIMEOUT 1.0`; a worker
  scenario (BW7) shows nothing follows. RED first.
- BP10 *The image check.* A 1024×1024 noise PNG passes `check`; a 512×512 one fails `OUTPUT: size 512x512, expected 1024x1024`; a
  constant grey 1024×1024 fails `OUTPUT: the image is constant (every pixel <v>)`; `run` with the fixture writing each of the three:
  the first exits 0, the others 1 with the same line. RED first.
- BP11 *The video check.* A 121-frame `testsrc` clip passes `check --workflow wan5b`; a 97-frame clip fails `OUTPUT: 97 frames, expected
  121 (ffprobe -count_frames)`; a 121-frame clip of a constant colour (`color=c=gray`) fails `OUTPUT: the frames are constant`. RED first.
- BP12 *The drift of images.* Two identical PNGs: `drift r=1: mad 0.000 psnr identical`; a PNG against a copy with every pixel
  raised by 1 (clipped): `mad 1.000` (within 0.01) and a finite three-decimal `psnr` (`48.131` for an 8-bit image without clipping:
  the test computes the expected value with the same formula, not by hand); no reference file for seed 2: `drift r=2: unavailable
  (the reference of seed 2 is missing)`, exit 0; the numbers never appear for that seed. RED first.
- BP12v (split from BP12) *The drift of a video.* Two identical 24-frame clips: `identical`; a clip against the same with a 10 % brighter
  middle frame: a finite `psnr` and a `mad` above 0; the values are the mean over the frames (the test checks `mad` against the
  per-frame mean it computes from the decoded arrays).
- BP13 *The arm words reach the graph.* `COMFY_BENCH_WEIGHT_DTYPE=fp8_e4m3fn graph zimage --seed 1`: the `UNETLoader`'s
  `weight_dtype` is `fp8_e4m3fn`; without the word it is `default`; `COMFY_BENCH_COMPILE=1 graph wan5b`: a `TorchCompileModel`
  node (`backend inductor`) whose `model` input is `["lora", 0]` and the shift node's model is `["compile", 0]`; for `zimage` the
  compile's input is `["unet", 0]`; `COMFY_BENCH_FROB=1`: exit 2, one line `COMFY_BENCH_FROB is not a bench word; legal:
  COMFY_BENCH_WEIGHT_DTYPE, COMFY_BENCH_COMPILE`; without either word the graph equals `base`'s (byte-equal JSON). RED first.
- BP14 *The card readings* — folded into BP5 (the fixture's `vram_free`, `vram_total` are in the cold run's JSON and in every run's).

**The worker and the arm-round (`tests/test_comfy_bench.sh`)**

- BW1 *One fresh prefixed container with the isolation words.* `step … zimage 1 base`: exit 0; exactly one `run -d` call of a name
  starting `r9700tune-comfy-base-1`; its argv holds, as whole words, `--tmpfs` followed by `/data:exec,size=8g`, `-v` followed by
  `comfy-models:/models:ro`, `-v` followed by `r9700tune-comfy-cache:/cache`, `--gpus all`, `--shm-size 8g`, `--output-directory`
  followed by `/work/r9700/comfyui/bench/<outdir name>/base-1`, and no word `comfy-data`, `comfy-cache:/cache` (the operator's),
  `-p`, `--highvram`, `--lowvram`, `--normalvram`, `--gpu-only`, `--novram`, `--cpu`; a run with `--tmpfs /data` and no `:exec`
  fails this assertion (the test asserts the exact word). With `zimage 1 base fp16acc`: two `run -d` calls, two names, the second
  after the first's `stop` or its clean-stop `exec` (call order). RED first.
- BW2 *The cache clear before every arm-round.* `zimage 2 base`: before each bench container's `run -d` one foreground `run --rm` of
  a name `r9700tune-comfy-clear-<n>` whose program names `/cache/tunableop` and `mkdir -p`; `rounds/base-1/cache.txt` starts with
  `before clear:` lines holding the stub's size answer (`answers/comfy_cache`, default `12 /cache/miopen`); `answers/comfy_clear_rc
  2`: the worker exits 2, the outcome `KIND=refused` with `the bench cache could not be cleared`, no bench container was started, the
  supervisor's exit 2 (no retry), `vllm` restored. RED first (the refusal).
- BW3 *The bench cache volume is made only when missing.* No `$STUB/volumes/r9700tune-comfy-cache`: one `volume list`, one `volume
  create r9700tune-comfy-cache` before the clear's run, stdout `comfy: bench: created volume r9700tune-comfy-cache`; with the file
  present: no create. `fail-volume-list 3`: exit 1, the arm-round `rejected/` with `the volume list failed`.
- BW4 *The free-card wait.* `answers/comfy_vram` (call k takes line k, the last repeats; default `34000000000 34359738368`) scripted
  as three lines `1000000000 34359738368` then `33000000000 34359738368`: the record's `VRAM_FREE_BEFORE=33000000000`,
  `VRAM_TOTAL_BEFORE=34359738368`, four probe `exec` calls before the first `bench.py` exec (one readiness, three waits), at least
  two `t_scale 10` sleeps apart; all lines `1000000000 …`: exit 1, `rejected/base-1-*/reason` = `UNSTARTED: the card is not free
  (vram_free 1000000000 of 34359738368 after 300 s)`, the container stopped and not alive, no `bench.py` exec; the probe answering
  `vram: not in the answer`: `CARD: vram not reported by /system_stats`. RED first.
- BW5 *A container that does not become ready.* `answers/comfy_ready` = `fail`, `READY_TIMEOUT_S=60`: the arm-round in `rejected/`
  with `UNSTARTED: r9700tune-comfy-base-1 not ready after <n> s (…)`, its `server.log` saved (the stub's log answer), `stop
  r9700tune-comfy-base-1` logged, the container not alive before the worker's exit (call order: `logs` < `stop` < the worker's
  last line), exit 1; through `step` with `MAX_FAILED_TRIES=2`: two attempts, exit 7, one `pwsh.exe -Detach`. No `unsupported/`
  folder ever exists (question 8). RED first.
- BW6 *Every ceiling ends the container.* (a) `answers/comfy_bench_mode.1` = `slow 5` with `COMFY_BENCH_TEST_RUN_MAX_S` unset and the
  worker's exec ceiling scaled to 1 s (`R9700_COMFY_TEST_EXEC_S=1`, a knob of the worker that replaces `run_max_s + 60`; its row in
  *Test knobs*): the exec returns 124, `rejected/…/reason` starts `CEILING: the exec of run 1 was ended by the adapter`, `stop
  r9700tune-comfy-base-1` is logged after it and the container is not alive at the worker's exit; (b) `answers/comfy_bench_mode.cold`
  = `cold_timeout`: BW7; (c) a guard stop: `R9700_RAM_MIN_MB` above the stub's RAM answer during a `slow` run → the supervisor's RAM
  guard stops the session, `_step_stop_containers` stops the prefixed container, the attempt is swept as `INTERRUPTED` by the next
  worker start, and no container is alive at the supervisor's exit (the existing L-scenarios' shape); (d) `kill -TERM $SUP` during a
  `slow` run → exit 143, the container stopped by the cleanup, `vllm` listed again. In every case the next arm-round (when one runs)
  starts after the `stop` and a `list` that no longer shows the name (call order). RED first for (a).
- BW7 *`COLD_TIMEOUT`.* `answers/comfy_bench_mode.cold` = `cold_timeout` (the stub prints `COLD_TIMEOUT 1801.0` and exits 3): the
  arm-round in `rejected/base-1-<stamp>/` with `reason` line 1 `COLD_TIMEOUT: the cold run reached 1801.0 s of cold_max_s 1800`, no
  measured run exec, the container stopped, exit 1; `rounds/` holds no `base-1`; the word `slower` appears nowhere in the worker's
  output or the reason. RED first.
- BW8 *A complete arm-round by ONE rename.* `zimage 1 base`: `rounds/base-1/` holds `record.env` (the keys of the contract step 5 with
  `STOP=clean`, `INERT=no`), `bench.txt` (nine lines, passes `comfy-check-block`), `runs/cold.json 1.json 2.json 3.json`, `runs/cold.log
  1.log 2.log 3.log`, `runs/cold.txt`, `server.log` (equal to the stub's whole log answer at the last save), `outputs/` with four files,
  `evidence.txt`, `drift.txt`, `flags.txt`, `cache.txt`; the exchange folder `…/bench/<outdir name>/base-1` is gone; no `.part-`
  folder remains; the call log shows exactly one `mv`-free transition (the test watches `rounds/` through the run: a `base-1.part-*`
  then `base-1`, never both); the `logs` call count is 5 (after each run and before the stop). RED first.
- BW9 *A rejected arm-round.* (a) `answers/comfy_bench_mode.2` = `error`: `rejected/base-1-<stamp>/reason` line 1 `EXECUTION_ERROR:
  node sampler (KSampler): boom`, exit 1; (b) `answers/comfy_bench_mode.1` = `constant`: `OUTPUT: the image is constant (…)`; (c)
  `answers/comfy_bench_lines` with the `r=3 vae_s` line left out: `reason` holds `check-block: expected 9 lines, found 8` and `missing
  r=3 vae_s`; (d) `answers/comfy_bench_mode.1` = `cached`: `CACHED: …`. Each: the container stopped, `rounds/base-1` absent, the
  worker exit 1, the step's failed try counted (`failed try 1 of 3` in the supervisor log). RED first for (c).
- BW10 *The load flag.* `answers/comfy_bench_log.2` = two lines `Requested to load WAN21` and `loaded completely 9.5 1.2 True`: `flags.txt`
  has `run 2: load 2, recompile 0` and `run 1: load 0, recompile 0`; `record.env` `FLAGS_RUN_2=load=2,recompile=0`; `bench.txt` holds
  no such line (it still passes `comfy-check-block`). RED first.
- BW11 *The recompile flag.* With `compile` (its default stub log answer at the cold run: a `TorchCompileModel` node in every run's
  JSON and `cache_after.inductor.files` 3) and `answers/comfy_bench_log.3` = `Recompiling function forward in /opt/x.py:12`: `flags.txt`
  `run 3: load 0, recompile 1`; `evidence.txt` names `node=TorchCompileModel: present` and `cache=inductor: present (3 files)`, and
  the recompile line is not among the evidence; with the cold run's `cache_after.inductor.files` 0: rejected `EVIDENCE: activation
  cache=inductor: missing (runs/cold.json: 0 files)` although the recompile line is there. RED first.
- BW12 *The balanced order.* `zimage 2 base fp16acc`: the bench containers' run calls in log order are `base-1`, `fp16acc-1`,
  `fp16acc-2`, `base-2` (read from the names); `zimage 3 base fp16acc` after that: `base-3`, `fp16acc-3` only.
- BW13 *The part sweep.* A planted `rounds/base-1.part-20261108T000000Z-1/` with a `record.env` naming `RUN_ID=20261108T000000Z-1` and
  a planted `$RESULTS_DIR/runs/20261108T000000Z-1/status` = `interrupted`: the next worker start moves it to
  `rejected/base-1-<stamp>/` with `reason` `INTERRUPTED: base-1.part-20261108T000000Z-1 was left by run 20261108T000000Z-1 (its status:
  interrupted)`, the worker's first lines say so, and `base-1` is then run (not skipped); without the status file: `(its status: not
  found)`. The exchange folder `…/bench/<outdir name>/base-1` planted with a file is removed at that start. RED first.
- BW14 *The resume after a lost arm-round.* `zimage 2 base fp16acc` through `step_bg`; `wait_for` the `exec` of `bench.py` for
  `fp16acc-2`'s cold run; `kill -KILL $SUP` (no cleanup); then `comfy_bench_left <outdir> 2 base fp16acc` prints `2`,
  `comfy_bench_recorded` `2`; the same `step` command again: the sweep's line names `fp16acc-2.part-…` and the run id, the bench
  containers started are `fp16acc-2` then `base-2` (round 2 reversed, continued from the first missing), exit 0, four records, the two
  kept records byte-for-byte unchanged (the test hashes them before and after). RED first.
- BW15 *The identity re-check before every arm-round.* `zimage 2 base` with `on-stop-r9700tune-comfy-base-1` (the stub's hook at the
  first container's end) appending one argument word to the `base` row of the arms copy: the second arm-round is not started; the
  outcome is `KIND=refused RC=2` with a line `fingerprint differs: arms.base.args: …`; the supervisor exits 2 without a retry; one
  record. The same with the evidence copy's `base` row changed (`fingerprint differs: tools.evidence_conf: …`), with `bench.py`'s placed
  copy touched (the tools hash), and with `answers/inspect` answering another `Id` (`fingerprint differs: image.id: …`). RED first.
- BW16 *The gate before every arm-round.* The disk gate answering a new record (the stub's `disk` answers): the worker's outcome
  `KIND=disk_gate`, exit 1, no container; `set_load 9` after the first arm-round: exit 3 before the second (`NOT QUIET: fp16acc round 1
  (…)`), the supervisor waits and admits again when the load falls; `R9700_COMFY_ARM_SECONDS=100000`: exit 4 at the first gate,
  `comfy-bench: 2 arm-rounds no longer fit before the deadline`, the supervisor's exit 6; the default allowance for `zimage` is read
  back as 3300 (the worker prints `fit: <n> s per arm-round` once at its start).
- BW17 *The drift pairing.* `zimage 2 base fp16acc`: before `fp16acc-1`'s measured runs the files of `rounds/base-1/outputs/` with run
  numbers 1–3 are in `…/bench/<outdir name>/ref/` (the test's `on-start-` hook of the `fp16acc` container copies the folder listing
  to a file); `rounds/fp16acc-1/drift.txt` holds the stub's three `drift r=<n>:` lines; `rounds/base-2/drift.txt` the same (base against
  base-1); `rounds/base-1/drift.txt` is `drift: unavailable (base-1 is the reference)`; with `rounds/base-1` planted as a `rejected/`
  attempt only: `fp16acc-1`'s `drift: unavailable (no base-1 record)`; `ref/` is gone after each arm-round. RED first.
- BW18 *Never the operator's containers.* `comfyui` NOT listed (the owner check would refuse) but `vllm` running: the worker's `stop`
  calls name only `r9700tune-comfy-*`; no `stop vllm` from the worker (the supervisor's one stop is before the worker); a
  `comfyui-fetch` container planted stays alive through the run; every `run` the worker made has a name starting `r9700tune-`.
- BW19 (added) *The clean stop and the forced stop.* Default: the stop of a validated arm-round is one `exec r9700tune-comfy-base-1
  python3 -c <program naming SIGINT>` after the last `logs`, the stub ends the container, no `stop` call for it, `record.env`
  `STOP=clean`, one report container (`run --rm --name r9700tune-comfy-report-<n>` whose program names `tunableop_results.csv`) after
  the container is gone (call order: the clean-stop `exec` < a `list` without the name < the report's `run`); `answers/comfy_clean_stop`
  = `ignore`: the container stays, then `stop r9700tune-comfy-base-1` after `t_scale 60`, `STOP=forced`, the record still final for
  `base`; for `tunableop` with `ignore`: rejected `EVIDENCE: activation tunable=tunableop_results.csv: missing (the stop was forced:
  the file is written at the server's exit)`. With `answers/comfy_tunableop` holding two `Validator` lines and one result row and a
  clean stop: `rounds/tunableop-1/tunableop_results.csv` equals it and `evidence.txt` says `tunable=tunableop_results.csv: present (1
  row)`. RED first.

**The evidence (`tests/test_comfy_bench.sh`)** — each arm with its default stub answers, then one answer removed or changed.

- BE1 *Present → recorded; absent → rejected.* `fp16acc`: `evidence.txt` has `activation log=Enabled fp16 accumulation: present
  (server.log:<n>)` and the record is final; with `answers/comfy_evidence.fp16acc` emptied: `rejected/fp16acc-1-*/reason` line 1
  `EVIDENCE: activation log=Enabled fp16 accumulation: missing (server.log)`, exit 1. RED first.
- BE2 *The argv alone is never activation.* `fp8wmm` with the stub's `system.argv` holding `--fast fp8_matrix_mult` and the log
  answer without the `float8_e4m3fn` line: rejected naming `log=model weight dtype torch\.float8_e4m3fn: missing`; with the line and
  an argv without the word: rejected naming `argv=fp8_matrix_mult: missing (runs/cold.json)`; both present: final. An evidence copy
  whose `fp8wmm` activation is `argv=fp8_matrix_mult` alone: `comfy_bench_check` exits 2 before the lock with `r9700: comfy: bench:
  arm_evidence.conf: fp8wmm: the activation evidence is the argv alone; a passed flag is never proof it acted`. RED first.
- BE3 *`fp16acc` inert only with both bf16 lines.* Log answer with `model weight dtype torch.bfloat16, manual cast: None` and `VAE
  load device: cuda:0, offload device: cpu, dtype: torch.bfloat16`: `record.env` `INERT=yes`, `INERT_EVIDENCE=` both lines, the
  worker prints `fp16acc-1: inert on zimage (…)`; with the VAE line `dtype: torch.float16`: `INERT=no`, no inert line. RED first.
- BE4 *`tunableop` needs rows.* `answers/comfy_tunableop` empty: rejected `tunable=tunableop_results.csv: missing (empty)`; only
  `Validator` lines: `missing (no result row)`; a row: present (BW19).
- BE5 *`miopen`.* Log answer without `cudnn.enabled = False` and with `MIOpen(HIP): Info [Find] …` in the cold cut: final; with the
  `Set: torch.backends.cudnn.enabled = False for better AMD performance.` line: rejected `nolog=cudnn\.enabled = False: present
  (server.log:<n>)`; without a find line in the cold cut (one only in run 2's cut): rejected `coldlog=…: missing (runs/cold.log)`.
- BE6 *`compile`.* BW11's two halves; plus a measured run whose JSON lacks the node (`answers/comfy_bench_nodes.2` without
  `TorchCompileModel`): rejected `node=TorchCompileModel: missing (runs/2.json)`.
- BE7 *`base`.* With the attention line: final; without it: rejected `log=Using pytorch attention: missing (server.log)`.
- BE8 (added) *The evidence table's grammar.* `comfy_evidence_load` on a copy: a row with one `|` → 2, `r9700: comfy: <file>:<n>: a row
  has three fields (arm, activation, inertness), this one has 2`; an unknown kind `foo=x` → `… unknown check kind "foo"; legal: log,
  nolog, coldlog, node, cache, tunable, argv`; an empty argument `log=` → `… the check "log=" has no argument`; a row twice → `… defined
  twice`; `-` fields load as none. RED first.

**The tables (`tests/test_comfy_bench.sh`)**

- BA1 *The six rows.* `arms_load comfyui/arms.conf` → `arms_names` is exactly `base fp16acc fp8wmm tunableop miopen compile` in file
  order; `base` has empty args, env and mounts; `fp16acc`'s args are exactly `--fast fp16_accumulation` and its env empty; `fp8wmm`
  `--fast fp8_matrix_mult` and `COMFY_BENCH_WEIGHT_DTYPE=fp8_e4m3fn`; `tunableop` no args and the four `PYTORCH_TUNABLEOP_*` words;
  `miopen` the three `MIOPEN`/`COMFYUI_ENABLE_MIOPEN` words; `compile` the three words of its row; every mounts field empty (the test
  reads the expectation from this spec's table, typed once in the test).
- BA2 *One evidence row per arm, both ways.* The arm names of `arms.conf` equal the row keys of `arm_evidence.conf` as sets;
  `comfy_bench_check zimage 1 base` on copies with a `miopen` row removed from the evidence → 2, `arm "miopen" has no row in
  arm_evidence.conf`; with an extra `frob` evidence row → 2, `arm_evidence.conf names "frob", which is not an arm of arms.conf`.
- BA3 *No forbidden word.* No row's env holds `PYTORCH_HIP_ALLOC_CONF` (trap 1), no row's args hold a memory-mode word, `--listen`,
  `--port`, `--output-directory`, `--base-directory`, `--models-directory` (the worker's own), no row's mounts field is non-empty;
  `tunableop` carries both tuning bounds and the file name; `compile` carries `TORCHINDUCTOR_CACHE_DIR=/cache/inductor` (N3). A copy
  with `PYTORCH_HIP_ALLOC_CONF=expandable_segments:True` in a row: `comfy_bench_check` exits 2 naming trap 1. RED first (the check).

**The identity (`tests/test_comfy_bench.sh`, `tests/test_fingerprint.py`)**

- BF1 *A version-1 document.* After `comfy_bench_fingerprint <outdir> zimage 2 real base fp16acc`: `fingerprint.py show <file> kind` →
  `comfy`; `show … workflow` → `zimage`; `show … base` → `base`; `show … rounds` → `2`; `show … arms` → `base fp16acc`; `show …
  image.ref` → `comfyui-r9700:local`; `show … image.id` → the stub's `sha256:stub`; `show … comfy_ref` → `v0.44.0`; `show …
  constants.seeds.cold` → `4242`; `show … constants.ceilings.cold_max_s` → `1800`; `show … models` lists `diffusion_models/z_image_turbo_bf16.safetensors`,
  `text_encoders/qwen_3_4b.safetensors`, `vae/ae.safetensors` and no `loras/` key; `show … tools` names `bench_py`, `arms_conf`,
  `evidence_conf`, `comfy_bench_sh`, `fingerprint_py`, `verdict_py`; `compare <file> <file>` → 0, nothing. In Python
  (`tests/test_fingerprint.py`): `build-comfy` over a hand-written inputs folder gives these leaves, and a `comfy.env` without
  `IMAGE_ID=` fails with `fingerprint: comfy.env: IMAGE_ID= is missing`, exit 2. RED first (`build-comfy` is not a command).
- BF2 *A change refuses, an extension merges.* After BF1: a copy of `arms.conf` with `--fast fp16_accumulation --x` for `fp16acc` →
  `comfy_bench_fingerprint … real …` exits 2 with `fingerprint differs: arms.fp16acc.args: ["--fast","fp16_accumulation"] ->
  ["--fast","fp16_accumulation","--x"]` on stderr, the stored file unchanged, no container call; the same for an edited evidence
  row (`tools.evidence_conf`), a `bench.py` edit (`tools.bench_py`; the placed copy is re-placed first), a changed pin in a
  `models.conf` copy (`models.diffusion_models/z_image_turbo_bf16.safetensors`, BF5), another `COMFY_REF` (`comfy_ref`), another
  inspect `Id` (`image.id`); `… 3 real base fp16acc` → `fingerprint: rounds extended 2 -> 3`, merged; `… 2 real base fp16acc
  miopen` → `fingerprint: arm miopen added`, merged; `dry` writes nothing (no file in a new outdir, the stored file byte-identical).
- BF3 *No new fingerprint over records whose identity is lost.* `rounds/` present and no `fingerprint.json`: exit 2 with the
  series' line with `bench` (`comfy: bench: <outdir> has rounds/ or rejected/ but no fingerprint.json: …; use a new --out name`),
  nothing written; `dry` the same.
- BF4 *A missing image.* `answers/inspect_rc 1`: exit 2, `r9700: comfy: bench: the image comfyui-r9700:local is not there (inspect
  code 1); run bin/r9700 comfy build first`, no fingerprint, no container; a missing model file (the throwaway container's listing
  answer `answers/comfy_models_listing` without the VAE line): exit 2, `/models/vae/ae.safetensors is not in the models volume
  (zimage of comfyui/models.conf); run bin/r9700 comfy fetch zimage first`; the listing container's argv has `comfy-models:/models:ro`,
  no `--gpus`, `--entrypoint sh`. RED first.
- BF5 *The model identity is the pin, for the workflow's files only.* `comfy_bench_fingerprint … wan5b 1 real base`: `show … models`
  lists exactly the four `wan5b` files of `models.conf` including `loras/Wan2_2_5B_FastWanFullAttn_lora_rank_128_bf16.safetensors`
  with the pinned hash; a `models.conf` copy with that pin changed: BF2's difference naming the `loras/` key; a changed pin of an
  `sd15` file: no difference for `wan5b`.

**The stub and the probe (`tests/test_stubs.sh`, `tests/test_adapter_comfy.sh`)**

- SC1 *The bench answers.* `wslc exec r9700tune-comfy-base-1 env COMFY_BENCH_X=1 python3 /work/r9700/comfyui/bench.py run zimage --tag
  base-1 --run 1 --out /work/r9700/comfyui/bench/o/base-1` (the container recorded): writes `run-1.json` (a JSON with `nodes`,
  `cached_nodes`, `server_argv` from `answers/comfy_bench_json` or the default) and `zimage_r1_00001_.png` (a stub file) into
  `$R9700_WORK_DIR/r9700/comfyui/bench/o/base-1/`, prints the three lines `base-1 zimage r=1 total_s: 12.345` … (from
  `answers/comfy_bench_lines`, lines keyed `r=<n> <metric>: <v>` with the tag and workflow prefixed by the stub; default
  values 12.345, 10.000, 1.500 for run 1 and +0.010 per run), appends `answers/comfy_bench_log.<run>` to `answers/logs` (for the cold
  run also `answers/comfy_evidence.<arm>`, default the activation lines of this spec's table per arm, the arm from the name), exit 0;
  `--run cold` prints `cold: total 40.000 s` and writes `run-cold.json` with `cold: true`, `cache_after` from `answers/comfy_bench_cache`
  (default inductor 0 files; `compile`: 3). `answers/comfy_bench_mode.<run>` (or `.<arm>.<run>`): `ok`, `error` (prints `EXECUTION_ERROR:
  node sampler (KSampler): boom`, 1), `constant` (`OUTPUT: the image is constant (every pixel 128)`, 1), `cached`, `refused` (`PROMPT:
  refused: x`, 1), `slow <s>` (sleeps, recorded sleeper), `cold_timeout` (`COLD_TIMEOUT 1801.0`, 3), `run_timeout`, `hang` (`stub_hang`).
  `drift` prints three `drift r=<n>: mad 0.000 psnr identical` lines (or `answers/comfy_drift`). An exec into a name not listed
  fails as today. RED first.
- SC2 *The clear container.* A foreground `run --rm --name r9700tune-comfy-clear-1 -v r9700tune-comfy-cache:/cache --entrypoint sh img -c
  <program naming /cache/tunableop>`: prints `answers/comfy_cache` (default `12 /cache/miopen` and three more lines) with CRLF, removes
  the files under `$STUB/cache/` (the stub's bench cache content, planted by a test) and exits `answers/comfy_clear_rc` (default 0).
- SC3 *The log grows per run.* After SC1's cold run and run 1: `wslc logs r9700tune-comfy-base-1` prints the planted `answers/logs`
  plus the evidence lines plus run 1's scripted lines, in that order, so a worker that saves after each exec sees a growing file.
- SC4 *The isolation words are logged as given.* The detached run's `calls.argv` block holds `--tmpfs` and `/data:exec,size=8g` as two
  consecutive lines and `comfy-models:/models:ro` as one line (the stub already records every argument; this pins it for BW1).
- SC5 (added) *The report container and the clean stop.* A foreground run whose program names `tunableop_results.csv`: prints
  `answers/comfy_cache_report` (default four `du` lines, `--- tunableop_results.csv`, then `answers/comfy_tunableop` when present),
  exit `answers/comfy_report_rc` (default 0); `wslc exec <name> python3 -c <program naming SIGINT>`: ends the container's record (as
  `stop` does) unless `answers/comfy_clean_stop` is `ignore`; prints nothing; exit 0.
- SC6 (added) *The widened readiness answer.* `answers/comfy_ready` `ok` now prints `device cuda:0 AMD Radeon AI PRO R9700 : native`,
  `vram_free <f>`, `vram_total <t>` (from `answers/comfy_vram`, call k line k, default `34000000000 34359738368`; the word `none` prints
  `vram: not in the answer` instead of the two lines) and `ready`; E1's CS2 still finds its `device` line.
- AP1 *The widened probe.* `comfy_probe_program` against a fake `urlopen` (E1's AW5 shape): a 200 with `{"devices": [{"name": "cuda:0 X
  : native", "vram_total": 34359738368, "vram_free": 34000000000}]}` → `device cuda:0 X : native`, `vram_free 34000000000`,
  `vram_total 34359738368`, `ready`, exit 0; without the two keys → `device …`, `vram: not in the answer`, `ready`, exit 0 (ComfyUI is
  ready; the card reading is a separate fact, never 0); a non-integer `vram_free` → the same `not in the answer` line; every AW5
  failure case unchanged; E1's AW5 assertions on the first and last lines still hold. RED first.

#### Brief for the Sonnet coder

Read first: this section whole, *Facts every story uses*, *The seam between S2 and S3*; the parent's *The bench's measurement
contract*, *The tuning series* and *Records and growth*; `lib/series.sh` whole (the worker you mirror: `series_unit`,
`_series_gate`, `_series_recheck`, `_series_validate`, `_series_reject`, `series_sweep_parts`, `series_fingerprint`,
`_series_probe`); `lib/kernels.sh:1–80`; `lib/moe.sh:60–100` and `lib/moe_verb.sh:30–50` (`moe_place`); `lib/comfy.sh:40–104`,
`:404–444`; `lib/run_guarded.sh:1–46`, `:224–287`, `:443–493`; `lib/step.sh` whole; `lib/adapter.sh:1–40`, `:84–110`, `:291–334`,
`:520–525`; `lib/fingerprint.py` whole; `lib/verdict.py` as S1 merged it (`comfy-check-block`); `comfyui/entrypoint.sh`;
`tests/stubs/wslc:143–237`, `:328–371`; `tests/stubs/stub_common.sh:1–60`; `tests/lib/comfycase.sh`, `tests/lib/stepcase.sh`,
`tests/lib/seriescase.sh`; `tests/test_series.sh:1–80`; `tests/test_comfy.sh:619–660` (MC1); ComfyUI v0.44.0's
`comfy/model_management.py`, `comfy/model_base.py`, `comfy/sd.py`, `comfy/model_patcher.py`, `comfy/ldm/modules/attention.py`
(the exact evidence and flag strings), `execution.py` and `server.py` (`/system_stats`, `/history`); the hand-made prototype (the
main session gives its location; copy no path or name from it). Reuse, never copy: `series_left`, `series_recorded`,
`_series_reject`, `_series_disk_gate`, `_series_stamp`, `_series_iso`, `_series_hash_path`, `moe_place`, `container_name`,
`container_host_path`, `comfy_volume_ensure`, `ready_wait`, `comfy_probe`, `_rg_listing_tries`, `wslc_*`, `t_scale`,
`outcome_write`, `quiet_check`, `disk_gate_check`, `arms_load`/`arm_args`/`arm_env`/`arm_mounts`, `comfy_models_load`,
`fingerprint.py`'s `read_arms`, `hex_pairs`, `document_of`, `write_atomic`, `read_document`. No line of `lib/comfy_bench*.sh`,
`comfyui/bench.py` or the tests names `wslc` as a command word (the seam).

1. **`comfyui/bench.py`** (new; a docstring in the style of `lib/fingerprint.py`'s: the commands, the exit codes, the ONE table).
   Order: the constants table and `constants`/`workflows`/`metrics`/`graph` (standard library; the imports of `aiohttp`, `numpy`,
   `PIL` happen inside the functions that need them, so BP1's `-S` run passes); then `check` and `drift`; then `run` (the
   prototype's loop, widened as *The contract as text* says). Two test knobs, the environment only: `COMFY_BENCH_TEST_RUN_MAX_S`,
   `COMFY_BENCH_TEST_COLD_MAX_S` (BP8, BP9). Under 800 lines; if the graphs push it over, `comfyui/bench_graphs.py` beside it
   (placed as an `optional`-less second `required` asset row; its hash in `tools`).
2. **`comfyui/arms.conf`, `comfyui/arm_evidence.conf`** exactly as the two tables above (a header comment each: the grammar in one
   paragraph, the parent's arm table as the source, the two words the spec adds and why — `MIOPEN_LOG_LEVEL`, the TunableOp file).
3. **`comfyui/models.conf`**: the `wan5b loras …` line (question 10); the hash read once with `curl -sI -L` and the command and its
   answer in the summary. `tests/test_comfy.sh` MC1: the parity row for the LoRA's pin (`:643`'s shape).
4. **`lib/comfy_bench.sh`** (new; the header in the style of `lib/series.sh:1–27`: the seam functions of this document's table, the
   worker's codes, the record, the test knobs `R9700_COMFY_ARMS_CONF`, `R9700_COMFY_EVIDENCE_CONF`, `R9700_COMFY_ARM_SECONDS`,
   `R9700_COMFY_TEST_EXEC_S`). The seam functions as the table names them, then the worker's: `comfy_evidence_load <file>` (the
   arrays `_CE_ACT[<arm>]`, `_CE_INERT[<arm>]`, each a `;`-joined list; BE8's refusals in one pass, the `comfy_models_load` shape),
   `_cb_order`, `_cb_sweep_parts`, `_cb_gate`, `_cb_recheck`, `_cb_clear`, `_cb_start`, `_cb_card_free`, `_cb_run <k>`, `_cb_cut <k>`,
   `_cb_flags <k>`, `_cb_drift`, `_cb_validate`, `_cb_clean_stop`, `_cb_gone <name>`, `_cb_report`, `_cb_evidence`, `_cb_check_one
   <kind> <argument> <part>` (one function per kind is fine; the dispatch is a `case`), `comfy_bench_unit`, `comfy_bench_main`, the
   two-face tail. The constants `_CB_CLEAR_SH`, `_CB_REPORT_SH`, `_CB_SIGINT_PY` (`import os, signal; os.kill(1, signal.SIGINT)`),
   `_CB_LOAD_RE`, `_CB_RECOMPILE_RE`, `_CB_ROUND_OVERHEAD_S=600`, `_CB_CARD_WAIT_S=300`, `_CB_STOP_WAIT_S=60`, `_CB_EXCHANGE=/work/r9700/comfyui/bench`.
   Messages `comfy-bench: <text>` on stdout (the worker's lines go to the step log) and `r9700: comfy: bench: <text>` on stderr for
   the seam's refusals. If the file passes 700 lines, the evidence and drift functions move to `lib/comfy_bench_evidence.sh`,
   sourced by both faces and listed in `_CB_UNIT_SH`.
5. **`lib/fingerprint.py`**: `build-comfy <inputs> --out <file>` (`cmd_build_comfy`, `build_comfy_components`: `read_comfy_env`
   with the eight required keys, `read_arms`, `constants.json` loaded as JSON, `hex_pairs` for `models` and `tools`); the docstring's
   command list; `compare`, `show`, `--merge`, `check-quality` untouched (`tests/test_fingerprint.py`'s existing cases pass with no
   edit; BF1's Python cases are new tests in that file).
6. **`lib/adapter.sh`**: `_COMFY_PROBE_PY` widened (AP1; the two lines between `device` and `ready`; `int()` of each value, the
   `not in the answer` line on any failure of that read); `comfy_probe` unchanged; the header row. `tests/test_adapter_comfy.sh`: AP1;
   E1's AW5 adjusted only where it asserted the line COUNT (say so in the summary).
7. **`tests/requirements.txt`**: the pins (question 10). `tests/run.mjs` installs it already (`:319–329`); nothing else changes there.
8. **The stub**: `tests/stubs/wslc` — in `exec_in`, before the `*system_stats*` branch, a branch for a word matching `*/bench.py` after
   optional `env` words (`comfy_bench_call`), one for a `-c` program holding `SIGINT` (`comfy_clean_stop`); in `run_container`, before
   the generic foreground branch, `comfy_clear_is` (a program naming `/cache/tunableop` and `rm -rf`) → `comfy_clear_answer`,
   `comfy_report_is` (a program naming `tunableop_results.csv`) → `comfy_report_answer`, `comfy_listing_is` (a program naming
   `/models` and `stat`) → `answers/comfy_models_listing` (default: the files of every set with sizes); the `ok` readiness answer's
   four lines; `tests/stubs/stub_common.sh`'s header gains every new file: `answers/comfy_bench_mode[.<arm>].<run>`,
   `comfy_bench_lines`, `comfy_bench_json`, `comfy_bench_log.<run>`, `comfy_bench_nodes.<run>`, `comfy_bench_cache`,
   `comfy_evidence.<arm>`, `comfy_drift`, `comfy_cache`, `comfy_clear_rc`, `comfy_cache_report`, `comfy_report_rc`,
   `comfy_tunableop`, `comfy_clean_stop`, `comfy_vram`, `comfy_models_listing`, and `cache/` (the stub's bench cache content).
9. **`tests/fixtures/comfy/comfy_server.py`** (new; `aiohttp`; scripted by a JSON path in `COMFY_FIXTURE_SCRIPT`; writes only below
   the folder it is given; records its pid for the runner) and **`tests/test_comfy_bench_py.py`** (BP1–BP13, BP12v; the server started
   per test on a free port, `bench.py` run as a subprocess with `COMFY_BENCH_API=http://127.0.0.1:<port>`, a test knob of the program
   — the environment only, default `http://127.0.0.1:8188` — with its row in *Test knobs*).
10. **`tests/test_comfy_bench.sh`** (BW1–BW19, BE1–BE8, BA1–BA3, BF1–BF5's bash half; `bench_setup` as *Test scenarios* defines it;
    every wait a bounded `wait_for`; every process recorded; `kill_recorded_pids "$CASE"` where containers are left);
    **`tests/test_fingerprint.py`** (BF1's Python cases); **`tests/test_stubs.sh`** (SC1–SC6).
11. **`research/module_tests.md`**: the rows of `tests/test_comfy_bench.sh`, `tests/test_comfy_bench_py.py`, `tests/fixtures/comfy/`;
    the knobs of steps 1, 4, 9 and the stub files of step 8 in *Test knobs*; `ffmpeg`/`ffprobe` as a prerequisite in *How it is run*;
    in *What it does not prove*: the eight unverified facts of *Facts every story uses* (the stub stands in for each; S3's acceptance
    observes them), and N2's clean stop. Nothing in `README.md`, `research/architecture.md` or `research/module_comfyui.md` (S3's).

**Never**: a second implementation of the part sweep, the rejection, the fingerprint document, the placement or the readiness wait;
a `bench.txt` line that is not S1's grammar; a seed, a ceiling or a tile value typed anywhere but the constants table; a stop of a
container whose name is not prefixed; a `machine.env` field; an edit of `lib/config.sh`, `config/arms.conf`, `lib/comfy.sh`'s modes,
S1's `verdict.py` paths or `tests/test_verdict*.py`; a real network call in a test (the LoRA's hash is read once by you, by hand, and
pinned).

**Commands.**

```bash
node tests/run.mjs tests/test_comfy_bench.sh tests/test_comfy_bench_py.py tests/test_fingerprint.py tests/test_stubs.sh tests/test_adapter_comfy.sh tests/test_comfy.sh tests/test_series.sh tests/test_verdict_comfy.py
node tests/run.mjs
bash tests/check_static.sh
node .agents/conventions/tools/plan-lifecycle.mjs
```

Report the runner's PASS line per file and its total, the static check's exit code, each RED observation (the failing line, then
the pass), the LoRA's `X-Linked-ETag` as read with its command, the three pins with the command that chose them, the two TunableOp
names as confirmed in torch, the five ComfyUI strings as read at `COMFY_REF`, and the line count of every new file.

#### Done when

- BP1–BP13 and BP12v, BW1–BW19, BE1–BE8, BA1–BA3, BF1–BF5, SC1–SC6 and AP1 pass through `node tests/run.mjs` with the pinned
  requirements installed by the runner; every refusal and guard marked RED first was seen failing first and the summary says how.
- One arm-round in the stub world is one fresh prefixed container with `--tmpfs /data:exec,size=8g`, the models volume `:ro` and
  the bench cache cleared before it; a cold run past `cold_max_s` is `COLD_TIMEOUT` and nothing follows; every ceiling, guard stop and
  rejection ends the container and sees it gone; an arm-round without its activation evidence is rejected and an inert `fp16acc` is
  recorded as inert; a load and a recompile are flagged per measured run outside `bench.txt`; the record is made by ONE rename and
  holds the files of contract step 14; the same command continues from the first missing arm-round in the balanced order after a lost
  one and refuses another experiment before any container; the clean stop is recorded as `clean` or `forced`.
- `bench.py` against the fixture server prints the three metrics per measured run and nothing for the cold run, fails fast on an
  `execution_error`, a refused prompt, a cached sampler, a wrong size, a constant image or a truncated video, and computes the drift
  with `identical` for an exact match and `unavailable` for a missing reference; its pure commands run with `-S`.
- `fingerprint.py build-comfy` writes a version-1 document with `kind` `comfy` that `compare`, `--merge` and `show` read unchanged;
  `tests/test_fingerprint.py`'s existing cases and `tests/test_verdict*.py` pass with no edit.
- The LoRA line is in `models.conf` with its pin read once from the source and MC1's parity row; the three pins are in
  `tests/requirements.txt`; the two tables carry the rows of this spec; `bash tests/check_static.sh` exits 0 (the seam is still
  exactly `lib/adapter.sh`); `node .agents/conventions/tools/plan-lifecycle.mjs` is clean; every new file is under 800 lines; CI green.

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

- **N1 — the arm name (settled, 2026-11-08).** The parent named the arm with an underscore, which `_RE_ARM` (`^[a-z0-9]+$`,
  `lib/config.sh:102`) and `verdict.py`'s `arm_name` (`lib/verdict.py:395–398`) refuse. The parent now names it `fp8wmm`: a
  fix that only satisfies the toolkit's existing grammar, not a plan change. `_RE_ARM` stays as it is.
- **N2 — `tunableop`'s activation evidence may never be readable.** The evidence is "the results file is not empty and holds the
  workload's shapes" (`:304`). By PyTorch's documentation (not read in this repository, fact 6) TunableOp keeps its results in
  memory and writes the file when the process ends; the bench stops its container with a signal, and ComfyUI is not known to
  run Python's exit handlers on one. If the file is not written, every `tunableop` arm-round is rejected for missing evidence: a
  false rejection, not a measurement. Smallest fix: none until it is observed; S2's spec checks the file's moment in the
  fixture's terms and the acceptance (or the by-hand run of its item 4) observes it before E3. If the file is written only on a
  clean exit, the evidence row changes (for example to TunableOp's own verbose lines in the cold run) — a change of the
  evidence table, the owner's.
  Design (Fable, 2026-11-08; the S2 spec, *N2: the TunableOp file*): PyTorch's page confirms the file is written when the process ends,
  so every recorded arm-round ends its container with a clean stop (SIGINT to pid 1, the server's normal exit) before the hard stop,
  and a report container copies the file into the record; the evidence row is unchanged. Open for the owner only if the acceptance
  sees that the clean stop does not end ComfyUI normally on the card: the fallback (TunableOp's own verbose lines) changes the row.
- **N3 — `compile`'s activation evidence needs the inductor cache in `/cache`.** The evidence is "the inductor cache written in
  the cold run" (`:306`), and the bench cache is said to hold "the inductor cache of `compile`" (`:399`). The arm's environment
  names only `COMFY_BENCH_COMPILE=1` and `TORCH_LOGS=recompiles` (`:306`); by PyTorch's documentation the inductor writes its
  cache under `/tmp` in the container unless `TORCHINDUCTOR_CACHE_DIR` says otherwise (fact 7), so neither the clear nor the
  evidence check would see it. Smallest fix: the `compile` row of `comfyui/arms.conf` also sets `TORCHINDUCTOR_CACHE_DIR` under
  `/cache` (`/cache/inductor`). This only makes the parent's own two sentences true (plan-change-control: "a fix that only
  satisfies the plan as written" is not a change); Settled 2026-11-08: the parent's `compile` row now sets `TORCHINDUCTOR_CACHE_DIR=/cache/inductor`.
- **N4 — the LoRA is not in E1's fetch.** E2's acceptance takes its models from E1's acceptance run 2 (`:558–559`), but the
  `wan5b` LoRA line is added by E2 (`:175`), so that fetch cannot hold it, and a `wan5b` bench before a second fetch fails at its
  cold run. Smallest fix, applied in this document without a parent change: S3's acceptance step 0 runs `bin/r9700 comfy fetch
  wan5b` after E2 is merged (only the LoRA downloads). Settled 2026-11-08: the parent's E2 *Depends on* now says so.
- **N5 — the flags cannot be lines of `bench.txt`.** The parent says a measured run with a load or a recompile "is flagged in
  `bench.txt`" (`:262–263`), and S1's grammar (this document, VC9) refuses any line of a bench file that is not a bench line.
  Smallest fix, built by the S2 spec: the flags are `flags.txt` beside `bench.txt` and `FLAGS_RUN_<n>=` words of `record.env`;
  `bench.txt` holds the block only. Not a plan change: the contract — every measured run's load and recompile are flagged and a
  reader sees whether a time includes a transfer or a compile — holds; where the flag is written is the record's layout.
- **N6 — `tunableop`'s "holds the workload's shapes".** The evidence row (`:304`) names the workload's shapes, which are not known
  before the card. The S2 spec reads the check as "non-empty, with `Validator` lines and at least one result row" and keeps the
  file in the record; S3's acceptance item 4 records the real rows. Pinning the shapes afterwards is a stricter check that
  satisfies the row as written: not a plan change, and open only for the list of shapes.
- **N7 — the `miopen` row needs a MIOpen log level.** Its evidence is "MIOpen's find lines in the cold run" (`:305`), and MIOpen
  prints no find line unless `MIOPEN_LOG_LEVEL` is set (ComfyUI prints none of its own; checked in `comfy/model_management.py`
  v0.44.0, 2026-11-08). Smallest fix, built by the S2 spec: `MIOPEN_LOG_LEVEL=5` in the `miopen` row of `comfyui/arms.conf`, the
  N3 precedent (a word that makes the parent's own evidence sentence true is not a change). Open for the value only: the acceptance's
  by-hand run says whether level 5 prints the find lines or 6 is needed, and the row is corrected (a new experiment, not a plan change).
- **N8 — the inert arm in the verdict's output.** The parent says an arm whose inertness evidence is present "is reported as inert on
  <workload>, with the evidence, never as 'no gain'" (`:279`). The S2 record carries it (`record.env` `INERT=yes`, `INERT_EVIDENCE=`,
  `evidence.txt`, the worker's stdout line); S3's `comfy_bench_verdict` as specified above prints only S1's verdict lines. Smallest
  fix, for S3's coder (Opus's section; recorded here, not applied): one `note: <arm> inert on <workflow> (<evidence>)` line per arm
  whose round-1 `record.env` says `INERT=yes`, printed before the `invoking:` line. Not a plan change: the parent requires it and S3's
  text omitted it.

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
  `fp8wmm`; the argv never activation evidence alone (`:158`, `:178`, `:273–281`, `:299–306`).
- **OP7 — the test dependency:** exact pins of `aiohttp`, `numpy` and `Pillow` in `tests/requirements.txt` (`:430–434`).
- **OP8 — `--tmpfs` and the read-only volume:** built as written, `--tmpfs /data:exec,size=8g` (a plain one is `noexec`),
  observed 2026-11-08; a fallback is the owner's (`:238–248`).
