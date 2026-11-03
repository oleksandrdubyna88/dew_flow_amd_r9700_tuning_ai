# Acceptance of `bin/r9700 linear-bench` on the R9700 — prepared 2026-11-03, NOT RUN YET

The flow that CI cannot run (`research/module_tests.md`): it needs the GPU, the real `wslc`, the real image and the model's linear shapes. The operator's
session runs it before a release and pastes the output below. Until then every section named "observed" is empty on purpose. The operator holds GPU runs for
now: this file is a template, as the acceptance of `series` and of `moe-tune` were.

## Subject and conditions (fill in at the run)

| | |
|---|---|
| Subject (commit of this repository) | `<sha>` |
| Harness | `bin/r9700` (verbs `init`, `linear-bench`) |
| Date of the run, machine | `<date>`, the R9700 PC |
| Model file | `models/qwen3.6-35b-a3b-gptq.env`, unedited (`LINEAR_SHAPES` holds the five shapes of the speed-options runs, `LINEAR_GROUP_SIZE=128`) |
| Out, name | `acceptance-kernels`, `acceptance` (the record is `<RESULTS_DIR>/acceptance-kernels/linear/acceptance/`) |
| Pinned, not varied | the image tag, the model file, `lib/linear_bench.py` (its hash is in `linear.env`), the seed 0 of the benchmark (random weights: only timing noise differs between runs), `--ms` and `--sweep-ms` at their defaults, `--timer graph` |
| Machine file | the operator's `machine.env` (not copied here: it holds the machine's paths) |
| Compared with | `dew_flow_benchmark · research/RESULTS_vllm_029_r9700_speed_options.md` § 12.1 (the CUDA-graph run of the night of 2026-10-30, the table of lines 519-528), and the published JSON the test `tests/test_linear_bench.py` (LB1) reproduces it from |

## Commands

```bash
bin/r9700 init
bin/r9700 linear-bench qwen3.6-35b-a3b-gptq --name acceptance --out acceptance-kernels
```

## Prediction, written BEFORE the run (measurement rule 4)

From § 12.1 (the same seed, the same shapes and Ms, random weights; the old run was `linear_bench_graph.py`, the toolkit's `--timer graph` is its port):

- the container runs about 6 minutes after its start (the old run took 00:12 to 00:18, § 12.1 line 514); the first lines are `kernels: outdir …` and `cache clear: running …`, and the record is `recorded linear/acceptance`.
- `linear_bench.json` holds 50 rows (5 shapes x 10 Ms). `summary.txt` prints the table of § 12.1 within a few percent per cell: M 1 default about 2.48 ms (split about 2.79); M 6 about 4.91 / 4.79 / 5.89 / 4.28 (default, Triton default tile, split HIP, tuned), change about -13 %;
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
(paste the output of bin/r9700 init)
```

## Observed: the run

```
(paste the output of the linear-bench command, and `ls -l <RESULTS_DIR>/acceptance-kernels/linear/acceptance`; linear.env)
```

```
(paste summary.txt)
```

Observed against predicted: `(table: container minutes, rows, M 1, M 6 and M 16 cells against § 12.1, split above default for M of 6 and more, the tiles of M 6, 8 and 16, the two maxdiff limits, stops and restores, one row each)`.

## Observed: the guards and the cache

```
(paste the supervisor log of the run folder: the quiet checks, admitted, the cache clear line with its three folders, the hook line, restored)
```

## Questions the run answers

- Does a foreground `wslc run --rm --name <name>` appear in `wslc list` while it runs, and does `wslc stop <name>` end it? (The question of the `moe-tune` acceptance too; UNVERIFIED until one of the two runs.) Answer: `(yes/no: wslc list during the run)`.
- What does `du` print for `triton-linear` after the run? The size was never measured (144 tiles x 5 shapes x 4 sweep Ms are compiled). Answer: `(the line of the cache clear)`.
- Does the port measure what the two old files measured? Answer: `(the cells against § 12.1)`.

## What this record does not settle

One model, one image, one run. It does not say that a tuned tile gains anything end to end (§ 12.1 line 539: "not shown: an end-to-end gain"), and it says nothing about the 27B AWQ model, whose file leaves `LINEAR_SHAPES` empty because
nobody has measured whether that model takes the hybrid W4A16 kernel. A "tuned is not faster at M 12" is the recorded result, not a failure.
