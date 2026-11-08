# PLAN — E2 stories: `comfy bench` under the supervisor, and the verdict over its records

> Status: **plan only, nothing implemented yet, 2026-11-08.** Scope: the three stories of epic E2 of
> [PLAN_comfyui_r9700.md](PLAN_comfyui_r9700.md), section
> [E2 — `comfy bench` under the supervisor, and the verdict over its records](PLAN_comfyui_r9700.md#e2--comfy-bench-under-the-supervisor-and-the-verdict-over-its-records):
> the comfy mode of the ship test, the arm-round and its measurement contract, the verb `comfy bench` with the verdict over its folder,
> the documents and the first bench run on the R9700. Cornerstone: E2.S2 (`model: fable`), recorded in the parent's ledger line.

This document splits E2 into stories. It adds no scope to E2 and removes none. Where the parent plan is wrong or silent for E2, the
point is listed under [Open points for the plan owner](#open-points-for-the-plan-owner) with the smallest fix; a story that uses
such a fix says so at the place where it uses it. The parent plan keeps the change ledger; this document has none of its own
(plan-change-control: a stories document keeps no ledger).

## Stories at a glance

| Story | Title | Spec by | Code by | Depends on | Cornerstone |
|---|---|---|---|---|---|
| E2.S1 | The comfy mode of the ship test: `lib/verdict.py comfy` and `comfy-check-block` | Opus (this document) | Sonnet | nothing in E2 | no |
| E2.S2 | The arm-round and its measurement contract: `comfyui/bench.py`, `comfyui/arms.conf`, the worker `lib/comfy_bench.sh`, the record and its identity | **Fable** — `model: fable` | Sonnet | E2.S1 (the line grammar and the block check) | **yes** — the parent's area *the measurement contract* |
| E2.S3 | The verb `comfy bench` under the supervisor, `verdict` over a bench folder, the documents, the first bench run on the R9700 | Opus (this document) | Sonnet | E2.S2 (the seam below); E1's acceptance for the run on the card | no |

Order: S1, then S2, then S3. Fable may write the S2 spec at once: it needs only S1's line grammar (this document) and E1's merged
code. S2 is coded after S1 is merged (its validation calls S1's block check). S3 is coded after S2 is merged (it calls the seam
S2 provides). Every story is reviewed by Opus and fixed by Sonnet (subagent-models, per-story pipeline).

**The cut.** The parent's cornerstone area is the measurement contract: what one arm-round is (the isolated container, the
cleared cache, the cold run, the three same-seed measured runs, the `vram_free` wait), what fails it (`execution_error`, an
invalid output, missing arm evidence) and what is recorded. Most of that contract runs inside the container, in `bench.py`
(the run sequence, the seeds, the fast failure, the output check), and the rest in the worker (the container, the cache, the
evidence, the validation, the record, the identity). A cut between `bench.py` and the worker would give one contract two
authors, so S2 holds both, with `arms.conf` (the evidence lives there) and the fingerprint (what is recorded as the identity).
S1 is the verdict widening, which the parent says is not a cornerstone. S3 is the wiring that every other GPU verb already has
(the grammar, `supervise`, the resume count, the dry run), the verdict over a bench folder, the documents and the run on the card.

## Coverage — every E2 item is in exactly one story

The parent's E2 *Scope* (`PLAN_comfyui_r9700.md:369–374`), *Done when* (`:378–384`), the measurement contract (`:160–187`), the
records and growth (`:251–273`), the tests (`:283–288`) and the documents (`:291–296`), item by item. Where a later story extends a
file an earlier one creates, the row says which part each writes. Nothing below is in two stories.

| E2 item (parent plan) | Story | The other stories' part |
|---|---|---|
| `lib/verdict.py` widened with a second mode (a metric list, a direction), the vLLM mode and its tests unchanged | S1 | S2's validation calls its block check; S3's verdict calls its mode |
| The comfy mode passes an arm below the base's spread, fails one above it, decides nothing for an incomplete arm, prints exact decimals (`:382–383`) | S1 | — |
| `comfyui/bench.py`: the three workflows with every input pinned, the queue, the per-node times over the websocket, the verdict-grammar lines, a JSON per run (`:104`) | S2 | — |
| `bench.py` against local fixtures: an HTTP and websocket stub of ComfyUI's `/prompt`, `/history`, `/ws` (`:286–288`); `sampler_s`, `vae_s`, `total_s` per measured run and nothing for the cold run (`:381`) | S2 | — |
| `comfyui/arms.conf`: `base` and the five arms, each one change from `base`, each with the evidence it names (`:191–200`) | S2 | — |
| The measurement contract: isolation, the round (one cold run, three measured runs with the same seeds for every arm), offload made visible, failure is fast, the output is checked, the card is free at the start, the arm took effect, the order is balanced (`:160–187`) | S2 | — |
| The worker as ONE step: one arm-round after the other, every arm-round recorded only when complete (`:154`, `:366–367`) | S2 (the worker) | S3 (`supervise` around one `step_run`) |
| The part sweep (`:272–273`) | S2 | — |
| The fingerprint (`:253–254`) | S2 (its components, build, compare) | S3 calls it before admission |
| The drift numbers in the record, never gating (`:236–249`) | S2 | — |
| The refusal while `COMFY_CONTAINER` is listed (`:154`, `:371`) | S3 (through `supervise`'s check; open point OP2) | — |
| `bin/r9700 verdict` gives the ship test over a bench folder (`:367`) | S3 | uses S1's mode |
| The bench cases of the Tests section: refused beside ComfyUI, the dry run, one arm-round end to end, the verdict over stubbed rounds | S3 | the worker cases (a part swept, missing evidence rejected, a constant output rejected, an even round reversed, the cache cleared before every arm-round, one stubbed arm-round recorded) are S2's |
| The stub learns a scripted ComfyUI bench answer (`:93`) | S2 | S3 uses it |
| The growth rows of the results folder and the bench cache (`:251–273`) | S2 (the sizes and the sweeps, in this document's growth table) | S3 writes them into `research/module_comfyui.md` |
| The bench parts of the documents: `research/module_comfyui.md`, `research/architecture.md`, `README.md` (`:291–296`) | S3 | — |
| `research/module_tests.md` | each story its own rows | — |
| The cache volume's projection, "measured in E2 and the projection corrected in the record" (`:261`) | S3 (the acceptance) | S2 records the bench cache's size before every clear |
| The acceptance: `comfy bench zimage base fp16acc --rounds 1` on the card, recorded with its `vram_free`, its cold-run time and its outputs (`:374`, `:384`) | S3 | run by the operator's session after S2 and S3 are merged and after E1's acceptance |
| The seam check and the personal-path check over the new files; CI green | every story | — |

Out of E2 (E3; not built here): the `wan5b` feasibility run, the two series and their verdicts, the owner's look at the outputs,
the TTS question, `research/ACCEPTANCE_comfy_<date>.md`, `POST_DEPLOY.md`, the promotion of the plan. Also out (in no epic of the
plan): `comfy bench` as a step of `bin/r9700 run` (`lib/run_plan.sh` keeps its list of steps), and any change of `comfy start`,
`stop`, `status`, `build` or `fetch`.

## Facts every story uses (read 2026-11-08, at `6be7a67`)

**What E1 left (merged as PR #18).**

- `lib/comfy.sh` is **747 lines** (the house limit is 800, coding-style). It holds the modes `start`, `stop`, `status`, `build`,
  `fetch`; `comfy_modes` (`:44`) derives the legal modes from the functions `comfy_mode_<mode>` with `declare -F`, so a mode
  defined in another sourced file is a mode too; `comfy_locked` (`:50`), `comfy_volume_ensure <name> <listing> [<mode>]`
  (`:76`, list first, create only a missing volume), `comfy_assets` (`:435`, the three placed files), `comfy_win_dir` (`:442`),
  `_COMFY_CONTAINER_DIR=/work/r9700/comfyui` (`:410`, the placed folder as a container sees it), the placement call
  `local _MOE_PLACED_BY=comfy; moe_place comfy_assets` (`:578–579`).
- `bin/r9700` sources its libraries in one list (`:43`), ending with `comfy`. `verb_comfy` (`:589–603`) dispatches to
  `comfy_mode_<mode>`. `verb_verdict` (`:172–180`) runs `restore_first` under the lock when a marker exists, then
  `series_verdict "$@"` — it knows one kind of results folder.
- `supervise <verb> <prepare> <body>` (`lib/run_guarded.sh:503`): `lock_take` (`:508`), `restore_first` (`:509`), the prepare
  (`:510`), E1's owner check `_rg_card_free` (`:511`: the container list, then `comfy_owner_check`; exit 2 with the one owner
  line naming `bin/r9700 comfy stop`), `deadline_compute` (`:512`), `run_dir_new` (`:513`), the traps, the body, `cleanup_once`.
  `cleanup_once` (`:661`) stops every prefixed container (`container_stop_all`, `lib/restore.sh:159`, the prefix match at `:167`)
  and runs at most ONE registered hook (`cleanup_hook_set`, `:619`).
- `step_run <label> -- <command...>` (`lib/step.sh:238`) admits the worker (`_step_admit`, `:111`: the disk gate, the list, E1's
  `comfy_owner_check` at `:117`, the stop cap, the marker, the stop of the operator's server, the worker in its own session) and
  settles its outcome (`_step_settle`, `:199`): worker exit 0 done; 3 not quiet (wait, no try counted); 4 nothing more fits (the
  deadline); an outcome `KIND=refused` is a refusal (exit 2, no retry); anything else is a failed try, retried up to
  `MAX_FAILED_TRIES`.
- `bin/r9700 step [--model <m>] <label> -- <command...>` (`:195–224`) runs ANY command as one guarded step. S2's worker can be
  tested through it before S3's verb exists.
- `config_load_machine` (`lib/config.sh:484`) loads the machine file alone. No verb under `supervise` uses it yet: every
  `supervise` user loads a model file (`prepare_run`, `bin/r9700:184`). Whether a function under `supervise` reads a model key is
  not known; S3's first end-to-end test shows it.

**The patterns E2 reuses.**

- A two-faced library: SOURCED it defines the supervisor's half, RUN as `bash lib/<x>.sh <args>` it is the worker
  (`lib/series.sh:2–5`, `:534–541`; `lib/kernels.sh:3–5`, `:352–358`). The worker sets no trap, takes no lock, never stops the
  operator's server.
- The arm-round record of a series (`lib/series.sh:17–21`): `rounds/<arm>-<round>.part-<run id>/` while it is built, ONE rename
  to `rounds/<arm>-<round>/` after the validation, `rejected/<tag>-<UTC stamp>/` with a `reason` file (`_series_reject`, `:256`),
  the sweep of a part a killed worker left (`series_sweep_parts`, `:267`), `record.env` (`:401`), the identity re-checked at
  the start of every arm-round (`_series_recheck`, `:413`), the gate before every arm-round (the disk gate, the quiet check, the
  time fit, `_series_gate`, `:287`). The series runs the arms in ONE order every round (`series_main`, `:474–480`).
- The fingerprint (`lib/fingerprint.py`): `compare`, `compare --merge` (a new arm or more rounds is an extension) and `show`
  are generic over a version-1 document `{"version", "sha256", "components"}` (`:188–298`); `show` of a leaf that is not there
  exits 2 (`:283`). `build` is vLLM-only (`MODEL_KEYS`, `:39–43`, `build_components`, `:129`). `series_fingerprint`
  (`lib/series.sh:148`) builds before admission and refuses a fingerprint over records whose identity is lost (`:152–155`).
- The cache clear of the MoE units (`lib/moe.sh:69–90`): a prefixed throwaway container with only the cache volume, which
  prints the sizes (`du -sh`) and removes; a clear that fails before a unit refuses the unit (`KIND=refused`), the clear in the
  cleanup is best effort.
- The verb half of a measurement (`lib/kernels_verb.sh:164–188`): the placement, the dry run, the same-experiment check and the
  recorded count before admission, then ONE `step_run`. The series grammar (`bin/r9700:228–265`): `--rounds` 1..20, `--out`
  matched by `_SERIES_OUT_RE` (`:229`), an arm name `_RE_ARM` (`lib/config.sh:102`), an arm given twice refused.
- The adapter calls (`lib/adapter.sh`): `wslc_run <name> <args...>` is always `run -d --rm --name` (`:291–298`); `wslc_exec`
  (`:300`), `wslc_run_once` (`:320`), `wslc_logs` (`:369`); `comfy_probe` (`:521`) runs `_COMFY_PROBE_PY` (`:87–107`), which
  reads `devices[0].name` of `/system_stats` and prints `device <name>` and `ready`. `container_name <label>` (`lib/serve.sh:104`)
  prefixes a label `^[a-z0-9][a-z0-9-]{0,39}$` (`:102`); `container_host_path` (`:93`) maps `/work/...` to `$WORK_DIR/...`.
- The arm grammar (`lib/config.sh:545–571`): four fields `name | serve arguments | environment | mounts`, exactly three `|`;
  `arms_load` (`:573`), `arm_args`, `arm_env`, `arm_mounts` (`:622–624`), `arms_check` (`:626`, mounts under `PATCH_DIR`). There
  is no field for evidence.

**The image the bench runs** (`comfyui/`).

- `entrypoint.sh` makes the folders of `/data`, `/models`, `/cache` (`:10–14`), makes a `--system-site-packages` venv on `/data`
  at the first start (`:28–31`), and starts `main.py --listen 0.0.0.0 --port 8188 --base-directory /data --models-directory
  /models --enable-manager "$@"` (`:46–51`): ComfyUI's arguments after the image are appended. ComfyUI's outputs go to
  `/data/output` unless an argument says otherwise.
- `Containerfile` installs `ffmpeg` (`:17`, so `ffprobe` is there); `MIOPEN_USER_DB_PATH` and `MIOPEN_CUSTOM_CACHE_DIR` are
  `/cache/miopen`, `TRITON_CACHE_DIR` is `/cache/triton` (`:48–50`); it does NOT set `PYTORCH_HIP_ALLOC_CONF` (trap 1, `:41–43`).
  ComfyUI's own requirements are installed with the base's ROCm packages as constraints (`:27–29`).
- `comfyui/models.conf` pins the files of `zimage` (`:16–18`) and `wan5b` (`:19–21`) with their sha256.
- The volumes the bench must NOT touch: `COMFY_DATA_VOLUME` and `COMFY_CACHE_VOLUME` (the operator's). The models volume
  `COMFY_MODELS_VOLUME` is read by the bench.

**What the hand-made bench prototype shows** (`bench.py` of the operator's hand-made folder, outside every repository; the main
session gives its location; nothing of its paths or names goes into a tracked file). It ran on the R9700 on 2026-11-07, so its
shape is evidence of what works there:

- It runs inside the container through `wslc exec` with the image's `python` and `aiohttp` (`:4`, `:17`).
- The three workflows as ComfyUI API graphs with node ids `sampler` (a `KSampler`) and `vae` (`:23–77`): `zimage` is
  `UNETLoader` + `CLIPLoader lumina2` + `VAELoader`, `ModelSamplingAuraFlow` shift 3.0, 1024×1024, 8 steps, `res_multistep`,
  `simple`, cfg 1.0 (`:37–52`); `wan5b` is `UNETLoader` + `CLIPLoader wan` + `VAELoader`, `ModelSamplingSD3` shift 8.0,
  `Wan22ImageToVideoLatent` 1280×704, length 121, 20 steps, `uni_pc`, `simple`, cfg 5.0, and a `VAEDecodeTiled` (tile 512,
  overlap 64, temporal 32, temporal overlap 8) with the comment that the untiled decode of 121 frames stalled (`:55–77`).
- `compile` inserts `TorchCompileModel` (backend `inductor`) between the loader and the shift node (`:83–86`).
- One run (`:89–121`): open the websocket `/ws?clientId=<uuid>`, `POST /prompt` with the graph and the client id, time from the
  POST until the `executing` message with `node: null`; a node's time is from its `executing` message to the next one; an
  `execution_error` message ends the run at once; after the run `GET /system_stats` gives `devices[0]` (its `vram_free`).
- Seeds are `4242 + i` for run `i` (`:143`); run 1 is the cold run. It reads ComfyUI's own argv from `/system_stats`
  `system.argv` (`:140–141`) and the environment words `PYTORCH_*`, `MIOPEN_*`, `COMFYUI_*`, `TORCH_*`, `HIP*`, `HSA_*`,
  `TRITON_*` (`:150–151`).
- It does NOT: check the output, read `/history`, wait for free card memory, keep the server log per run, or know arms.

**Observed on the R9700 while rendering, 2026-11-07/08** (`research/module_comfyui.md:102–105`, hand runs, one run or one sweep each):
an UNTILED decode of the 121-frame `wan5b` clip stalled for more than 10 minutes; `VAEDecodeTiled` 512 / 64 / 32 / 8 decoded it in
about 100 s, 512 / 32 / 64 / 4 in about 70 s (open point OP4). At 20 `uni_pc` steps the `wan5b` output carries a fine diagonal
hatching that 50 steps remove (open point OP5). E1's own acceptance on the card has **not run yet** (`research/module_comfyui.md:109`).

**The tests and the checks.**

- `tests/run.mjs` runs `test_*.py` with the repository's `.venv` python and pytest (`:319–329`); `tests/requirements.txt` holds
  `pytest` and its four dependencies only, so `aiohttp`, `numpy` and `Pillow` are NOT in the test environment (on the host
  `python3 -c 'import aiohttp'` fails today). Open point OP7.
- `tests/test_comfy.sh` OC1 derives the verbs under `supervise` from the code lines (`supervised_verbs`, `:26–28`) and holds one
  legal command line per verb (`OC1_ROWS`, `:31`; `oc1_run`, `:34–43`): a new `supervise comfy …` call without a row fails it.
- `tests/test_comfy_start.sh:40–46` (CS1) compares the mode line with `comfy_modes` in the test shell, and
  `tests/lib/comfycase.sh:21` sources `lib/comfy.sh` only: a mode defined in a new file is missing from the test's list unless
  `comfycase.sh` sources that file too.
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

**Not verified anywhere in this repository** (each is the parent's assumption or ComfyUI's or PyTorch's documentation, not an
observation here; S2's spec decides how each is checked, and S3's acceptance observes each on the card):

1. `wslc run --tmpfs <path>` and a NAMED volume mounted read-only (`-v <volume>:/models:ro`). Today only bind mounts of Windows
   paths take `:ro` (`lib/serve.sh:79`, `lib/comfy.sh:737`); `--tmpfs` is used nowhere. Open point OP8.
2. Whether `wslc run -v <volume>:<path>` makes a missing named volume, or fails (E1 always lists, then creates: `lib/comfy.sh:76`).
3. Whether a process started by `wslc exec` sees the environment the container was started with (`-e`); the `compile` arm reads
   `COMFY_BENCH_COMPILE` in `bench.py`, which runs through `exec`.
4. `/system_stats` `devices[0].vram_total` (the prototype reads only `vram_free`; E1's probe only `name`).
5. ComfyUI's websocket messages other than `executing` and `execution_error` (`execution_start`, `execution_cached`,
   `execution_success`), and the `/history/<prompt id>` entry's `outputs` and `status` fields.
6. The log lines the arms' evidence names: `Enabled fp16 accumulation`, `cudnn.enabled = False`, `Using pytorch attention`; the
   environment word `COMFYUI_ENABLE_MIOPEN`; ComfyUI's model load and unload lines.
7. When PyTorch's TunableOp writes `PYTORCH_TUNABLEOP_FILENAME`: by PyTorch's documentation the results are kept in memory and
   written when the process ends, so the file can be empty while the container runs, and a stop that kills the process may
   never write it.
8. That `aiohttp`, `numpy` and `Pillow` are in the image (ComfyUI's server is built on `aiohttp`; the prototype imported it in
   the image; `numpy` and `Pillow` are taken from ComfyUI's requirements, not read here).

## The seam between S2 and S3

S3 is written in full against this seam; S2 provides it. Fable may rename a name or add an argument: the S2 spec then says so in
one line, and S3's coder follows the spec. What may not change is what each one is for.

| Name | Provided by S2 (`lib/comfy_bench.sh`, sourced) | Used by S3 |
|---|---|---|
| `bash lib/comfy_bench.sh <outdir> <workflow> <rounds> <arm>...` | the worker: the arm-rounds of the invocation not yet recorded, one after the other; exit 0 done, 1 an arm-round was rejected or the disk gate stopped, 3 not quiet, 4 nothing more fits before the deadline, a refusal as `KIND=refused` (the series worker's codes, `lib/series.sh:23–24`) | `step_run comfy-bench -- bash … ` |
| `comfy_bench_workflows` | the legal workflow names, one per line, sorted, derived from `bench.py` (never typed twice); runs on the host with the standard library only | the grammar check before the lock |
| `comfy_bench_metrics` | the metrics of a block, one line, space-separated, the deciding one first (`total_s sampler_s vae_s`), from the same place `bench.py` prints them | the verdict's `--metrics` and `--decide` |
| `comfy_bench_arms_conf` | `${R9700_COMFY_ARMS_CONF:-<repository>/comfyui/arms.conf}` (a test knob, the shape of `series_arms_conf`) | — (S2's own; named so S3's tests can point it at a copy) |
| `comfy_bench_check <workflow> <rounds> <arm>...` | after the machine config: the arm table loads, every arm is in it, every container label the worker will use fits; 2 and one line per problem | the prepare |
| `comfy_bench_assets` | `<placed name> <repository source> <required\|optional>` per line: at least `comfyui/bench.py` | `moe_place comfy_bench_assets` before admission |
| `comfy_bench_fingerprint <outdir> <workflow> <rounds> <real\|dry> <arm>...` | build `<outdir>/fingerprint.json`, or compare and merge an extension (a new arm, more rounds); a difference: `fingerprint differs: …` lines on stderr and 2; `dry` writes nothing | before admission |
| `comfy_bench_left` / `comfy_bench_recorded <outdir> <rounds> <arm>...` | the counts of arm-rounds with no final record / with one | the resume count before admission |
| `comfy_bench_dry_run <outdir> <workflow> <rounds> <arm>...` | prints `dry-run: <command>` lines of the first arm-round, starts nothing | `--dry-run` |
| The folder | `<outdir>/fingerprint.json` with the leaves `kind` (= `comfy`), `workflow`, `base`, `rounds`, `arms`; `<outdir>/rounds/<arm>-<round>/bench.txt` holding exactly one complete block of S1's grammar | the verdict and its dispatch |

## E2.S1 — The comfy mode of the ship test: `lib/verdict.py comfy` and `comfy-check-block`

**Cornerstone:** no. **Depends on:** nothing in E2. **Spec:** this section (Opus). **Code:** one Sonnet coder.

### Goal

`lib/verdict.py` gets a second mode that applies the RULE of the first (`lib/verdict.py:8–11`): an arm's median against the
base's spread over ALL the base's values (rounds × runs), exact decimals, and an arm with a missing arm-round is never PASS or
FAIL. The groups are one workflow's metrics, one metric decides, and the direction is a parameter (seconds: lower is better). A
block check for the same grammar lets S2's worker validate one arm-round before its record becomes final. The vLLM mode, its
grammar, its output and its 47 tests do not change.

### The line grammar (S2's `bench.py` prints it; this story owns it)

```text
<arm>-<round> <workflow> r=<n> <metric>: <value>
fp16acc-2 zimage r=3 total_s: 12.345
```

`<arm>` `[a-z0-9]+`, `<round>` `[1-9][0-9]*`, `<workflow>` `[a-z0-9]+`, `<n>` one of the three measured runs `1 2 3`, `<metric>`
`[a-z][a-z0-9_]*`, `<value>` a non-negative decimal `[0-9]+(\.[0-9]+)?` (seconds). A COMPLETE block of a tag is exactly one line for
every pair (run 1..3, metric of `--metrics`): 9 lines for the three metrics. A block starts at its `r=1 <first metric>` line (the
vLLM mode's `split_blocks` rule, `:117–125`, with another start key). The three runs are one constant,
`COMFY_RUNS = (1, 2, 3)`, beside `REPEATS` (`:35`), with a comment naming the parent's contract.

### The rule

For the deciding metric `d` (`--decide`) and each judged arm: the arm's values are `d` of every run of every round
`1..--rounds`; the base's the same. `stat_of` (`:163`) gives the median, the base median, delta = median − base median and the
spread = max − min of the base's values; `word_of` (`:168`) gives one of `higher`, `within, not lower`, `within, lower`, `lower`.
Then, with `--direction lower`:

| word | verdict | reason printed |
|---|---|---|
| `lower` | PASS | — |
| `higher` | FAIL | `<d> higher than the base by more than its spread` |
| `within, lower`, `within, not lower` | NOT DECIDED | `inside the base spread` (open point OP3) |

`--direction higher` mirrors it (`higher` passes, `lower` fails with `<d> lower than the base by more than its spread`). A missing
arm-round of the arm or of the base is INCOMPLETE with the vLLM mode's reasons (`missing_tags`, `:246`; `evaluate`, `:255–266`).
The other metrics of `--metrics` are computed the same way and printed as information; they never decide.

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
- VC3 *An arm inside the spread is NOT DECIDED, never FAIL* (OP3). `total_s` all `12.050` (`-> within, not lower`) and all
  `12.000` (`-> within, lower`): each `verdict <arm>: NOT DECIDED (inside the base spread)`; exit 0.
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

Read first: this section and *Facts every story uses*; `lib/verdict.py` whole; `tests/test_verdict.py:1–80`
(the helpers: `run` at `:22`, `write_bench` at `:63`); `tests/conftest.py`. Do not change any line of the `ship` or `check-block` paths' behaviour.

1. **Widen, do not copy** (reuse-first). `read_lines(path, parser=parse_line)`: the parser becomes an argument with today's
   default. `split_blocks(lines, start_key=START_KEY)`: the same. `stat_of`, `word_of`, `pick_blocks`, `missing_tags`,
   `write_json`, `InputError`, `arm_name` are used as they are.
2. **The comfy grammar.** `COMFY_LINE` (the regular expression of the grammar above, anchored, `\s+` after the colon),
   `COMFY_RUNS = (1, 2, 3)`. `comfy_parser(workflow)` returns a function `(text, file, number) -> Line` with `tag =
   <arm>-<round>`, `key = "r=<n> <metric>"`: no match → `InputError(f"{file}:{number}: not a bench line")`; another workflow →
   the VC9 line. `comfy_keys(metrics)` → `[f"r={r} {m}" for r in COMFY_RUNS for m in metrics]`. `metrics_of(text)` → the
   list, refusing an empty one, a word that is not `[a-z][a-z0-9_]*` and a repeated word, each with one `InputError` line
   naming `--metrics`. A type function `workflow_name` beside `arm_name` (`[a-z0-9]+`, its own message).
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

## E2.S2 — The arm-round and its measurement contract: `comfyui/bench.py`, `comfyui/arms.conf`, the worker `lib/comfy_bench.sh`, the record and its identity (cornerstone, `model: fable`)

**Cornerstone:** **yes** — the parent's E2 area *the measurement contract*. **Depends on:** E2.S1 (the line grammar and
`comfy-check-block`). **Spec:** written by Fable (below). **Code:** one Sonnet coder; review Opus.

### Goal

One arm-round of a ComfyUI arm on the R9700 is measured the same way every time and is recorded only when it is a measurement:
an isolated prefixed container started with the arm's arguments and environment, on a card whose memory is free, with a bench
cache cleared before it; one untimed cold run, then three measured runs whose seeds are the same for every arm; every run fails
fast on an `execution_error`, an output that is not the workflow's, or a run that exceeds its ceiling; the arm-round is rejected
when the evidence that its arm took effect is missing; the model loads inside a measured run are visible; and the record holds
the timings in S1's grammar, the per-run JSON, the server log, the outputs, the evidence, the drift numbers against the base, and
an identity (`fingerprint.json`) that refuses a resume of another experiment. ComfyUI is a queue with an execution cache and a
dynamic model offload: a run can look like a measurement and not be one, and every claim of E3 rests on this record.

### Scope

In (the parent's *The bench's measurement contract*, `:160–187`; *The tuning series* arms, `:191–204`; *Quality* layers 1 and 2,
`:236–246`; *Records and growth*, `:251–273`; the worker half of the verb row `bench`, `:154`):

- `comfyui/bench.py` (new, run inside the container through `wslc_exec`; its pure parts run on the host): the workflows
  `sd15`, `zimage`, `wan5b` with every input pinned (seed, steps, size, sampler, scheduler, cfg, shift, `wan5b`'s length and its
  VAE decode — open points OP4 and OP5 for two of those values); the run sequence of an arm-round (the cold run, the three measured
  runs, the seeds); `total_s` from the queue to the history entry, the per-node times from the websocket; S1's lines for the
  measured runs only; one JSON per run; the fast failures; the output check (dimensions, frame count by `ffprobe -count_frames`,
  pixels not constant); the drift computation (mean absolute pixel difference and PSNR, per seed); the commands
  `workflows` and `metrics` of the seam, standard library only.
- `comfyui/arms.conf` (new): `base`, `fp16acc`, `fp8mm`, `tunableop`, `miopen`, `compile` as the parent's table, each one change
  from `base`, each with the evidence that proves it took effect (open point OP6 for where the evidence is written and for the
  two arms the parent names none for).
- `lib/comfy_bench.sh` (new, two faces: sourced for the seam above, run as the worker): the gate before every arm-round, the
  identity re-check, the bench cache clear, the bench container (isolation; `--tmpfs`, open point OP8), the readiness and the
  free-card wait, `bench.py` through `exec`, the server log per measured run and the flag of a measured run with a model load,
  the evidence check, the validation (S1's `comfy-check-block` among it), ONE rename into `rounds/<arm>-<round>/`, `rejected/`
  with a `reason`, the part sweep, the balanced order (odd rounds as given, even rounds reversed), the drift pairing (the base's
  round-1 output of the same seed; base rounds 2 and 3 against base round 1; `unavailable (<why>)` when the reference is
  missing or rejected), the deadline and the quiet check as a series has them.
- The fingerprint: its components (`kind` = `comfy`, the image id, `COMFY_REF`, the workflow and its constants, the arms, the hash
  of `bench.py` and of the worker's modules, the PINNED sha256 of every model file the workflow loads — from `models.conf`, never
  names and sizes —, `base`, `rounds`), built and compared before admission, re-checked at every arm-round; `lib/fingerprint.py`
  widened (its `compare`, `show` and `--merge` are generic), not copied.
- The stub (`tests/stubs/wslc`, `stub_common.sh`): the bench container, the `exec` of `bench.py` with scripted answers (good
  lines and JSON, an `execution_error`, a constant output, a slow run), the clear container with its size line, the server log
  with the arms' evidence lines.
- The fixture server `tests/fixtures/comfy/comfy_server.py`: ComfyUI's `/prompt`, `/history/<id>`, `/ws`, `/system_stats`, with
  scripted messages, timings, errors and output files.
- The placed `bench.py` under `$WORK_DIR/r9700/comfyui/` (`moe_place comfy_bench_assets`).
- The rows of its own test files in `research/module_tests.md`, its knobs and stub files in *Test knobs*, and its lines in *What
  it does not prove* (the eight unverified facts above that the stub stands in for).

Out: the verb's grammar, `supervise`, the dry-run printing call site, the verdict over a folder, the documents other than
`module_tests.md`, the acceptance (S3); the verdict rule (S1); the `wan5b` feasibility run and the series (E3).

### Files

| File | Change |
|---|---|
| `comfyui/bench.py` | new |
| `comfyui/arms.conf` | new |
| `lib/comfy_bench.sh` | new (open point OP1: not `lib/comfy.sh`, which is 747 lines) |
| `lib/fingerprint.py` | a build for the comfy identity beside `build`; `compare`, `show`, `--merge` unchanged |
| `lib/config.sh` | only if the evidence widens the arm grammar (OP6); the series' table and `arms_load`'s callers unchanged |
| `lib/adapter.sh` | only what the spec needs (a probe that also reads `vram_free` and `vram_total` is the likely one; the seam stays here) |
| `tests/stubs/wslc`, `tests/stubs/stub_common.sh` | the bench answers |
| `tests/fixtures/comfy/comfy_server.py` | new |
| `tests/test_comfy_bench_py.py` | new: the `BP` scenarios |
| `tests/test_comfy_bench.sh` | new: the `BW`, `BA`, `BF` scenarios |
| `tests/test_stubs.sh` | the `SC` scenarios |
| `tests/test_fingerprint.py` | the `BF` cases of the Python half |
| `tests/requirements.txt` | only with open point OP7's first fix |
| `research/module_tests.md` | the rows, knobs and lines of *Scope* |

### Test scenario IDs (one line each; the scenarios themselves are in Fable's spec)

**`bench.py` against the fixture server (`tests/test_comfy_bench_py.py`)**

- BP1 `bench.py workflows` and `bench.py metrics` run on the host with the standard library only and print the three workflows and the three metrics.
- BP2 Each workflow's graph has every input pinned, and the constants are the ones the fingerprint records (one table, read by both).
- BP3 One cold run, untimed, then three measured runs; the measured seeds are the same for every arm, differ from each other, and differ from the cold run's seed.
- BP4 Per measured run exactly the three lines of S1's grammar and none for the cold run; the block passes `comfy-check-block`.
- BP5 `total_s` runs from the queue to the history entry; the node times come from the websocket; a JSON per run (the cold run's marked cold) holds them with the seed and the cached nodes.
- BP6 A measured run in which the sampler did not execute (its output taken from ComfyUI's cache) fails: a time that measured nothing is never printed.
- BP7 An `execution_error` on the websocket fails the run at once, one line with the node and the message; the same error found only in `/history` fails it too.
- BP8 A prompt that `/prompt` refuses fails before any timing; a run that exceeds its ceiling fails at the ceiling.
- BP9 The output check: an image of the workflow's width × height passes; a wrong size fails; a constant image fails.
- BP10 The video check: a video with the workflow's `length` frames passes; a truncated video fixture fails (`ffprobe -count_frames`).
- BP11 The drift: per seed the mean absolute pixel difference and the PSNR; identical outputs give 0 and the spec's word for an infinite PSNR; a missing reference gives `unavailable (<why>)`, never a number.
- BP12 The card readings: `vram_free` and `vram_total` before the cold run are in the cold run's JSON.

**The worker and the arm-round (`tests/test_comfy_bench.sh`, the stub world, the worker run through `bin/r9700 step`)**

- BW1 One arm-round is one prefixed container: an empty `/data`, the models volume read-only, the bench cache volume, the arm's arguments and environment, ComfyUI's default memory mode — never the operator's data or cache volume.
- BW2 The bench cache is cleared before every arm-round by a prefixed throwaway container, its size before the clear is recorded, and a clear that fails refuses the arm-round (`KIND=refused`).
- BW3 The bench cache volume is made when it is missing (list first, `comfy_volume_ensure`), and only then.
- BW4 The free-card wait: `vram_free` at least 90 % of the total before the cold run, bounded; the value is recorded; a card that does not free in time fails the arm-round with the readings.
- BW5 A bench container that does not become ready is stopped by name before the worker exits, and the attempt goes to `rejected/`.
- BW6 A complete arm-round becomes `rounds/<arm>-<round>/` by ONE rename after the validation, with `record.env`, `bench.txt`, the run JSONs, `server.log`, the outputs, the evidence and the drift.
- BW7 An `execution_error`, an invalid output, or a `bench.txt` that fails `comfy-check-block` rejects the arm-round to `rejected/<arm>-<round>-<stamp>/` with a `reason`; the worker exits 1.
- BW8 Missing evidence rejects the arm-round with an `EVIDENCE:` reason; present evidence is recorded beside the timings.
- BW9 An arm that is inert on the workload (`fp16acc` on bf16 weights) is recorded with ComfyUI's weight and compute dtype line and marked inert, not rejected.
- BW10 A model load or unload inside a measured run is kept per run and the run is flagged; a run without one is not.
- BW11 Odd rounds run the arms as given, even rounds reversed; a resumed invocation keeps that order for what is left.
- BW12 A part a killed worker left is moved to `rejected/` as `INTERRUPTED` at the next start.
- BW13 The identity is re-checked at the start of every arm-round; an edit of `arms.conf`, `bench.py` or the image between arm-rounds refuses (`KIND=refused`) before the next container.
- BW14 The gate before every arm-round: the disk gate stops (`KIND=disk_gate`), a PC that is not quiet is exit 3, an arm-round that no longer fits before the deadline is exit 4.
- BW15 The drift pairing: an arm's output against the base's round-1 output of the same seed; base rounds 2 and 3 against base round 1; a missing or rejected base round 1 gives `unavailable (<why>)`.
- BW16 The worker never stops or starts the operator's ComfyUI or vLLM, and every container it starts is prefixed (the cleanup can stop it).

**`comfyui/arms.conf` (`tests/test_comfy_bench.sh`)**

- BA1 The six rows load with the arm grammar, the names are the parent's, and each row differs from `base` in exactly one change.
- BA2 Every arm names its evidence (derived over the file: a row without evidence fails the test).
- BA3 No row sets `PYTORCH_HIP_ALLOC_CONF` (trap 1) or mounts a host path.

**The identity (`tests/test_comfy_bench.sh`, `tests/test_fingerprint.py`)**

- BF1 `fingerprint.json` is a version-1 document that `fingerprint.py show` and `compare` read, with `kind` = `comfy` and every component of *Scope*.
- BF2 A change of any component refuses the resume with `fingerprint differs: <leaf>: <old> -> <new>` before anything is stopped; a new arm or more rounds is an extension.
- BF3 No new fingerprint is built over `rounds/` or `rejected/` whose identity is lost.
- BF4 A `COMFY_IMAGE` that does not exist refuses (2) naming `bin/r9700 comfy build`.
- BF5 The model identity is the pinned sha256 of `models.conf` for exactly the files the workflow loads; a changed pin is a difference.

**The stub (`tests/test_stubs.sh`)**

- SC1 The stub answers the bench container's readiness and the `exec` of `bench.py` from scripted files (lines, JSON, outputs, an `execution_error`, a constant output, a slow run).
- SC2 The stub's clear container prints a size line and empties the stub's bench cache; its failure is scriptable.
- SC3 The stub's `logs` of a bench container holds the scripted evidence and model-load lines.

### Spec: written by Fable

> **This section is Fable's.** Fable writes, in this file, under this heading: the scenarios BP1–BP12, BW1–BW16, BA1–BA3,
> BF1–BF5 and SC1–SC3 in the detail of E2.S1's (each with its setup, its exact lines, its RED-first mark where it has one), the
> brief for the Sonnet coder (read first, steps, commands, what to report) and the *Done when* of this story. Fable may add a
> scenario, merge two or split one, and says so in one line. The cornerstone ledger line of the parent already names this story.

What the spec must settle (each item is a question the parent leaves open or a fact above that is not verified; Opus has decided
none of them):

1. **The open points it builds on.** OP4 (the `wan5b` decode), OP5 (the `wan5b` steps), OP6 (where the evidence is written; the
   evidence of `fp8mm` and `compile`), OP7 (how `bench.py`'s transport is tested), OP8 (`--tmpfs` and the read-only models
   volume). Until the owner answers, the spec builds the smallest fix of each and names the one constant or line that changes
   with the answer.
2. **The seeds.** The three measured seeds are the same for every arm; the cold run's seed must differ from them, because
   ComfyUI takes a node from its cache when its inputs are equal, and a measured run with the cold run's seed would time nothing
   (BP3, BP6). The spec names the seeds and where they are written once.
3. **Where the outputs go.** `/data` is empty and in memory; the outputs must reach the record, and the drift needs the base's
   round-1 outputs inside the container. The toolkit's existing way is an exchange folder under `$WORK_DIR/r9700/` mounted at
   `/work` and read on the host with `container_host_path` (`lib/kernels.sh` `kernels_exchange_dir`; `lib/series.sh:366–371`);
   ComfyUI takes an `--output-directory` argument. The spec names the folder, its sweep and its growth row.
4. **The server log per measured run.** The worker can read `wslc_logs` between runs (one `exec` of `bench.py` per run) or
   `bench.py` can read ComfyUI's own log; the spec picks the one the stub can prove and the acceptance can observe.
5. **The readiness and the free card.** E1's `ready_wait` with a probe argument (`lib/restore.sh:186`) and `comfy_probe`; the
   spec says whether the probe is widened to print `vram_free` and `vram_total` (fact 4) or `bench.py` waits.
6. **The evidence that can be read.** Fact 7 (TunableOp writes its file at process end), fact 6 (the log lines), fact 3 (the
   environment of an `exec`): for each arm, evidence that exists while or right after the container runs.
7. **An arm that does not start.** The series marks `unsupported/` after two failed starts (`lib/series.sh:326–350`); the parent
   is silent for ComfyUI. The spec says whether a bench container that does not become ready is a failed try only, or also an
   unsupported mark, and what the verdict then sees.
8. **Missing model files.** A file of the workflow that is not in the models volume fails every try after the operator's server
   was stopped. The spec says whether the supervisor's half checks, before admission, that the workflow's files are present (a
   throwaway container without the card, the shape of `_series_probe`, `lib/series.sh:99`), or why not.
9. **The time an arm-round may need** for the fit check before the deadline (the series uses `R9700_ARM_SECONDS`, default
   1500 s, `lib/series.sh:291`): per workflow, from the prototype's figures (the `wan5b` run took about 340 s at 20 steps,
   `research/module_comfyui.md:105`).
10. **The two placed-file faces.** `comfy_bench_assets` and whether `comfy_assets` (the build context) stays three files.

---

## E2.S3 — The verb `comfy bench` under the supervisor, `verdict` over a bench folder, the documents, the first bench run on the R9700

**Cornerstone:** no. **Depends on:** E2.S2 merged (the seam); E2.S1 merged (the verdict mode); for the run on the card, E1's
three acceptance runs (the built image, the `zimage` set fetched). **Spec:** this section (Opus). **Code:** one Sonnet coder; the
acceptance run by the operator's session.

### Goal

`bin/r9700 comfy bench <workflow> <arm>... [--rounds N] [--out <name>] [--dry-run]` runs S2's worker as ONE step under
`supervise`: one lock, the restore first, the operator's vLLM stopped once at the admission and restored once at the end, the
guards, the deadline, and E1's refusal while the operator's ComfyUI is listed. The identity is built or compared before anything
is stopped, and a resume runs only what is not recorded. `bin/r9700 verdict <folder>` gives the comfy ship test over a bench
folder and the vLLM one over a series folder, unchanged. The documents describe `bench`, and the first bench run on the R9700 is
recorded.

### Files

| File | Change |
|---|---|
| `lib/comfy_bench_verb.sh` | new (open point OP1): `comfy_bench_args`, `comfy_mode_bench`, `comfy_bench_prepare`, `comfy_bench_body`, `comfy_bench_verdict`, `verdict_is_comfy` |
| `bin/r9700` | the library list (`:43`) gains `comfy_bench comfy_bench_verb` after `comfy`; `verb_verdict` (`:172–180`) dispatches; the header's verb list (`:2–5`) names `bench`; the exit comment rows only where brief step 5 adds words |
| `tests/test_comfy_bench_verb.sh` | new: CV1–CV13, VD1–VD5 |
| `tests/test_comfy.sh` | OC1's row `comfy` (`:31`, `:34–43`) |
| `tests/lib/comfycase.sh` | sources `lib/comfy_bench.sh` and `lib/comfy_bench_verb.sh` after `lib/comfy.sh` (`:21`), so CS1's derived mode list holds `bench` |
| `tests/test_lifecycle.sh` | no edit: its exit-table test (`:432`) checks that brief step 5's words are the same in the three places |
| `research/module_comfyui.md`, `research/architecture.md`, `research/module_tests.md`, `README.md` | brief step 7 |

### Test scenarios

All in `tests/test_comfy_bench_verb.sh` (OC1 in `tests/test_comfy.sh`), through `tests/run.mjs`, in the stub world:
`bench_setup` is `comfy_setup` (`tests/lib/comfycase.sh`) with the operator's server running, the three volumes present, S2's
default stub answers for a good arm-round of any arm, and `R9700_COMFY_ARMS_CONF` unset (the real `comfyui/arms.conf`);
`bench <args>` is `r9700 comfy bench "$@"`; `bench_bg` / `bench_end` are `comfy_bg` / `comfy_end` for `bench`. The call log is
`$STUB/calls.log` (`stop_lines`, `log_count`, `argv_of`). "Nothing happened" means: no lock file was made, no `wslc` call was
logged. RED first as in E2.S1.

- CV1 *The grammar is refused before the lock, and the workflows are derived.* `bench` (no word): exit 2, `r9700: comfy: bench:
  usage: bench <workflow> <arm>... [--rounds <1..20>] [--out <name>] [--dry-run]`; `bench nosuch base`: exit 2, `r9700: comfy:
  bench: unknown workflow "nosuch"; legal: <comfy_bench_workflows, space-separated>` (the test reads the list from the function,
  and asserts it holds `zimage`); `bench zimage` (no arm): exit 2, `at least one arm is needed`; `bench zimage Base`: `"Base" is
  not an arm name (lower-case letters and digits only)`; `bench zimage base base`: `the arm "base" is given twice`; `--rounds 0`,
  `--rounds 21`, `--rounds x`: `--rounds "<v>" is not a whole number from 1 to 20`; `--out ../x`: the `--out` line; `--rounds`
  with no value: `--rounds needs a value`; `--frob`: `unknown option "--frob"; legal: --rounds <1..20>, --out <name>, --dry-run`.
  Each: exactly one stderr line, nothing happened. RED first (the mode does not exist: `unknown mode "bench"`).
- CV2 *The prepare refuses after the restore and before any stop, and needs no model file.* `bench zimage base nosuch`: exit 2,
  the arm line of `_arm_known` (`config: arm "nosuch" is not in …; legal: …`, `lib/config.sh:607–611`) through S2's
  `comfy_bench_check`; no `stop`, no run folder under `RESULTS_DIR/runs`, the lock free afterwards. With a recovery marker left
  (vLLM was running, down now): the restore ran first (one `pwsh.exe -Detach`), then the same refusal. Two model files in
  `models/` and no `--model`: CV5 passes (the machine config alone, `config_load_machine`). A machine file with
  `COMFY_CONTAINER=r9700tune-comfy`: exit 2, E1's NR1 line, no stop.
- CV3 *Refused while the operator's ComfyUI is listed, before anything is stopped* (open point OP2). `comfyui` listed: exit 2;
  exactly one stderr line, E1's owner line `r9700: the operator's ComfyUI (comfyui) is listed and holds the card; run bin/r9700
  comfy stop first`; no `stop`; no run folder; no `fingerprint.json` under `RESULTS_DIR/comfy-zimage`; `comfyui` and `vllm` still
  listed. A container named `comfyuix` listed instead: the run goes on (a whole name).
- CV4 *The lock.* A `step_bg … worker.sh child` holds the lock: `bench zimage base` → exit 4, the holder line `pid <pid>, step`,
  no call. While a bench holds it (`bench_bg zimage base` with S2's slow-run answer; wait for the first `exec` call):
  `r9700 step --model <35B> t -- worker.sh ok` → 4, the holder line names `comfy`; `bench_end` → 0.
- CV5 *One arm-round end to end: one stop, one restore, one record.* `bench zimage base --rounds 1`, the server running: exit 0;
  exactly one `stop vllm`; one `pwsh.exe -Detach` after it; `vllm` listed at the end; no marker; the lock free; no prefixed
  container listed at the end; `RESULTS_DIR/comfy-zimage/fingerprint.json` with `kind` `comfy` (`fingerprint.py show`);
  `rounds/base-1/bench.txt` passes `verdict.py comfy-check-block`; stdout holds `comfy: bench: outdir <RESULTS_DIR>/comfy-zimage`
  and `comfy: bench: 1 of 1 arm-rounds recorded; read them with bin/r9700 verdict <RESULTS_DIR>/comfy-zimage`. RED first.
- CV6 *Two arms, two rounds: still one stop and one restore, and the order alternates.* `bench zimage base fp16acc --rounds 2`:
  exit 0; one `stop vllm`, one `pwsh.exe -Detach`; four records; the bench containers' run calls, in log order, are base, fp16acc
  (round 1), fp16acc, base (round 2) — the test reads the arm from each container name.
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
  `dry-run:` (S2's `comfy_bench_dry_run`: at least the clear container, the bench container's run and the `exec` of `bench.py`);
  no `stop`; no `run` call; no `fingerprint.json`, no `rounds/`; the placed `bench.py` exists (the placement is before the dry
  run, as in `lib/kernels_verb.sh:169–173`). Like `moe-tune --dry-run` it takes the lock and restores first: with a marker left,
  one `pwsh.exe -Detach`, then the dry run.
- CV11 *An arm-round rejected on every try ends at `MAX_FAILED_TRIES` with the server restored once.* S2's stub answer for an
  `execution_error` on every run, `MAX_FAILED_TRIES=3`: exit 7; three attempts in `rejected/` each with a `reason`; no
  `rounds/base-1`; one `pwsh.exe -Detach` at the end; stderr holds `step failed 3 times`.
- CV12 *The folder name.* No `--out`: `comfy-zimage`; `--out zt1`: `RESULTS_DIR/zt1`; `bench wan5b base --dry-run` names
  `comfy-wan5b`.
- CV13 *A signal during the bench ends it cleanly.* `bench_bg zimage base` with S2's slow-run answer; wait for the first `exec`
  of `bench.py`; `kill -TERM $SUP`: exit 143; every prefixed container stopped (the cleanup's `container_stop_all`); `vllm`
  listed again; no marker; the lock free; `rounds/` holds no final `base-1`; the next `bench zimage base` sweeps the part to
  `rejected/` as `INTERRUPTED` (S2's sweep) and records `base-1`.

**`bin/r9700 verdict` over a bench folder** (`tests/test_comfy_bench_verb.sh`; the folders are made by a stub run of the verb, or
built by the test from S1's grammar with a fingerprint written through S2's `comfy_bench_fingerprint`)

- VD1 *A bench folder gets the comfy ship test.* After CV6 with the stub's timings scripted so that `fp16acc`'s `total_s` is
  below the base's spread: `r9700 verdict <RESULTS_DIR>/comfy-zimage` → exit 0; stdout holds `comfy bench <dir>: workflow
  zimage, base base, 2 rounds, fingerprint <12 hex>`, an `invoking: python3 …/verdict.py comfy --workflow zimage --metrics
  "total_s sampler_s vae_s" …` line naming `--decide total_s --direction lower`, and `verdict fp16acc: PASS`. A folder with
  `fp16acc-2` missing: exit 1 and `INCOMPLETE`. RED first.
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
(`tests/test_comfy_start.sh:40–46`, after `comfycase.sh` sources the new files) and the
exit-table test for brief step 5's words (`tests/test_lifecycle.sh:432`) are each seen RED after the code exists and before the rows are written, then
green.

### Brief for the Sonnet coder

Read first: this section, *Facts every story uses* and *The seam between S2 and S3*; S2's merged `lib/comfy_bench.sh` and its
spec section above; `bin/r9700:172–180`, `:226–310` (the series verb: the grammar, the prepare, the body), `:586–603`;
`lib/kernels_verb.sh` whole; `lib/series.sh:485–531` (`series_verdict`); `lib/run_guarded.sh:503–525`; `tests/lib/comfycase.sh`;
`tests/lib/seriescase.sh:1–40`; `tests/test_series_verdict.sh:1–60`; `tests/test_comfy.sh:20–75`. Reuse, never copy:
`supervise`, `step_run`, `config_load_machine`, `moe_place`, `_SERIES_OUT_RE`, `_RE_ARM`, `fingerprint.py show`, S2's seam. No
line of the new file or of `bin/r9700` names `wslc` as a word (the seam).

**1. `lib/comfy_bench_verb.sh`** (new; header in the style of `lib/kernels_verb.sh:1–13`: the verb half of `comfy bench`,
SOURCED after `lib/comfy_bench.sh`, takes no lock and sets no trap itself). Messages `r9700: comfy: bench: <text>` (stderr) and
`comfy: bench: <text>` (stdout).

- `_CB_USAGE` the CV1 usage line. `comfy_bench_args <args...>`: sets `_CB_WORKFLOW`, `_CB_ARMS` (array), `_CB_ROUNDS` (default
  3), `_CB_OUT`, `_CB_DRY` (`yes|no`); the option loop of `series_args` (`bin/r9700:233–265`) with `--rounds`, `--out`,
  `--dry-run`; the first word that is not an option is the workflow, the others are arms; the checks in CV1's order: usage,
  workflow in `comfy_bench_workflows` (a whole line), at least one arm, `--rounds` `^([1-9]|1[0-9]|20)$`, each arm `_RE_ARM` and
  once, `--out` default `comfy-<workflow>` and `_SERIES_OUT_RE`. 2 and one line each.
- `comfy_mode_bench`: `comfy_bench_args "$@" || return 2`, then `supervise comfy comfy_bench_prepare comfy_bench_body` and its
  code. The lock holder word is `comfy`, the same as `comfy start` and `build` (the parent's verb row: `supervise comfy …`).
- `comfy_bench_prepare`: `config_load_machine "${R9700_MACHINE_ENV:-./machine.env}" || return 2`, then `comfy_bench_check
  "$_CB_WORKFLOW" "$_CB_ROUNDS" "${_CB_ARMS[@]}" || return 2`. Nothing else: `supervise` runs E1's owner check right after it
  (CV3); no check of its own before the lock (OP2).
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
`README.md` exit list) gains `comfy bench: an unknown workflow or arm, a bench whose identity changed (fingerprint differs: …),
or the image COMFY_IMAGE does not exist` in the same words; row 1's `verdict` words cover a bench folder already (no change).
The three places must agree (`tests/test_lifecycle.sh:432`).

**6. Tests** as *Test scenarios*: every wait a bounded `wait_for` on a call-log line or a file, never a fixed sleep; every started
process recorded (`guard_pid`), `kill_recorded_pids "$CASE"` at the end of a test that leaves containers.

**7. Documents.** None of the four documents of `check_static.sh --unfinished` may hold `planned`, `E3 will` or `not built yet`.

- `research/module_comfyui.md`: the title says six modes; *Purpose* adds the bench in one sentence; a section *The bench* from
  S2's MERGED code (not from this plan): the verb, the arm table, the arm-round (the container, the cache clear, the free-card
  wait, the cold run and the three measured runs, the seeds, the failures, the output check, the evidence, the order, the
  record, the drift, the identity), the verdict over a bench folder; the flow `bench` in *The flows*; the Mermaid diagram gains
  the bench container, the bench cache volume and the supervisor; *Growth* gains the rows of this document's growth table
  that are S2's (the results folder, the bench cache volume, the exchange folder S2 names, the placed `bench.py`); *What is not
  proven* gains the facts the stub stands in for (S2's lines) until the acceptance observes them; *Acceptance on the R9700 (E2)*
  (below).
- `research/architecture.md`: the ComfyUI module row (`:23`) names `lib/comfy_bench.sh`, `lib/comfy_bench_verb.sh`,
  `comfyui/bench.py`, `comfyui/arms.conf` and `lib/fingerprint.py`'s comfy build; the verb row (`:41`) names `bench` (`supervise
  comfy`, one step, one stop and one restore of the operator's server; refused while ComfyUI is listed); the `verdict` row and
  the sentence of `:5` say that `verdict` reads a series folder or a bench folder; the exit table row 2 (step 5).
- `research/module_tests.md`: the row of `tests/test_comfy_bench_verb.sh` (CV1–CV13, VD1–VD5), OC1's extended row; the flow
  catalogue row `| \`bin/r9700 comfy bench\` and \`verdict\` over a bench folder | covered | …ids… |` and one `not covered` row
  `the bench on the card` naming the acceptance section; the knobs S3 adds (none expected).
- `README.md`: *The commands* line of `bin/r9700 comfy <mode>` names `bench`; the ComfyUI section gains a paragraph *Bench* (the
  command, the arms of `comfyui/arms.conf`, one stop and one restore of the operator's server, the first arm is the base, the
  folder `comfy-<workflow>`, resume by the same command, `bin/r9700 verdict <folder>` and what PASS, FAIL, NOT DECIDED and
  INCOMPLETE mean, that a series is three rounds); the exit list row 2 (step 5).

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

### Acceptance on the R9700 (the operator's session, after S2 and S3 are merged and E1's three acceptance runs are recorded)

Recorded in `research/module_comfyui.md` § *Acceptance on the R9700 (E2)*, the prediction written there BEFORE the first command;
each command with its output in a fenced block, the commit it ran at, the date, the image id, and what the record does not settle.
Not an `ACCEPTANCE_*.md` file: the parent gives its one acceptance record to E3 (the reason E1 gave, `PLAN_comfyui_r9700_E1.md`,
*Acceptance on the R9700*).

1. `bin/r9700 comfy bench zimage base fp16acc --rounds 1`, the operator's vLLM running. Prediction (the parent's, `:219–221`):
   `fp16acc` is inert on `zimage` (bf16 weights) and is recorded as inert with its evidence line; one stop and one restore of
   vLLM; two arm-rounds recorded. Recorded: the lines; per arm-round the `vram_free` and `vram_total` before the cold run, the
   cold run's time, the three measured runs' `sampler_s`, `vae_s`, `total_s`, the model-load flags, the evidence lines as found,
   the bench cache's size before each clear; the outputs, looked at by the operator (the record says so); the drift numbers of
   `fp16acc` against `base`.
2. `bin/r9700 verdict <RESULTS_DIR>/comfy-zimage`. Prediction: the one-round note, then `verdict fp16acc: NOT DECIDED` or a
   word the record explains; no speed claim is made from one round.
3. The facts the stub stands in for, each observed once and written down: `--tmpfs` and the read-only models volume accepted by
   `wslc run` (OP8), a named volume made or refused by `run` (fact 2), the environment of an `exec` (fact 3), the
   `/system_stats` fields (fact 4), the websocket messages and the `/history` fields (fact 5), the log lines of the evidence
   (fact 6), the TunableOp file (fact 7, by a by-hand run of `tunableop` with `--rounds 1` if the operator agrees to the GPU
   time), the image's `aiohttp`, `numpy` and `Pillow` versions (fact 8). A shape that differs from S2's parse is a fix and a
   deviation.
4. The operator's cache volume `COMFY_CACHE_VOLUME`, measured once (a throwaway container that runs `du -sh /cache`, by hand),
   and the growth row of `research/module_comfyui.md` corrected from "projected, not measured" to the measured value with its
   date (`:261` of the parent).

### Done when

- CV1–CV13, VD1–VD5 and OC1 pass through `node tests/run.mjs`; every other test passes unchanged (`tests/test_series_verdict.sh`
  and `tests/test_verdict.py` with no edit); each RED observation is in the summary.
- `comfy bench` is refused with E1's owner line while the operator's ComfyUI is listed, with nothing stopped; a bench stops the
  operator's vLLM once and restores it once however many arm-rounds it runs; a resume of the same command runs nothing and stops
  nothing; another experiment is refused before anything is stopped.
- `bin/r9700 verdict` gives the comfy ship test over a bench folder and the unchanged vLLM one over a series folder.
- `bin/r9700 commands` is unchanged; `comfy_modes` lists `bench`; the module row, the verb row, the README line and section and
  the exit rows exist; `bash tests/check_static.sh` exits 0 (the seam is still exactly `lib/adapter.sh`); CI green.
- The acceptance on the R9700 is recorded as above.

---

## Growth surfaces of these stories

| Surface | Story | Size | Who retires it | Interrupted |
|---|---|---|---|---|
| The results folder `<RESULTS_DIR>/comfy-<workflow>/` (`fingerprint.json`, `rounds/`, `rejected/`) | S2 (the worker writes it), S3 (names it) | per arm-round: `bench.txt` ≈ 2 KB, four run JSONs ≈ 20 KB, `server.log` ≈ 100 KB, the outputs (`zimage` 3 × ≈ 1.5 MB; `wan5b` 3 × ≈ 5 MB; plus the cold run's if S2 keeps it): ≈ 5 MB (`zimage`) and ≈ 15 MB (`wan5b`); a 6-arm × 3-round series ≈ 95 MB (`zimage`) and ≈ 270 MB (`wan5b`), the parent's figures; E2's acceptance ≈ 10 MB; each rejected attempt adds up to one arm-round's size, at most `MAX_FAILED_TRIES` per arm-round per invocation | kept forever: collected data is append-only and the operator's (the rule of every series here); the toolkit deletes nothing under `RESULTS_DIR` | a part left by a kill is moved to `rejected/` as `INTERRUPTED` at the next worker start (BW12); a fingerprint input folder left by a kill is removed by the next build (the series' rule) |
| The bench cache volume `<CONTAINER_PREFIX>comfy-cache` | S2 | one arm-round's MIOpen, Triton and TunableOp caches: at most 2 GB projected (the parent's projection for the operator's cache volume; the Triton MoE caches of this toolkit grew 0.5–1.3 GB per tuning chunk); measured by the size line of every clear and recorded in the arm-round | its CONTENT: the worker, cleared before every arm-round (so never more than one arm-round's caches); the volume itself: the operator, by hand — the toolkit never removes a volume | a killed arm-round leaves its caches until the next arm-round's clear |
| The bench container's empty `/data` (in memory with `--tmpfs`, OP8) | S2 | the venv `entrypoint.sh` makes at each start and ComfyUI's temp files: tens of MB of RAM, measured by the acceptance; the outputs do not go there (S2's spec, item 3) | gone with the container (`--rm`) | the cleanup stops the prefixed container |
| The exchange folder under `$WORK_DIR/r9700/` that S2's spec names (item 3) | S2 | at most one arm-round's outputs plus the base's round-1 references: ≤ 20 MB (`zimage`), ≤ 35 MB (`wan5b`) | the worker, once the outputs are in the record; S2's spec names the sweep | a kill leaves it; the next worker start sweeps it (S2's spec) |
| The placed `bench.py` under `$WORK_DIR/r9700/comfyui/` | S2 | one file, ≈ 15 KB | rewritten when the repository's file changes (`moe_place`) | a `.part` left by a kill is replaced by the next placement |
| Run folders `<RESULTS_DIR>/runs/<id>/` | S3 (through `supervise`) | one per invocation, as for every verb under the supervisor (the supervisor log, the step's logs, the guards' logs: KB) | unchanged: as every verb under the supervisor | unchanged |
| Test files | S1, S2, S3 | a few KB per run (bench files, fixture outputs, the fixture server's log) | the runner removes its run folder | the runner's sweep |

## Build order

1. **E2.S1** — Sonnet codes the S1 section; Opus reviews; Sonnet fixes. It touches nothing the others write.
2. **E2.S2** — Fable writes the spec into this file (it may start at once); the ledger line names it (this commit); the owner's
   answers to OP4–OP8 are read before the spec is final when they have come, else the spec uses the smallest fixes; Sonnet codes
   after S1 is merged; Opus reviews; Sonnet fixes.
3. **E2.S3** — Sonnet codes after S2 is merged; Opus reviews; Sonnet fixes. Then, after E1's three acceptance runs, the operator's
   session runs the E2 acceptance and records it.

## Definition of Done (E2, by story)

- [ ] S1: VC1–VC13 pass in CI; `tests/test_verdict.py` passes with no edit; the RED observations are in the summary.
- [ ] S2: the scenarios of Fable's spec pass in CI with the stub and the fixture server, each refusal seen failing first; every
      item of the parent's measurement contract is a scenario; the eight unverified facts are in *What it does not prove*.
- [ ] S3: CV1–CV13, VD1–VD5 and OC1 pass in CI; a bench stops and restores the operator's vLLM once; `verdict` reads both kinds of
      folder; the documents describe `bench`; the E2 acceptance on the R9700 is recorded with its `vram_free`, its cold-run time
      and its outputs, and the operator's cache volume is measured.
- [ ] Every story: the seam and personal-path checks pass; `research/architecture.md` and `research/module_tests.md` describe what
      exists; `node .agents/conventions/tools/plan-lifecycle.mjs` is clean.

## Open points for the plan owner

Each point names the parent plan's line, what is wrong or missing, and the smallest fix. None is applied to the parent plan by
this document. The stories use the smallest fix where they must, and say so at that place; a fix the owner rejects changes the
named place only. A change of the approved contract is a plan change: it goes through the parent's ledger after a review, not
through this document.

- **OP1 — The worker's file.** `PLAN_comfyui_r9700.md:154` and `:370` put the worker in `lib/comfy.sh` (`lib/comfy.sh bench`).
  That file is 747 lines; the worker and the verb half add several hundred, past the 800-line limit of coding-style. Smallest
  fix: the worker in `lib/comfy_bench.sh` (two faces, like `lib/series.sh`) and the verb half in `lib/comfy_bench_verb.sh` (like
  `lib/kernels_verb.sh`), with `comfy_mode_bench` defined there (`comfy_modes` derives it, `lib/comfy.sh:44`). No behaviour
  changes. Used by S2 and S3.
- **OP2 — The refusal "before the lock".** `PLAN_comfyui_r9700.md:154` says `bench` is refused before the lock while
  `COMFY_CONTAINER` is listed. E1 built that check into `supervise`, after the restore-first and the prepare and before anything
  is stopped (`lib/run_guarded.sh:511`), for every verb under the supervisor. A check before the lock needs the config before the
  lock and the restore, against the order of every verb (`bin/r9700:7–9`: a broken config must not block a restore) and against
  E1's restore guard (a marker beside a listed ComfyUI must end at the restore's exit 5, not at an earlier 2). Smallest fix: `bench`
  uses `supervise`'s check (exit 2, the same owner line, nothing stopped) and adds none before the lock. Used by S3 (CV3).
- **OP3 — The verdict word inside the spread.** `PLAN_comfyui_r9700.md:224–226` says a result inside the base's spread is
  reported as not decided, never as "no difference"; `:230–234` says the comfy verdict takes the vLLM RULE, where an arm inside
  the spread is FAIL (`lib/verdict.py:236–243`, "no decode median is higher than the base spread"); `:382` (the E2 DoD) names
  PASS below and FAIL above and is silent inside. Smallest fix: the comfy mode prints `NOT DECIDED (inside the base spread)` for
  a median inside the spread and FAIL only for one slower by more than the spread; the vLLM mode keeps its FAIL. Used by S1 (VC3,
  VC4).
- **OP4 — The `wan5b` VAE decode is already known.** `PLAN_comfyui_r9700.md:206–212` lets E3's feasibility run decide whether the
  base workflow switches to a tiled decode; `:254` already lists "a tiled VAE decode" among the fingerprint's constants.
  `research/module_comfyui.md:104` records that the untiled decode of this clip stalled for more than 10 minutes on the card and
  that `VAEDecodeTiled` took about 100 s (512 / 64 / 32 / 8) or about 70 s (512 / 32 / 64 / 4). Smallest fix: E2's `wan5b`
  workflow uses `VAEDecodeTiled` with constants the owner picks (the prototype's 512 / 64 / 32 / 8, or the faster 512 / 32 / 64 / 4
  of one sweep), recorded in the fingerprint; E3's feasibility run times that workflow and reads its memory and builds no
  untiled variant. One constant of `bench.py`'s table changes with the answer.
- **OP5 — The `wan5b` step count.** `PLAN_comfyui_r9700.md:215` sets `wan5b` to 20 `uni_pc` steps. `research/module_comfyui.md:105`
  records that 20 steps leave a diagonal hatching in this model's output that 50 steps (the model's official setting) remove. A
  series at 20 steps measures a workflow whose output is known to be flawed; 50 steps make each video generation about 2.5 times
  longer and E3's GPU hours grow with them. Smallest fix: the owner picks 20 (the record then says the output carries the
  hatching) or 50. One constant of `bench.py`'s table; S2 keeps 20 until the answer.
- **OP6 — Where the arm evidence is written, and two arms without one.** `PLAN_comfyui_r9700.md:91` puts the arms in "the same
  grammar" as `config/arms.conf`, which has four fields and no place for evidence (`lib/config.sh:545`); `:183–185` and
  `:196–200` name evidence for `fp16acc`, `tunableop` and `miopen` only, none for `fp8mm` and `compile`. Smallest fix: the
  evidence is a fifth field of the comfy arm table (the arm loader takes the field count as an argument; `config/arms.conf` keeps
  four) or a second table keyed by arm name — S2's spec picks one; `fp8mm`'s evidence is its `--fast fp8_matrix_mult` word in
  ComfyUI's own argv (`/system_stats` `system.argv`) and a log line if the acceptance finds one (it is a screening arm, and an
  inert result is reported as inert); `compile`'s is the `TorchCompileModel` node in the node times of every measured run.
- **OP7 — How `bench.py` is tested in CI.** `PLAN_comfyui_r9700.md:104` writes `bench.py` with "stdlib + the image's aiohttp";
  `:286–288` tests it against local fixtures in CI. `tests/requirements.txt` holds `pytest` and its dependencies only;
  `aiohttp`, `numpy` and `Pillow` are not in the test environment. Smallest fix, one of two, S2's spec picks: (a)
  `tests/requirements.txt` gains exact pins of `aiohttp` (and of `numpy` and `Pillow` if the output check and the drift are
  tested on the host) — a dependency change, under the dependency rules; or (b) `bench.py`'s transport and checks are written
  with the standard library (`urllib`, a small websocket client over `socket`, `ffprobe` and a pixel read without `numpy`), and
  the drift's `numpy` part is tested inside the image only, by the acceptance. Either way the pure parts of `bench.py` import
  nothing outside the standard library (the seam's `workflows` and `metrics` run on the host).
- **OP8 — Two engine features the isolation assumes.** `PLAN_comfyui_r9700.md:163–164` gives the bench container an empty `/data`
  by `--tmpfs` and the models volume read-only. Neither `--tmpfs` nor a read-only NAMED volume is used anywhere in the toolkit
  (only Windows bind mounts take `:ro`: `lib/serve.sh:79`, `lib/comfy.sh:737`), and neither has been observed with `wslc`.
  Smallest fix: none to the plan now; S2 builds them, the E2 acceptance observes them first (S3, acceptance item 3). If `wslc`
  refuses either, the fallback — a prefixed empty data volume cleared like the bench cache, or the models volume mounted
  read-write — changes the isolation and is the owner's to approve.
