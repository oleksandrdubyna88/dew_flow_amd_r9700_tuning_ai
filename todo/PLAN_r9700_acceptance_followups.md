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

- [x] The decision on item 1 is recorded (option b, 2026-11-04), and item 12 of `POST_DEPLOY.md` matches it.
- [ ] Item 2's answer is in `research/module_tests.md`.
- [ ] A new `POST_DEPLOY.md` stamp covers items 2 and 4–10.
- [ ] KW5 passes under load, with the cause named in the commit.
