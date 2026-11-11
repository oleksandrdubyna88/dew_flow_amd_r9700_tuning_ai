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

1. **Red first.** A test that starts the guard just before a second boundary: wait until the sub-second part of
   `date +%s.%N` is above 0.95, then start `comfy guard --max-s 1`. It must fail at least 9 of 10 times on the current
   code. Record the counts.
2. **The fix, one of two (decided by the red test's evidence):**
   - (a) the ceiling counts ticks or uses a clock with sub-second resolution (`date +%s%N`), so `--max-s 1` means a
     full second; or
   - (b) the tests that need N reads stop the guard by reads, not by time: the `--until <file>` the guard already
     has (`lib/comfy_watch.sh:7`), written by the stub after the third read.

   (a) also fixes the real ceiling's up-to-one-second early end. (b) changes only the tests.
3. **Green**, then **red again**: put the old line back and check that the new test fails.
4. The same check for the timeline mode's loop (`lib/comfy_watch.sh:145`).

## Test plan

- The new boundary test: red on the old code at least 9 of 10 times, then green 20 of 20.
- `tests/test_comfy_watch.sh` 20 times in a row under the bounded CPU burners of the earlier load-flake work
  (`research/PLAN_r9700_acceptance_followups.md`, item 4): 0 failures.
- The whole suite, once.

## Definition of Done

- [ ] The boundary test exists, was red, is green, and is red again without the fix.
- [ ] `test_comfy_watch.sh` passes 20 of 20 under load.
- [ ] `research/module_tests.md` says how the guard's ceiling is measured.
- [ ] This plan is promoted to `research/` with its deviations.
