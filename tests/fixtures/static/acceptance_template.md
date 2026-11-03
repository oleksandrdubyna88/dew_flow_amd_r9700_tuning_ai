# Acceptance of `bin/r9700 prefixtest` on the R9700 — prepared 2026-11-03, NOT RUN YET

The flow that CI cannot run (`research/module_tests.md`): it needs the GPU, the real `wslc`, the real image, the model and a real vLLM server. The operator's
session runs it before a release and pastes the output below. Until then every section named "observed" is empty on purpose. The operator holds GPU runs for
now: this file is a template, as the acceptance of `series` and of `moe-tune` were.

## Subject and conditions (fill in at the run)

| | |
|---|---|
| Subject (commit of this repository) | `<sha>` |
| Harness | `bin/r9700` (verbs `init`, `prefixtest`) |
| Date of the run, machine | `<date>`, the R9700 PC |
| Model file, arm | `models/qwen3.6-35b-a3b-gptq.env`, unedited; arm `base` of `config/arms.conf` |
| Out, name | `acceptance-kernels`, `acceptance` (the record is `<RESULTS_DIR>/acceptance-kernels/prefix/acceptance/`) |
| Pinned, not varied | the image tag, the model file, the arm's serve options (built by the series' own builder), `lib/prefixtest.py` (its hash is in `prefix.env`), `--lens` at its default (`8192 1024`) and `--tail` at its default (64) |
| Machine file | the operator's `machine.env` (not copied here: it holds the machine's paths) |
| Compared with | `dew_flow_benchmark · research/RESULTS_vllm_029_r9700_speed_options.md` § 13.3 (lines 635-639: three of the eight arm-rounds), the raw file `raw/prefixtest.txt` of the night of 2026-10-31 (16 lines), and § 6.5 (the RAM dip of a model load) |

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
(paste the output of bin/r9700 init)
```

## Observed: the run

```
(paste the output of the prefixtest command, and `ls -l <RESULTS_DIR>/acceptance-kernels/prefix/acceptance`; prefix.env)
```

```
(paste prefixtest.txt and summary.txt)
```

Observed against predicted: `(table: minutes to ready, the 8k times and the 1k times against § 13.3, the two ratios, stops and restores, one row each)`.

## Observed: the guards

```
(paste the supervisor log of the run folder: the quiet checks, admitted, the RAM guard reads, restored)
```

## Questions the run answers

- Does the stall of § 6.1 show on the first request of a fresh server? Answer: `(the A cold and B cold of each length; the ratio)`.
- Is the server stopped by name before the worker ends, and is no prefixed container left? Answer: `(wslc list after the run)`.
- Does a model load drive the RAM below the guard's limit with the default `RAM_MIN_MB`? Answer: `(the RAM guard log of the step)`.

## What this record does not settle

One model, one arm, one image, one run. The check applies no threshold: it says how long a cold and a hit request take, not whether the prefix cache is "working". It does not find the cause of the stall of § 6.1; it only
shows whether the stall is on a cold request of a fresh server. It says nothing about the other arms (the series runs the same check after an arm-round in the old nights; the toolkit's `series` does not), and nothing about
the production server.
