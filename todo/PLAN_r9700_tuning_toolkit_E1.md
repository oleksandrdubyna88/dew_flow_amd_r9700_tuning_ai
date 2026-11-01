# PLAN — E1 stories: a usable, trustworthy server-flag comparison

> Status: **plan only, nothing implemented yet, 2026-11-01.** Scope: the three stories of epic E1 of
> [PLAN_r9700_tuning_toolkit.md](PLAN_r9700_tuning_toolkit.md) — section
> [E1 — a usable, trustworthy server-flag comparison](PLAN_r9700_tuning_toolkit.md#e1--a-usable-trustworthy-server-flag-comparison).
> Cornerstones: E1.S2 and E1.S3 (`model: fable`), recorded in the parent's ledger line.

This document splits E1 into stories. It adds no scope to E1 and removes none. The parent plan keeps the change
ledger; this document has none of its own (plan-change-control: a stories document keeps no ledger).

## Stories at a glance

| Story | Title | Spec by | Code by | Depends on | Cornerstone |
|---|---|---|---|---|---|
| E1.S1 | Config contract, ship-test verdict, quality harness, test and CI base | Opus (this document) | Sonnet | nothing in E1 (one precondition, below) | no |
| E1.S2 | Lifecycle and restore protocol: supervisor, guards, adapter seam, `init` | **Fable** — `model: fable` | Sonnet | E1.S1 | **yes** — area (1) |
| E1.S3 | Run identity and completion: the series, fingerprint, atomic arm-round records, `series` and `verdict`, docs, acceptance | **Fable** — `model: fable` | Sonnet | E1.S1, E1.S2 | **yes** — area (2) |

Order: S1, then S2, then S3. Fable may write the S2 spec while S1 is coded. The S3 spec is written after the S2 spec
is approved, because S3 consumes the exit-code contract, the container naming and the worker interface that S2 fixes.
Every story is reviewed by Opus and fixed by Sonnet (subagent-models, per-story pipeline).

## Coverage — every E1 item is in exactly one story

The parent's E1 *Scope* and *Done when*, item by item. Nothing below is in two stories; where a later story extends a
file an earlier one creates, the row says which part each one writes.

| E1 item (parent plan) | Story | The other stories' part |
|---|---|---|
| Config contract: `lib/config.sh`, `machine.env.example`, `models/*.env`, `config/arms.conf`, validation | S1 | S2 may add or change lifecycle fields (it then updates the loader, the example and `research/module_config.md` in its own commit) |
| An invalid config field is refused, with the field and the legal values | S1 (the loader) | S2: the ordering test — refused **before any server is stopped** |
| `research/module_config.md` lists every field | S1 | S2 as above |
| `lib/harness.py` (20 greedy prompts, GSM8K-200) | S1 | S3 runs it in round 1 |
| `lib/verdict.py`; reproduces `fcombo` pass, `fb1` and `o7` fail | S1 | S3 wires `bin/r9700 verdict` |
| CI workflow (unit, guard, static checks), the static check for personal paths, `LICENSE` | S1 | S2 and S3 add test files to the same runner; no second workflow |
| First `research/architecture.md` and `research/module_tests.md` | S1 (what S1 builds) | S2 and S3 add their modules and flows |
| Adapter seam for `wslc` and `powershell.exe` | S2 | — |
| `lib/serve.sh wait_ready.sh bench.sh restore.sh guard_ram.sh guard_quiet.sh disk_gate.sh run_guarded.sh` | S2 | — |
| *Lifecycle and recovery* paragraph whole (supervisor, `flock`, marker, worker group, prefix, restore-first, readiness, exit 3, `init`) | S2 | — |
| `bin/r9700` entry point and `init` | S2 | S3 adds `series` and `verdict` |
| Guard tests: RAM stop leaves no orphan; exit 3 waited, not failed; deadline stops the step; restore runs once; unreadable telemetry is unsafe; every wait has a ceiling; the deadline keeps a cleanup budget; a guard stop writes the server log tail | S2 | — |
| Growth row *containers* | S2 | — |
| `lib/series.sh`; *Run identity* (fingerprint, atomic arm-round records, refused resume naming what differs) | S3 | — |
| A lost server leaves no done marker; a container that fails to start is retried a bounded number of times, then the arm is unsupported | S3 | — |
| Growth row *series outdir* | S3 | — |
| "Kept exactly" behaviour list | split by file: harness content S1; bench and the mounted generation config S2 (`bench.sh`, `serve.sh`); prefill, spec-decode metrics, round-1 quality, alternating arms S3 (`series.sh`) | — |
| `README.md` quick start for `init`, `series`, `verdict` | S3 | — |
| Series acceptance run on the R9700 (`base` vs `ta3`, one round, 35B); both example model files run `series` unedited | S3 | — |

Out of E1 (other epics, not to be built here): MoE tuning, `prefixtest`, `linear-bench`, the `run` driver,
`POST_DEPLOY.md`, the final README and publication (E2, E3). The `PREFIXTEST=1` branch of the old series script
(`speed_A.sh` lines 76–78) belongs to E3.

## Facts every story uses

**Sources and their line numbers.** Line numbers below are of the **last-run copies** of the scripts (the operator's
backup of the 2026-11-01 session; the main session gives a coder or a spec writer their location — it is not written
in a tracked file). The published copies are in `dew_flow_benchmark · research/vllm-r9700-speed-options/harness/`
(read with `git show origin/main:<path>`, never by a checkout in that repository). Checked 2026-11-01 with `diff`:
`harness.py`, `restore_server.sh`, `ram_guard_all.sh`, `wait_quiet.sh`, `disk_gate.sh` and `night5.sh` are identical
in both; `serve.sh`, `bench.sh` and `speed_A.sh` differ (the published ones are older, before the 2026-11-01 model
variables); `wait_ready.sh` and `night7.sh` are not published. Line counts: `serve.sh` 22, `wait_ready.sh` 14,
`bench.sh` 11, `restore_server.sh` 22, `ram_guard_all.sh` 16, `wait_quiet.sh` 13, `disk_gate.sh` 26, `speed_A.sh` 95,
`night5.sh` 45, `night7.sh` 56, `harness.py` 282.

**Fixtures for the verdict** (copy byte for byte, with
`git -C <benchmark checkout> show origin/main:research/vllm-r9700-speed-options/<path> > <target>`):

| Source path (under `research/vllm-r9700-speed-options/`) | Target | Content |
|---|---|---|
| `night-2026-10-31/raw/bench_final_ab.txt` | `tests/fixtures/ship_test/bench_final_ab.txt` | 357 lines; arms `fbase`, `fcombo`, `fb1`, 3 rounds; two incomplete blocks (below) |
| `night-2026-10-31/option7/bench_option7.txt` | `tests/fixtures/ship_test/bench_option7.txt` | 216 lines; arms `o7ref`, `o7`, 3 rounds; 36 lines per arm-round |
| `night-2026-10-28/quality/gsm8k_fbase.json` | `tests/fixtures/ship_test/quality/gsm8k_fbase.json` | 171 of 200, stderr 0.024897… |
| `night-2026-10-31/quality/gsm8k_fcombo.json` | `…/quality/gsm8k_fcombo.json` | 169 of 200, stderr 0.025591… |
| `night-2026-10-31/quality/gsm8k_fb1.json` | `…/quality/gsm8k_fb1.json` | 171 of 200 |
| `night-2026-10-31/quality/gsm8k_o7ref.json` | `…/quality/gsm8k_o7ref.json` | 170 of 200 |
| `night-2026-10-31/quality/gsm8k_o7.json` | `…/quality/gsm8k_o7.json` | 170 of 200 |
| `night-2026-10-28/quality/prompts_fbase.json` | `tests/fixtures/prompts/prompts_fbase.json` | 20 greedy results |
| `night-2026-10-31/quality/prompts_fcombo.json` | `tests/fixtures/prompts/prompts_fcombo.json` | 12 of 20 identical to `fbase` |
| `night-2026-10-31/quality/prompts_fb1.json` | `tests/fixtures/prompts/prompts_fb1.json` | 20 of 20 identical to `fbase` |

Scanned 2026-11-01 for personal paths and names: none of these files holds one (they carry `http://127.0.0.1:8000`
and the served name only).

**The two incomplete blocks in `bench_final_ab.txt`** (counted 2026-11-01; the results file mentions only the first):

- `fcombo-2`, file lines 145–174 (30 lines): the block of 20:32 that the RAM guard stopped during the 32k prefill —
  it ends after `prefill32768 r=1`. The complete `fcombo-2` block is lines 175–210.
- `fb1-2`, file lines 211–213 (3 lines): one `c=1 r=1` triple of a start the RAM guard stopped (01:52). The complete
  `fb1-2` block is lines 214–249.

**The recorded verdicts the verdict must reproduce** (`dew_flow_benchmark ·
research/RESULTS_vllm_029_r9700_speed_options.md` § 13.2 *Correction* and § 13.5 last bullet), recomputed here
2026-11-01 from the fixtures with complete blocks only — spread = max − min over the base arm's 9 values (3 rounds × 3
seeds), difference = the arm's 9-value median − the base's 9-value median:

| Arm vs base | c=1: arm / base / delta / base spread | c=4: arm / base / delta / base spread | GSM8K delta / limit | Verdict |
|---|---|---|---|---|
| `fcombo` vs `fbase` | 84.47 / 76.08 / +8.39 / 9.84 | 202.44 / 178.39 / +24.05 / 10.90 | −0.0100 / 0.0512 | **pass** |
| `fb1` vs `fbase` | 77.33 / 76.08 / +1.25 / 9.84 | 181.00 / 178.39 / +2.61 / 10.90 | +0.0000 / 0.0498 | **fail** |
| `o7` vs `o7ref` | 85.64 / 85.66 / −0.02 / 3.51 | 202.40 / 203.39 / −0.99 / 7.86 | +0.0000 / 0.0505 | **fail** |

Two wrong ways to compute, both checked 2026-11-01, so the tests can name them: counting every line (incomplete
blocks included) gives `fcombo` c=1 a median of 83.56 over 12 values and `fb1` c=1 77.50 over 10; the spread over the
three round medians (76.08 / 75.26 / 76.62) is 1.36, not 9.84.

**The ship test** (written before the 2026-10-27 run, results file § 2 *Setup*): an arm passes on speed when its
output-throughput median is higher than the base's by **more than** the base spread at c=1 **or** c=4 (rule 1), and
at no concurrency is it lower by more than that concurrency's base spread (rule 2); and on quality when
|GSM8K accuracy delta| ≤ 2 × max(stderr of the two) (`harness.py` lines 195–202).

**Test frameworks — dependency-light.** Python: `pytest`, the only third-party package, pinned exactly in
`tests/requirements.txt`. Shell: plain bash test scripts `tests/test_*.sh` with a small shared assertion file
`tests/lib/assert.sh`; stub `wslc` and `powershell.exe` executables in `tests/stubs/` are put first on `PATH` for
shell behaviour (S2 writes the stubs). No bats. One runner, `tests/run.mjs` (Node, already required by the shared
conventions), runs both kinds one after the other — one worker, below the 8-worker cap — at lowered priority
(local-cpu-budget).

**Test leftovers (rule `common.test-leftovers`).** Every test file writes only inside ONE folder per run,
`testsToDelete-<owner>-r9700-run-<id>`, which `tests/run.mjs` claims, creates and removes, and the next run sweeps if
this one was killed. pytest gets it as `--basetemp`; a bash test gets its own subfolder as `R9700_TEST_ROOT`. No test
calls `mktemp`, `mkdtemp` or sets `TMPDIR` (the guard's `raw-temp` class). Product code under `lib/` makes no temp
path outside the directory it is given (an atomic write uses a sibling `<name>.part` in the same directory).
**Precondition, owned by the main session, not by a coder:** the token `r9700` is registered as a row of the
`## Tokens` table of `common/test-leftovers.md` in `dew_flow_conventions` (row: `` `r9700` `` · `dew_flow` ·
`the R9700 tuning toolkit`), released, and this repository's `.agents/conventions` pin is moved to that release.
A cross-repository change, so it is named in both plans (planning-docs, *Across repositories*). Until it lands,
S1's guard step is red by design and S1 is not merged.

**Public repository.** No personal path, account name, machine name or token in any tracked file — the machine's
values live only in the untracked `machine.env`. Examples use placeholders such as `C:\r9700\work`.

---

## E1.S1 — Config contract, ship-test verdict, quality harness, test and CI base

**Cornerstone:** no. **Depends on:** nothing in E1; the token precondition above. **Spec:** this section (Opus).
**Code:** one Sonnet coder.

### What it delivers

1. A config layer: one untracked `machine.env`, one `models/<name>.env` per model, one `config/arms.conf`; a bash
   loader that validates every field before anything else runs and never executes the files' content.
2. `lib/verdict.py`: the ship test over bench lines, which reproduces the three recorded verdicts and uses complete
   arm-round blocks only; a `check-block` command that S3 uses to validate an arm-round record.
3. `lib/harness.py`: the quality harness, unchanged in what it measures, with an atomic result write.
4. The test base: the runner, the assertion file, the vendored leftovers helper, fixtures, the static check, the CI
   workflow, `.gitignore`, `LICENSE`, and the first `research/` documents.

### Files it creates

| File | What |
|---|---|
| `lib/config.sh` | the loader and the field table (source of truth for every field) |
| `config/arms.conf` | the arm table |
| `machine.env.example` | every machine field, with placeholders and one comment line each |
| `models/qwen3.6-35b-a3b-gptq.env`, `models/qwen3.8-27b-awq.env` | the two example models, from the measured runs |
| `lib/verdict.py` | `ship` and `check-block` |
| `lib/harness.py` | from `harness.py` |
| `tests/run.mjs` | the one test runner |
| `tests/lib/lower-priority.mjs` | verbatim copy of `.agents/conventions/tools/templates/lower-priority-preload.mjs`, only its `MOUNT` line edited to `new URL("../../.agents/conventions/", import.meta.url)` |
| `tests/lib/owned.mjs`, `tests/lib/git.mjs`, `tests/lib/leftovers-sweep.mjs` | byte-identical copies of the same files under `.agents/conventions/tools/lib/` at the pinned submodule |
| `tests/lib/owned-token.mjs` | this repository's own token file: `REPO_TOKEN = "r9700"`, `REPO_ROW = "the R9700 tuning toolkit"` (shape: the header of `.agents/conventions/tools/lib/owned-token.mjs`) |
| `tests/lib/assert.sh` | bash assertions |
| `tests/requirements.txt` | `pytest==<exact version>` |
| `tests/conftest.py` | fixture paths (`FIXTURES = Path(__file__).parent / "fixtures"`) |
| `tests/test_config.sh`, `tests/test_verdict.py`, `tests/test_harness.py`, `tests/test_static.sh` | the scenarios below |
| `tests/check_static.sh` | the static checks |
| `tests/fixtures/…` | the files of the fixture table above, plus `tests/fixtures/config/` (below) |
| `.github/workflows/tests.yml` | CI |
| `.gitignore` | `machine.env`, `.venv/`, `__pycache__/`, `*.pyc`, `.pytest_cache/` |
| `LICENSE` | Apache-2.0 (the same licence as the vendored vLLM benchmark that E2 adds, so the tree has one licence; the operator may change it before publication in E3) |
| `research/module_config.md` | every field: name, file, type, legal values, default, what it does, where it came from |
| `research/module_tests.md`, `research/architecture.md` | first versions, only what S1 builds |
| `research/README.md` | rows for the three documents |

### The field table (the config contract)

`machine.env` (untracked; `machine.env.example` is tracked):

| Key | Type and legal values | Default | Replaces |
|---|---|---|---|
| `WSLC` | command: a bare name looked up on `PATH`, or an absolute path | `wslc` | `serve.sh` line 8 |
| `POWERSHELL` | command | `powershell.exe` | `ram_guard_all.sh` line 8, `disk_gate.sh` line 7 |
| `RESTORE_SHELL` | command | `pwsh.exe` | `restore_server.sh` line 19 |
| `IMAGE` | image reference `^[a-z0-9][a-z0-9./_-]*:[A-Za-z0-9._-]+$` | required | `serve.sh` line 8 |
| `HF_VOLUME`, `CACHE_VOLUME` | name `^[a-z0-9][a-z0-9_.-]*$` | `hf-cache`, `vllm-cache` | `serve.sh` line 10 |
| `WORK_DIR` | WSL directory, absolute, exists | required | `serve.sh` lines 9–10 (the Windows form) |
| `WORK_DIR_WIN` | Windows path `^[A-Za-z]:\\` — the same directory, mounted at `/work` | required | `serve.sh` lines 9–10 |
| `PATCH_DIR` | WSL directory, absolute, exists — base of every mount source | required | `serve.sh` lines 13–16; `speed_A.sh` lines 13, 15 |
| `PATCH_DIR_WIN` | Windows path of the same directory | required | as above |
| `GENCONFIG_WIN` | Windows path of the operator's generation-config directory | required | `speed_A.sh` line 19 |
| `GSM8K_DATA` | container path `^/` | `/work/gsm8k/test.jsonl` | `speed_A.sh` line 83 |
| `RESULTS_DIR` | WSL path, absolute; its parent exists | required | new (growth row *series outdir*) |
| `PROD_CONTAINER` | name | `vllm` | `restore_server.sh` line 14; `speed_A.sh` line 44 |
| `RESTORE_SCRIPT_WIN` | Windows path | required | `restore_server.sh` line 19 |
| `RESTORE_ARGS` | string | required | `restore_server.sh` lines 16, 20–21 (and its `restore_args` file) |
| `CONTAINER_PREFIX` | `^[a-z0-9][a-z0-9-]{0,15}-$` | `r9700tune-` | the `vllmprtest-` literal (`ram_guard_all.sh` line 11, `restore_server.sh` line 11) |
| `RAM_MIN_MB` | integer 512..65536 | `2048` | `night5.sh` line 20 (`ram_guard_all.sh` line 6 had 4096) |
| `QUIET_LOAD_MAX` | decimal 0.1..64 | `4` | `wait_quiet.sh` line 9 |
| `QUIET_BUSY_PATTERN` | string; empty = no process check | empty | `wait_quiet.sh` line 7 (`coai-exp`) |
| `QUIET_BUSY_IGNORE` | string; a command-line substring that excludes a match | empty | `wait_quiet.sh` line 7 (`keep-awake`) |
| `DISK_GATE` | enum `on` `off` | `on` | `disk_gate.sh` |
| `DEADLINE` | `HH:MM` 24 h, or empty = none | empty | `night5.sh` line 10 |
| `MAX_RUN_MINUTES` | integer 10..2880 — the ceiling when `DEADLINE` is empty or later | `720` | new (every wait has a ceiling) |
| `CLEANUP_BUDGET_S` | integer 60..3600 — kept free before the deadline for cleanup and restore | `900` | new (E1 done-when) |

`models/<name>.env` (tracked):

| Key | Type and legal values | Default | Replaces |
|---|---|---|---|
| `MODEL_DIR` | container path | required | `serve.sh` line 19 |
| `SERVED_NAME` | name `^[a-z0-9][a-z0-9._-]*$` | required | `serve.sh` line 19 |
| `MAX_MODEL_LEN` | integer 2048..1048576, and ≥ 1536 (bench 1024 + 512) | required | `speed_A.sh` line 11 |
| `MAX_NUM_SEQS` | integer 1..256 | required | `serve.sh` line 20 |
| `GPU_MEM_UTIL` | decimal 0.10..0.95 | `0.85` | `serve.sh` line 20 |
| `PREFILL_LENS` | list of integers, each + 128 ≤ `MAX_MODEL_LEN` | required | `speed_A.sh` line 12 |
| `TUNED_CONFIG_DIR` | container path, or empty | empty | `speed_A.sh` line 58 |
| `MOUNTS` | list of `<relative source>:<container path>[:ro]`; source relative to `PATCH_DIR`, no `..`, no leading `/` | empty | `serve.sh` lines 13–16 |
| `EXTRA_SERVE_ARGS` | string, split on spaces; quotes are refused | empty | `serve.sh` line 21 |

The two example models (values from the measured runs):

- `models/qwen3.6-35b-a3b-gptq.env`: `MODEL_DIR=/root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ`,
  `SERVED_NAME=qwen3.6-35b-a3b`, `MAX_MODEL_LEN=131072`, `MAX_NUM_SEQS=4`, `GPU_MEM_UTIL=0.85`,
  `PREFILL_LENS="8192 32768"`, `TUNED_CONFIG_DIR=/work/moe/tune/merged`,
  `MOUNTS="C/auto_gptq.py:/opt/python/lib/python3.14/site-packages/vllm/model_executor/layers/quantization/auto_gptq.py:ro C/gptq_utils.py:/opt/python/lib/python3.14/site-packages/vllm/model_executor/layers/quantization/utils/gptq_utils.py:ro"`,
  `EXTRA_SERVE_ARGS="--limit-mm-per-prompt.image 0 --limit-mm-per-prompt.video 0"`.
- `models/qwen3.8-27b-awq.env`: as above except `MODEL_DIR=/root/.cache/huggingface/local/Qwen3.8-27B-AWQ`,
  `SERVED_NAME=qwen3.8-27b`, `MAX_MODEL_LEN=16384`, `MAX_NUM_SEQS=16`, `PREFILL_LENS=8192` (`night7.sh` line 22). It
  keeps the same `MOUNTS` and `TUNED_CONFIG_DIR`, because that is how it was measured on 2026-11-01 (`speed_A.sh`
  line 62 mounts variant C for every arm, line 58 sets the tuned folder for every arm).

`config/arms.conf` — one arm per line, four fields separated by ` | `: name, serve arguments, environment
(`KEY=VALUE` words), extra mounts (same grammar as `MOUNTS`). `#` starts a comment line. The rows, from `speed_A.sh`
lines 27–34 and 57–60 (MTP 2 unless named; `--generation-config /genconfig` is NOT in the table — `serve.sh` adds it
for every arm, it is on the "kept exactly" list):

| Arm | Serve arguments | Env | Extra mounts |
|---|---|---|---|
| `base`, `fbase` | `--speculative-config.method mtp --speculative-config.num_speculative_tokens 2` | | |
| `mtp1` | same with `1` | | |
| `mtp3`, `ra3` | same with `3` | | |
| `mnbt8k` | MTP 2 + `--max-num-batched-tokens 8192` | | |
| `tattn` | MTP 2 + `--attention-backend TRITON_ATTN` | | |
| `fp8kv` | MTP 2 + `--kv-cache-dtype fp8` | | |
| `fcombo`, `o7ref`, `ta3` | MTP 3 + `--attention-backend TRITON_ATTN` | | |
| `ta3mb` | MTP 3 + `--attention-backend TRITON_ATTN --max-num-batched-tokens 8192` | | |
| `fb1` | MTP 2 | `VLLM_TUNED_CONFIG_FOLDER=/work/moe/tune/merged_b1` | |
| `o7` | MTP 3 + `--attention-backend TRITON_ATTN` | | `work/speed/o7/rdna_hybrid_w4a16.py:/opt/python/lib/python3.14/site-packages/vllm/model_executor/kernels/linear/mixed_precision/rdna_hybrid_w4a16.py:ro` |
| `ra3opt` | MTP 3 | | `work/speed/ra/rocm_attn.py:/opt/python/lib/python3.14/site-packages/vllm/v1/attention/backends/rocm_attn.py:ro` |

`q27old` and `q27new` (`speed_A.sh` line 27, comment line 26) are dropped: with a model file they are `base` and `ta3`.

### Test scenarios

Shell scenarios are in `tests/test_config.sh` and `tests/test_static.sh`; Python ones in `tests/test_verdict.py` and
`tests/test_harness.py`. Test names state the guarantee. "The machine fixture" is
`tests/fixtures/config/machine.env.in` with `@ROOT@` replaced by the test's `R9700_TEST_ROOT` (the test creates
`@ROOT@/work`, `@ROOT@/patches/C/auto_gptq.py`, `@ROOT@/patches/C/gptq_utils.py`,
`@ROOT@/patches/work/speed/o7/rdna_hybrid_w4a16.py`, `@ROOT@/patches/work/speed/ra/rocm_attn.py` as empty files, and
the parent of `@ROOT@/results`). It sets every required machine key: `WSLC=wslc`, `POWERSHELL=powershell.exe`,
`IMAGE=rocm/vllm:rocm10.1.0_ubuntu24.04_py3.14-pytorch_2.13.0_vllm-0.29.0`, `WORK_DIR=@ROOT@/work`,
`WORK_DIR_WIN=C:\r9700\work`, `PATCH_DIR=@ROOT@/patches`, `PATCH_DIR_WIN=C:\r9700\patches`,
`GENCONFIG_WIN=C:\r9700\genconfig`, `RESULTS_DIR=@ROOT@/results`, `RESTORE_SCRIPT_WIN=C:\r9700\start-vllm.ps1`,
`RESTORE_ARGS="-Model /root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ -ServedName qwen3.6-35b-a3b -MaxModelLen 131072 -MaxNumSeqs 4 -Detach"`.
A "variant" of it is the same file with one line changed, written by the test into its root.

**Config loader (`tests/test_config.sh`)**

1. *The machine fixture and the 35B example load and apply the defaults.* Given the machine fixture and
   `models/qwen3.6-35b-a3b-gptq.env`; when `config_load` runs; then it returns 0, prints nothing on stderr, and
   `R9700_SERVED_NAME=qwen3.6-35b-a3b`, `R9700_MAX_MODEL_LEN=131072`, `R9700_PREFILL_LENS="8192 32768"`,
   `R9700_RAM_MIN_MB=2048`, `R9700_CONTAINER_PREFIX=r9700tune-`, `R9700_CLEANUP_BUDGET_S=900`.
2. *Both example model files load unedited.* Same machine fixture with `models/qwen3.8-27b-awq.env`: returns 0;
   `R9700_SERVED_NAME=qwen3.8-27b`, `R9700_MAX_NUM_SEQS=16`, `R9700_MAX_MODEL_LEN=16384`, `R9700_PREFILL_LENS=8192`.
   The list of model files is derived (`models/*.env`), not typed, so a third example is covered by the same loop.
3. *A missing required key is refused with the field and its legal values.* Variant without the `IMAGE` line: returns
   2; stderr has exactly one line starting `config: ` that contains `IMAGE: required`, and the legal shape
   `image reference <repository>:<tag>`.
4. *A non-integer is refused with the range.* Variant `RAM_MIN_MB=2GB`: returns 2; stderr line contains
   `RAM_MIN_MB: "2GB" is not an integer; legal: 512..65536` and the file name and line number of that line.
5. *An enum value outside the set is refused with the set.* `DISK_GATE=maybe`: returns 2; stderr contains
   `DISK_GATE: "maybe" is not one of: on off`.
6. *An unknown key is refused with the list of legal keys.* `RAM_MIN=2048` (a typo): returns 2; stderr contains
   `RAM_MIN: unknown key` and the word `RAM_MIN_MB` in the listed legal keys (the list printed is
   `config_keys` output, not a typed copy).
7. *The loader never executes the file.* Variant `IMAGE=$(touch @ROOT@/pwned)`: returns 2; stderr contains
   `IMAGE: "$" and "`" are not allowed (values are never expanded)`; the file `@ROOT@/pwned` does not exist. Same for
   a backtick variant.
8. *All errors are reported in one pass.* A variant with both `RAM_MIN_MB=x` and `DISK_GATE=maybe`: returns 2;
   stderr has exactly two `config: ` lines, one per field.
9. *A duplicate key is refused.* Two `IMAGE=` lines: returns 2; stderr names the second line number and
   `IMAGE: set twice (first on line <n>)`.
10. *A WSL path where a Windows path is required is refused.* `WORK_DIR_WIN=/mnt/c/r9700/work`: returns 2; stderr
    contains `WORK_DIR_WIN: "/mnt/c/r9700/work" is not a Windows path; legal: X:\…`.
11. *A prefill length that does not fit the context is refused (cross-field check).* A model variant of the 27B file
    with `PREFILL_LENS="8192 16384"`: returns 2; stderr contains `PREFILL_LENS: 16384 + 128 output tokens exceed
    MAX_MODEL_LEN 16384`. The unchanged 27B file passes (scenario 2) — the positive for the same fixture.
12. *A mount that leaves the patch directory is refused.* Model variant with `MOUNTS="../x.py:/opt/x.py:ro"`:
    returns 2; stderr contains `MOUNTS: "../x.py" leaves PATCH_DIR`.
13. *The arm table gives the measured arguments.* `arms_load config/arms.conf`, then for every arm of the table above,
    `arm_args <arm>` prints exactly the listed arguments, one per line; `arm_env fb1` prints
    `VLLM_TUNED_CONFIG_FOLDER=/work/moe/tune/merged_b1`; `arm_mounts o7` prints the one `o7` mount. (This table is a
    parity check against the measured scripts, `speed_A.sh` lines 27–34 and 57–60; it is the reference, not a copy of
    `arms.conf`.)
14. *An unknown arm is refused with the legal arms.* `arms_check base nosuch`: returns 2; stderr contains
    `arm "nosuch" is not in config/arms.conf; legal:` followed by the names `arms_names` prints.
15. *A missing mount source is refused before use.* With the machine fixture loaded but
    `@ROOT@/patches/work/speed/o7/rdna_hybrid_w4a16.py` removed: `arms_check o7` returns 2 and names the missing file;
    `arms_check fcombo` returns 0.
16. *A duplicate arm is refused with its line.* An arms file with two `base` rows: `arms_load` returns 2, stderr
    contains `base: defined twice (lines <a> and <b>)`.
17. *Every field is documented, and nothing else is.* The keys printed by `config_keys` equal, as sets, the keys in
    the first column of the two field tables of `research/module_config.md` (parsed from the markdown rows). A key
    added to the loader without a doc row fails this test, and so does a doc row for a removed key.
18. *The example machine file holds every machine key.* Every machine key of `config_keys` appears as `KEY=` (or
    `# KEY=` for an optional key left at its default) in `machine.env.example`.

**Verdict (`tests/test_verdict.py`)** — `run(args)` calls `lib/verdict.py` as a subprocess with `sys.executable` and
returns (exit code, stdout, stderr). `AB = fixtures/ship_test/bench_final_ab.txt`, `O7 = …/bench_option7.txt`,
`Q = …/quality`.

19. *`fcombo` passes, as recorded.* `ship --base fbase --arm fcombo --bench AB --prefill-lens "8192 32768"
    --gsm8k-dir Q`: exit 0; stdout contains the lines
    `  c=1 output tok/s: median 84.47 vs 76.08, delta +8.39, base spread 9.84 -> within, not lower`,
    `  c=4 output tok/s: median 202.44 vs 178.39, delta +24.05, base spread 10.90 -> higher`,
    `  gsm8k accuracy: 0.8450 vs 0.8550, delta -0.0100, limit 0.0512 -> pass`,
    `verdict fcombo: PASS`.
20. *`fb1` fails, as recorded.* Same with `--arm fb1`: c=1 `median 77.33 vs 76.08, delta +1.25, base spread 9.84 ->
    within, not lower`; c=4 `median 181.00 vs 178.39, delta +2.61, base spread 10.90 -> within, not lower`; gsm8k
    `delta +0.0000, limit 0.0498 -> pass`; `verdict fb1: FAIL (no decode median is higher than the base spread)`.
21. *`o7` fails, as recorded.* `ship --base o7ref --arm o7 --bench O7 --prefill-lens "8192 32768" --gsm8k-dir Q`:
    c=1 `median 85.64 vs 85.66, delta -0.02, base spread 3.51 -> within, lower`; c=4 `median 202.40 vs 203.39, delta
    -0.99, base spread 7.86 -> within, lower`; `verdict o7: FAIL (no decode median is higher than the base spread)`.
22. *Incomplete blocks are ignored and named.* Run 19's command: stdout also contains
    `ignored incomplete block: fcombo-2, 30 lines from bench_final_ab.txt:145` and
    `ignored incomplete block: fb1-2, 3 lines from bench_final_ab.txt:211`, and the `fcombo` header says
    `3 rounds, 9 values per concurrency`.
23. *Named for the refuted approach:* `test_counting_every_line_would_give_fcombo_83_56_from_12_values_and_that_is_the_point`
    — the test computes the naive median over every `fcombo` c=1 line of the fixture (83.56, n=12) and asserts the
    verdict prints 84.47 and 9 values: the two differ, which is why blocks are checked.
24. *Named for the refuted approach:* `test_spread_over_round_medians_would_be_1_36_and_is_not_used` — the three
    `fbase` c=1 round medians give 1.36; the verdict prints `base spread 9.84`.
25. *"By more than" is strict, with exact decimals.* A synthetic bench file (built by a helper in the test that
    writes complete 36-line blocks from given c=1/c=4 throughput values; other metrics constant). Base c=4 values
    `50.00 50.05 50.10 50.11 50.12 50.20 50.30 50.40 60.90` (median 50.12, spread 10.90); every arm c=4 value `61.02`
    (delta exactly +10.90); c=1 all `40.00` for both. Then: verdict `FAIL`, c=4 `-> within, not lower`. With every
    arm c=4 value `61.03`: `PASS`, `-> higher`. Binary floating point gets the first case wrong — checked 2026-11-01:
    `61.02 − 50.12` is `10.900000000000006` and `60.90 − 50.00` is `10.899999999999999` in `float`, so a float
    comparison says "higher". The verdict uses `decimal.Decimal` parsed from the text.
26. *Rule 2: lower by more than the spread at the other concurrency fails.* Synthetic: c=4 delta +20 with spread 10,
    c=1 delta −(spread + 0.01): `FAIL (c=1 is lower by more than the base spread)`, c=1 `-> lower`. With c=1 delta
    exactly −spread: `PASS`, c=1 `-> within, lower`.
27. *Quality outside 2 × stderr fails.* A GSM8K file written by the test for the arm with `summary` n 200, correct
    150, accuracy 0.75, stderr 0.030619 against `gsm8k_fbase.json`: `gsm8k … delta -0.1050, limit 0.0612 -> fail`;
    `verdict <arm>: FAIL (gsm8k)`, even when the speed rules pass.
28. *A missing round makes the arm incomplete, not a verdict.* A copy of `O7` without the `o7-3` lines,
    `--rounds 3`: exit 1; stdout `verdict o7: INCOMPLETE (missing complete arm-rounds: o7-3)`; no `PASS`/`FAIL` line
    for `o7`.
29. *A base without complete rounds is an input error.* `--base nosuch`: exit 2; stderr
    `base arm "nosuch" has no complete arm-round in the inputs`.
30. *A line that is not a bench line is refused with its place.* A copy of `AB` with `garbage` appended: exit 2;
    stderr `bench_final_ab.txt:358: not a bench line`.
31. *Missing quality is incomplete; skipping it is said.* `--gsm8k-dir` pointing at a directory without
    `gsm8k_fcombo.json`: exit 1, `verdict fcombo: INCOMPLETE (no gsm8k_fcombo.json)`. With `--no-quality` instead:
    exit 0, `verdict fcombo: PASS (quality NOT checked)`.
32. *Prefill is reported, not judged.* Run 19's command prints
    `  prefill32768 median TTFT ms: median 15586.41 vs 16164.65, delta -578.24, base spread 909.60 (information)`, and
    the verdict line is the same as in 19.
33. *`--json` writes the same numbers, atomically.* With `--json <basetemp>/v.json`: the file parses; for `fcombo`
    `c4.delta == "24.05"`, `c4.spread == "10.90"`, `c4.n == 9`, `verdict == "PASS"`; no `v.json.part` remains. When the
    write fails (the target is a directory), exit 2 and no partial file.
34. *`check-block` accepts exactly one complete block.* Lines 175–210 of `AB` written to a file:
    `check-block --tag fcombo-2 --prefill-lens "8192 32768" <file>` exits 0. Lines 145–174: exit 1, stdout lists the
    missing keys, the first being `prefill32768 r=2 Output token throughput (tok/s)`. Lines 175–210 with line 175
    duplicated: exit 1, `expected 36 lines, found 37 (duplicate: c=1 r=1 Output token throughput (tok/s))`. Lines
    211–213: exit 1, `expected 36 lines, found 3`.

**Quality harness (`tests/test_harness.py`)**

35. *The original self-test cases hold.* Each assertion of `harness.py` lines 207–233 (`parse_token_id`, `parse_top`,
    the six `compare_item` cases, the five `extract_number` cases) is one pytest test with the same inputs and
    expected values.
36. *Compare reproduces the recorded prompt results.* `compare prompts_fbase.json prompts_fb1.json`: exit 0, last
    line `20 identical of 20; divergences all near-tie: yes`. `compare prompts_fbase.json prompts_fcombo.json`: exit 1,
    last line `12 identical of 20; divergences all near-tie: no`.
37. *GSM8K compare reproduces the recorded quality check.* `gsm8k-compare gsm8k_fbase.json gsm8k_fcombo.json`: exit
    0, output `accuracy A=0.8550 B=0.8450 delta=-0.0100 limit=2*max(stderr)=0.0512 pass=yes`.
38. *Collect writes 20 results from a server.* A stub HTTP server (`http.server` on `127.0.0.1`, port 0, in a thread)
    answers `/v1/completions` with one choice `{"text": "x", "finish_reason": "length", "logprobs": …}` whose
    `logprobs` has `tokens ["token_id:1","token_id:2"]`,
    `top_logprobs [{"token_id:1": -0.1, "token_id:9": -2.0}, {"token_id:2": -0.2, "token_id:8": -3.0}]`,
    `token_logprobs [-0.1, -0.2]`: `collect --url http://127.0.0.1:<port> --model m --out <basetemp>/p.json` exits 0;
    the file has 20 results, each `token_ids == [1, 2]`, and the server saw 20 requests with `temperature 0`,
    `logprobs 2`, `return_tokens_as_token_ids true`.
39. *A failing server leaves no result file.* The stub answers HTTP 500 on the 3rd request: `collect` exits non-zero,
    stderr names `HTTP 500`, and neither `p.json` nor `p.json.part` exists.
40. *GSM8K scores from a server.* A 3-row data file (golds `#### 5`, `#### 5`, `#### 7`), the stub answers every
    chat request with `"... #### 5"`: `gsm8k --n 3 --concurrency 1` writes `summary.correct == 2`,
    `summary.n == 3`; the stub saw `temperature 0` and `chat_template_kwargs {"enable_thinking": false}`.

**Static checks (`tests/test_static.sh`, which runs `tests/check_static.sh`)**

41. *The tracked tree is clean.* `bash tests/check_static.sh` exits 0 on the S1 tree.
42. *The personal-path scan finds a planted path.* A file `$R9700_TEST_ROOT/planted.txt` with one planted line:
    `bash tests/check_static.sh --scan <file>` exits 1 and prints `planted.txt:1:`. One test per pattern: a Windows
    profile path (drive `C:`, then `Users`, then the name `someone`, joined by backslashes), the same through
    `/mnt/c/`, a Linux home directory of `someone`, a macOS one. The test BUILDS each planted line at run time by
    joining two parts (for example `"/ho""me/someone/x"`), so no tracked file — this plan and the test file included —
    holds a match. A file with `C:\r9700\work` and a placeholder profile path whose name is `<you>` exits 0. (The
    scan's companion: it must still find a known instance — testing, *A structural test that matches nothing passes
    forever*.)
43. *A syntax error is caught.* A file `$R9700_TEST_ROOT/bad.sh` with `if then`: `check_static.sh --bash <file>`
    exits 1 naming it; a file `bad.py` with `def (`: `--python <file>` exits 1 naming it.
44. *`machine.env` cannot be committed by accident.* `git check-ignore -q machine.env` returns 0.
45. *The vendored leftovers helper equals the mounted one.* When `.agents/conventions/tools/lib/owned.mjs` exists,
    the sha256 of each of `tests/lib/owned.mjs`, `git.mjs`, `leftovers-sweep.mjs` equals that of the mounted file; a
    difference fails naming the file (it means the pin moved and the copies were not refreshed).

**Runner (checked by hand once, written into `research/module_tests.md`)**

46. After `node tests/run.mjs`, no folder whose name starts `testsToDelete-<your owner token>-r9700-` is left in the
    temp root; after a run killed with `kill -9` during the pytest step, the next run's first lines report it as
    removed (`gone` owner).

### Brief for the Sonnet coder

Read first: this section; `todo/PLAN_r9700_tuning_toolkit.md` sections *Design*, *Config contract*, the "kept exactly"
paragraph; `.agents/conventions/common/test-leftovers.md` §2–§4; the header comments of
`.agents/conventions/tools/lib/owned.mjs` and `leftovers-sweep.mjs`. Do not read or change anything about the
lifecycle (S2) or the series (S3).

**1. `lib/config.sh`** (bash, `set -u` safe, no `set -e` inside functions, sourced — it runs nothing at source time
except defining functions and the field table).

- The field table: one function call per field, `_field <scope> <KEY> <type> <default-or-"required"> "<one-line
  description>"`, with scope `machine` or `model`, in the order of the tables above. Types: `cmd`, `image`, `name`,
  `dir` (absolute, exists), `path` (absolute, parent exists), `win` (`^[A-Za-z]:\\`), `cpath` (`^/`), `cpath?`
  (empty allowed), `int:<min>:<max>`, `dec:<min>:<max>`, `enum:<a>,<b>`, `hhmm?`, `str`, `str?`, `ints` (space list),
  `mounts`, `args`. Cross-field checks run after all single-field checks: `MAX_MODEL_LEN ≥ 1536`; each `PREFILL_LENS`
  value + 128 ≤ `MAX_MODEL_LEN`; each `MOUNTS` source exists under `PATCH_DIR`.
- Parsing, per line: blank and `#` lines skip; otherwise the line must match `^([A-Z][A-Z0-9_]*)=(.*)$`. A value is
  either bare (no spaces, no quotes) or wrapped in one pair of double quotes. Refuse `$` and `` ` `` anywhere in a
  value (scenario 7), a quote inside a quoted value, and trailing text after the closing quote. Never `source`,
  `eval` or `declare` the file content; assign with `printf -v "R9700_$key" '%s' "$value"` only after the key was
  found in the table.
- `config_load <machine.env> <model.env>`: parse both, apply defaults, validate, collect every error (format
  `config: <file>:<line>: <KEY>: <problem>; legal: <legal>`; a missing key has no line: `config: <file>: <KEY>:
  required; legal: <legal>`), print them all to stderr, return 2 if any, else export every `R9700_<KEY>` and return
  0. A key valid for the other scope is still unknown in this file (`IMAGE` in a model file is refused).
- `config_keys`: prints `<scope> <KEY> <type> <default>` per field — the one list the tests and the docs derive from.
- `config_resolved`: prints every `R9700_<KEY>=<value>` sorted by key (S3 hashes it for the fingerprint).
- `arms_load <file>`, `arms_names`, `arm_args <arm>` (one argument per line, so a caller does
  `mapfile -t a < <(arm_args x)`), `arm_env <arm>`, `arm_mounts <arm>`, `arms_check <arm>...` (exists, and each
  mount source exists under `R9700_PATCH_DIR`). Same error format, return 2. Arm names `^[a-z0-9]+$`; an arguments
  field may not contain quotes, `$` or `` ` ``.
- No literal model, machine or person anywhere in the file.

**2. `config/arms.conf`, `machine.env.example`, `models/*.env`** — exactly the tables above. The example uses
placeholders (`C:\r9700\work`, `/mnt/c/r9700/work`, `C:\r9700\start-vllm.ps1`) and a comment line per key taken from
the field's description; optional keys at their default appear commented out (`# RAM_MIN_MB=2048`).

**3. `lib/verdict.py`** (Python ≥ 3.10, stdlib only — it also runs in the image's 3.14).

- Line grammar (one compiled regex):
  `^(?P<arm>[a-z0-9]+)-(?P<round>[1-9][0-9]*) (?:c=(?P<c>[14]) r=(?P<r>[1-9])|prefill(?P<len>[0-9]+) r=(?P<pr>[1-9])) (?P<metric>Output token throughput \(tok/s\)|Mean TTFT \(ms\)|Mean TPOT \(ms\)|Median TTFT \(ms\)):\s+(?P<value>[0-9]+(?:\.[0-9]+)?)\s*$`.
  Real lines carry trailing spaces (`fbase-1 c=1 r=1 Output token throughput (tok/s):         74.29     `). Blank lines
  skip; any other line is an input error `<file>:<line>: not a bench line` (exit 2).
- Blocks: per tag `<arm>-<round>`, a block starts at its `c=1 r=1 Output token throughput` line and runs to the next
  such line of the same tag, across `--bench` files in the order given. `expected_keys(prefill_lens)` returns the 36
  keys of a complete block for two prefill lengths (18 decode: c ∈ {1,4} × r ∈ {1,2,3} × {Output token throughput,
  Mean TTFT, Mean TPOT}; 9 per length: r ∈ {1,2,3} × {Output token throughput, Mean TTFT, Median TTFT}). A block is
  complete when its keys equal that set and none repeats. Per tag the LAST complete block is used; every incomplete
  block is reported as `ignored incomplete block: <tag>, <n> lines from <file basename>:<first line>`; an earlier
  complete block replaced by a later one is reported as `superseded complete block: …`. The canonical key order
  (used whenever keys are listed): c=1 r=1..3, then c=4 r=1..3, then each prefill length in `--prefill-lens` order
  with r=1..3; inside each, the metrics in the order Output token throughput, Mean TTFT, then Mean TPOT (decode) or
  Median TTFT (prefill).
- `check-block` does NOT split: every line of the file must carry the given tag, and the whole file is one block —
  complete when its keys equal the expected set with no repeat. It prints the missing keys in canonical order, or
  `expected <n> lines, found <m>` (with `(duplicate: <key>)` when a key repeats).
- Numbers: parse every value with `decimal.Decimal(text)`; median with `statistics.median` over Decimals; spread =
  max − min of the base's values; print with two decimals (`quantize(Decimal("0.01"))`, `ROUND_HALF_EVEN`) and an
  explicit sign for deltas; compare the unrounded Decimals.
- Words for a decode line: `higher` (delta > spread), `within, not lower` (0 ≤ delta ≤ spread), `within, lower`
  (−spread ≤ delta < 0), `lower` (delta < −spread). Verdict: `PASS` when some concurrency is `higher` and none is
  `lower` and quality passes; else `FAIL (<first reason>)` with the reasons `no decode median is higher than the base
  spread`, `c=<c> is lower by more than the base spread`, `gsm8k`.
- GSM8K: read `summary.accuracy` and `summary.stderr` from `<dir>/gsm8k_<arm>.json` and `gsm8k_<base>.json`; delta and
  limit = 2 × max(stderr) with four decimals; pass when |delta| ≤ limit (as `harness.py` lines 196–199).
- CLI: `ship --base <arm> --arm <arm> [--arm …] --bench <file> [--bench …] --prefill-lens "<lens>" [--rounds 3]
  (--gsm8k-dir <dir> | --no-quality) [--json <file>]`; `check-block --tag <tag> --prefill-lens "<lens>" <file>`.
  Exit codes: `ship` 0 every arm decided (PASS or FAIL), 1 at least one INCOMPLETE, 2 input error; `check-block` 0
  complete, 1 incomplete, 2 input error. Output order per arm: header, c=1, c=4, prefill lines (`(information)`, on
  `Median TTFT (ms)`), gsm8k, verdict — the strings of scenarios 19–34 exactly.
- `--json`: a list with one object per arm, `{"arm", "base", "rounds", "c1", "c4", "prefill", "gsm8k", "verdict",
  "reason"}`; `c1`/`c4` are `{"median", "base_median", "delta", "spread", "n", "word"}` with the Decimal numbers as
  two-decimal strings (`"24.05"`); `prefill` maps `"8192"` etc. to the same shape; `gsm8k` is `null` with
  `--no-quality`; `verdict` is `"PASS"`, `"FAIL"` or `"INCOMPLETE"`. Write `<file>.part`, then `os.replace`; on any
  error remove the `.part` and exit 2.
- Functions under 50 lines; no globals mutated; no literal arm name.

**4. `lib/harness.py`** — copy `harness.py` (all 282 lines). Change only `save_json` (lines 105–107): write
`<path>.part`, then `os.replace(part, path)`; remove the `.part` when the dump raises. Keep `PROMPTS` (lines 13–34),
`GSM_SUFFIX` (line 35), every request payload (lines 112–114, 171–174), every default (lines 239–268), the sequential
collect (line 130) and the `--selftest` flag — they are on the "kept exactly" list. No other change.

**5. Test base.**

- `tests/run.mjs`: first `await import("./lib/lower-priority.mjs")`; then `sweepLeftovers({ repo })` from
  `./lib/leftovers-sweep.mjs` (repo = the repository root) and print one line per `removed`, `preserved`, `listed` and
  `errors` entry — it never changes the exit code; then a `cleanupScope()` and ONE `ownedDir(scope, "run")` from
  `./lib/owned.mjs`; in `try`: run, one after the other, `python -m pytest -q -p no:cacheprovider --basetemp
  <run>/pytest <py files>` (python = `.venv/bin/python` when it exists, else `python3`) and `bash <file>` for each
  `tests/test_*.sh` with `R9700_TEST_ROOT=<run>/sh/<file stem>` (created with `mkdir`) and `PATH` unchanged (S2 adds
  the stub directory per test). Spawn with an argv array, never a shell string, with a ceiling per file (10 min) that
  kills the child's process group. Optional arguments filter the files (`node tests/run.mjs tests/test_verdict.py`).
  Print `PASS <file>` / `FAIL <file> (exit <n>)` per file and a total; `finally`: `await scope.close()`. Exit 1 if any
  file failed. The file list is derived by globbing `tests/test_*.py` and `tests/test_*.sh`, never typed.
- `tests/lib/assert.sh`: `assert_eq <expected> <actual> <name>`, `assert_contains <haystack> <needle> <name>`,
  `assert_exit <code> <name> -- <cmd...>` (captures stdout and stderr into `$OUT` / `$ERR`), `t_finish` (prints
  `<n> passed, <m> failed`, exits 1 on any failure). Each test body is a function `t_<guarantee>`; the file ends with
  calling every function whose name starts with `t_` (derived with `declare -F`).
- `tests/check_static.sh`: no arguments = all checks over `git ls-files`; `--scan <files>`, `--bash <files>`,
  `--python <files>` = one check over the given files (scenarios 42–43).
  - bash: `bash -n` on every tracked `*.sh` and every file under `bin/`.
  - python: `python3 -c 'import sys; [compile(open(f, encoding="utf-8").read(), f, "exec") for f in sys.argv[1:]]'`
    over every tracked `*.py` — the same syntax check as `py_compile` without writing `__pycache__` into the tree.
  - personal paths, `grep -nE` over every tracked text file (binary files skipped with `grep -I`), with these four
    extended regular expressions, each written inside single quotes in the script:
    `[A-Za-z]:\\Users\\[A-Za-z0-9._-]`, `/mnt/[a-z]/Users/[A-Za-z0-9._-]`, `/home/[A-Za-z0-9._-]+/`,
    `/Users/[A-Za-z0-9._-]+/`. Output `<file>:<line>: <text>`; exit 1 on any hit. A placeholder name in angle
    brackets (`<you>`) does not match, because `<` is outside the name class. The patterns are chosen so that their
    own text does not match them (after `Users\`, `Users/` or `home/` the next character in the pattern text is `[`),
    so the script and this plan can be scanned like every other file — no file is excluded.
  - vendored copies: scenario 45.
- `tests/fixtures/`: the fixture table above, plus `tests/fixtures/config/machine.env.in`.
- `tests/requirements.txt`: install with `pip install 'pytest>=8,<9'`, then write the exact installed version
  (`pip freeze | grep '^pytest=='`).

**6. CI — `.github/workflows/tests.yml`.** On `push` and `pull_request`; `ubuntu-latest`; `actions/checkout` with
`submodules: true`; `actions/setup-node` (Node 20) and `actions/setup-python` (3.12); steps:
`npm ci --ignore-scripts --prefix .agents/conventions`; `python -m pip install -r tests/requirements.txt`;
`node tests/run.mjs`; `bash tests/check_static.sh`;
`node .agents/conventions/tools/leftovers-check.mjs --repo . --token r9700 --identity "the R9700 tuning toolkit" --profile node`
(check the flag names against that file's header at the pinned version before writing the step; if it reports the
vendored `tests/lib/*.mjs`, read in that header how it recognises a copied helper beside its own `owned-token.mjs`
before changing anything — never add an exemption to make it green);
`node .agents/conventions/tools/plan-lifecycle.mjs`. No throttling in CI (local-cpu-budget §3).

**7. Docs.** `research/module_config.md`: an intro, then two tables with the header
`| Key | Type and legal values | Default | What it does | Replaces |` (machine, model), then the `arms.conf` grammar and
table. `research/module_tests.md`: where the tests are, the exact commands below, the flow catalogue so far
(`lib/verdict.py ship`, `check-block`; `lib/harness.py collect | compare | gsm8k | gsm8k-compare`; the config
loader) each `covered` with its test file, the runner check of scenario 46, and *what it does not prove* (no GPU, no
real `wslc`, no real vLLM server — the HTTP stub stands in for it). `research/architecture.md`: what exists after S1,
one paragraph per module, and a Mermaid flowchart of config → loader → (later) supervisor; describe nothing that
does not exist yet.

**Commands.**

```bash
python3 -m venv .venv && .venv/bin/python -m pip install -r tests/requirements.txt   # once
node tests/run.mjs                                   # every test, lowered, one worker
node tests/run.mjs tests/test_verdict.py             # one file
bash tests/check_static.sh                           # static checks
node .agents/conventions/tools/leftovers-check.mjs --repo . --token r9700 --identity "the R9700 tuning toolkit" --profile node
node .agents/conventions/tools/plan-lifecycle.mjs
```

Report the runner's output (every file's PASS line and the total) and the static check's exit code. For scenarios
19–21, also report one run against the real fixture with the output pasted, so a reviewer sees the numbers.

---

## E1.S2 — Lifecycle and restore protocol (cornerstone, `model: fable`)

**Cornerstone:** **yes**, area (1) of the parent. Fable writes this story's scenarios and brief; this section gives
only the goal, the files, the boundaries, the source facts and the questions the spec must answer.
**Depends on:** E1.S1 (loader, runner, assertion file, CI).

### Goal

`bin/r9700` is the one supervisor. It can stop the operator's server, run a worker step in its own process group under
the RAM, quiet-PC, disk and deadline guards, survive a guard stop, the deadline or a hard kill, and restore the
operator's server exactly once, ready, at the end — or on the next invocation of any kind after a hard kill. Every
call to `wslc` and to Windows PowerShell goes through one adapter, so the CI stubs replace exactly one place.

### Files

`bin/r9700` (supervisor, dispatch, `init`); `lib/adapter.sh`; `lib/serve.sh`, `lib/wait_ready.sh`, `lib/bench.sh`,
`lib/restore.sh`, `lib/guard_ram.sh`, `lib/guard_quiet.sh`, `lib/disk_gate.sh`, `lib/run_guarded.sh`; `tests/stubs/wslc`,
`tests/stubs/powershell.exe`, `tests/stubs/pwsh.exe`; `tests/test_lifecycle.sh`, `tests/test_guards.sh` (names may be
refined by the spec); updates to `research/architecture.md`, `research/module_tests.md`, and — only if a lifecycle
field changes — `lib/config.sh`, `machine.env.example`, `research/module_config.md`.

### Boundaries

- In: the whole *Lifecycle and recovery* paragraph of the parent; the guard behaviours of E1's *Done when*; the growth
  row *containers*; `bench.sh` and the `--generation-config /genconfig` mount in `serve.sh` exactly as on the "kept
  exactly" list (`bench.sh` lines 5–10: random 1024/512, c=1 with 6 prompts and c=4 with 12, seeds 1–3; the output
  line prefix `<tag> c=<c> r=<r> `, which `lib/verdict.py` parses).
- In: an ordering test that an invalid config is refused before any `wslc stop` (the stub's call log has no stop).
- Out: the series loop, arm-rounds, done records, fingerprint, prefill, spec metrics, round-1 quality (S3). S2
  exposes to S3: the worker invocation, the exit-code contract, the container naming, and a `serve`/`wait_ready`/
  `bench` interface.
- Out: the `run` driver chaining several steps (E3). S2's supervisor runs ONE step (with its waits and repeats).
- Out: MoE cache clearing (E2).

### Source facts (verified 2026-11-01)

| Source | Lines | What it does now | What E1 must change |
|---|---|---|---|
| `serve.sh` | 6–21 | starts a detached `--rm` container with fixed mounts, env and args; literals for `wslc` path, image, Windows paths (8–10, 15) | read config; one adapter; the prefix name |
| `serve.sh`, `wait_ready.sh` | 22; 6–13 | waits up to 120 × 10 s; 3 missed `wslc list --no-trunc` reads = exited (plain `list` cuts long names); saves the log | keep the ceiling and the 3-miss rule |
| `restore_server.sh` | 9 | a `skip_restore` file skips one restore (the drivers' workaround for nested traps) | dropped: one restore, by the supervisor |
| `restore_server.sh` | 11–13, 14, 16–21 | stops every `vllmprtest-*` container; does nothing if `vllm` runs; reads a `restore_args` file; starts the server with `pwsh.exe -File <start script> … -Detach` | no readiness wait today — E1 adds `/v1/models` + one-token request, bounded, loud on failure |
| `ram_guard_all.sh` | 7–16 | every 15 s reads Windows "Available MBytes"; below the limit stops test containers and TERMs the group | line 9: an unreadable value counts as fine — E1: unsafe |
| `wait_quiet.sh` | 6–12 | 3 quiet checks 300 s apart; load < 4 and no busy process | no ceiling of its own (`night5.sh` line 29 wraps it in `timeout 900`) |
| `disk_gate.sh` | 5–25 | baseline/check of the newest disk/stornvme System-log record; exit 1 new event, 2 query failed or log reset; state file beside the script | state file moves to the run's directory |
| `night5.sh` | 14, 16–27 | `trap` restore on EXIT; `setsid` step; RAM guard at 2048; deadline watcher every 30 s that stops tests and TERMs the group | the deadline keeps no time for cleanup and restore — E1 adds `CLEANUP_BUDGET_S` |
| `night5.sh` | 29, 36–41 | quiet wait; up to 6 failed tries; exit 3 = not quiet, waited, not counted | the exit-3 contract moves into the supervisor |
| `speed_A.sh`; `night7.sh` | 44; 41 | `wslc stop vllm` without any record of what to restore | E1: the recovery marker is written BEFORE the stop |
| RESULTS § 13.4 | — | 2026-10-31 21:43: the guard TERMed the driver only; its child series ran on, wrote a false done marker and started a server while production loaded | the stub test: a RAM stop leaves no process of the worker group |

### Open questions the spec must answer

1. **Supervisor and worker.** How `bin/r9700` starts the worker (`setsid`), stays outside its group, and handles its
   own SIGINT/SIGTERM. What a SIGKILL of the supervisor leaves (the lock is freed by the kernel; the worker group may
   live on): does the marker record the worker's process group and start time, and does the next invocation stop that
   group (only when it is provably the same process, not a reused pid) before it restores?
2. **The lock.** Where the `flock` file lives; whether a second invocation waits or refuses (and with what message
   naming the holder); which invocations take it (`init`? `verdict`, which only reads?).
3. **The recovery marker.** Path, content (pre-run state of `PROD_CONTAINER` — running or not —, the restore command,
   run id, time), atomic write, and when it is cleared (after readiness only). If the operator's server was NOT
   running before the run, does the restore start it? (The old script always started it.)
4. **Restore-first.** Every invocation restores first when a marker exists — before or after taking the lock, and
   before or after config validation (a broken config must not block the restore of a server the marker describes)?
5. **Readiness.** The two checks (`/v1/models` answers; a one-token request completes), how they reach the server
   (an `exec` into `PROD_CONTAINER` like `wait_ready.sh` line 10, or the published port), the ceiling, and the exit
   code and stderr line of a restore that does not become ready.
6. **Exit-code contract** between worker and supervisor: 0, 3 (not quiet: wait for `guard_quiet` within the deadline
   and repeat the same step), a guard stop, the deadline, a worker failure. How the supervisor learns WHY the worker
   ended without parsing messages (a typed outcome file written by the guard, for example). The maximum number of
   failed tries (the drivers used 6).
7. **Unreadable telemetry.** RAM value or load unreadable: stop at once, or after how many consecutive failed reads
   (one failed PowerShell call should not end a night; three in 45 s may)? Either way it is never counted as fine.
8. **Deadline and budget.** How `DEADLINE`, `MAX_RUN_MINUTES` and `CLEANUP_BUDGET_S` combine; that every wait
   (`wait_ready`, `guard_quiet`, restore readiness, the stop of containers) is bounded by the remaining budget.
9. **Containers.** Name shape `<CONTAINER_PREFIX>…` and its length (the 20-character cut of plain `wslc list`); how a
   guard stop finds and stops every prefixed container; what `init` removes (stopped and running?) and whether it may
   do so while another run holds the lock.
10. **The log tail.** On a guard stop, which container's log is saved, how many lines, and where in the run directory.
11. **The adapter seam.** The function interface (`wslc_run`, `wslc_exec`, `wslc_list`, `wslc_stop`, `wslc_logs`,
    `win_ram_mb`, `win_disk_newest`, `restore_start`, or fewer) and how a bare `WSLC=wslc` resolves to the stub on
    `PATH` in tests and to the real executable on the machine.
12. **The stubs.** How a test scripts the stubs' answers (files or environment per call), what they record (an
    append-only call log under `R9700_TEST_ROOT`), and how a stubbed container "process" is made so that an orphan is
    observable (a real child `sleep` whose pid the test checks after the RAM stop).
13. **`init`.** What it checks and creates (config valid, `RESULTS_DIR`, the adapter answers, leftover prefixed
    containers) and its output.
14. **A derived flow list.** How `bin/r9700` lists its verbs (for example `bin/r9700 commands`), so
    `research/module_tests.md` can derive its flow catalogue (scenario-tests rule 4).
15. **Stop only when admitted.** The operator's server is stopped only when a step is admitted (the quiet check
    passed and the step starts), never while the supervisor waits for a quiet PC: measured 2026-11-01 12:03–12:47,
    a driver stopped production at its start and then waited 44 minutes for a quiet PC with the GPU idle. How
    does a wait after an exit 3 handle the server — restore it while waiting, or keep it stopped when the wait is
    short — and what bounds the number of stop/start cycles (each model load drives Windows available RAM near
    zero, RESULTS § 6.5)?

---

## E1.S3 — Run identity and completion (cornerstone, `model: fable`)

**Cornerstone:** **yes**, area (2) of the parent. Fable writes this story's scenarios and brief, after the S2 spec is
approved. **Depends on:** E1.S1 (config, arms, `verdict.py check-block`, `harness.py`), E1.S2 (supervisor, exit-code
contract, serve/bench, guards, stubs).

### Goal

`bin/r9700 series <model> <arm>…` runs arm-rounds in alternating order under the S2 supervisor and records each
arm-round only when it is complete, atomically, so a resume can trust every record it skips; a resume whose effective
experiment differs is refused and names what differs. `bin/r9700 verdict <outdir>` prints the ship test. A person can
do all of it from the README quick start, and the acceptance run on the R9700 is recorded.

### Files

`lib/series.sh`; the fingerprint code (`lib/fingerprint.py` or a function in `series.sh` — the spec decides);
`bin/r9700` gains `series` and `verdict`; `tests/test_series.sh`, `tests/test_fingerprint.py` (names may be refined);
`README.md` quick start for `init`, `series`, `verdict`; updates to `research/architecture.md` and
`research/module_tests.md`; the acceptance record in `research/` (for example `research/ACCEPTANCE_series_<date>.md`).

### Boundaries

- In: the parent's *Run identity* paragraph whole; the growth row *series outdir*; the "kept exactly" items the
  series owns — prefill 8192/128 and 32768/128 × 3 at c=1 with 3 prompts (`speed_A.sh` lines 36–43, lengths from
  `PREFILL_LENS`), spec-decode metrics (lines 74–75), round 1 adds the 20 greedy prompts and GSM8K-200 (lines 79–84),
  arms alternate inside a round (line 45).
- In: E1 done-when "a lost server leaves no done marker" and "a container that fails to start is retried a bounded
  number of times before the arm is marked unsupported" (today: 2 tries, 60 s apart, lines 62–67).
- In: the definition of a complete arm-round reuses `lib/verdict.py check-block` (S1) for the bench lines — one
  definition of "complete", not two.
- Out: the supervisor, the guards, restore, the lock, the marker (S2) — `series.sh` sets no restore trap
  (`speed_A.sh` line 20 goes) and does not stop the operator's server itself (line 44 goes).
- Out: `PREFIXTEST` (lines 76–78, E3); MoE (E2).

### Source facts (verified 2026-11-01)

| Source | Lines | What it does now | What E1 must change |
|---|---|---|---|
| `speed_A.sh` | 45–47, 92 | skips an arm-round when `done_<arm>-<round>` exists; writes it with `touch` at the end | the record is written to a temporary name, validated and renamed |
| `speed_A.sh` | 71–72, 85–91 | counts only the six `Output token throughput` decode lines appended to a shared `bench.txt`, and whether the container is still listed | prefill lines and the other metrics are not checked; a partial block stays in the shared file (the two incomplete blocks of the fixture) |
| `speed_A.sh` | 51–55 | `QUIETCHECK=1`: exit 3 at an arm-round start when the PC is busy | the exit-3 contract is S2's; the check before each arm-round stays here |
| `speed_A.sh` | 48, 94 | disk gate before every arm-round and at the end | through S2's `disk_gate.sh` |
| `speed_A.sh` | 56, 58–60 | container name `vllmprtest-sp-<arm>-<round>`; tuned folder and per-arm mounts by `if` | name from S2; args, env and mounts from `arms.conf` (S1) |
| `speed_A.sh` | 69–70 | greps the server log for configuration lines (MoE config used, KV cache size, backend) | kept as evidence in the record |
| `night5.sh` | 30, 35–37 | counts missing done markers; refuses to start when the remaining arm-rounds × 1500 s do not fit the deadline | the fit check moves here or to S2 — the spec decides with S2's budget |
| RESULTS § 13.4 | — | the false `done_o7ref-1` of 2026-10-31 21:43 | the scenario that the stub run must reproduce and refuse |

### Open questions the spec must answer

1. **Fingerprint inputs, exactly.** Model files' identity (what is read, from where — the model sits in a named volume
   that only a container sees — and at what cost); image identity (tag or digest); the mounted patches' sha256 (read
   from `PATCH_DIR`); the generation config; each arm's resolved arguments, env and mounts; the kept-exactly workload
   (lengths, prompts, seeds); `PREFILL_LENS`; the sha256 of `lib/harness.py` and of `bench.sh`. Canonical form and
   hash.
2. **"Names what differs".** The stored form that lets a refused resume print `fingerprint differs: <component>: <old>
   -> <new>`; whether adding an arm to a series is a different experiment or an allowed extension.
3. **The arm-round record.** Directory layout (`rounds/<arm>-<round>/` with bench lines, spec metrics, server log,
   configuration grep, quality files in round 1), the temporary name, the validation (`check-block`, the server alive
   at the end, the quality files present in round 1), the atomic rename, and what a rejected attempt leaves (kept as
   evidence under another name — collected data is append-only).
4. **Reading back.** Whether `bin/r9700 verdict <outdir>` passes each record's bench file to `verdict.py ship` as one
   `--bench` each, and which arm is the base (the first arm of the series, recorded in the fingerprint, or `--base`).
5. **`harness.py` in the container.** The container mounts Windows paths only, so how `lib/harness.py` reaches
   `/work` (a copy into `WORK_DIR` before the series, its sha256 in the fingerprint) and where the quality files land
   before they move into the record.
6. **Unsupported arms.** Tries and pause, how `unsupported` is recorded (append-only) and reported by `verdict`.
7. **Round count.** `series` default 3 rounds; how the one-round acceptance run is invoked and what `verdict` prints for
   it (`--rounds 1`, or INCOMPLETE as designed).
8. **Both example models "run `series` unedited".** A real one-round run with the 27B file on the R9700, or a recorded
   dry run (resolved commands) — the spec chooses, and the acceptance record says which.
9. **Outdir growth.** Confirm the parent's ≈5 MB per 3-arm 3-round series against the record layout, and that nothing
   in the toolkit deletes it.
10. **The stub scenarios** that prove: a server lost mid-bench leaves no record (and the false-marker case of
    2026-10-31); a resume skips exactly the recorded arm-rounds; a changed `MAX_NUM_SEQS` (or a changed patch file)
    refuses the resume with the component named; a container that never becomes ready is retried, then the arm is
    unsupported and the series goes on.

---

## Growth surfaces of these stories

| Surface | Story | Size | Who retires it | Interrupted |
|---|---|---|---|---|
| Test fixtures (tracked) | S1 | ≈0.9 MB once (three prompt files ≈250 KB each; the rest ≈150 KB) | kept; replaced only by a deliberate fixture change | — |
| The test run folder `testsToDelete-<owner>-r9700-run-<id>` | S1 | under 10 MB per run (copies of fixtures, pytest base temp, bash test roots) | removed by the run that made it (`tests/run.mjs`, `finally`) | swept by the next run's start (rule `common.test-leftovers` §4: owner `gone`) |
| Series outdir, containers | S3, S2 | as in the parent's table | as in the parent's table | as in the parent's table |

## Build order

1. Main session: the token precondition (conventions row, release, pin bump here).
2. E1.S1 — Sonnet codes this document's S1 section; Opus reviews; Sonnet fixes.
3. E1.S2 — Fable writes the spec (may start during step 2); Sonnet codes; Opus reviews; Sonnet fixes.
4. E1.S3 — Fable writes the spec after the S2 spec is approved; Sonnet codes; Opus reviews; Sonnet fixes; the
   acceptance run on the R9700 is done by the operator's session and recorded.

## Definition of Done (E1, by story)

- [ ] S1: scenarios 1–45 pass in CI through `node tests/run.mjs`; scenario 46 checked by hand and recorded; the
      static check, the leftovers guard and the plan-lifecycle check are green in CI.
- [ ] S1: the verdict reproduces `fcombo` pass, `fb1` fail, `o7` fail from the fixtures, with the numbers of the
      table above.
- [ ] S1: `research/module_config.md` lists every field (scenario 17); `LICENSE` exists.
- [ ] S2: the guard tests of E1's *Done when* pass in CI with the stubs (spec by Fable).
- [ ] S3: the resume and completion tests pass in CI with the stubs; the acceptance run is recorded in `research/`;
      the README quick start covers `init`, `series`, `verdict` (spec by Fable).
- [ ] Every story: no tracked file holds a personal path, account or machine name; `research/architecture.md` and
      `research/module_tests.md` describe what exists.
