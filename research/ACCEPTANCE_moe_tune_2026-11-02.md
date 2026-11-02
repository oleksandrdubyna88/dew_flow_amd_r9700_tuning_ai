# Acceptance of `bin/r9700 moe-tune` on the R9700 — prepared 2026-11-02, NOT RUN YET

The flow that CI cannot run (`research/module_tests.md`): it needs the GPU, the real `wslc`, the real image, the model and the vendored benchmark. The
operator's session runs it before a release and pastes the output below. Until then every section named "observed" is empty on purpose. The operator holds
GPU runs for now: this file is a template, as the acceptance of `series` was.

## Subject and conditions (fill in at the run)

| | |
|---|---|
| Subject (commit of this repository) | `<sha>` |
| Harness | `bin/r9700` (verbs `init`, `moe-tune`) |
| Date of the run, machine | `<date>`, the R9700 PC |
| Model file | `models/qwen3.6-35b-a3b-gptq.env`, unedited |
| Out | `acceptance-moe` (`<RESULTS_DIR>/acceptance-moe`) |
| Pinned, not varied | the image tag, the vendored benchmark (`vendor/benchmark_moe.py`, hash in `chunk.env`), the coarse candidates, the model file's `TUNED_CONFIG_DIR` (the production file of 2026-10-27, 9 keys) |
| Machine file | the operator's `machine.env` (not copied here: it holds the machine's paths) |
| The server at `activate` | stopped by hand, or `--force` after the operator confirmed that the server does not mount the exchange folder (say which: `activate.env` has `FORCED=`) |

## Commands

```bash
bin/r9700 init
bin/r9700 moe-tune chunk qwen3.6-35b-a3b-gptq --keys "24" --coarse --out acceptance-moe
bin/r9700 moe-tune merge qwen3.6-35b-a3b-gptq --out acceptance-moe experts-coarse-24
bin/r9700 moe-tune activate qwen3.6-35b-a3b-gptq <the stamp the merge printed> --out acceptance-moe
bin/r9700 moe-tune ab qwen3.6-35b-a3b-gptq --keys "8 16 24 32" --rule median --rule-keys "24" --out acceptance-moe
```

**Key 24 is the measured case.** Keys 8, 16 and 32 are regression coverage: they are in the production file and in the merged file with the same tiles, so their
change should be noise. A change there beyond ± 3 % would say the activated file broke a key it did not touch, not that key 24 is good or bad.

## Prediction, written BEFORE the run (measurement rule 4)

From `RESULTS_vllm_029_r9700_speed_options.md` § 14.1 (the coarse grid picked the current tile at every key, and the A/B was within ± 0.6 %):

- the chunk takes about 5 to 6 minutes (the four-key coarse chunk of 2026-11-01 took 1,244 s); its key 24 is `BLOCK 16/16/64, GROUP 1, 1 warp, 2 stages,
  waves_per_eu 4`, the same config as key 24 of the merged fixture `tests/fixtures/moe/b2/`.
- the merge writes a 10-key file: the 9 production keys plus 24. Its keys 1 to 16 and 256 to 2048 equal the production file's, and its key 24 equals the chunk's.
- `activate` prints `previous kept as none` (a fresh exchange folder) and `merged/activate.env` names the stamp.
- **the tuned arm loaded the activated file.** Every `tuned-<rep>.log` of the A/B holds the line
  `Using configuration from /work/r9700/moe/qwen3.6-35b-a3b-gptq/merged/E=256,N=512,device_name=AMD_Radeon_R9700,dtype=int4_w4a16.json for MoE layer`
  (the worker refuses to record the A/B without it). `ab.env` holds it as `B_CONFIG_LINE`; paste it, and `A_CONFIG_LINE` with it (what the default arm prints
  for the production folder).
- the A/B's key-24 change is within ± 1 % and the decision is `KERNEL: not faster (median change at 24: <±0.x> %)`; the three regression keys are within ± 1 %.
- the operator's server is stopped twice (one per GPU invocation: the chunk and the A/B) and is back, ready, after each; `activate` stops nothing.
- the cache clear line shows a size near 1 GB before the A/B (the chunk filled it), and the exit-path clear ran after each GPU invocation: two
  `cleanup hook: moe_cache_clear rc=0` lines in the two supervisor logs, each before its `restored` line.
- no `rejected/` folder.

What would make it wrong, and what it would mean:

- a different key-24 tile: the coarse grid is not deterministic across runs. Then the A/B decides, and either decision is a record.
- a key-24 change outside ± 3 %: the kernel timing on this day was noisy, or the file differs; read `ab.env`.
- a regression key outside ± 3 %: the file broke something it did not touch; read `B_CONFIG_LINE` and the merged file.
- a `tuned-<rep>.log` without the `Using configuration from <activated file>` line: the A/B is rejected, and the real log line is the evidence (the text of vLLM may differ).

## Observed: `init`

```
(paste the output of bin/r9700 init)
```

## Observed: the chunk

```
(paste the output of the chunk command, and `ls -R <RESULTS_DIR>/acceptance-moe/chunks | head -30`; `chunk.env` and `chunk.summary`)
```

Read back: the key-24 config of the chunk's JSON: `(paste)`. The size line of the cache clear before the chunk and the supervisor log of the run folder: `(paste)`.

## Observed: the merge

```
(paste the output of the merge command and merged/<stamp>/merge.env; the keys of the merged file)
```

Observed against predicted: `(10 keys; keys 1-16 and 256-2048 equal the production file; key 24 equals the chunk)`.

## Observed: the activation

```
(paste the output of the activate command and merged/activate.env)
```

Say how the server was handled: `(stopped by hand | --force after the operator confirmed it does not mount the exchange folder)`.

## Observed: the kernel A/B

```
(paste the output of the ab command, ab/<stamp>/summary.txt, and the B_CONFIG_LINE and A_CONFIG_LINE of ab.env)
```

```
(paste: grep 'Using configuration from' <RESULTS_DIR>/acceptance-moe/ab/<stamp>/tuned-*.log)
```

Observed against predicted: `(table: key 24 change, keys 8 16 32 changes, decision, the two cache-clear lines, the two stops and restores; one row each)`.

## Questions the run answers

- Does a foreground `wslc run --rm --name <name>` appear in `wslc list` while it runs, and does `wslc stop <name>` end it? (E2.S2 decision 9 and the refusal of
  `activate` rest on it; UNVERIFIED.) Answer: `(yes/no: wslc list during the chunk)`.
- Does the clear container's `du` print what the code expects (one line per cache folder, in `cache before clear: …`)? Answer: `(the line)`.
- What does the default arm print for a folder that holds the file (`A_CONFIG_LINE`)? Answer: `(the line)`.
- Is hook 3 observed? No: a draft chunk is not in this run (`--layer draft`); it stays unobserved until a draft chunk runs on the machine.
- Did every guard stay quiet? Answer: `(the supervisor logs of the run folders)`.

## What this record does not settle

One key, one model, one night. It does not tune keys by a full search, does not run the draft layer (hook 3), and says nothing about the 27B model (its file
may need `MOE_DTYPE=none`; whether it has MoE layers is not known here). A decision of "not faster" is a result, not a failure.
