# Acceptance of `bin/r9700 series` on the R9700 — prepared 2026-11-02, RUN 2026-11-02 (one round, quiet gate off)

The one flow that CI cannot run (`research/module_tests.md`): it needs the GPU, the real `wslc`, the real image and the model. The operator's
session runs it before a release and pastes the output below. Until then every section named "observed" is empty on purpose.

## Subject and conditions (fill in at the run)

| | |
|---|---|
| Subject (commit of this repository) | `901b48e` (main after #2; `lib/` and `bin/` are equal at 255aeac) |
| Harness | `bin/r9700` (verbs `init`, `series`, `verdict`) |
| Date of the run, machine | 2026-11-02 22:40–23:34 CET, the R9700 PC |
| Model file | `models/qwen3.6-35b-a3b-gptq.env`, unedited |
| Arms | `base` and `ta3` of `config/arms.conf`, unedited |
| Rounds | 1 (`--rounds 1`) |
| Command | `R9700_QUIET_CHECKS=1 bin/r9700 series qwen3.6-35b-a3b-gptq base ta3 --rounds 1 --out acceptance`, with `QUIET_LOAD_MAX=16` in `machine.env` (the operator: no quiet wait) |
| Pinned, not varied | the image tag, the patch files, the generation config and the tuned MoE folder of the model file; the quality prompts and GSM8K n 200; seeds 1-3 |
| Machine file | the operator's `machine.env` (not copied here: it holds the machine's paths) |

## Prediction, written BEFORE the run (measurement rule 4)

`ta3` is `fcombo` of 2026-10-31 under another name (MTP 3 speculative tokens and the Triton attention backend), so against `base` it should come out
as `fcombo` did:

- c=1: about +8 tok/s over the base median (the recorded `fcombo`: median 84.47 against 76.08).
- c=4: about +24 tok/s (202.44 against 178.39).
- the verdict for `ta3`: PASS, quality within the GSM8K limit.
- one round gives 3 values per concurrency; the base spread of 3 values is smaller than the recorded 9-value spread (9.84 at c=1), so a PASS is
  easier to reach than in the recorded verdict, and the output must carry the `note: 1 round` line.
- the machine: the operator's server is stopped once and is back, ready, when the command ends; no `rejected/` and no `unsupported/` folder.

What would make this prediction wrong, and what it would mean: a FAIL with a delta near 0 would say the arms did not differ (read back the `server_config.txt` of
both records); a delta much larger than +8 at c=1 would say the base ran without something the recorded base had.

## Observed: `init`

```
(run again at 23:36 after the series; the first output, 21:05, was lost with /tmp at the reboot — it was the same 8 ok lines)
init: config: ok
init: results dir: ok
init: state dir: ok
init: wslc: ok
init: vllm: running
init: leftover containers: none
init: ram telemetry: ok (9917 MB)
init: disk telemetry: ok (record 4566)
rc=0
```

## Observed: the series

First attempt (21:42, the default quiet gate), kept as written:

```
series: outdir <RESULTS_DIR>/acceptance
2026-11-02T20:42:55Z coai-exp processes=0 load=0.02 quiet-checks=1/3 next check in 300 s
2026-11-02T20:47:55Z coai-exp processes=0 load=3.63 quiet-checks=2/3 next check in 300 s
2026-11-02T20:52:55Z coai-exp processes=0 load=2.53 quiet-checks=3/3
2026-11-02T20:52:55Z QUIET
2026-11-02T20:52:56Z disk gate: baseline 4566
2026-11-02T20:53:14Z admitted
2026-11-02T20:53:14Z worker started: session 128995, start ticks 232599
2026-11-02T21:00:37Z worker ended rc=1
2026-11-02T21:00:37Z failed try 1 of 3: worker 1
2026-11-02T21:00:37Z coai-exp processes=0 load=3.91 quiet-checks=1/3 next check in 300 s
2026-11-02T21:05:37Z coai-exp processes=0 load=4.12 quiet-checks=0/3 next check in 300 s
2026-11-02T21:10:37Z coai-exp processes=0 load=2.50 quiet-checks=1/3
2026-11-02T21:15:37Z restoring the operator's server while the PC is not quiet
restore: starting vllm with <RESTORE_SCRIPT_WIN>
vLLM patches active from <the start script's patch folder>: auto_gptq.py, gptq_utils.py, moe\ tuned config (see README.md there)
e8968f84d3ca1337e5c042afe4396e1817e1854dfab6786cb5a9554681d9db9b
2026-11-02T21:19:57Z restored
2026-11-02T21:19:57Z coai-exp processes=0 load=3.11 quiet-checks=1/3 next check in 300 s
2026-11-02T21:24:57Z coai-exp processes=0 load=5.92 quiet-checks=0/3 next check in 300 s
2026-11-02T21:29:57Z coai-exp processes=0 load=3.41 quiet-checks=1/3
2026-11-02T21:34:57Z coai-exp processes=0 load=10.22 quiet-checks=0/3 next check in 300 s
2026-11-02T21:39:57Z coai-exp processes=0 load=6.28 quiet-checks=0/3 next check in 300 s
2026-11-02T21:40:19Z signal TERM: cleaning up
r9700: interrupted, restored
```

Second run (22:40, one quiet check, `QUIET_LOAD_MAX=16`):

```
series: outdir <RESULTS_DIR>/acceptance
2026-11-02T21:40:36Z coai-exp processes=0 load=7.62 quiet-checks=1/1
2026-11-02T21:40:36Z QUIET
2026-11-02T21:40:39Z disk gate: baseline 4566
2026-11-02T21:40:54Z admitted
2026-11-02T21:40:54Z worker started: session 919901, start ticks 518605
2026-11-02T22:29:33Z worker ended rc=0
restore: starting vllm with <RESTORE_SCRIPT_WIN>
vLLM patches active from <the start script's patch folder>: auto_gptq.py, gptq_utils.py, moe\ tuned config (see README.md there)
47b3d26ec1438f7f01cb5af18e9dd1d9aa93fa0011f1a7f7f71581c26f6ef353
2026-11-02T22:34:14Z restored
series rc=0
```

```
<RESULTS_DIR>/acceptance:
fingerprint.json
quality
rejected
rounds

<RESULTS_DIR>/acceptance/quality:
gsm8k_base.json
gsm8k_ta3.json

<RESULTS_DIR>/acceptance/rejected:
base-1-20261102T210034Z

<RESULTS_DIR>/acceptance/rejected/base-1-20261102T210034Z:
bench.txt
reason
record.env
server.log
server_config.txt
spec_metrics.txt

<RESULTS_DIR>/acceptance/rounds:
base-1
ta3-1

<RESULTS_DIR>/acceptance/rounds/base-1:
bench.txt
collect.out
gsm8k.out
gsm8k_base.json
prompts_base.json
record.env
server.log
server_config.txt
spec_metrics.txt

<RESULTS_DIR>/acceptance/rounds/ta3-1:
bench.txt
collect.out
gsm8k.out
gsm8k_ta3.json
prompts_ta3.json
record.env
server.log
server_config.txt
spec_metrics.txt
```

Read back, one cell per arm (measurement rule 1): `rounds/base-1/server_config.txt` and `rounds/ta3-1/server_config.txt`, to prove the arms differed.
Observed: `base` logs `num_speculative_tokens: 2` and `Fused multi-step draft decode is not supported by attention backend(s) ROCM_ATTN`; `ta3` logs
`num_speculative_tokens: 3` and `Using TRITON_ATTN backend (selected via --attention-backend)`. Both records carry the fingerprint `cc953f70dd56…`.

## Observed: the verdict

```
series <RESULTS_DIR>/acceptance: base base, 1 rounds, fingerprint cc953f70dd56
note: 1 round, 3 values per concurrency; the recorded ship test used 3 rounds (9)
invoking: python3 <checkout>/lib/verdict.py ship --base base --arm ta3 --bench <RESULTS_DIR>/acceptance/rounds/base-1/bench.txt --bench <RESULTS_DIR>/acceptance/rounds/ta3-1/bench.txt --prefill-lens 8192 32768 --rounds 1 --gsm8k-dir <RESULTS_DIR>/acceptance/quality
arm ta3 vs base: 1 round, 3 values per concurrency
  c=1 output tok/s: median 84.18 vs 77.18, delta +7.00, base spread 4.45 -> higher
  c=4 output tok/s: median 187.08 vs 179.56, delta +7.52, base spread 18.11 -> within, not lower
  prefill8192 median TTFT ms: median 2027.28 vs 1950.33, delta +76.95, base spread 96.23 (information)
  prefill32768 median TTFT ms: median 15527.95 vs 16094.37, delta -566.42, base spread 416.77 (information)
  gsm8k accuracy: 0.8450 vs 0.8500, delta -0.0050, limit 0.0512 -> pass
verdict ta3: PASS
```

Observed against predicted:

| | predicted | observed | held? |
|---|---|---|---|
| c=1 delta | about +8 tok/s | +7.00 (84.18 vs 77.18), base spread 4.45 → higher | yes |
| c=4 delta | about +24 tok/s | +7.52 (187.08 vs 179.56), base spread 18.11 → within | **no** |
| verdict `ta3` | PASS | PASS | yes |
| quality | within the GSM8K limit | 0.845 vs 0.850, limit 0.051 | yes |
| `note: 1 round` line | present | present | yes |
| the machine | one stop, the server back; no `rejected/`, no `unsupported/` | the server back and ready; one `rejected/` (the first attempt, below) | **partly** |

- **c=4 is much smaller than predicted, and the base's c=4 spread (18.11 tok/s over 3 values) is three times the 5.41 of the quiet nights.** The
  quiet gate was off by the operator's decision, and the 1-minute load was 7.6 at admission (other sessions' test suites and reviews). With c=4
  inside a spread that large, this round says nothing about c=4; it does not contradict § 13.2 of the benchmark record (+14.1 % over 3 quiet rounds).
- **`rejected/base-1-20261102T210034Z`: the first attempt's base round died in the middle of the bench** (`LOST: server alive 0`, bench code 137,
  6 of 36 lines). At that minute the PC ran a fork storm of a test of another story (about 15,900 processes; fixed since, with a process cap in
  `tests/run.mjs`). The cause of the server's death is not proven. The series did what it must: the part became a rejected record with the reason,
  the failed try was counted, and the operator's server was restored while it waited. That attempt was then stopped by TERM in its quiet wait
  (`interrupted, restored`), and the second run resumed the same folder.

## The 27B model file as a dry run

The second example model runs `series` unedited as a DRY RUN here: the dry run loads the config, computes the fingerprint without writing it (the throwaway container
runs, so the model listing is real) and prints every resolved command of the first arm-round without starting a server. A second real run costs about
25 minutes of the GPU for no new mechanism. (If the session ran it for real instead, say so here.)

```
series: outdir <RESULTS_DIR>/acceptance27
dry-run: wslc run -d --rm --name r9700tune-sp-base-1 --gpus all --shm-size 16g -e HIP_VISIBLE_DEVICES=0 -e TRITON_CACHE_DIR=/root/.cache/vllm/triton -e PYTHONPYCACHEPREFIX=/tmp/pyc-fresh -e PYTHONDONTWRITEBYTECODE=1 -e VLLM_TUNED_CONFIG_FOLDER=/work/moe/tune/merged -v hf-cache:/root/.cache/huggingface -v vllm-cache:/root/.cache/vllm -v <WORK_DIR_WIN>:/work -v <GENCONFIG_WIN>:/genconfig:ro -v <PATCH_DIR_WIN>\C\auto_gptq.py:/opt/python/lib/python3.14/site-packages/vllm/model_executor/layers/quantization/auto_gptq.py:ro -v <PATCH_DIR_WIN>\C\gptq_utils.py:/opt/python/lib/python3.14/site-packages/vllm/model_executor/layers/quantization/utils/gptq_utils.py:ro rocm/vllm:rocm10.1.0_ubuntu24.04_py3.14-pytorch_2.13.0_vllm-0.29.0 vllm serve /root/.cache/huggingface/local/Qwen3.8-27B-AWQ --served-model-name qwen3.8-27b --host 0.0.0.0 --port 8000 --max-model-len 16384 --gpu-memory-utilization 0.85 --max-num-seqs 16 --generation-config /genconfig --limit-mm-per-prompt.image 0 --limit-mm-per-prompt.video 0 --speculative-config.method mtp --speculative-config.num_speculative_tokens 2
dry-run: bench c=1 r=1: wslc exec r9700tune-sp-base-1 vllm bench serve --backend vllm --base-url http://127.0.0.1:8000 --model qwen3.8-27b --tokenizer /root/.cache/huggingface/local/Qwen3.8-27B-AWQ --dataset-name random --random-input-len 1024 --random-output-len 512 --ignore-eos --num-prompts 6 --max-concurrency 1 --seed 1
dry-run: prefill 8192 r=1: wslc exec r9700tune-sp-base-1 vllm bench serve --backend vllm --base-url http://127.0.0.1:8000 --model qwen3.8-27b --tokenizer /root/.cache/huggingface/local/Qwen3.8-27B-AWQ --dataset-name random --random-input-len 8192 --random-output-len 128 --ignore-eos --num-prompts 3 --max-concurrency 1 --seed 1
dry-run: quality collect: wslc exec r9700tune-sp-base-1 python3 /work/r9700/harness.py collect --url http://127.0.0.1:8000 --model qwen3.8-27b --out /work/r9700/acceptance27/prompts_base.json
dry-run: quality gsm8k: wslc exec r9700tune-sp-base-1 python3 /work/r9700/harness.py gsm8k --url http://127.0.0.1:8000 --model qwen3.8-27b --data /work/gsm8k/test.jsonl --n 200 --out /work/r9700/acceptance27/gsm8k_base.json
rc=0
```

The same dry run for the 35B model (`--out postdeploy-35b`, both arms) also ended `rc=0`. Neither wrote a fingerprint or a folder.

## Questions the run answers

- Does `wslc image inspect` exist on this machine? (`wslc image inspect <tag>`; the fingerprint holds the image TAG only, decision 1: a later story
  can add the digest when the verb exists.) Answer: yes — `wslc image inspect <tag>` prints the image JSON (rc 0), so the digest is available for a later story.
- Does the throwaway container answer (`find -printf`, `xargs -r`, `sha256sum`, `sh -c` without an entrypoint)? Answer: yes — both dry runs ended with exit 0, printed every dry-run line and wrote no `fingerprint.json`.
- Did every guard stay quiet? Answer: yes in the passing run — its supervisor log has no guard line (quiet → disk baseline → admitted → worker rc 0 → restored).

## What this record does not settle

One round, one model, one night. It does not show that the verdict is stable across rounds (the recorded ship test used 3 rounds, 9 values), and it
does not measure the 27B model.
