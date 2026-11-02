# PLAN — E2 stories: MoE config tuning on the E1 supervisor

> Status: **plan only, nothing implemented yet, 2026-11-02.** Scope: the three stories of epic E2 of
> [PLAN_r9700_tuning_toolkit.md](PLAN_r9700_tuning_toolkit.md) — section
> [E2 — MoE config tuning on the E1 supervisor](PLAN_r9700_tuning_toolkit.md#e2--moe-config-tuning-on-the-e1-supervisor).
> No cornerstone (the parent names none for E2); the ledger line stays `Cornerstones: 2 of 2`.

This document splits E2 into stories. It adds no scope to E2 and removes none. The parent plan keeps the change
ledger; this document has none of its own (plan-change-control: a stories document keeps no ledger). E1 is merged on
`main` (commit `017ed6d`); every story here builds on it and changes E1's code only where this document says so.

## Stories at a glance

| Story | Title | Spec by | Code by | Depends on | Cornerstone |
|---|---|---|---|---|---|
| E2.S1 | The pure parts: `lib/merge_moe.py` (merge and check), `lib/moe_kernel_ab.py` (table and decision), `config/coarse_candidates.json`, `vendor/benchmark_moe.py` with its hooks and README, the fixtures | Opus (this document) | Sonnet | E1 (the test base) | no |
| E2.S2 | The chunk and the kernel A/B as workers under `step_run`: records, the Triton cache cleared at every start and in the exit path (one hook in `cleanup_once`), the new config fields, the stub answers | Opus (this document) | Sonnet | E2.S1 | no |
| E2.S3 | `bin/r9700 moe-tune` (`chunk`, `merge`, `ab`), the vendored benchmark placed in the work folder, the docs, the acceptance template | Opus (this document) | Sonnet | E2.S1, E2.S2 | no |

Order: S1, then S2, then S3. S1 is the riskiest part by the parent's own words (the merge validation) and the
cheapest to test, so it goes first and alone. Every story is reviewed by Opus and fixed by Sonnet (subagent-models,
per-story pipeline).

## Coverage — every E2 item is in exactly one story

The parent's E2 *Scope* and *Done when*, item by item. Nothing below is in two stories.

| E2 item (parent plan) | Story | The other stories' part |
|---|---|---|
| `lib/merge_moe.py` — one script with arguments replacing `merge_moe.py`, `merge_b1.py`, `merge_b2.py` | S1 | S3 calls it from `moe-tune merge`; S2 calls its `check` on every chunk record |
| Merge unit tests: missing chunk, duplicate key, version mismatch, expected keys present | S1 | — |
| `lib/moe_kernel_ab.py` — the table and the decision; kernel A/B decision tests for the B1 and B2 shapes | S1 | S2 calls it at the end of an A/B unit |
| `config/coarse_candidates.json` | S1 | S2 mounts it into the chunk container |
| `vendor/benchmark_moe.py` with its header and the three hooks; `vendor/README.md` shows the diff; byte-identical to upstream outside the hooks | S1 | S3 places the file in the work folder with its hash checked |
| `lib/tune_chunk.sh` and `lib/moe_kernel_ab.sh` of the parent's design (here one file, `lib/moe.sh`: the chunk unit and the A/B unit, decision S2-1) | S2 | S3 starts them as the step of `moe-tune` |
| A chunk dir without its JSON is deleted before a rerun | S2 | — |
| The *MoE cache* paragraph: the Triton cache cleared after a MoE step in the exit path too | S2 (the hook in `cleanup_once`) | — |
| A guard stop or abort during a chunk clears the Triton cache and leaves no container with the prefix (stub test) | S2 | — |
| Growth rows *MoE chunk dirs* and *Triton tuning cache* | S2 | — |
| `bin/r9700 moe-tune` | S3 | — |
| The README section and `research/architecture.md` describe `moe-tune`, its inputs and its outputs | S3 | — |
| The acceptance run on the R9700 (`moe-tune --coarse --keys 24` and the kernel A/B), recorded in `research/` with the merged config | S3 (the template, NOT RUN — the operator holds GPU runs) | — |

Out of E2 (other epics, not to be built here): the `run` driver that chains MoE steps with series steps (E3; this
epic leaves it the same `supervise` and `step_run` contract E1 left), `linear-bench`, `prefixtest`, `POST_DEPLOY.md`,
publication.

## Facts every story uses

**Sources and their line numbers.** Cross-repository citations are paths, not links (planning-docs). Unless said
otherwise the line numbers are of the published copies in `dew_flow_benchmark · research/vllm-r9700-speed-options/harness/`
at `origin/main` (read 2026-11-02; read them with `git show`, never by a checkout in that repository):
`tune_chunk.sh` (22 lines), `merge_b1.py` (44), `merge_b2.py` (44), `moe_kernel_ab.sh` (26), `moe_kernel_ab.py` (34),
`b2.sh` (34), `speed_CB.sh` (37), `night2.sh` (53), `night3.sh` (63), `night4.sh` (49). The first merge script,
`merge_moe.py` (41 lines), is published in `vllm_pr_work · branch docs/pr-plans, research/2026-10-27_r9700_moe_tuning/harness/`,
beside `coarse_candidates.json` (82 configs) and the two-hook `benchmark_moe.py` (1169 lines) with `benchmark_moe.local.diff`.
The results are `dew_flow_benchmark · research/RESULTS_vllm_029_r9700_speed_options.md` (§ 11.4 lines 479–495, § 12.2
lines 541–551, § 13.1 lines 569–584, § 14.1 lines 699–716, the code facts at lines 322–326) and
`dew_flow_benchmark · research/RESULTS_vllm_029_r9700_fixes.md` § 3 *How we tuned it* (lines 150–171) and § 5.2 (lines 306–312).
The data: `research/vllm-r9700-speed-options/night-2026-10-31/phaseB1_kernel_ab/` and `night-2026-11-01/phaseB2/`.

**How a chunk ran** (`tune_chunk.sh`, read whole):

| Lines | What it does now | What E2 keeps or changes |
|---|---|---|
| 2, 8 | a chunk is done only when `E=*.json` exists in its folder; a done chunk is skipped | kept: a final record is the marker (S2 decision 3) |
| 3, 9 | a chunk folder without JSON is a half-written chunk and is `rm -rf`-ed before the run | kept, on the exchange folder only (S2 decision 3) |
| 4, 12–13, 17 | `TUNE_DTYPE` (default `int4_w4a16`) is `--dtype`; `TUNE_ACT=bfloat16` sets `MOE_TUNE_ACT_DTYPE` (a local hook); `CANDIDATES` sets `MOE_TUNE_CANDIDATES` | `--layer experts\|draft`, `--coarse` (S2 decision 2) |
| 6–7 | the work folder, the `wslc` path, the image and the Windows path are literals | config: `WORK_DIR`, `WORK_DIR_WIN`, `IMAGE`, the adapter |
| 10, 22 | the disk gate before and after the chunk | E1's `disk_gate_check` before the unit; the gate at the end as `series_main` does |
| 14–18 | `run --rm --name vllmprtest-moe-tune-<name> --gpus all --shm-size 16g -e HIP_VISIBLE_DEVICES=0 [-e MOE_TUNE_CANDIDATES=…] [-e MOE_TUNE_ACT_DTYPE=…] -e TRITON_CACHE_DIR=/root/.cache/vllm/triton-moe-tune -v hf-cache:/root/.cache/huggingface -v vllm-cache:/root/.cache/vllm -v <moe folder>:/moe -w /moe <image> python3 benchmark_moe.py --model <model dir> --tp-size 1 --dtype <dtype> --tune --batch-size <keys> --save-dir /moe/tune/<name> --trust-remote-code`, output to `<name>.log` | the same argv through `wslc_run_once`, the folder under `/work` (S2 decision 2) |
| 19–21 | prints `chunk <name> (bs …): rc=<rc>, <seconds> s, json: <file>` and greps `Start tuning\|Tuning space\|Completed tuning\|Best config\|Kernel time\|Error\|Traceback` | the line goes to `chunk.env`; the grep stays as the log summary |

**How the chunks were driven** (`speed_CB.sh` lines 10–11, 22, 26, 29–36; `night2.sh` lines 29–33, 48–49; `b2.sh`
lines 14–32): one chunk per call, each under the RAM guard, the cache cleared after every chunk and after a failed one
(`clear_cache`: a container with only the `vllm-cache` volume runs
`du -sh /root/.cache/vllm/triton-moe-tune; rm -rf /root/.cache/vllm/triton-moe-tune`, `b2.sh` line 21); the draft
layer with `TUNE_DTYPE=auto TUNE_ACT=bfloat16` (`speed_CB.sh` line 22); the coarse chunk with
`CANDIDATES=/moe/coarse_candidates.json` (line 30; `b2.sh` line 25); a RAM-guard stop retried once (`b2.sh` lines
24–27); the chunks ran while the PC was busy (`night2.sh` line 4: "runs that load no model go on meanwhile") — E2
runs them under E1's quiet wait instead (S2 decision 5).

**How the kernel A/B ran** (`moe_kernel_ab.sh`, `moe_kernel_ab.py`, read whole): the operator's server stopped first
(line 13); for rep 1 2 3, for arm `default` then `tuned` (line 14): the disk gate (15), a container
`vllmprtest-moeab-<arm>-<rep>` under `timeout 1800` with `benchmark_moe.py` WITHOUT `--tune`, `--dtype $AB_DTYPE`,
`--batch-size $AB_BS`, `TRITON_CACHE_DIR=/root/.cache/vllm/triton-moe-ab`, and for the tuned arm
`VLLM_TUNED_CONFIG_FOLDER=$AB_B`, for the default arm `VLLM_TUNED_CONFIG_FOLDER=$AB_A` only when `AB_A` is set (lines
16–23); the log with CRs removed (23); a count of `Kernel time` lines (24). The decision program (`moe_kernel_ab.py`)
reads `*-[123].log`, the regex `Batch size: (\d+), config: (.*)\nKernel time: ([\d.]+) us` (line 14), the median per
batch size and arm (20), the change in percent (21), the table line `f"{bs:>2}  {d:10.2f}  {t:8.2f}  {gain:+6.1f} %   n={…}/{…}"`
(22), one `<arm> bs <n> config: <dict>` line per batch size (23–25), and two rules: B1 — every one of bs 1 and 4
faster by more than 3 % (33); B2 — the median change over 24, 32, 64, 128 below −3 % and no tested batch size slower
by more than 3 % (29–30). B1 ran with `AB_DTYPE=auto AB_ACT=bfloat16 AB_B=/moe/tune/merged_b1` and no `AB_A`
(default = vLLM's own config); B2 with `AB_DTYPE=int4_w4a16 AB_ACT= AB_A=/moe/tune/merged AB_B=/moe/tune/merged_b2
AB_BS="8 16 20 24 32 48 64 96 128 192 256"` (`b2.sh` lines 31–32).

**How the merges ran** (`merge_moe.py` lines 10–37, `merge_b1.py` lines 11–40, `merge_b2.py` lines 12–40): a fixed
chunk list, a fixed `EXPECTED` key set, `FIELDS = {BLOCK_SIZE_M, BLOCK_SIZE_N, BLOCK_SIZE_K, GROUP_SIZE_M, num_warps,
num_stages}`, a fixed output `NAME`; per chunk: read `<tune dir>/<chunk>/<NAME>`, pop `triton_version` and refuse a
mismatch, refuse a duplicate key and a config missing a field; refuse `set(keys) != EXPECTED`; write
`{"triton_version": …, "<bs>": …}` in numeric key order with `json.dumps(indent=4) + "\n"`. `merge_b2.py` reads the
production file as one more source (line 19); `merge_b1.py` copies the int4 file beside the BF16 output (line 39), so a
server pointed at the folder keeps it. Checked 2026-11-02: that output rule reproduces both published merged files byte
for byte — `merged_b1` from its five chunk key groups, `merged_b2` from the 9-key production file plus keys 24, 32,
64, 128 (scenarios M1 and M2 rest on this).

**The chunk JSON** (`benchmark_moe.py` `save_configs`, lines 768–798 of the two-hook copy): the file name comes from
vLLM's `get_config_file_name(E, N, dtype string, block shape)` — `E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json`
for the int4 experts and `E=256,N=512,device_name=AMD_Radeon_R9700.json` for the BF16 draft (§ 11.4 lines 481–484;
the data files). The toolkit never builds that name: it reads it back from the chunk folder (`ls E=*.json`,
`tune_chunk.sh` lines 8 and 20). The content is `{"triton_version": "<triton.__version__>", "<batch size>": {…}}`
(line 797), one key per `--batch-size` value, each config holding the six fields above plus, on ROCm, `waves_per_eu`
and, for int4, `SPLIT_K` (set to 1 during tuning, lines 1067–1071 of the copy). Keys are strings of the batch sizes
in the order given on the command line (`sort_config`, lines 1099–1101).

**Timing and size (measured, so the ceilings and the acceptance estimate have a base):**

| What | Measured | Where |
|---|---|---|
| int4 full search, one key | bs 1 (pilot, 304 configs) ≈ 28 min; bs 2 / 4 / 8 / 12 / 16: 58 / 83 / 142 / 140 / 214 min | fixes § 3 table (lines 156 and 158) |
| int4 full search at bs 24 | ≈ 11 h estimated (2,100 configs at ≈ 19.5 s); stopped after 1 h 43 min | § 14.1 lines 701–702 |
| int4 coarse, 82 candidates | keys 256 1024 2048: 24 min; keys 24 32 64 128 (`int4-coarse-mid`): 1,244 s | fixes line 157; § 14.1 line 703, `b2.log` line 5 |
| BF16 draft (pruned space) | bs 1: 298 s, bs 2: 309 s (352 configs), coarse 256/1024/2048: 374 s, bs 4: 1,554 s (1,000 configs), bs 12: 2,511 s (1,580) | § 11.4 lines 488–490, § 12.2 lines 545–546 |
| one kernel A/B container (100 iterations, no `--tune`) | B1: 6 containers in 17:55:16–17:58:40 (≈ 40 s each); B2: 6 in 11:57:08–12:01:39 (≈ 50 s each) | `phaseB1_kernel_ab/summary.log` lines 2–18; `phaseB2/b2_kernel_ab.log` lines 2–18 |
| Triton tuning cache after one coarse chunk | 1.3 GB (`du -sh` before the clear) | `b2.log` line 6; the parent's growth row says 0.5–1.3 GB |
| the A/B log | 22 lines (8 batch sizes) and 28 lines (11 batch sizes), ≈ 3 KB | the data files |
| the end of a chunk log | three harmless `ImportError: sys.meta_path is None` tracebacks after `Completed tuning` and the saved JSON | § 11.4 lines 493–494; `b2_tune.log` lines 4–9 |

**The decision rules and the recorded decisions the tests reproduce:**

| Run | Keys measured | Rule | Table (median of 3, µs: default / tuned / change) | Decision |
|---|---|---|---|---|
| B1 (draft, `--dtype auto`, default config against `merged_b1`) | 1 2 3 4 6 8 12 16 | each of bs 1 and 4 faster by more than 3 % | 1: 77.97 / 70.67 / −9.4 %; 2: 230.20 / 195.61 / −15.0; 3: 318.32 / 274.61 / −13.7; 4: 392.72 / 352.51 / −10.2; 6: 545.59 / 505.72 / −7.3; 8: 692.88 / 656.17 / −5.3; 12: 900.45 / 868.86 / −3.5; 16: 1110.13 / 1081.88 / −2.5 | **faster** (`summary.log` lines 19–32, `decision.txt`) |
| B2 (int4, production file against `merged_b2`) | 8 16 20 24 32 48 64 96 128 192 256 | median change over 24 32 64 128 below −3 % and no size slower by more than 3 % | 8: 275.84 / 276.83 / +0.4; 16: 442.56 / 442.15 / −0.1; 20: 502.56 / 502.75 / +0.0; 24: 563.24 / 566.89 / +0.6; 32: 671.37 / 671.81 / +0.1; 48: 819.88 / 819.60 / −0.0; 64: 910.24 / 910.39 / +0.0; 96: 1005.15 / 1002.58 / −0.3; 128: 1044.79 / 1043.21 / −0.2; 192: 1073.96 / 1075.23 / +0.1; 256: 1094.44 / 1096.96 / +0.2 | **not faster** (median change at 24/32/64/128: +0.0 %) (`b2_kernel_ab.log` lines 19–53) |

**The vendored benchmark — provenance.** Upstream: vLLM `main` commit `2c880f1e68200f79c4663dd0f1e7beab6f536cfa`,
file `benchmarks/kernels/benchmark_moe.py`, 1169 lines, sha256
`8e4d60d12f5ccee9a5b66fe7b50bba7a9525b7edea0b6750eb9d46d71f788f83` (fixes line 150 names the commit; the hash was
computed 2026-11-02 from a vLLM checkout). Its header is `# SPDX-License-Identifier: Apache-2.0` and
`# SPDX-FileCopyrightText: Copyright contributors to the vLLM project` (lines 1–2) — kept. The hooks:

| Hook | Where (two-hook copy) | What | Source |
|---|---|---|---|
| 1 — no `HIP_VISIBLE_DEVICES` → `ROCR_VISIBLE_DEVICES` rename | main, the 9 lines after `use_deep_gemm = …` replaced by a 4-line comment | Ray 2.59 in the image refuses `ROCR_VISIBLE_DEVICES`; without `HIP_VISIBLE_DEVICES` Ray also schedules the iGPU | `benchmark_moe.local.diff` hunk 1; fixes lines 163–167 |
| 2 — `MOE_TUNE_CANDIDATES` | main, 5 lines after `search_space = get_configs_compute_bound(…)`: when set, the JSON list in that file replaces the search space (the ROCm pruning still applies) | the coarse search | hunk 2; fixes lines 168–170 |
| 3 — `MOE_TUNE_ACT_DTYPE` | `resolve_dtype` (lines 924–926: on ROCm the activations are forced to `float16`): `bfloat16` makes it return `torch.bfloat16` | the BF16 draft layer | § 11.4 line 481, speed-options lines 324–326 (the plan-gate finding) |

**FACT (hook 3), verified 2026-11-02 by the main session.** The published copy has hooks 1 and 2 only (sha256
`a47c4e1bd55c269164612dca92966970c99da694985669afa0c905b42e515539`, 1169 lines). The copy that ran the B1 chunks and
the B2 run holds all three: it is `<WORK_DIR>/moe/benchmark_moe.py` on the operator's PC, 1173 lines, sha256
`1584d339831452d4a568091e4d2a573dfed10200b04bdb4b49add37242698640`, and it contains `MOE_TUNE_ACT_DTYPE`. The S1
coder vendors THIS file byte for byte (the main session gives its path); S1 decision 5's reconstruction fallback is
not needed and stays only as the rule for a machine where that file is gone.

**Fixtures** (copy byte for byte with `git -C <benchmark checkout> show origin/main:<path> > <target>`; the two
`vllm_pr_work` files from that repository's `docs/pr-plans` branch the same way):

| Source | Target | Content |
|---|---|---|
| `night-2026-10-31/phaseB1_kernel_ab/default-{1,2,3}.log`, `tuned-{1,2,3}.log` | `tests/fixtures/moe/b1_ab/<same name>` | 22 lines each; 8 `Kernel time` lines |
| `night-2026-10-31/phaseB1_kernel_ab/summary.log` lines 19–32 | `tests/fixtures/moe/b1_ab/expected.txt` | the table, the config lines, `B1 KERNEL: faster` (the last line is replaced by the new decision line, scenario K1) |
| `night-2026-10-31/phaseB1_kernel_ab/merged_b1_E=256,N=512,device_name=AMD_Radeon_R9700.json` | `tests/fixtures/moe/b1/E=256,N=512,device_name=AMD_Radeon_R9700.json` | 7 keys, `triton_version` 3.8.0 |
| `night-2026-11-01/phaseB2/kernel_ab/default-{1,2,3}.log`, `tuned-{1,2,3}.log` | `tests/fixtures/moe/b2_ab/<same name>` | 28 lines each; 11 `Kernel time` lines |
| `night-2026-11-01/phaseB2/b2_kernel_ab.log` lines 19–53 | `tests/fixtures/moe/b2_ab/expected.txt` | as above, `B2 KERNEL: not faster (…)` replaced (K2) |
| `night-2026-11-01/phaseB2/merged_b2_E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json` | `tests/fixtures/moe/b2/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json` | 13 keys |
| `vllm_pr_work · research/2026-10-27_r9700_moe_tuning/config/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json` | `tests/fixtures/moe/b2_base/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json` | the 9-key production file of 2026-10-27, sha256 `072d25060edbc1b3c5d1ad6caaec59d7d6db99bb4208a14a49a1a9f565537839` |
| `vllm_pr_work · research/2026-10-27_r9700_moe_tuning/harness/coarse_candidates.json` | `config/coarse_candidates.json` | 82 configs, sha256 `d23483de2f75986046f3d36817cefa6cd3ea4a787a5b9c3c6ad2cee556d79273` |

Scanned 2026-11-02 for personal paths and names: none of these files holds one (they carry container paths such as
`/root/.cache/huggingface/local/…` and `/moe/tune/merged_b1/…`). `phaseB2/b2.log` and `b2_tune_ramguard.log` are NOT
copied: `b2.log` holds the operator's paths. The fixture file names hold `=` and `,`; git, the runner and pytest take
them as they are, and the tests never type the name — they list `E=*.json`, as the product does.

**What E2 reuses from E1, by name** (the contracts; read the E1 document's amendments A1–A24 before writing code —
they are hard-won rules and nothing here re-invents them): `supervise <verb> <prepare> <body>` and `step_run <label>
-- <cmd…>` (A5: one supervisor, one restore at the end); the worker started as `setsid lib/worker_gate.sh … 9>&-`
(A1, A2: descriptor 9 only in the lock owner) and stopped by SESSION (A8); every adapter call under a ceiling and cut
at `R9700_T_STOP` (A9, decision 8), the cleanup phase without it; the typed outcome KINDs `worker | ram_guard |
disk_gate | deadline | interrupted | refused` and the exit table of decision 6 (`refused` from A16: the worker's own
word, never a bare exit code); `R9700_TIME_SCALE`, `R9700_CEILING_SCALE`, `R9700_QUIET_CHECKS` and `stop_in` for
timing-safe tests (A3, A10, the `stepcase.sh` helpers); the stubs (decision 12, A4: a container is a `setsid sleep`
recorded with its start ticks, killed by its owner); `container_name <label>`, `wslc_run_once <ceiling> <args…>`,
`wslc_list`, `wslc_stop`, `wslc_logs`, `disk_gate_check`, `quiet_check`, `outcome_write`, `rg_log`, `t_scale`,
`t_ceiling`, `_rg_run`; the record shape of E1.S3 decision 3 (`<name>.part-<run id>` → validated → `mv -T` → final,
or `rejected/<name>-<stamp>/` with a `reason`); A16's cheap re-check before every unit; A22's restore retries; the
flow catalogue derived from `bin/r9700 commands` (L18). The test frameworks and the leftovers rules are E1's
(`tests/run.mjs`, `tests/lib/assert.sh`, `R9700_TEST_ROOT`, the token `r9700`); no new runner, no `mktemp`.

**Public repository.** No personal path, account name, machine name or token in any tracked file; the machine's
values live only in the untracked `machine.env`. The MoE scripts under `lib/` may not hold the words `wslc`,
`powershell` or `pwsh` as command words or assignments (`tests/check_static.sh --seam`): every call goes through the
adapter's functions.

---

## E2.S1 — The pure parts: merge and check, the A/B table and decision, the candidates, the vendored benchmark

**Cornerstone:** no. **Depends on:** E1 (the test base). **Spec:** this section (Opus). **Code:** one Sonnet coder.

### Goal

Three merge scripts that differed only in their chunk list and file name become one `lib/merge_moe.py` with
arguments, which also owns the ONE definition of a valid chunk file (`check`) that S2's record uses. `moe_kernel_ab.py`
becomes `lib/moe_kernel_ab.py`, which reproduces the recorded B1 and B2 tables exactly and decides by a named rule.
The coarse candidates and the vendored benchmark are tracked with their provenance, and a test proves the vendored
file is upstream plus the three hooks and nothing else.

### Files

| File | What |
|---|---|
| `lib/merge_moe.py` | `check` (one chunk file against its promised keys) and `merge` (chunk records and an optional base into one file) |
| `lib/moe_kernel_ab.py` | `decide` (the table, the config lines, the decision line, the exit code) |
| `config/coarse_candidates.json` | the fixture table's copy, unchanged |
| `vendor/benchmark_moe.py` | upstream `2c880f1e6` + the three hooks |
| `vendor/hooks.diff` | the unified diff upstream → vendored (three hunks, each marked `LOCAL CHANGE`) |
| `vendor/UPSTREAM` | three lines: `commit=2c880f1e68200f79c4663dd0f1e7beab6f536cfa`, `path=benchmarks/kernels/benchmark_moe.py`, `sha256=8e4d60d12f5ccee9a5b66fe7b50bba7a9525b7edea0b6750eb9d46d71f788f83` |
| `vendor/README.md` | provenance, the licence (Apache-2.0, the same as the repository's), the three hooks explained one by one, the diff embedded verbatim in one fenced block |
| `tests/test_merge_moe.py`, `tests/test_moe_kernel_ab.py`, `tests/test_candidates.py` | the scenarios below (pytest) |
| `tests/test_vendor.sh` | V1–V5 (bash: `patch` and `sha256sum`) |
| `tests/fixtures/moe/…` | the fixture table above |
| `research/module_tests.md` | the new rows of the flow catalogue; `research/README.md` unchanged |

### Boundaries

- In: everything a chunk JSON, an A/B log folder or the vendored file can be checked for without a container.
- Out: any `wslc` call, any record directory, any config field (S2); the verb and the docs of `moe-tune` (S3).
- `lib/merge_moe.py` and `lib/moe_kernel_ab.py` are stdlib-only Python ≥ 3.10 (they also run in the image's 3.14 if
  ever needed), like `lib/verdict.py`; functions under 50 lines; no literal model, device or file name — the file
  name is always read from the inputs.

### Decisions

**1. One merge with the chunk list as arguments, the expected keys as the union of promises.** `merge_moe.py merge
--out <dir> [--base <file>] [--expect "<keys>"] <chunk dir>…`. A chunk dir is a record directory holding exactly one
`E=*.json` (read back, never typed) and, when present, a `chunk.env` (S2 decision 3) with `KEYS=` and the identity
words. The merge refuses, with exit 2 and one `merge: ` line each (all problems in one pass, as the config loader):
a chunk dir without a JSON (`missing chunk: <dir> has no E=*.json`), a dir with two, a JSON that does not parse
(`<file>: not JSON (<reason>)`), a missing `triton_version`, a `triton_version` unlike the first (`triton_version
mismatch in <dir>: <v> vs <first>`), a key that is not a positive integer, a duplicate key across inputs (`duplicate
key <bs> in <dir> (first in <dir>)`), a config missing a field (`key <bs> in <dir> misses [<fields>]`), chunk file
names that differ (`file names differ: <a> vs <b>` — two layers can never be merged into one file), and an identity
word of `chunk.env` (`IMAGE`, `MODEL_DIR`, `DTYPE`, `LAYER`) that differs between chunks. The expected set is: the
base's keys plus every chunk's `KEYS=` promise; `--expect` replaces it. `set(keys) != expected` is refused with both
sets printed, so a chunk that delivered fewer keys than it promised is caught — the generalised form of the fixed
`EXPECTED` sets (`merge_b1.py` line 12, `merge_b2.py` line 13). The output is `{"triton_version": v, "<bs>": …}` in
numeric key order, `json.dumps(indent=4) + "\n"` (the sources' line 36–38), written to `<out>/<NAME>` with `.part` +
`os.replace`, never over an existing file (`merge: <out>/<NAME> exists; merges are append-only, choose another --out`),
and the last stdout line is `wrote <out>/<NAME>: triton <v>, keys [<sorted ints>]` (line 40). Rejected: a `--copy`
of other files into the output folder (`merge_b1.py` line 39) — in E2 a model's merged folder holds every layer's
file side by side (S2 decision 4), so there is nothing to copy.

**2. `check` is the ONE definition of a valid chunk file.** `merge_moe.py check --keys "<keys>" <file>`: the same
parse as `merge` on one file, then `set(keys) == set(--keys)`; exit 0, or 1 with the first problem on stdout (the
record's `reason`, as `verdict.py check-block` is for a bench block). Extra fields (`waves_per_eu`, `SPLIT_K`) pass:
the fields set is a lower bound (`FIELDS <= cfg.keys()`, the sources' line 31).

**3. The decision is a rule with its keys, and the arithmetic is exact.** `moe_kernel_ab.py decide <dir> --keys
"<bs…>" --rule each|median --rule-keys "<bs…>" [--reps 3] [--threshold 3]`: reads `default-<n>.log` and
`tuned-<n>.log` for n in 1..reps with the regex of the source (line 14); refuses (exit 2) a missing log, a log with a
batch size outside `--keys`, a batch size of `--keys` that an arm has fewer than `reps` values for (`incomplete: tuned
bs 24 has 2 of 3 values`), and a rule key outside `--keys`. Prints the table of the source (lines 18–22) with the
header `bs  default_us  tuned_us  change   (median of reps)`, then the config lines (23–25), then ONE decision line:
`KERNEL: faster|not faster (<why>)`. Numbers are `decimal.Decimal` parsed from the text; the median over Decimals;
`gain = (t − d) / d × 100`; printed with `+6.1f` (Decimal formats with its sign, so `-0.0` prints as the source did);
compared unrounded against the threshold, strict (`gain < −3`, `gain > 3`, the source's lines 30 and 33). Rule
`each`: every rule key's gain `< −threshold` → `faster (each of <keys> is faster by more than 3 %)`; else `not faster
(bs <k>: <gain> % is not below -3 %)` naming the first that is not. Rule `median`: the median of the rule keys' gains
`< −threshold` AND no key of `--keys` with `gain > threshold` → `faster (median change at <keys>: <m> %; no size
slower by more than 3 %)`; else `not faster (median change at <keys>: <m> %)` or `not faster (median change at <keys>:
<m> %; bs <k> is slower by <gain> %)`. Exit 0 faster, 1 not faster. Why Decimal: `(97.00 − 100.00) / 100.00 × 100`
is `-3.0000000000000004` in binary float, which a float comparison calls "faster" at exactly −3 % (scenario K7 is
named for it). Why one threshold: 3 % is the figure of both recorded rules (`moe_kernel_ab.sh` line 5); it is an
argument so a plan file can name another, with the default 3.

**4. The candidates file is tracked as data, with its shape asserted.** 82 entries: the 81 of
`BLOCK_SIZE_M/N/K ∈ {32, 64, 128} × num_warps ∈ {2, 4, 8}` with `GROUP_SIZE_M 1, num_stages 2, waves_per_eu 0`, plus
the batch-size-1 winner of 2026-10-26 (`16/16/64, 1 warp, waves_per_eu 4`) — counted 2026-11-02 from the file;
fixes lines 169–170 describe it so. A test derives the product and asserts the file equals it plus one named extra;
nobody retypes 82 rows.

**5. The vendored file is upstream plus the diff, proven by `patch -R`.** `vendor/benchmark_moe.py` is the
three-hook copy from the operator's backup (*Facts*, the fact to verify) when the main session hands it over; the
coder diffs it against upstream `2c880f1e6` (a `git show` from any vLLM checkout, or the file fetched by commit) and
writes `vendor/hooks.diff` from that diff, checking it holds exactly the three hooks and that each hunk's added
lines carry `LOCAL CHANGE`. **If the backup cannot be found**, the coder starts from the published two-hook copy,
writes hook 3 as the smallest change that makes `resolve_dtype` return `torch.bfloat16` when
`MOE_TUNE_ACT_DTYPE=bfloat16` on ROCm (a comment line `# LOCAL CHANGE (…): MOE_TUNE_ACT_DTYPE=bfloat16 tunes the
draft layer with BF16 activations`, then the two code lines), marks it `reconstructed` in `vendor/README.md`, and the
acceptance of S3 is where its effect is observed (a draft-layer chunk is not in the acceptance; the README says the
hook is unobserved until one runs). The test (V1) does not need vLLM: `patch -R -o - vendor/benchmark_moe.py
vendor/hooks.diff | sha256sum` must equal `vendor/UPSTREAM`'s hash — upstream is never in this repository, only its
hash. Companions (testing: a structural test that matches nothing passes forever): the diff applies (`patch --dry-run`
exit 0), it has exactly three hunks (`grep -c '^@@'`), and `grep -c '^+.*LOCAL CHANGE'` is 3.

### Test scenarios

Python scenarios in `tests/test_merge_moe.py` (M), `tests/test_moe_kernel_ab.py` (K), `tests/test_candidates.py`
(C); bash in `tests/test_vendor.sh` (V). `run(args)` is E1's helper (a subprocess with `sys.executable`, returns exit
code, stdout, stderr). `B1 = fixtures/moe/b1`, `B2 = fixtures/moe/b2`, `BASE = fixtures/moe/b2_base`, `AB1 =
fixtures/moe/b1_ab`, `AB2 = fixtures/moe/b2_ab`. "A chunk dir built from a merged fixture for keys K" is a directory
the test writes under its basetemp with one file of the fixture's own name holding `{"triton_version": <the fixture's>,
<the fixture's entries for K>}` — the chunk files of 2026-10-28..11-01 are not published, and this is exactly how the
merged files were made (*Facts*). Test names state the guarantee.

**Merge (`tests/test_merge_moe.py`)**

1. *The five B1 chunk groups merge into the published `merged_b1` byte for byte.* Chunk dirs built from `B1` for
   `256 1024 2048`, `1`, `2`, `4`, `12` (the groups of `merge_b1.py` line 11): `merge --out <tmp>/m <dirs…>` exits 0;
   `<tmp>/m/E=256,N=512,device_name=AMD_Radeon_R9700.json` (the name read back by listing `E=*.json`) equals the fixture
   byte for byte; stdout's last line is `wrote …: triton 3.8.0, keys [1, 2, 4, 12, 256, 1024, 2048]`.
2. *The 9-key production file plus the coarse chunk gives the published `merged_b2` byte for byte.* `--base
   BASE/<its file>` and one chunk dir built from `B2` for `24 32 64 128`: the output equals the `B2` fixture.
3. *A chunk dir without its JSON is a missing chunk.* An empty dir among the inputs: exit 2, stderr `merge: missing
   chunk: <dir> has no E=*.json`; no output file, no `.part`.
4. *A duplicate key is refused naming both chunks.* Two chunk dirs that both hold key 4: exit 2, `duplicate key 4 in
   <second> (first in <first>)`.
5. *A `triton_version` mismatch is refused.* One chunk with `"triton_version": "3.7.0"`: `triton_version mismatch in
   <dir>: 3.7.0 vs 3.8.0`.
6. *A config missing a field is refused naming the fields.* A chunk whose key 2 lacks `num_warps` and `num_stages`:
   `key 2 in <dir> misses ['num_stages', 'num_warps']`.
7. *Extra fields pass.* The `B2` fixture's configs carry `waves_per_eu` and `SPLIT_K`: scenario 2 passes (the positive
   for the same validator as 6).
8. *Keys not delivered are refused against the promise.* A chunk dir with `chunk.env` `KEYS="24 32 64 128"` whose
   JSON holds 24, 32, 64 only: exit 2, `keys [1, 2, 4, 8, 12, 16, 24, 32, 64, 256, 1024, 2048] != expected [… 128 …]`
   (both lists printed in full). The same inputs with `--expect "1 2 4 8 12 16 24 32 64 256 1024 2048"`: exit 0 (the
   explicit set wins).
9. *Two layers can never be merged into one file.* A `B1` chunk dir and a `B2` chunk dir: exit 2, `file names differ:
   E=256,N=512,device_name=AMD_Radeon_R9700.json vs E=256,…,dtype=int4_w4a16.json`.
10. *A chunk tuned on another image is refused.* Two chunk dirs whose `chunk.env` `IMAGE=` lines differ: exit 2,
    `IMAGE differs: <dir a> <value a> vs <dir b> <value b>`; with equal lines, exit 0.
11. *All problems are reported in one pass.* A dir with a duplicate key AND a chunk with a bad version: two `merge: `
    lines on stderr, exit 2.
12. *Merges are append-only.* Run scenario 1 twice into the same `--out`: the second exits 2 with `exists; merges are
    append-only`, and the first output is byte-identical to before (mtime unchanged).
13. *The write is atomic.* `--out` pointing at a file (not a directory): exit 2; no `.part` anywhere under the parent.
14. *`check` accepts a complete chunk file and names the first problem of a bad one.* `check --keys "24 32 64 128"
    <the chunk file of scenario 2>`: exit 0, no output. `check --keys "24 32 64 128 256"` on it: exit 1, stdout
    `keys [24, 32, 64, 128] != expected [24, 32, 64, 128, 256]`. A file whose key 24 lacks `BLOCK_SIZE_K`: exit 1, `key
    24 in <file> misses ['BLOCK_SIZE_K']`. A file that is not JSON: exit 1, `<file>: not JSON (…)`.
15. *A key that is not a batch size is refused.* A chunk with the key `"abc"`: exit 2, `key "abc" in <dir> is not a
    positive integer`.
16. *The commands are catalogued.* The subcommands of `merge_moe.py`'s parser (`check`, `merge`) each have a `covered`
    row in `research/module_tests.md` (the E1 derivation: parsed from the markdown, never a typed list).

**Kernel A/B (`tests/test_moe_kernel_ab.py`)**

1. *The B1 table and decision are reproduced exactly.* `decide AB1 --keys "1 2 3 4 6 8 12 16" --rule each --rule-keys
   "1 4"`: exit 0; stdout equals `AB1/expected.txt` line for line. The fixture's last line (`B1 KERNEL: faster`) is
   replaced by `KERNEL: faster (each of 1 4 is faster by more than 3 %)` when the fixture is made; `expected.txt`
   holds no comment (a comment would break the equality), the fixtures table of `research/module_tests.md` says it.
2. *The B2 table and decision are reproduced exactly.* `decide AB2 --keys "8 16 20 24 32 48 64 96 128 192 256" --rule
   median --rule-keys "24 32 64 128"`: exit 1; stdout equals `AB2/expected.txt`, whose last line is `KERNEL: not faster
   (median change at 24 32 64 128: +0.0 %)`; the `48` row prints `-0.0 %` as the source did.
3. *Rule `each` fails on the first key that is not faster, naming it.* `AB1` with `--rule-keys "1 16"` (bs 16 is
   −2.5 %): exit 1, `KERNEL: not faster (bs 16: -2.5 % is not below -3 %)`.
4. *Rule `median` is refused by one size that is slower by more than the threshold.* Synthetic logs (a helper writes
   `default-<n>.log` / `tuned-<n>.log` with `Batch size: <bs>, config: {}` / `Kernel time: <µs> us` pairs from a table
   of values): rule keys at −10 %, bs 8 at +3.01 %: exit 1, `KERNEL: not faster (median change at 24 32: -10.0 %; bs 8
   is slower by 3.0 %)`; with bs 8 at +3.00 %: exit 0, `KERNEL: faster (median change at 24 32: -10.0 %; no size slower
   by more than 3 %)`.
5. *An arm short of a rep is incomplete, not a decision.* `AB1` with `tuned-3.log` removed: exit 2, stderr
   `incomplete: tuned bs 1 has 2 of 3 values` (the first key in `--keys` order); no `KERNEL:` line on stdout.
6. *A batch size the logs do not hold is refused, and a rule key outside the keys too.* `--keys "1 2 99"`: exit 2,
   `incomplete: default bs 99 has 0 of 3 values`. `--rule-keys "5"` with `--keys "1 4"`: exit 2, `rule key 5 is not in
   --keys`.
7. *Named for the refuted approach:* `test_float_arithmetic_would_call_exactly_minus_3_percent_faster_and_that_is_the_point`
   — synthetic logs with default 100.00 and tuned 97.00 at every rep for one key, rule `each`: the test asserts that
   `(97.0 - 100.0) / 100.0 * 100 < -3` is `True` in float (the refuted approach) and that `decide` prints `not faster
   (bs 1: -3.0 % is not below -3 %)`; with tuned 96.99: `faster`.
8. *The median of three reps is the middle value, not the mean.* Synthetic: default 100, 100, 100; tuned 90, 97, 97 at
   one key, rule `each` over it: the table shows `97.00` and `-3.0 %`, decision not faster (the mean, 94.67, would
   have passed).
9. *`--reps` and `--threshold` are read.* `--reps 2` over `AB1` (the `-3` logs are ignored): exit 0 and the table says
   `n=2/2`. `--threshold 10` on `AB1`, rule each over `1 4`: exit 1, `KERNEL: not faster (bs 1: -9.4 % is not below
   -10 %)` (bs 4 at −10.2 % would pass; bs 1 does not).
10. *A log line that is not a measurement is ignored; a malformed kernel time is refused.* The fixture logs hold Ray
    and warning lines before the pairs (scenario 1 passes over them). A log with `Kernel time: abc us`: exit 2,
    `<file>:<line>: not a kernel time`.
11. *The config lines follow the table in arm, then batch-size order.* In scenario 1's output the first config line is
    `default bs 1 config: {'BLOCK_SIZE_M': 16, 'BLOCK_SIZE_N': 64, …}` and the last is `tuned bs 16 config: …` (the
    source's lines 23–25; the dict text is the log's text, copied, not re-serialised).
12. *The commands are catalogued* (as M16, for `decide`).

**Candidates (`tests/test_candidates.py`)**

1. *The file is the 81-config product plus the batch-size-1 winner.* Parse `config/coarse_candidates.json`; build the
   product of decision 4 in the test; assert every product entry is in the file, the file has 82 entries, and the one
   entry outside the product is `{BLOCK_SIZE_M 16, BLOCK_SIZE_N 16, BLOCK_SIZE_K 64, GROUP_SIZE_M 1, num_warps 1,
   num_stages 2, waves_per_eu 4}`.
2. *Every candidate passes the merge's field check.* For every entry, `FIELDS <= entry.keys()` with `FIELDS`
   imported from `lib/merge_moe.py` (not retyped).
3. *The file's hash is the published one.* sha256 equals `d23483de…` (so a silent edit is a red test, and a deliberate
   one updates the test with its reason).

**Vendor (`tests/test_vendor.sh`)**

1. *The vendored file is upstream plus the hooks.* `patch -R -o - vendor/benchmark_moe.py vendor/hooks.diff |
   sha256sum` equals the `sha256=` line of `vendor/UPSTREAM`; `patch --dry-run -R vendor/benchmark_moe.py
   vendor/hooks.diff` exits 0.
2. *The diff is alive: three hunks, each a marked local change.* `grep -c '^@@' vendor/hooks.diff` is 3 and
   `grep -c '^+.*LOCAL CHANGE' vendor/hooks.diff` is 3; the three environment names `MOE_TUNE_CANDIDATES`,
   `MOE_TUNE_ACT_DTYPE` and `HIP_VISIBLE_DEVICES` each appear in an added line.
3. *The README embeds the diff verbatim.* The text between the ```` ```diff ```` fence that follows the heading
   `## The diff` and the next fence in `vendor/README.md` equals `vendor/hooks.diff` byte for byte.
4. *The licence header is kept.* Lines 1–2 of `vendor/benchmark_moe.py` are the two SPDX lines of *Facts*.
5. *The vendored file compiles.* `tests/check_static.sh --python vendor/benchmark_moe.py` exits 0 (the static check's
   Python pass already runs over every tracked `.py`; this names it).

### Brief for the Sonnet coder

Read first: this section; the E1 document's S1 brief for `lib/verdict.py` (the Decimal rules, the `.part` +
`os.replace` write, `run(args)` in the tests) and its *Test frameworks* and *Test leftovers* paragraphs; *Facts every
story uses* above. The source scripts are given to you by the main session (the published ones are listed there; the
three-hook `benchmark_moe.py` comes from the operator's backup). Do not touch `lib/*.sh`, `bin/r9700` or the stubs.

**1. `lib/merge_moe.py`** — `check` and `merge` of decisions 1 and 2. Parse: `pathlib`, `json`; a chunk dir's file is
`sorted(dir.glob("E=*.json"))` and must be exactly one; `chunk.env` (when present) is read with the config grammar
(`^([A-Z][A-Z0-9_]*)=(.*)$`, bare or double-quoted values, never `source`d). Collect problems in a list and print them
all (`merge: <problem>`), exit 2. Output: `.part` then `os.replace`; refuse an existing target BEFORE writing the
part. Keep `FIELDS` as a module constant with a comment naming `merge_moe.py` line 12 of the source.

**2. `lib/moe_kernel_ab.py`** — `decide` of decision 3. The regex of the source's line 14 compiled once; every number
a `Decimal`; the table format strings copied from the source's lines 18 and 22 (the `n=` part counts the values
found); the config lines as lines 23–25. Rules in two functions, `rule_each(gains, rule_keys, threshold)` and
`rule_median(gains, keys, rule_keys, threshold)`, each returning `(faster: bool, why: str)`; the decision line is
built from that pair only.

**3. `config/coarse_candidates.json`, `vendor/`** — the fixture table, decision 5. `vendor/README.md` sections: *What
this is* (upstream commit, path, hash, licence), *The three hooks* (one paragraph each: what, why, where, the source
of the fact), *The diff* (the fenced block), *How it is used* (S3 places it under `WORK_DIR/r9700/`, the container
runs it from `/work/r9700`), *Verified on the machine* (empty until the acceptance; names hook 3 as observed or not).

**4. Tests** — the scenarios above; fixtures from the table (copy with `git show`, never by hand); the synthetic log
helper of K4 writes files with the exact two-line shape of the source. For K1 and K2 the `expected.txt` files are the
source's output with the last line replaced as the scenarios say; record in `research/module_tests.md` (the fixtures
table) that this is the only edit.

**5. Docs.** `research/module_tests.md`: the three new test files in *Where it is*, the fixture folder `tests/fixtures/moe/`
with its provenance, the catalogue rows `lib/merge_moe.py check`, `lib/merge_moe.py merge`, `lib/moe_kernel_ab.py
decide`, `config/coarse_candidates.json`, `vendor/benchmark_moe.py` (covered by `tests/test_vendor.sh`), and under
*what it does not prove*: the benchmark is never run in CI; hook 3 is known by its effect only until the acceptance.

**Commands.**

```bash
node tests/run.mjs tests/test_merge_moe.py tests/test_moe_kernel_ab.py tests/test_candidates.py tests/test_vendor.sh
node tests/run.mjs                                   # everything
bash tests/check_static.sh
node .agents/conventions/tools/leftovers-check.mjs --repo . --token r9700 --identity "the R9700 vLLM tuning toolkit" --profile node
node .agents/conventions/tools/plan-lifecycle.mjs
```

Report the runner's lines and the total, the static check's exit code, and paste the output of K1 and K2 (the
recorded tables reproduced) and of V1 (the upstream hash matched).

---

## E2.S2 — The chunk and the kernel A/B as workers under the E1 supervisor

**Cornerstone:** no. **Depends on:** E2.S1 (`check`, `decide`, the candidates, the vendored file). **Spec:** this
section (Opus). **Code:** one Sonnet coder.

### Goal

`lib/moe.sh` runs ONE tuning chunk or ONE kernel A/B as a worker that `step_run` starts, under every guard E1 has,
and records the result only when it is complete and valid, atomically. The Triton tuning cache is cleared before
every unit and, by the supervisor, in the exit path of the invocation — on a normal end, a guard stop, the deadline
and an interrupt alike. The config gains the MoE fields. A guard stop during a chunk leaves no prefixed container
and clears the cache, and the stub tests prove it without a GPU.

### Files

| File | What |
|---|---|
| `lib/moe.sh` | sourced functions AND an executable worker (`[[ "${BASH_SOURCE[0]}" == "$0" ]] && moe_main "$@"`, the shape of `lib/series.sh`): `moe_main chunk …`, `moe_main ab …`, `moe_cache_clear`, `moe_sweep_parts`, the record functions |
| `lib/run_guarded.sh` | gains `cleanup_hook_set <function>` and ONE call site in `cleanup_once` (decision 6); nothing else changes |
| `lib/config.sh`, `machine.env.example`, `models/*.env` (comment lines only), `research/module_config.md` | the fields of decision 7 and the changed budget rule |
| `tests/stubs/wslc` | the foreground `run --rm --name <name>` answers of decision 9 |
| `tests/test_moe.sh` | T1–T18 |
| `tests/lib/moecase.sh` | the helpers of T1–T18 (`moe_setup`, `moe_step`, `moe_supervise`, the answers) |
| `research/architecture.md`, `research/module_tests.md` | the module, the record life cycle, the hook, the knobs, the scenarios |

### Boundaries

- In: the chunk unit (`tune_chunk.sh` lines 8–22 as a worker), the A/B unit (`moe_kernel_ab.sh` lines 14–26 as a
  worker), the cache clear (`b2.sh` line 21) at every unit start and in the exit path, the chunk and A/B records,
  the half-written chunk rule, the growth rows *MoE chunk dirs* and *Triton tuning cache*, the stub answers.
- In: the one hook in `cleanup_once`, the one new cross-field rule of the budget (decision 6).
- Out: the verb and its argument grammar, the placement of the vendored file into `WORK_DIR` (S3) — S2's tests place
  the file themselves. Out: merging (S1 + S3). Out: the quiet wait, the admission, the restore (E1, unchanged).

### Source facts (verified 2026-11-02)

| Source | Lines | What it does now | What E2 must change |
|---|---|---|---|
| `tune_chunk.sh` | 8–9 | a done chunk is skipped on its JSON; a chunk folder without JSON is deleted before the run | the record is `<outdir>/chunks/<chunk>/` (final only when valid); the exchange folder `tune/<chunk>/` under `/work` is deleted before every run (decision 3) |
| `tune_chunk.sh` | 14–18 | the container argv (*Facts*) | through `wslc_run_once`; the names `moe-tune-<chunk>` through `container_name`; the paths under `/work/r9700/` |
| `tune_chunk.sh` | 19–21 | rc, seconds, the JSON name, the log summary | `chunk.env` and `chunk.summary` in the record |
| `b2.sh` | 21, 29, 26 | the cache cleared after a chunk and after a failed one, by a container with only the cache volume | cleared BEFORE every unit (the worker) and in `cleanup_once` (the hook) — the parent's finding 5 |
| `b2.sh` | 24–27 | a RAM-guard stop retried once | E1's `MAX_FAILED_TRIES` (default 3; each retry is one admission) |
| `b2.sh` | 8 | "no deadline (tuning loads no model weights)" | E1's deadline always holds: a chunk is cut at `T_STOP` by the adapter (A9) and the deadline watcher; the operator sizes `MAX_RUN_MINUTES` for a long search (decision 5) |
| `moe_kernel_ab.sh` | 13 | `wslc stop vllm` by the script | gone: the admission of `step_run` stops the server once |
| `moe_kernel_ab.sh` | 14–25 | 3 reps × (default, tuned), the disk gate before each container, `timeout 1800`, the log with CRs removed, a count of kernel times | kept as the A/B unit; the gate through `disk_gate_check`; 1800 s through `t_ceiling`; the count is the validation |
| `moe_kernel_ab.sh` | 26 | the decision program over the folder | `moe_kernel_ab.py decide` (S1) at the end of the unit; its output is `summary.txt`, its last line `decision.txt` |
| `night2.sh` | 4, 29–33, 48–49 | chunks ran while the PC was busy; one chunk at a time by an expected-seconds table against the deadline; a chunk that stopped is not retried that night | E2: one chunk per invocation, under the quiet wait; no expected-seconds table (decision 5) |
| `speed_CB.sh` | 22, 30 | the draft layer: `TUNE_DTYPE=auto TUNE_ACT=bfloat16`; the coarse chunk: `CANDIDATES=/moe/coarse_candidates.json` | `--layer draft`, `--coarse` (decision 2) |
| `b2.sh` | 31–32 | the A/B's A arm is the production file, B the merged file, keys `8 16 20 24 32 48 64 96 128 192 256`, rule b2 | A = the model's `TUNED_CONFIG_DIR` when set, B = the model's merged exchange folder (decision 4) |
| RESULTS § 14.1 | 713–716 | the coarse search picked the same tile at every key; nothing to test end to end | the acceptance prediction (S3) |

### Decisions

**1. One file, two units, no second lifecycle.** `lib/moe.sh` holds both workers because they share the container
argv builder, the record functions and the cache clear (the parent's `tune_chunk.sh` and `moe_kernel_ab.sh` names
are the parent's design list; a reader finds them in the module table of `research/architecture.md` as the two units
of `lib/moe.sh`). A worker is started by `step_run moe-chunk -- bash lib/moe.sh chunk <outdir> <model name> <chunk>
<layer> <search> <keys…>` or `step_run moe-ab -- bash lib/moe.sh ab <outdir> <model name> <layer> <rule>
"<rule keys>" <reps> "<keys>"`; it never stops the operator's server, sets no trap, takes no lock (the supervisor
owns all three). Its exit codes: 0 done; 1 the unit failed (a rejected record — a failed try for the supervisor); 2
with the outcome `KIND=refused` when the identity check fails (A16); a disk-gate stop writes `KIND=disk_gate` and
exits 1 (the series' shape). No exit 3 (the supervisor's quiet wait runs before every admission; a unit is one
container run, so no second check inside) and no exit 4 (a chunk's duration is unknown before it runs; the deadline
watcher ends it — decision 5).

**2. The chunk unit.** Inputs: `<layer>` is `experts` (`--dtype $R9700_MOE_DTYPE`, no activation hook) or `draft`
(`--dtype auto` and `-e MOE_TUNE_ACT_DTYPE=bfloat16`, the literals of `speed_CB.sh` line 22 with their origin in a
comment); `<search>` is `full` or `coarse` (`-e MOE_TUNE_CANDIDATES=/work/r9700/coarse_candidates.json`); `<keys>`
are 1..20 positive integers, each at most 65536, given once. The exchange folder is `$R9700_WORK_DIR/r9700/moe/<model>/`
(container path `/work/r9700/moe/<model>/`; `WORK_DIR` and `WORK_DIR_WIN` are one folder, E1.S1): the chunk's
save-dir is `tune/<chunk>/` under it, `rm -rf`-ed and re-made before the run (`tune_chunk.sh` line 9: a half-written
chunk is deleted — it holds no evidence, the log is elsewhere). The container: `container_name "moe-tune-<chunk>"`
(so the chunk name is `^[a-z0-9][a-z0-9-]{0,30}$`, which keeps the label at most 40), argv = `tune_chunk.sh` lines
14–17 with `--gpus all --shm-size 16g -e HIP_VISIBLE_DEVICES=0 [the two optional -e] -e
TRITON_CACHE_DIR=/root/.cache/vllm/triton-moe-tune -v $R9700_HF_VOLUME:/root/.cache/huggingface -v
$R9700_CACHE_VOLUME:/root/.cache/vllm -v $R9700_WORK_DIR_WIN:/work -w /work/r9700 $R9700_IMAGE python3
benchmark_moe.py --model $R9700_MODEL_DIR --tp-size 1 --dtype <dtype> --tune --batch-size <keys…> --save-dir
/work/r9700/moe/<model>/tune/<chunk> --trust-remote-code`, run as `wslc_run_once "$R9700_MOE_CHUNK_MAX_S" … >
<part>/chunk.log` (foreground: the worker's session holds the client, and the guards stop the container by name
anyway). Before the run: `moe_cache_clear`; the identity check (decision 8); `disk_gate_check`. After it: `chunk.env`
(`CHUNK`, `LAYER`, `SEARCH`, `KEYS`, `DTYPE`, `ACT_DTYPE`, `CANDIDATES_SHA256` (empty for full), `BENCHMARK_SHA256`
(of the placed file), `IMAGE`, `MODEL_DIR`, `CONTAINER`, `RUN_ID`, `STARTED_AT`, `FINISHED_AT`, `SECONDS`, `RC`),
`chunk.summary` (the grep of `tune_chunk.sh` line 21, `tail -n 6`), the JSON copied from the exchange folder
(`cp`, then the exchange copy stays until the next run deletes it), then validation: (a) `RC=0`; (b) exactly one
`E=*.json`; (c) `python3 lib/merge_moe.py check --keys "<keys>" <json>` exits 0 (the ONE definition of valid, S1
decision 2); (d) `chunk.log` is non-empty. Then `mv -T <part> chunks/<chunk>` (E1.S3 decision 3). A failed
validation: `rejected/<chunk>-<stamp>/` with `reason` (`rc=137` / `check: keys [24] != expected [24, 32]` / …), exit 1.
The `ImportError: sys.meta_path is None` tracebacks at the end of a log (*Facts*) are not a failure: the rule is the
exit code and the JSON, never a grep for `Traceback` (reliability: typed outcomes, not message substrings).

**3. The chunk record is the marker; the exchange folder is scratch.** `<outdir>/chunks/<chunk>/` exists only when
complete; in flight it is `<outdir>/chunks/<chunk>.part-<run id>/`. `moe_sweep_parts` at every worker start moves a
stale `.part-` directory to `rejected/` with the reason `INTERRUPTED: …` (the `series_sweep_parts` shape, kept as
evidence — the log of a chunk the deadline cut is the thing a person wants to see). The exchange folder's
`tune/<chunk>/` is deleted before every run (decision 2) — the parent's done-when "a chunk dir without its JSON is
deleted before a rerun" names THIS folder; the record folders are never deleted. A chunk whose record exists is not
run again: the verb (S3) counts it before admission; the worker, started by a plan file that did not look, skips it
with `chunk <name>: recorded, nothing to do` and exit 0. Rejected: a done marker file (E1.S3 decision 3's reason) and
re-running a recorded chunk under a new name by default (a person who wants a second search names the chunk).

**4. The A/B unit.** `<layer>` picks `--dtype` (as decision 2) and the activation hook for the containers; the B arm
is `-e VLLM_TUNED_CONFIG_FOLDER=/work/r9700/moe/<model>/merged` (the exchange folder's `merged/`, which S3's `merge`
fills; the worker refuses with `KIND=refused` when it holds no `E=*.json` for the layer's name — the name is read
from `chunks/*/` or, when there is no chunk, from `merged/` itself: it is whatever file is there, never typed); the A
arm is `-e VLLM_TUNED_CONFIG_FOLDER=$R9700_TUNED_CONFIG_DIR` when the field is set, else no folder (vLLM's own
config — B1's shape; B2's shape when set, `b2.sh` line 31). The record `<outdir>/ab/<stamp>.part-<run id>/` → `ab/<stamp>/`
holds `default-<rep>.log`, `tuned-<rep>.log` (CRs removed, `moe_kernel_ab.sh` line 23), `ab.env` (`LAYER`, `DTYPE`,
`ACT_DTYPE`, `KEYS`, `RULE`, `RULE_KEYS`, `REPS`, `A_FOLDER`, `B_FOLDER`, `B_SHA256` (of the merged file), `IMAGE`,
`MODEL_DIR`, `BENCHMARK_SHA256`, `RUN_ID`, `STARTED_AT`, `FINISHED_AT`), `summary.txt` (the stdout of `decide`) and
`decision.txt` (its last line). The containers: `container_name "moe-ab-<arm>-<rep>"`, the same argv as decision 2
without `--tune` and `--save-dir`, `-e TRITON_CACHE_DIR=/root/.cache/vllm/triton-moe-ab`, under `wslc_run_once
"$(t_ceiling 1800)"` (line 19); `disk_gate_check` before each (line 15); the order rep-major, default then tuned
(line 14). Validation: each log holds exactly `len(keys)` `Kernel time` lines (line 24's count, made a rule), then
`decide` exits 0 or 1 — both are a complete record (a "not faster" is a result, § 14.1); exit 2 of `decide` or a
short log → `rejected/ab-<stamp>/` with the reason, worker exit 1.

**5. Under the guards as E1 runs them, with two named differences from the night drivers.** (a) The quiet wait: the
drivers ran chunks on a busy PC because a model-loading A/B was waiting for quiet and the GPU would otherwise idle
(`night2.sh` line 4); the toolkit has one lifecycle, and that lifecycle waits for quiet before it stops the operator's
server. A person who wants to tune on a busy PC raises `QUIET_LOAD_MAX` or sets `QUIET_BUSY_PATTERN` empty — knobs
that exist. Kernel timings taken on a busy PC are noisy (speed-options § 6.4), so for the A/B this is the better
rule anyway. (b) The deadline: a full search at one key took up to 214 min (int4 bs 16) and was estimated at 11 h for
bs 24; with the default `MAX_RUN_MINUTES` 720 and `CLEANUP_BUDGET_S` 1560, `T_STOP` is about 11.6 h after the start,
and the chunk's own ceiling `MOE_CHUNK_MAX_S` (default 43200 = 12 h) is cut to that by A9. A chunk the deadline ends
is `KIND=deadline`, exit 6, the `.part-` goes to `rejected/` at the next start with its log, and the next run deletes
the exchange copy: nothing is lost but the GPU hours, which is the sources' rule too (`night2.sh` line 32: a stopped
chunk is not retried that night). The README (S3) tells the operator to set `MAX_RUN_MINUTES` (up to 2880) and
`MOE_CHUNK_MAX_S` for a full search. Rejected: an expected-seconds table per chunk (`night2.sh` line 30 — numbers for
one model, wrong for the next) and exempting MoE steps from the deadline (`b2.sh` line 8 — a chunk that is never
ended is a wait without a ceiling).

**6. The cache clear: before every unit by the worker, in the exit path by ONE hook.** `moe_cache_clear` is
`wslc_run_once "$(t_ceiling 60)" --name "$(container_name moe-clear)" -v "$R9700_CACHE_VOLUME:/root/.cache/vllm"
"$R9700_IMAGE" sh -c 'du -sh /root/.cache/vllm/triton-moe-tune /root/.cache/vllm/triton-moe-ab 2>/dev/null; rm -rf
/root/.cache/vllm/triton-moe-tune /root/.cache/vllm/triton-moe-ab'` (`b2.sh` line 21, both cache folders, a name so a
hung clear is stopped by prefix like any container; the program text holds no variable — plan-gate E1 finding 1).
Its output is logged as `cache before clear: <du lines>`. The worker calls it before every unit (parent: "cleared at
the next chunk start"). The EXIT PATH: `lib/run_guarded.sh` gains `cleanup_hook_set <function name>` (one variable,
`_RG_CLEANUP_HOOK`, reset by `supervise`) and `cleanup_once` calls the function once, after `container_stop_all` and
before `restore_now`, logging `cleanup hook: <name> rc=<n>`; a non-zero return is logged and never changes the
cleanup's result (the restore must run whatever the clear did). The hook runs in the cleanup phase — no
`R9700_T_STOP`, its own 60 s ceiling + 5 s grace. `verb_moe_tune` (S3) registers `moe_cache_clear` before
`supervise`; S2's tests register it the same way through `supervise` directly. **The budget rule follows:** the
cleanup is sized by `CLEANUP_BUDGET_S ≥ READY_TIMEOUT_S + 300` (A13: restore start 125 s + one container's tail and
stop 130 s + grace 10 s + margin); 65 s more need the rule `≥ READY_TIMEOUT_S + 360`, the default `CLEANUP_BUDGET_S`
1560 (was 1500) and the cap of `READY_TIMEOUT_S` 3240 (was 3300; 3240 + 360 = 3600, the budget's own cap). This is a
default of E1's field changed for E2's design item (the parent's *MoE cache* paragraph), done as E1.S2 did its own
(the loader, the example, `research/module_config.md` and the E1 tests that state the default — `tests/test_config.sh`
scenario 1 and the cross-field case, `tests/test_steps.sh`'s `1500` — updated in S2's commit); it is not a change of
the parent plan (the parent names no number). Rejected: running the clear concurrently with the restore (less
budget, but concurrency inside the one cleanup path is the kind of thing the restore protocol was built to not
have), and a clear that runs only after a successful unit (the parent's finding 5 names the exit path).

**7. The fields.** New, in `lib/config.sh`'s table, `machine.env.example` and `research/module_config.md`:

| Scope | Key | Type and legal values | Default | Replaces |
|---|---|---|---|---|
| model | `MOE_DTYPE` | enum `auto,fp8_w8a8,int8_w8a16,int4_w4a16,none` | `int4_w4a16` | `tune_chunk.sh` line 4 (`TUNE_DTYPE`), `benchmark_moe.py` line 1155 (the `--dtype` choices); `none` says the model has no MoE layers: `moe-tune` refuses before admission (S3) |
| machine | `MOE_CHUNK_MAX_S` | integer 600..86400 | `43200` | new: the ceiling of one chunk container (the longest measured chunk was 214 min; a full bs-24 search was estimated at 11 h) |
| machine | `CLEANUP_BUDGET_S` | unchanged type; cross-field `≥ READY_TIMEOUT_S + 360` | `1560` (was 1500) | decision 6 |
| machine | `READY_TIMEOUT_S` | integer 60..3240 (was 3300) | `1200` | decision 6 |

The two example model files gain one comment line each (`# MOE_DTYPE=int4_w4a16`, the default) and no value; E1's
"both example files run `series` unedited" keeps holding (scenario 2 of E1.S1 derives from `models/*.env`). The
draft layer's activation dtype (`bfloat16`) and the two cache folder names are constants in `lib/moe.sh` with their
origin, not fields: no source varied them. Question for the acceptance, not for the build: whether the 27B example
model has MoE layers at all is unknown to this document (UNVERIFIED); if it has none, its file gets `MOE_DTYPE=none`
in the acceptance record's deviations, and until then `moe-tune` on it would fail at the benchmark's
`get_model_params` (a failed try, loudly).

**8. The identity check of a unit (A16's shape).** Before the container starts, the worker checks: the placed
`$R9700_WORK_DIR/r9700/benchmark_moe.py` has the sha256 of `vendor/benchmark_moe.py`; for a coarse chunk,
`$R9700_WORK_DIR/r9700/coarse_candidates.json` has the sha256 of `config/coarse_candidates.json`; for an A/B, the
B folder holds a file of the layer's name. A difference writes `KIND=refused` with the `fingerprint differs`-style
line (`moe: benchmark_moe.py in the work folder differs from vendor/ (<old> -> <new>)`) and exits 2: the supervisor
stops at once (no retry, one restore). The hashes are recorded in `chunk.env` / `ab.env`, so a merge of chunks
tuned by two different benchmark copies is refused by S1's identity words. Why the worker and not only the verb: one
`step_run` can restart the worker after a failed try, hours later (A16's reason).

**9. The stubs.** `tests/stubs/wslc`: a foreground `run --rm` WITH `--name <name>` (the chunk, the A/B and the clear
containers; the fingerprint's throwaway run has no name and keeps its E1 answer) records `containers/<name>.pid` with
the stub's own pid and start ticks for its duration and removes it at the end, so `wslc list` shows it while it runs
and `wslc stop <name>` ends it. UNVERIFIED for a foreground `run --rm`: the old scripts stopped such containers by
name only through the guards (`ram_guard_all.sh` lines 11–12 over `list`), and nobody has observed whether a
foreground run is listed; the stub follows the detached container's known behaviour, and the acceptance (S3) watches
a real `wslc list` during a chunk. The answers:
`python3 benchmark_moe.py … --tune … --save-dir <dir>` → sleep `answers/moe_tune_seconds` (default 0), then write
`<dir translated from /work/ to $R9700_WORK_DIR/>/<name of answers/moe_json>` with the content of
`answers/moe_json` (the test writes a complete chunk file there, built from a fixture for the asked keys; a missing
answer writes nothing — the half-written case), print `answers/moe_tune_log` (default: three lines ending with
`Completed tuning for batch_size=<k>`), exit `answers/moe_tune_rc` (default 0); without `--tune` → sleep
`answers/moe_ab_seconds`, print `answers/moe_ab.<arm>` where `<arm>` is the word after `moe-ab-` in the name
(`default` or `tuned`); `sh -c 'du -sh … rm -rf …'` → print `answers/moe_cache` (default one line `1.3G
/root/.cache/vllm/triton-moe-tune`). Every answer file is read from `$R9700_STUB_DIR` only.

### Test scenarios

`tests/test_moe.sh` (bash; the E1 preamble through `tests/lib/stepcase.sh`: stubs first on `PATH`, `R9700_STATE_DIR`,
`R9700_STUB_DIR`, `R9700_TIME_SCALE=100`, `R9700_CEILING_SCALE=10`, `R9700_QUIET_CHECKS=1`, the machine fixture, the
35B model file, the operator's server running, the stub `trap`). `moe_setup` also writes the placed files
(`$R9700_WORK_DIR/r9700/benchmark_moe.py` as a copy of `vendor/benchmark_moe.py`, the candidates copy) and the stub
answers (`moe_json` = a chunk file built from `tests/fixtures/moe/b2` for the asked keys, `moe_ab.default` /
`moe_ab.tuned` = `tests/fixtures/moe/b1_ab/default-1.log` / `tuned-1.log`). "A stub chunk" is `bin/r9700 step
moe-chunk --model <35B> -- bash lib/moe.sh chunk $OUT qwen3.6-35b-a3b-gptq int4-24 experts full 24` with `OUT =
$R9700_RESULTS_DIR/moe-qwen3.6-35b-a3b-gptq`; "a stub A/B" is `… step moe-ab -- bash lib/moe.sh ab $OUT
qwen3.6-35b-a3b-gptq draft each "1 4" 3 "1 2 3 4 6 8 12 16"` with `$R9700_WORK_DIR/r9700/moe/<model>/merged/` holding
the `b1` fixture file. The hook scenarios use `moe_supervise`, a helper that sources `bin/r9700`'s libraries, calls
`cleanup_hook_set moe_cache_clear` and `supervise moe prepare_run <body>` with a body of one `step_run` (the E1 L22
shape). Leftovers: everything under `R9700_TEST_ROOT`; stub pids killed by the trap; the token `r9700`.

1. *A chunk is recorded only when its JSON passes `check`, and the record carries the identity.* A stub chunk: exit
   0; `chunks/int4-24/` exists with `E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json` (listed, not
   typed), `chunk.log`, `chunk.summary`, `chunk.env` with `KEYS=24`, `LAYER=experts`, `SEARCH=full`,
   `DTYPE=int4_w4a16`, `BENCHMARK_SHA256=` equal to `sha256sum vendor/benchmark_moe.py`, `IMAGE=` the fixture's,
   `RC=0`, `STARTED_AT ≤ FINISHED_AT`; no `.part-` remains; `python3 lib/merge_moe.py check --keys 24 <json>` exits 0;
   the operator's server was stopped once and restored once (`stop vllm` once, `pwsh.exe` once).
2. *The container argv is the measured one.* The call log's `run --rm --name r9700tune-moe-tune-int4-24` line holds,
   in order, `--gpus all --shm-size 16g -e HIP_VISIBLE_DEVICES=0 -e TRITON_CACHE_DIR=/root/.cache/vllm/triton-moe-tune
   -v hf-cache:/root/.cache/huggingface -v vllm-cache:/root/.cache/vllm -v C:\r9700\work:/work -w /work/r9700
   rocm/vllm:rocm10.1.0_ubuntu24.04_py3.14-pytorch_2.13.0_vllm-0.29.0 python3 benchmark_moe.py --model
   /root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ --tp-size 1 --dtype int4_w4a16 --tune --batch-size 24
   --save-dir /work/r9700/moe/qwen3.6-35b-a3b-gptq/tune/int4-24 --trust-remote-code` and no `MOE_TUNE_` word (the
   parity check against `tune_chunk.sh` lines 14–17; the argv compared as an array through `calls.argv`).
3. *The draft layer and the coarse search set exactly their two environment words.* `… chunk $OUT <model> draft-c
   draft coarse 256 1024 2048` with `moe_json` built from the `b1` fixture: the `run` line holds `-e
   MOE_TUNE_ACT_DTYPE=bfloat16`, `-e MOE_TUNE_CANDIDATES=/work/r9700/coarse_candidates.json`, `--dtype auto`,
   `--batch-size 256 1024 2048`; the record's JSON is `E=256,N=512,device_name=AMD_Radeon_R9700.json`; `chunk.env` has
   `CANDIDATES_SHA256=` equal to the file's. With `experts full`: neither `-e MOE_TUNE_` word appears (the negative
   with the same fixture).
4. *The cache is cleared before the unit, by a prefixed container with only the cache volume.* In scenario 1's call
   log, a `run --rm --name r9700tune-moe-clear -v vllm-cache:/root/.cache/vllm <image> sh -c …` line whose program
   holds both `rm -rf /root/.cache/vllm/triton-moe-tune` and `triton-moe-ab` precedes the `moe-tune-int4-24` run; the
   worker log holds `cache before clear: 1.3G`; the argv has no `--gpus`.
5. *A half-written chunk is deleted before the run, and the record is rejected with its log.* `answers/moe_json`
   absent (the stub writes nothing), `moe_tune_rc` = 0: the worker exits 1; `rejected/int4-24-<stamp>/` holds
   `chunk.log` and a `reason` starting `check: ` or `no E=*.json`; `chunks/int4-24/` does not exist; the exchange
   folder `$R9700_WORK_DIR/r9700/moe/<model>/tune/int4-24/` is empty; with `MAX_FAILED_TRIES=1` the supervisor exits 7
   and restored once. Then, with the answer present, the same command: exit 0, the record exists — and the exchange
   folder was re-made (the call log's `run` line is the same; the `rejected/` entry is still there).
6. *A chunk that delivered fewer keys than promised is rejected by `check`, naming the sets.* `moe_json` holding key
   24 only for a `… 24 32` chunk: `rejected/int4-24-32-*/reason` holds `keys [24] != expected [24, 32]`.
7. *A non-zero container exit is a rejected chunk, never a record.* `moe_tune_rc` = 1 with a good `moe_json`: no
   record, `reason` starts `rc=1`; `chunk.env` in the rejected folder has `RC=1`.
8. *A recorded chunk is not run again.* After scenario 1, the same stub chunk: exit 0, stdout `chunk int4-24: recorded,
   nothing to do`, the call log has no second `moe-tune-int4-24` run, the record's mtime is unchanged. (The worker's
   skip; the verb's pre-admission count is S3's U-scenario.)
9. *A RAM stop during a chunk leaves no prefixed container, no worker process, and clears the cache in the exit
   path.* `answers/moe_tune_seconds` = 100 (the stub sleeps), `answers/ram` = `8000` then `100`, `MAX_FAILED_TRIES=1`,
   through `moe_supervise`: exit 7; the outcome `KIND=ram_guard`; after the exit `wslc list` (the stub) shows no
   `r9700tune-` name and `containers/r9700tune-moe-tune-int4-24.pid` is gone; no process of the worker's session is
   left; in the call log, AFTER the `stop r9700tune-moe-tune-int4-24` line and BEFORE the `pwsh.exe` line there is a
   `run --rm --name r9700tune-moe-clear …` line; the supervisor log has `cleanup hook: moe_cache_clear rc=0`; the
   `.part-` directory is in `rejected/` after the NEXT worker start (scenario 10). (The parent's done-when: a guard
   stop or abort during a chunk clears the Triton cache and leaves no container with the prefix.)
10. *A stale part directory is evidence, not a record.* After scenario 9, a stub chunk: its first stdout lines include
    `moe: int4-24.part-<old run id> moved to rejected/int4-24-<stamp>` with the old `chunk.log` inside; then the
    chunk runs and is recorded.
11. *An interrupt clears the cache once, and the second signal does not run it again.* `moe_tune_seconds` = 100;
    `TERM` to the supervisor after the chunk container is listed (bounded poll on the pid file), then a second `TERM`
    0.2 s later: exit 143; exactly one `moe-clear` run line after the `stop` of the chunk container; `pwsh.exe` once;
    the marker is gone.
12. *The hook never blocks the restore.* `answers/moe_cache` absent and the stub's `mode` file set to `hang` by the
    test's `on-stop-r9700tune-moe-tune-int4-24` script (so only the calls after the stop hang), `R9700_CEILING_SCALE=100`:
    the clear is ended by its 60 s / 100 ceiling, the supervisor log has `cleanup hook: moe_cache_clear rc=124`, the
    restore still ran (`pwsh.exe` once), exit 7 (the RAM stop of scenario 9's shape), and no stub sleeper is alive.
13. *The deadline ends a chunk and the part becomes evidence.* The short variant of E1's G5 (`MAX_RUN_MINUTES=10`,
    `CLEANUP_BUDGET_S=420`, `READY_TIMEOUT_S=60` — the new rule 60 + 360 holds), `moe_tune_seconds` = 100: exit 6,
    `KIND=deadline`; the chunk container is stopped (its pid file gone); the exit-path clear ran; the next start moves
    the part to `rejected/` with `reason` `INTERRUPTED: …`.
14. *The A/B records six logs, the table, and the decision; the arms get the measured folders.* A stub A/B with
    `TUNED_CONFIG_DIR` empty in a model variant: exit 0; `ab/<stamp>/` holds `default-1..3.log`, `tuned-1..3.log`
    (each 22 lines, CRs removed), `summary.txt` equal to `tests/fixtures/moe/b1_ab/expected.txt`, `decision.txt` =
    `KERNEL: faster (each of 1 4 is faster by more than 3 %)`, `ab.env` with `B_FOLDER=/work/r9700/moe/qwen3.6-35b-a3b-gptq/merged`,
    `A_FOLDER=` empty, `B_SHA256=` equal to the merged fixture's, `RULE=each`, `RULE_KEYS="1 4"`; the call log shows
    six `run --rm --name r9700tune-moe-ab-<arm>-<rep>` lines in the order default-1, tuned-1, default-2, …, each with
    `-e TRITON_CACHE_DIR=/root/.cache/vllm/triton-moe-ab`, `--dtype auto`, `-e MOE_TUNE_ACT_DTYPE=bfloat16`, no `--tune`;
    the tuned lines hold `-e VLLM_TUNED_CONFIG_FOLDER=/work/r9700/moe/qwen3.6-35b-a3b-gptq/merged` and the default
    lines no `VLLM_TUNED_CONFIG_FOLDER`; a `disk` answer was read before each container (six `Get-WinEvent` calls after
    the admission's baseline). With the unedited 35B model (`TUNED_CONFIG_DIR=/work/moe/tune/merged`): the default lines
    hold `-e VLLM_TUNED_CONFIG_FOLDER=/work/moe/tune/merged` (B2's shape, `b2.sh` line 31).
15. *A short log makes no A/B record.* `moe_ab.tuned` = the fixture's `tuned-1.log` without its last two lines (7
    kernel times): worker exit 1, `rejected/ab-<stamp>/reason` = `tuned-1.log: 7 kernel times, expected 8`, no
    `ab/<stamp>/`; the three default logs and the one short tuned log are in the rejected folder.
16. *An A/B without a merged file is refused before any container, and `step` stops at once.* The merged folder
    empty: the worker exits 2 with the outcome `KIND=refused` and `DETAIL` holding `merged/ holds no E=*.json`;
    the supervisor exits 2 after one admission (no retry), restored once; no `moe-ab-` run in the call log.
17. *A changed placed benchmark is refused by the identity check.* Append a byte to
    `$R9700_WORK_DIR/r9700/benchmark_moe.py` before a stub chunk: `KIND=refused`, `DETAIL` holds
    `benchmark_moe.py in the work folder differs from vendor/`, exit 2, no `moe-tune-` run.
18. *The new fields load, are documented, and the budget rule moved.* `config_load` with the machine fixture:
    `R9700_MOE_CHUNK_MAX_S=43200`, `R9700_MOE_DTYPE=int4_w4a16`, `R9700_CLEANUP_BUDGET_S=1560`; a variant
    `CLEANUP_BUDGET_S=1559`: exit 2, `CLEANUP_BUDGET_S: 1559 is less than READY_TIMEOUT_S 1200 + 360`; `READY_TIMEOUT_S=3241`:
    exit 2 with the range `60..3240`; `MOE_DTYPE=int4`: exit 2 naming the five legal values; `MOE_CHUNK_MAX_S=599`:
    exit 2. E1's scenario 17 (every field documented) keeps passing because it derives from `config_keys`.

### Brief for the Sonnet coder

Read first: this section whole; S1's decisions 1–3 (what `check` and `decide` print); the E1 document's S2 decisions
6, 9, 11, 12 and 15, its amendments A1–A24, and its S3 brief part 2 (`series_unit`, `_series_reject`,
`series_sweep_parts` — the record functions you mirror); `lib/step.sh` and `lib/run_guarded.sh` (read, do not
change except decision 6's hook); `tests/lib/stepcase.sh` and `tests/lib/seriescase.sh` (the helpers you copy the
shape of); `.agents/conventions/common/reliability.md` § *Every wait has a ceiling* and § *Paid work is written down
as it is earned*; `common/test-leftovers.md` §2–§4. The source scripts come from the main session; the line numbers
above are theirs. Do not change `lib/adapter.sh`, `lib/series.sh`, `lib/verdict.py`, `lib/merge_moe.py`,
`lib/moe_kernel_ab.py`.

**1. `lib/moe.sh`** — sourced functions and the worker. Functions: `moe_exchange_dir <model>` (prints
`$R9700_WORK_DIR/r9700/moe/<model>`), `moe_container_dir <model>` (`/work/r9700/moe/<model>`), `moe_cache_clear`
(decision 6), `moe_identity_check <layer> <search>` (decision 8; writes `KIND=refused` through `outcome_write
"$R9700_OUTCOME_FILE"` and returns 2), `moe_layer_words <layer> <envs array> <dtype var>` (decision 2: the `-e`
words and the dtype), `moe_argv <argv array> <envs> <name> <tune|ab> <keys…>` (the one argv builder; `_serve_argv`'s
shape), `moe_sweep_parts <outdir>`, `moe_reject <outdir> <tag> <part> <reason>`, `moe_chunk_unit <outdir> <model>
<chunk> <layer> <search> <keys…>`, `moe_ab_unit <outdir> <model> <layer> <rule> <rule keys> <reps> <keys>`,
`moe_main`. The chunk name regex `^[a-z0-9][a-z0-9-]{0,30}$` and the key rules of decision 2 are checked by
`moe_main` first (exit 2 with one `moe: ` line; the verb checks them again before the lock in S3). Every container
name through `container_name`; every call through the adapter; `set -u` safe, no `set -e`; no `wslc` word anywhere
in the file (the seam check). The worker's stdout is its log (the supervisor keeps it in `steps/<n>.worker.log`);
print one `=== <UTC> chunk <name> (<layer>, <search>, keys <keys>)` header, the clear's lines, the identity check's
line, and at the end `recorded chunks/<chunk>` or the rejection line.

**2. `lib/run_guarded.sh`** — `cleanup_hook_set <function>`: refuses (2) a name that `declare -F` does not know;
sets `_RG_CLEANUP_HOOK`. In `cleanup_once`, after the `container_stop_all` line and before the restore block:
`if [ -n "${_RG_CLEANUP_HOOK:-}" ]; then "$_RG_CLEANUP_HOOK"; hrc=$?; rg_log "cleanup hook: $_RG_CLEANUP_HOOK
rc=$hrc"; fi` — a foreground call, as `restore_now` is in the same function, under the adapter's own ceiling
(`_rg_run` is for the step phase, where a signal must end a call at once; the cleanup phase ignores signals). `supervise` resets
`_RG_CLEANUP_HOOK` with the other per-invocation state (`_rg_state_reset`). Nothing else in the file changes; the
header comment gains the two lines.

**3. The fields** — decision 7's table into `lib/config.sh` (`_field model MOE_DTYPE enum:auto,fp8_w8a8,int8_w8a16,int4_w4a16,none
int4_w4a16 "…"`, `_field machine MOE_CHUNK_MAX_S int:600:86400 43200 "…"`, the `CLEANUP_BUDGET_S` default and
description, the `READY_TIMEOUT_S` range, `_cfg_cross`'s `+ 300` → `+ 360` with its message), `machine.env.example`
(one comment line and the commented default per new machine key), `models/*.env` (the comment line), and
`research/module_config.md` (the rows; the `CLEANUP_BUDGET_S` row's *Replaces* column says `default 1560 since
E2.S2 decision 6 (was 1500 since E1.S2 decision 8, 900 before)`). Update the E1 tests that state the old default and
rule (`tests/test_config.sh` lines 59 and 256–260, `tests/test_steps.sh` line 124 and the `545`/`540` budget cases)
to the new numbers, with the decision named in the assertion text.

**4. The stub** — decision 9, in `tests/stubs/wslc`'s `run_container` (the foreground branch gains the `--name`
case) and `exec`-free: the benchmark answers are matched on the argv words `benchmark_moe.py` and `--tune`, the clear
on `sh -c` with `triton-moe-tune` in the program. `stub_record_pid` for the foreground container; remove the pid file
in an `EXIT` trap of the stub so a `stop` (which kills the stub) and a normal end both clear it.

**5. Tests** — `tests/lib/moecase.sh` (`moe_setup`, `moe_step <args…>` = `bin/r9700 step --model … -- bash
lib/moe.sh …` as a user runs it, `moe_bg`/`moe_end` as `step_bg`/`step_end`, `moe_supervise <body>`, `moe_answer
<name> <content>`, `chunk_json_for <fixture file> <keys…>` — builds a chunk file from a merged fixture with
`python3 -c`) and `tests/test_moe.sh` with T1–T18 as `t_<guarantee>` functions. Faults are triggered after the
container's pid file exists (bounded poll, `wait_for`), never after a fixed time; timings use `stop_in` and the
scaled numbers (A3, A10).

**6. Docs.** `research/architecture.md`: the module row `MoE tuning — lib/moe.sh (the chunk unit, the A/B unit, the
cache clear), config/coarse_candidates.json, vendor/benchmark_moe.py`; the record life cycle of a chunk and of an
A/B (`.part-` → `check`/the kernel-time count → final, or `rejected/`); the exchange folder and why it exists (the
container sees `/work` only); the hook in `cleanup_once` and the budget rule; a Mermaid flow `chunk: clear → identity
→ disk gate → container → copy → check → record`. `research/module_tests.md`: the test file, the helpers, the new
knobs (`answers/moe_*`), the catalogue rows `bin/r9700 step … lib/moe.sh chunk` and `… ab` (covered, T1–T18) and
`cleanup_hook_set` (T9, T11, T12); under *what it does not prove*: the stub's foreground container is listed and
stoppable like a detached one (UNVERIFIED on the real `wslc` for a foreground `run --rm`; the acceptance checks it),
the tuning itself never runs, the cache volume is never touched.

**Commands.**

```bash
node tests/run.mjs tests/test_moe.sh tests/test_config.sh tests/test_steps.sh
node tests/run.mjs                                   # everything
bash tests/check_static.sh                           # includes --seam over lib/moe.sh
node .agents/conventions/tools/leftovers-check.mjs --repo . --token r9700 --identity "the R9700 vLLM tuning toolkit" --profile node
node .agents/conventions/tools/plan-lifecycle.mjs
```

Report the runner's lines and the total, the static check's exit code, and paste T9's assertion output (no prefixed
container, no session member, the clear between the stop and the restore) — it is the parent's done-when.

---

## E2.S3 — `bin/r9700 moe-tune`, the placed benchmark, the docs, the acceptance template

**Cornerstone:** no. **Depends on:** E2.S1, E2.S2. **Spec:** this section (Opus). **Code:** one Sonnet coder.

### Goal

A person runs `bin/r9700 moe-tune chunk <model> --keys "24" --coarse`, then `moe-tune merge <model> <chunk>…`, then
`moe-tune ab <model> --keys "…" --rule median --rule-keys "24"` and gets a merged, validated config file in the
model's merged folder and a decision line — all from the README, with the E1 lifecycle (one lock, restore first, one
stop, one restore). The acceptance on the R9700 is written as a template with its prediction and marked NOT RUN.

### Files

`bin/r9700` gains `verb_moe_tune`; `lib/moe.sh` gains `moe_place <model>` (the vendored file and the candidates into
the work folder, hash-checked) and `moe_merge_verb` (the merge mode's body); `tests/test_moe_tune.sh` (U1–U12);
`README.md` (a *MoE tuning* section after the quick start); `research/architecture.md`, `research/module_tests.md`;
`research/ACCEPTANCE_moe_tune_<date>.md` (the template, NOT RUN); `todo/README.md` unchanged (this document's row
is added with this document).

### Boundaries

- In: the verb, its three modes, the argument grammar and its refusals before the lock; the pre-admission count of
  a recorded chunk; the placement of `vendor/benchmark_moe.py` and `config/coarse_candidates.json` into
  `$R9700_WORK_DIR/r9700/` (the shape of E1.S3 decision 5 for `harness.py`); the merge mode's two outputs (the record
  and the exchange copy); the docs; the acceptance template.
- Out: the workers, the records, the hook (S2); the merge arithmetic (S1); the `run` plan file that chains these
  steps (E3 — the verb is built so that `run` can call `step_run moe-chunk …` and `step_run moe-ab …` with the same
  worker argv, and the merge as a plain step).

### Decisions

**1. One verb, three modes.** `bin/r9700 moe-tune chunk|merge|ab <model> [options]` — `moe-tune` is the parent's
verb name; the modes are the three steps a person took by hand (tune a chunk, merge, A/B) and the mode word is the
first argument, as `lib/verdict.py` has `ship` and `check-block`. `commands` lists `moe-tune` once (the verb table of
E1 decision 14 is unchanged in shape).

- `moe-tune chunk <model> --keys "<k…>" [--coarse] [--layer experts|draft] [--chunk <name>] [--out <name>]`: the
  chunk name defaults to `<layer>-<coarse-|full-><keys joined by ->` (`experts-coarse-24`, `draft-full-1`); `--out`
  defaults to `moe-<model name>`; the outdir is `$R9700_RESULTS_DIR/<out>`. Order: arguments (syntax, before the
  lock) → `supervise moe-tune moe_prepare moe_chunk_body`, where `moe_prepare` = `prepare_run` + the checks that need
  the config (`MOE_DTYPE=none` → exit 2 `moe-tune: <model> has MOE_DTYPE=none: no MoE layers to tune`; the chunk name
  fits a container label) and `moe_chunk_body` = `moe_place` → the recorded-chunk count (`chunks/<chunk>/` exists →
  `moe-tune: chunk <name> is recorded, nothing to do`, return 0 before admission) → `cleanup_hook_set moe_cache_clear`
  → `step_run moe-chunk -- bash lib/moe.sh chunk …`.
- `moe-tune ab <model> --keys "<k…>" --rule each|median --rule-keys "<k…>" [--reps 3] [--layer …] [--out <name>]`:
  the same order; the body is `moe_place` → `cleanup_hook_set` → `step_run moe-ab -- bash lib/moe.sh ab …`.
- `moe-tune merge <model> [--layer experts|draft] [--base auto|none|<file>] [--out <name>] <chunk>…`: no GPU, no
  admission, so it is a READING verb like `verdict` (E1 decision 2): the lock only when a marker exists (restore
  first), then the config, then `python3 lib/merge_moe.py merge --out <outdir>/merged/<stamp>/ [--base <file>]
  <outdir>/chunks/<chunk>…`, then the exchange copy: the output file copied to
  `$R9700_WORK_DIR/r9700/moe/<model>/merged/<NAME>` (`.part` + `mv`; an existing file of that name there is replaced,
  because the record under `merged/<stamp>/` keeps every version and the exchange folder is what the A/B and a server
  read). `--base auto` (the default): when `TUNED_CONFIG_DIR` starts with `/work/`, the file of the merged NAME under
  `$R9700_WORK_DIR/<rest>/` is the base when it exists (B2's shape: the production file plus the new keys, `b2.sh` line
  30); any other container path cannot be read from WSL, so the merge says `base: TUNED_CONFIG_DIR <path> is not under
  /work, no base` and goes on without one; `none` skips the base; a path names it. The record's `merged/<stamp>/merge.env`
  holds `CHUNKS`, `BASE`, `BASE_SHA256`, `OUTPUT_SHA256`, `EXCHANGE_PATH`, `WRITTEN_AT`. Printed: the merge's last line
  and `exchange: <path>`.

Rejected: a verb per mode (three names for one subject, and the parent names one); a `moe-tune all` that chains
chunk, merge and A/B in one invocation (that is E3's `run` with a plan file — building it twice is the thing the
boundary table exists to stop).

**2. The placed files, hash-checked, before admission.** `moe_place <model>` copies `vendor/benchmark_moe.py` to
`$R9700_WORK_DIR/r9700/benchmark_moe.py` and `config/coarse_candidates.json` to `$R9700_WORK_DIR/r9700/coarse_candidates.json`
(`.part` + `mv`) when the sha256 differs or the file is missing, then checks both hashes; a failure is exit 2 before
anything is stopped. The worker re-checks them (S2 decision 8).

**3. The dry run.** `--dry-run` on `chunk` and `ab` prints the resolved `wslc run --rm --name … benchmark_moe.py …`
line(s) through `wslc_argv_text` (the same builder as the worker, `moe_argv`) and the clear's line, after `moe_place`,
and starts nothing: the chunk's one line; the A/B's six lines. As E1's A17: a dry run writes no record and no part.

**4. Exit codes.** The supervisor's table of E1 decision 6 unchanged: 0, 2 (arguments, config, `MOE_DTYPE=none`, a
refused identity — the worker's `KIND=refused`), 4, 5, 6, 7, 8, 9, 129/130/143. `merge` exits with `merge_moe.py`'s
code (0 or 2). No new code.

**5. The acceptance is a template, NOT RUN.** `research/ACCEPTANCE_moe_tune_<date>.md`, the shape of
`research/ACCEPTANCE_series_2026-11-02.md`: the subject sha, the harness, the model file unedited, the three
commands, the prediction written BEFORE the run, the observed sections empty on purpose, the questions the run
answers, what it does not settle. The commands (the parent's acceptance: `moe-tune --coarse --keys 24` plus the
kernel A/B, ≈ 25 min):

```bash
bin/r9700 init
bin/r9700 moe-tune chunk qwen3.6-35b-a3b-gptq --keys "24" --coarse --out acceptance-moe
bin/r9700 moe-tune merge qwen3.6-35b-a3b-gptq --out acceptance-moe experts-coarse-24
bin/r9700 moe-tune ab qwen3.6-35b-a3b-gptq --keys "8 16 24 32" --rule median --rule-keys "24" --out acceptance-moe
```

The prediction, from § 14.1 (the coarse grid picked the current tile at every key, and the A/B was within ± 0.6 %):
the chunk takes about 5–6 min (1,244 s for four keys), its key 24 is `BLOCK 16/16/64, GROUP 1, 1 warp, 2 stages,
waves_per_eu 4` — the same config as the `b2` fixture's key 24; the merge writes a 10-key file (the 9 production
keys plus 24) whose keys 1–16, 256–2048 equal the production file's and whose key 24 equals the chunk's; the A/B's
four changes are within ± 1 % and the decision is `KERNEL: not faster (median change at 24: <±0.x> %)`; the
operator's server is stopped twice (one per GPU invocation) and is back, ready, after each; the cache clear line
shows a size near 1 GB before the A/B (the chunk filled it) and the exit-path clear ran after each invocation (two
`cleanup hook: moe_cache_clear rc=0` lines in the two supervisor logs). What would make it wrong: a different key-24
tile (the coarse grid is not deterministic across runs — then the A/B decides, and either decision is a record); an
A/B outside ± 3 % (then the kernel timing on this day was noisy, or the file differs — read `ab.env`). The questions
the run answers: does a foreground `wslc run --rm --name` appear in `wslc list` while it runs and does `wslc stop`
end it (S2 decision 9, UNVERIFIED); does the clear container's `du` print what we expect; is hook 3 observed (no —
a draft chunk is not in this run; say so). The operator holds GPU runs for now: the template is written and marked
NOT RUN, as E1 did; the record is filled by the operator's session when it runs.

### Test scenarios

`tests/test_moe_tune.sh` (bash; S2's `moecase.sh` helpers; "a verb chunk" is `bin/r9700 moe-tune chunk
qwen3.6-35b-a3b-gptq --keys "24" --out m`, `OUT = $R9700_RESULTS_DIR/m`).

1. *A verb chunk places the files, records the chunk, and names it.* `$R9700_WORK_DIR/r9700/benchmark_moe.py` and
   `coarse_candidates.json` are absent before: exit 0; both exist after, byte-identical to `vendor/` and `config/`;
   `OUT/chunks/experts-full-24/` is the record (the default name); stdout has `moe-tune: outdir <OUT>` first and
   `recorded chunks/experts-full-24` later; one `stop vllm`, one `pwsh.exe`.
2. *`--coarse`, `--layer draft` and `--chunk` shape the name and the worker arguments.* `--keys "256 1024 2048"
   --coarse --layer draft`: the record is `chunks/draft-coarse-256-1024-2048/`; the worker's argv (the supervisor log's
   `worker started` line names the command, or `steps/1.worker.log`'s header) holds `draft coarse 256 1024 2048`.
   `--chunk mine`: `chunks/mine/`.
3. *A recorded chunk is counted before admission.* After U1 the same command: exit 0, `moe-tune: chunk experts-full-24
   is recorded, nothing to do`, no `stop vllm` and no `pwsh.exe` in the second invocation's call log, no new run dir
   step.
4. *The arguments are refused before the lock, naming the legal shape.* `moe-tune` alone: exit 2, usage line
   naming `chunk|merge|ab`; `moe-tune chunk` without `--keys`: exit 2 `moe-tune: chunk: --keys is required`; `--keys
   "a 2"`: `"a" is not a batch size (1..65536)`; `--keys "2 2"`: `given twice`; `--layer heads`: names `experts draft`;
   `--chunk "Bad Name"`: names `^[a-z0-9][a-z0-9-]{0,30}$`; `ab --rule mean`: names `each median`; `ab` without
   `--rule-keys`: `--rule-keys is required`; `--rule-keys "5"` with `--keys "1 4"`: `rule key 5 is not in --keys`. In
   every case the call log is empty (no lock taken: `init` from another shell during the refusal is not needed —
   assert the state dir has no `lock` file written by this call) and `containers/vllm.pid` is untouched.
5. *`MOE_DTYPE=none` is refused after the restore-first and before any stop.* A model variant with `MOE_DTYPE=none`:
   exit 2, stderr `moe-tune: <model>: MOE_DTYPE=none: no MoE layers to tune`, no `stop vllm`. With a marker present
   (written by hand as E1's L6 does): the first stdout line is `r9700: recovery marker found …`, the restore ran
   (`pwsh.exe` once), THEN the refusal — the E1 order (lock → restore-first → config → work).
6. *`--dry-run` prints the container line and starts nothing.* `… --keys "24" --coarse --dry-run`: exit 0; stdout
   has one `dry-run: wslc run --rm --name r9700tune-moe-tune-experts-coarse-24 … -e MOE_TUNE_CANDIDATES=/work/r9700/coarse_candidates.json … --batch-size 24 …`
   line and one `dry-run: wslc run --rm --name r9700tune-moe-clear …` line; the call log has no `run`, no `stop`, no
   `pwsh.exe`; no `chunks/` and no `.part-` under `OUT`. `ab … --dry-run`: six `dry-run: wslc run … moe-ab-…` lines.
7. *`merge` writes the record and the exchange copy, with `--base auto` reading the model's tuned folder.* After U1
   and a second verb chunk `--keys "32"` (two records): the 35B model's `TUNED_CONFIG_DIR=/work/moe/tune/merged`, so
   the test writes the `b2_base` fixture file into `$R9700_WORK_DIR/moe/tune/merged/`; `moe-tune merge
   qwen3.6-35b-a3b-gptq --out m experts-full-24 experts-full-32`: exit 0; `OUT/merged/<stamp>/E=…int4_w4a16.json` holds
   keys 1 2 4 8 12 16 24 32 256 1024 2048 (listed by `python3 -c`); `merge.env` has `BASE=` that path and
   `BASE_SHA256=072d2506…`; `$R9700_WORK_DIR/r9700/moe/qwen3.6-35b-a3b-gptq/merged/E=…int4_w4a16.json` equals the
   record byte for byte; stdout's last line `exchange: <that path>`; no `stop vllm`, no `pwsh.exe` (a reading verb).
8. *`merge` without a readable base says so and goes on; `--base none` skips it.* A model variant with
   `TUNED_CONFIG_DIR=/data/moe` (not under `/work`): stdout `base: TUNED_CONFIG_DIR /data/moe is not under /work, no
   base`; the output holds the two chunks' keys only. `--base none` with the unedited model: the same two keys, no
   `base:` line.
9. *`merge` refuses a missing chunk and leaves nothing behind.* `moe-tune merge … experts-full-24 nosuch`: exit 2,
   stderr `merge: missing chunk: <OUT>/chunks/nosuch has no E=*.json`; no new `merged/<stamp>/`, no `.part` anywhere,
   the exchange file unchanged (mtime).
10. *A second merge is a new record and replaces the exchange copy.* Run U7's command again: a second
    `merged/<stamp2>/` (the first untouched, same bytes), the exchange copy's mtime advanced, its content equal to the
    second record.
11. *`ab` through the verb records the decision and registers the hook.* After U7, `moe-tune ab qwen3.6-35b-a3b-gptq
    --keys "1 2 3 4 6 8 12 16" --rule each --rule-keys "1 4" --layer draft --out m` with the `b1` fixture placed by the
    test as the exchange merged file (the draft name): exit 0; `OUT/ab/<stamp>/decision.txt` = `KERNEL: faster (each of
    1 4 is faster by more than 3 %)`; the supervisor log has `cleanup hook: moe_cache_clear rc=0`; `stop vllm` once,
    `pwsh.exe` once.
12. *The verb is listed and catalogued, and `--model`-less resolution follows E1.* `bin/r9700 commands` holds
    `moe-tune` (and `tests/test_lifecycle.sh`'s L18 keeps passing: every verb has its catalogue row); `moe-tune chunk
    nosuchmodel --keys 1`: exit 2 `r9700: model "nosuchmodel" not found; legal: …` (E1's `model_resolve`, unchanged).

### Brief for the Sonnet coder

Read first: this section; S2's decisions 1–4 and 8 and its brief part 1 (the worker's argv — `moe-tune` passes
exactly those positional words); `bin/r9700`'s `verb_series`, `series_args`, `series_prepare`, `series_body` and
`verb_verdict` (the shapes you copy: syntax before the lock, `supervise <verb> <prepare> <body>`, a reading verb's
marker check); E1.S3's decision 5 (`harness.py` placed with its hash checked) and A17 (a dry run writes nothing);
`research/ACCEPTANCE_series_2026-11-02.md` (the template you mirror). Do not change `lib/step.sh`,
`lib/run_guarded.sh` (S2 made its one change), `lib/merge_moe.py`, `lib/moe_kernel_ab.py`.

**1. `bin/r9700`** — `verb_moe_tune`: `moe_tune_args <mode> <args…>` (syntax only; sets `_MOE_MODE`,
`_R9700_MODEL_ARG`, `_MOE_KEYS`, `_MOE_COARSE`, `_MOE_LAYER`, `_MOE_CHUNK`, `_MOE_OUT`, `_MOE_RULE`, `_MOE_RULE_KEYS`,
`_MOE_REPS`, `_MOE_BASE`, `_MOE_CHUNKS`, `_MOE_DRY`; 2 with one `r9700: moe-tune: <mode>: ` line); `moe_prepare`
(`prepare_run`, the `MOE_DTYPE=none` refusal, `container_name "moe-tune-$_MOE_CHUNK"` and `"moe-ab-default-$_MOE_REPS"`
as the longest labels); `moe_chunk_body`, `moe_ab_body` (decision 1; the dry run of decision 3 returns before
`step_run`); `moe_merge_verb` for the reading mode (the `verb_verdict` shape, then `moe_merge_verb` of `lib/moe.sh`).
The usage line: `r9700: moe-tune: usage: moe-tune chunk|merge|ab <model> [options]`. The outdir line first:
`moe-tune: outdir <path>` (A23's shape).

**2. `lib/moe.sh`** gains `moe_place <model>` (decision 2) and `moe_merge_verb <outdir> <model> <layer> <base>
<chunk…>` (decision 1's merge mode: the stamp folder, the `merge_moe.py` call with `exec`-free capture of its exit
code, `merge.env`, the exchange copy, the two printed lines) and `moe_dry_run <mode> …` (decision 3, through
`wslc_argv_text` and `moe_argv`).

**3. Tests** — U1–U12 in `tests/test_moe_tune.sh` with `moecase.sh`; a helper `mv_verb <args…>` = `bin/r9700 moe-tune
<args…>` as a user runs it.

**4. README** — a section *MoE tuning* after the quick start: what a chunk, a merge and an A/B are (one sentence
each, with the measured times: a coarse chunk of four keys ≈ 21 min, a full search of one key 1–3.6 h, an A/B ≈ 5
min); the three commands of the acceptance as the example; where the records are (`<RESULTS_DIR>/moe-<model>/chunks/`,
`merged/<stamp>/`, `ab/<stamp>/`, `rejected/`) and where the file a server uses is (`<WORK_DIR>/r9700/moe/<model>/merged/`,
which is `/work/r9700/moe/<model>/merged` inside a container — set it as `TUNED_CONFIG_DIR`, or copy the file into
the folder the operator's own server mounts); how to resume (the same `chunk` command skips a recorded chunk; name
another `--chunk` for a second search); the two knobs for a long search (`MAX_RUN_MINUTES`, `MOE_CHUNK_MAX_S`); that
every GPU invocation stops the operator's server once and restores it; the draft layer (`--layer draft`) and when it
applies (an MTP draft MoE layer — the 35B's case); `MOE_DTYPE=none` for a model without MoE layers. No personal path.

**5. Docs** — `research/architecture.md`: the verb's three modes in the verb table, the merge's two outputs, the
Mermaid flow extended with `moe-tune chunk → chunks/ → merge → merged/ + exchange → ab → decision`;
`research/module_tests.md`: the test file, the catalogue rows `bin/r9700 moe-tune chunk|merge|ab` (covered,
U1–U12), the acceptance row (`not covered by CI: run by the operator's session; the record is
research/ACCEPTANCE_moe_tune_<date>.md`), and under *what it does not prove*: the benchmark never runs, hook 3 is
unobserved until a draft chunk runs on the machine, the foreground-container listing is a stub assumption.
`research/README.md`: the acceptance template's row. `research/ACCEPTANCE_moe_tune_<date>.md`: decision 5, with
every "observed" section empty and the heading `— prepared <date>, NOT RUN YET`.

**Commands.**

```bash
node tests/run.mjs tests/test_moe_tune.sh tests/test_lifecycle.sh
node tests/run.mjs                                   # everything
bash tests/check_static.sh
node .agents/conventions/tools/leftovers-check.mjs --repo . --token r9700 --identity "the R9700 vLLM tuning toolkit" --profile node
node .agents/conventions/tools/plan-lifecycle.mjs
```

Report the runner's lines and the total, the static check's exit code, and paste U7's output (the merge with the
base, the exchange line) and U6's dry-run lines.

---

## Growth surfaces of these stories

| Surface | Story | Size at the measured volumes | Who retires it | Interrupted |
|---|---|---|---|---|
| Chunk records `<RESULTS_DIR>/moe-<model>/chunks/<chunk>/` (JSON ≈ 1–3 KB, `chunk.log` ≈ 30 KB, env and summary < 2 KB) | S2 | ≈ 35 KB per chunk; the 2026-10 work was 12 chunks ≈ 0.4 MB; a full tuning of one model stays under 1 MB | kept forever under `RESULTS_DIR` (the evidence; the parent's row) | a cut chunk's `.part-` goes to `rejected/` at the next worker start with its log |
| `rejected/` under the same outdir | S2 | ≈ 35 KB per rejected attempt, at most `MAX_FAILED_TRIES` per invocation | kept forever | — |
| A/B records `ab/<stamp>/` (6 logs ≈ 3 KB each, summary ≈ 3 KB) | S2 | ≈ 25 KB per A/B | kept forever | a cut A/B's `.part-` as above |
| Merge records `merged/<stamp>/` | S3 | ≈ 3 KB per merge | kept forever (append-only: every merge is a new folder) | the `.part` of an interrupted write is removed by the writer; a stray one is ignored (never read) |
| The exchange folder `<WORK_DIR>/r9700/moe/<model>/` (`tune/<chunk>/` ≈ 1–3 KB, `merged/` ≈ 3 KB per layer) and `<WORK_DIR>/r9700/benchmark_moe.py` (41 KB), `coarse_candidates.json` (11 KB) | S2, S3 | bounded by the number of chunks; under 100 KB per model | `tune/<chunk>/` is deleted before every run of that chunk; `merged/` is replaced by each merge; the placed files are replaced when `vendor/` changes | a half-written `tune/<chunk>/` is deleted at the next run; a `.part` of a placement is left and replaced |
| The Triton caches `triton-moe-tune`, `triton-moe-ab` in the `vllm-cache` volume | S2 | 0.5–1.3 GB after a chunk (measured 1.3 GB) | cleared before every unit and in the exit path of every `moe-tune` invocation (the hook) | a hard-killed supervisor runs no hook: the next unit's start clears it; nothing else does |
| Containers `<prefix>moe-tune-<chunk>`, `<prefix>moe-ab-<arm>-<rep>`, `<prefix>moe-clear` | S2 | one at a time, `--rm` | the guards and the cleanup stop them by prefix (E1) | `init` stops leftovers by prefix (E1) |
| Test fixtures (tracked) | S1 | ≈ 60 KB (12 logs, 3 JSON files, 2 expected tables) + `vendor/` 45 KB + the candidates 11 KB | kept; replaced only by a deliberate change | — |

## Build order

1. E2.S1 — Sonnet codes the S1 section; Opus reviews; Sonnet fixes. The main session hands over the three-hook
   `benchmark_moe.py` (or S1 decision 5's fallback applies and is recorded).
2. E2.S2 — Sonnet codes the S2 section (the hook in `run_guarded.sh` and the field changes in the same commit as
   their tests); Opus reviews; Sonnet fixes.
3. E2.S3 — Sonnet codes the S3 section; Opus reviews; Sonnet fixes. The acceptance template is written NOT RUN; the
   operator's session runs it when GPU runs are released, and records the result and the merged file in `research/`.
4. One coai code round covers the whole epic (as E1's A6 did for S2's parts).

## Definition of Done (E2, by story)

- [ ] S1: M1–M16, K1–K12, C1–C3 and V1–V5 pass in CI through `node tests/run.mjs`; M1 and M2 reproduce the two
      published merged files byte for byte; K1 and K2 reproduce the recorded B1 and B2 tables and decisions.
- [ ] S1: `vendor/benchmark_moe.py` is upstream `2c880f1e6` plus the three hooks (V1), and `vendor/README.md` shows
      the diff (V3); hook 3's provenance (the backup, or reconstructed) is recorded in the README.
- [ ] S2: T1–T18 pass in CI with the stubs; T9 shows a RAM stop during a chunk leaves no prefixed container and clears
      the cache in the exit path (the parent's done-when); the new fields are in the loader, the example and
      `research/module_config.md`, and E1's derived tests keep passing.
- [ ] S3: U1–U12 pass; `bin/r9700 commands` lists `moe-tune` and the catalogue has its rows; the README and
      `research/architecture.md` describe `moe-tune`, its inputs and its outputs; the acceptance template exists in
      `research/`, marked NOT RUN, with its prediction; when the operator's session runs it, the record and the merged
      config it produced are added there (the parent's done-when; until then this box stays open and says so).
- [ ] Every story: no tracked file holds a personal path, account or machine name (the static check is green);
      `research/module_tests.md` names every new flow and what it does not prove; `plan-lifecycle.mjs` is clean.
