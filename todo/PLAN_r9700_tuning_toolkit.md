# PLAN — a toolkit to tune vLLM on the R9700 without writing scripts

> Status: **plan only, nothing implemented yet, 2026-11-01; `review_plan` proceed (2 reviewers, 8 findings
> accepted).** Scope: this new repository — the scripts written ad hoc during the 2026-10-25..11-01 tuning
> work, made model-independent, tested and documented.

## Plan changes

> Epoch 1 · approved 2026-11-01 · by reviewers · state: open

  (note) The epoch-1 baseline includes the eight findings of the approving round, written into the
  sections below, and the epic split the gate ordered with that verdict; neither is a change entry.

## Goal

Between 2026-10-25 and 2026-11-01, tuning one model (Qwen3.6-35B-A3B GPTQ) on one GPU (AMD Radeon AI PRO
R9700, gfx1201, Windows 11 + WSL2, containers through `wslc`) took about 30 scripts, each written for that
moment: hard-coded model paths, served names, MoE shapes, arm lists, the operator's Windows paths. They
work, and the results are in `dew_flow_benchmark · research/RESULTS_vllm_029_r9700_fixes.md` and
`… _speed_options.md`. The operator wants the next model (for example Qwen3.8-27B, already on disk) tuned by
**writing one model config and running commands**, with no new script.

What must be true when this is done:

1. A model is described by one file `models/<name>.env`; the machine by one untracked `machine.env`.
2. One entry point, `bin/r9700`, runs every step that was run by hand: MoE config tuning (int4 and the BF16
   MTP draft layer; full or coarse search; merge; kernel A/B), a server-flag A/B series, the verdict (ship
   test), the linear-kernel micro-benchmark, the prefix-cache check, and an unattended driver that chains
   steps under the guards.
3. The guards that the night runs needed are built in, with the defects already found fixed: a RAM guard
   that stops the whole process group (2026-10-31: an orphan series kept loading a model), a done marker
   only for a complete arm-round (2026-10-31: a false marker), a per-round quiet-PC check, a deadline, one
   restore of the operator's server at the end.
4. Tests run without a GPU (CI) and prove those guard behaviours with stubbed `wslc`/`powershell`.
5. The repository is public and joins the dew_flow family (shared conventions on `release`).

## Inputs (verified 2026-11-01)

The source scripts, as last run (session scratchpad, backed up on the operator's machine; the published
copies are in `dew_flow_benchmark · research/vllm-r9700-speed-options/harness/`):

| Area | Scripts | Machine-specific references |
|---|---|---|
| server | `serve.sh` (22 lines), `wait_ready.sh` (14), `bench.sh` (11), `restore_server.sh` (22) | `wslc` path, image, Windows work path, start script |
| series | `speed_A.sh` (95), `night*.sh` drivers (≈56 each) | patch paths, model name defaults |
| guards | `ram_guard_all.sh` (16), `wait_quiet.sh` (13), `disk_gate.sh` (26) | none / `powershell.exe` |
| MoE | `tune_chunk.sh` (22), `merge_moe.py` / `merge_b1.py` / `merge_b2.py` (≈44 each), `moe_kernel_ab.sh` (26) + `.py` (34), `benchmark_moe.py` (1173, vLLM's script with three local hooks), `coarse_candidates.json` (82 configs) | image, Windows path |
| kernels | `linear_bench.py` (93; shapes hard-coded), `linear_bench_graph.py` (44) | none |
| quality | `harness.py` (282: 20 greedy prompts, GSM8K-200, compare), `prefixtest.py` (34) | none |

Three merge scripts that differ only in their chunk list and file name are one script with arguments
(reuse-first: widen the existing thing). `speed_A.sh`'s `case` table of arms becomes a data file.

## Design

```text
bin/r9700                      entry point: init | moe-tune | series | verdict | linear-bench | prefixtest | run
lib/                           the scripts above, model-independent (read config, never a literal model)
  serve.sh wait_ready.sh bench.sh restore.sh
  guard_ram.sh guard_quiet.sh disk_gate.sh run_guarded.sh   (setsid process group; deadline; one restore)
  series.sh                    arm-rounds, alternating, resumable, complete-round check, QUIETCHECK
  tune_chunk.sh merge_moe.py moe_kernel_ab.sh moe_kernel_ab.py
  verdict.py                   ship test: base spread = max−min of its 9 values; rule 1/2; GSM8K 2×stderr
  harness.py prefixtest.py linear_bench.py linear_bench_graph.py
vendor/benchmark_moe.py        vLLM's benchmark (Apache-2.0, header kept) + the three hooks, diff in vendor/README.md
config/arms.conf               arm -> serve args, env, mounts (base, mtp1..3, tattn, mnbt8k, fp8kv, combos)
config/coarse_candidates.json
models/qwen3.6-35b-a3b-gptq.env  models/qwen3.8-27b-awq.env   (examples, from the measured runs)
machine.env.example            wslc path, image, work dirs, restore command, RAM limit, quiet load, deadline
tests/                         pytest (python) + plain-bash tests with stub wslc/powershell
research/                      architecture.md, module_tests.md, README.md
todo/                          this plan, README.md
POST_DEPLOY.md  README.md  LICENSE  .github/workflows (family checks, tests)
```

**Lifecycle and recovery (plan-gate findings 0, 4, 6, 7).** One supervisor, the parent `bin/r9700`
process, owns the workstation lock (`flock`, one run per machine), the recovery marker, the worker's process
group and every container. Before it stops the operator's server it writes a recovery marker (what to
restore, with which command); a guard stop or the deadline kills the WORKER group (`setsid`) and stops every
container named with the fixed prefix (`machine.env: CONTAINER_PREFIX`, default `r9700tune-`), because
killing a client does not stop a detached container. The supervisor itself stays outside that group, then
restores once, waits for readiness (`/v1/models` answers and a one-token request completes, bounded), and only
then clears the marker; a restore that does not become ready is a loud failure (exit code and a line on
stderr), never silence. A run killed so hard that no cleanup ran leaves the marker: the next `bin/r9700`
invocation of any kind restores first (idempotent: a ready server is left alone). A step that exits 3 (PC not
quiet) is not a failure: the driver waits for `guard_quiet` (bounded by the deadline) and repeats the same
step. `init` removes leftover containers with the prefix.

**Config contract (finding 1).** `lib/config.sh` loads `machine.env` and `models/<name>.env` and validates
every field before anything is stopped: required keys, types (path, integer, enum), allowed values; an error
names the field and the legal values. The field list is in `research/module_config.md` (written in E1).

**Run identity (finding 2).** A series outdir carries `fingerprint.json`: a hash of the resolved effective
experiment (model files' identity, served name, image tag, mounted patches' hashes, generation config, the
arms' resolved arguments, workloads and seeds). A resume with a different fingerprint is refused. An
arm-round is complete only when its result file is written to a temporary name, validated (the expected
lines present, the server alive at the end), and renamed into place.

**MoE cache (finding 5).** The supervisor clears the Triton tuning cache after a MoE step in its exit path
too, not only at the next chunk start.

Behaviour that is kept exactly (it was measured): bench 1024/512 at c=1 (6 prompts) and c=4 (12) × 3
seeds; prefill 8192/128 and 32768/128 × 3; spec-decode metrics; round 1 adds 20 greedy prompts and
GSM8K-200; arms alternate; the operator's sampling defaults are mounted (`--generation-config`).

## Growth surfaces

| Surface | Size at the measured volumes | Who retires it | Interrupted |
|---|---|---|---|
| A series outdir (bench lines, server logs, quality json) | ≈5 MB per 3-arm 3-round series (2026-10-31: 1.5 MB data + ≈0.3 MB per server log) | kept by the operator outside the repo (`machine.env: RESULTS_DIR`); never deleted by the toolkit | resumable: done markers only for complete arm-rounds |
| MoE chunk dirs + logs | ≈1 KB JSON + ≈30 KB log per chunk | kept (they are the evidence) | a chunk dir without its JSON is deleted before a rerun (existing rule) |
| Triton tuning cache (`vllm-cache` volume) | 0.5–1.3 GB per chunk (measured) | cleared after every chunk (existing rule) | cleared at the next chunk start |
| Containers | one per step | `--rm`; the guard stops every `<prefix>-*` container | the next run's start stops leftovers by prefix |

## Build order

1. Skeleton (done: shared conventions on `release`, adapter hooks, `.agents/PROJECT.md`).
2. Config layer: `machine.env.example`, `models/*.env`, `config/arms.conf`, a loader with validation.
3. `lib/` server + guards + `run_guarded.sh`; their bash tests with stubs.
4. `series.sh` + `verdict.py`; tests from the real bench lines of 2026-10-31 (the verdict must reproduce the
   recorded one: `fcombo` passes, `fb1` and `o7` fail).
5. MoE: `tune_chunk.sh`, `merge_moe.py`, `moe_kernel_ab.*`, vendor copy; tests for merge and decision.
6. Kernels + quality scripts; `linear_bench` shapes from the model config.
7. `bin/r9700` with `run` (a plan file of steps for the unattended driver).
8. Docs (`README.md` quick start, `research/`), `POST_DEPLOY.md`, CI, licence.
9. Acceptance on the real machine (below), then publish and the family consumer row.

## Test plan

- **Unit (pytest, CI):** merge (missing chunk, duplicate key, version mismatch, expected keys); verdict on
  fixture bench files (reproduces the three recorded verdicts; the 9-value spread, not round medians);
  kernel-A/B decision rules (B1 and B2 shapes); harness compare on fixture prompt files.
- **Guards (bash, CI, stub `wslc` and `powershell.exe` on PATH):** a RAM stop kills the whole process group
  (no orphan child keeps running — the 2026-10-31 failure); a lost server leaves no done marker; a busy PC
  exits 3 and is not counted as a failure; the deadline stops the step; the restore runs exactly once.
- **Static (CI):** `bash -n` on every script, `python -m py_compile`, a check that no tracked file holds a
  personal path or account name.
- **Acceptance on the R9700 (manual, recorded in `research/`):** `r9700 series` with `base` vs `ta3`, one
  round, on the 35B model (≈40 min); `r9700 moe-tune --coarse --keys 24` + kernel A/B (≈25 min); a
  `r9700 run` plan with a forced RAM-guard limit to watch a clean stop and one restore; `r9700 prefixtest`
  and `r9700 linear-bench` once each with the 35B config, each producing its result file (finding 3).

## Definition of Done

- [ ] Every script listed in *Inputs* has a home in `lib/`, `vendor/` or `bin/`, or is named here as dropped
      with the reason.
- [ ] A model needs only `models/<name>.env`; the two example models run through `series` without edits.
- [ ] The guard tests above pass in CI; the verdict reproduces the three recorded verdicts.
- [ ] No tracked file holds a personal path, account or machine name (checked in CI).
- [ ] `README.md` quick start, `research/architecture.md`, `research/module_tests.md`, `POST_DEPLOY.md`.
- [ ] The acceptance runs on the R9700 passed and are recorded.
- [ ] The repository is public, its family checks are green, and the conventions consumer list names it.
