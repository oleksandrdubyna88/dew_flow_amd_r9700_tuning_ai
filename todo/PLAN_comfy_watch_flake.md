# PLAN — `test_comfy_watch.sh` does not depend on where a second boundary falls

> Status: **plan only, nothing implemented yet, 2026-11-11.** Scope: the comfy guard's ceiling in `lib/comfy_watch.sh`
> and its tests in `tests/test_comfy_watch.sh`; no behaviour of a real watch changes.

## Symptom

The CI job `tests · static · leftovers · plans` failed three times on 2026-11-10/11, on pull requests that changed
only the conventions pin (#29 and #31). Each time one assertion failed:

```
FAIL - each miss is counted aloud
FAIL tests/test_comfy_watch.sh (exit 1)
```

The runs were `42891650443` (attempts 1 and 2) and `42917113803` (attempt 1). A re-run of the same commit passed each
time, and the other CI run of the same commit passed too. The code under test did not change.

## Cause (read from the code, not yet proven by a test)

`tests/test_comfy_watch.sh:43-46` gives the guard two unreadable reads, then a good one, and runs it with
`comfy guard --max-s 1`. It then expects the output line `telemetry unreadable (2 of 3)`
(`lib/comfy_watch.sh:103`).

The ceiling is measured with bash `$SECONDS`, which counts whole seconds: `start=$SECONDS`
(`lib/comfy_watch.sh:88`), and the loop ends when `$((SECONDS - start)) -ge "$max"` (`lib/comfy_watch.sh:92`). So
with `--max-s 1` the guard ends at the next whole-second boundary, which can be a few milliseconds after it starts.
A tick is `_COMFY_GUARD_TICK_S=5` (`lib/comfy_watch.sh:28`) at `R9700_TIME_SCALE=100`, so 0.05 s. When the start
falls just before a boundary, the guard makes only one read, prints `(1 of 3)` and stops, and the assertion fails.
A slow runner makes this more likely, but it is not the root cause. The timeline mode uses the same measure
(`lib/comfy_watch.sh:143-145`).

## Build order

1. **A clock the test controls.** The ceiling reads its clock through one small helper in `lib/comfy_watch.sh`
   that a test can override (an environment variable naming a stub clock, the way `R9700_TIME_SCALE` already
   bends the sleeps). The default is the real clock. No busy wait on wall time, and no `date +%N`, which BSD
   `date` does not have (the plan round, 2026-11-11).
2. **Red first.** With the stub clock, start the guard 0.01 s before a second boundary of ITS OWN clock and run
   `comfy guard --max-s 1` with the test's two unreadable reads. On the current code it must end after one read
   (it prints `(1 of 3)`, not `(2 of 3)`), every time. Record that.
3. **The fix in the guard itself:** the ceiling counts elapsed time with sub-second resolution (or counts ticks),
   so `--max-s 1` lasts a full second. A test-only workaround (stopping by `--until`) is not enough: in real use
   a `--max-s N` watch can end up to one second early.
4. **Green**, then **red again**: put the old ceiling line back and check that the new test fails.
5. The same for the timeline mode's loop (`lib/comfy_watch.sh:145`).

## Test plan

- The new boundary test: red on the old code every time (it uses the stub clock, so it is deterministic), green
  after the fix.
- `tests/test_comfy_watch.sh` 20 times in a row under the bounded CPU burners of the earlier load-flake work
  (`research/PLAN_r9700_acceptance_followups.md`, item 4): 0 failures. Each run uses the suite's own scratch
  folder and stub processes, which the suite already removes; the loop checks after the 20 runs that no stub
  process and no scratch folder is left.
- The whole suite, once.

## Definition of Done

- [ ] The clock helper exists; the boundary test was red, is green, and is red again without the fix.
- [ ] `test_comfy_watch.sh` passes 20 of 20 under load.
- [ ] `research/module_tests.md` says how the guard's ceiling is measured.
- [ ] This plan is promoted to `research/` with its deviations.
