# Acceptance of `bin/r9700 run` on the R9700 — prepared 2026-11-03, NOT RUN YET

The flow that CI cannot run (`research/module_tests.md`): a chain of real steps over a real server, a real RAM guard and a real restore. The operator's session
runs it before a release and pastes the output below. Until then every section named "observed" is empty on purpose. The operator holds GPU runs for
now: this file is a template, as the acceptance of `series` and of `moe-tune` were. It forces the RAM limit instead of waiting for a real dip (results § 6.5: a real dip comes only during a model load).

## Subject and conditions (fill in at the run)

| | |
|---|---|
| Subject (commit of this repository) | `<sha>` |
| Harness | `bin/r9700` (verbs `init`, `run`) |
| Date of the run, machine | `<date>`, the R9700 PC |
| The plan | `acceptance.plan`, the operator's own file kept OUTSIDE the repository: `prefixtest qwen3.6-35b-a3b-gptq --name run-a --out acceptance-kernels`, then `linear-bench qwen3.6-35b-a3b-gptq --name run-a --out acceptance-kernels` |
| Model file | `models/qwen3.6-35b-a3b-gptq.env`, unedited |
| Pinned, not varied | the image tag, the model file, the two verbs' default options |
| Varied | run 1: `RAM_MIN_MB=65536` (the field's maximum: more than the PC has free, so the guard fires at its first read after admission) and `MAX_FAILED_TRIES=1` in `machine.env`; run 2: both fields back to their defaults |
| Machine file | the operator's `machine.env` (not copied here: it holds the machine's paths) |
| Compared with | `research/ACCEPTANCE_prefixtest_2026-11-03.md` and `research/ACCEPTANCE_linear_bench_2026-11-03.md` (the same two steps, one by one) and `POST_DEPLOY.md` item 4 (the operator's server answers after a run) |

## Commands

```bash
bin/r9700 init
bin/r9700 run acceptance.plan --check          # exit 0, no lock, nothing started
# run 1: machine.env with RAM_MIN_MB=65536 and MAX_FAILED_TRIES=1
bin/r9700 run acceptance.plan
# run 2: both fields back to their defaults
bin/r9700 run acceptance.plan
```

## Prediction, written BEFORE the run (measurement rule 4)

**Run 1, the forced stop.** From the supervisor's rules (`research/architecture.md`, *The step* and *The run driver*):

- `--check` prints `run: step 1: ok (prefixtest …)`, `run: step 2: ok (linear-bench …)` and `run: at most 2 stops of the operator's server if every step is admitted after a busy wait; MAX_SERVER_STOPS=3`, exit 0.
- the run waits for a quiet PC first. With the default of three quiet checks 300 s apart this is about 10 minutes before `admitted` (the quiet wait runs before every step); the operator's server is stopped once, at the admission of step 1.
- the RAM guard fires at its first read after admission, within about one guard tick (15 s): exit 7. On stderr: `r9700: step failed 1 times, last: ram_guard available <mb> MB < 65536 MB`, then `r9700: run: stopped at step 1 of 2 (prefixtest …): 7`.
- `run.txt` of the run folder: `1 stopped 7 …` and `2 not-started - …`; `plan.txt` holds the plan byte for byte.
- `wslc list` shows no `r9700tune-*` container, and no process of the worker's session is left.
- exactly one `restored` line in the supervisor log; the operator's server answers a one-token request (`POST_DEPLOY.md` item 4).
- `<RESULTS_DIR>/acceptance-kernels/` holds no final prefix record; `rejected/` holds nothing (the guard stopped before a record was started) or one `INTERRUPTED` part at the next start of a kernels unit.

**Run 2, the clean chain.**

- exit 0; `run.txt` has two `done 0` lines; two records (`prefix/run-a/` and `linear/run-a/`).
- the operator's server is stopped ONCE (at step 1) and restored ONCE (at the end): the second step's admission finds it down and charges no stop. The supervisor log has two `admitted` lines and one `restored` line.
- the wall time is about 35 to 40 minutes: two quiet waits of about 10 minutes (three checks 300 s apart), the prefix step about 6 to 8 minutes (3 to 5 minutes to load the model, the requests, the stop), the linear step about 6 minutes, and the restore. (The plan of E3 said 12 to 15 minutes; it left out the quiet waits.)

What would make it wrong, and what it would mean:

- a real RAM dip during the model load of run 2 (results § 6.5: down to a few hundred MB for about 1.5 minutes): the guard fires for a true reason, a retry follows after the quiet wait, and the record says so. That is a result about the PC, not a failure of `run`.
- a stop during the restore: a signal in the restore is held until the current call ends; the record says what was sent.
- a quiet PC that never gets quiet: exit 8 (`not quiet before the deadline`) with the server restored; that is the correct end of the chain, not a defect.
- run 1 ends with exit 6 or 8 instead of 7: the guard did not fire (the machine reported at least 65536 MB available, or the deadline came first); read the supervisor log.

## Observed: `--check` and `init`

```
(paste the output of bin/r9700 init and of bin/r9700 run acceptance.plan --check)
```

## Observed: run 1, the forced stop

```
(paste the output of the first run, its exit code, and `cat <run folder>/run.txt`)
```

```
(paste: the supervisor log of the run folder, the RAM guard log of step 1, `wslc list` after the run)
```

Observed against predicted: `(table: minutes to admitted, minutes from admitted to the stop, the exit code, the two stderr lines, run.txt, the containers left, the restored lines, the one-token request, one row each)`.

## Observed: run 2, the clean chain

```
(paste the output of the second run, its exit code, and `cat <run folder>/run.txt`)
```

```
(paste: the supervisor log of the run folder; the `admitted` lines and the `restored` line; `ls -l` of the two records)
```

Observed against predicted: `(table: exit code, the two done lines, the number of stops and restores of the operator's server, the wall time, one row each)`.

## Questions the run answers

- Is the operator's server stopped only once across two steps? Answer: `(the admitted lines and the stop calls of the supervisor log)`.
- Does the second step's admission list no server? Answer: `(the log line of that admission)`.
- Does a forced RAM stop leave a clean state: no container, no session, one restore, no marker? Answer: `(wslc list, the state folder, POST_DEPLOY.md items 5 to 7)`.
- Does the step that follows a quiet wait start after exactly the three quiet checks of the log? Answer: `(the quiet-checks lines)`.

## What this record does not settle

Two steps, one model, one image, two runs. It forces the RAM limit, so it says the guard stops the chain cleanly; it does not say what a real dip does to a night, and it does not exercise the deadline, `MAX_SERVER_STOPS` or a
busy-wait restore between steps (the stub tests R4, R18 and R19 of `tests/test_run.sh` do). It does not run `series`, `moe-tune` or a plan of more than two steps.
