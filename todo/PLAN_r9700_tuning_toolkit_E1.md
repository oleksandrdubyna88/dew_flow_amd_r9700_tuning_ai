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
`## Tokens` table of `common/test-leftovers-detail.md` (since 105d53c; earlier mounts: `common/test-leftovers.md`) in `dew_flow_conventions` (row: `` `r9700` `` · `dew_flow` ·
`the R9700 vLLM tuning toolkit`), released, and this repository's `.agents/conventions` pin is moved to that release.
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
| `tools/lib/owned.mjs`, `tools/lib/git.mjs`, `tools/lib/leftovers-sweep.mjs` (amended 2026-11-01: `tools/lib/`, not `tests/lib/` — the guard scans `tests/` and treats `tools/lib/**` as product code, `leftovers-check.mjs` line 195) | byte-identical copies of the same files under `.agents/conventions/tools/lib/` at the pinned submodule |
| `tools/lib/owned-token.mjs` (amended 2026-11-01, as the row above) | this repository's own token file: `REPO_TOKEN = "r9700"`, `REPO_ROW = "the R9700 vLLM tuning toolkit"` (shape: the header of `.agents/conventions/tools/lib/owned-token.mjs`) |
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
`node .agents/conventions/tools/leftovers-check.mjs --repo . --token r9700 --identity "the R9700 vLLM tuning toolkit" --profile node`
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
node .agents/conventions/tools/leftovers-check.mjs --repo . --token r9700 --identity "the R9700 vLLM tuning toolkit" --profile node
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
`tests/stubs/powershell.exe`, `tests/stubs/pwsh.exe`, `tests/stubs/worker.sh`; `tests/test_lifecycle.sh`, `tests/test_guards.sh`,
`tests/test_adapter.sh`; updates to `research/architecture.md`, `research/module_tests.md`, and — only if a lifecycle
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

### Decisions (the answers to the fifteen questions)

One decision per question of the draft this section replaces, in its order and under its title. Each names its
reason and the option it rejects.

**1. Supervisor and worker.** `bin/r9700` is the supervisor. It runs a step as `setsid <cmd> &` from
`run_guarded` (the shape of `night5.sh` line 19): a background job of a non-interactive shell is not a group
leader, so `setsid` does not fork, and `$!` is both the worker's pid and its process-group id. The supervisor
never calls `setsid` on itself, so it stays in the caller's group; a guard sends `TERM` to `-<pgid>`
(`ram_guard_all.sh` line 12), which can never reach the supervisor. The supervisor traps `INT` and `TERM`:
the handler runs the one cleanup path (§ *The cleanup path* in the brief) with outcome kind `interrupted` and
exits 130 or 143. A `SIGKILL` of the supervisor runs no handler: the kernel frees the lock, the marker stays,
and the worker group may live on. So the marker records the worker's process-group id, the worker's start time
in clock ticks (`/proc/<pid>/stat` field 22) and the machine's `boot_id` (`/proc/sys/kernel/random/boot_id`).
The next invocation stops that group only when a process with that pid exists, the boot id is the same and the
start ticks are equal — the pid is then provably the same process, never a reused pid. Rejected: comparing
wall-clock start times (a stepped clock makes a live worker look foreign) and killing by pid alone (a reused
pid is somebody else's process).

**2. The lock.** `flock -n` on `$R9700_STATE_DIR/lock`; the atomic operation it rests on is the kernel's
`flock(2)`, which a `SIGKILL` releases. The state directory is `${XDG_STATE_HOME:-$HOME/.local/state}/r9700`,
overridable by the environment variable `R9700_STATE_DIR` (the tests set it inside `R9700_TEST_ROOT`). It is
NOT a config field, because the lock and the marker must work when the config is broken (decision 4). After
taking the lock the holder writes one line into the lock file, `<pid> <verb> <UTC time>`; a second invocation
reads that line and refuses at once: `r9700: another run holds <path>: pid <pid>, <verb>, since <time>`,
exit 4. `series` and `init` always take the lock. `verdict` reads records only, so it takes the lock only
when a marker exists (to restore first, decision 4) — then it releases it before reading. `commands` takes
nothing. Rejected: waiting for the lock (an unattended second run would start hours later on a machine whose
state nobody planned), and one lock per outdir (two series on one GPU is the thing the lock forbids).

**3. The recovery marker.** `$R9700_STATE_DIR/recovery.env`, a `KEY=VALUE` file in the config grammar
(bare or double-quoted values, no `$`, no backtick), written with `.part` + `mv` (atomic on one file system).
Keys: `MARKER_VERSION=1`, `RUN_ID`, `WRITTEN_AT` (UTC), `PROD_CONTAINER`, `PROD_WAS_RUNNING` (`yes`|`no`),
`WSLC`, `RESTORE_SHELL`, `RESTORE_SCRIPT_WIN`, `RESTORE_ARGS`, `CONTAINER_PREFIX`, `READY_TIMEOUT_S`,
`WORKER_PGID`, `WORKER_START_TICKS`, `BOOT_ID`. It is written BEFORE the stop of the operator's server
(`speed_A.sh` line 44 and `night7.sh` line 41 stopped it with no record — the fact of the source table) and
rewritten once more when the worker has started, to add the three worker keys. **The worker does no work before
that second write is durable (plan-gate E1 finding 0):** `run_guarded` starts the worker as
`setsid lib/worker_gate.sh <gate file> <cmd…>`; the gate script waits (bounded, 30 s, then exits 4) until
`<gate file>` exists, then `exec`s the command. The supervisor writes the marker with the worker keys
(`.part` + `mv`), then creates the gate file. A `SIGKILL` of the supervisor before the gate file exists leaves a
worker that only waits and then exits 4 by itself — it never touches the GPU or a container; one after it
leaves a marker that names the worker. Scenario L21 kills the supervisor in that window (a test hook
`R9700_TEST_KILL_BEFORE_GATE=1` makes the supervisor `kill -9` itself right after the worker start) and checks:
the worker exits 4 within the ceiling, no stub container call was made, the next invocation restores. It is removed only after the
restore is ready (or, when the server was not running before, after every prefixed container is stopped).
**If the operator's server was not running before the run, the restore does not start it**: a restore puts
the machine back as it was, and starting a server the operator had stopped on purpose loads the GPU behind
their back. The old script always started it (`restore_server.sh` lines 19–21); that was right for one
operator who always runs it, and wrong as a default for a public tool. `init` prints the pre-run state it sees,
so the operator knows which case applies.

**4. Restore-first.** Order of every `series` and `init` invocation: parse the arguments → take the lock →
read the marker and restore if one exists → load and validate the config → run. The restore needs no config:
the marker carries every value it uses (decision 3), so a broken `machine.env` cannot block the restore of a
server the marker describes. A config error after the restore is reported as in S1 (exit 2) — and no
container has been stopped by then except the leftover prefixed ones the restore stops, which belong to the
dead run. The ordering test of the boundaries (no `stop` before the config is refused) holds for a run
without a marker. Rejected: restore after validation (the case the question names) and restore without the
lock (two invocations would restore at once).

**5. Readiness.** Two checks, both through `wslc exec` into `PROD_CONTAINER`, as `wait_ready.sh` line 10
does — the operator's server publishes a port the config does not know, and the loopback port 8000 inside the
container is the one every old script used. Check 1: `GET http://127.0.0.1:8000/v1/models` answers 200 within
5 s. Check 2: `POST /v1/completions` with `{"model": <first id of check 1>, "prompt": "Hi", "max_tokens": 1}`
answers 200 within 60 s. Both are run by the one Python one-liner `restore_probe` of the adapter (one place).
The loop runs every 10 s up to `READY_TIMEOUT_S` (new machine field, integer 60..3600, default 1200 — the
120 × 10 s of `wait_ready.sh` line 6), with the 3-missed-`list` rule of `wait_ready.sh` lines 8–9 (a server
that exited is reported at once). A restore that does not become ready: exit 5, exactly one stderr line
`r9700: restore: <PROD_CONTAINER> not ready after <n> s (<last probe result>)`, the marker KEPT so the next
invocation tries again, and the server left as it is (a second start on top of a loading server is the
worst option). Rejected: the published port (unknown to the toolkit; a change of the operator's start script
would silently break it).

**6. Exit-code contract.** The worker exits: `0` done; `3` the PC is not quiet at a unit start (the
supervisor waits and repeats the same step; not a failed try); `4` the next unit no longer fits before the
deadline (the supervisor ends the step cleanly; not a failed try); any other code is a failed try. The
supervisor never parses worker messages. It reads a typed outcome file, `<run dir>/steps/<n>.outcome`, with
the lines `KIND=<worker|ram_guard|disk_gate|deadline|interrupted>`, `RC=<worker exit code>`, `DETAIL=<one
line>`, `ENDED_AT=<UTC>`: the RAM guard writes `KIND=ram_guard` before it sends `TERM`, the deadline watcher
writes `KIND=deadline`, the signal handler writes `KIND=interrupted`, and `run_guarded` writes `KIND=worker`
after `wait` when no other kind was written first (an exclusive create, `set -o noclobber`, so the first
writer wins). Failed tries are counted together — a worker failure and a RAM stop alike, as `night5.sh` line
41 did — up to `MAX_FAILED_TRIES` (new machine field, integer 1..20, default 6, from `night5.sh` line 36).
The supervisor's exit codes:

| Exit | Meaning | Line on stderr |
|---|---|---|
| 0 | the step is done | — |
| 2 | config or arguments refused (S1's loader, or the argument check) | S1's `config: …` lines |
| 4 | another run holds the lock | `r9700: another run holds …` |
| 5 | the restore did not become ready | `r9700: restore: … not ready after …` |
| 6 | the deadline or `MAX_RUN_MINUTES` stopped the step, or the worker said nothing more fits (worker 4) | `r9700: deadline: step stopped at <time>, <n> units done` |
| 7 | the step failed `MAX_FAILED_TRIES` times | `r9700: step failed <n> times, last: <KIND> <DETAIL>` |
| 8 | the quiet wait or the server-stop budget ended before the step could start (decision 15) | `r9700: not quiet before the deadline` / `r9700: server stopped <n> times, limit …` |
| 9 | the disk gate stopped the run | `r9700: disk gate: <its line>` |
| 10 | `init` found a problem (adapter unreachable, telemetry unreadable, …) | `init: <check>: <problem>` |
| 130 / 143 | interrupted by SIGINT / SIGTERM; cleanup and restore ran | `r9700: interrupted, restored` |

Rejected: distinguishing outcomes by grepping the worker's log (reliability: loop exits are decided on typed
outcomes, never message substrings).

**7. Unreadable telemetry.** The RAM guard reads every 15 s (`ram_guard_all.sh` line 15). A read that is not
an integer (`ram_guard_all.sh` line 9 treated it as fine) is a miss; one miss is one log line; **three misses
in a row** (45 s) are unsafe: the guard stops the step exactly as a low reading does, with
`DETAIL=telemetry unreadable 3 times`. Reason for three, not one: a single PowerShell call failing under load
was seen in the night runs' guard logs, and one such call must not end a night; 45 s without a reading is
longer than any model load takes to push RAM to zero only on a machine already in trouble, so stopping is the
safe side. The quiet check fails closed at once: an unreadable `/proc/loadavg` or a missing `pgrep` means
"not quiet" (it is local and never flaky). The disk gate already treats a failed query as `STOP` (exit 2,
`disk_gate.sh` line 11). Nothing anywhere counts an unreadable value as fine.

**8. Deadline and budget.** At start the supervisor computes `T_END = min(next occurrence of DEADLINE,
now + MAX_RUN_MINUTES × 60)` (when `DEADLINE` is empty, the second term alone) and `T_STOP = T_END −
CLEANUP_BUDGET_S`. It refuses to start when `T_STOP < now + 60` (exit 2, `deadline: only <n> s remain before
the cleanup budget`). The deadline watcher (every 30 s, `night5.sh` lines 21–24) fires at `T_STOP`, not at
`T_END`, so the budget is kept free for the cleanup. Every wait of the step phase — the quiet wait,
`wait_ready`, each `wslc` call — has its own ceiling AND is cut at `T_STOP − now`. The cleanup phase (stop
the worker group, save tails, stop containers, restore, readiness) is bounded by its own ceilings only
(10 s grace per `TERM`, 60 s per `wslc` call, `READY_TIMEOUT_S`), and the budget is sized to hold them: a
cross-field check refuses `CLEANUP_BUDGET_S < READY_TIMEOUT_S + 120`. So S2 changes the S1 default of
`CLEANUP_BUDGET_S` from 900 to 1500 (`READY_TIMEOUT_S` 1200 + 300 for stopping) — a lifecycle field change
S2 is allowed to make, with the loader, the example and `research/module_config.md` updated in S2's commit.
Rejected: a watcher that fires at `T_END` (the night drivers' shape — the deadline then eats the restore) and
cutting the restore at `T_END` (a restore stopped half way is the one failure worse than a late one).

**9. Containers.** Name: `<CONTAINER_PREFIX><label>`, where the label is given by the worker and must match
`^[a-z0-9][a-z0-9-]{0,39}$` (`container_name <label>` refuses anything else); with a 16-character prefix the
name is at most 56 characters. Every listing uses `wslc list --no-trunc` (`wait_ready.sh` line 3 — plain
`list` cuts names near 20 characters), so the length is not a problem. A guard stop and the cleanup find
containers by `wslc_list | grep "^<prefix>"` and stop each with a 60 s ceiling, after saving its log tail
(decision 10) — the log must be read BEFORE `stop`, because `--rm` removes the container with its log.
`init` stops every running prefixed container (every container the toolkit starts is `--rm`, so a stopped one
does not exist); it holds the lock while it does so, so it can never stop a running series' container
(exit 4 instead).

**10. The log tail.** On a guard stop, the deadline or an interrupt, the cleanup saves for EVERY prefixed
container the last 200 lines of `wslc logs <name>` to `<run dir>/guard/<UTC stamp>-<name>.tail.log`, and the
outcome file names the directory. 200 lines hold the vLLM error and its traceback (the longest seen in the
night logs was under 120 lines). Rejected: the whole log (0.3 MB per container; the worker already saves the
whole log into its own record when it ends normally) and only the newest container (a step may have two).

**11. The adapter seam.** `lib/adapter.sh`, sourced; the ONLY file under `lib/` and `bin/` that expands
`$R9700_WSLC`, `$R9700_POWERSHELL` or `$R9700_RESTORE_SHELL` (a static check in `tests/check_static.sh`
greps for it; scenario A6). Functions:

| Function | Does | Ceiling |
|---|---|---|
| `wslc_run <name> <args…>` | `run -d --rm --name <name> <args…>`; prints the last 2 lines, CRs removed (`serve.sh` line 21) | 120 s |
| `wslc_exec <ceiling-s> <name> <cmd…>` | `exec <name> <cmd…>`, CRs removed | the argument |
| `wslc_list` | names from `list --no-trunc`, one per line, CRs removed (`restore_server.sh` line 11) | 60 s |
| `wslc_stop <name>` | `stop <name>`, output discarded | 60 s |
| `wslc_logs <name>` | `logs <name>` (stderr merged), CRs removed | 60 s |
| `win_ram_mb` | prints the integer of `ram_guard_all.sh` line 8; prints nothing and returns 1 when the output is not an integer | 30 s |
| `win_disk_newest` | prints the record id of `disk_gate.sh` line 7; nothing and 1 when not an integer | 60 s |
| `restore_start` | `$R9700_RESTORE_SHELL -NoProfile -File $R9700_RESTORE_SCRIPT_WIN <RESTORE_ARGS words> -Detach` (`restore_server.sh` lines 19–21); prints the last 5 lines | 120 s |
| `restore_probe <name>` | the two readiness checks of decision 5 through `wslc_exec 70`; prints `models`, `completion` or the failing check with the HTTP status | 70 s |

Every call is argv (never a shell string) under `timeout --kill-after=5 <ceiling>`, which kills the child on
expiry (security: a timeout that only stops waiting makes an orphan). A bare `WSLC=wslc` resolves through
`command -v` at the first call; the tests put `tests/stubs` first on `PATH`, the machine's `machine.env`
holds the absolute path when the executable is not on `PATH`. Rejected: fewer functions with a `case` on the
first argument (the stub then has to parse the toolkit's own argument grammar).

**12. The stubs.** `tests/stubs/wslc`, `tests/stubs/powershell.exe`, `tests/stubs/pwsh.exe` are bash scripts.
They read and write only under `$R9700_STUB_DIR` (the test sets it to `$R9700_TEST_ROOT/stub`; a stub with
it unset exits 99 at once, so a stub can never run against a real machine by accident). A test scripts the
answers by writing files BEFORE the call: `answers/ram` (one integer or the word `garbage` per line; call k
takes line k, the last line repeats), `answers/disk` (record ids, same rule), `answers/ready` (one word per
`restore_probe`/`wait_ready` probe: `ok`, `models-only`, `fail`), `answers/bench` (the lines `wslc exec …
vllm bench serve` prints, with the tag inserted by the stub from `--seed` and `--max-concurrency`),
`answers/logs` (what `wslc logs` prints). Every call appends one line `<n> <stub> <argv…>` to `calls.log`
(append-only; the tests assert on it). `wslc run -d --rm --name X …` starts a real detached child,
`setsid sleep 1000` (a container is a process outside the client's group, exactly like the real one), writes
its pid to `containers/X.pid` and appends it to `pids`; `wslc list` prints the names whose pid is alive;
`wslc stop X` kills that pid and removes `containers/X.pid`; `wslc logs X` prints `answers/logs`; `wslc exec
X python3 -c …urlopen…` answers from `answers/ready`. `pwsh.exe -File …` (the restore) creates
`containers/<PROD_CONTAINER>.pid` the same way, so `wslc list` then shows the operator's server. Every test file
ends with `trap` cleanup that kills every pid in `pids` (`kill -0` then `kill`), so no `sleep` outlives the
test; the folder itself is removed by the runner. The worker of the lifecycle tests is
`tests/stubs/worker.sh <mode>` with the modes `ok` (writes `worker.done`, exit 0), `child` (spawns
`sleep 1000`, writes its pid to `child.pid`, then sleeps 1000 itself), `exit3-then-ok` (exit 3 on the first
call, 0 on the second, counted in `worker.calls`), `exit3` (always 3), `exit4`, `fail` (exit 1), `serve`
(calls `serve_start` and `wait_ready` through the real `lib/` functions, so the adapter is exercised end to
end, then sleeps 1000 with the container running).

**13. `init`.** Order: lock → restore-first → config → checks. Checks, one line each on stdout, `init: <check>:
ok` or `init: <check>: <problem>`: the config loads; `RESULTS_DIR` exists or is created (`mkdir -p`); the state
directory is writable; `wslc_list` answers (the adapter is reachable); `win_ram_mb` is readable; when
`DISK_GATE=on`, `win_disk_newest` is readable; `PROD_CONTAINER` running or not (information); leftover
prefixed containers: each one stopped and named. Exit 0 when every check is `ok`, else 10 with the failing
lines also on stderr. `init` creates nothing but `RESULTS_DIR` and the state directory.

**14. The verb list.** `bin/r9700` dispatches to functions `verb_<name>`; `bin/r9700 commands` prints the
names derived from `declare -F` (`verb_` stripped), sorted, one per line — the same derivation S1's
`assert.sh` uses for `t_` functions. `research/module_tests.md` derives its flow catalogue from that output
(scenario-tests rule 4), and a scenario asserts the catalogue and `commands` agree (L18).

**15. Stop only when admitted.** The operator's server is stopped only inside `admit`, which runs after the
quiet wait and the disk gate passed, immediately before the worker starts. The supervisor's quiet wait
(`guard_quiet wait`, at most 900 s — `night5.sh` line 29 — and at most `T_STOP − now`) runs with the server
running. After a worker exit 3 the server is already stopped: the supervisor keeps it stopped for ONE quiet
wait (at most 900 s: the three checks 300 s apart need 600 s at least, so a shorter wait could never admit);
when that wait does not end quiet, the supervisor restores the server (readiness checked, the marker cleared)
and keeps waiting with it running, in quiet waits of 900 s each, until `T_STOP`. Every admission is one stop
of the operator's server; the count per invocation is bounded by `MAX_SERVER_STOPS` (new machine field,
integer 1..10, default 3), because every model load drives Windows available RAM near zero (RESULTS § 6.5).
At the bound the supervisor exits 8 with `r9700: server stopped <n> times, limit MAX_SERVER_STOPS=<n>`.
Rejected: restoring at once after every exit 3 (one stop/start cycle more per exit 3, the cost the question
names) and never restoring while waiting (the 44-minute idle of 2026-11-01 12:03–12:47, with the server down).

**Three new machine fields and one changed default** (S2 updates `lib/config.sh`, `machine.env.example`,
`research/module_config.md` and the S1 scenarios 17–18 keep passing because they derive from `config_keys`):

| Key | Type and legal values | Default | Replaces |
|---|---|---|---|
| `READY_TIMEOUT_S` | integer 60..3480 (amended 2026-11-01: with `CLEANUP_BUDGET_S` ≤ 3600 and ≥ ready + 120, 3481..3600 could never pass) | `1200` | `wait_ready.sh` line 6 (120 × 10 s); `serve.sh` line 3 |
| `MAX_FAILED_TRIES` | integer 1..20 | `6` | `night5.sh` line 36 |
| `MAX_SERVER_STOPS` | integer 1..10 | `3` | new (decision 15) |
| `CLEANUP_BUDGET_S` | unchanged type; cross-field `≥ READY_TIMEOUT_S + 120` | `1500` (was 900) | decision 8 |

**Amendments from the cadence consultation of 2026-11-01 (epics 1–3), each checked against this text.** They
override the decisions and the brief where they differ.

- **A1 — the lock stays with the supervisor.** `flock` holds while ANY process has the open file description,
  and a child started after `exec 9>lock` inherits descriptor 9: after a `SIGKILL` of the supervisor the worker
  would keep the lock and the recovery would refuse with exit 4. Every child the supervisor starts (worker,
  `guard_ram`, the deadline watcher, `restore_start`) is started with `9>&-`. Scenario L6 adds: before the kill,
  `/proc/<worker pid>/fd/9` does not exist; after it, `flock -n` on the lock file succeeds.
- **A2 — one start form.** The worker is started only as `setsid lib/worker_gate.sh <gate file> "$@" 9>&-`
  (decision 3); the ungated `setsid "$@"` in the brief's `admit` is replaced by it.
- **A3 — tests do not wait on real quiet rounds.** `quiet_wait` reads a test knob `R9700_QUIET_CHECKS` (default
  3; never in `machine.env`); the lifecycle and guard tests set it to 1, and a test that triggers a fault first
  waits for a worker-ready file the stub worker writes (`<run dir>/steps/<n>.ready`), never for a fixed time.
  The deadline arithmetic (`deadline_compute`, `T_STOP`, `T_END`) is tested as pure functions; G5 keeps one
  integration case whose timings follow from `R9700_QUIET_CHECKS=1`.
- **A4 — stub containers are cleaned by their owner, not by a process group.** The stubs' `setsid sleep`
  children are outside every group by design. Each records its pid in `R9700_TEST_ROOT/containers/<name>.pid`;
  every bash test's `EXIT` trap kills the recorded pids, and `tests/run.mjs` kills every pid recorded under its
  run folder in its own `finally` (also after a test hit its ceiling) before it removes the folder.
- **A5 — one supervisor, several steps (the contract E3 builds on).** `run_guarded` is split: `step_run <label>
  -- <cmd…>` runs one step (admission, worker, guards, outcome, retries) and neither restores nor releases the
  lock; `supervise <body function>` takes the lock, restores first, runs the body, and ends with the one
  `cleanup_once` (one restore). `verb_step` is `supervise` around one `step_run`; E3's `run` is `supervise`
  around several `step_run` calls, so the server is restored once at the end, and between steps only by the
  wait rule of decision 15. Scenario L22: a body with two `step_run` calls restores exactly once.
- **A6 — S2 is built and reviewed in three parts**, each an Opus review before the next: (a) the adapter seam
  and the stubs (A4); (b) ownership and recovery — lock (A1), marker, worker gate (A2), restore, readiness,
  restore-first; (c) guards, admission, retries and `supervise`/`step_run` (A3, A5). One coai code round still
  covers the whole epic.
- **A7 — a hosted remote before S1 merges.** CI needs the GitHub repository; creating it and the first push
  (whose exact file list the operator approves first — the repository is public) is a main-session
  precondition beside the token registration. Publication acceptance stays in E3.

**Amendments from the review of part (a), 2026-11-01** (each reproduced by the reviewer):

- **A8 — stop by SESSION, not by process group.** GNU `timeout` calls `setpgid(0,0)`, so every adapter call runs
  in its own process group inside the caller's session: a `TERM` to the worker's group does not reach a running
  `wslc exec … bench` (up to its 1800 s ceiling). The worker is started with `setsid`, so its sid = pgid = pid;
  `guard_ram`, the deadline watcher, `cleanup_once` and `restore_from_marker` stop every process whose
  `/proc/<pid>/stat` field 6 equals that sid (`TERM`, the grace, then `KILL`); the test runner does the same for a
  test file's session. Never `timeout --foreground` (it does not kill the child's children on expiry). A G1
  variant: the guard fires while the worker sits in a hung adapter call; afterwards no process of the session
  is left.
- **A9 — adapter calls are cut at `T_STOP`.** `_adapter_call` uses `min(ceiling, R9700_T_STOP − now)` when
  `R9700_T_STOP` is set and refuses with an `adapter:` line when that is ≤ 0; the supervisor's cleanup phase runs
  without `R9700_T_STOP` in its environment (decision 8).
- **A10 — a ceiling scale apart from the time scale.** `R9700_CEILING_SCALE` (test knob, default
  `R9700_TIME_SCALE`) divides only the adapter ceilings; lifecycle and guard tests set it to 10 while sleeps run
  at 100, and only the hang tests use 100 (measured: a stub call takes 39 ms idle, up to 227 ms under load,
  against a 0.30 s RAM ceiling at scale 100).
- **A11 — the test runner runs only `t_*` functions defined in the test file itself** (`declare -F` under
  `extdebug`, enabled only inside the lookup, paths compared with `readlink -f`), so a sourced library function
  such as `t_scale` is never run as a test.
- **A12 — the supervisor's own calls leave no grandchild (part (b)).** GNU `timeout --kill-after` KILLs only its
  direct child, and A8's session kill does not cover the supervisor's own adapter calls (`restore_start`,
  `restore_probe`, `container_stop_all`, `init`), which run in the caller's session. `_adapter_call` starts
  `timeout` in the background, keeps its pid (= the pgid of the call, which cannot be reused while a member of
  that group lives), waits, and after rc 124 or 137 sends `kill -KILL -- -<timeout pid>` to that group. A test
  runs a supervisor-side call against the stub mode `hang-ignore-term` with a TERM-ignoring grandchild and
  checks that no process of the call's group is left. Part (c)'s G1 variant uses the same stub mode for the
  worker side (A8).

### Test scenarios

Three bash files, run by `tests/run.mjs` like S1's: `tests/test_lifecycle.sh` (L1–L20), `tests/test_guards.sh`
(G1–G14), `tests/test_adapter.sh` (A1–A8). Test names state the guarantee. Every test:

- puts `$REPO/tests/stubs` first on `PATH`; sets `R9700_STATE_DIR=$R9700_TEST_ROOT/state`,
  `R9700_STUB_DIR=$R9700_TEST_ROOT/stub`, `R9700_TIME_SCALE=100` (every sleep and ceiling in `lib/` is divided
  by it — § *Time* in the brief — so 1200 s becomes 12 s and 15 s becomes 0.15 s);
- writes the S1 machine fixture into its root (`@ROOT@` replaced) and uses `models/qwen3.6-35b-a3b-gptq.env`
  unedited; "the config" below is that pair;
- runs `bin/r9700` through `assert_exit`, so `$OUT`/`$ERR` hold its output; "the call log" is
  `$R9700_STUB_DIR/calls.log`; "the marker" is `$R9700_STATE_DIR/recovery.env`; "the run dir" is the one
  directory under `$RESULTS_DIR/runs/`;
- starts with `answers/ram` = `8000`, `answers/disk` = `100`, `answers/ready` = `ok`, and
  `containers/vllm.pid` present (the operator's server runs) unless the scenario says otherwise;
- ends with the stub `trap`: every pid in `$R9700_STUB_DIR/pids` and in `child.pid` is killed when alive.

Leftovers: every file is under `R9700_TEST_ROOT`, which the runner's `testsToDelete-<owner>-r9700-run-<id>`
folder holds; no `mktemp`, no `TMPDIR`; the stubs' `sleep` children are killed by the test's trap and, were
the test killed, die with the runner's process group (the runner kills the child's group at its ceiling).
The token `r9700` is the one the vendored helper uses; its registration in the shared `## Tokens` table is
the precondition the main session owns (*Facts every story uses*).

The step verb of these tests is `bin/r9700 step <label> -- <cmd…>` — a verb that runs one guarded step and is
the thing `series` (S3) is built on. It is listed by `commands` and is part of the product (E3's `run`
driver uses it too), not a test-only door.

**Lifecycle (`tests/test_lifecycle.sh`)**

1. *The config is refused before any server is stopped.* Given a machine variant with `DISK_GATE=maybe`; when
   `bin/r9700 step t -- worker.sh ok` runs; then exit 2, stderr has one `config: ` line naming `DISK_GATE`, the
   call log has no line containing ` stop `, and `containers/vllm.pid` still exists. (Positive companion: L2.)
2. *A step stops the server once, runs the worker, restores once, and the marker is gone.* `step t -- worker.sh
   ok`: exit 0; `worker.done` exists; the call log has exactly one `wslc stop vllm` and exactly one `pwsh.exe …
   -File C:\r9700\start-vllm.ps1 … -Detach` line, in this order: `stop vllm` before `worker.done`'s mtime, the
   `pwsh.exe` line after it; `containers/vllm.pid` exists again; the marker does not exist; the outcome file
   `steps/1.outcome` holds `KIND=worker` and `RC=0`.
3. *The marker is written before the stop and carries what the restore needs.* Worker mode `child`, with
   `answers/ram` = `8000` then `100` (the guard fires on the second read): the marker read from the run dir's
   copy `steps/1.marker` (the supervisor copies the marker into the run dir at admission — evidence) has
   `PROD_WAS_RUNNING=yes`, `RESTORE_SCRIPT_WIN=C:\r9700\start-vllm.ps1`, `RESTORE_ARGS` equal to the fixture's,
   `WSLC=wslc`, `CONTAINER_PREFIX=r9700tune-`; and its mtime is before the `stop vllm` line's stamp in the call
   log (the stub stamps every line with `date +%s.%N`).
4. *A restore that never becomes ready exits 5 with one stderr line and keeps the marker.* `answers/ready` =
   `fail`; `step t -- worker.sh ok`: exit 5; stderr has exactly one line, matching `^r9700: restore: vllm not
   ready after [0-9]+ s \(`; the marker exists; the call log has exactly one `pwsh.exe` line (no second start).
5. *A server that answers `/v1/models` but not a completion is not ready.* `answers/ready` = `models-only`:
   exit 5, the stderr line ends with `(completion: HTTP 500)`.
6. *A hard kill of the supervisor leaves the marker, and the next invocation of any verb restores first.*
   Start `bin/r9700 step t -- worker.sh child` in the background; wait until `child.pid` exists; `kill -9` the
   supervisor's pid; then the marker exists with `WORKER_PGID` equal to the worker's pid and `BOOT_ID` equal to
   `/proc/sys/kernel/random/boot_id`; the worker and its child are still alive (the kill did not reach them).
   Then run `bin/r9700 verdict $R9700_TEST_ROOT/nodir` (a verb that only reads): its first stdout line is
   `r9700: recovery marker found (run <id>), restoring first`; after it the worker's pid and `child.pid` are
   dead, `containers/vllm.pid` exists, the marker is gone, the call log shows `pwsh.exe` once; `verdict`'s own
   exit is 2 (`nodir` is not an outdir), which proves the restore ran before the verb's own argument check.
7. *A marker whose worker pid was reused is not killed.* Write a marker by hand with `WORKER_PGID` = the pid of
   a `sleep 1000` the test starts, `WORKER_START_TICKS=1` (not that process's start) and the real boot id; run
   `bin/r9700 init`; then the `sleep` is still alive (`kill -0`), the restore ran, the marker is gone.
8. *A second invocation is refused while the lock is held, naming the holder.* Start `step t -- worker.sh
   child` in the background; after `child.pid` exists, run `bin/r9700 init`: exit 4; stderr `r9700: another
   run holds <state>/lock: pid <pid>, step, since <time>` with `<pid>` the background supervisor's pid; the call
   log gained no `stop` line from the second invocation. Then `kill -TERM` the supervisor: it exits 143, the
   child is dead, `pwsh.exe` was called once, the marker is gone.
9. *`verdict` takes the lock only to restore.* Two halves. (a) A marker present (written by hand from the L3
   copy) and the lock held by the test itself (`flock` on the lock file in a background subshell): `verdict
   <dir>` exits 4 (it must restore first and cannot). (b) No marker and the lock held the same way: `verdict
   <empty dir>` reaches its own argument check — exit 2 with a line naming the directory — and never exit 4.
10. *A server that was not running is not started by the restore.* Remove `containers/vllm.pid` before the
    step: `step t -- worker.sh ok` exits 0; the marker copy has `PROD_WAS_RUNNING=no`; the call log has no
    `stop vllm` and no `pwsh.exe` line; the marker is gone at the end.
11. *The worker's exit 3 is waited out and the same step repeats; it is not a failed try.* Worker
    `exit3-then-ok`, `answers/load` (a stub-free input: the quiet check reads `R9700_LOADAVG_FILE` when set,
    which the test points at its own file) first `9.0 …` then `0.5 …` after the first quiet-wait tick: exit 0;
    `worker.calls` = 2; `steps/1.outcome` has `KIND=worker RC=3`, `steps/2.outcome` has `RC=0`; stdout has
    `not quiet at a unit start, waiting` and no `failed try`; the server was stopped once (one `stop vllm`), the
    marker is gone.
12. *After an exit 3 the server is restored while a long wait goes on, and the stops are bounded.* Variant
    `DEADLINE` empty, `MAX_RUN_MINUTES=30`, `CLEANUP_BUDGET_S=600`, `READY_TIMEOUT_S=60` (with scale 100:
    `T_END` 18 s, `T_STOP` 12 s); the load file quiet at start; worker `exit3` (always 3); the test's helper
    writes `9.0` into the load file as soon as `steps/1.outcome` exists. Then: the server-stopped quiet wait
    (900 s / 100 = 9 s) does not end quiet; the call log shows `pwsh.exe` (the restore while waiting) and the
    marker is gone at that moment; the wait goes on with the server running until `T_STOP`: exit 8, stderr
    `r9700: not quiet before the deadline`, `containers/vllm.pid` exists, exactly one `stop vllm` and one
    `pwsh.exe` in the log, the whole call under 14 s. Second half: a variant with `MAX_SERVER_STOPS=1`, the
    load file quiet throughout, worker `exit3`: after the first admission and exit 3 the next admission is
    refused — exit 8, stderr `r9700: server stopped 1 times, limit MAX_SERVER_STOPS=1`, `pwsh.exe` once.
13. *A failing worker is retried up to MAX_FAILED_TRIES, then exit 7.* Variant `MAX_FAILED_TRIES=2`, worker
    `fail`: exit 7; stderr `r9700: step failed 2 times, last: worker 1`; two outcome files, both `KIND=worker
    RC=1`; `pwsh.exe` once; the marker is gone.
14. *Worker exit 4 ends the step cleanly as a deadline.* Worker `exit4`: exit 6, stderr begins `r9700:
    deadline: step stopped`, one outcome file `KIND=worker RC=4`, restore once, marker gone.
15. *`init` reports every check and stops leftover prefixed containers.* Create `containers/r9700tune-old.pid`
    (a stub container) and a foreign `containers/other-x.pid`: `bin/r9700 init` exits 0; stdout has the lines
    `init: config: ok`, `init: results dir: ok`, `init: state dir: ok`, `init: wslc: ok`, `init: ram telemetry:
    ok (8000 MB)`, `init: disk telemetry: ok (record 100)`, `init: vllm: running`, `init: leftover containers:
    stopped r9700tune-old`; the call log has `stop r9700tune-old` and no `stop other-x`; `other-x`'s pid is
    alive.
16. *`init` fails loudly when the adapter is unreachable.* `PATH` without the stubs directory and
    `WSLC=/nonexistent/wslc` in the variant: exit 10; stdout has `init: wslc: ` followed by a problem; the same
    line is on stderr.
17. *`init` finds unreadable telemetry.* `answers/ram` = `garbage`: exit 10, line `init: ram telemetry:
    unreadable ("garbage")`.
18. *The verb list is derived, and the catalogue matches it.* `bin/r9700 commands` prints, one per line and
    sorted, exactly the names of the `verb_*` functions found by `grep -oE '^verb_[a-z]+\(\)' bin/r9700`; and
    every name appears as a row in the flow catalogue of `research/module_tests.md` (parsed from the markdown),
    and every catalogue row of kind `verb` is in that output.
19. *The run dir and the outcome are the durable status.* After L2, `<run dir>/status` holds `done` and
    `<run dir>/supervisor.log` has the lines `admitted`, `worker ended rc=0`, `restored`, in this order; after
    L4 it holds `restore-failed`.
20. *An unknown verb or a bad label is refused.* `bin/r9700 nosuch`: exit 2, stderr `r9700: unknown verb
    "nosuch"; legal:` followed by the `commands` list. `step 'Bad Label' -- true`: exit 2, stderr names
    `^[a-z0-9][a-z0-9-]{0,39}$`.

**Guards (`tests/test_guards.sh`)**

1. *A RAM stop leaves no process of the worker group.* Worker `child`; `answers/ram` = `8000`, `100`: the
   supervisor exits 7 after `MAX_FAILED_TRIES=1` (variant); when it has exited, `kill -0 $(cat child.pid)`
   fails and the worker's own pid is dead; the outcome has `KIND=ram_guard` and `DETAIL=available 100 MB <
   2048 MB`; `pwsh.exe` once; the marker is gone. (This is the 2026-10-31 21:43 failure, RESULTS § 13.4.)
2. *A RAM stop stops every prefixed container and saves its log tail first.* Worker `serve` (it starts
   `r9700tune-t-1` through the stub), `answers/ram` = ten lines `8000` then `100` (the container is up well
   before the eleventh read at 1.5 s), `answers/logs` = 300 numbered lines: after the stop, `containers/r9700tune-t-1.pid` is gone and its pid dead; `<run dir>/guard/` holds one
   file matching `*-r9700tune-t-1.tail.log` with exactly 200 lines, the last being line 300; in the call log
   the `logs r9700tune-t-1` line precedes the `stop r9700tune-t-1` line.
3. *Unreadable telemetry is unsafe after three misses, and one miss is not.* `answers/ram` = `8000`,
   `garbage`, `8000`, `garbage`, `garbage`, `garbage`, worker `child`, `MAX_FAILED_TRIES=1`: the step is stopped
   on the sixth read; the outcome has `DETAIL=telemetry unreadable 3 times`; the guard log
   (`<run dir>/steps/1.ram_guard.log`) has a line `telemetry unreadable (1 of 3)` after the second read and the
   worker was still alive then (the worker writes a heartbeat file every 0.1 s; its mtime is after that line).
4. *A reading exactly at the limit is fine; one below is not.* `answers/ram` = `2048` forever with worker
   `ok`: exit 0. `answers/ram` = `2047`: the step is stopped (`KIND=ram_guard`).
5. *The deadline stops the step and keeps the cleanup budget.* "The short variant": `DEADLINE` empty,
   `MAX_RUN_MINUTES=10`, `CLEANUP_BUDGET_S=360`, `READY_TIMEOUT_S=60` (the cross-field check of decision 8
   holds: 360 ≥ 60 + 120). With it and worker `child`: with scale 100, `T_STOP` = 2.4 s after start; the worker group is
   dead by 3 s; exit 6; the outcome `KIND=deadline`; the restore ran (`pwsh.exe` once) and the whole invocation
   ended before `T_END` (6 s) — asserted with `date +%s.%N` around the call.
6. *A deadline that leaves no room is refused before anything is stopped.* Variant `MAX_RUN_MINUTES=10`,
   `CLEANUP_BUDGET_S=3600`: exit 2, stderr `deadline: only -3000 s remain before the cleanup budget` (the
   number is computed, the sign shows the shape), no `stop` in the call log.
7. *`DEADLINE` as a clock time is the next occurrence.* Variant `DEADLINE=<now + 2 min, HH:MM>` and
   `MAX_RUN_MINUTES=2880`: `T_END` printed by `bin/r9700 step --show-deadline t` is within 120 s of now;
   `DEADLINE=<now − 2 min>`: `T_END` is within 24 h − 120 s.
8. *The quiet wait is bounded by the deadline, not by its own loop.* Load file `9.0`, the short variant of G5,
   worker `ok`: exit 8 within 4 s (`T_STOP` 2.4 s + one tick);
   no `stop vllm` (never admitted); `pwsh.exe` never called (the server was never stopped).
9. *The quiet check needs three quiet reads in a row.* Load file sequence through
   `R9700_LOADAVG_FILE` rewritten by a helper every tick: `0.5`, `0.5`, `9.0`, `0.5`, `0.5`, `0.5`: the
   supervisor log shows `quiet-checks=2/3` then `0/3` then `3/3`, and admission happens after the sixth read,
   not the third.
10. *A busy process blocks admission, and the ignore pattern excludes.* The short variant of G5 plus
    `QUIET_BUSY_PATTERN=r9700-busy-marker`, `QUIET_BUSY_IGNORE=keep-awake`: the test starts `sleep 1000` under
    the name `r9700-busy-marker` (`exec -a`) — admission waits (exit 8 at `T_STOP`); the same with a process
    whose command line also holds `keep-awake` — admitted (exit 0).
11. *An unreadable load is not quiet.* The short variant of G5 and `R9700_LOADAVG_FILE` pointing at a missing
    file: the supervisor log has `load unreadable: not quiet`, exit 8 at `T_STOP`, no `stop vllm`.
12. *The disk gate stops the run on a new event or a failed query, and passes on none.* `answers/disk` = `100`
    (baseline at admission), then `101`: the worker `serve` calls `disk_gate check` before its unit (through
    the worker's env `R9700_RUN_DIR`) — the step is stopped with `KIND=disk_gate`, exit 9, stderr `r9700: disk
    gate: STOP: new disk event (record 101 > baseline 100)`. `answers/disk` = `100`, `` (empty line): exit 9
    with `STOP: query failed`. `100`, `100`: exit 0. `DISK_GATE=off`: no `Get-WinEvent` in the call log.
13. *Every wait has a ceiling: a hung adapter call is killed.* Stub mode file `hang` (the stub sleeps 1000 on
    `list`): `bin/r9700 init` ends within 60 s / 100 + 1 s, exit 10, line `init: wslc: timeout after 1 s`; no
    stub process is alive afterwards (the `timeout --kill-after` killed it; checked through `pids`).
14. *`wait_ready` reports an exited server after three missed listings and a ready one at once.* Through the
    `serve` worker: `answers/ready` = `fail` and the test kills the container's pid after the first probe —
    the worker's `serve_start` returns 1 with `SERVER EXITED` in its log within 3 probes; with `answers/ready` =
    `ok` it returns 0 and `<run dir>/…/server.log` equals `answers/logs`.

**Adapter and stubs (`tests/test_adapter.sh`)**

1. *The stub refuses to run without a stub directory.* `env -u R9700_STUB_DIR wslc list`: exit 99, stderr
   `stub: R9700_STUB_DIR unset`.
2. *`wslc_run` starts a detached process that outlives its caller.* `source lib/adapter.sh; wslc_run
   r9700tune-a img sleep` in a subshell that exits: afterwards `containers/r9700tune-a.pid` names a live process
   whose process group is not the test's; `wslc_list` prints `r9700tune-a`; `wslc_stop r9700tune-a` kills it and
   `wslc_list` prints nothing.
3. *CRs are removed everywhere.* The stub's `answers/logs` with CRLF endings: `wslc_logs` output has no `\r`;
   the same for `wslc_list` and `win_ram_mb`.
4. *`win_ram_mb` prints nothing and returns 1 on garbage, and the integer otherwise.* `answers/ram` =
   `garbage` → empty output, rc 1; ` 8000 ` (with spaces and a CR) → `8000`, rc 0.
5. *`restore_start` passes the configured script and arguments as argv.* After `restore_start`, the call log's
   `pwsh.exe` line is exactly `-NoProfile -File C:\r9700\start-vllm.ps1 -Model /root/.cache/huggingface/local/
   Qwen3.6-35B-A3B-GPTQ -ServedName qwen3.6-35b-a3b -MaxModelLen 131072 -MaxNumSeqs 4 -Detach` (one argument
   per word; the stub prints argv with `printf '%s\n'` and the test compares the array).
6. *Only the adapter names the executables (the seam is one place).* `grep -lE '\$\{?R9700_(WSLC|POWERSHELL|
   RESTORE_SHELL)' lib/*.sh bin/*` (expansions, not names) prints exactly `lib/adapter.sh` (amended 2026-11-01: the loader builds
   the names as `R9700_$key`, so a literal grep would need a comment to match — a structural check is not met by a comment)
   — run through `tests/check_static.sh --seam`; its companion: the same grep over `lib/adapter.sh` alone finds
   at least three hits (the scan is alive).
7. *A bare command resolves on `PATH`, an absolute path as given.* `WSLC=wslc` with the stubs first on `PATH`:
   `wslc_list` calls `tests/stubs/wslc` (the call log says so — the stub writes `$0`); `WSLC=$R9700_TEST_ROOT/
   bin/wslc` (a copy of the stub) calls that copy.
8. *`serve_start` builds the measured container command.* `serve_start r9700tune-t-1 <log> -e A=1 -v
   C/auto_gptq.py:/opt/x.py:ro -- --speculative-config.method mtp`: the call log's `run` line holds, in order,
   `-d --rm --name r9700tune-t-1 --gpus all --shm-size 16g -e HIP_VISIBLE_DEVICES=0 -e
   TRITON_CACHE_DIR=/root/.cache/vllm/triton -e PYTHONPYCACHEPREFIX=/tmp/pyc-fresh -e PYTHONDONTWRITEBYTECODE=1
   -e A=1 -v hf-cache:/root/.cache/huggingface -v vllm-cache:/root/.cache/vllm -v C:\r9700\work:/work -v
   C:\r9700\genconfig:/genconfig:ro -v C:\r9700\patches\C\auto_gptq.py:/opt/x.py:ro
   rocm/vllm:rocm10.1.0_ubuntu24.04_py3.14-pytorch_2.13.0_vllm-0.29.0 vllm serve
   /root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ --served-model-name qwen3.6-35b-a3b --host 0.0.0.0 --port
   8000 --max-model-len 131072 --gpu-memory-utilization 0.85 --max-num-seqs 4 --generation-config /genconfig
   --limit-mm-per-prompt.image 0 --limit-mm-per-prompt.video 0 --speculative-config.method mtp` (the parity check
   against `serve.sh` lines 17–21 and `speed_A.sh` line 28; the values come from the fixture, and `--generation-
   config /genconfig` is added by `serve_start` for every arm). `bench_run r9700tune-t-1 fcombo-2` with
   `answers/bench` = the 18 decode lines of fixture lines 175–192 without their tag: the output equals those 18
   lines exactly (tag, `c=`, `r=` and the trailing spaces as the stub reproduces them), and the six `exec` lines
   in the call log carry `--num-prompts 6 --max-concurrency 1` ×3 then `--num-prompts 12 --max-concurrency 4` ×3
   with `--seed 1 2 3`, `--random-input-len 1024 --random-output-len 512 --ignore-eos` (`bench.sh` lines 5–10).

### Brief for the Sonnet coder

Read first: this section whole; the S1 section's brief (the loader's functions, `assert.sh`, the runner, the
machine fixture); the parent's *Lifecycle and recovery* paragraph; `.agents/conventions/common/reliability.md`
(*Every wait has a ceiling*, *A timed-out child process is a killed child process*, *Before designing a lock*);
`common/test-leftovers.md` §2–§4. The source scripts are given to you by the main session; the line numbers in
this section are theirs. Do not read or change anything about the series, records or the fingerprint (S3).

**Files.** `bin/r9700`; `lib/adapter.sh`, `lib/run_guarded.sh`, `lib/serve.sh`, `lib/wait_ready.sh`,
`lib/bench.sh`, `lib/restore.sh`, `lib/guard_ram.sh`, `lib/guard_quiet.sh`, `lib/disk_gate.sh` — all sourced
function files (`set -u` safe, no `set -e`, nothing runs at source time); `tests/stubs/wslc`,
`tests/stubs/powershell.exe`, `tests/stubs/pwsh.exe`, `tests/stubs/worker.sh`; `tests/test_lifecycle.sh`,
`tests/test_guards.sh`, `tests/test_adapter.sh`; `tests/check_static.sh` gains `--seam` (A6); `lib/config.sh`,
`machine.env.example`, `research/module_config.md` gain the three fields and the changed default of decision 8;
`research/architecture.md` and `research/module_tests.md` gain S2's modules and flows. Nothing in any file names
a model, a machine, a person or a path outside the repository (the static check runs over your files too).

**Time (every sleep and ceiling in one place).** `lib/run_guarded.sh` defines `t_scale <seconds>`: prints
`<seconds> / R9700_TIME_SCALE` (default 1; a positive integer, refused otherwise) with two decimals through
`awk`. EVERY `sleep` and every `timeout` in `lib/` goes through it — `sleep "$(t_scale 15)"`,
`timeout --kill-after="$(t_scale 5)" "$(t_scale 60)"`. The production values are the literals of the sources:
15 s between RAM reads (`ram_guard_all.sh` line 15), 300 s between quiet checks and 3 checks (`wait_quiet.sh`
lines 6, 11), 900 s per quiet wait (`night5.sh` line 29), 10 s between readiness probes (`wait_ready.sh` line
11), 30 s between deadline checks (`night5.sh` line 23), 10 s of `TERM` grace before `KILL`, 60 s after a
container stop before the next unit is not kept (the worker owns its pauses). `R9700_TIME_SCALE` and
`R9700_LOADAVG_FILE` (default `/proc/loadavg`) are test knobs read from the environment, documented in
`research/module_tests.md` under *test knobs*, never in `module_config.md`, never in `machine.env`.

**1. `lib/adapter.sh`** — the table of decision 11, exactly those names and ceilings. Shape of every function:

```bash
wslc_stop() { timeout --kill-after="$(t_scale 5)" "$(t_scale 60)" "$(adapter_exe "$R9700_WSLC")" stop "$1" >/dev/null 2>&1; }
```

`adapter_exe <value>`: an absolute path is printed as is; a bare name goes through `command -v`, and a miss is
an error line `adapter: <name> not found on PATH` with return 10. `wslc_list` is `list --no-trunc`, CRs removed,
`awk 'NR>1{print $NF}'` (`restore_server.sh` line 11). `win_ram_mb` runs the exact PowerShell command of
`ram_guard_all.sh` line 8 through `$R9700_POWERSHELL -NoProfile -Command <string>` (one argv element for the
command string, as the source) and prints only when the result matches `^[0-9]+$`. `win_disk_newest` the same
with `disk_gate.sh` line 7. `restore_start` is `restore_server.sh` lines 18–21 with the config values (`read -r
-a extra <<< "$R9700_RESTORE_ARGS"` for the word split, as line 18). `restore_probe <name>` runs, through
`wslc_exec 70 <name> python3 -c <program>`, one Python program that does check 1 then check 2 of decision 5 and
prints `models`, then `completion`, or `<check>: HTTP <status>` / `<check>: <exception class>` and exits 1.
The program text is one string constant in the adapter. Nothing in this file reads a config file; it reads
`R9700_*` variables only.

**2. `lib/guard_ram.sh`** — `guard_ram <worker pgid> <min mb> <outcome file> <log>`: the loop of
`ram_guard_all.sh` lines 7–16 with `win_ram_mb` (line 8), the miss counter of decision 7, `container_stop_all`
(below) in place of line 11, `TERM` to `-<pgid>` as line 12, then exit 1. Before the `kill`, it writes the
outcome file with `KIND=ram_guard`, `RC=`, `DETAIL=available <mb> MB < <min> MB` or `DETAIL=telemetry unreadable
3 times`, `ENDED_AT=<UTC>` — through `outcome_write`, which uses `set -o noclobber` so a file already written
by another party is left as it is. A log line every 20 reads as line 14, and `telemetry unreadable (<k> of 3)`
per miss.

**3. `lib/guard_quiet.sh`** — `quiet_check`: prints `coai-exp processes=<n> load=<l>` as `wait_quiet.sh` line 10
but with the configured pattern (`pgrep -f "$R9700_QUIET_BUSY_PATTERN"`, skipped when empty; a match whose
`/proc/<pid>/cmdline` holds `R9700_QUIET_BUSY_IGNORE` is not counted — lines 7–9), the load from
`R9700_LOADAVG_FILE` (line 8), returns 0 when quiet; an unreadable file or a missing `pgrep` prints `load
unreadable: not quiet` and returns 1. `quiet_wait <ceiling-s>`: the loop of lines 6–12 (3 quiet checks in a row,
300 s apart) bounded by the ceiling; returns 0 quiet, 1 ceiling reached. The worker-side check of
`speed_A.sh` lines 51–55 is `quiet_check` too (S3 calls it; the exit 3 is S3's).

**4. `lib/disk_gate.sh`** — `disk_gate_baseline <state file>`, `disk_gate_check <state file>`: `disk_gate.sh`
lines 6–18 with `win_disk_newest` and the state file under the run dir (`<run dir>/disk_gate.state`), never
beside the script (line 5 goes). `decide` stays a pure function with the four cases of lines 11–14 and their
exact strings; the `selftest` of lines 19–24 becomes four assertions in `tests/test_guards.sh` (G12 covers the
live path). When `DISK_GATE=off`, both functions print `disk gate off` and return 0 without a call.

**5. `lib/serve.sh`, `lib/wait_ready.sh`, `lib/bench.sh`.** `serve_start <name> <log> [-e K=V]… [-v
<rel>:<dst>[:ro]]… -- <serve args…>`: builds the argv of `serve.sh` lines 17–21 from config — the fixed env
(line 17–18), the volumes of line 10 with `R9700_WORK_DIR_WIN`, `-v "$R9700_GENCONFIG_WIN:/genconfig:ro"`
(line 12, always), then the model's `R9700_MOUNTS` and the given `-v` mounts, each source turned into
`R9700_PATCH_DIR_WIN\<rel with / replaced by \>`; the serve line (19–21) with `R9700_MODEL_DIR`,
`R9700_SERVED_NAME`, `R9700_MAX_MODEL_LEN`, `R9700_GPU_MEM_UTIL`, `R9700_MAX_NUM_SEQS`, `--generation-config
/genconfig` (`speed_A.sh` line 28, for every arm), `R9700_EXTRA_SERVE_ARGS` split on spaces, then the given
serve args. It calls `wslc_run`, then `wait_ready <name> <log>` and returns its code. `wait_ready`: lines 6–13
with `wslc_list` and `restore_probe`'s check 1 only (a Python one-liner constant, `wait_ready.sh` line 10),
every 10 s up to `R9700_READY_TIMEOUT_S` and `T_STOP`; 3 misses = `SERVER EXITED`, return 1; ready = `READY
(waited <n> s here)`, return 0; always saves the log through `wslc_logs` (line 13). No heartbeat file (line 7
goes; the supervisor is the heartbeat). `bench_run <name> <tag>`: lines 5–10 with `wslc_exec 1800`,
`R9700_SERVED_NAME`, `R9700_MODEL_DIR`; every other literal stays (random 1024/512, 6 and 12 prompts, seeds 1–3,
the three greps, the `sed` prefix). The tee into a shared file (`speed_A.sh` line 72) is NOT here: `bench_run`
prints, the caller decides where the lines go.

**6. `lib/restore.sh`** — `restore_from_marker <marker file> <run dir>`: reads the marker with the config
grammar (`marker_read`, one regex, refuses `$` and backtick, unknown keys refused — return 2 with `marker:
<file>:<line>: …`); kills the worker group when `WORKER_PGID` is set and provably the same process (decision
1: `/proc/<pid>/stat` field 22 equals `WORKER_START_TICKS` and the boot id matches; `TERM`, 10 s, `KILL`);
saves tails and stops every prefixed container (`container_stop_all <run dir>`); when `PROD_WAS_RUNNING=yes`
and `wslc_list` does not show `PROD_CONTAINER`, calls `restore_start` once and then `ready_wait`; when it
shows it, `restore: <name> already running` and `ready_wait` only (idempotent, `restore_server.sh` line 14);
when `PROD_WAS_RUNNING=no`, no start. `ready_wait`: `restore_probe` every 10 s up to `READY_TIMEOUT_S` with
the 3-miss rule; success removes the marker (`rm`, after `sync`); failure keeps it, prints the one stderr line
of decision 5 and returns 5. `marker_write <file> <KEY=VALUE>…`: `.part` then `mv`. `container_stop_all <run
dir>`: for each name of `wslc_list` starting with `R9700_CONTAINER_PREFIX`: `wslc_logs <name> | tail -n 200 >
<run dir>/guard/<UTC stamp>-<name>.tail.log`, then `wslc_stop <name>`.

**7. `lib/run_guarded.sh`** — the supervisor's engine, sourced by `bin/r9700`:

- `deadline_compute`: sets `T_END`, `T_STOP` (epoch seconds) per decision 8; `DEADLINE` as the next
  occurrence (`date -d`, as `night5.sh` line 10); refuses when `T_STOP < now + 60`.
- `run_guarded <label> -- <cmd…>`: the loop of decision 15 and the exit table of decision 6:
  `tries=0; stops=0; while :; do quiet_wait $(min 900 $((T_STOP-now))) || {restore-while-waiting per
  decision 15; continue}; disk gate; admit; wait; outcome; case …; done`. `admit`: `stops+1 > MAX_SERVER_STOPS`
  → exit 8; `marker_write` (decision 3, without the worker keys); `wslc_stop PROD_CONTAINER` when it is listed
  (and `PROD_WAS_RUNNING=yes` in the marker) else `no`; `setsid lib/worker_gate.sh <gate file> "$@" 9>&- >>"<run dir>/steps/<n>.worker.log" 2>&1 &
  p=$!` (amendments A1, A2); `marker_write` again with the worker keys (ticks from `/proc/$p/stat` field 22 — read it with
  `awk '{print $22}'` after cutting at the last `)`, because the command name may hold spaces); copy the marker
  to `steps/<n>.marker`; start `guard_ram $p …` and the deadline watcher (`night5.sh` lines 21–24, firing at
  `T_STOP`, writing `KIND=deadline` first, then `container_stop_all`, then `TERM -$p`) as background
  children of the supervisor; `wait $p`; `kill` the two watchers; `outcome_write KIND=worker RC=$rc` (the
  noclobber create fails when a guard wrote first — that is the design). Then: `KIND=worker RC=0` → done;
  `RC=3` → `not quiet at a unit start, waiting`, continue (the server stays stopped for one `quiet_wait 900`;
  when that returns 1, `restore_now` — restore + ready + marker removed — and the loop continues with the
  server running; a later admission stops it again and counts); `RC=4` → exit 6; `KIND=deadline` → exit 6;
  `KIND=disk_gate` → exit 9; anything else → `tries+1`, `failed try <tries> of <max>: <KIND> <DETAIL>`,
  and `tries == MAX_FAILED_TRIES` → exit 7. Every exit of the loop goes through `cleanup_once`.
- The worker gets the environment `R9700_RUN_DIR`, `R9700_STEP_N`, `R9700_STEP_LABEL`, `R9700_T_STOP`,
  `R9700_OUTCOME_FILE` and every `R9700_<KEY>` of the config (exported by `config_load`), nothing else new.
  A worker that stops a unit because of the disk gate writes `KIND=disk_gate` itself (through
  `outcome_write`, the file name is in its environment) and exits non-zero.
- `cleanup_once <kind>`: guarded by a flag so it runs once per invocation — kills the worker group if alive
  (`TERM`, 10 s, `KILL`), `container_stop_all`, `restore_now` (when a marker exists), writes `<run dir>/status`
  (`done`, `failed`, `deadline`, `interrupted`, `restore-failed`, `not-quiet`, `disk-gate`), releases the lock.
  The `INT`/`TERM` trap calls it with `interrupted` and exits 130/143.
- `lock_take <verb>`: `exec 9>"$R9700_STATE_DIR/lock"; flock -n 9 || { read holder; refuse exit 4; }`; then
  `printf '%s %s %s\n' $$ "$verb" "$(date -u +%FT%TZ)" >&9` (truncate first). Released by the process end or
  by `cleanup_once`.
- `run_dir_new`: `RESULTS_DIR/runs/<UTC yyyymmddThhmmssZ>-<pid>/` with `steps/`, `guard/`, `supervisor.log`;
  every supervisor line goes to stdout AND the log (`tee -a`). The run id is the directory name.
- `outcome_write <file> <KEY=VALUE>…` with `noclobber`; `outcome_read <file>` sets `O_KIND`, `O_RC`, `O_DETAIL`.

**8. `bin/r9700`** — `#!/usr/bin/env bash`, `set -u`; resolves its own directory, sources `lib/config.sh`,
`lib/adapter.sh`, `lib/run_guarded.sh`, `lib/restore.sh`, the guards, `lib/serve.sh`, `lib/wait_ready.sh`,
`lib/bench.sh`; `main`: the first argument is the verb; `declare -F "verb_$1"` or the refusal of L20; then
`verb_<name> "${@:2}"`. Verbs in S2: `verb_commands` (decision 14), `verb_init` (decision 13), `verb_step`
(`step [--show-deadline] <label> -- <cmd…>`: lock → restore-first → `config_load "$R9700_MACHINE_ENV"
<model>` — `step` takes `--model <file>` defaulting to `models/` lookup by name, the same argument shape
`series` will use — → `deadline_compute` → `run_dir_new` → `run_guarded`). The machine file is
`./machine.env` or `R9700_MACHINE_ENV`. `verb_verdict` and `verb_series` are S3's; S2 ships `verb_verdict` as
the restore-first shell only: marker check (lock only when a marker exists, decision 2) then `r9700: verdict:
not implemented in S2` exit 2 — L6 and L9 need the restore-first half, S3 replaces the second line.
`restore_first`: `[ -f marker ] || return 0; echo "r9700: recovery marker found (run <RUN_ID>), restoring
first"; restore_from_marker …; rc 5 → exit 5`.

**9. The stubs.** `tests/stubs/wslc`: `[ -n "${R9700_STUB_DIR:-}" ] || { echo "stub: R9700_STUB_DIR unset"
>&2; exit 99; }`; append `"$(date +%s.%N) $n wslc $*"` (argv joined by single spaces; a second file
`calls.argv` holds one call per block with `printf '%s\n'` per argument and a blank line, for A5 and A8) under
`flock` on `calls.log`; `[ -f mode ] && [ "$(cat mode)" = hang ] && sleep 1000`; then `case "$1"`: `run` →
find `--name`, `setsid sleep 1000 &`, record the pid (the `containers/<name>.pid` file and `pids`), print two
lines; `list` → the header line then one line per live pid file, `<junk>  <name>` (the name LAST, as the
awk of `restore_server.sh` line 11 expects); `stop` → kill, remove the pid file; `logs` → `cat answers/logs`;
`exec` → `vllm bench serve` → print `answers/bench` with the tag from `--max-concurrency`/`--seed` prefixed as
`bench.sh` line 10 does — `python3 -c *urlopen*` → the next line of `answers/ready`, and for a `restore_probe`
program (it contains `/v1/completions`) `ok` prints `models\ncompletion` exit 0, `models-only` prints
`models\ncompletion: HTTP 500` exit 1, `fail` prints `models: <urlopen error>` exit 1; for the `wait_ready`
probe `ok` exit 0, else exit 1 — any other `exec` → exit 0 with nothing. `powershell.exe`: same preamble and
logging; the command string containing `Available MBytes` → the next line of `answers/ram` (with the CR the
real one prints); `Get-WinEvent` → `answers/disk`. `pwsh.exe`: logs, then creates
`containers/${R9700_STUB_PROD:-vllm}.pid` with a `setsid sleep 1000` (the stub cannot know `PROD_CONTAINER`;
the fixture's value is `vllm`, and a test with another name sets `R9700_STUB_PROD`). `worker.sh`: the modes of decision 12; every mode writes
`heartbeat` every 0.1 s while it sleeps.

**10. Tests** — the scenarios above, in `t_<guarantee>` functions with `assert.sh`. Each file's prelude is one
function `setup_case` (fresh `R9700_STUB_DIR` and `R9700_STATE_DIR` per test under `R9700_TEST_ROOT/<n>`,
the answers' defaults, the machine fixture, the `trap`), so every test starts clean; the pids file is global
to the test file and the trap kills everything in it. Waiting for a background supervisor uses a bounded
poll (`for i in $(seq 1 100); do [ -f child.pid ] && break; sleep 0.1; done`), never an unbounded loop.

**11. Docs.** `research/module_config.md`: the three rows and the changed default, with the cross-field check.
`research/module_tests.md`: the three test files; the flows `commands`, `init`, `step` (and the `verdict`
restore-first half) each `covered` with the scenario ids; the test knobs; *what it does not prove*: no real
`wslc`, no real PowerShell, no real server — the readiness probe's Python program runs only in the stub's
mind (it is a string the stub matches, not code the test executes), so a syntax error in it is found only on
the machine; this is named as a gap and the first acceptance run of S3 is where it is closed.
`research/architecture.md`: the supervisor, the adapter seam, the marker, the lock, the exit table, and a
Mermaid sequence of `step`: lock → restore-first → config → quiet → admit (marker, stop) → worker → outcome →
cleanup (tails, containers, restore, marker removed).

**Commands.**

```bash
node tests/run.mjs                                   # everything, including S1
node tests/run.mjs tests/test_lifecycle.sh tests/test_guards.sh tests/test_adapter.sh
bash tests/check_static.sh                           # includes --seam
node .agents/conventions/tools/leftovers-check.mjs --repo . --token r9700 --identity "the R9700 vLLM tuning toolkit" --profile node
node .agents/conventions/tools/plan-lifecycle.mjs
```

Report the runner's lines for the three files and the total, the static check's exit code, and for G1 the
exact assertion output showing the child pid dead after the stop (paste it — it is the 2026-10-31 defect).

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

`lib/series.sh`; `lib/fingerprint.py` (the spec's choice: hashing and JSON belong in Python, bash gathers the inputs);
`bin/r9700` gains `series` and `verdict`; `tests/test_series.sh`, `tests/test_fingerprint.py`;
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

### Decisions (the answers to the ten questions)

S3 uses S2's names exactly: `verb_series`, `verb_verdict`, `run_guarded`, `quiet_check`, `disk_gate_check`,
`serve_start`, `wait_ready`, `bench_run`, `wslc_exec`, `wslc_list`, `wslc_run`, `container_name`,
`outcome_write`, the worker exit codes 0/3/4, the environment `R9700_RUN_DIR`, `R9700_T_STOP`,
`R9700_OUTCOME_FILE`, and S1's `config_resolved`, `arm_args`, `arm_env`, `arm_mounts`, `arms_check`,
`verdict.py ship` and `check-block`.

**1. Fingerprint inputs.** The fingerprint is a JSON document, `<outdir>/fingerprint.json`, `{"version": 1,
"sha256": <hex>, "components": {…}}`, where `sha256` is over the canonical form of `components`:
`json.dumps(components, sort_keys=True, separators=(",", ":"), ensure_ascii=True)`. The components:

| Component | Value | Read from | Cost |
|---|---|---|---|
| `model.dir`, `model.served_name`, `model.max_model_len`, `model.max_num_seqs`, `model.gpu_mem_util`, `model.extra_serve_args`, `model.tuned_config_dir` | the model fields | `config_resolved` | none |
| `model.listing` | sha256 of `find <MODEL_DIR> -type f -printf '%P %s\n' \| LC_ALL=C sort` run INSIDE a throwaway container (`wslc_run` is for detached servers; this is `wslc run --rm` through a new adapter function `wslc_run_once <ceiling> <args…>`, 120 s, no GPU, the `hf-cache` volume and the generation config mounted) | the container | one container start, seconds; no weights are read |
| `genconfig` | sha256 of every regular file under `/genconfig`, recursive and hidden files included (`find . -type f -print0` → `sha256sum`), `<relative path> <sha256>` lines sorted with `LC_ALL=C` (plan-gate E1 finding 2; scenario F7 changes a nested and a hidden file and expects a refused resume) | the container | as above |
| `image` | the `IMAGE` tag string | config | none |
| `patches` | `{<rel source>: sha256}` for every mount of `MOUNTS` and of every arm's extra mounts | `PATCH_DIR` | one read per file |
| `arms` | `{<arm>: {"args": [...], "env": [...], "mounts": [...]}}` for the arms of this series | `arm_args`, `arm_env`, `arm_mounts` | none |
| `base` | the first arm of the series | the arguments | none |
| `workload` | `{"bench": {"input": 1024, "output": 512, "prompts": {"1": 6, "4": 12}, "seeds": [1,2,3]}, "prefill": {"lens": PREFILL_LENS, "output": 128, "prompts": 3, "seeds": [1,2,3]}, "quality": {"prompts": 20, "gsm8k_n": 200}}` | constants of `bench_run` and `prefill_run`, `PREFILL_LENS` from config | none |
| `rounds` | the round count | the arguments | none |
| `tools` | `{"harness_py": sha256(lib/harness.py), "bench_sh": sha256(lib/bench.sh), "series_sh": sha256(lib/series.sh)}` | the repository | none |
| `machine` | `CONTAINER_PREFIX`, `GSM8K_DATA` | config | none |

Why names and sizes, not the weights' hash: the 35B model is tens of gigabytes in a volume only a container
sees; hashing it on every start and resume costs minutes of disk and GPU-less container time per series,
while a listing with sizes catches a replaced or re-quantised model (another file set or size) and misses only
a same-size edit of a weight file — a case that does not happen by accident, and the record says so.
Rejected: `MODEL_DIR` alone (a re-quantised model under the same path passes). Why the tag, not a digest: no
`wslc` image-inspect verb is used by any source script, so none is verified on this machine; the tag is what
the operator controls, and the first acceptance run notes whether `wslc image inspect` exists so a later story
can add the digest. Why the generation config through the container: only `GENCONFIG_WIN` is in the config
(S1), the WSL path is unknown, and the container already mounts it at `/genconfig`.

**2. "Names what differs".** `lib/fingerprint.py compare <stored.json> <new.json>` walks both `components`
trees and prints one line per differing leaf, `fingerprint differs: <dotted path>: <old> -> <new>` (a missing
leaf is `<absent>`), exit 1; equal trees exit 0. `series` on an existing outdir runs the compare; any line
refuses the resume (exit 2, the lines on stderr). **Arms are compared per name**: an arm in the new list that
the stored fingerprint knows must be identical; a NEW arm is an allowed extension — the stored file is
rewritten (atomically) with the arm added and a line `fingerprint: arm <name> added` on stdout; an arm left
out of a later invocation is not a difference (its records stay; the verdict reads what is recorded). The base
arm is a component of its own (`base`), so a resume that would change what every arm is compared against is
refused. Reason: an arm-round record depends on its own arm, the model, the image, the patches and the
workload — not on which other arms exist; the night runs added arms over several nights into comparable series.
Rejected: the arm list as one value (the operator would need a new outdir to add `ta3mb` to a series that
already holds `base` and `ta3`, and the verdict then could not compare them).

**3. The arm-round record.** `<outdir>/rounds/<arm>-<round>/` is a final record; while it is being built it is
`<outdir>/rounds/<arm>-<round>.part-<run id>/`. Contents:

| File | What |
|---|---|
| `bench.txt` | the arm-round's bench lines: 18 decode lines (`bench_run`) + 9 per prefill length (`prefill_run`), tag `<arm>-<round>` |
| `spec_metrics.txt` | the `vllm:spec_decode` lines, prefixed `<arm>-<round> ` (`speed_A.sh` lines 74–75) |
| `server.log` | the container's whole log, saved by `wait_ready` and again at the end (`speed_A.sh` line 89) |
| `server_config.txt` | the configuration lines of `speed_A.sh` lines 69–70 (same regex, `cut -c1-240`, `sort -u`) |
| `record.env` | `ARM`, `ROUND`, `RUN_ID`, `CONTAINER`, `STARTED_AT`, `FINISHED_AT` (UTC), `FINGERPRINT` (the sha256), `SERIES_SH` (its sha256) |
| round 1 only: `prompts_<arm>.json`, `gsm8k_<arm>.json` | the harness outputs, moved in from `WORK_DIR` (decision 5) |

Validation before the rename, in this order, each failure a named reason: (a) `python3 lib/verdict.py
check-block --tag <arm>-<round> --prefill-lens "$R9700_PREFILL_LENS" bench.txt` exits 0 — the ONE definition
of complete; (b) the container is still listed by `wslc_list` (`speed_A.sh` line 87); (c) in round 1 both
quality files exist, parse as JSON, and `gsm8k_<arm>.json` has `summary.n == 200` and `prompts_<arm>.json`
has 20 results; (d) `server.log` is non-empty. Then `mv rounds/<arm>-<round>.part-<id> rounds/<arm>-<round>`
— one `rename(2)` on one file system, so a reader sees either no record or a complete one. A failed
validation moves the directory to `<outdir>/rejected/<arm>-<round>-<UTC stamp>/` with a `reason` file
(`LOST: server alive 0, check-block: missing prefill32768 r=2 …`) — kept as evidence, never deleted; the
series then exits 1 (a failed try for the supervisor, which stops the container and counts it). After the
rename the series copies `gsm8k_<arm>.json` into `<outdir>/quality/gsm8k_<arm>.json` (the layout S1's
`verdict.py --gsm8k-dir` reads) — a copy of 100 KB, not a link, because links are not portable across the
file systems `RESULTS_DIR` may sit on. Rejected: a shared `bench.txt` for the series (`speed_A.sh` line 72 —
that is where the two incomplete blocks of the fixture came from) and a `done_` marker file (the directory's
final name is the marker; there is no second thing to get out of step).

**4. Reading back.** `bin/r9700 verdict <outdir> [--base <arm>] [--no-quality] [--json <file>]`: reads
`fingerprint.json` (the base is `components.base` unless `--base` is given; `rounds` is its `rounds`), lists
`rounds/<arm>-<round>/bench.txt` in arm order of the fingerprint and round order, passes each as one `--bench`,
`--prefill-lens` from the fingerprint's `workload.prefill.lens`, `--gsm8k-dir <outdir>/quality`, `--rounds
<rounds>`, `--arm` for every arm of the fingerprint that is not unsupported (decision 6). It prints
`verdict.py`'s output unchanged after one header line `series <outdir>: base <arm>, <n> rounds, fingerprint
<first 12 hex>` and exits with `verdict.py`'s code. A record directory without `bench.txt` or a `.part-` or
`rejected/` directory is never passed (so an in-flight or rejected attempt can never reach the verdict).

**5. `harness.py` in the container.** Before the first arm-round of round 1, `series` copies
`lib/harness.py` to `$R9700_WORK_DIR/r9700/harness.py` (`.part` + `mv`) and checks its sha256 equals
`components.tools.harness_py`; the container sees it as `/work/r9700/harness.py` (`WORK_DIR` and
`WORK_DIR_WIN` are the one directory, S1's field table). Quality output goes to `/work/r9700/<series>/` —
`$R9700_WORK_DIR/r9700/<series>/prompts_<arm>.json` and `gsm8k_<arm>.json`, written atomically by `harness.py`
(S1) — and is MOVED into the `.part-` record directory (same file system when `RESULTS_DIR` is on the same
mount; otherwise a copy and a remove, which is what `mv` does). The GSM8K data: when `GSM8K_DATA` starts with
`/work/`, `series` checks `$R9700_WORK_DIR/<rest>` exists before round 1 and refuses with exit 2 naming the
file when it does not; any other container path is not checkable from WSL and the check is skipped with a
printed line.

**6. Unsupported arms.** Two tries, 60 s apart, as `speed_A.sh` lines 62–67 (the first failed container is
stopped and the second start uses a new container name, `<label>-r2`, so the two logs are both kept in
`rejected/`). After the second failure: `<outdir>/unsupported/<arm>-<UTC stamp>.txt` with the last three
`Error|error:` lines of the server log (`speed_A.sh` line 65) and the paths of the two rejected attempts; the
series skips an arm that has any `unsupported/<arm>-*.txt` (as line 47) and continues (line 66) — the
supervisor sees exit 0 at the end. `verdict` prints `verdict <arm>: UNSUPPORTED (did not start twice,
<stamp>)` for such an arm and leaves it out of the `--arm` list.

**7. Round count.** `series --rounds <n>` default 3 (`speed_A.sh` line 45); the count is in the fingerprint,
so a resume with another count is refused like any other difference. `verdict` passes that count, so a
one-round series gets a full verdict over 3 values per concurrency, with one added line after the header:
`note: 1 round, 3 values per concurrency; the recorded ship test used 3 rounds (9)`. Rejected: refusing a
verdict below 3 rounds — the acceptance run is one round by the parent's design, and a verdict with its
conditions named is what measurement rule 3 asks for.

**8. Both example models run `series` unedited.** The 35B file runs for real on the R9700: `base` vs `ta3`,
one round (the parent's acceptance). The 27B file runs `series --dry-run` on the R9700: the dry run loads the
config, computes the fingerprint (the throwaway container runs, so the model listing is real) and prints
every resolved command of the first arm-round — the `wslc run` argv, the bench and prefill argv, the quality
argv — without starting a server. The acceptance record says which model ran how. Reason: the two files differ
only in resolved values, and the dry run shows exactly those; a second real run costs about 25 minutes of the
operator's GPU for no new mechanism. The main session may replace this with a real 27B run; the record then
says so.

**9. Outdir growth.** Per arm-round: `bench.txt` ≈ 3 KB, `spec_metrics.txt` ≈ 2 KB, `server.log` ≈ 300 KB
(measured 2026-10-31), `server_config.txt` ≈ 1 KB; round 1 adds `prompts_<arm>.json` ≈ 250 KB and
`gsm8k_<arm>.json` ≈ 100 KB. A 3-arm, 3-round series: 9 × 306 KB + 3 × 350 KB + 3 × 100 KB (the `quality/`
copies) + `fingerprint.json` ≈ 10 KB ≈ 4.2 MB, plus S2's run directories (logs, a few KB each) and rejected
attempts (≈ 300 KB each, at most `MAX_FAILED_TRIES` per invocation). The parent's ≈5 MB holds. Nothing in the
toolkit deletes anything under `RESULTS_DIR`; `init` creates it and `series` only adds.

**10. The stub scenarios** are S1–S20 below; the false-marker case of 2026-10-31 21:43 is S5 and S6.

**Series semantics not asked but needed.** `bin/r9700 series <model> <arm>… [--out <name>] [--rounds n]
[--dry-run]`: `<model>` is a name under `models/` or a path to a `.env`; `--out` defaults to
`<model name>-<UTC date>`; the outdir is `$R9700_RESULTS_DIR/<name>`. The verb is `run_guarded series --
bash lib/series.sh <outdir> <rounds> <arm>…` after the fingerprint step (which runs in the supervisor, before
admission, so a refused resume stops nothing). The worker loop is `speed_A.sh` lines 45–93 with: the skip on a
final record directory (line 46) and on `unsupported/` (line 47); `disk_gate_check` (line 48; a `STOP` writes
`KIND=disk_gate` and exits 1); `quiet_check` → exit 3 (lines 51–55, always on — `QUIETCHECK` goes); the fit
check of `night5.sh` line 37 before every arm-round — `now + 1500 > R9700_T_STOP` → exit 4; the container
name `container_name "sp-<arm>-<round>"` (line 56); `serve_start` with `arm_env`, `arm_mounts`, `arm_args`
(lines 56–62); `prefill_run <name> <tag> <len>` = `speed_A.sh` lines 36–43 with `wslc_exec 1800`; the record of
decision 3; `sleep 10` after a record (line 92). `series.sh` sets no trap (line 20 goes) and never stops the
operator's server (line 44 goes).

### Test scenarios

`tests/test_series.sh` (S1–S16, bash, the S2 preamble: stubs first on `PATH`, `R9700_STATE_DIR`,
`R9700_STUB_DIR`, `R9700_TIME_SCALE=100`, the machine fixture, the 35B model file, the stub `trap`) and
`tests/test_fingerprint.py` (F1–F6, pytest). "A stub series" is `bin/r9700 series qwen3.6-35b-a3b-gptq fbase
fcombo --out s --rounds <n>` with the stubs answering: `answers/bench` = the 18 decode lines and 18 prefill
lines of fixture lines 175–210 without their tag (the stub re-tags them from the argv, so every arm-round
prints a complete block); `answers/ready` = `ok`; `answers/logs` = 50 lines with one `Using configuration from
/work/moe/tune/merged` line; `answers/find` (the throwaway container's output) = `a.safetensors 100\nconfig.json
10\n`; `answers/genconfig` = `generation_config.json <64 hex>\n`; `answers/metrics` = two `vllm:spec_decode_…`
lines; the harness calls (`exec … /work/r9700/harness.py collect|gsm8k`) write a 20-result `prompts_<arm>.json`
and a `gsm8k_<arm>.json` with `summary.n` 200 into `$R9700_WORK_DIR/r9700/s/` (the stub writes them — it stands
in for the container that would). The outdir is `$RESULTS_DIR/s`. Leftovers: as S2 — everything under
`R9700_TEST_ROOT`, the stub pids killed by the trap, the token `r9700`.

**Series (`tests/test_series.sh`)**

1. *A one-round, two-arm series writes two final records and a fingerprint, in alternating order.* A stub
   series with `--rounds 1`: exit 0; `rounds/fbase-1/` and `rounds/fcombo-1/` exist with every file of the
   record table (round-1 quality included), no `.part-` directory remains; `fingerprint.json` parses and its
   `sha256` equals the sha256 the test computes from the canonical form of `components`; the call log's
   container starts are `r9700tune-sp-fbase-1` then `r9700tune-sp-fcombo-1`; the operator's server was stopped
   once and restored once; `quality/gsm8k_fbase.json` equals `rounds/fbase-1/gsm8k_fbase.json` byte for byte.
2. *Three rounds alternate arms inside a round.* `--rounds 3` with a worker that records order: the container
   starts in the call log are `fbase-1, fcombo-1, fbase-2, fcombo-2, fbase-3, fcombo-3`; six records exist.
3. *Each record's bench file is one complete block that `check-block` accepts.* For every record of S2,
   `python3 lib/verdict.py check-block --tag <arm>-<round> --prefill-lens "8192 32768" rounds/<arm>-<round>/
   bench.txt` exits 0 — derived over `rounds/*/`, not typed.
4. *`record.env` carries the run identity.* `rounds/fbase-1/record.env` has `ARM=fbase`, `ROUND=1`,
   `CONTAINER=r9700tune-sp-fbase-1`, `FINGERPRINT=` equal to `fingerprint.json`'s `sha256`, `RUN_ID=` equal to
   the run directory's name, and `STARTED_AT` ≤ `FINISHED_AT` (ISO UTC).
5. *A server lost mid-bench leaves no final record and a rejected attempt with its reason.* `answers/ready` =
   `ok`; the test's helper kills `containers/r9700tune-sp-fbase-1.pid` after the third `exec … bench serve`
   line appears in the call log (bounded poll); `answers/bench` is unchanged: `series` exits non-zero;
   `rounds/fbase-1/` does NOT exist; `rejected/fbase-1-<stamp>/` exists with `reason` starting `LOST: server
   alive 0` and a `bench.txt` of fewer than 36 lines; the supervisor's outcome has `KIND=worker RC=1`, the
   status is `failed` after `MAX_FAILED_TRIES=1`, and the restore ran once. (RESULTS § 13.4: the false
   `done_o7ref-1`.)
6. *Missing lines make no record even when the server is alive.* `answers/bench` with the `prefill32768 r=2`
   lines removed (lines 175–210 of the fixture minus three): no `rounds/fbase-1/`; `rejected/fbase-1-*/reason`
   contains `check-block: missing prefill32768 r=2 Output token throughput (tok/s)`; the full `bench.txt` of the
   attempt is in the rejected directory.
7. *A resume skips exactly the recorded arm-rounds.* After S1 (`--rounds 1`), run the same command with
   `--rounds 1` again: exit 0; the supervisor counts the missing records BEFORE admission (`series_left`, the
   `left` of `night5.sh` line 30 over final record directories) and, when none is missing, prints `series: 2
   of 2 arm-rounds recorded, nothing to do` and ends without admitting: the second invocation's call log has no
   `run -d`, no `stop vllm` and no `pwsh.exe`. With `--rounds 2` instead: two new records `fbase-2`, `fcombo-2`,
   the round-1 records untouched (same mtimes), the container starts are exactly `fbase-2, fcombo-2`, one
   `stop vllm`.
8. *A resume with a changed `MAX_NUM_SEQS` is refused naming the component, before any stop.* After S1, a
   model variant with `MAX_NUM_SEQS=8`: exit 2; stderr contains `fingerprint differs: model.max_num_seqs: 4 ->
   8`; the second invocation's call log has no `stop vllm`; the server was never stopped (`containers/vllm.pid`
   mtime unchanged).
9. *A changed patch file is refused naming the file.* After S1, append a byte to
   `@ROOT@/patches/C/auto_gptq.py`: exit 2, stderr `fingerprint differs: patches.C/auto_gptq.py: <old sha> ->
   <new sha>` (both 64-hex, different).
10. *A changed model listing is refused; a new arm is an extension.* `answers/find` changed to `a.safetensors
    101`: exit 2, `fingerprint differs: model.listing: … -> …`. With the original listing and the arms `fbase
    fcombo fb1`: exit 0, stdout `fingerprint: arm fb1 added`, `fingerprint.json` now holds `arms.fb1` and the
    old arms unchanged, `rounds/fb1-1/` exists. With the arms `fcombo fbase` (another base): exit 2,
    `fingerprint differs: base: fbase -> fcombo`.
11. *A container that never becomes ready is retried once, then the arm is unsupported and the series goes
    on.* `answers/ready` = `fail` for the first two probes sequences of `fbase` (the stub's `ready` file is per
    container name: `answers/ready.r9700tune-sp-fbase-1` and `….r9700tune-sp-fbase-1-r2` = `fail`, the default
    `ok` for the rest): exit 0; `unsupported/fbase-<stamp>.txt` exists and names two rejected directories;
    `rejected/` holds `fbase-1-*` twice (`server.log` of each); `rounds/fcombo-1/` exists; the call log shows
    `run … --name r9700tune-sp-fbase-1`, a `stop` of it, then `run … --name r9700tune-sp-fbase-1-r2`, with 60 s /
    100 between (stamps); then `fcombo`. A second invocation does not start `fbase` again (no `run … fbase`).
12. *The quiet check runs before every arm-round and exits 3.* Load file `9.0` from the start and the short
    variant of S2's G5 (`MAX_RUN_MINUTES=10`, `CLEANUP_BUDGET_S=360`, `READY_TIMEOUT_S=60`): the supervisor
    never admits (exit 8); with a load
    file that turns `9.0` AFTER the first record (the helper rewrites it when `rounds/fbase-1/` appears):
    `series.sh` exits 3 before `fcombo-1`; the supervisor log has `not quiet at a unit start, waiting`; when
    the helper sets `0.5` again, `fcombo-1` is recorded and exit is 0 — one `stop vllm` in total.
13. *The fit check ends the series cleanly before the deadline.* Variant `MAX_RUN_MINUTES=30`,
    `CLEANUP_BUDGET_S=1500` with scale 100 (`T_STOP` = 3 s after start), the test knobs `R9700_ARM_SECONDS=200`
    (the per-arm-round allowance, scaled to 2 s) and `R9700_STUB_DELAY_S=0.1` (the stub sleeps that long per
    `bench serve` call, so an arm-round takes at least 1.2 s): the first unit starts at about 0.3 s and fits
    (0.3 + 2 < 3); the second starts after the first record, at about 1.8 s, and does not (1.8 + 2 > 3) —
    `series.sh` exits 4 with `series: 1 arm-rounds no longer fit before the deadline`; the supervisor exits 6;
    `rounds/fbase-1/` exists, nothing for `fcombo`; no `failed try` line.
14. *The disk gate stops the series.* `answers/disk` = `100` then `101`: after `fbase-1`, `series.sh` writes
    `KIND=disk_gate` and exits 1; the supervisor exits 9; `rounds/fbase-1/` is final (the gate is checked
    before a unit, not inside one).
15. *A partial series gets no full verdict, and in-flight or rejected attempts never reach it.* Two halves.
    (a) After S5 (`fbase-1` rejected, nothing final) plus a hand-made `rounds/fcombo-1.part-x/bench.txt` (a
    copy of a complete block): `bin/r9700 verdict $RESULTS_DIR/s` exits 2 with `base arm "fbase" has no
    complete arm-round in the inputs` (the base has no final record), and the verdict's `invoking:` line (it
    prints the `verdict.py` argv) holds no `.part-x` and no `rejected/` path. (b) After a complete `--rounds 3`
    run, with `rounds/fcombo-3/` moved by the test to `rejected/by-test/`: exit 1, stdout `verdict fcombo:
    INCOMPLETE (missing complete arm-rounds: fcombo-3)`, and no `PASS` or `FAIL` line anywhere in stdout.
16. *The stopped `fcombo-2` block and the `fb1-2` fragment of the fixture are ignored by completeness, and
    the records reproduce the recorded verdict.* A fixture outdir built by the test from `bench_final_ab.txt`:
    for each tag, the lines of the fixture are written into `rounds/<tag>/bench.txt` by splitting the file at
    each `c=1 r=1 Output token throughput` line — so `rounds/fcombo-2/bench.txt` first receives the stopped
    block (lines 145–174) and then the complete one (175–210) appended, and `rounds/fb1-2/bench.txt` receives
    lines 211–213 then 214–249; `fingerprint.json` written by the test with `base: fbase`, arms `fbase fcombo
    fb1`, `rounds: 3`, `prefill.lens "8192 32768"`; `quality/` from the S1 fixture. `bin/r9700 verdict` exits
    0; stdout has `ignored incomplete block: fcombo-2, 30 lines from bench.txt:1`, `ignored incomplete block:
    fb1-2, 3 lines from bench.txt:1`, `verdict fcombo: PASS`, `verdict fb1: FAIL (no decode median is higher
    than the base spread)`, and the S1 numbers (`median 84.47 vs 76.08`, `base spread 9.84`, `202.44 vs
    178.39`). The companion that keeps the scan honest: `python3 lib/verdict.py check-block --tag fcombo-2 …
    rounds/fcombo-2/bench.txt` exits 1 with `expected 36 lines, found 66` — which is why a record directory of
    the toolkit's own making never holds two blocks (S3), and why `verdict` reads the fixture's shape only
    through `ship`, whose last-complete-block rule handles it.
17. *`verdict` reports an unsupported arm and leaves it out.* S11's shape with `fcombo` unsupported instead
    of `fbase` (`answers/ready.r9700tune-sp-fcombo-1` and `….r9700tune-sp-fcombo-1-r2` = `fail`), one round:
    `bin/r9700 verdict` prints `verdict fcombo: UNSUPPORTED (did not start twice, <stamp>)`, exits 0, and the
    `invoking:` line shows `verdict.py` called with no `--arm`. An unsupported BASE arm is refused instead:
    S11 as written, then `verdict`: exit 2, stderr `verdict: base arm fbase is unsupported`.
18. *A one-round series gets a verdict with its condition named.* After S1: `bin/r9700 verdict` exits 0;
    stdout has `note: 1 round, 3 values per concurrency; the recorded ship test used 3 rounds (9)` and a
    `verdict fcombo: PASS` or `FAIL` line (the stub's block is the fixture's `fcombo-2` block for both arms, so
    the delta is 0 → `FAIL (no decode median is higher than the base spread)`; asserted exactly).
19. *`--dry-run` prints the resolved commands and starts no server.* `series … --dry-run` with the 27B model
    file: exit 0; the call log has the one throwaway `run --rm` (the fingerprint's container) and no `run -d`,
    no `stop vllm`, no `pwsh.exe`; stdout has `dry-run: wslc run -d --rm --name r9700tune-sp-fbase-1 …
    --max-model-len 16384 … --max-num-seqs 16 …`, `dry-run: bench … --model qwen3.8-27b`, `dry-run: prefill
    8192` and no `prefill 32768`; `fingerprint.json` is written (the dry run records what it resolved);
    `rounds/` does not exist.
20. *`harness.py` is placed in `WORK_DIR` with its hash checked, and missing GSM8K data is refused before round
    1.* After S1, `$R9700_WORK_DIR/r9700/harness.py` equals `lib/harness.py` (sha256). With
    `@ROOT@/work/gsm8k/test.jsonl` absent (the test creates it in `setup_case` for the other scenarios): exit 2
    before any `run -d`, stderr `series: GSM8K_DATA /work/gsm8k/test.jsonl not found at <root>/work/gsm8k/
    test.jsonl`; with `GSM8K_DATA=/data/x.jsonl` (not under `/work`): stdout `series: GSM8K_DATA /data/x.jsonl is
    not under /work, not checked` and the series proceeds.

**Fingerprint (`tests/test_fingerprint.py`)** — `run(args)` as S1's, `lib/fingerprint.py`.

1. *The canonical form is key-sorted, compact, ASCII, and the hash is over it.* `build` from an inputs
   directory the test writes (every component file): the output's `sha256` equals
   `hashlib.sha256(json.dumps(components, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode())`;
   the same inputs in another file order give the same hash.
2. *`compare` names every differing leaf with its path, old and new.* Two documents differing in
   `model.max_num_seqs` (4 → 8) and `patches.C/auto_gptq.py`: exit 1, stdout exactly two lines in sorted path
   order, `fingerprint differs: model.max_num_seqs: 4 -> 8` first.
3. *A missing leaf is `<absent>`.* `tools.series_sh` missing on the old side: `fingerprint differs:
   tools.series_sh: <absent> -> <sha>`.
4. *A new arm is an extension; a changed arm and a changed base are differences.* `compare` with `arms.fb1`
   only on the new side: exit 0, stdout `fingerprint: arm fb1 added`; with `arms.fcombo.args` changed: exit 1
   naming `arms.fcombo.args`; with `base` changed: exit 1 naming `base`.
5. *`build` refuses a malformed input, naming it.* An inputs directory whose `patches` file has a line without
   a hash: exit 2, stderr `fingerprint: patches:3: expected "<path> <64 hex>"`.
6. *`build` writes atomically.* `--out <basetemp>/fp.json` with the target a directory: exit 2, no `fp.json.part`.

### Brief for the Sonnet coder

Read first: this section whole; the S2 section's decisions 6, 9, 11, 12, 15 and its brief (the function
names you call, the worker environment, the stubs); the S1 brief for `lib/verdict.py` (`check-block`, `ship`,
the exit codes) and `lib/config.sh` (`config_resolved`, `arm_*`); the parent's *Run identity* paragraph and
the "kept exactly" paragraph; `.agents/conventions/common/reliability.md` § *Paid work is written down as it
is earned*. The source line numbers are of `speed_A.sh` and `night5.sh` unless said otherwise. Do not change
`lib/run_guarded.sh`, `lib/adapter.sh` (except the one function below), `lib/verdict.py` or `lib/harness.py`.

**Files.** `lib/series.sh` (sourced functions AND an executable worker: `[[ "${BASH_SOURCE[0]}" == "$0" ]] &&
series_main "$@"`), `lib/fingerprint.py` (stdlib, Python ≥ 3.10), `lib/adapter.sh` gains `wslc_run_once
<ceiling> <args…>` (`run --rm` in the foreground, CRs removed, the same shape as `wslc_exec`), `bin/r9700`
gains `verb_series` and replaces the S2 placeholder body of `verb_verdict`; `tests/test_series.sh`,
`tests/test_fingerprint.py`; `tests/stubs/wslc` gains the `run --rm` (foreground) answer from `answers/find`
and `answers/genconfig`, the per-container `answers/ready.<name>` lookup, `answers/metrics` for the
`/metrics` exec, and the harness `collect`/`gsm8k` answers that write the two JSON files; `README.md` quick
start; `research/architecture.md`, `research/module_tests.md`; `research/ACCEPTANCE_series_<date>.md` (written
by the operator's session from the real run — you write its template with the predictions, measurement rule 4).

**1. `lib/fingerprint.py`.**

- `build <inputs dir> --out <file>`: the inputs directory holds one file per component group, written by
  `series.sh` (bash writes files, Python assembles — no JSON built in bash): `config.env` (the
  `config_resolved` output), `arms/<arm>.args`, `arms/<arm>.env`, `arms/<arm>.mounts` (one item per line, the
  `arm_*` outputs), `patches` (`<rel> <64 hex>` per line), `listing` (the `find` output), `genconfig`
  (`<name> <64 hex>` per line), `tools` (`<key> <64 hex>` per line), `series` (`base=`, `rounds=`,
  `prefill_lens=`). It builds `components` exactly as decision 1's table (model fields from `config.env` with
  the `R9700_` prefix removed and lower-cased keys; `model.listing` = sha256 of the `listing` file's bytes;
  `genconfig` = sha256 of the `genconfig` file's bytes; `workload` constants typed in this file ONCE, with a
  comment naming `bench.sh` lines 5–10 and `speed_A.sh` lines 36–43), computes the sha256 of the canonical form,
  writes `{"version": 1, "sha256": …, "components": …}` with `.part` + `os.replace`, and prints the hash.
  Malformed input: `fingerprint: <file>:<line>: expected "<shape>"`, exit 2.
- `compare <stored> <new>`: flattens both `components` to dotted leaf paths (lists compared whole, as JSON);
  for `arms.<name>.*` a path absent on the stored side and present on the new side is an extension (collected,
  printed as `fingerprint: arm <name> added`, one line per arm); every other difference is `fingerprint
  differs: <path>: <old> -> <new>` (`<absent>` for a missing side; values printed as compact JSON); exit 1 when
  any difference line was printed, else 0. `--merge <file>` additionally writes the stored document with the
  new arms added (atomic) — `series.sh` calls it on a resume.
- Functions under 50 lines; no globals mutated; `python3 lib/fingerprint.py --selftest` is not needed — the
  pytest file covers it.

**2. `lib/series.sh`.**

- `series_fingerprint <outdir> <model.env> <rounds> <arm>…` (runs in the SUPERVISOR, from `verb_series`, before
  admission): `mkdir -p <outdir>`; writes the inputs directory `<outdir>/.fingerprint-inputs.part-<run id>/`
  (removed after the build; it is the one temporary thing, inside the outdir); the patches list from
  `R9700_MOUNTS` and `arm_mounts <arm>` for every arm, `sha256sum` under `R9700_PATCH_DIR`; the listing and the
  generation config from ONE throwaway container: `wslc_run_once 120 -v hf-cache:/root/.cache/huggingface -v
  "$R9700_GENCONFIG_WIN:/genconfig:ro" "$R9700_IMAGE" sh -c 'find "$1" -type f -printf "%P %s\n" | LC_ALL=C
  sort; echo ---; cd /genconfig && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum' sh
  "$R9700_MODEL_DIR"` split at the `---` line (the volume names from `R9700_HF_VOLUME`). **The model path is an
  argument (`$1`), never text inside the `sh -c` program** (plan-gate E1 finding 1): scenario F8 sets
  `MODEL_DIR='/m; touch /tmp/x; #'` in a stub run and checks the stub received it as one argv element and no
  command ran; the tools' hashes with `sha256sum lib/harness.py lib/bench.sh lib/series.sh`. Then
  `fingerprint.py build`; when `<outdir>/fingerprint.json` exists, `fingerprint.py compare --merge` instead of
  replacing it — a difference line means exit 2 with the lines on stderr (`verb_series` has not admitted, so
  nothing was stopped). With `--dry-run`: the same, then `series_dry_run` prints the resolved argv of the
  first arm-round (`dry-run: wslc run -d --rm --name …` built by `serve_start --print`, a flag S3 adds to
  S2's function that prints the argv instead of calling `wslc_run`; `dry-run: bench …`; `dry-run: prefill
  <len> …`; `dry-run: quality …`) and returns 0.
- `series_left <outdir> <rounds> <arm>…`: counts arm-rounds without a final `rounds/<arm>-<round>/` and
  without `unsupported/<arm>-*.txt` (`night5.sh` line 30); `verb_series` prints `series: <done> of <all>
  arm-rounds recorded, nothing to do` and returns 0 when it is zero, BEFORE `run_guarded`.
- `series_main <outdir> <rounds> <arm>…` — the worker (lines 45–93), per arm-round in `for round; for arm`
  order: skip a final record or an unsupported arm; `disk_gate_check "$R9700_RUN_DIR/disk_gate.state"` (line
  48; `STOP` → `outcome_write "$R9700_OUTCOME_FILE" KIND=disk_gate RC=1 "DETAIL=<its line>"`, exit 1); `quiet_check
  || { echo "NOT QUIET: $arm round $round"; exit 3; }` (lines 51–55); the fit check: `$(date +%s) + 1500 >
  R9700_T_STOP` → `echo "series: $(series_left …) arm-rounds no longer fit before the deadline"; exit 4` (the
  1500 s of `night5.sh` line 12 is `${R9700_ARM_SECONDS:-1500}` through `t_scale`, a test knob like S2's,
  with its origin in a comment; `R9700_STUB_DELAY_S` is the stub's own knob, S13); the
  record directory `<outdir>/rounds/<arm>-<round>.part-$R9700_RUN_ID/` (`mkdir`, exclusive); `record.env`
  started; the start: `name=$(container_name "sp-$arm-$round")`, `mapfile -t a < <(arm_args "$arm")`, the
  env words from `arm_env` as `-e`, the mounts from `arm_mounts` as `-v`, `-e
  VLLM_TUNED_CONFIG_FOLDER=$R9700_TUNED_CONFIG_DIR` when set (line 58 — the arm's own env, `fb1`, comes after
  it and wins, as `wslc` takes the last `-e`); `serve_start "$name" "$part/server.log" … -- "${a[@]}"`; on
  failure `wslc_stop "$name"`, `sleep 60`, the second try as `${name}-r2` (lines 62–67); a second failure →
  `rejected/` for both attempts' logs, `unsupported/<arm>-<UTC stamp>.txt` (the three `grep -E "Error|error:"`
  lines, line 65), `sleep 20`, `continue`. Then: `server_config.txt` (lines 69–70); `bench_run "$name"
  "$arm-$round" > bench.txt`; `for pl in $R9700_PREFILL_LENS: prefill_run … >> bench.txt` (line 73);
  `spec_metrics.txt` (lines 74–75 through `wslc_exec 60`); round 1: the two harness calls of lines 80–83 with
  `/work/r9700/harness.py`, `--out /work/r9700/<series>/prompts_<arm>.json` and `gsm8k_<arm>.json`, `--data
  $R9700_GSM8K_DATA`, `--n 200`, then `mv` both from `$R9700_WORK_DIR/r9700/<series>/` into the record;
  `server.log` saved again (`wslc_logs`, line 89); `alive` from `wslc_list` (line 87); `wslc_stop "$name"`
  (line 90); validation (a)–(d) of decision 3 — `check-block`'s stdout is the reason text; a failure moves
  the directory to `rejected/<arm>-<round>-<stamp>/`, writes `reason`, prints `LOST: …` and exits 1 (line 91);
  success: `FINISHED_AT`, `mv "$part" "<outdir>/rounds/$arm-$round"`, `cp gsm8k_<arm>.json
  <outdir>/quality/` in round 1, `sleep 10` (line 92). `prefill_run <name> <tag> <len>`: lines 36–43 with
  `wslc_exec 1800`, `R9700_SERVED_NAME`, `R9700_MODEL_DIR`. Before round 1's first unit: the `harness.py` copy
  and hash check, the GSM8K data check (decision 5). No `trap` (line 20), no `stop vllm` (line 44), no
  `PREFIXTEST` (lines 76–78), no `QUIETCHECK` switch (always on), no shared `bench.txt` (line 72).
- Every step of the unit that can fail is inside the unit: a failure of one arm-round never ends the loop
  except through the typed exits above (reliability: one failed unit is recorded and skipped — here, recorded
  and the supervisor decides).

**3. `bin/r9700`.** `verb_series <model> <arm>… [--out <name>] [--rounds <n>] [--dry-run]`: lock →
restore-first → `config_load` → `arms_load config/arms.conf` and `arms_check <arm>…` → `deadline_compute` →
`run_dir_new` → `series_fingerprint` → (dry run returns here) → `series_left` → `run_guarded series -- bash
"$LIB/series.sh" <outdir> <rounds> <arm>…`. `verb_verdict <outdir> [--base <arm>] [--no-quality] [--json
<file>]`: marker check (S2's restore-first half, unchanged) → `fingerprint.json` read with `python3 -c` (one
small helper `fingerprint.py show <file> <path>` prints a leaf) → the header and the `note:` line of decision
7 → the `UNSUPPORTED` lines of decision 6 (an unsupported base: exit 2, `verdict: base arm <arm> is
unsupported`) → `invoking: python3 lib/verdict.py ship …` (the argv, one line) → `exec python3 lib/verdict.py
ship …` so the exit code is `verdict.py`'s.

**4. The stubs** — the additions named under *Files*; `answers/ready.<name>` falls back to `answers/ready`;
the harness `collect` answer writes a 20-result file and `gsm8k` a `summary {"n": 200, "correct": 170,
"accuracy": 0.85, "stderr": 0.0252}` file at the `--out` path translated from `/work/` to `$R9700_WORK_DIR/`
(the stub reads `R9700_WORK_DIR` from the environment the supervisor exported).

**5. Tests** — the scenarios above; `tests/test_series.sh` with the S2 prelude and a `setup_case` that also
creates `$R9700_WORK_DIR/gsm8k/test.jsonl` (empty is enough) and the stub answers of the stub series. S16's
fixture outdir is built by a helper `build_fixture_outdir <dir>` that splits `tests/fixtures/ship_test/
bench_final_ab.txt` on `c=1 r=1 Output token throughput` lines — derive the tags from the lines, never type
them.

**6. README quick start** (the three verbs only, E3 writes the rest): copy `machine.env.example` to
`machine.env` and fill it; `bin/r9700 init`; `bin/r9700 series qwen3.6-35b-a3b-gptq base ta3 --rounds 1`;
`bin/r9700 verdict <RESULTS_DIR>/<outdir>`; what a resume is (the same command again); what the exit codes
mean (S2's table, copied by reference to `research/architecture.md`, not retyped); where the records are. No
personal path: `C:\r9700\…` placeholders only.

**7. Docs.** `research/module_tests.md`: `series`, `verdict` (full), `commands`, `init`, `step` — every verb of
`bin/r9700 commands` `covered` with its scenario ids; the acceptance run as the one flow that runs on the
R9700 "before a release, by the operator's session", with its record file; *what it does not prove*: the stub
writes the quality files the container would (the real `harness.py` runs only in the acceptance), the model
listing is a stub answer, and the 27B model ran as a dry run. `research/architecture.md`: the series worker,
the record life cycle (`.part-` → validation → final, or `rejected/`), the fingerprint components, the quality
copy, and the Mermaid flow of an arm-round. `research/ACCEPTANCE_series_<date>.md` template: subject sha,
harness path (`bin/r9700`), date, the pinned variables (the model file, the arms, one round), the prediction
written BEFORE the run (for `base` vs `ta3` on the 35B: `ta3` ≈ `fcombo` of 2026-10-31, c=1 ≈ +8 tok/s, c=4 ≈
+24 tok/s, PASS expected), then the observed `verdict` output pasted, then the 27B dry run's output pasted,
and whether `wslc image inspect` exists (decision 1).

**Commands.**

```bash
node tests/run.mjs                                   # everything
node tests/run.mjs tests/test_series.sh tests/test_fingerprint.py
bash tests/check_static.sh
node .agents/conventions/tools/leftovers-check.mjs --repo . --token r9700 --identity "the R9700 vLLM tuning toolkit" --profile node
node .agents/conventions/tools/plan-lifecycle.mjs
```

Report the runner's lines for the two files and the total, the static check's exit code, and for S5 and S16
the exact output (the rejected `reason` of S5; the `ignored incomplete block` and verdict lines of S16) —
pasted, so a reviewer sees the 2026-10-31 case refused and the recorded verdict reproduced from records.

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
