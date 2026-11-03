# Acceptance of `bin/r9700 prefixtest` on the R9700 — prepared 2026-11-03, RUN 2026-11-03 (quiet gate off)

The flow that CI cannot run (`research/module_tests.md`): it needs the GPU, the real `wslc`, the real image, the model and a real vLLM server. The operator's
session runs it before a release and pastes the output below. It was run on 2026-11-03 (the sections below); the prediction section is as it was written before the run, unchanged.

## Subject and conditions (fill in at the run)

| | |
|---|---|
| Subject (commit of this repository) | `d983327` (main after #8) |
| Harness | `bin/r9700` (verbs `init`, `prefixtest`) |
| Date of the run, machine | 2026-11-03 20:06–20:15 CET, the R9700 PC |
| Model file, arm | `models/qwen3.6-35b-a3b-gptq.env`, unedited; arm `base` of `config/arms.conf` |
| Out, name | `acceptance-kernels`, `acceptance` (the record is `<RESULTS_DIR>/acceptance-kernels/prefix/acceptance/`) |
| Command | `R9700_QUIET_CHECKS=1 bin/r9700 prefixtest qwen3.6-35b-a3b-gptq --name acceptance --arm base --out acceptance-kernels`, with `QUIET_LOAD_MAX=16` in `machine.env` (the operator: "don't wait") |
| Pinned, not varied | the image tag, the model file, the arm's serve options (built by the series' own builder), `lib/prefixtest.py` (its hash is in `prefix.env`: `PREFIXTEST_SHA256=f01b783d895d…`), `--lens` at its default (`8192 1024`) and `--tail` at its default (64) (all read back in `prefix.env`) |
| Machine file | the operator's `machine.env` (not copied here: it holds the machine's paths) |
| Compared with | `dew_flow_benchmark · research/RESULTS_vllm_029_r9700_speed_options.md` § 13.3 (lines 635-639: three of the eight arm-rounds), the raw file `raw/prefixtest.txt` of the night of 2026-10-31 (16 lines), and § 6.5 (the RAM dip of a model load) |
| Quiet gate | OFF by the operator's decision: one quiet check and a load limit of 16. The read of this run was load 1.68, so the PC was quiet anyway |

## Commands

```bash
bin/r9700 init
bin/r9700 prefixtest qwen3.6-35b-a3b-gptq --name acceptance --arm base --out acceptance-kernels
```

## Prediction, written BEFORE the run (measurement rule 4)

From § 13.3 and § 6.5 (the old run was `prefixtest.py` after the bench of every arm-round; the toolkit starts one server for the check alone, so the server is fresh):

- the server is ready in 3 to 5 minutes (a model load; § 6.5 lines 283-304: the RAM of the PC dips to a few hundred MB for about 1.5 minutes during a load, which is why a RAM guard set near 2 GB can fire).
- the record is `<RESULTS_DIR>/acceptance-kernels/prefix/acceptance/` with `prefixtest.txt` (exactly two lines, one per length), `summary.txt`, `server.log` and `prefix.env`.
- the 8k line: `A cold` about 2.0 to 2.2 s, `A hit` and `B hit` about 0.46 to 0.51 s, `A partial` about 0.46 to 0.49 s (§ 13.3: `fcombo-1` 2.10 / 0.50 / 0.51 / 2.15 / 0.48 / 0.49; `fbase-3` 2.00 / 0.47 / 0.47 / 1.96 / 0.46 / 0.46).
- the 1k line: every value about 0.18 to 0.22 s.
- `summary.txt` prints `(4.2x)` (between 4.0x and 4.5x) for the 8192 line and `(1.0x)` (between 0.8x and 1.1x) for the 1024 line; no verdict and no threshold (the program only prints times).
- the operator's server is stopped once and is back, ready, after the run; the test server is stopped by name before the worker ends; no prefixed container is left.
- no `rejected/` folder.

What would make it wrong, and what it would mean:

- **the stall of § 6.1 on a cold request.** If one cold request waits about 12 to 14 s more than the others (`A cold` or `B cold` near 12 to 14 s, and the 8k ratio near 25x), the record shows the stall on a fresh server: a record of the stall, not a failure of the toolkit.
  The record then says which request, and the cause stays unknown (results § 13.3 line 642).
- a busy PC: the quiet phase should prevent it.
- a RAM stop during the load: a true reason (§ 6.5); the supervisor retries and the record says so.
- a different image: a hit may then cost something else; the record says the image tag.

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

Command output, as printed (`start …` and `end …` are the operator's session's time stamps, in CET; the other times are UTC, `Z`):

```
start 2026-11-03 20:06:34
kernels: outdir <RESULTS_DIR>/acceptance-kernels
2026-11-03T19:06:34Z coai-exp processes=0 load=1.68 quiet-checks=1/1
2026-11-03T19:06:34Z QUIET
2026-11-03T19:06:35Z disk gate: baseline 4566
2026-11-03T19:06:49Z stopped the operator's server (stop 1 of 3)
2026-11-03T19:06:49Z admitted
2026-11-03T19:06:49Z worker started: session 1382914, start ticks 3609907
2026-11-03T19:10:49Z worker ended rc=0
recorded prefix/acceptance
PREFIX acceptance len=8192: cold 2.06 s, hit 0.48 s (4.3x), partial 0.50 s
PREFIX acceptance len=1024: cold 0.25 s, hit 0.25 s (1.0x), partial 0.30 s
restore: starting vllm with <RESTORE_SCRIPT_WIN>
vLLM patches active from <the start script's patch folder>: auto_gptq.py, gptq_utils.py, moe\ tuned config (see README.md there)
2e45b026fb50f4704564379b302d1d65729b6f32d3445c1204a012aedc276aaf
2026-11-03T19:15:19Z restored
rc=0
end 2026-11-03 20:15:19
```

The record folder (`stat -c '%s  %n'`, so no account name is printed), and `prefix.env`:

```
1821  <RESULTS_DIR>/acceptance-kernels/prefix/acceptance/prefix.env
215  <RESULTS_DIR>/acceptance-kernels/prefix/acceptance/prefixtest.txt
35738  <RESULTS_DIR>/acceptance-kernels/prefix/acceptance/server.log
150  <RESULTS_DIR>/acceptance-kernels/prefix/acceptance/summary.txt
NAME=acceptance
MODEL=qwen3.6-35b-a3b-gptq
IMAGE=rocm/vllm:rocm10.1.0_ubuntu24.04_py3.14-pytorch_2.13.0_vllm-0.29.0
MODEL_DIR=/root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ
ARM=base
ARM_ARGS="--speculative-config.method mtp --speculative-config.num_speculative_tokens 2"
ARM_ENV=
ARM_MOUNTS=
SERVED_NAME=qwen3.6-35b-a3b
LENS="8192 1024"
TAIL=64
SERVE_LINE="wslc run -d --rm --name identity --gpus all --shm-size 16g -e HIP_VISIBLE_DEVICES=0 -e TRITON_CACHE_DIR=/root/.cache/vllm/triton -e PYTHONPYCACHEPREFIX=/tmp/pyc-fresh -e PYTHONDONTWRITEBYTECODE=1 -e VLLM_TUNED_CONFIG_FOLDER=/work/moe/tune/merged -v hf-cache:/root/.cache/huggingface -v vllm-cache:/root/.cache/vllm -v <WORK_DIR_WIN>:/work -v <GENCONFIG_WIN>:/genconfig:ro -v <PATCH_DIR_WIN>\C\auto_gptq.py:/opt/python/lib/python3.14/site-packages/vllm/model_executor/layers/quantization/auto_gptq.py:ro -v <PATCH_DIR_WIN>\C\gptq_utils.py:/opt/python/lib/python3.14/site-packages/vllm/model_executor/layers/quantization/utils/gptq_utils.py:ro rocm/vllm:rocm10.1.0_ubuntu24.04_py3.14-pytorch_2.13.0_vllm-0.29.0 vllm serve /root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ --served-model-name qwen3.6-35b-a3b --host 0.0.0.0 --port 8000 --max-model-len 131072 --gpu-memory-utilization 0.85 --max-num-seqs 4 --generation-config /genconfig --limit-mm-per-prompt.image 0 --limit-mm-per-prompt.video 0 --speculative-config.method mtp --speculative-config.num_speculative_tokens 2"
LINEAR_BENCH_SHA256=e28f6eb41aa53e503f3e6d5cf4d63c8c58bb3e09456e78c8f1a67497e6062cba
PREFIXTEST_SHA256=f01b783d895d0c7e0c949428654c9a8e1aa3c435a12af692423468520314f22c
CONTAINER=r9700tune-prefix-base-1
RUN_ID=20261103T190634Z-1382607
STARTED_AT=2026-11-03T19:06:50Z
ENDED_AT=2026-11-03T19:10:46Z
RC=0
```

`prefixtest.txt` (exactly two lines) and `summary.txt`:

```
acceptance prefixtest len=8192 A cold=2.14s A hit=0.47s A hit=0.47s B cold=1.98s B hit=0.49s A partial=0.5s
acceptance prefixtest len=1024 A cold=0.27s A hit=0.2s A hit=0.22s B cold=0.22s B hit=0.32s A partial=0.3s
--- summary.txt
PREFIX acceptance len=8192: cold 2.06 s, hit 0.48 s (4.3x), partial 0.50 s
PREFIX acceptance len=1024: cold 0.25 s, hit 0.25 s (1.0x), partial 0.30 s
```

Observed against predicted:

| | predicted | observed | held? |
|---|---|---|---|
| minutes to ready | 3 to 5 | `READY (waited 222 s here)`: 3 min 42 s (the worker ran 4 min in all) | yes |
| the record | `prefixtest.txt` (two lines), `summary.txt`, `server.log`, `prefix.env` | exactly those four files; `prefixtest.txt` has two lines | yes |
| 8k `A cold` | about 2.0 to 2.2 s | 2.14 s (`B cold` 1.98 s; `summary.txt` prints the cold of the two as 2.06) | yes |
| 8k `A hit`, `B hit` | about 0.46 to 0.51 s | 0.47, 0.47 and 0.49 s | yes |
| 8k `A partial` | about 0.46 to 0.49 s | 0.5 s | **no** (0.01 s above) |
| 1k, every value | about 0.18 to 0.22 s | 0.27 (`A cold`), 0.2, 0.22, 0.22 (`B cold`), 0.32 (`B hit`), 0.3 (`A partial`) | **no** (three of six are above: 0.27, 0.32, 0.3) |
| ratio of the 8192 line | `(4.0x)` to `(4.5x)` | `(4.3x)` | yes |
| ratio of the 1024 line | `(0.8x)` to `(1.1x)` | `(1.0x)` | yes |
| the operator's server | stopped once, back and ready after the run | `stopped the operator's server (stop 1 of 3)` at 19:06:49Z; `restored` at 19:15:19Z | yes |
| the test server stopped by name, no prefixed container left | none left | no `wslc list` was taken after the run. Indirect: 5 min 23 s after this container ended (`ENDED_AT` 19:10:46Z) the next unit (run 1 of `research/ACCEPTANCE_run_2026-11-03.md`) started a container of the SAME name (`r9700tune-prefix-base-1`) with no name clash | indirect |
| no `rejected/` folder | none | none at the end of this run (the first `rejected/` entry of `acceptance-kernels/` is from run 1 of the run record, 19:20Z) | yes |

The 1k line is a reading, not a failure: this run's 1k values are 0.05 to 0.10 s above the band, and the same check run again (step 1 of run 2 of the run record, name `run-a`, 20:20 CET) has every 1k value at 0.18 or 0.19 s and its 8k line at 2.09 / 0.46 / 0.46 / 1.93 / 0.46 / 0.46 s, inside the band. So the 1k values of this run are about as far from the band as the check varies from one run to the next; one run does not settle a band for the 1k line.

## Observed: the guards

The supervisor log of the run folder (`runs/20261103T190634Z-1382607`), the step's `worker.log`, and the RAM guard log:

```
2026-11-03T19:06:34Z coai-exp processes=0 load=1.68 quiet-checks=1/1
2026-11-03T19:06:34Z QUIET
2026-11-03T19:06:35Z disk gate: baseline 4566
2026-11-03T19:06:49Z stopped the operator's server (stop 1 of 3)
2026-11-03T19:06:49Z admitted
2026-11-03T19:06:49Z worker started: session 1382914, start ticks 3609907
2026-11-03T19:10:49Z worker ended rc=0
2026-11-03T19:15:19Z restored
--- steps/1.worker.log
=== 2026-11-03T19:06:49Z prefix acceptance (arm base, lens 8192 1024, tail 64)
5782e4271d30822b239f817db86a386dc1db8798834a9337481c980b8f0d8a44
READY (waited 222 s here)
recorded prefix/acceptance
--- steps/1.ram_guard.log
2026-11-03T19:06:51Z available RAM 37625 MB
```

The quiet gate printed `quiet-checks=1/1` at once (one check, load limit 16: the operator's decision). There is no guard line other than the RAM guard's first read.

## Questions the run answers

- Does the stall of § 6.1 show on the first request of a fresh server? Answer: no. 8192: `A cold` 2.14 s and `B cold` 1.98 s, the ratio 4.3x (the stall would show as a cold request 12 to 14 s above the others and a ratio near 25x); 1024: `A cold` 0.27 s and `B cold` 0.22 s. The repeat of the check (`run-a`) agrees: 2.09 and 1.93 s. Two fresh servers, 8k and 1k, no stall.
- Is the server stopped by name before the worker ends, and is no prefixed container left? Answer: not observed directly: no `wslc list` was taken after the run. The worker ended with rc 0 and `restored` followed; the same container name started cleanly 5 min 23 s after this container ended (above). The step's `worker.log` has no stop line of its own.
- Does a model load drive the RAM below the guard's limit with the default `RAM_MIN_MB`? Answer: not seen, and the log cannot show a short dip. The guard read the PC every 15 s and would have stopped the step at the first read below 2048 MB; it did not (no `ram_guard` outcome, `steps/1.outcome` is `KIND=worker RC=0`). The log keeps only the first read (37625 MB at 19:06:51Z, two seconds after the start, before the load) and every 20th (five minutes), and the run lasted 4 minutes, so no read DURING the load is written down. The model load of run 2 of the run record is the second load of the same kind: its log holds the same, and it too ended without a guard stop. The record of § 6.5 (a dip of about 1.5 minutes to a few hundred MB) did not repeat in a way that a 15 s read would catch; the machine started with 32058 MB available (`init`) and about 37 GB at the first read.

## What this record does not settle

One model, one arm, one image, one run. The check applies no threshold: it says how long a cold and a hit request take, not whether the prefix cache is "working". It does not find the cause of the stall of § 6.1; it only
shows whether the stall is on a cold request of a fresh server. It says nothing about the other arms (the series runs the same check after an arm-round in the old nights; the toolkit's `series` does not), and nothing about
the production server.
