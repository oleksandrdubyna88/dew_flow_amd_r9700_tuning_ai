# PLAN — the items the GPU acceptance of 2026-11-03 left open

> Status: **plan only, nothing implemented yet, 2026-11-03.** Scope: the parts of the Definition of Done of
> [../research/PLAN_r9700_gpu_acceptance.md](../research/PLAN_r9700_gpu_acceptance.md) that the runs of 2026-11-03 did not meet
> (its deviations list them); the toolkit code is merged, and nothing here is needed to use it.

## Why this exists

`common.planning-docs` § *Partially implemented plans*: the shipped part of a plan moves to `research/`, and its unfinished phases go into
a fresh `todo/` plan. The GPU acceptance plan shipped its four records (`research/ACCEPTANCE_*_2026-11-0[23].md`) and one fix (the stop
of the operator's server that returns non-zero but leaves no server); these four items did not ship.

## The items

1. **POST_DEPLOY item 12 fails on this PC, by design of the PC, and needs the operator's decision.** The operator's server mounts its MoE
   config from the start script's own patch folder at `/vllm-tuned-moe` (`VLLM_TUNED_CONFIG_FOLDER=/vllm-tuned-moe`, seen with
   `wslc inspect vllm` on 2026-11-03); it does not mount `<WORK_DIR>/r9700/moe/<model>/merged`. So `moe-tune activate` can never reach it,
   which is exactly the failure item 12 names. Options for the operator: (a) point the start script's MoE mount at the exchange folder;
   (b) keep the two apart and copy an activated file into the patch folder by hand after a passed A/B; (c) a toolkit verb that does (b)
   with a backup. Until decided, item 12 stays "fails on this PC" in the stamp. No code changes before the decision.
2. **Is a foreground `wslc run --rm --name <n>` listed by `wslc list` while it runs?** UNVERIFIED (the chunk, A/B and linear units use it;
   the stubs assume yes). Observe it once during the next real foreground unit (`wslc list` from a second shell while a chunk runs), and
   record the answer in `research/module_tests.md`.
3. **Re-run `POST_DEPLOY.md` items 2 and 4–10 against the installed version** (the stamp of 2026-11-03 observed items 1, 3, 11 and 12
   only at d983327). Write the new stamp with date, target and version.
4. **The `test_kernels.sh` KW5 load flake.** It failed once in a full suite run on 2026-11-03 and passed alone twice and in the next full run;
   the cause is not found. Reproduce it under load (the full suite beside a CPU burner), find the race, and fix it RED-GREEN-RED.

## Build order

Item 1 first (a question to the operator; it decides whether item 12 changes). Items 2 and 3 at the next GPU window, in one sitting. Item 4
is CPU-only and can run any time.

## Test plan

Item 4 has a test (the flake reproduced, then fixed). Items 2 and 3 are observations recorded in `research/`. Item 1 is a decision; a code
change it causes gets its own tests.

## Definition of Done

- [ ] The operator's decision on item 1 is recorded, and item 12 of `POST_DEPLOY.md` matches it.
- [ ] Item 2's answer is in `research/module_tests.md`.
- [ ] A new `POST_DEPLOY.md` stamp covers items 2 and 4–10.
- [ ] KW5 passes under load, with the cause named in the commit.
