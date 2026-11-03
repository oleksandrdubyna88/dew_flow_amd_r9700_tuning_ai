# PLAN — the GPU acceptance runs of the R9700 toolkit (they were NOT RUN until 2026-11-03)

> Status: **IMPLEMENTED, 2026-11-03.** The four runs were made on the R9700 PC on 2026-11-03 (about 19:25 to 20:36 CET) at `d983327`, and the four records are filled in; what shipped differently from this plan, and what is NOT done, are in *Deviations* below.
> Scope: the runs on the real R9700 PC that CI cannot make, for the parts of the toolkit that are merged
> ([PLAN_r9700_tuning_toolkit.md](PLAN_r9700_tuning_toolkit.md), epics E2 and E3; its stories documents are in `research/` too), and the `POST_DEPLOY.md` items they observe.
> The plan itself changed no code: each run fills a record that already existed as a template in `research/`. One toolkit change followed from a finding of the runs (deviation 3).
> Open items (the parts of the Definition of Done below that are not met) moved to [../todo/PLAN_r9700_acceptance_followups.md](../todo/PLAN_r9700_acceptance_followups.md).

## Deviations — what shipped differently, and what is NOT done (2026-11-03)

The records are the evidence; this section is what a reader of the plan needs. Each point names what was CHECKED.

1. **The quiet gate was off, by the operator's decision ("don't wait").** The plan said to confirm that the PC is quiet; the records predicted quiet waits of about 10 minutes before every admission. Every command of the day ran with `R9700_QUIET_CHECKS=1` and `QUIET_LOAD_MAX=16` in `machine.env`: one read, a load limit of 16. It was not fully off: at the chunk's second read the load was 18.07 and the supervisor waited one 300 s step. The loads read at the quiet checks were 0.45 to 2.85 except the chunk's 8.31 and 18.07. Consequence: the wall time of the run record is 14 min 54 s against the predicted 35 to 40, and the kernel timings were not taken behind three quiet reads. Checked: the supervisor logs of every run folder (`quiet-checks=<k>/<n>` lines).
2. **`activate` was run with `--force`.** The plan allowed it "only after confirming the server does not mount the exchange folder, and say which in the record". The operator's session confirmed with `wslc inspect vllm` that production mounts its MoE config from the start script's own patch folder at `/vllm-tuned-moe` (`VLLM_TUNED_CONFIG_FOLDER=/vllm-tuned-moe`) and not the exchange folder, so the forced activation could not change what production reads. The record says it (`FORCED=yes` in `activate.env`). The consequence is that item 12 of `POST_DEPLOY.md` cannot hold on this PC as the file stands: the toolkit's own A/B container read the activated file (3 of 3 tuned logs), the operator's server does not.
3. **A finding that the plan did not foresee: the stop of the operator's server returned code 1 in 2 of the 6 admissions that had to stop it (the `linear-bench` run and the `moe-tune` chunk), and the server WAS stopped each time.** Each cost a failed try (and, for the chunk, a 5 minute quiet wait). The cause is NOT known: `wslc_stop` discarded wslc's output. Checked: the supervisor logs of the six admissions; not checked: the text wslc printed, which is lost. The toolkit was changed after the runs (the commit that follows the records on the branch `docs/gpu-acceptance-2026-11-03`): `wslc_stop` keeps wslc's text (the last 20 lines), the step logs it on a failure, and after a non-zero stop the step lists again and counts a server that is gone as stopped. It is proven against the stub (`stop-gone-<name>`); the PC was not run again, so the change is not observed on the real `wslc`.
4. **Open, and not extracted into a plan (the promotion was asked to leave `todo/` with no open plan).**
   - *The foreground container.* The question "does a foreground `wslc run --rm --name <name>` appear in `wslc list` while it runs, and does `wslc stop <name>` end it" stays UNVERIFIED. Checked: no `wslc list` was taken during a unit in any of the four runs. What was seen: the guard of run 1 saved the log tail of the DETACHED prefix server `r9700tune-prefix-base-1` and stopped it by name (`guard/<stamp>-r9700tune-prefix-base-1.tail.log`); no foreground container was listed by anything. The `moe-tune` and `linear-bench` records say the same.
   - *Item 12 with the operator's own server* (above, point 2): not observed; to observe it the merged file must reach the folder the server mounts, which this run did not do.
   - *`POST_DEPLOY.md`* was NOT run in full after the install: items 1, 3 and 11 (and 12 in part) were observed at the stamp of 2026-11-03; items 2 and 4 to 10 keep their observation of 2026-11-02 (4: no one-token request was sent to the operator's own server today). Item 3 ran over the acceptance plan, not the operator's night plan. `series` was not re-run at `d983327` (its record is at `901b48e`, and `lib/` changed since).
   - *The merge to `main`.* The records, the stamp and the toolkit change are commits of the branch `docs/gpu-acceptance-2026-11-03`; the pull request is not made by the session that wrote this.
5. **The predictions that did not hold are results, as the plan said they would be, and the predictions are unchanged.** `linear-bench`: the cells of M 6 to 16 in the default columns are 6 to 10 % below the recorded ones and the change column is 3 to 4 points away at M 6, 12 and 16; the same unit run twice on the day differs by about as much. `prefixtest`: 8k partial 0.50 s (0.01 s above) and three of six 1k values above the band in the first run (the repeat is inside it). `moe-tune`: the cache before the A/B was empty, not near 1 GB (the exit-path clear of the chunk had emptied it; the chunk's cache was 78 MB). `run`: the wall time (point 1). Smaller misses (the `linear-bench` container time of 7 min 55 s against about 6, the cache-clear line that names only the folders that exist) are in the tables; every row of a table says `yes`, `no`, `partly` or `indirect`.
6. **The order followed the plan** (`linear-bench`, `moe-tune`, `prefixtest`, `run`), one model load at a time: three model starts in all (`prefixtest`, run 1 stopped by the guard 2 s after its start, run 2). No RAM guard stop for a true reason occurred; the guard logs only the first read and every 20th, so a dip shorter than the 15 s between reads is not excluded.

## Goal

The toolkit is merged and public, and every flow is proven against stubs. Four acceptance records are still templates marked NOT RUN, each with a prediction written before the run
(`common.measurement`, rule 4). The operator holds GPU runs for now. This plan says what to run, in which order, under which cautions, and what counts as done, so that the operator's session
can run them in one go when GPU runs are released.

**Already done, not in this plan.** The acceptance of E1 (`series`, `base` against `ta3`, one round on the 35B model; the 27B file as a dry run) was run on 2026-11-02 and is recorded in
[ACCEPTANCE_series_2026-11-02.md](ACCEPTANCE_series_2026-11-02.md). `POST_DEPLOY.md` items 1, 2 and 4 to 10 were observed at that stamp.

## What is still open

| # | Record (a template today) | Command | Prediction in the record (the pass rule) | About |
|---|---|---|---|---|
| A1 | [ACCEPTANCE_moe_tune_2026-11-02.md](ACCEPTANCE_moe_tune_2026-11-02.md) (E2) | `moe-tune chunk --coarse --keys 24`, `merge`, `activate`, `ab` over keys 8 12 16 24 | a 10-key merged file; key 24 equals the chunk's; the tuned arm loaded the activated file (`Using configuration from …` in every tuned log); the key-24 change within ± 1 %, `KERNEL: not faster`; regression keys within ± 1 %; two stops and restores, no `rejected/` | about 15 to 25 minutes in the containers, plus quiet waits |
| A2 | [ACCEPTANCE_linear_bench_2026-11-03.md](ACCEPTANCE_linear_bench_2026-11-03.md) (E3.S1) | `linear-bench` on the 35B file, name `acceptance` | 50 rows; the table of results § 12.1 within ± 5 % per cell and ± 2 points on the change; `split_ms` above `default_ms` at every M of 6 and more; tuned tiles near the recorded ones; `tuned_maxdiff` 0.0, `split_maxdiff` at most 0.0078; one stop and one restore | about 6 minutes in the container |
| A3 | [ACCEPTANCE_prefixtest_2026-11-03.md](ACCEPTANCE_prefixtest_2026-11-03.md) (E3.S1) | `prefixtest` on the 35B file, arm `base` | ready in 3 to 5 minutes; 8k cold 2.0 to 2.2 s, hit 0.46 to 0.51 s; 1k all 0.18 to 0.22 s; ratios 4.0x to 4.5x and 0.8x to 1.1x; one stop and one restore | a model load (this one drives the RAM dip) |
| A4 | [ACCEPTANCE_run_2026-11-03.md](ACCEPTANCE_run_2026-11-03.md) (E3.S2) | `run` over a two-step plan; run 1 with `RAM_MIN_MB=65536` and `MAX_FAILED_TRIES=1`, run 2 with the defaults | run 1: exit 7 within about 15 s of `admitted`, `run.txt` `1 stopped 7` and `2 not-started`, no prefixed container, one `restored`; run 2: exit 0, two `done`, ONE stop and ONE restore, 35 to 40 minutes in all | the longest: two quiet waits of about 10 minutes each |

`POST_DEPLOY.md` items that these runs observe (run the whole file on the PC after the install of the merged version, then set the stamp):

| Item | What | Observed by |
|---|---|---|
| 3 | `run --check` over the operator's own night plan | the plan of A4 first (it is valid), then the operator's real plan |
| 11 | the five acceptance records were done for this commit and their observed sections are filled | A1 to A4 (the series record is done) |
| 12 | the operator's own server reads the activated MoE file | after A1's `activate`, the operator restarts their own server and its start log holds `Using configuration from <the activated file> for MoE layer` (the one step no template does: it needs the operator's start script mounting the exchange folder) |

## Build order — the order to run them on the GPU

Run them in this order and not in parallel: **one model load at a time**, and one supervised run at a time (the lock refuses a second one anyway).

1. **Before the first run: read the cautions below, and confirm the PC is quiet and nobody will use it.** `bin/r9700 init` must exit 0; `POST_DEPLOY.md` items 4 to 7 must hold (the operator's server answers, no test container is left, no lock, no marker).
2. **A2 `linear-bench`** first: the shortest, loads no weights (random weights in one container), so it cannot cause the RAM dip of a model load. It also answers the question the other runs share: does a foreground `wslc run --rm --name` appear in `wslc list`.
3. **A1 `moe-tune`**: also no model load (the benchmark builds kernels). Chunk, merge, activate, ab. `activate` is refused while a server is listed: stop your own server by hand for it, or use `--force` only after confirming the server does not mount the exchange folder, and say which in the record.
4. **A3 `prefixtest`**: the first model load of the series of runs. Watch the RAM guard.
5. **A4 `run`**: run 1 (the forced stop) first, then run 2 (the clean chain, which loads the model once for its prefix step).
6. **Item 12 and the stamp**: restart your own server on the activated file, then run `POST_DEPLOY.md` against the install and write the new stamp (date, target, version, which items were observed).

**Cautions, from `dew_flow_benchmark · research/RESULTS_vllm_029_r9700_speed_options.md`** (cited by path; read § 6.5 and § 14.4 before the first run):

- **Free RAM falls to near 0 at every model load** (§ 6.5: the Modified page list reaches 30 to 42 GB, available RAM a few hundred MB for about 1.5 minutes; the production restore once went to 6 MB). The default `RAM_MIN_MB=2048` can fire during a load for a TRUE reason (§ 14.4: 43 MB, 195 MB, 956 MB stops); that is why A3 and A4 run 2 may show a guard stop and a retry. Do not lower the limit to avoid it without writing it in the record.
- **Do not chain loads back to back.** The retry rule waits for the stopped container and for a quiet PC; a retry 23 s after a RAM stop, before the RAM was back, stopped again (§ 14.4, night8). Let the supervisor's waits run; do not shorten them.
- **The crash of 2026-11-02 (01:45:56):** a Windows bug check (0x7E, the AMD display driver named as possibly related) came at the end of 29 model starts in one night, with free RAM near 0 at several (§ 14.4). One crash does not prove a cause, and the dump was not analysed. So keep the number of model starts of the whole plan small: A3 starts one, A4 run 2 starts one (run 1 starts at most one that the guard stops within seconds); do not repeat a run "to be sure" the same night.
- **Never skip the restore** (§ 14.4: production was down from 17:28 to 18:07 after a restore skipped as "a planned restart"). The toolkit restores once at every exit path; if a run ends with exit 5 or 11, look at the operator's server by hand before anything else.
- **Never run a test with a fork bomb outside the process cap.** The suite's runner caps processes (the shim incident of 2026-11-02, about 15,900 processes); the runs on the GPU are not tests and do not need that, but do not run the test suite on the PC during a run (a busy PC is not quiet, and the quiet phase will wait).
- The stop of the operator's server is the point of the run: tell nobody to use it during the window, and have the operator present for A3 and A4.

## Test plan

Each template's prediction is the pass rule. For every run:

1. Fill the **Subject and conditions** table (the commit, the date, the model file unedited, the out and name).
2. Run the commands exactly as the template lists them; paste the output into the `(paste …)` blocks; fill every `Observed against predicted` and `Answer` line with a table or a sentence, no placeholder left.
3. Compare each observed value with the prediction. A value outside the prediction is a RESULT, recorded as such with its reading ("a different key-24 tile means the coarse grid is not deterministic"), not a failure of the toolkit and not a reason to edit the prediction (a prediction formed after the numbers is not a prediction).
4. A real failure of the toolkit (a stop that left a container, a restore that did not run, a record made without validation) is a bug: stop the series of runs, restore the operator's server by hand, and open a bug before the next run.
5. Change the title of the record from `NOT RUN YET` to `RUN <date>`. `tests/test_docs.sh` then holds the record to the stricter rule: no `(paste` prompt, no `<sha>` or `<date>`, no empty `Answer` or `Observed against predicted` line.

## Growth surfaces

| Surface | Size | Who retires it | Interrupted |
|---|---|---|---|
| The result folders of the runs under `<RESULTS_DIR>` (`acceptance-moe`, `acceptance-kernels`, the run folders) | under 5 MB in all (a chunk ≈ 35 KB, a prefix record ≈ 0.3 MB, a run folder ≈ 1 MB) | kept: they are the evidence; the toolkit never deletes them | an interrupted run leaves a part that the next start moves to `rejected/` |
| The Triton caches in the cache volume | 0.5 to 1.3 GB per chunk; `triton-linear` not measured (A2 measures it: the `du` line of the cache clear) | cleared before every unit and in the exit path by the toolkit | a hard-killed supervisor: the next unit's start clears it |
| The five records in `research/` | a few KB each | kept (they are documentation once filled) | — |

## Definition of Done

As it stood at the end of 2026-11-03. The boxes that are not ticked say why.

- [x] A1 to A4 each ran on the R9700 PC at a commit of this repository that is named in its record (`d983327`); each record is filled (no `NOT RUN`, no placeholder), carries the observed output and the observed-against-predicted table.
- [ ] Each record answers its questions, "including the open one of the foreground container in `wslc list`": NOT MET for that one question (deviation 4). The other questions are answered, or say they cannot be (the record says which).
- [x] Every observed value outside its prediction is written down as a result with its reading, and the prediction is unchanged (the tables of the four records; deviation 5).
- [x] The merged config of A1 and `activate.env` are named in the record (the stamp `20261103T185726Z`, `FORCED=yes`).
- [ ] Item 12 of `POST_DEPLOY.md` was observed with the operator's own server: NOT MET (deviation 2); it was observed in the A/B's tuned logs only.
- [ ] `POST_DEPLOY.md` was run on the PC after the install: PARTLY (deviation 4): its stamp names the date, the target and the version, and says which items were observed; items 3 and 11 are no longer "NOT RUN", item 12 is observed in part.
- [ ] The records are merged to `main` through a pull request: NOT YET (the branch is local, deviation 4). `plan-lifecycle` is clean, and this plan is promoted to `research/` with its deviations; its open items are listed in deviation 4 and are NOT extracted into a fresh plan.
