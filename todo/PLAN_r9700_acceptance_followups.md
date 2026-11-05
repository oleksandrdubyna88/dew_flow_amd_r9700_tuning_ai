# PLAN — the items the GPU acceptance of 2026-11-03 left open

> Status: **plan only, nothing implemented yet, 2026-11-03.** Scope: the parts of the Definition of Done of
> [../research/PLAN_r9700_gpu_acceptance.md](../research/PLAN_r9700_gpu_acceptance.md) that the runs of 2026-11-03 did not meet
> (its deviations list them); the toolkit code is merged, and nothing here is needed to use it.

## Why this exists

`common.planning-docs` § *Partially implemented plans*: the shipped part of a plan moves to `research/`, and its unfinished phases go into
a fresh `todo/` plan. The GPU acceptance plan shipped its four records (`research/ACCEPTANCE_*_2026-11-0[23].md`) and one fix (the stop
of the operator's server that returns non-zero but leaves no server); these four items did not ship.

## The items

1. **DONE 2026-11-04 — POST_DEPLOY item 12: the folders stay apart (option b).** The operator's server mounts its MoE config from the
   start script's own patch folder at `/vllm-tuned-moe` (`wslc inspect vllm`, 2026-11-03), not `<WORK_DIR>/r9700/moe/<model>/merged`. Decided
   by the question consultants (coai consult d4a08b51, two answers agreeing), verified on the code: `moe-tune ab` needs `activate.env`
   (lib/moe.sh `_moe_b_file`), so activation comes BEFORE the A/B verdict, and pointing production at the exchange folder (a) would let an
   untested candidate reach production at its next restart. So the toolkit never writes into the production folder; after an A/B that says
   faster, the operator copies the activated file by hand (README already says so), and item 12 now checks that copy. Option (c), a verb
   that copies with a backup and a hash check, is not built: today's A/B found no gain, and it is worth it only if tuned files ship often.
   No production change was made. The operator may still choose (a) or (c).
2. **DONE 2026-11-04 — yes, it is listed.** Observed during a real chunk (09:16–09:24 UTC, `research/module_tests.md` § *What it does not prove*); the watcher's raw log was lost when a Windows bug check at 10:32 cleared `/tmp`, the lines read before it are quoted there. Original question: **Is a foreground `wslc run --rm --name <n>` listed by `wslc list` while it runs?** UNVERIFIED (the chunk, A/B and linear units use it;
   the stubs assume yes). Observe it once during the next real foreground unit (`wslc list` from a second shell while a chunk runs), and
   record the answer in `research/module_tests.md`.
3. **Re-run `POST_DEPLOY.md` items 2 and 4–10 against the installed version** (the stamp of 2026-11-03 observed items 1, 3, 11 and 12
   only at d983327). Write the new stamp with date, target and version.
4. [ ] **Load flakes of the test suite** (2026-11-04: reproduced under bounded CPU burners; KW5, R18 and the ceiling part of R3/R17 fixed RED-GREEN-RED; one other window left).
   - [x] `test_kernels.sh` KW5 (failed once in a full run on 2026-11-03): the test's deadline window (`short_variant`, T_STOP 9.4 s after the start at scale 25) was already
     past when the unit's container started on a starved CPU (`the part stays` 0 != 1; the step ended 8 or 5). KW5 now runs at scale 5 (T_STOP 35 s).
   - [x] `test_run.sh` R18 (exit 137 instead of 8): `step_end` killed the supervisor after its fixed 60 s while the four-step chain with three busy waits needed more on a starved CPU;
     `run_end` now takes a bound and R18 gives it 300 s (the busy-wait watcher lives as long).
   - [x] `test_run.sh` R3 and R17 `restore-5`, the ceiling part (seen once in CI): an adapter call's ceiling (`wslc list` 60 s / 10 = 6 s) ran out in a stub call that only waited
     for the CPU: `failed try 1 of 3: admit the container list failed ()`, a repeated admission, a chain ending 7. `run_setup` now divides the ceilings by 2 (30 s). Proven without load by R3b:
     the stub's one-shot `list-delay-once` makes one `wslc list` take 8 s; with the old scale the test fails with that very line, with the new one it passes (RED, GREEN, RED, 2026-11-04).
   - [ ] `test_run.sh` R3 and R17 `restore-5`, the other window: under heavy load (4 busy loops on 2 cores) the chains still ended 5 with the new ceilings, so a window other than the
     `wslc list` ceiling runs out too. Not found; no load has shown 0 failures.
   - [ ] More assertions fail at a high load, the two wall-clock ones on main too, so this branch did not cause those (2026-11-04, all at the machine's own load from other work, no burners). `test_adapter.sh` "the nine calls
     took under 8 s" and `test_guards.sh` "the supervisor waited for the guard's call" (< 2 s, actual 2.30 and 2.51 s) assert a wall clock: run alternately, main and this branch each failed 1 of 3 (main at load 30, the branch
     at load 16; the other runs passed at loads from 5 to 37), and in the re-run of the failed files both failed on the branch at load 15. `test_adapter.sh` "nine hung stubs were recorded" (8) and `test_restore.sh` "two transient failures of the list" (`vllm not ready after 67 s`, exit 5) and a deadline
     test of `test_series.sh` ("fbase-1 is recorded") failed once, in one full run at load 24 to 35, and passed when the files ran again at load 15. Not fixed.
5. [ ] **`moe-tune` tunes the main layer with FP16 activations, but production serves BF16** (added 2026-11-05, the operator agreed to a todo, not a run). `lib/moe.sh` `moe_layer_words` sets `MOE_TUNE_ACT_DTYPE=bfloat16` only for
   the `draft` layer, and `experts` takes the default of `benchmark_moe.py`, FP16 on ROCm. So the tuned int4 file and the "not faster" verdict of 2026-11-02 are FP16 results. Measured with BF16 (`dew_flow_benchmark · research/RESULTS_vllm_029_r9700_speed_options.md`
   § 15.3): the file is 16.4 % slower than the default at M=640, and a `"512"` entry gives −13.5 % to −28.3 % at M 512–768 as a kernel. End to end (§ 15.5) that entry shows no measured gain, so this is not urgent. Another R9700 owner's BF16 tuning reached the
   same tiles at most batch sizes, which suggests little more to find. To do when a model is tuned next: let `experts` tune and A/B with the activation dtype the model serves, with a test of the argv, and say which dtype in the README. No re-tune is planned before that.

## Build order

Item 1 first (a question to the operator; it decides whether item 12 changes). Items 2 and 3 at the next GPU window, in one sitting. Item 4
is CPU-only and can run any time. Item 5 is a small code change with its own tests, then a GPU run only if a re-tune is wanted.

## Test plan

Item 4 has a test (the flake reproduced, then fixed). Items 2 and 3 are observations recorded in `research/`. Item 1 is a decision; a code
change it causes gets its own tests.

## Definition of Done

- [x] The decision on item 1 is recorded (option b, 2026-11-04), and item 12 of `POST_DEPLOY.md` matches it.
- [x] Item 2's answer is in `research/module_tests.md` (listed, 2026-11-04).
- [x] A new `POST_DEPLOY.md` stamp covers items 2 and 4–10 (2026-11-04: items 4–10 at 2f8cd71, item 2 at 4b81cc9 after the hold of the 10:32 bug check was lifted).
- [x] KW5 passes under load, with the cause named in the commit (b16baf8); R18 likewise (0e02531).
- [ ] R3 and R17 `restore-5`: the other window that still ended 5 under heavy load is found and fixed (item 4). Until then this plan stays in `todo/`.
- [ ] The assertions of `test_adapter.sh`, `test_guards.sh`, `test_restore.sh` and `test_series.sh` that fail at a high load (item 4) pass there, or a wall-clock assertion is replaced by one that does not depend on the load.
- [ ] `moe-tune` uses the activation dtype the model serves for the `experts` layer, with a test, and the README says so (item 5).
