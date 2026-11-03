# PLAN — the GPU acceptance runs of the R9700 toolkit that are still NOT RUN

> Status: **plan only, nothing implemented yet, 2026-11-03.** Scope: the runs on the real R9700 PC that CI cannot make, for the parts of the toolkit that are merged
> ([PLAN_r9700_tuning_toolkit.md](../research/PLAN_r9700_tuning_toolkit.md), epics E2 and E3; its stories documents are in `research/` too), and the `POST_DEPLOY.md` items they would observe.
> No code changes: each run fills a record that already exists as a template in `research/`.

## Goal

The toolkit is merged and public, and every flow is proven against stubs. Four acceptance records are still templates marked NOT RUN, each with a prediction written before the run
(`common.measurement`, rule 4). The operator holds GPU runs for now. This plan says what to run, in which order, under which cautions, and what counts as done, so that the operator's session
can run them in one go when GPU runs are released.

**Already done, not in this plan.** The acceptance of E1 (`series`, `base` against `ta3`, one round on the 35B model; the 27B file as a dry run) was run on 2026-11-02 and is recorded in
[ACCEPTANCE_series_2026-11-02.md](../research/ACCEPTANCE_series_2026-11-02.md). `POST_DEPLOY.md` items 1, 2 and 4 to 10 were observed at that stamp.

## What is still open

| # | Record (a template today) | Command | Prediction in the record (the pass rule) | About |
|---|---|---|---|---|
| A1 | [ACCEPTANCE_moe_tune_2026-11-02.md](../research/ACCEPTANCE_moe_tune_2026-11-02.md) (E2) | `moe-tune chunk --coarse --keys 24`, `merge`, `activate`, `ab` over keys 8 12 16 24 | a 10-key merged file; key 24 equals the chunk's; the tuned arm loaded the activated file (`Using configuration from …` in every tuned log); the key-24 change within ± 1 %, `KERNEL: not faster`; regression keys within ± 1 %; two stops and restores, no `rejected/` | about 15 to 25 minutes in the containers, plus quiet waits |
| A2 | [ACCEPTANCE_linear_bench_2026-11-03.md](../research/ACCEPTANCE_linear_bench_2026-11-03.md) (E3.S1) | `linear-bench` on the 35B file, name `acceptance` | 50 rows; the table of results § 12.1 within ± 5 % per cell and ± 2 points on the change; `split_ms` above `default_ms` at every M of 6 and more; tuned tiles near the recorded ones; `tuned_maxdiff` 0.0, `split_maxdiff` at most 0.0078; one stop and one restore | about 6 minutes in the container |
| A3 | [ACCEPTANCE_prefixtest_2026-11-03.md](../research/ACCEPTANCE_prefixtest_2026-11-03.md) (E3.S1) | `prefixtest` on the 35B file, arm `base` | ready in 3 to 5 minutes; 8k cold 2.0 to 2.2 s, hit 0.46 to 0.51 s; 1k all 0.18 to 0.22 s; ratios 4.0x to 4.5x and 0.8x to 1.1x; one stop and one restore | a model load (this one drives the RAM dip) |
| A4 | [ACCEPTANCE_run_2026-11-03.md](../research/ACCEPTANCE_run_2026-11-03.md) (E3.S2) | `run` over a two-step plan; run 1 with `RAM_MIN_MB=65536` and `MAX_FAILED_TRIES=1`, run 2 with the defaults | run 1: exit 7 within about 15 s of `admitted`, `run.txt` `1 stopped 7` and `2 not-started`, no prefixed container, one `restored`; run 2: exit 0, two `done`, ONE stop and ONE restore, 35 to 40 minutes in all | the longest: two quiet waits of about 10 minutes each |

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

- [ ] A1 to A4 each ran on the R9700 PC at a commit of this repository that is named in its record; each record is filled (no `NOT RUN`, no placeholder), carries the observed output and the observed-against-predicted table, and answers its questions, including the open one of the foreground container in `wslc list`.
- [ ] Every observed value outside its prediction is written down as a result with its reading, and the prediction is unchanged.
- [ ] The merged config of A1 (and `activate.env`) is named in the record, and item 12 of `POST_DEPLOY.md` was observed with the operator's own server.
- [ ] `POST_DEPLOY.md` was run on the PC after the install: its stamp names the date, the target, the version and the items observed; items 3, 11 and 12 are no longer "NOT RUN".
- [ ] The records are merged to `main` through a pull request; `plan-lifecycle` is clean; this plan is promoted to `research/` with its deviations (or its open items are extracted into a fresh plan).
