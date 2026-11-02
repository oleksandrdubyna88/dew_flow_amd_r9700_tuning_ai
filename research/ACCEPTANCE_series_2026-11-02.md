# Acceptance of `bin/r9700 series` on the R9700 — prepared 2026-11-02, NOT RUN YET

The one flow that CI cannot run (`research/module_tests.md`): it needs the GPU, the real `wslc`, the real image and the model. The operator's
session runs it before a release and pastes the output below. Until then every section named "observed" is empty on purpose.

## Subject and conditions (fill in at the run)

| | |
|---|---|
| Subject (commit of this repository) | `<sha>` |
| Harness | `bin/r9700` (verbs `init`, `series`, `verdict`) |
| Date of the run, machine | `<date>`, the R9700 PC |
| Model file | `models/qwen3.6-35b-a3b-gptq.env`, unedited |
| Arms | `base` and `ta3` of `config/arms.conf`, unedited |
| Rounds | 1 (`--rounds 1`) |
| Command | `bin/r9700 series qwen3.6-35b-a3b-gptq base ta3 --rounds 1 --out acceptance` |
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
(paste the output of bin/r9700 init)
```

## Observed: the series

```
(paste the output of the series command, and `ls -R <RESULTS_DIR>/acceptance | head -60`)
```

Read back, one cell per arm (measurement rule 1): `rounds/base-1/server_config.txt` and `rounds/ta3-1/server_config.txt`, to prove the arms differed.

## Observed: the verdict

```
(paste the output of bin/r9700 verdict <RESULTS_DIR>/acceptance)
```

Observed against predicted: `(table: c=1 delta, c=4 delta, verdict, quality; one row each)`.

## The 27B model file as a dry run

The second example model runs `series` unedited as a DRY RUN here: the dry run loads the config, computes the fingerprint without writing it (the throwaway container
runs, so the model listing is real) and prints every resolved command of the first arm-round without starting a server. A second real run costs about
25 minutes of the GPU for no new mechanism. (If the session ran it for real instead, say so here.)

```
(paste the output of: bin/r9700 series qwen3.8-27b-awq base --out acceptance27 --rounds 1 --dry-run)
```

## Questions the run answers

- Does `wslc image inspect` exist on this machine? (`wslc image inspect <tag>`; the fingerprint holds the image TAG only, decision 1: a later story
  can add the digest when the verb exists.) Answer: `(yes/no, the output)`.
- Does the throwaway container answer (`find -printf`, `xargs -r`, `sha256sum`, `sh -c` without an entrypoint)? Answer: `(the dry run ended with exit 0 and printed its dry-run lines; it writes no fingerprint.json)`.
- Did every guard stay quiet? Answer: `(the supervisor log of the run folder)`.

## What this record does not settle

One round, one model, one night. It does not show that the verdict is stable across rounds (the recorded ship test used 3 rounds, 9 values), and it
does not measure the 27B model.
