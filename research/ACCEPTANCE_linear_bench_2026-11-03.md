# Acceptance of `bin/r9700 linear-bench` on the R9700 — prepared 2026-11-03, RUN 2026-11-03 (quiet gate off)

The flow that CI cannot run (`research/module_tests.md`): it needs the GPU, the real `wslc`, the real image and the model's linear shapes. The operator's
session runs it before a release and pastes the output below. It was run on 2026-11-03 (the sections below); the prediction section is as it was written before the run, unchanged.

## Subject and conditions (fill in at the run)

| | |
|---|---|
| Subject (commit of this repository) | `d983327` (main after #8) |
| Harness | `bin/r9700` (verbs `init`, `linear-bench`) |
| Date of the run, machine | 2026-11-03 19:25–19:39 CET, the R9700 PC |
| Model file | `models/qwen3.6-35b-a3b-gptq.env`, unedited (`LINEAR_SHAPES` holds the five shapes of the speed-options runs, `LINEAR_GROUP_SIZE=128`) |
| Out, name | `acceptance-kernels`, `acceptance` (the record is `<RESULTS_DIR>/acceptance-kernels/linear/acceptance/`) |
| Command | `R9700_QUIET_CHECKS=1 bin/r9700 linear-bench qwen3.6-35b-a3b-gptq --name acceptance --out acceptance-kernels`, with `QUIET_LOAD_MAX=16` in `machine.env` (the operator: "don't wait") |
| Pinned, not varied | the image tag, the model file, `lib/linear_bench.py` (its hash is in `linear.env`: `LINEAR_BENCH_SHA256=e28f6eb41aa5…`), the seed 0 of the benchmark (random weights: only timing noise differs between runs), `--ms` and `--sweep-ms` at their defaults, `--timer graph` (all read back in `linear.env`) |
| Machine file | the operator's `machine.env` (not copied here: it holds the machine's paths) |
| Compared with | `dew_flow_benchmark · research/RESULTS_vllm_029_r9700_speed_options.md` § 12.1 (the CUDA-graph run of the night of 2026-10-30, the table of lines 519-528), and the published JSON the test `tests/test_linear_bench.py` (LB1) reproduces it from |
| Quiet gate | OFF by the operator's decision: one quiet check (`R9700_QUIET_CHECKS=1`) and a load limit of 16 (`QUIET_LOAD_MAX=16`). The two reads of this run were load 0.58 and 1.09, so the PC was quiet anyway; the prediction's "the quiet phase should prevent a busy PC" was not tested by the default gate |

## Commands

```bash
bin/r9700 init
bin/r9700 linear-bench qwen3.6-35b-a3b-gptq --name acceptance --out acceptance-kernels
```

## Prediction, written BEFORE the run (measurement rule 4)

From § 12.1 (the same seed, the same shapes and Ms, random weights; the old run was `linear_bench_graph.py`, the toolkit's `--timer graph` is its port):

- the container runs about 6 minutes after its start (the old run took 00:12 to 00:18, § 12.1 line 514); the first lines are `kernels: outdir …` and `cache clear: running …`, and the record is `recorded linear/acceptance`.
- `linear_bench.json` holds 50 rows (5 shapes x 10 Ms). `summary.txt` prints the table of § 12.1 within ± 5 % per cell and ± 2 points on the change column: M 1 default about 2.48 ms (split about 2.79); M 6 about 4.91 / 4.79 / 5.89 / 4.28 (default, Triton default tile, split HIP, tuned), change about -13 %;
  M 16 about 6.93 / 6.69 / 11.67 / 5.95, change about -14 %; M 12 about -1 %.
- `split_ms` is above `default_ms` at every M of 6 and more (the split HIP op is slower than the default, by up to 68 % at M 16, § 12.1 line 531).
- the tuned tiles of M 6, 8 and 16 are near the recorded ones (`tiles M=<m>:` lines): `16/16/32, 1 warp` for the two QKV input projections and `16/16/128, 4 warps` for `out_proj + o_proj` and the shared-expert `gate_up` (§ 12.1 lines 534-535); the shared-expert `down_proj` varies with M.
- every `tuned_maxdiff` in the rows is 0.0 and every `split_maxdiff` is at most 0.0078 (§ 12.1 line 538).
- the operator's server is stopped once and is back, ready, after the run; no prefixed container is left; the exit-path line `cleanup hook: moe_cache_clear rc=0` stands in the supervisor log before the `restored` line; the cache clear names three cache folders (the two MoE ones and `triton-linear`).
- no `rejected/` folder.

What would make it wrong, and what it would mean:

- a busy PC: the quiet phase should prevent it. Results § 6.4 measured a load of 12 to 20 and found that it did not explain the stall of § 6.1, so it is not known how far load moves this timer (the graph replay is less sensitive to it than eager calls, § 12.1 line 514); a row far from § 12.1 with a high load in the supervisor log is a measurement of the load.
- a changed image: vLLM's dispatch rule (HIP skinny kernel for M of 5 and less, Triton above) may differ; the record says the image tag, and a different default column is then a result about the new image.
- a tile that no longer compiles: a `skip tile` line in `linear.log` is a result, not a failure.
- the timer: if the graph timer fails to capture, the unit fails and the record is rejected with its reason; the eager timer is not the acceptance case.

## Observed: `init`

```
init: config: ok
init: results dir: ok
init: state dir: ok
init: wslc: ok
init: vllm: running
init: leftover containers: none
init: ram telemetry: ok (32058 MB)
init: disk telemetry: ok (record 4566)
rc=0
```

## Observed: the run

Command output, as printed (the first line `start …` and the last `end …` are the operator's session's time stamps, in CET; the other times are UTC, `Z`):

```
start 2026-11-03 19:25:11
kernels: outdir <RESULTS_DIR>/acceptance-kernels
2026-11-03T18:25:11Z coai-exp processes=0 load=0.58 quiet-checks=1/1
2026-11-03T18:25:11Z QUIET
2026-11-03T18:25:12Z disk gate: baseline 4566
2026-11-03T18:25:35Z failed try 1 of 3: admit stopping vllm failed (code 1)
2026-11-03T18:25:35Z coai-exp processes=0 load=1.09 quiet-checks=1/1
2026-11-03T18:25:35Z QUIET
2026-11-03T18:25:38Z disk gate: OK: no new disk event (newest 4566)
2026-11-03T18:25:38Z admitted
2026-11-03T18:25:39Z worker started: session 1252085, start ticks 3362864
2026-11-03T18:33:39Z worker ended rc=0
recorded linear/acceptance
M  default_ms  triton_default_ms  split_ms  tuned_ms  change
1  2.41  4.62  2.71  -  -
2  2.43  4.63  2.75  -  -
3  2.63  4.46  2.94  -  -
4  2.91  4.48  3.21  -  -
5  3.26  4.50  3.56  -  -
6  4.51  4.49  5.74  4.12  -9 %
8  5.10  5.07  6.19  4.07  -20 %
10  5.08  5.02  6.83  -  -
12  4.52  4.50  8.90  4.31  -5 %
16  6.21  6.25  11.34  5.13  -17 %
tiles M=6: linear_attn.in_proj_qkvz=[16, 32, 32, 1, null] linear_attn.out_proj+self_attn.o_proj=[16, 16, 128, 4, null] self_attn.qkv_proj=[16, 16, 32, 1, null] shared_expert.gate_up_proj=[16, 16, 128, 4, 1] shared_expert.down_proj=[16, 16, 32, 2, null]
tiles M=8: linear_attn.in_proj_qkvz=[16, 16, 32, 1, null] linear_attn.out_proj+self_attn.o_proj=[16, 16, 128, 4, null] self_attn.qkv_proj=[16, 16, 32, 1, null] shared_expert.gate_up_proj=[16, 16, 128, 4, 1] shared_expert.down_proj=[16, 16, 32, 2, null]
tiles M=12: linear_attn.in_proj_qkvz=[16, 16, 32, 1, 2] linear_attn.out_proj+self_attn.o_proj=[16, 16, 128, 4, null] self_attn.qkv_proj=[16, 16, 32, 1, 2] shared_expert.gate_up_proj=[16, 16, 128, 4, 1] shared_expert.down_proj=[16, 16, 32, 2, null]
tiles M=16: linear_attn.in_proj_qkvz=[16, 64, 128, 4, null] linear_attn.out_proj+self_attn.o_proj=[16, 16, 128, 4, null] self_attn.qkv_proj=[16, 16, 32, 1, 2] shared_expert.gate_up_proj=[16, 16, 128, 4, 1] shared_expert.down_proj=[16, 16, 128, 8, null]
2026-11-03T18:33:40Z cleanup hook: moe_cache_clear rc=0
restore: starting vllm with <RESTORE_SCRIPT_WIN>
vLLM patches active from <the start script's patch folder>: auto_gptq.py, gptq_utils.py, moe\ tuned config (see README.md there)
a65f15e96d1abc457f7f43f28df79b8f5f0c21fc74bd0940325ac2867a5967d4
2026-11-03T18:39:05Z restored
rc=0
end 2026-11-03 19:39:05
```

The record folder (`stat -c '%s  %n'`, so no account name is printed; `rejected/` does not hold this unit), and `linear.env`:

```
1441  <RESULTS_DIR>/acceptance-kernels/linear/acceptance/linear.env
13869  <RESULTS_DIR>/acceptance-kernels/linear/acceptance/linear.log
14163  <RESULTS_DIR>/acceptance-kernels/linear/acceptance/linear_bench.json
1358  <RESULTS_DIR>/acceptance-kernels/linear/acceptance/summary.txt
NAME=acceptance
MODEL=qwen3.6-35b-a3b-gptq
IMAGE=rocm/vllm:rocm10.1.0_ubuntu24.04_py3.14-pytorch_2.13.0_vllm-0.29.0
MODEL_DIR=/root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ
SHAPES="linear_attn.in_proj_qkvz:2048:12288:30 linear_attn.out_proj+self_attn.o_proj:4096:2048:40 self_attn.qkv_proj:2048:9216:10 shared_expert.gate_up_proj:2048:1024:40 shared_expert.down_proj:512:2048:40"
GROUP_SIZE=128
MS="1 2 3 4 5 6 8 10 12 16"
SWEEP_MS="6 8 12 16"
TIMER=graph
LINEAR_ARGV="wslc run --rm --name identity --gpus all --shm-size 16g -e HIP_VISIBLE_DEVICES=0 -e TRITON_CACHE_DIR=/root/.cache/vllm/triton-linear -v vllm-cache:/root/.cache/vllm -v <WORK_DIR_WIN>:/work rocm/vllm:rocm10.1.0_ubuntu24.04_py3.14-pytorch_2.13.0_vllm-0.29.0 python3 /work/r9700/linear_bench.py run --out /work/r9700/linear/acceptance/linear_bench.json --shapes linear_attn.in_proj_qkvz:2048:12288:30 linear_attn.out_proj+self_attn.o_proj:4096:2048:40 self_attn.qkv_proj:2048:9216:10 shared_expert.gate_up_proj:2048:1024:40 shared_expert.down_proj:512:2048:40 --group-size 128 --ms 1 2 3 4 5 6 8 10 12 16 --sweep-ms 6 8 12 16 --timer graph"
LINEAR_BENCH_SHA256=e28f6eb41aa53e503f3e6d5cf4d63c8c58bb3e09456e78c8f1a67497e6062cba
PREFIXTEST_SHA256=f01b783d895d0c7e0c949428654c9a8e1aa3c435a12af692423468520314f22c
CONTAINER=r9700tune-linear-bench-2
RUN_ID=20261103T182511Z-1251184
STARTED_AT=2026-11-03T18:25:42Z
ENDED_AT=2026-11-03T18:33:37Z
RC=0
```

`summary.txt` is the table the command printed (`M  default_ms …` to the four `tiles M=` lines), byte for byte:

```
M  default_ms  triton_default_ms  split_ms  tuned_ms  change
1  2.41  4.62  2.71  -  -
2  2.43  4.63  2.75  -  -
3  2.63  4.46  2.94  -  -
4  2.91  4.48  3.21  -  -
5  3.26  4.50  3.56  -  -
6  4.51  4.49  5.74  4.12  -9 %
8  5.10  5.07  6.19  4.07  -20 %
10  5.08  5.02  6.83  -  -
12  4.52  4.50  8.90  4.31  -5 %
16  6.21  6.25  11.34  5.13  -17 %
tiles M=6: linear_attn.in_proj_qkvz=[16, 32, 32, 1, null] linear_attn.out_proj+self_attn.o_proj=[16, 16, 128, 4, null] self_attn.qkv_proj=[16, 16, 32, 1, null] shared_expert.gate_up_proj=[16, 16, 128, 4, 1] shared_expert.down_proj=[16, 16, 32, 2, null]
tiles M=8: linear_attn.in_proj_qkvz=[16, 16, 32, 1, null] linear_attn.out_proj+self_attn.o_proj=[16, 16, 128, 4, null] self_attn.qkv_proj=[16, 16, 32, 1, null] shared_expert.gate_up_proj=[16, 16, 128, 4, 1] shared_expert.down_proj=[16, 16, 32, 2, null]
tiles M=12: linear_attn.in_proj_qkvz=[16, 16, 32, 1, 2] linear_attn.out_proj+self_attn.o_proj=[16, 16, 128, 4, null] self_attn.qkv_proj=[16, 16, 32, 1, 2] shared_expert.gate_up_proj=[16, 16, 128, 4, 1] shared_expert.down_proj=[16, 16, 32, 2, null]
tiles M=16: linear_attn.in_proj_qkvz=[16, 64, 128, 4, null] linear_attn.out_proj+self_attn.o_proj=[16, 16, 128, 4, null] self_attn.qkv_proj=[16, 16, 32, 1, 2] shared_expert.gate_up_proj=[16, 16, 128, 4, 1] shared_expert.down_proj=[16, 16, 128, 8, null]
```

`linear_bench.json` holds 50 rows (5 shapes x 10 Ms). The largest `tuned_maxdiff` over its rows is 0.0 and the largest `split_maxdiff` is 0.0078125 (read with a short Python program over the file; 0.0078125 is 2^-7, the 0.0078 of § 12.1).

Observed against predicted:

| | predicted | observed | held? |
|---|---|---|---|
| container time | about 6 minutes | 7 min 55 s (`STARTED_AT` 18:25:42Z, `ENDED_AT` 18:33:37Z) | **no** (a third more) |
| first lines, the record | `kernels: outdir …`, `cache clear: running …`, `recorded linear/acceptance` | `kernels: outdir …` and `recorded linear/acceptance` on the command's output; `cache clear: running (ceiling 90 s)` is the first line of the step's `worker.log` | yes |
| rows | 50 | 50 | yes |
| M 1 `default_ms`, `split_ms` | about 2.48, about 2.79 | 2.41 (-2.8 %), 2.71 (-2.9 %) | yes (± 5 %) |
| M 6 cells (default / Triton default / split / tuned) | about 4.91 / 4.79 / 5.89 / 4.28 | 4.51 / 4.49 / 5.74 / 4.12: -8.1 % / -6.3 % / -2.5 % / -3.7 % | **partly** (split and tuned inside ± 5 %, default and Triton default outside) |
| M 6 change | about -13 % | -9 % | **no** (4 points; the limit is ± 2) |
| M 16 cells | about 6.93 / 6.69 / 11.67 / 5.95 | 6.21 / 6.25 / 11.34 / 5.13: -10.4 % / -6.6 % / -2.8 % / -13.8 % | **partly** (only split inside ± 5 %) |
| M 16 change | about -14 % | -17 % | **no** (3 points) |
| M 12 change | about -1 % | -5 % | **no** (4 points) |
| `split_ms` above `default_ms` at every M of 6 and more | yes, up to +68 % at M 16 | yes in the summary at every M of 6 and more (M 6 5.74 against 4.51, M 16 11.34 against 6.21: +83 %); in the JSON rows the smallest shape (`shared_expert.down_proj`) has `split_us` at or below `default_us` at M 6, 8, 10 and 16 | **partly** (the direction holds; +83 % is above "up to +68 %") |
| tuned tiles of M 6, 8, 16 | `16/16/32, 1 warp` for the two QKV input projections; `16/16/128, 4 warps` for `out_proj + o_proj` and `gate_up`; `down_proj` varies with M | `self_attn.qkv_proj` `[16, 16, 32, 1, …]` at M 6, 8 and 16; `out_proj+o_proj` and `gate_up` `[16, 16, 128, 4, …]` at all three; `down_proj` varies (`[16, 16, 32, 2]`, `[16, 16, 32, 2]`, `[16, 16, 128, 8]`). `linear_attn.in_proj_qkvz` is `[16, 16, 32, 1]` at M 8 only: `[16, 32, 32, 1]` at M 6 and `[16, 64, 128, 4]` at M 16 | **partly** (the tile of `in_proj_qkvz` at M 6 and 16 is not the recorded one) |
| `tuned_maxdiff` 0.0, `split_maxdiff` at most 0.0078 | yes | 0.0 in every row; 0.0078125 at most | yes |
| stops and restores of the operator's server | one stop, one restore | one stop that WORKED (the server was gone) but whose call returned code 1: one failed try was counted (finding (a) of `research/ACCEPTANCE_moe_tune_2026-11-02.md`); one `restored` at 18:39:05Z | **partly** |
| exit-path line | `cleanup hook: moe_cache_clear rc=0` before `restored` | at 18:33:40Z, before `restored` at 18:39:05Z | yes |
| the cache clear names three cache folders | three | the clear before the unit printed two (`triton-moe-ab` 4.7M and `triton-linear` 135M), the one in the exit path printed one (`triton-linear` 135M): `du` names the folders that exist | **no** (the code prints only the folders that exist) |
| no prefixed container left, no `rejected/` | none | no `wslc list` was taken after the run; the next unit that used the same container name (`r9700tune-linear-bench-2`, step 2 of run 2 of `research/ACCEPTANCE_run_2026-11-03.md`, 19:24Z) started without a name clash. No `rejected/` entry belongs to this unit | yes for `rejected/`; the container half is indirect |

What the table says. The structure of § 12.1 is there: the default and the Triton default are about equal from M 6, the split HIP op is slower, the tuned tile is faster, the maxdiff limits hold, and M 1 to 5 are inside ± 5 %. The numbers of M 6 to 16 in the default columns are 6 to 10 % lower than the recorded ones, so the change column is 3 to 4 points away from the recorded one at M 6, 12 and 16 (smaller at M 6, larger at M 12 and 16). This record does not say why (the image tag was read back from `linear.env`; whether the driver or the image of 2026-10-30 is the same was NOT checked). **The same unit was run again the same evening** as step 2 of run 2 of `research/ACCEPTANCE_run_2026-11-03.md` (name `run-a`): its M 12 change is -8 % (here -5 %), its M 16 default is 5.93 ms (here 6.21 ms, 4.5 % apart), and its tile for `in_proj_qkvz` at M 6 is `[16, 32, 64, 2, 2]` (here `[16, 32, 32, 1, null]`). So the toolkit's own run-to-run difference is of the size of the prediction's ± 2 points and ± 5 %: a cell outside the prediction by that much is not a measurement of a change of the machine.

## Observed: the guards and the cache

The supervisor log of the run folder (`runs/20261103T182511Z-1251184`; it is the lines of the command's output above, without the `recorded`, `restore:` and table lines), the step's `worker.log`, the RAM guard log and the exit-path hook log:

```
2026-11-03T18:25:11Z coai-exp processes=0 load=0.58 quiet-checks=1/1
2026-11-03T18:25:11Z QUIET
2026-11-03T18:25:12Z disk gate: baseline 4566
2026-11-03T18:25:35Z failed try 1 of 3: admit stopping vllm failed (code 1)
2026-11-03T18:25:35Z coai-exp processes=0 load=1.09 quiet-checks=1/1
2026-11-03T18:25:35Z QUIET
2026-11-03T18:25:38Z disk gate: OK: no new disk event (newest 4566)
2026-11-03T18:25:38Z admitted
2026-11-03T18:25:39Z worker started: session 1252085, start ticks 3362864
2026-11-03T18:33:39Z worker ended rc=0
2026-11-03T18:33:40Z cleanup hook: moe_cache_clear rc=0
2026-11-03T18:39:05Z restored

--- steps/2.worker.log
=== 2026-11-03T18:25:39Z linear acceptance (graph, ms 1 2 3 4 5 6 8 10 12 16, sweep 6 8 12 16)
cache clear: running (ceiling 90 s)
cache before clear: 4.7M /root/.cache/vllm/triton-moe-ab,135M /root/.cache/vllm/triton-linear
recorded linear/acceptance
--- steps/2.ram_guard.log
2026-11-03T18:25:41Z available RAM 47579 MB
2026-11-03T18:31:25Z available RAM 48766 MB
--- guard/cleanup-hook.log
cache clear: running (ceiling 90 s)
cache before clear: 135M /root/.cache/vllm/triton-linear
```

Two things in it that the prediction did not have: the quiet gate printed `quiet-checks=1/1` at once (finding (c) of the moe-tune record), and line 4 of the log, `failed try 1 of 3: admit stopping vllm failed (code 1)`: the stop returned 1, yet the next admission, 3 seconds later, did not stop the server again (there is no second `stopped the operator's server` line) and went on to `admitted`. That is finding (a) of the moe-tune record; the cause is not known.

## Questions the run answers

- Does a foreground `wslc run --rm --name <name>` appear in `wslc list` while it runs, and does `wslc stop <name>` end it? (The question of the `moe-tune` acceptance too; UNVERIFIED until one of the two runs.) Answer: NOT answered. No `wslc list` was taken while a unit ran, in this run or in the others of 2026-11-03, so this stays UNVERIFIED. What the runs show: no step of the day found a name in use, and the worker ended by itself each time.
- What does `du` print for `triton-linear` after the run? The size was never measured (144 tiles x 5 shapes x 4 sweep Ms are compiled). Answer: `cache before clear: 135M /root/.cache/vllm/triton-linear` (the exit-path clear, `guard/cleanup-hook.log`). The clear before the unit printed `4.7M /root/.cache/vllm/triton-moe-ab,135M /root/.cache/vllm/triton-linear`, the same 135M: that folder was already there before this unit (where it came from was not checked), so 135M is the size a run leaves, not a growth caused by this one.
- Does the port measure what the two old files measured? Answer: in structure yes, in the numbers partly: M 1 to 5 within 3 %, the default columns of M 6 to 16 6 to 10 % lower, the change column 3 to 4 points away at M 6, 12 and 16 (the table above); `tuned_maxdiff` 0.0 and `split_maxdiff` 0.0078125 as recorded. The same unit run twice on this day differs by about as much as the gap to § 12.1.

## What this record does not settle

One model, one image, one run. It does not say that a tuned tile gains anything end to end (§ 12.1 line 539: "not shown: an end-to-end gain"), and it says nothing about the 27B AWQ model, whose file leaves `LINEAR_SHAPES` empty because
nobody has measured whether that model takes the hybrid W4A16 kernel. A "tuned is not faster at M 12" is the recorded result, not a failure.
