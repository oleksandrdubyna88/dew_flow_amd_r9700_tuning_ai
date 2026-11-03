# PLAN — E3 stories: kernels, prefix check, the unattended driver, publication

> Status: **IMPLEMENTED, 2026-11-03.** Scope: the three stories of epic E3 of
> [PLAN_r9700_tuning_toolkit.md](PLAN_r9700_tuning_toolkit.md) — section
> [E3 — kernels, prefix check, the unattended driver, publication](PLAN_r9700_tuning_toolkit.md#e3--kernels-prefix-check-the-unattended-driver-publication).
> No cornerstone (the parent names none for E3); the ledger line stays `Cornerstones: 2 of 2`.

This document splits E3 into stories. It adds no scope to E3 and removes none. The parent plan keeps the change
ledger; this document has none of its own (plan-change-control: a stories document keeps no ledger; E2 read it the
same way). E1 is merged on `main`; E2 is PR #3, nearly done; this branch (`feat/e3`) was made from `feat/e2` at
`9e61945`, so E2's code is here. **E3 starts after PR #3 merges**: the first E3 commit after that merges `main` into
`feat/e3`. Every story builds on E1 and E2 and changes their code only where this document says so.

## Stories at a glance

| Story | Title | Spec by | Code by | Depends on | Cornerstone |
|---|---|---|---|---|---|
| E3.S1 | The linear-kernel micro-benchmark and the prefix-cache check: the pure parts first (`lib/linear_bench.py` with arguments and `summarize`, `lib/prefixtest.py` with arguments and `summarize`, the fixtures), then the two workers of `lib/kernels.sh` under `step_run`, the two verbs `linear-bench` and `prefixtest`, the model fields `LINEAR_SHAPES` and `LINEAR_GROUP_SIZE` | Opus (this document) | Sonnet | E1, E2 (the placement and the hook) | no |
| E3.S2 | The `run` driver: a declarative plan file of steps, run as ONE supervisor (one lock, one stop, one restore); exit 3 waits and repeats the step; the deadline ends the chain; the exit code is the stopped step's and the line names the step; `--check` and `--dry-run` | Opus (this document) | Sonnet | E3.S1 (the plan file names its verbs) | no |
| E3.S3 | Publication and closing: every *Inputs* script has a home or is named as dropped with its reason, the final `README.md`, `research/architecture.md`, `research/module_tests.md`, `POST_DEPLOY.md`, the three acceptance templates (NOT RUN, with predictions), the family consumer row (already merged) and the visibility check | Opus (this document) | Sonnet | E3.S1, E3.S2 | no |

Review (coai plan gate, 2026-11-03, verdict proceed, 7 findings accepted, written into the sections they name; and a
risk consultation on the stop budget of S2, verified against `lib/step.sh`): a reused `--name` is compared with the
record's identity before it skips work (S1 decision 6); every shape/M pair exactly once (S1 decision 4); exactly one
line per requested length (S1 decision 7); a prefix server whose readiness fails is stopped before the worker exits
(S1 decision 7); `LINEAR_GROUP_SIZE > 0` asserted before any `%` (S1 decision 1); `run_record_write` reachable from
the signal handler, `_RG_RUN_STEP` set before the traps, a signal before the first step and between steps tested (S2
decisions 6 and 10); the chain's exit code is the NORMALIZED step result, with the supervisor's own codes kept and a
mapping table (S2 decision 5); `MAX_SERVER_STOPS` is a run-wide cap on ACTUAL production stops, charged right before
the stop and only when the server is listed, never reset by a step — the per-step reset of the first draft is
replaced (S2 decision 4).

Order: S1, then S2, then S3. S2 is the riskiest part (sequencing under one lifecycle, the budgets, one restore,
the exit code of a chain) and it needs S1's verbs to have something to chain, so S1 goes first and alone, with its
pure parts first inside it. Every story is reviewed by Opus and fixed by Sonnet (subagent-models, per-story pipeline).

## Coverage — every E3 item is in exactly one story

The parent's E3 *Scope* and *Done when*, item by item. Nothing below is in two stories.

| E3 item (parent plan) | Story | The other stories' part |
|---|---|---|
| `lib/linear_bench.py`, `lib/linear_bench_graph.py` (shapes from the model config) — here ONE file `lib/linear_bench.py` with `--timer graph\|eager`, decision S1-1 | S1 | S2 chains it; S3 names the merge of the two files in the *Inputs* home table |
| `lib/prefixtest.py` | S1 | S2 chains it |
| `bin/r9700 linear-bench \| prefixtest` | S1 | S3 documents them |
| The `run` driver (a declarative plan file of steps; exit 3 waits and repeats the step; the deadline ends the chain) and `bin/r9700 run` | S2 | S1 gives the verbs a `--name` so a chain resumes (S1 decision 6); S3 documents it |
| Stub test: a three-step plan through `run`, a RAM stop in step two kills the worker group, stops every container with the prefix, restores once, the exit code names the stopped step | S2 (R2) | — |
| Stub test: a step that exits 3 is repeated after the quiet wait and is not counted as a failure | S2 (R3) | — |
| `linear-bench` and `prefixtest` each write their result file on the R9700 with the 35B config (acceptance) | S3 (the templates, NOT RUN — the operator holds GPU runs) | S1 builds what they run |
| The `run` acceptance with a forced RAM limit: a clean stop and one restore | S3 (the template, NOT RUN) | S2 builds what it runs |
| Every script in *Inputs* has a home in `lib/`, `vendor/` or `bin/`, or is named as dropped with the reason | S3 (the home table) | — |
| `POST_DEPLOY.md`, the final `README.md`, `research/architecture.md`, `research/module_tests.md` | S3 | S1 and S2 add their own rows and sections as they land (the knowledge-base rule); S3 makes them final |
| The repository is public, its family checks are green, the conventions consumer list names it | S3 | — |

Out of E3 (nothing else is planned after it): the end-to-end A/B of a tile patch (speed-options § 12.1 line 539,
"Not shown: an end-to-end gain") is a measurement of a future day, not a toolkit feature; `moe-tune merge` and
`activate` as steps of a plan (refused by S2 decision 3).

## Facts every story uses

**Sources and their line numbers.** Cross-repository citations are paths, not links (planning-docs). The line
numbers are of the files in `dew_flow_benchmark · research/vllm-r9700-speed-options/harness/` at commit `c466652`
(read 2026-11-03; the working tree of that folder was clean): `linear_bench.py` (93 lines), `linear_bench_graph.py`
(44), `prefixtest.py` (34), `night.sh` (32), `night2.sh` (53), `night3.sh` (63), `night4.sh` (49), `night4_extra.sh`
(11), `night5.sh` (45), `night6.sh` (46), `night7.sh` (56), `night8.sh` (58), `night9.sh` (73), `night10.sh` (76),
`wait_quiet.sh` (13), `ram_guard_all.sh` (16), `prodcheck.sh` (18), `disk_gate.sh` (26), `resume_AC.sh` (14),
`speed_CB.sh` (37), `speed_A.sh` (95), `restore_server.sh` (22), `b2.sh` (34). The results are
`dew_flow_benchmark · research/RESULTS_vllm_029_r9700_speed_options.md` (847 lines; § 6.4 lines 272–279, § 6.5
281–304, § 6.6 306–326, § 11.3 453–477, § 12.1 510–539, § 13.3 631–642, § 13.4 644–657, § 14.4 777–809, the files
table 392–420). The data: `night-2026-10-30/phaseC2/linear_bench_graph.json` (50 rows, sha256
`853bcb00…e7fc1120`) and `night-2026-10-31/raw/prefixtest.txt` (16 lines, sha256 `c0015325…fda723c0`); neither
holds a personal path (scanned 2026-11-03).

**`e2e_moe.sh` does not exist.** The E3 brief names it among the old scripts. Checked 2026-11-03: it is not in the
harness folder, not anywhere in the `dew_flow_benchmark` working tree, not in that repository's history (`git log
--all` finds no file of that name), and the results document never mentions it. There is nothing to place; the home
table of S3 records this as *checked*, so the next reader sees the edges of the search (planning-docs: a negative
result names what was checked).

**How the linear-kernel benchmark ran** (`linear_bench.py`, read whole):

| Lines | What it does now | What E3 keeps or changes |
|---|---|---|
| 1–8 | three timings per shape and M: `default` (vLLM's dispatch: HIP skinny for M ≤ 5, Triton above), `split` (the HIP op on ≤ 5-row chunks), `tuned` (Triton with the best of a tile sweep); max abs diff of split and tuned against default; random int4 weights, bf16 activations, group 128 | kept exactly |
| 13–18 | `torch`, `triton`, `vllm._custom_ops`, `rdna_hybrid_w4a16`, `num_compute_units` — the image's vLLM | kept; imported lazily inside `main`, so the pure parts run without torch (S1 decision 2) |
| 20 | `GS = 128` | the model field `LINEAR_GROUP_SIZE` (default 128) |
| 22–28 | five hard-coded shapes `(name, K, N, layers)`: `linear_attn.in_proj_qkvz` 2048/12288/30, `linear_attn.out_proj / self_attn.o_proj` 4096/2048/40, `self_attn.qkv_proj` 2048/9216/10, `shared_expert.gate_up_proj` 2048/1024/40, `shared_expert.down_proj` 512/2048/40 | the model field `LINEAR_SHAPES` (S1 decision 1); the 35B file carries these five |
| 29–30 | `MS = [1, 2, 3, 4, 5, 6, 8, 10, 12, 16]`, `SWEEP_MS = [6, 8, 12, 16]` | verb options `--ms`, `--sweep-ms` with these defaults |
| 31 | `TILES`: the product of `[16] × [16, 32, 64, 128] × [32, 64, 128] × [1, 2, 4, 8] × [None, 1, 2]` = 144 tiles | kept (a constant of the kernel, not of the model) |
| 34–35 | `bench(fn)` = `triton.testing.do_bench(fn, warmup=25, rep=100) × 1000` µs — eager calls | `--timer eager` |
| 38–54 | `split_skinny`, `triton_tile` (`BLOCK_K = min(bk, GS)`, `ZP_BIAS=8`, `HAS_ZP=False`) | kept |
| 58, 62–66 | `torch.manual_seed(0)`; weights `randint(-128, 127, (n, k//2)) int8`, scales `rand × 0.02 + 0.001` bf16, activations `randn × 0.1` bf16 | kept (the same seed gives the same weights on every run) |
| 68–87 | one JSON row per shape and M, printed as it is made: `shape K N layers M default_us triton_default_us [split_us split_maxdiff] [tuned_us tuned_tile tuned_maxdiff]`; `split` only when `k × min(m, 5) ≤ LDS_CAPACITY_ELEMENTS`; a tile that does not compile is skipped with a stderr line | kept exactly: the published JSON is the fixture of `summarize` |
| 88–89, 92–93 | `json.dump(rows, f, indent=1)` to `sys.argv[1]` | `--out <file>`; the exchange folder (S1 decision 4) |

`linear_bench_graph.py` (read whole): lines 1–6, the eager timer held Python and launch work, so each call is
captured 20 times into one CUDA graph and the replay is timed with CUDA events, the median of 50 replays divided
by 20; line 12, `sys.path.insert(0, "/work/speed")` and `import linear_bench as lb`; line 15, `CALLS, REPLAYS = 20,
50`; lines 18–41, `bench_graph` (three warm-up calls on a side stream, the capture, one untimed replay, 50 timed
replays, `sorted(times)[len(times) // 2]`); lines 43–44, `lb.bench = bench_graph; lb.main(sys.argv[1])`. The
eager run gave no verdict (§ 11.3 lines 459–462: the default path summed to 23.8 ms per forward at M = 4 against
a whole decode step of 8.5–8.9 ms under CUDA graphs); the graph run is the plausible one (§ 12.1 line 530). So the
graph timer is the default of E3 and the eager one stays as an option (S1 decision 1).

How it ran: `speed_CB.sh` lines 14–19, a foreground container `vllmprtest-linear` under `timeout 5400` with
`--gpus all --shm-size 16g -e HIP_VISIBLE_DEVICES=0 -e TRITON_CACHE_DIR=/root/.cache/vllm/triton-linear -v
vllm-cache:/root/.cache/vllm -v <work>:/work <image> python3 /work/speed/linear_bench.py /work/speed/linear_bench.json`,
skipped when the JSON already exists (line 14), the row count by `grep -c '^{'` (line 19); `night3.sh` lines 35–45
the same for the graph timer (container `vllmprtest-linear2`), after a `stop vllm` (36) and the disk gate (37, 42),
skipped when `linear_bench_graph.json` exists (45). Measured: the graph run took 00:12–00:18 (§ 12.1 line 514);
the eager run 22:32–22:43 (§ 11.3 line 457). **The § 12.1 table is reproduced from the published JSON** (checked
2026-11-03): per M, the sum over the five shapes of `<value>_us × layers`, divided by 1000, printed with two
decimals, gives exactly the table of lines 519–528 (M 1: 2.48 / 4.97 / 2.79; M 6: 4.91 / 4.79 / 5.89 / 4.28 −13 %;
M 16: 6.93 / 6.69 / 11.67 / 5.95 −14 %), with the change `(tuned − default) / default × 100` rounded to a whole
percent. Scenario LB1 rests on this.

**How the prefix-cache check ran** (`prefixtest.py`, read whole): lines 1–6, the § 6.1 hypothesis ("is a full
prefix-cache hit ~12 s slow on this model?"); line 13, `url, model, tag = sys.argv[1:4]`; line 14, `rng =
random.Random(time.time_ns())` (new prompts per run, so no hit from an earlier run); lines 17–22, `ask(ids)`: POST
`<url>/v1/completions` with `{"model", "prompt": <token ids>, "max_tokens": 1, "temperature": 0}`, `timeout=900`,
the wall time by `time.perf_counter`; lines 25–26, `prompt(n)` = `n` ids in `randrange(1000, 150000)`; lines 29–34:
for n in `(8192, 1024)`: A and B random, `a_changed = a[:-64] + prompt(64)`, the six requests `A cold, A hit, A hit,
B cold, B hit, A partial`, times rounded to 2 decimals, ONE line `<tag> prefixtest len=<n> A cold=<s>s A hit=<s>s A
hit=<s>s B cold=<s>s B hit=<s>s A partial=<s>s`. No decision, no threshold, no cache metric: it prints times. It
ran inside the running test server's container after the bench of every arm-round (`speed_A.sh` lines 76–78:
`"$W" exec "$name" python3 /work/speed/prefixtest.py http://127.0.0.1:8000 "$SERVED" "$arm-$round" | tr -d '\r' |
tail -2 | tee -a "$OUT/prefixtest.txt"`, when `PREFIXTEST=1`; `night3.sh` line 12, `night4.sh` line 10, `night5.sh`
line 13 set it). Measured (§ 13.3 lines 633–642): 8k cold ≈ 2.0–2.15 s, hit ≈ 0.46–0.51 s, partial ≈ 0.46–0.49 s;
1k all ≈ 0.18–0.22 s; "A full prefix-cache hit is ~4× faster than a cold 8k prefill, in every arm", the ~12 s stall
is not a slow hit, its cause still unknown. The raw file holds 8 arm-rounds × 2 lengths = 16 lines (line 1:
`fcombo-1 prefixtest len=8192 A cold=2.1s A hit=0.5s A hit=0.51s B cold=2.15s B hit=0.48s A partial=0.49s`).

**How the nights were driven, and what `run` replaces** (the drivers, read whole; the pattern of `night5.sh`):

| Lines (`night5.sh`) | What it does now | What E3 keeps or changes |
|---|---|---|
| 2–7 | the header: each step in its own process group (`setsid`), the RAM guard and the deadline stop the group (night4's guard left an orphan), `QUIETCHECK=1` (exit 3 = not quiet: wait, no try counted), up to 6 failed tries, the server restored once at the exit | E1 built all of it into `supervise` and `step_run` (A5, A8); `run` is `supervise` around several `step_run` calls |
| 10 | `DEADLINE` 07:15 today, else tomorrow | the config's `DEADLINE` and `MAX_RUN_MINUTES` (E1) |
| 13 | `SERIES=("speedF:fbase fcombo fb1:1" "speedO7:o7ref o7:0")` — the night's steps as a bash array `outdir:arms:PREFIXTEST` | the plan file (S2 decision 1): one step per line, the verb's own command line |
| 14 | `trap 'rm -f skip_restore; restore_server.sh' EXIT` — the one restore | `cleanup_once` (E1) |
| 15 | `stop_tests`: every `vllmprtest-*` container stopped | `container_stop_all` by prefix (E1) |
| 16–27 | `guarded`: `setsid "$@"`, `ram_guard_all.sh <pid> 2048`, a deadline watcher every 30 s that stops the tests and `kill -TERM -- -<pid>` | `step_run` (E1) |
| 28–29 | `coai_count`, `quiet`: `timeout 900 wait_quiet.sh` | `quiet_wait` under `step_run`'s 900 s phase (E1) |
| 30 | `left`: the arm-rounds without a done marker | `series_left` (E1) |
| 35–37 | the loop: stop at 6 failed tries; stop when `left × ARM_SECONDS` no longer fits before the deadline | `MAX_FAILED_TRIES` per step; the series worker's own fit check (exit 4 → deadline) |
| 38 | not quiet → `timeout 300 tail -f /dev/null` and again | the quiet phase of `step_run` |
| 40–41 | the step; `case $rc in 0) ;; 3) "not quiet at an arm-round start, waiting";; *) fails++` | `_step_settle`: `worker:3` → "not quiet at a unit start, waiting", return 10, the loop repeats (lib/step.sh lines 177–191) |

The other drivers differ only in their steps: `night.sh` (prodcheck 26, `wait_quiet` under `timeout 3600` 27,
`speed_A.sh speedF` 29, `speed_CB.sh` 31; a single-pid TERM at 19, no `setsid`); `night2.sh` and `night3.sh` (phase
C, then a loop that takes the A/B when quiet and fits, else the next B1 chunk, else a 300 s sleep: lines 37–52 and
47–62); `night4.sh` (the kernel A/B 29, `fb1` added when "faster" 31, the A/B loop 35–44, `night4_extra.sh` 45–48);
`night6.sh` (`speedO7` only); `night7.sh`/`night8.sh` (`speedRA`, `speed27` with per-series env words at line 22;
night8 without the quiet gate, 40); `night9.sh`/`night10.sh` (`speed27` only; `settled()` lines 45–54 waits up to
20 min until no test container is listed and available RAM ≥ 24 GB; 2 failed tries). `resume_AC.sh` (lines 5–14)
is `speed_A.sh speedA` then `speed_CB.sh`, each under the RAM guard, no `setsid`, no deadline, no trap of its own.
`night4_extra.sh` (11 lines) is `speed_A.sh speedO7 o7ref o7` with `PREFIXTEST=0`.

**The incidents the driver must not repeat** (§ 13.4, § 14.4): the orphan series (lines 649–654: the guard sent
TERM to the driver only, the child wrote a false done marker and started the next arm while production was
loading — fixed by `setsid` and the group stop; E1 stops by session, A8); the restore skipped "as a planned restart"
so production was down 17:28–18:07 (lines 781–783; E1 restores once at every exit path); a retry started before
the stopped container was gone and failed with `ERROR_ALREADY_EXISTS` (lines 786–788; E1's `_step_wait_worker`
stops the containers of a stopped try before a retry, lib/step.sh lines 165–167); a retry 23 s after a RAM stop,
before the RAM was back, stopped again (lines 789–791; the RAM guard reads every scaled 15 s and the quiet phase
stands between tries); 26 test starts in one night with free RAM near 0 at several, then a Windows crash during a
production load — "one crash does not prove a cause" (lines 799–809; `MAX_SERVER_STOPS` bounds the stops per step,
S2 decision 4 says how a chain counts them). § 6.5 (lines 283–304): every model load drives the Modified list to
30–42 GB and available RAM to a few hundred MB for about 1.5 min; this is why the RAM guard fires during loads and
why the acceptance of `run` forces the limit instead of waiting for a real dip.

**What E3 reuses from E1 and E2, by name** (the contracts; read the E1 document's amendments A1–A24 and the E2
document's *Facts* and plan-gate findings before writing code — they are hard-won rules and nothing here re-invents
them): `supervise <verb> <prepare> <body>` and `step_run <label> -- <cmd…>` (A5: one supervisor, several steps, one
restore at the end; L22 proves a body with two `step_run` calls restores once — `tests/test_step.sh` line 450);
descriptor 9 only in the lock owner (A1: every child `9>&-`); the worker started as `setsid lib/worker_gate.sh …`
and stopped by SESSION (A2, A8); every adapter call under a ceiling cut at `R9700_T_STOP` (A9), the cleanup phase
without it; traps per call depth (the adapter puts the caller's traps back after every call; `_rg_traps_on`/`off`
around a body); the typed outcome KINDs `worker | ram_guard | disk_gate | deadline | interrupted | refused` and
`_step_settle` (lib/step.sh lines 177–191: `worker:0` done, `worker:3` wait, `refused:*` exit 2 at once, `worker:4`
and `deadline:*` exit 6, `disk_gate:*` 9, the rest a failed try); the exit table of E1 decision 6, listed in ONE
header (`bin/r9700` lines 9–24), the README and `research/architecture.md`, and checked by
`tests/test_lifecycle.sh` line 430 (`run` adds no code); `R9700_TIME_SCALE`, `R9700_CEILING_SCALE`,
`R9700_QUIET_CHECKS`, `stop_in` and the time scale 25 for a deadline test (A3, A10; E2's T13 and T19) — timing-safe
tests, never a fixed sleep; the stubs (A4: a container is a `setsid sleep` recorded with its start ticks, killed by
its owner; the scripted answers under `$R9700_STUB_DIR/answers/`); `container_name`, `wslc_run_once <ceiling>`,
`wslc_exec <ceiling>`, `wslc_list`, `wslc_stop`, `wslc_logs`, `serve_start` (also `--print`), `wait_ready`,
`arms_load`, `arm_args`, `arm_env`, `arm_mounts`, `disk_gate_check`, `quiet_check`, `outcome_write`, `rg_log`,
`_rg_run`, `cleanup_hook_set` (ONE hook per invocation, under an enforced ceiling); the record shape of E1.S3
decision 3 and E2.S2 decisions 2–4 (`<name>.part-<run id>` → validated → ONE rename → final, or
`rejected/<name>-<stamp>/` with a `reason`; a part a killed worker left goes to `rejected/` at the next start);
the identity re-check at every unit start (A16; E2.S2 decision 8: every placed asset, every unit, the record names
the hashes the unit started with); the placement with its hash checked before admission (`moe_place`,
`lib/moe_verb.sh` line 36; `moe_assets`, `lib/moe.sh` line 74); the one-place verb list (`bin/r9700 commands`, L18:
every verb is a row of the flow catalogue, derived, never typed); the test frameworks and the leftovers rules
(`tests/run.mjs`, `tests/lib/assert.sh`, `R9700_TEST_ROOT`, the token `r9700`; no new runner, no `mktemp`).

**The test-safety rules of 2026-11-02 — every E3 test brief says so** (`research/module_tests.md` § *The
process cap*): `tests/run.mjs` caps processes per test file (`ulimit -u <the user's threads at the start + 3000>`
and a watch on the file's session; a file that forks without end FAILS and is ended); every test command is run
under the outer guard `bash -c 'ulimit -u $(( $(ps -L -u $(id -u) --no-headers | wc -l) + 3000 )); exec nice -n
19 node tests/run.mjs <file>'`; **a test shim never resolves to itself**: it looks the real tool up with the shim
directory removed from `PATH` (`PATH="${PATH//"$dir:"/}" command -v python3`), refuses a result inside the shim
directory, and puts the directory on `PATH` once however often the shim is written. The cause: on 2026-11-02 a
`python3` shim found itself first on `PATH` and exec'd itself without end, about 15,900 processes. E3 adds no new
shim; where a brief says "a shim", this rule is the brief.

**Public repository.** No personal path, account name, machine name or token in any tracked file
(`tests/check_static.sh`: the four profile-path patterns); the machine's values live only in the untracked
`machine.env`. The new scripts under `lib/` may not hold the words `wslc`, `powershell` or `pwsh` as command words
or assignments (`--seam`): every call goes through the adapter. A plan file is the operator's own file outside the
repository; the README's example plan names only model files and arms.

---

## E3.S1 — The linear-kernel micro-benchmark and the prefix-cache check as steps

**Cornerstone:** no. **Depends on:** E1 (the supervisor, the serve and bench functions), E2 (the placement and
identity check, the cleanup hook). **Spec:** this section (Opus). **Code:** one Sonnet coder.

### Goal

Two scripts that were run by hand inside containers become two steps of the toolkit: `bin/r9700 linear-bench
<model>` times the model's hybrid W4A16 linear shapes (from the model config, no literal shape) under the CUDA-graph
timer and records the rows and the § 12.1-style table; `bin/r9700 prefixtest <model>` starts a measured server
for one arm, sends the twelve prefix-cache requests and records the two lines and their cold/hit ratios. Both run
as ONE step under the E1 supervisor with E2's placement, identity check and cache clear; both have pure parts that
reproduce the recorded results in CI without a GPU.

### Files

| File | What |
|---|---|
| `lib/linear_bench.py` | `run` (the benchmark, in the container: `--out`, `--shapes`, `--group-size`, `--ms`, `--sweep-ms`, `--timer graph\|eager`) and `summarize <json>` (the table of § 12.1; stdlib only); `linear_bench_graph.py` is merged into it as the `graph` timer |
| `lib/prefixtest.py` | `run <url> <model> <tag> [--lens] [--tail] [--seed] [--timeout]` (the twelve requests, stdlib `urllib`) and `summarize <file>` (the ratios); `parse_line` |
| `lib/kernels.sh` | sourced: `kernels_assets`, `kernels_cache_clear` (the hook), the shape words and the helpers; run as the worker: `bash lib/kernels.sh linear <outdir> <model> <name> <timer> "<ms>" "<sweep ms>"` and `bash lib/kernels.sh prefix <outdir> <model> <name> <arm> "<lens>" <tail>` |
| `lib/kernels_verb.sh` | the verb half: the argument grammar of `linear-bench` and `prefixtest`, `kernels_prepare`, `kernels_linear_body`, `kernels_prefix_body`, the dry runs (the shape of `lib/moe_verb.sh`) |
| `bin/r9700` | `verb_linear_bench`, `verb_prefixtest` (thin: parse, then `supervise`) |
| `lib/config.sh`, `machine.env.example`, `models/*.env`, `research/module_config.md` | the model fields `LINEAR_SHAPES` and `LINEAR_GROUP_SIZE` (decision 1); the 35B file gets the five shapes, the 27B file leaves `LINEAR_SHAPES` empty with a comment |
| `lib/moe_verb.sh`, `lib/moe.sh` | `moe_place` and `moe_identity_check` take the assets function as an argument (decision 3); `_MOE_CLEAR_SH` clears the `triton-linear` folder too (decision 5); nothing else changes |
| `tests/test_linear_bench.py`, `tests/test_prefixtest.py` | the pure scenarios LB and PT (pytest) |
| `tests/test_kernels.sh`, `tests/lib/kernelcase.sh` | the worker and verb scenarios KW and KV (bash, the stubs) |
| `tests/fixtures/kernels/linear_bench_graph.json`, `tests/fixtures/kernels/linear_table.txt`, `tests/fixtures/kernels/prefixtest.txt` | the published JSON (copied with `git -C <benchmark checkout> show <commit>:<path>`), the § 12.1 table as `summarize` prints it, the 16 raw lines |
| `tests/stubs/wslc` | a foreground `run --rm --name <prefix>linear-bench-*` answers from `answers/linear` (decision 8); `exec … prefixtest.py` answers from `answers/prefix` |
| `research/module_tests.md`, `research/architecture.md`, `README.md` | the rows and sections of the two verbs (S3 makes the documents final) |

### Boundaries

- In: everything the two scripts, their records and their verbs need; the two model fields; the three small edits of
  E2's files named above.
- Out: the chain (S2); the acceptance templates and the final documents (S3); any change of the series, the
  verdict or the MoE records.
- `lib/linear_bench.py` and `lib/prefixtest.py` are Python ≥ 3.10; `summarize`, `parse_line` and the argument
  parsing import nothing but the stdlib, so CI runs them; `torch`/`triton`/`vllm` are imported inside `run` only.
  Functions under 50 lines; no literal model, shape, device or file name outside the defaults named here.

### Source facts (verified 2026-11-03)

In *Facts every story uses* above: the two scripts line by line, the run lines of `speed_CB.sh` 14–19 and
`night3.sh` 35–45, the `exec` line of `speed_A.sh` 76–78, the measured durations and values of § 11.3, § 12.1 and
§ 13.3, and the reproduction of the § 12.1 table from the published JSON. Also: the hybrid W4A16 kernel is the
GPTQ int4 path of gfx12 (`MAX_SKINNY_BATCH_SIZE = 5`, `rdna_hybrid_w4a16.py:63`; the HIP op compiled for 1–5 rows;
§ 6.6 lines 320–325); whether the AWQ 27B model takes that path was NOT measured and is not known here (checked:
the results document names no 27B linear shapes; nothing else was checked), so the 27B file leaves `LINEAR_SHAPES`
empty and `linear-bench` refuses it with the reason. The § 6.1 stall (lines 203–245): one request per benchmark
run stalls ~12 s, cause unknown; a `prefixtest` cold request can show it.

### Decisions

**1. The shapes are a model field; the two timers are one file.** `LINEAR_SHAPES` (model file, type `shapes?`,
default empty): words `<name>:<K>:<N>:<layers>` separated by spaces, name `^[A-Za-z0-9._+-]+$`, K, N and layers
positive integers, K a multiple of 8 and of `LINEAR_GROUP_SIZE` (the kernel call reads `k // 8` and `k // GS`,
line 52), N a multiple of 16 (the smallest `BLOCK_N` of the sweep, line 31); the loader prints the usual
`config: <file>:<line>: LINEAR_SHAPES: <problem>; legal: …` line. `LINEAR_GROUP_SIZE` (model, `int:32:1024`,
default 128, line 20); its type already keeps it above 0 in the config, and `parse_shapes` asserts `group_size > 0`
itself before any `%` (gate finding 6: the function is also called from the container with an argument, where no
loader stands before it; a zero would be a `ZeroDivisionError` instead of a named refusal). The 35B file carries the five shapes of lines 22–28 with the second name written
`linear_attn.out_proj+self_attn.o_proj` (a name has no space; `+` joins the two layers that share the shape). An
empty `LINEAR_SHAPES` is legal and means "no hybrid W4A16 linear shapes known for this model": `linear-bench`
refuses it before anything is stopped (`r9700: linear-bench: <model>: LINEAR_SHAPES is empty: no shapes to time`,
exit 2), the same rule as `MOE_DTYPE=none`. The M lists are workload, not model: `--ms "1 2 3 4 5 6 8 10 12 16"`
and `--sweep-ms "6 8 12 16"` (every sweep M must be in `--ms`), the defaults of lines 29–30. `--timer graph|eager`,
default `graph`: the `bench_graph` of `linear_bench_graph.py` lines 18–41 moves into `lib/linear_bench.py` as
`bench_graph(fn)` beside `bench_eager(fn)` (lines 34–35); the sum of the eager values was not a plausible decode
time (§ 11.3), so the default is the timer that was. **One file, not two:** `linear_bench_graph.py` existed only
because it monkey-patched `lb.bench` (line 43); with the timer an argument there is nothing to patch. The parent's
design lists both files; the home table (S3) names the merge, as E2's did for `tune_chunk.sh` and
`moe_kernel_ab.sh` into `lib/moe.sh`. The `/work/speed` path of line 12 goes with it.

**2. The pure parts are importable without torch, and `summarize` reproduces § 12.1.** `python3 lib/linear_bench.py
summarize <json>` prints `M  default_ms  triton_default_ms  split_ms  tuned_ms  change` rows, one per M in
ascending order: per M the sum over the rows of `<value>_us × layers` / 1000 with two decimals (`Decimal`, as
`lib/verdict.py` does); `split_ms` and `tuned_ms` print `-` when a row of that M lacks the value; `change` is
`(tuned − default) / default × 100` rounded to a whole percent with its sign (`+6.0f`-style, `-13 %`), `-` when
there is no tuned value; then one `tiles M=<m>: <shape>=<tile> …` line per sweep M (the `tuned_tile` lists as
JSON text, copied). It refuses (exit 2, `linear: <reason>`) a file that is not a JSON list, a row without `shape`,
`layers`, `M`, `default_us` or `triton_default_us`, a `layers` or `M` that is not a positive integer, a value that
is not a finite number, and a `tuned_us` without `tuned_tile`. It checks nothing about shapes: the table is a sum.
Exit 0. `run` also prints the `summarize` table on stdout after the JSON is written, so the container log carries
it. Why Decimal: the same reason as E2.S1 decision 3 — a binary float sum can print `4.275` as `4.27` where the
record says `4.28`.

**3. The placement and the identity check are shared, not copied.** E2's `moe_place` (`lib/moe_verb.sh` line 36)
and `moe_identity_check` (`lib/moe.sh` line 97) read `moe_assets` by name. S1 gives both an argument — the name of
the assets function — with `moe_assets` as the default when it is omitted, so E2's callers and tests (T17, U1)
change nothing. `kernels_assets` prints `linear_bench.py lib/linear_bench.py required` and `prefixtest.py
lib/prefixtest.py required`; `kernels_prepare` calls `moe_place kernels_assets` before admission (the files under
`<WORK_DIR>/r9700/`, hash-checked, a stale one replaced through a part file); every unit calls `moe_identity_check
kernels_assets` at its start (A16's shape) and the record's env file names the hashes (`LINEAR_BENCH_SHA256=`,
`PREFIXTEST_SHA256=`). The identity words of a record (`IMAGE`, `MODEL_DIR`, `SERVED_NAME`, the arm's resolved
words for `prefix`) are written as `chunk.env` writes them (`_moe_env_line`). Rejected: a copy of the placement
loop into `lib/kernels.sh` (the family rule: a consumer imports, it does not copy).

**4. The linear unit: one foreground container, one record.** `bash lib/kernels.sh linear <outdir> <model> <name>
<timer> "<ms>" "<sweep ms>"`: the identity check; the exchange folder `<WORK_DIR>/r9700/linear/<name>/` is deleted
and made again (scratch, as E2's `tune/<chunk>/`); the disk gate check (`disk_gate_check`, as the chunk unit); then
`wslc_run_once <ceiling>` with the argv of `night3.sh` lines 38–40 built from the config: `run --rm --name
<prefix>linear-bench-<n> --gpus all --shm-size 16g -e HIP_VISIBLE_DEVICES=0 -e
TRITON_CACHE_DIR=/root/.cache/vllm/triton-linear -v <CACHE_VOLUME>:/root/.cache/vllm -v <WORK_DIR_WIN>:/work
<IMAGE> python3 /work/r9700/linear_bench.py run --out /work/r9700/linear/<name>/linear_bench.json --shapes
"<LINEAR_SHAPES>" --group-size <LINEAR_GROUP_SIZE> --ms "<ms>" --sweep-ms "<sweep ms>" --timer <timer>`, its
output to `<part>/linear.log`. The ceiling is 5400 s (`speed_CB.sh` line 16, `night3.sh` line 38), cut at
`R9700_T_STOP` by A9; a cut is `KIND=deadline`, exit 1 from the worker, 6 from the supervisor (E2.S2 decision 5's
rule for a chunk). The record `<outdir>/linear/<name>/` is built as `<outdir>/linear/<name>.part-<run id>/`:
`linear_bench.json` copied from the exchange folder, `linear.log`, `summary.txt` (the `summarize` output),
`linear.env` (`NAME`, `MODEL`, `IMAGE`, `MODEL_DIR`, `SHAPES`, `GROUP_SIZE`, `MS`, `SWEEP_MS`, `TIMER`, `CONTAINER`,
`STARTED_AT`, `ENDED_AT`, `RC`, the hashes). Validation before the ONE rename: `RC=0`; the JSON passes
`summarize`; **every expected (shape, M) pair appears EXACTLY once** — the set of `(shape, M)` of the rows equals the
product of the requested shapes and `--ms`, with no missing, duplicate or unexpected pair (gate finding 1: a row
count alone would accept a duplicate row standing in for a missing one; the reason names the first pair that is
missing, doubled or unexpected); every sweep M has `tuned_us` in every row of that M; every `*_maxdiff` is finite. A failed validation moves the part to `rejected/linear-<name>-<stamp>/` with a `reason`
and the worker exits 1 (a failed try). A part a killed worker left is moved to `rejected/` with `INTERRUPTED` at the
next start of any kernels unit (`moe_sweep_parts`' shape). `<outdir>` defaults to `kernels-<model>` (one folder
for both record kinds; no date, so a `--name` resumes on another day, A23). The container name's label is
`linear-bench-<step n>`; the default clear of decision 5 removes its cache after the invocation.

**5. The cache clear is the ONE hook, extended.** `linear-bench` registers `cleanup_hook_set moe_cache_clear` as
`moe-tune` does; `_MOE_CLEAR_SH` (`lib/moe.sh` line 37) gains `/root/.cache/vllm/triton-linear` in both its `du`
and its `rm -rf`, so one program clears every Triton tuning cache the toolkit fills, whichever units an invocation
ran (in a `run` chain, S2, the last registered hook runs once at the end; with one function there is nothing to
choose). The worker clears before its unit too, as the chunk unit does. The size of `triton-linear` was never
measured (checked: the phase C and C2 logs have no `du` line; the parent's growth row names only the MoE cache);
the clear bounds it to one invocation. The clear container's label stays `moe-clear` (one name, one stub answer).

**6. `--name` makes a kernels record resumable.** Both verbs take `--name <name>` (`^[a-z0-9][a-z0-9-]{0,30}$`,
the chunk grammar); the default is the UTC stamp, a new record every run. With a name, a final record of that name
under `<outdir>/linear/` (or `prefix/`) is "recorded, nothing to do" — counted before admission, exit 0, nothing
stopped — exactly as a recorded chunk (`moe_chunk_body`, `bin/r9700` lines 458–461), **but only when the record is
the same experiment** (gate finding 0): before it skips, the body reads the record's env file and compares its
`MODEL`, `IMAGE`, `MODEL_DIR`, the asset hashes, and the run parameters (`SHAPES`, `GROUP_SIZE`, `MS`, `SWEEP_MS`,
`TIMER` for linear; `ARM`, `ARM_ARGS`, `ARM_ENV`, `ARM_MOUNTS`, `SERVED_NAME`, `LENS`, `TAIL` for prefix) with the
request's resolved values (and, from the Opus review of E3.S1, `LINEAR_ARGV` and `SERVE_LINE`: the whole container command and the whole `serve_start --print` text under a fixed container name, so an edited `EXTRA_SERVE_ARGS`, `MAX_MODEL_LEN`, `MOUNTS`, `TUNED_CONFIG_DIR` or volume is another experiment too); a difference is refused with exit 2 and one line per differing key, `r9700: <verb>: the
record <kind>/<name> is another experiment: <KEY> <recorded> -> <requested>; use another --name`, before anything
is stopped. A reused name never silently stands for a different measurement — the fingerprint rule of the series
(E1.S3 decision 7) in its cheapest form. This is what the night
drivers did with `[ -s linear_bench.json ]` (`speed_CB.sh` 14, `night3.sh` 45), and it is what lets a plan file
(S2) be run again after a stop without repeating a 6-minute benchmark and a server start.

**7. The prefix unit: one measured server, twelve requests, one record.** `bash lib/kernels.sh prefix <outdir>
<model> <name> <arm> "<lens>" <tail>`: the identity check; the disk gate; `serve_start <prefix>prefix-<arm>-<n>
<part>/server.log -e … -v … -- <the arm's serve args>` with the arm's words from `arms_load`/`arm_args`/`arm_env`/
`arm_mounts` exactly as the series builds them (`_series_serve_options`, `lib/series.sh` line 185 — S1 calls the
same functions; a refused arm is refused before admission by `kernels_prepare` through `arms_check`); readiness is
`serve_start`'s own (`wait_ready`, `READY_TIMEOUT_S`). **When `serve_start` returns non-zero (the container did not
start, or `wait_ready` failed or timed out), the worker stops its container by name (`wslc_stop <name>`, with
`R9700_T_STOP` unset for that one call, as the cleanup phase does) BEFORE it exits 1** (gate finding 5): a server a
failed try leaves running is the `ERROR_ALREADY_EXISTS` of § 14.4 lines 786–788 at the next try, and in a chain it
is also the container the next step finds on the GPU; the series worker does the same (`lib/series.sh` lines 333
and 343). Then `wslc_exec 1800 <name> python3 /work/r9700/prefixtest.py
run http://127.0.0.1:8000 <SERVED_NAME> <name> --lens "<lens>" --tail <tail>` (the ceiling of a bench run,
`lib/bench.sh`; the script's own per-request timeout of line 21 stays 900 s and the exec ceiling bounds the whole:
every wait has a ceiling); the lines (CRs removed by the adapter) go to `<part>/prefixtest.txt`; then
`wslc_stop <name>` (the series stops its server at the end of an arm-round the same way, `lib/series.sh` line 382).
`prefix.env` holds `NAME`, `MODEL`, `ARM`, `ARM_ARGS`, `ARM_ENV`, `ARM_MOUNTS`, `IMAGE`, `MODEL_DIR`, `SERVED_NAME`,
`LENS`, `TAIL`, `CONTAINER`, the times, `RC`, the hashes; `summary.txt` is the `summarize` output. Validation before
the rename: `RC=0`; **exactly one line per requested length and no other line** — the multiset of `len=` values of
the lines equals the requested lengths, so a duplicate, a missing or an unexpected length is rejected naming it
(gate finding 2); each line passing `parse_line`; the container was still listed before
the stop (a lost server leaves no record — the series' rule, E1.S3 decision 3). Defaults: `--arm base` (the first
row of `config/arms.conf`, the base of every measured series), `--lens "8192 1024"` (line 29), `--tail 64`
(line 31); every length must satisfy `len + 1 ≤ MAX_MODEL_LEN` (one output token) and `tail < min(lens)`, checked
with the config before admission. Why one arm per invocation and not "every arm-round of a series": the check was a
hypothesis test of § 6.1, answered the same way in every arm (§ 13.3 line 641); a person who wants it for another
arm runs the verb again with `--arm`, or puts two lines in a plan. Rejected: a `PREFIXTEST=1` hook inside the
series (the source's form) — it would make the series record depend on a second script and a second validation.

**8. `prefixtest.py` gets arguments and a pure half.** `run <url> <model> <tag> [--lens "8192 1024"] [--tail 64]
[--seed <int>] [--timeout 900]`: the six requests per length of lines 29–34, the same payload (line 18), the same
line format (line 34, two decimals, the trailing `s`), printed as each length ends, `flush=True`. Without `--seed`
the RNG is seeded from `time.time_ns()` (line 14: new prompts per run); with it the prompts are reproducible (the
test's way to assert the partial prompt). The ids are `randrange(1000, 150000)` (line 26). An HTTP error or a
timeout is one `prefix: <name> at len=<n>: <reason>` line on stderr and exit 1 (nothing is retried: a stalled
request is a measurement, and the record's reason). `summarize <file>` reads every line with `parse_line` (the
regex of the exact format; a line that does not match is refused with its number) and prints, per line, `PREFIX
<tag> len=<n>: cold <c> s, hit <h> s (<r>x), partial <p> s` where `cold` is the mean of `A cold` and `B cold`,
`hit` the mean of the three hit values, `partial` the `A partial` value, `r = cold / hit` with one decimal, all
`Decimal`, two decimals for the seconds. No threshold and no verdict: measured before recommended; the record is
the numbers, and the table of § 13.3 is what a reader compares with. For the raw line 1 this gives `PREFIX fcombo-1
len=8192: cold 2.13 s, hit 0.50 s (4.3x), partial 0.49 s`; for line 2 `… len=1024: cold 0.21 s, hit 0.21 s (1.0x),
partial 0.19 s` (computed 2026-11-03: (2.1 + 2.15) / 2 = 2.125 → 2.13; (0.5 + 0.51 + 0.48) / 3 = 0.4967 → 0.50;
2.125 / 0.4967 = 4.28 → 4.3).

**9. The verbs.** `bin/r9700 linear-bench <model> [--name <name>] [--ms "…"] [--sweep-ms "…"] [--timer graph|eager]
[--out <name>] [--dry-run]` and `bin/r9700 prefixtest <model> [--name <name>] [--arm <arm>] [--lens "…"] [--tail
<n>] [--out <name>] [--dry-run]`. Syntax before the lock (one `r9700: <verb>: …` line, exit 2, the E2 grammar:
unknown options name the legal ones, a value that is missing is named); then `supervise <verb> kernels_prepare
kernels_<linear|prefix>_body`. `kernels_prepare`: `prepare_run`, the field checks of decisions 1 and 7, the arm
table (prefix), `container_name` for the longest label, the placement (decision 3). The body: the outdir line, the
dry run (below), the recorded-name count (decision 6), `cleanup_hook_set moe_cache_clear` (linear), then ONE
`step_run linear-bench|prefixtest -- bash lib/kernels.sh …`; after a done step it prints `recorded
linear/<name>` (or `prefix/<name>`) and the `summary.txt`. `--dry-run` prints the resolved container line
(`wslc_argv_text`, the words of decision 4) or the serve line (`serve_start --print`) and the exec line, starts
nothing, takes the lock and the restore-first like every E2 dry run (the README says so). The exit table is
unchanged: the verbs add no code.

**10. The stub.** `tests/stubs/wslc`: a foreground `run --rm --name <prefix>linear-bench-<n> …` whose program word
is `linear_bench.py` writes `answers/linear` (a JSON file the test prepares; default: the fixture) to the `--out`
path inside the mounted work folder (the stub resolves `/work/` to the test's `WORK_DIR` as it does for the chunk's
`--save-dir`) and prints `answers/linear.log`; `exec <name> python3 … prefixtest.py run …` prints `answers/prefix`
(default: the two fixture lines of `fcombo-1`, the tag replaced by the asked one). Every answer file is read by the
stub only; the stub never resolves a program of its own (*Facts*: the shim rule).

### Test scenarios

Python scenarios in `tests/test_linear_bench.py` (LB) and `tests/test_prefixtest.py` (PT); bash in
`tests/test_kernels.sh` (KW: the workers through `bin/r9700 step`, KV: the verbs), with `tests/lib/kernelcase.sh`
(`kernels_setup`, `kernels_step`, `kernels_verb`, `linear_answer`, `prefix_answer`, the shapes of `moecase.sh`).
Test names state the guarantee. Every bash test sets `R9700_TIME_SCALE=100`, `R9700_CEILING_SCALE=10`,
`R9700_QUIET_CHECKS=1` and a load file (the E1 preamble); the deadline tests use the time scale 25 and `stop_in`.

**Linear bench, pure (`tests/test_linear_bench.py`)**

1. *The § 12.1 table is reproduced from the published JSON.* `summarize fixtures/kernels/linear_bench_graph.json`
   exits 0 and its output equals `fixtures/kernels/linear_table.txt` line for line (the fixture is the table of
   decision 2 as printed; `research/module_tests.md` says the only edit is the layout — the results document's
   table holds `(HIP)`/`(Triton)` notes and bold that the program does not print).
2. *A missing value prints a dash and a present one a number.* Rows for M 1 (no `tuned_us`) print `-` in `tuned_ms`
   and `change`; rows for M 6 print both.
3. *The arithmetic is exact.* A synthetic list of two rows (`default_us` 1000.5 and 1000.4, layers 1 and 1) prints
   `2.00` (Decimal 2.0009 → 2.00), and a case named for the refuted approach:
   `test_float_summing_would_print_4_27_where_the_record_says_4_28_and_that_is_the_point` — values chosen so that
   the binary float sum rounds down and the Decimal sum rounds up.
4. *A malformed file is refused naming the problem.* Not a list; a row without `layers`; `M` = `"6"`; `default_us`
   `NaN`; `tuned_us` without `tuned_tile`: each exit 2 with one `linear: …` line naming the row index and the key.
5. *`run` refuses its arguments without touching torch.* `run` with `--sweep-ms "7"` and `--ms "1 2"`: exit 2,
   `linear: sweep M 7 is not in --ms`; `--shapes "a:2048:12288:30 b:100:16:1"`: exit 2 (K 100 is not a multiple
   of the group size); `--timer x`: exit 2 naming `graph eager`. All before any import of torch (the test runs with
   a `sitecustomize`-free `python3 -I` and asserts no `ModuleNotFoundError`).
6. *The shapes grammar is one function shared with the loader's check.* `parse_shapes("linear_attn.in_proj_qkvz:2048:12288:30 …")`
   returns the five tuples of lines 22–28; the loader's `shapes?` check in `lib/config.sh` and this function agree
   on the test's list of good and bad words (the bash side is KV5).
7. *The commands are catalogued.* `run` and `summarize` each have a `covered` row in `research/module_tests.md`
   (the E1 derivation).

**Prefix test, pure (`tests/test_prefixtest.py`)**

1. *The twelve requests have the recorded shape, in order.* A local `ThreadingHTTPServer` (the pattern of
   `tests/test_harness.py` line 62) records every POST: `run http://127.0.0.1:<port> m t --seed 1`: 12 POSTs to
   `/v1/completions`, each `{"model": "m", "prompt": [ints], "max_tokens": 1, "temperature": 0}`; the first six
   prompts have 8192 ids, the next six 1024; prompts 1, 2, 3 identical (A), 4 and 5 identical (B), 6 equals A in
   its first 8128 ids and differs in the last 64; every id in `[1000, 150000)`.
2. *The output line is the recorded format.* The two printed lines match `parse_line` and carry two-decimal
   seconds with the trailing `s`; `--lens "512"` prints one line with `len=512`.
3. *Without a seed the prompts differ between two runs; with one they are equal.*
4. *An HTTP failure is one line and exit 1, nothing retried.* The server answers 500 on the fourth request: exit 1,
   stderr `prefix: B cold at len=8192: HTTP 500`, exactly four POSTs received.
5. *A timeout is the same.* `--timeout 0.2` against a handler that sleeps 1 s: exit 1, `… : timed out`, one POST.
6. *`summarize` reproduces the ratios of the raw file.* `summarize fixtures/kernels/prefixtest.txt`: 16 lines;
   line 1 and line 2 are the two strings of decision 8; the `fbase-3` 8k line prints `(4.2x)` ((2.00 + 1.96) / 2 =
   1.98; (0.47 + 0.47 + 0.46) / 3 = 0.4667; 4.24 → 4.2).
7. *A line that is not the format is refused with its number.* A file whose line 3 lacks `A partial`: exit 2,
   `prefix: line 3: not a prefixtest line`.
8. *The arithmetic is exact and the mean is a mean.* Synthetic lines where a float mean would print `0.49` and the
   Decimal mean prints `0.50`, named for the refuted approach.
9. *The commands are catalogued* (`run`, `summarize`).

**The workers through `step` (`tests/test_kernels.sh`, KW)**

1. *A linear unit records only a validated JSON, with the measured argv.* `step --model <35B fixture> linear-bench
   -- bash lib/kernels.sh linear <outdir> <model> n1 graph "1 2 6" "6"`: exit 0; `linear/n1/` holds the five files;
   the stub's call log shows one `run --rm --name r9700tune-linear-bench-1 … python3 /work/r9700/linear_bench.py
   run --out /work/r9700/linear/n1/linear_bench.json --shapes "<the five words>" --group-size 128 --ms "1 2 6"
   --sweep-ms "6" --timer graph` with the image and volumes of the config (asserted word by word from `run_argv`);
   `linear.env` names the hashes of the two placed files and `summary.txt` equals `summarize` of the JSON; the
   exchange folder was deleted and made before the run (a stale file put there first is gone).
2. *A JSON that fails `summarize` is a rejected record and a failed try.* `answers/linear` holds a row without
   `layers`: no `linear/n1/`, `rejected/linear-n1-<stamp>/reason` names the row, the worker exited 1; with
   `MAX_FAILED_TRIES=1` the step exits 7.
3. *Every shape/M pair exactly once.* (a) 10 rows for 3 shapes × 4 M: `reason` names the first missing pair
   (`missing (<shape>, M 6)`). (b) 12 rows where one pair is doubled and one is missing (the count is right): `reason`
   names the duplicate — the positive that a bare count would have passed, named for the refuted approach. (c) 13
   rows with an extra pair for an M that was not asked: `reason` names `unexpected (<shape>, M 7)`.
4. *A placed file edited between placement and the unit is refused.* The test changes
   `<WORK_DIR>/r9700/linear_bench.py` after `kernels_prepare` placed it (the step verb places it; the test edits it
   through an `on-stop` hook or before the gate): `KIND=refused`, exit 2, no record, one restore (T21's shape).
5. *The deadline ends a linear unit as `KIND=deadline`.* Time scale 25, `DEADLINE` from `stop_in`, the stub's
   foreground run holds (`R9700_STUB_DELAY_S`): exit 6, `rejected/` holds the part with `INTERRUPTED` after the next
   unit start, the restore before `T_END` (T13's shape).
6. *A RAM stop during a linear unit leaves no prefixed container and clears the cache in the exit path.* The RAM
   answer drops after `steps/1.ready`: `KIND=ram_guard`, no `r9700tune-*` listed, the clear container's argv holds
   all three cache folders, `cleanup hook: moe_cache_clear rc=0` before `restored` (T9's shape).
7. *A prefix unit starts the arm's server, sends the exec, stops the server, and records.* `step … prefixtest --
   bash lib/kernels.sh prefix <outdir> <model> p1 base "8192 1024" 64`: the call log holds the `run -d --rm --name
   r9700tune-prefix-base-1 …` line equal to the series' serve line for `base` (compared with `serve_start --print`
   output), then `exec r9700tune-prefix-base-1 python3 /work/r9700/prefixtest.py run http://127.0.0.1:8000
   qwen3.6-35b-a3b p1 --lens "8192 1024" --tail 64`, then `stop r9700tune-prefix-base-1`; `prefix/p1/prefixtest.txt`
   is the two answer lines; `summary.txt` their ratios; `prefix.env` names the arm's words.
8. *A server lost during the exec leaves no record.* `lose_server_after` (seriescase) ends the container during the
   exec: `rejected/prefix-p1-<stamp>/reason` says the server was not listed; no `prefix/p1/`.
9. *Exactly one line per requested length.* `answers/prefix` with one line for two lengths: rejected, `reason`
   says `missing len=1024`; two lines both `len=8192`: `duplicate len=8192`; a third line `len=512`: `unexpected
   len=512` (a count of 2 would have passed the duplicate: the positive case).
10. *A recorded name is not run again when it is the same experiment, and is refused when it is not.* After KW1,
    the same unit with `n1`: `recorded linear/n1, nothing to do` and no new `run` in the call log. Then `n1` with
    `--ms "1 2"` (another parameter): exit 2, `the record linear/n1 is another experiment: MS "1 2 6" -> "1 2"`, no
    admission; the same with the 27B model file (another `MODEL_DIR`) and with `linear.env`'s `LINEAR_BENCH_SHA256`
    edited (another asset): each refused naming the key. The prefix twin: `p1` with `--arm ta3` is refused naming
    `ARM`.
13. *A server that does not become ready is stopped before the worker exits.* `answers/ready.r9700tune-prefix-base-1`
    says not ready (S11's knob): the worker exits 1; the call log holds `stop r9700tune-prefix-base-1` AFTER the last
    readiness probe and BEFORE the outcome is written (the stub's `containers/` record of that name is gone when
    `steps/1.outcome` exists); `rejected/prefix-p1-<stamp>/reason` says `not ready`; with `MAX_FAILED_TRIES=2` the
    retry starts a second container of the same name without `ERROR_ALREADY_EXISTS` (the stub refuses a duplicate
    name as the real `wslc` does, E1 decision 12).
11. *The unit's identity check covers every kernels asset, derived.* For every line of `kernels_assets` (never a
    typed list) a corrupted placed file makes the unit refuse naming that file (T17's shape).
12. *`moe_place` and `moe_identity_check` without an argument still read `moe_assets`.* E2's T17 and U1 pass
    unchanged (run them; this is the companion that proves the default).

**The verbs (`tests/test_kernels.sh`, KV)**

1. *Every refusal of the grammar is before the lock.* Unknown option, `--name` with a bad character, `--timer x`,
   `--sweep-ms` outside `--ms`, `--lens` with a non-number, `--tail` ≥ a length, a missing model: exit 2, one
   `r9700: <verb>: …` line, no lock file written.
2. *An empty `LINEAR_SHAPES` is refused after the restore-first, before any stop.* The 27B fixture: exit 2,
   `LINEAR_SHAPES is empty`, a marker left by hand was restored first (U5's shape), `stop_lines` is 0.
3. *A length that does not fit the context is refused with the config.* The 27B file (`MAX_MODEL_LEN=16384`) with
   `--lens "16384"`: exit 2, `len 16384 + 1 > MAX_MODEL_LEN 16384`.
4. *The dry runs print the real calls' words and start nothing.* `linear-bench … --dry-run` prints the line of
   KW1's argv; `prefixtest … --dry-run` prints the serve line and the exec line; the call log holds `list` only;
   nothing under `<outdir>`; the lock was taken (exit 4 for a second verb meanwhile, U6's shape).
5. *The fields are loaded, validated and documented.* `LINEAR_SHAPES` with K 100: `config: …: LINEAR_SHAPES: …`;
   `LINEAR_GROUP_SIZE=16`: refused with the range; `research/module_config.md` lists both (the E1 derived test).
6. *A recorded name is counted before admission.* After a recorded `linear/n1`, `linear-bench … --name n1`: exit
   0, `recorded linear/n1, nothing to do`, no stop, no marker.
7. *The verb lists and the catalogue agree* (L18: `commands` prints `linear-bench` and `prefixtest`; each has its
   row).
8. *The two verbs under `run` are S2's* (named here so nobody writes a chain test in this file).

### Brief for the Sonnet coder

Read first: this section; *Facts every story uses* (the two scripts line by line, the test-safety rules); the E2
document's S2 and S3 briefs (`lib/moe.sh` as the worker shape, `lib/moe_verb.sh` as the verb shape, the stub's
foreground `run --rm --name` branch); the E1 document's S1 brief for `lib/verdict.py` (Decimal, the part write,
`run(args)` in the tests) and its *Test frameworks* and *Test leftovers* paragraphs. The source scripts are in
`dew_flow_benchmark · research/vllm-r9700-speed-options/harness/` — read them with `git -C <that checkout> show
c466652:<path>`, never by editing that repository; the fixtures are copied the same way. Do not touch
`lib/series.sh`, `lib/step.sh`, `lib/run_guarded.sh`, `lib/restore.sh` or `lib/adapter.sh`.

Order of work — **the pure parts first, with their tests green, before any bash**:

**1. `lib/linear_bench.py`** — move the five functions of the source (`split_skinny`, `triton_tile`, `main` → `run`,
`bench` → `bench_eager`, the `bench_graph` of the graph file) under a `run` subcommand whose torch imports happen
inside it; `parse_shapes`, `parse_ints`, `summarize` at module level, stdlib only (`argparse`, `json`, `decimal`,
`itertools`). `TILES` stays the constant of line 31 with a comment naming it. Keep the row dict's keys and order
(lines 68–85) and `json.dump(rows, f, indent=1)`. The `summarize` output of decision 2; print it at the end of `run`
too. Exit codes: 0, 2 (`linear: …` on stderr), 1 when the container-side run fails after the arguments were good.

**2. `lib/prefixtest.py`** — `run` and `summarize` of decision 8; `parse_line` with ONE compiled regex of the exact
format; the request function of lines 17–22 unchanged but for the timeout argument; `argparse` with the defaults
named. Every number a `Decimal` from the text.

**3. The fields** — `_field model LINEAR_SHAPES shapes? ""` and `_field model LINEAR_GROUP_SIZE int:32:1024 128` in
`lib/config.sh`'s table, the `shapes?` check as a `_cfg_shapes_problem` beside `_cfg_mounts_problem` (one word at
a time, the rules of decision 1; the group-size multiple is a cross-field check after both fields are read); the
example file, the two model files (the 35B's five words; the 27B's commented `# LINEAR_SHAPES=` with "not measured
for the AWQ path"), `research/module_config.md` rows with origin `linear_bench.py` lines 20, 22–28.

**4. `lib/moe_verb.sh`, `lib/moe.sh`** — `moe_place [<assets function>]`, `moe_identity_check [<assets function>]`,
`_moe_assets_unchanged` the same (`${1:-moe_assets}`); `_MOE_CLEAR_SH` with the third folder in both commands;
adjust E2's T-tests that assert the clear argv (the three folders now) — and nothing else of E2.

**5. `lib/kernels.sh`, `lib/kernels_verb.sh`, `bin/r9700`** — decisions 3–7 and 9. The worker's two faces as
`lib/moe.sh`; `kernels_assets`; the records through a part directory and ONE `mv -T`; the env files through
`_moe_env_line`; the sweep of a stale part; the `recorded … nothing to do` count. The verb half: the grammar
functions (`kernels_args <verb> <args…>`, syntax only, before the lock), `kernels_prepare`, the two bodies, the dry
runs through `wslc_argv_text` and `serve_start --print`. `bin/r9700`: two thin verbs, the header's verb list.

**6. The stub** — decision 10: the foreground branch of `tests/stubs/wslc` recognises the program word
`linear_bench.py` (as it does `benchmark_moe.py`), writes the answer file to the `--out` path mapped into the
test's `WORK_DIR`, prints the log answer; the `exec` branch recognises `prefixtest.py` and prints `answers/prefix`
with the tag replaced. A stub reads only under `$R9700_STUB_DIR` and never resolves a program.

**7. Tests** — LB1–LB7, PT1–PT9, KW1–KW13, KV1–KV8; `tests/lib/kernelcase.sh`; the three fixtures copied with
`git show`. The HTTP test server of PT1–PT5 is the class of `tests/test_harness.py` (import it; do not copy it).
Every chain through `step` uses the E1 preamble and `stop_in`; nothing sleeps for a fixed time waiting for a
state. **The process cap and the shim rule of *Facts* apply to every test you write**: run every test command under
the outer `ulimit -u` guard, and if you ever write a shim (you should not need one), it looks its tool up with its
own directory removed from `PATH`.

**8. Docs** — `research/module_tests.md`: the new files in *Where it is*, the fixture folder `tests/fixtures/kernels/`
with its provenance (the two source paths, the commit, the hashes, the one layout edit of the table fixture), the
catalogue rows `bin/r9700 linear-bench`, `bin/r9700 prefixtest`, `lib/linear_bench.py run|summarize`,
`lib/prefixtest.py run|summarize`, `lib/kernels.sh linear|prefix`, and under *what it does not prove*: the benchmark
and the prefix requests never run in CI (the stub answers are the fixtures); the eager timer is kept but its
numbers are not a decode time (§ 11.3). `research/architecture.md`: a module row *Kernels* and the two verbs in the
verb table with their order of operations (as the MoE verb's rows). `README.md`: a section *Kernels and the prefix
check* after *MoE tuning*: what each verb measures, the two commands with the 35B model, where the records are,
`--name`, the 27B refusal and why.

**Commands.**

```bash
G='ulimit -u $(( $(ps -L -u $(id -u) --no-headers | wc -l) + 3000 ))'
bash -c "$G; exec nice -n 19 node tests/run.mjs tests/test_linear_bench.py tests/test_prefixtest.py"
bash -c "$G; exec nice -n 19 node tests/run.mjs tests/test_kernels.sh tests/test_moe.sh tests/test_moe_tune.sh tests/test_config.sh tests/test_lifecycle.sh"
bash -c "$G; exec nice -n 19 node tests/run.mjs"      # everything
bash tests/check_static.sh
node .agents/conventions/tools/leftovers-check.mjs --repo . --token r9700 --identity "the R9700 vLLM tuning toolkit" --profile node
node .agents/conventions/tools/plan-lifecycle.mjs
```

Report the runner's lines and the total, the static check's exit code, and paste the output of LB1 (the § 12.1
table reproduced) and PT6 (the ratios of the raw file).

---

## E3.S2 — The `run` driver: a plan file of steps under ONE supervisor

**Cornerstone:** no. **Depends on:** E3.S1 (the verbs a plan names), E1 (A5: `supervise` around several
`step_run` calls), E2 (the MoE verbs as steps). **Spec:** this section (Opus). **Code:** one Sonnet coder.

### Goal

A person writes a plan file — one step per line, each line the command line of a toolkit verb — and runs
`bin/r9700 run <plan>` overnight. The steps run in order under ONE lifecycle: one lock, the restore-first, the
operator's server stopped at the first admission and restored ONCE at the end (between steps only by the quiet
rule); a step whose worker exits 3 is waited out and repeated, not counted; the deadline ends the chain; a step that
ends with any other non-zero code ends the chain with that code, and the line on stderr and the run folder name the
step. `run --check <plan>` validates every step's syntax and config without the lock; `run --dry-run <plan>` prints
every step's dry run under one supervisor. The eleven night drivers become one verb and a text file.

### Files

| File | What |
|---|---|
| `lib/run_plan.sh` | sourced: `plan_parse <file>` (the lines into steps, the refusals), `plan_words <line>` (the config grammar's split), `plan_step_kind <words…>` (the verb and mode, and whether it is a legal step), `run_record_write` (`run.txt`), `run_plan_copy` |
| `bin/r9700` | `verb_run`: the argument grammar, the validation of every step (`--check`), `run_prepare` (every step's config and prepare), `run_body` (the chain), the step dispatch table (`series`, `moe-tune chunk`, `moe-tune ab`, `linear-bench`, `prefixtest`) |
| `lib/step.sh` | `_step_admit`: the stop budget charged right before `wslc_stop` of the operator's server and only when it is listed, the cap checked there, before the marker, the stop and the worker (decision 4); `step_budget_reset`: the per-step failed-try count only; nothing else changes |
| `lib/run_guarded.sh` | `_RG_RUN_STEP=""` in `_rg_state_reset`; `run_record_write` defined HERE (decision 6), so the signal handler always reaches it |
| `tests/test_run.sh`, `tests/lib/runcase.sh` | the scenarios R1–R21 (bash, the stubs of E1, E2 and S1) |
| `tests/test_lifecycle.sh`, `tests/test_guards.sh` | E1's L12 and the exit-8 guard test rewritten to the new charge rule (decision 4) |
| `tests/fixtures/plans/*.plan` | the plan files of the scenarios (model names of the fixture model files, nothing else) |
| `research/module_tests.md`, `research/architecture.md`, `README.md` | the rows and sections of `run` (S3 makes them final) |

### Boundaries

- In: the plan grammar, the chain, the budgets, the record of a run, `--check`, `--dry-run`, the stub tests.
- Out: any new worker (the steps are S1's, E1's and E2's verbs as they are); any change of `supervise`,
  `cleanup_once`, the guards, the restore or the adapter; a fit check for the kernels steps (decision 7). In
  `_step_admit` only the place and the condition of the stop charge change (decision 4).
- `bin/r9700` stays under 800 lines (`research/module_tests.md`'s limit); the parser lives in `lib/run_plan.sh`
  so it is tested as functions.

### Source facts (verified 2026-11-03)

In *Facts every story uses*: the `night5.sh` table (the steps array line 13, the loop 35–41, the `case $rc`
line 41 with `3)` as "waiting"), the other drivers, `resume_AC.sh`, and the incidents. In the code: `supervise`
(`lib/run_guarded.sh` lines 433–454: lock → `restore_first` → prepare → `deadline_compute` → `run_dir_new` → traps
→ body → `cleanup_once`, the body's code returned, 5 when the restore failed); `step_run` (`lib/step.sh` lines
193–216: `_RG_TRIES=0` per call; the quiet phase; the admission; `_step_settle` return 10 → the loop repeats);
`_step_admit` counts `_RG_STOPS` at every admission, also when the server is already down (lines 99–105 and the
comment), and refuses at `MAX_SERVER_STOPS` with exit 8 (lines 94–97); `_rg_state_reset` (lines 457–461) zeroes
`_RG_STOPS` once per `supervise`; `cleanup_hook_set` keeps ONE function per invocation (lines 498–505) and the hook
runs once in `cleanup_once` after an admitted step (lines 553–556); the verbs' bodies (`series_body` lines 268–286,
`moe_chunk_body` 450–465, `moe_ab_body` 468–483) each end in ONE `step_run` and return its code, and their `*_args`
functions parse syntax before the lock (`series_args` 219–254, `moe_tune_args` 398–433); `config_load` validates and
exports every field of both files (`research/module_config.md`); L22 (`tests/test_step.sh` line 450) proves a body
with two `step_run` calls restores exactly once.

### Decisions

**1. The plan file is data: one step per line, the verb's own command line.** A text file; blank lines and lines
starting with `#` are skipped; every other line is ONE step: `<verb> <arguments…>` where the words are split as the
config grammar splits a value (bare words, or ONE pair of double quotes around a word with spaces, as `--keys "24
32"`); a `$`, a backtick, a single quote, `;`, `|`, `&`, `<`, `>`, `(`, `)`, a carriage return or a tab anywhere in
the line is refused — the file is never given to a shell. A step's words are exactly what a person would type after
`bin/r9700`, so the README's examples are both documentation and plans. Why this grammar and not YAML or JSON: the
toolkit has one config grammar already (`research/module_config.md`), the operator reads and writes the file by
hand at 22:00, and every verb already validates its own command line — a second description of the same arguments
would be a second list to keep in step. The old form (`night5.sh` line 13: `outdir:arms:PREFIXTEST` in a bash array)
is what this replaces.

**2. The legal steps are the GPU verbs.** `series …`, `moe-tune chunk …`, `moe-tune ab …`, `linear-bench …`,
`prefixtest …`. Each is dispatched to the verb's own triplet — `<verb>_args` (syntax), `<verb>_prepare` (the config
and the checks before admission), `<verb>_body` (the dry run, the recorded count, ONE `step_run`) — the functions
`bin/r9700` already has (`series_args`/`series_prepare`/`series_body`, `moe_tune_args`/`moe_prepare`/
`moe_chunk_body`|`moe_ab_body`, S1's `kernels_args`/`kernels_prepare`/`kernels_*_body`), through a dispatch table
in `verb_run` (one `case`, the ONE place that says which verbs are steps; `plan_step_kind` reads the same table
through a function, never a second list).

**3. Four verbs are refused as steps, each with its reason in the line.** `init` (it is the machine check a person
runs before a night, not a measurement; `run` does its own restore-first), `verdict` (a reading verb; run it in the
morning), `moe-tune merge` (a reading verb; its inputs are chunk names a person chooses after reading the chunks)
and `moe-tune activate` (the ONE step that changes what the operator's own server reads, refused while a server is
listed, explicit by E2.S3 decision 1 — a chain that activated a file at 03:00 would be a decision nobody made). A
line with `--dry-run` is refused (`run --dry-run` dry-runs the whole plan; a plan line is a real step). A verb that
is not in the table: `r9700: run: <file>:<line>: "<verb>" is not a step; legal: series, moe-tune chunk, moe-tune ab,
linear-bench, prefixtest`. All problems of the file are printed in one pass (the loader's rule), exit 2, before the
lock.

**4. `MAX_SERVER_STOPS` is a run-wide cap on ACTUAL production stops; the failed tries are per step; the deadline
is per run.** (The risk consultation of 2026-11-03, verified against `lib/step.sh`; it replaces the first draft's
per-step reset of the stop count.) Today `_step_admit` counts `_RG_STOPS` at every admission once the container
list answered, also when the operator's server is already down (lines 99–105), and refuses at the cap before the
list (lines 94–97). A chain of three steps would therefore be charged three stops while the server was stopped
once, at the first admission, and stayed down; and a per-step reset would let a chain bounce the server once per
step without any cap. So the count becomes what its name says: **`_RG_STOPS` is charged in `_step_admit` right
BEFORE the `wslc_stop` of the operator's server (lines 113–117), and only when the server is listed; the cap is
checked at that same place, and an admission that WOULD stop the server past the cap is refused there — before the
marker is written, before the stop, before any worker is started — with the existing exit-8 meaning (`r9700:
admitted <n> times (each admission stops the operator's server), limit MAX_SERVER_STOPS=<n>` reworded to `stopped
the operator's server <n> times, limit MAX_SERVER_STOPS=<n>`); an admission that finds the server already down
charges nothing. Nothing resets `_RG_STOPS` inside an invocation; `step_budget_reset` resets only the per-step
failed-try count (`_RG_TRIES`, which `step_run` zeroes already — the function exists so `run_body` says what it
resets).** Consequences, all tested: a quiet chain costs ONE stop and ONE restore however many steps it has (L22
proves two steps, one restore; R8 proves four); only the busy-wait restore (`_step_restore`, "restoring the
operator's server while the PC is not quiet", decision 15 — kept: it gives the operator the server back while the PC
is in use) followed by a new admission costs another stop; when the cap is reached, the chain ends with 8 and
`run.txt` names the step, and a refused admission never prevents the final restore (the marker of the earlier stop
stands, `cleanup_once` restores). E1's L12 ("after an exit 3 the server is already down and the admission still
counts") and A20's wording follow the new rule: S2 rewrites that scenario's assertion to "charges nothing"; the
cross-field rule `MAX_FAILED_TRIES ≤ MAX_SERVER_STOPS` stays (a retry after a busy-wait restore is a stop again).
`run --check` does NOT refuse `steps × MAX_SERVER_STOPS`; it prints the worst case as one line (`run: at most
<n> stops of the operator's server if every step is admitted after a busy wait; MAX_SERVER_STOPS=<cap>`). The
night's budget of `night5.sh` (6 failed tries over two series, line 36) becomes `MAX_FAILED_TRIES` per step
(default 3) — the same figure per series. The deadline is computed ONCE by `supervise` for the whole chain
(`T_END`, `T_STOP`): a step that ends with 6 ends the chain, and every later step is `not-started`. **The exit-3 repeats have a bound of their own** (S2 review, 2026-11-03): an admission that finds the server down charges no stop and an exit 3 is not a failed try, so a worker that exits 3 again and again on a quiet PC would be started again until `T_STOP`; each step therefore allows `3 × MAX_FAILED_TRIES` repeats (the test knob `R9700_MAX_WAIT_REPEATS`, environment only, replaces the figure), and the next exit 3 ends the step with exit 8 and `r9700: <step> waited <n> times (worker exit 3), limit <m>`.

**5. Validate everything, then run; re-check each step at its start.** `verb_run`: the arguments (`run <file>
[--check] [--dry-run]`; the file must exist and be readable); `plan_parse` (decisions 1–3, every line); then for
every step in order, `<verb>_args` on its words (syntax, one pass, every problem printed with `<file>:<line>:`);
exit 2 on any. `--check` then also runs every step's config and prepare without the lock (`prepare_run`'s
`config_load` for the step's model, the arm table, the field checks, `container_name`, the placement is NOT done —
nothing is written) and prints `run: step <k>: ok (<line>)` per step, exit 0 — the thing to run before leaving the
PC. Without `--check`: `supervise run run_prepare run_body`. `run_prepare` = the same per-step prepare for EVERY step
(so a typo in step 3 is refused before step 1 stops anything), including each kernels and MoE step's placement.
`run_body`: for each step: `step_budget_reset` (the failed tries); re-parse the line (`<verb>_args`, cheap, sets the verb's globals);
`config_load` for the step's model again (the files are re-read: a model file edited since the validation is
refused here with exit 2 and the chain ends — the identity re-check at a unit start is the worker's own, A16); the
step's prepare again; `run_record_write k running`; the body; its code. Code 0 → `done`, next step. Any other code →
`stopped`, the chain ends, the remaining steps `not-started`, and `run_body` returns that code. The stderr line:
`r9700: run: stopped at step <k> of <n> (<the line>): <code>` after the step's own line (so the operator sees both
the cause and the place). **The exit code is the stopped step's NORMALIZED code — the body's result after
`_step_settle` (lib/step.sh lines 177–191) and the verb's own refusals — never a raw worker code; `run` adds no
code, and the supervisor's own codes keep their meaning** (gate finding 4). The mapping, which the code carries as
a comment at the dispatch and R17 tests row by row:

| What happened in the step | Step body returns | `run.txt` state and code | `run` exits |
|---|---|---|---|
| the worker ended 0 | 0 | `done 0` | goes on; 0 at the end |
| the worker ended 3 (not quiet) | (not returned: the step waits and repeats) | stays `running` | — |
| the worker ended 4 (nothing more fits) or `KIND=deadline` | 6 | `stopped 6` | 6 |
| the worker ended 5 (the gate never opened, A21) or any other code; `KIND=ram_guard` | a failed try; after `MAX_FAILED_TRIES`: 7 | `stopped 7` | 7 |
| `KIND=refused` (identity, A16), a refused argument or config, a fingerprint difference, a record of another experiment | 2 | `stopped 2` | 2 |
| `KIND=disk_gate` | 9 | `stopped 9` | 9 |
| not quiet before the deadline; the stop cap reached (decision 4) | 8 | `stopped 8` | 8 |
| a busy-wait restore that did not become ready | 5 | `stopped 5` | 5 |
| INT, TERM, HUP | (the handler exits) | `interrupted -` | 130, 143, 129 |
| the lock held (before any step) | — | no run folder | 4 |
| the FINAL restore did not become ready (`cleanup_once` returns 5) | the step's own code stays in `run.txt` | unchanged (`done 0` on a chain that finished, or the stopped step's code) | **5 overrides** (`supervise` line 451: a cleanup code replaces the body's) |

A raw worker 4 or 5 therefore never surfaces as a lock or restore failure: 4 and 5 at the `run` level mean only what
E1's table says. The status file of the run folder is `supervise`'s (`done`, `deadline`, `failed`, `not-quiet`,
`disk-gate`, `restore-failed`, `interrupted`).

**6. The run folder records the plan and the chain.** `run_dir_new` makes `<RESULTS_DIR>/runs/<id>/` as for every
invocation; `run` adds `plan.txt` (the plan file copied byte for byte, its sha256 in `run.txt`'s header) and
`run.txt`: `PLAN=<path> SHA256=<hash> STEPS=<n>` then one line per step `<k> <state> <code|-> <the line>`, rewritten
atomically (part + `mv`) at every state change (`not-started` → `running` → `done|stopped|interrupted`). The signal
handler's cleanup marks the running step `interrupted` (an `_RG_RUN_STEP` the handler reads; `run_body` sets it to
the step number before the step and to `""` after it). **`run_record_write` is defined in `lib/run_guarded.sh`
itself, beside the handler, and `_RG_RUN_STEP=""` is set in `_rg_state_reset` — before `_rg_traps_on` registers
the handler** (gate finding 3): the handler must never call a function that exists only when another file was
sourced, and a signal before the first step (between the traps and the first `run_record_write k running`) or
between two steps (after `done` and before the next `running`) finds `_RG_RUN_STEP` empty and writes nothing extra
— `run.txt` then shows every step as `done` or `not-started`, and the exit is 130/143/129 as always (R20). The
per-step records (`steps/<n>.*`) are the supervisor's as before: `run.txt` maps a step to its worker starts by
the `STEP_N` range it writes.

**7. No fit check for the kernels steps; the series keeps its own.** The series worker refuses to start an
arm-round that does not fit before `T_STOP` (exit 4 → `deadline`, `lib/series.sh` line 24); a chunk is bounded by
`MOE_CHUNK_MAX_S` cut at `T_STOP`; a linear or prefix unit is bounded by its container ceiling cut at `T_STOP` (A9),
so a step started late is ended at `T_STOP` as `KIND=deadline`, exit 6, and the chain ends with the restore inside
the budget. The cost is at most one wasted container start. Rejected: an expected-seconds table per step (E2.S2
decision 5 rejected it for chunks: numbers for one model, wrong for the next). A person who wants the morning free
orders the plan so the long step is last.

**8. Resume is re-running the same plan.** Every step verb skips its recorded work before admission (a series' final
arm-rounds, a recorded chunk, a kernels record by `--name`, S1 decision 6), so after a stop the same `run night.plan`
runs what is left; a step whose identity changed is refused by its own fingerprint (exit 2 ends the chain before
anything is stopped if it is step 1, or after the earlier steps' records are final). The README says: give every
kernels step a `--name`, or it runs again.

**9. The dry run.** `run --dry-run <plan>`: `supervise` (the lock, the restore-first, the deadline, the run folder,
as every E2 dry run) around a body that calls every step's body with the verb's dry flag set (`_SERIES_DRY=yes`,
`_MOE_DRY=yes`, S1's `_KERNELS_DRY=yes`), prints `run: step <k> (<line>):` before each, and writes nothing under any
outdir (S19's rule: a dry run never changes an identity; `run.txt` is written in the run folder only).

**10. Signals and the one cleanup are E1's.** INT, TERM and HUP end the chain through `_rg_on_signal`: the running
step's outcome `interrupted`, the worker's session, the containers, the one hook, the one restore, exit 130/143/129.
The deadline watcher and the RAM guard of the running step are the ones `step_run` started. Nothing in `run` is a
second lifecycle.

### Test scenarios

`tests/test_run.sh` (R), bash, with `tests/lib/runcase.sh` (`run_setup`: the E1 preamble, the fixture machine file,
the two fixture model files, the stub answers of a one-round stub series (`seriescase.sh`), of a chunk
(`moecase.sh`) and of the kernels (S1's `kernelcase.sh`); `plan_write <name> <lines…>`; `run_bg <args…>`/`run_end`;
`run_txt` reads `run.txt`). The chain scenarios use `R9700_TIME_SCALE=100`, `R9700_CEILING_SCALE=10`,
`R9700_QUIET_CHECKS=1`; the deadline scenarios the time scale 25 and `stop_in`. The three-step plan of R1–R3 is
`prefixtest <35B> --name p1`, `series <35B> base --rounds 1`, `linear-bench <35B> --name n1`.

1. *A three-step plan runs to the end under one lifecycle.* Exit 0; `stop_lines` 1 (the operator's server stopped
   once, at step 1's admission); `log_count pwsh.exe -Detach` 1 (one restore, at the end); the three records
   exist (`prefix/p1`, `rounds/base-1`, `linear/n1`); `run.txt` has three `done` lines; the supervisor log shows
   `admitted` three times (the server listed only at the first); `status` is `done`.
2. *A RAM stop in step two kills the worker group, stops every container with the prefix, restores once, and the
   exit code names the stopped step.* `MAX_FAILED_TRIES=1`; the RAM answer drops after step 2's `steps/2.ready`
   (the stub series holds in a bench with `R9700_STUB_DELAY_S`): exit 7; no process of step 2's session is left
   (`session_pids`); no `r9700tune-*` listed; `log_count pwsh.exe -Detach` 1; stderr holds `r9700: step failed 1
   times, last: ram_guard` and then `r9700: run: stopped at step 2 of 3 (series … base --rounds 1): 7`; `run.txt`:
   `1 done 0`, `2 stopped 7`, `3 not-started -`; `prefix/p1` exists, `linear/n1` does not.
3. *A step that exits 3 is repeated after the quiet wait and is not counted as a failure.* The load file says busy
   before step 2's arm-round (the series worker's gate, `lib/series.sh` line 290, exits 3); the stub's
   `on-stop-<prefix container>` hook of step 1 turns the load busy and a second hook (or a timed write from the
   test, bounded by `wait_for` on the supervisor log line `not quiet at a unit start, waiting`) turns it quiet:
   exit 0; the supervisor log has `not quiet at a unit start, waiting` then a second `admitted` for step 2; `failed
   try` appears nowhere; `run.txt` three `done`; the restore count is 1 (the quiet wait stayed under the 900 s
   phase, so the mid-run restore of decision 15 did not fire); `stop_lines` 1.
4. *The deadline ends the chain and the restore is inside the budget.* Time scale 25, `DEADLINE` by `stop_in`, step
   1's stub holds: exit 6; `run.txt`: `1 stopped 6`, `2 not-started -`, `3 not-started -`; `restored` before
   `T_END` (read `T_END` from `step --show-deadline` with the same config); one restore.
5. *`--check` refuses a bad plan before the lock, all problems in one pass.* A plan with an unknown verb on line 2,
   a `$` on line 4 and `moe-tune activate` on line 5: exit 2, three `r9700: run: <file>:<n>: …` lines, no lock file,
   no run folder. A good plan: exit 0, one `run: step <k>: ok (…)` per step, no lock file.
6. *A `--dry-run` inside a plan is refused, and so are the four verbs that are not steps.* Five one-line plans:
   each exit 2 with the reason of decision 3.
7. *`run --dry-run` prints every step's dry run under one supervisor and writes nothing.* The call log holds `list`
   calls only; no file under any outdir; `fingerprint.json` absent after a dry run of a series step (S19); the
   lock was taken (a second verb gets 4 meanwhile, bounded by `wait_for` on the run folder).
8. *Four continuously quiet steps cost exactly one production stop and one restore.* Named for the refuted
   approach: `t_charging_every_admission_would_refuse_the_fourth_step_and_that_is_the_point` — a four-step plan (the
   three above plus `prefixtest <35B> --name p2`) with `MAX_SERVER_STOPS=3`: exit 0, four `done`; `stop_lines` 1
   (one `wslc stop vllm`); `log_count pwsh.exe -Detach` 1; the supervisor log shows four `admitted` lines and ONE
   `stopped the operator's server` charge line; the test also asserts, through the stub's call log, that the server
   was never listed at admissions 2–4.
17. *The exit code of a chain is the normalized step result, row by row.* For every row of the mapping table of
    decision 5 that a stub can produce: a worker that exits 4 (`worker.sh exit4` as the series' stand-in) ends the
    chain with 6 and `run.txt` `stopped 6` — never 4; a worker whose gate never opens (A21's exit 5, by killing the
    gate file's directory permission before the gate: the L21 knob) is a failed try and, with `MAX_FAILED_TRIES=1`,
    7 — never 5; a `KIND=refused` worker gives 2; the disk gate 9; `run` exits with exactly the code `run.txt`
    records for the stopped step. The companion: the mapping comment at the dispatch names every row of this test
    (a scan asserts the two agree).
18. *The stop cap is reached only by real stops, and a refused admission launches nothing and never prevents the
    final restore.* `MAX_SERVER_STOPS=3`, a four-step plan, and a busy interval longer than the 900 s quiet phase
    (scaled) between every two steps (the on-stop hook of each step's container turns the load busy; a later
    bounded write turns it quiet after the supervisor log shows `restoring the operator's server while the PC is
    not quiet`): steps 1–3 each stop the server after a busy-wait restore (three `stop vllm` calls, three charge
    lines); the fourth admission is refused BEFORE any stop or worker start — the call log shows no fourth `stop
    vllm`, no fourth worker start, no marker write after the refusal — with exit 8, stderr `stopped the operator's
    server 3 times, limit MAX_SERVER_STOPS=3` then `r9700: run: stopped at step 4 of 4 (…): 8`, `run.txt` `4 stopped
    8`; the final restore ran (`restored` in the log, `pwsh.exe -Detach` count 4: three busy-wait restores and the
    final one) and the operator's server is listed at the end.
19. *A genuine final restore failure returns 5 while `run.txt` keeps the step's own outcome.* `fail-list` makes the
    restore's lists fail past A22's retries after a chain that finished: exit 5; `run.txt` three `done 0`;
    `status` `restore-failed`; the marker stays. The same after a RAM stop at step 2 with `MAX_FAILED_TRIES=1`:
    exit 5, `run.txt` `2 stopped 7`.
20. *A signal before the first step and between steps is clean.* (a) `TERM` sent as soon as the run folder exists
    and before `steps/1.ready` (bounded `wait_for` on the folder): exit 143, `run.txt` every step `not-started`, no
    `interrupted` line, no marker, no restore call (nothing was stopped), the lock free. (b) `TERM` sent after step
    1's record is final and before step 2's `admitted` (the on-stop hook of step 1's container sends it): exit 143,
    `run.txt` `1 done 0`, `2 not-started -`, `3 not-started -`, one restore. (c) R10 stays the during-a-step case.
21. *`--check` prints the worst case and refuses nothing for it.* A ten-step plan with `MAX_SERVER_STOPS=3`: exit 0,
    one line `run: at most 10 stops of the operator's server if every step is admitted after a busy wait;
    MAX_SERVER_STOPS=3`.
9. *A step refused by its identity ends the chain with 2 after the earlier records are final.* Step 2's
   `fingerprint.json` is made stale (a patch file edited before `run`): exit 2; `run.txt`: `1 done 0`, `2 stopped
   2`, `3 not-started -`; `prefix/p1` final; `fingerprint differs` on stderr; one restore. The same edit before step
   1 (step 1 a series): exit 2 before any stop (`stop_lines` 0).
10. *A `TERM` during step 2 ends the chain with 143, one restore, and `run.txt` says interrupted.* `run.txt`: `1
    done 0`, `2 interrupted -`, `3 not-started -`; no `r9700tune-*` listed; `status` `interrupted`.
11. *Re-running the plan after a stop runs only what is left.* After R2 (step 1 recorded): the same plan with the RAM
    answer normal: step 1 prints `recorded prefix/p1, nothing to do` (no admission for it), step 2 and 3 run; the
    supervisor log has `admitted` twice; exit 0.
12. *Each step runs with its own model's config.* A two-step plan (`prefixtest <35B> --name a`, `prefixtest <27B>
    --name b`): the two serve lines in the call log carry `qwen3.6-35b-a3b` then `qwen3.8-27b` as the served name
    and the two `MODEL_DIR` values; `prefix.env` of each record names its model.
13. *A model file edited between the validation and the step is refused at the step.* The 27B file of R12 is given
    a bad `MAX_NUM_SEQS` after `run` started (the on-stop hook of step 1's container): exit 2 at step 2, `config: …`
    on stderr, step 1's record final, one restore.
14. *The plan is copied into the run folder with its hash.* `plan.txt` equals the plan file byte for byte;
    `run.txt`'s `SHA256=` equals `sha256sum` of it; a plan with a comment and blank lines keeps them in the copy.
15. *A plan with no step is refused.* An empty file and a comments-only file: exit 2, `r9700: run: <file>: no
    step`.
16. *The verb list and the catalogue agree, and the exit codes are unchanged.* L18 with `run`; the exit-code
    agreement test of `tests/test_lifecycle.sh` line 430 passes with the three lists unchanged (`run` adds no
    code: the assertion is that the header's list is the same set as before this story).

### Brief for the Sonnet coder

Read first: this section; *Facts every story uses* (the `night5.sh` table, the incidents, the test-safety rules);
`lib/run_guarded.sh` lines 427–567 (`supervise`, the signal handler, `cleanup_once`) and `lib/step.sh` whole;
`bin/r9700` whole (the triplets you dispatch to); the E1 document's A5, A20, A21 and L22; S1's `lib/kernels_verb.sh`.
Do not change `supervise`, `cleanup_once`, the guards, the restore or the adapter; in `_step_admit` change only the
place and the condition of the stop charge (decision 4); `lib/step.sh` gains only `step_budget_reset`.

**1. `lib/run_plan.sh`** — `plan_words <line> <array name>`: the split of decision 1 (reuse the config loader's
value parser for the quoted form; refuse the listed characters with the character named); `plan_parse <file>`:
fills `_PLAN_LINES` (line numbers), `_PLAN_TEXT` (the lines) and `_PLAN_KIND` (`series`, `moe-chunk`, `moe-ab`,
`linear-bench`, `prefixtest`) through `plan_step_kind`, which calls a function `run_step_table` that `bin/r9700`
defines (the dispatch `case` returns the kind or 1); every problem to stderr as `r9700: run: <file>:<line>: …`,
return 2 after the whole file; `run_record_write <k> <state> [<code>]` and `run_plan_copy` of decision 6.

**2. `bin/r9700`** — `verb_run`: the grammar (`run <file> [--check] [--dry-run]`, syntax before the lock);
`run_validate` (every step's `<verb>_args` with the words; `--check` adds the per-step prepare without the lock and
without placement — add a `_R9700_NO_PLACE=yes` that `kernels_prepare` and `moe_prepare` honour, or call the
prepare's parts without `moe_place`; say which in the code comment); `run_prepare` and `run_body` of decision 5
with the dispatch `case`; `_RG_RUN_STEP` set to the step number before each step's body and to `""` after it; the
stderr line of decision 5 and the mapping table as a comment at the dispatch (the companion of R17 reads it); the
worst-case line of `--check` (decision 4). The dry run of decision 9. The header's verb list and exit codes (no new
code).

**3. `lib/step.sh`** — decision 4: in `_step_admit`, move the `_RG_STOPS` increment from after the list (line 102)
to directly before `wslc_stop "$R9700_PROD_CONTAINER"` (line 114), inside the `listed = yes` branch, and move the
cap check (lines 94–97) to that same place, before `marker_write_base`: the order becomes list → (listed? cap check
→ refuse 8 with nothing written) → marker → charge → stop → worker. Reword the exit-8 line as decision 4 says, and
the header comment of lines 99–101. `step_budget_reset() { _RG_TRIES=0; }` with a comment that the stop count is
run-wide and never reset. Rewrite E1's scenario L12 so it asserts that an admission with the server already down
charges nothing (and the exit-8 test of `tests/test_guards.sh` so it reaches the cap through real stops, with a
busy-wait restore between tries); keep every other E1 assertion.

**4. `lib/run_guarded.sh`** — `run_record_write <k> <state> [<code>]` defined here (it writes `${RUN_DIR}/run.txt`
atomically from the arrays `_PLAN_*` when `_RUN_PLAN_ACTIVE=1`, and returns 0 at once otherwise, so it is a no-op in
every other verb); `_RG_RUN_STEP=""` added to `_rg_state_reset`; ONE line in `_rg_on_signal`, before
`cleanup_once`: `[ -z "${_RG_RUN_STEP:-}" ] || run_record_write "$_RG_RUN_STEP" interrupted`. `lib/run_plan.sh`
keeps the parser only.

**5. Tests** — R1–R21 in `tests/test_run.sh` with `tests/lib/runcase.sh`; the plan fixtures under
`tests/fixtures/plans/` name only the fixture model files. Every wait is `wait_for` on a file or a log line, bounded;
every deadline test uses `stop_in` and the time scale 25; nothing sleeps for a fixed time. **The process cap and the
shim rule of *Facts* apply**: run every test command under the outer `ulimit -u` guard; a chain test starts many
processes (a supervisor, workers, guards, stub containers), so watch the runner's `process cap` line and keep the
default headroom; no test writes a shim.

**6. Docs** — `research/module_tests.md`: `tests/test_run.sh` in *Where it is*, the catalogue row `bin/r9700 run`
(R1–R21), and under *what it does not prove*: a chain over real containers (the acceptance of S3).
`research/architecture.md`: the verb `run` in the verb table (its order of operations: parse → validate every step →
lock → restore-first → every step's prepare → the deadline → the run folder → the chain → the one cleanup), the plan
grammar, the dispatch table as the ONE list of steps, the budgets rule, `run.txt`. `README.md`: a section *A night:
`run`* with an example plan (the three-step plan of R1 on the 35B model, a `moe-tune chunk` line with `--coarse`),
`--check` before leaving, how a stop reads (`run.txt`), how to resume (the same command), the four verbs that are
not steps and why.

**Commands.**

```bash
G='ulimit -u $(( $(ps -L -u $(id -u) --no-headers | wc -l) + 3000 ))'
bash -c "$G; exec nice -n 19 node tests/run.mjs tests/test_run.sh tests/test_step.sh tests/test_lifecycle.sh"
bash -c "$G; exec nice -n 19 node tests/run.mjs"      # everything
bash tests/check_static.sh
node .agents/conventions/tools/leftovers-check.mjs --repo . --token r9700 --identity "the R9700 vLLM tuning toolkit" --profile node
node .agents/conventions/tools/plan-lifecycle.mjs
```

Report the runner's lines and the total, the static check's exit code, and paste the stderr of R2 (the two lines
that name the cause and the step) and the `run.txt` of R2 and R4.

---

## E3.S3 — Publication and closing

**Cornerstone:** no. **Depends on:** E3.S1, E3.S2 (everything is built). **Spec:** this section (Opus). **Code:**
one Sonnet coder (documents, templates, the two checks).

### Goal

The repository is a finished, public toolkit: every old script has a home or is named as dropped with its reason;
the README, `research/architecture.md`, `research/module_tests.md` and `POST_DEPLOY.md` describe what exists and
nothing that does not; the three GPU acceptance runs of E3 are written as templates with predictions, marked NOT RUN
(the operator holds GPU runs); the family consumer row is confirmed; the family checks are green.

### Files

| File | What |
|---|---|
| `research/INPUTS_homes.md` | the home table (decision 1): every file of the old harness folder → its home, or dropped with the reason; `research/README.md` gets its row |
| `README.md` | final: the purpose, the quick start (`init`, `series`, `verdict`), *MoE tuning*, *Kernels and the prefix check*, *A night: `run`*, the records, the exit codes (the list checked by L-430), tests, the acceptance records |
| `research/architecture.md` | final: the module map with every module, the verb table with every verb, the supervisor and its order, the exit table, the flow, nothing "planned" left in it (E3 is the last epic) |
| `research/module_tests.md` | final: every test file, every flow `covered` or `not covered` with the reason, the fixtures, the knobs, the process cap, what it does not prove |
| `POST_DEPLOY.md` | decision 3: items 2 and 3 merged, a `run --check` item added, item 11 names the E3 records |
| `research/ACCEPTANCE_linear_bench_2026-11-03.md`, `research/ACCEPTANCE_prefixtest_2026-11-03.md`, `research/ACCEPTANCE_run_2026-11-03.md` | the three templates, NOT RUN, with predictions (decision 2); `research/README.md` rows |
| `tests/test_static.sh` | one more scan: no tracked `.md` under `research/` or `README.md` says "planned", "E3 will" or "not built yet" except the acceptance templates' NOT RUN lines (decision 4) |
| `todo/` and `research/` | the promotion of the parent and the three stories documents is NOT part of S3's code: it is the main session's closing task after the acceptance runs (planning-docs: promote in the same task that finishes the plan; the acceptance boxes stay open until the operator's session runs them) |

### Boundaries

- In: documents, templates, the two small checks, the verification of the consumer row and the visibility.
- Out: code of the toolkit (S1, S2); the GPU runs themselves (the operator's session, later); the promotion of the
  plans (the main session, when the acceptance records are filled).

### Source facts (verified 2026-11-03)

The harness folder's 33 files and their purposes (*Facts*; the scout's inventory, every file opened by the main
session where a home decision rests on it); the `e2e_moe.sh` search (*Facts*); the parent's *Inputs* table (lines
42–50 of the parent) and *Design* (56–74); `dew_flow_conventions` commit `abac5a8` ("docs(readme): consumers —
dew_flow_amd_r9700_tuning_ai joins (token r9700, pinned at release 5863c60) (#110)", on `main` of that repository,
read 2026-11-03) — the consumer row is merged; `POST_DEPLOY.md` as it is (12 items, the cap; the stamp of
2026-11-02, PARTIAL); `research/ACCEPTANCE_moe_tune_2026-11-02.md` as the template shape; § 12.1 lines 519–528
and § 13.3 lines 635–639 for the predictions; § 6.5 lines 283–304 for the RAM behaviour of a load.

### Decisions

**1. The home table covers every file of the old folder, not only the parent's rows.** The parent's DoD says every
script of *Inputs*; the folder holds 33 files, and the parent's table groups them. `research/INPUTS_homes.md` lists
every file with its home or its reason, so no reader has to decide whether a file was "in the table":

| Old file | Home | Note |
|---|---|---|
| `serve.sh`, `wait_ready.sh`, `bench.sh`, `restore_server.sh` | `lib/serve.sh`, `lib/wait_ready.sh`, `lib/bench.sh`, `lib/restore.sh` (E1) | `restore_server.sh`'s `restore_args` file is the config's `RESTORE_ARGS`; `skip_restore` (line 9) has no home: the one restore is the supervisor's |
| `speed_A.sh` | `lib/series.sh` (E1); its arm `case` table is `config/arms.conf`; its `PREFIXTEST` hook is `bin/r9700 prefixtest` (E3.S1) | the done marker is the final record |
| `ram_guard_all.sh`, `wait_quiet.sh`, `disk_gate.sh` | `lib/guard_ram.sh`, `lib/guard_quiet.sh`, `lib/disk_gate.sh` (E1) | — |
| `tune_chunk.sh`, `moe_kernel_ab.sh` | `lib/moe.sh` (E2; one file, two units) | — |
| `merge_b1.py`, `merge_b2.py` (and the earlier `merge_moe.py` of the other repository) | `lib/merge_moe.py` (E2) | one script with arguments |
| `moe_kernel_ab.py` | `lib/moe_kernel_ab.py` (E2) | — |
| `harness.py` | `lib/harness.py` (E1) | — |
| `linear_bench.py`, `linear_bench_graph.py` | `lib/linear_bench.py` (E3.S1; `--timer graph\|eager`) | two files became one; the `/work/speed` path is gone |
| `prefixtest.py` | `lib/prefixtest.py` (E3.S1) | arguments, a pure `summarize` |
| `night.sh`, `night2.sh`, `night3.sh`, `night4.sh`, `night4_extra.sh`, `night5.sh`, `night6.sh`, `night7.sh`, `night8.sh`, `night9.sh`, `night10.sh` | `bin/r9700 run` with a plan file (E3.S2) | every guard they carried is E1's; `night9/10`'s `settled()` (no test container listed, RAM ≥ 24 GB) is NOT kept as a gate: the retry rule waits for the stopped container (E1) and the quiet phase stands between tries; a RAM floor before a start is not measured as useful (checked: § 14.4 lines 793–798 report the gate, not its effect) |
| `resume_AC.sh` | `bin/r9700 run` again with the same plan (E3.S2 decision 8) | a resume is the same command |
| `speed_CB.sh`, `b2.sh` | `moe-tune chunk` (E2) + `linear-bench` (E3.S1) as steps of a plan (E3.S2) | the `fits()` table of `speed_CB.sh` lines 25–26 is dropped: E2.S2 decision 5 |
| `prodcheck.sh` | **dropped** | it measured the operator's PRODUCTION server (TTFT of 8192/32768 prompts, `--save-detailed`) for the § 6.1 stall, without stopping it; the toolkit never measures the production server (PROJECT.md: it stops it only for its own duration), and its prefill measurement is the series' `prefill_run` against a test server. The stall's cause is still unknown (§ 13.3 line 642); a person who needs that check runs `vllm bench serve` by hand, as the script did |
| `e2e_moe.sh` | **does not exist** | checked 2026-11-03: not in the folder, not in the repository's history, not in the results document |
| `coarse_candidates.json`, `benchmark_moe.py` (the other repository) | `config/coarse_candidates.json`, `vendor/benchmark_moe.py` (E2) | — |

**2. The three acceptance templates, NOT RUN, with predictions.** The shape of
`research/ACCEPTANCE_moe_tune_2026-11-02.md`: subject and conditions, the commands, the prediction BEFORE the run,
what would make it wrong, the observed sections empty on purpose, the questions the run answers, what it does not
settle. The operator holds GPU runs: the records are filled by the operator's session when GPU runs are released.

*`ACCEPTANCE_linear_bench_2026-11-03.md`* — `bin/r9700 init`, then `bin/r9700 linear-bench qwen3.6-35b-a3b-gptq
--name acceptance --out acceptance-kernels`. Prediction (§ 12.1, the same seed 0 and the same shapes, random
weights, so only timing noise differs): the container runs about 6 minutes (00:12–00:18, line 514) after its
start; 50 rows; `summary.txt` within a few percent of the § 12.1 table per cell (M 1 default ≈ 2.48 ms; M 6 ≈ 4.91 /
4.79 / 5.89 / ≈ 4.28, change ≈ −13 %; M 16 ≈ 6.93 / 6.69 / 11.67 / ≈ 5.95, ≈ −14 %); `split_ms` above `default_ms` at
every M ≥ 6; the tuned tiles of M 6, 8, 16 near the recorded ones (`16/16/32, 1 warp` for the two QKV input
projections, `16/16/128, 4 warps` for `out_proj+o_proj` and `gate_up`, lines 534–535); every `tuned_maxdiff` 0.0 and
every `split_maxdiff` ≤ 0.0078 (line 538); the operator's server stopped once and restored once; the cache-clear
line names three folders. What would make it wrong: a busy PC (the quiet phase should prevent it; § 6.4); a changed
image (then the dispatch rule of line 1–8 may differ — the record says so); a tile that no longer compiles (a
`skip tile` line in `linear.log`, which is a result). The questions: does the foreground `run --rm --name` appear in
`wslc list` (E2's UNVERIFIED question, answered here too); what `du` prints for `triton-linear`.

*`ACCEPTANCE_prefixtest_2026-11-03.md`* — `bin/r9700 prefixtest qwen3.6-35b-a3b-gptq --name acceptance --out
acceptance-kernels` (arm `base`). Prediction (§ 13.3 lines 635–639, and the measured load of § 6.5): the server is
ready in 3–5 minutes; the two lines: 8k `A cold` ≈ 2.0–2.2 s, hits ≈ 0.46–0.51 s, `A partial` ≈ 0.46–0.49 s; 1k every
value ≈ 0.18–0.22 s; `summary.txt`: `(≈ 4.2x)` at 8192 and `(≈ 1.0x)` at 1024; one stop, one restore. What would
make it wrong: the § 6.1 stall on a cold request (then `A cold` or `B cold` shows ≈ 12–14 s and the ratio ≈ 25x —
a record of the stall, not a failure of the toolkit; the record says which request); a busy PC. The question: does
the stall appear on the first request of a fresh server, as § 6.1 lines 210–212 describe?

*`ACCEPTANCE_run_2026-11-03.md`* — two runs of one two-step plan `acceptance.plan` (`prefixtest
qwen3.6-35b-a3b-gptq --name run-a --out acceptance-kernels`, `linear-bench qwen3.6-35b-a3b-gptq --name run-a --out
acceptance-kernels`). **Run 1, the forced stop:** `machine.env` with `RAM_MIN_MB=65536` (the field's maximum: more
than the PC has free, so the guard fires at its first read after admission) and `MAX_FAILED_TRIES=1`; `bin/r9700
run --check acceptance.plan` first (exit 0), then `bin/r9700 run acceptance.plan`. Prediction: exit 7 within about
one guard tick (15 s) of `admitted`; stderr `r9700: step failed 1 times, last: ram_guard …` then `r9700: run:
stopped at step 1 of 2 (prefixtest …): 7`; `run.txt`: `1 stopped 7`, `2 not-started -`; `wslc list` shows no
`r9700tune-*` container; exactly one `restored` line and the operator's server answers a one-token request
(POST_DEPLOY item 4); `rejected/` holds nothing (the guard stopped before a record was started) or one
`INTERRUPTED` part at the next start. **Run 2, the clean chain:** the two fields back to their defaults; the same
command: prediction: exit 0, `run.txt` two `done`, the two records, one stop of the operator's server (at step 1)
and one restore (at the end), about 12–15 minutes in all. What would make it wrong: a real RAM dip during the server
load of run 2 (§ 6.5: then the guard fires for a true reason, a retry follows, and the record says so); a stop
during the restore. The questions: is the server stopped only once across two steps (the supervisor log's
`admitted` lines and the stop calls); does the second step's admission list no server?

**3. `POST_DEPLOY.md`: the trigger question answered yes, under the cap.** `run` changes what must be true on the
deployed thing: the operator's plan file (outside the repository) must still be a valid plan for the installed
version, and a green build cannot see that file. The file is at twelve. Items 2 and 3 (the 35B and the 27B series
dry runs) are ONE failure class — "a model file does not match this PC" — with two commands; they become one item
whose check runs both dry runs (two commands in one cell, `&&`), and the freed slot takes: *the night plan the
operator keeps is refused by this version: the night is lost at 22:00 with nobody watching* — `cd "$TARGET" &&
bin/r9700 run --check "$R9700_PLAN"` (`$R9700_PLAN` the operator's plan path, named in the stamp line like the
target), auto. The commit says which items merged and why they were the weakest pair (one class, two rows). Item 11
names the three E3 acceptance records beside the two of E1 and E2. Nothing is removed because a test covers it.

**4. No document describes something that does not run.** E3 is the last epic, so after S3 nothing in
`research/architecture.md`, `research/module_tests.md` or `README.md` may say "planned", "E3 will" or "not built
yet" — except the acceptance templates' NOT RUN lines and the acceptance boxes of this plan. `tests/test_static.sh`
gains a scan of the three files for those phrases with its companion (the scan finds the phrase in a fixture file,
so a reformat cannot silence it). The architecture's first paragraph becomes a description of what exists, by
module, not by epic; the epic history stays in the promoted plans.

**5. The family consumer row is merged; the visibility is verified, not assumed.** The row is in
`dew_flow_conventions` since `abac5a8` (#110); S3 reads it at the pinned release and says so in the README's family
paragraph. Whether the GitHub repository is public was not checked here (checked: nothing — this document has no
network); S3 runs `gh repo view --json visibility` and records the answer; if it is private, the DoD box stays open
and the summary says so, because making it public is the operator's decision (A7: the first push's file list was
approved by the operator; the visibility is the same kind of decision).

### Test scenarios

`tests/test_static.sh` (two new functions) and the derived tests that already exist (L18, L-430, the config-doc
test, the catalogue derivation):

1. *No tracked document says a thing is planned.* The scan of decision 4 over `README.md`, `research/architecture.md`
   and `research/module_tests.md` finds nothing; the companion finds the phrase in `tests/fixtures/static/planned.md`.
2. *`research/INPUTS_homes.md` names every file of the old folder.* The test holds the 33 names as a fixture list
   (`tests/fixtures/static/harness_files.txt`, with the commit `c466652` in its first line) and asserts every name is
   a row of the table, and every row's home that is a path in this repository exists (`lib/…`, `config/…`,
   `vendor/…`, `bin/r9700`).
3. *`POST_DEPLOY.md` keeps its shape* (`post-deploy-check.mjs` structural mode: at most twelve items, the stamp, every
   item a command or `manual`).
4. *The acceptance templates exist and say NOT RUN* (a scan: each of the three files has `NOT RUN` in its first
   line and an empty observed section; the companion is the moe template).
5. *The catalogue and the verb list agree* (L18 after every verb landed) and *the exit-code lists agree* (L-430).

### Brief for the Sonnet coder

Read first: this section; `research/ACCEPTANCE_moe_tune_2026-11-02.md` (the template shape); `POST_DEPLOY.md`;
the three documents as S1 and S2 left them; the post-deploy-checks and knowledge-base rules (the stamp is an
observation; shortening drops the caveat — keep every qualifier when you shorten a section).

**1. `research/INPUTS_homes.md`** — the table of decision 1 with the 33 files, the commit, and the two "checked"
notes (`e2e_moe.sh`; `settled()`); `research/README.md` row.

**2. The three templates** — decision 2, the moe template's sections, the predictions as written there (quote the
numbers with their § lines), the observed sections empty with the `(paste …)` prompts; `research/README.md` rows.

**3. `POST_DEPLOY.md`** — decision 3; the stamp line keeps the 2026-11-02 observation and adds `NOT RUN` for the
new item until the operator runs the file; the pipe-in-a-cell rule (`\|`).

**4. The three documents** — the final pass of decision 4; the README's exit-code list unchanged; the architecture's
module map with *Config, Verdict, Quality harness, Adapter, Supervisor and guards, Series and run identity, MoE
tuning, MoE verb, Kernels, Run driver, Tests*; `research/module_tests.md`'s catalogue complete (every verb, every
`lib/*.py` subcommand, every worker mode) with `covered`/`not covered` and the reason.

**5. `tests/test_static.sh`** — the scans of scenarios 1, 2 and 4 with their companions and fixtures.

**6. The checks** — `gh repo view --json visibility`; the consumer row at the pinned release
(`.agents/conventions/README.md` or wherever the consumers table is in that release — find it, do not assume the
path); write both answers into the README's family paragraph and the summary.

**Commands.**

```bash
G='ulimit -u $(( $(ps -L -u $(id -u) --no-headers | wc -l) + 3000 ))'
bash -c "$G; exec nice -n 19 node tests/run.mjs"      # everything
bash tests/check_static.sh
node .agents/conventions/tools/post-deploy-check.mjs
node .agents/conventions/tools/leftovers-check.mjs --repo . --token r9700 --identity "the R9700 vLLM tuning toolkit" --profile node
node .agents/conventions/tools/plan-lifecycle.mjs
```

Report the runner's total, the four tools' exit codes, the visibility answer, and the consumer-row line as read.

---

## GPU acceptance — held

The parent's step 9 for E3 (the `linear-bench` and `prefixtest` runs with the 35B config, the `run` acceptance with
a forced RAM limit) is GPU work. The operator holds GPU runs for now, as for E1's `series` and E2's `moe-tune`
acceptance. S3 writes the three templates with their predictions (decision 2) and marks them NOT RUN; the
operator's session runs them when GPU runs are released, pastes the observed output, and the main session then
closes the acceptance boxes of this document and of the parent and promotes the plans. Until then those boxes stay
open and say so.

## Growth surfaces of these stories

| Surface | Story | Size at the measured volumes | Who retires it | Interrupted |
|---|---|---|---|---|
| Kernels records `<RESULTS_DIR>/kernels-<model>/linear/<name>/` (JSON 50 rows ≈ 20 KB, log ≈ 10 KB, summary and env < 3 KB) | S1 | ≈ 35 KB per run; a night has at most one or two | kept forever under `RESULTS_DIR` (the evidence; the parent's rule: nothing there is deleted) | a cut unit's `.part-` goes to `rejected/` at the next kernels unit start, with its log |
| Prefix records `prefix/<name>/` (two lines, summary, env, `server.log` ≈ 0.3 MB — the parent's figure per server log) | S1 | ≈ 0.3 MB per run | kept forever | as above |
| `rejected/` under the same outdir | S1 | ≈ 35 KB (linear) or ≈ 0.3 MB (prefix) per rejected attempt, at most `MAX_FAILED_TRIES` per invocation | kept forever | — |
| The exchange folder `<WORK_DIR>/r9700/linear/<name>/` (the JSON ≈ 20 KB) and the placed `linear_bench.py`, `prefixtest.py` (≈ 10 KB together) | S1 | bounded by the number of names; under 1 MB per model | `linear/<name>/` is deleted and made again before every run of that name; the placed files are replaced when `lib/` changes | a half-written folder is deleted at the next run |
| The Triton cache `triton-linear` in the cache volume | S1 | **not measured** (checked: the phase C and C2 logs have no size line); 144 tiles × 5 shapes × 4 sweep Ms compiled per run | cleared before every linear unit and in the exit path of every invocation by the ONE hook (decision 5) | a hard-killed supervisor runs no hook: the next unit's start clears it |
| Containers `<prefix>linear-bench-<n>`, `<prefix>prefix-<arm>-<n>` | S1 | one at a time, `--rm` | the guards and the cleanup stop them by prefix (E1); `init` stops leftovers | — |
| The run folder's `plan.txt` and `run.txt` | S2 | < 2 KB per invocation, beside the supervisor's own files (E1's row: one folder per invocation, ≈ 1 MB per night with the log tails) | kept with the run folder, which the toolkit never removes or trims (`research/architecture.md` line 106: collected data, the operator deletes a folder by hand); `restore_dirs_prune` (E1) is for the restore folders of the state directory only, not for run folders | — |
| Test fixtures (tracked) | S1, S2, S3 | ≈ 25 KB (the JSON, the table, the 16 lines, the plan files, the static fixtures) | kept; replaced only by a deliberate change | — |

## Build order

1. PR #3 (E2) merges; `feat/e3` merges `main`.
2. E3.S1 — Sonnet codes the S1 section, pure parts first (LB and PT green before any bash); Opus reviews; Sonnet
   fixes.
3. E3.S2 — Sonnet codes the S2 section; Opus reviews; Sonnet fixes.
4. E3.S3 — Sonnet writes the S3 section; Opus reviews; Sonnet fixes. The three templates are NOT RUN; the visibility
   answer is recorded.
5. One coai code round covers the whole epic (as E1's A6 and E2 did).
6. After the operator's session runs the three acceptance records: the main session closes the boxes, promotes the
   parent and the three stories documents together (planning-docs: the `git mv` last), and records the deviations.

## Definition of Done (E3, by story)

- [ ] S1: LB1–LB7, PT1–PT9, KW1–KW13 and KV1–KV8 pass in CI through `node tests/run.mjs`; LB1 reproduces the § 12.1
      table from the published JSON; PT6 reproduces the ratios of the raw file; KW3 and KW9 reject a duplicate pair or
      line that a bare count would pass; KW6 shows a RAM stop during a linear unit leaves no prefixed container and
      the hook clears three folders; KW10 refuses a reused `--name` of another experiment; KW13 stops a server that
      did not become ready before the worker exits; the two fields are in the loader, the example, both model files
      and `research/module_config.md`; `linear-bench` refuses the 27B file with the reason; E2's T17 and U1 pass
      unchanged.
- [ ] S2: R1–R21 pass; R2 is the parent's done-when (a RAM stop in step two: the worker group killed, every prefixed
      container stopped, one restore, the exit code is the stopped step's and the line names it); R3 is the parent's
      second done-when (exit 3 waited out, not counted); R8 shows four quiet steps cost one stop and one restore; R18
      shows the cap is reached only by real stops and a refused admission launches nothing and never prevents the
      final restore; R17 shows a raw worker 4 or 5 never surfaces as a lock or restore failure; R19 shows a final
      restore failure returns 5 with the step's own outcome kept; R20 shows a signal before the first step and
      between steps; E1's L12 and the exit-8 guard test were rewritten to the new charge rule and pass; `run` adds no
      exit code (L-430 unchanged).
- [ ] S3: every file of the old harness folder is in `research/INPUTS_homes.md` with a home or a reason (the static
      test); the three acceptance templates exist in `research/`, marked NOT RUN, with their predictions; `README.md`,
      `research/architecture.md`, `research/module_tests.md` and `POST_DEPLOY.md` are complete and describe nothing
      that does not run (the scan); the consumer row is confirmed at the pinned release; the visibility was read and
      recorded — public, or the box stays open with the operator's decision pending.
- [ ] The parent's done-when that needs the GPU (`linear-bench` and `prefixtest` write their result files on the
      R9700 with the 35B config; the `run` acceptance with the forced RAM limit shows a clean stop and one restore;
      all three recorded in `research/`): OPEN until the operator's session runs the templates; this box says so.
- [ ] Every story: no tracked file holds a personal path, account or machine name (the static check is green);
      every new flow is in `research/module_tests.md` with what it does not prove; every test brief carried the
      process-cap and shim rules; `plan-lifecycle.mjs` is clean; the parent's E3 section links this document and
      `todo/README.md` has its row.

## Deviations

What shipped differently from this document (2026-11-03).

- **33 names, not 33 files:** the folder holds 31; `wait_ready.sh` and `e2e_moe.sh` are rows that say what was checked (S3 decision 1). The night8 row says the toolkit has no switch for the quiet gate: the fields are `QUIET_LOAD_MAX` and `QUIET_BUSY_PATTERN`, and `R9700_QUIET_CHECKS` is a test knob only (S3 review).
- **After the S2 review:** a bound on exit-3 repeats per step (3 x `MAX_FAILED_TRIES`, then exit 8 and `r9700: <step> waited <n> times (worker exit 3), limit <m>`; knob `R9700_MAX_WAIT_REPEATS`), `machine.env` hashed at the start of a chain and a change refused at the next step (exit 2), a signal never overwrites `done` or `stopped`, one read of the plan (its hash is of the bytes parsed). The hold knob `R9700_TEST_RUN_HOLD_AT` takes `<k>` or `<k>-end`.
- **S3 files:** the document checks are in the new `tests/test_docs.sh` (S3 named `tests/test_static.sh`, which keeps only the unfinished-work scan); that scan is `check_static.sh --unfinished`, covers four documents, and its fixture is `tests/fixtures/static/unfinished.md`. The template check holds a record to its prompts only while its title says NOT RUN, so a filled record does not turn CI red, and then refuses a record that claims a run with a placeholder left.
- **`POST_DEPLOY.md`:** the freed slot is item 3 (not a renumbered 12), so items 4 to 12 keep their numbers; item 5 reads the container prefix from `machine.env`.
- **The run template's wall time is 35 to 40 minutes**, not "about 12 to 15": each step waits for three quiet checks 300 s apart.
- **The acceptance boxes of this document are open** (the three templates and `moe-tune`'s are NOT RUN): they moved to [PLAN_r9700_gpu_acceptance.md](../todo/PLAN_r9700_gpu_acceptance.md). Everything else was merged (PR #6) and the consumer row (`dew_flow_conventions` PR #110) and the visibility (`PUBLIC`) were read on 2026-11-03.
