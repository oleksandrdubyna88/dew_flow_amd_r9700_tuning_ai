# Acceptance of `bin/r9700 run` on the R9700 — prepared 2026-11-03, RUN 2026-11-03 (quiet gate off)

The flow that CI cannot run (`research/module_tests.md`): a chain of real steps over a real server, a real RAM guard and a real restore. The operator's session
runs it before a release and pastes the output below. It was run on 2026-11-03 (the sections below); the prediction section is as it was written before the run, unchanged. It forces the RAM limit instead of waiting for a real dip (results § 6.5: a real dip comes only during a model load).

## Subject and conditions (fill in at the run)

| | |
|---|---|
| Subject (commit of this repository) | `d983327` (main after #8) |
| Harness | `bin/r9700` (verbs `init`, `run`) |
| Date of the run, machine | 2026-11-03 20:15–20:36 CET (`--check` 20:15, run 1 20:16–20:20, run 2 20:20–20:35), the R9700 PC |
| The plan | `acceptance.plan`, the operator's own file kept OUTSIDE the repository: `prefixtest qwen3.6-35b-a3b-gptq --name run-a --out acceptance-kernels`, then `linear-bench qwen3.6-35b-a3b-gptq --name run-a --out acceptance-kernels` (the run folders' `plan.txt` equal it byte for byte, checked with `cmp`) |
| Model file | `models/qwen3.6-35b-a3b-gptq.env`, unedited |
| Pinned, not varied | the image tag, the model file, the two verbs' default options |
| Varied | run 1: `RAM_MIN_MB=65536` (the field's maximum: more than the PC has free, so the guard fires at its first read after admission) and `MAX_FAILED_TRIES=1` in `machine.env` (the two lines were appended for the run and the file was restored after it); run 2: both fields back to their defaults |
| Machine file | the operator's `machine.env` (not copied here: it holds the machine's paths) |
| Compared with | `research/ACCEPTANCE_prefixtest_2026-11-03.md` and `research/ACCEPTANCE_linear_bench_2026-11-03.md` (the same two steps, one by one) and `POST_DEPLOY.md` item 4 (the operator's server answers after a run) |
| Quiet gate | OFF by the operator's decision ("don't wait"): every command had `R9700_QUIET_CHECKS=1` and `QUIET_LOAD_MAX=16` was in `machine.env`. So the quiet waits of about 10 minutes that the prediction counts (before run 1's admission and before each step of run 2) did not take place: each admission waited for ONE read |

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

`init` was run once, before the first unit of the day (19:25 CET); `--check` at 20:15 CET.

```
init: config: ok
init: results dir: ok
init: state dir: ok
init: wslc: ok
init: vllm: running
init: leftover containers: none
init: ram telemetry: ok (32058 MB)
init: disk telemetry: ok (record 4566)
rc=0
--- bin/r9700 run acceptance.plan --check
run: step 1: ok (prefixtest qwen3.6-35b-a3b-gptq --name run-a --out acceptance-kernels)
run: step 2: ok (linear-bench qwen3.6-35b-a3b-gptq --name run-a --out acceptance-kernels)
run: at most 2 stops of the operator's server if every step is admitted after a busy wait; MAX_SERVER_STOPS=3
rc=0
```

## Observed: run 1, the forced stop

Command output (`start …` and `end …` are the operator's session's time stamps, in CET; the other times are UTC, `Z`), then `run.txt` of the run folder `runs/20261103T191602Z-1393350`:

```
start 2026-11-03 20:16:01
run: step 1 of 2 (prefixtest qwen3.6-35b-a3b-gptq --name run-a --out acceptance-kernels)
kernels: outdir <RESULTS_DIR>/acceptance-kernels
2026-11-03T19:16:02Z coai-exp processes=0 load=2.85 quiet-checks=1/1
2026-11-03T19:16:02Z QUIET
2026-11-03T19:16:05Z disk gate: baseline 4566
2026-11-03T19:16:09Z stopped the operator's server (stop 1 of 3)
2026-11-03T19:16:09Z admitted
2026-11-03T19:16:09Z worker started: session 1393914, start ticks 3665950
2026-11-03T19:16:24Z worker ended rc=143
2026-11-03T19:16:25Z failed try 1 of 1: ram_guard available 35664 MB < 65536 MB
r9700: step failed 1 times, last: ram_guard available 35664 MB < 65536 MB
r9700: run: stopped at step 1 of 2 (prefixtest qwen3.6-35b-a3b-gptq --name run-a --out acceptance-kernels): 7
restore: starting vllm with <RESTORE_SCRIPT_WIN>
vLLM patches active from <the start script's patch folder>: auto_gptq.py, gptq_utils.py, moe\ tuned config (see README.md there)
70b4c267d118a2d8b4993a66bb5de2cc43010a5b66907544cc1999a52d131e64
2026-11-03T19:20:29Z restored
rc=7
end 2026-11-03 20:20:30
--- run.txt
PLAN=<the plan file, kept outside the repository> SHA256=14dd75ec9a89a0748d99b2fb3d6c969de45d4b08f09f33b81d5e006399b31b0a STEPS=2
1 stopped 7 prefixtest qwen3.6-35b-a3b-gptq --name run-a --out acceptance-kernels
2 not-started - linear-bench qwen3.6-35b-a3b-gptq --name run-a --out acceptance-kernels
```

The supervisor log of the run folder, the RAM guard log of step 1, the step's `worker.log`, the outcome of step 1, the files of its `guard/` folder (`stat -c '%s  %n'`), and the `rejected/` entry that the NEXT start of a kernels unit made (it is in run 2's step 1, `steps/1.worker.log`, and in `acceptance-kernels/rejected/`):

```
2026-11-03T19:16:02Z coai-exp processes=0 load=2.85 quiet-checks=1/1
2026-11-03T19:16:02Z QUIET
2026-11-03T19:16:05Z disk gate: baseline 4566
2026-11-03T19:16:09Z stopped the operator's server (stop 1 of 3)
2026-11-03T19:16:09Z admitted
2026-11-03T19:16:09Z worker started: session 1393914, start ticks 3665950
2026-11-03T19:16:24Z worker ended rc=143
2026-11-03T19:16:25Z failed try 1 of 1: ram_guard available 35664 MB < 65536 MB
2026-11-03T19:16:25Z r9700: step failed 1 times, last: ram_guard available 35664 MB < 65536 MB
2026-11-03T19:16:25Z r9700: run: stopped at step 1 of 2 (prefixtest qwen3.6-35b-a3b-gptq --name run-a --out acceptance-kernels): 7
2026-11-03T19:20:29Z restored
--- steps/1.ram_guard.log
2026-11-03T19:16:11Z ram_guard: available 35664 MB < 65536 MB; stopping the step
--- steps/1.worker.log
=== 2026-11-03T19:16:09Z prefix run-a (arm base, lens 8192 1024, tail 64)
05fe136a0556f9c28c136233e99a9f36d10274fe06687cdd251c98fa6b4aac3d
--- steps/1.outcome
KIND=ram_guard
RC=
DETAIL=available 35664 MB < 65536 MB
ENDED_AT=2026-11-03T19:16:11Z
--- guard/
0  <RESULTS_DIR>/runs/20261103T191602Z-1393350/guard/20261103T191611Z-r9700tune-prefix-base-1.tail.log
--- <RESULTS_DIR>/acceptance-kernels/rejected/prefix-run-a-20261103T192051Z/reason
INTERRUPTED: run-a.part-20261103T191602Z-1393350 was left by an earlier worker that did not finish it
```

`wslc list` was NOT taken after the run. The guard's own file is the evidence about the container: the guard saves the log tail of every listed container whose name starts with the prefix, BEFORE it stops it, and `guard/20261103T191611Z-r9700tune-prefix-base-1.tail.log` (empty: the server had only just started) is that file, so `wslc list` did show the detached server `r9700tune-prefix-base-1` and the stop by name raised no `did not stop` line. The container's name was started again by run 2 at 19:20:51Z without a name clash.

Observed against predicted:

| | predicted | observed | held? |
|---|---|---|---|
| minutes to `admitted` | about 10 (three quiet checks 300 s apart) | 7 s: `QUIET` at 19:16:02Z, `stopped the operator's server (stop 1 of 3)` at 19:16:09Z, `admitted` at 19:16:09Z (one quiet check, load 2.85) | **no** (the quiet gate was off) |
| minutes from `admitted` to the stop | within about one guard tick (15 s) | the guard fired at 19:16:11Z, 2 s after the worker start (its first read: `available 35664 MB < 65536 MB`); `worker ended rc=143` at 19:16:24Z, 15 s after `admitted` | yes |
| exit code | 7 | 7 (`rc=7`) | yes |
| the two stderr lines | `r9700: step failed 1 times, last: ram_guard available <mb> MB < 65536 MB`, then `r9700: run: stopped at step 1 of 2 (prefixtest …): 7` | `r9700: step failed 1 times, last: ram_guard available 35664 MB < 65536 MB`, then `r9700: run: stopped at step 1 of 2 (prefixtest qwen3.6-35b-a3b-gptq --name run-a --out acceptance-kernels): 7` | yes |
| `run.txt` | `1 stopped 7 …`, `2 not-started - …`, `plan.txt` byte for byte | exactly those two lines; `plan.txt` equals the plan file (`cmp`) | yes |
| containers and sessions left | none | the guard stopped the listed prefixed container by name without error (above); no `wslc list` and no process listing after the run | indirect |
| `restored` lines | exactly one | one, at 19:20:29Z (4 min 4 s after the stop of the step; the restore waits for the server to answer) | yes |
| the one-token request (`POST_DEPLOY.md` item 4) | answers | NOT sent: nobody sent a request to the operator's server in this session. The `restored` line is printed after the restore's own readiness probe (`models` and a one-token `completion`), which is not the operator's own request | not observed |
| `acceptance-kernels/` | no final prefix record; `rejected/` empty, or one `INTERRUPTED` part at the next start | no `prefix/run-a/` after run 1; the part `run-a.part-20261103T191602Z-1393350` was moved to `rejected/prefix-run-a-20261103T192051Z` at run 2's step 1 with the reason `INTERRUPTED: … was left by an earlier worker that did not finish it` | yes (the second alternative) |

## Observed: run 2, the clean chain

Command output, then `run.txt` of the run folder `runs/20261103T192044Z-1397423`:

```
start 2026-11-03 20:20:44
run: step 1 of 2 (prefixtest qwen3.6-35b-a3b-gptq --name run-a --out acceptance-kernels)
kernels: outdir <RESULTS_DIR>/acceptance-kernels
2026-11-03T19:20:45Z coai-exp processes=0 load=0.79 quiet-checks=1/1
2026-11-03T19:20:45Z QUIET
2026-11-03T19:20:46Z disk gate: baseline 4566
2026-11-03T19:20:51Z stopped the operator's server (stop 1 of 3)
2026-11-03T19:20:51Z admitted
2026-11-03T19:20:51Z worker started: session 1398130, start ticks 3694089
2026-11-03T19:24:51Z worker ended rc=0
recorded prefix/run-a
PREFIX run-a len=8192: cold 2.01 s, hit 0.46 s (4.4x), partial 0.46 s
PREFIX run-a len=1024: cold 0.19 s, hit 0.18 s (1.0x), partial 0.18 s
run: step 2 of 2 (linear-bench qwen3.6-35b-a3b-gptq --name run-a --out acceptance-kernels)
kernels: outdir <RESULTS_DIR>/acceptance-kernels
2026-11-03T19:24:51Z coai-exp processes=0 load=0.45 quiet-checks=1/1
2026-11-03T19:24:51Z QUIET
2026-11-03T19:24:52Z disk gate: OK: no new disk event (newest 4566)
2026-11-03T19:24:52Z admitted
2026-11-03T19:24:52Z worker started: session 1401665, start ticks 3718259
2026-11-03T19:31:33Z worker ended rc=0
recorded linear/run-a
M  default_ms  triton_default_ms  split_ms  tuned_ms  change
1  2.40  4.64  2.68  -  -
2  2.43  4.69  2.71  -  -
3  2.61  4.58  2.93  -  -
4  2.91  4.54  3.21  -  -
5  3.24  4.48  3.50  -  -
6  4.41  4.43  5.70  4.04  -9 %
8  4.98  4.96  5.98  3.98  -20 %
10  5.19  5.04  6.62  -  -
12  4.49  4.47  8.69  4.15  -8 %
16  5.93  5.84  11.41  4.97  -16 %
tiles M=6: linear_attn.in_proj_qkvz=[16, 32, 64, 2, 2] linear_attn.out_proj+self_attn.o_proj=[16, 16, 128, 4, null] self_attn.qkv_proj=[16, 16, 32, 1, 2] shared_expert.gate_up_proj=[16, 16, 128, 4, 1] shared_expert.down_proj=[16, 16, 128, 4, null]
tiles M=8: linear_attn.in_proj_qkvz=[16, 16, 32, 1, 2] linear_attn.out_proj+self_attn.o_proj=[16, 16, 128, 4, null] self_attn.qkv_proj=[16, 16, 32, 1, 2] shared_expert.gate_up_proj=[16, 16, 128, 4, 1] shared_expert.down_proj=[16, 16, 64, 4, null]
tiles M=12: linear_attn.in_proj_qkvz=[16, 16, 32, 1, 2] linear_attn.out_proj+self_attn.o_proj=[16, 16, 128, 4, 1] self_attn.qkv_proj=[16, 16, 32, 1, null] shared_expert.gate_up_proj=[16, 16, 128, 4, 1] shared_expert.down_proj=[16, 16, 32, 1, 2]
tiles M=16: linear_attn.in_proj_qkvz=[16, 64, 128, 4, 2] linear_attn.out_proj+self_attn.o_proj=[16, 16, 32, 1, 2] self_attn.qkv_proj=[16, 16, 32, 1, 2] shared_expert.gate_up_proj=[16, 16, 128, 4, 1] shared_expert.down_proj=[16, 16, 32, 1, 2]
2026-11-03T19:31:34Z cleanup hook: moe_cache_clear rc=0
restore: starting vllm with <RESTORE_SCRIPT_WIN>
vLLM patches active from <the start script's patch folder>: auto_gptq.py, gptq_utils.py, moe\ tuned config (see README.md there)
2b0cd930a24bdc9c815aaf41e3bb81f91f03173c7bb80c1ba7cc442417b8346f
2026-11-03T19:35:38Z restored
rc=0
end 2026-11-03 20:35:38
--- run.txt
PLAN=<the plan file, kept outside the repository> SHA256=14dd75ec9a89a0748d99b2fb3d6c969de45d4b08f09f33b81d5e006399b31b0a STEPS=2
1 done 0 prefixtest qwen3.6-35b-a3b-gptq --name run-a --out acceptance-kernels
2 done 0 linear-bench qwen3.6-35b-a3b-gptq --name run-a --out acceptance-kernels
```

The supervisor log of the run folder, the RAM guard logs of the two steps, the step logs, the exit-path hook log, and the two records (`stat -c '%s  %n'`):

```
2026-11-03T19:20:45Z coai-exp processes=0 load=0.79 quiet-checks=1/1
2026-11-03T19:20:45Z QUIET
2026-11-03T19:20:46Z disk gate: baseline 4566
2026-11-03T19:20:51Z stopped the operator's server (stop 1 of 3)
2026-11-03T19:20:51Z admitted
2026-11-03T19:20:51Z worker started: session 1398130, start ticks 3694089
2026-11-03T19:24:51Z worker ended rc=0
2026-11-03T19:24:51Z coai-exp processes=0 load=0.45 quiet-checks=1/1
2026-11-03T19:24:51Z QUIET
2026-11-03T19:24:52Z disk gate: OK: no new disk event (newest 4566)
2026-11-03T19:24:52Z admitted
2026-11-03T19:24:52Z worker started: session 1401665, start ticks 3718259
2026-11-03T19:31:33Z worker ended rc=0
2026-11-03T19:31:34Z cleanup hook: moe_cache_clear rc=0
2026-11-03T19:35:38Z restored
--- steps/1.ram_guard.log
2026-11-03T19:20:53Z available RAM 37053 MB
--- steps/2.ram_guard.log
2026-11-03T19:24:54Z available RAM 37110 MB
2026-11-03T19:30:34Z available RAM 38656 MB
--- steps/1.worker.log
kernels: run-a.part-20261103T191602Z-1393350 moved to rejected/prefix-run-a-20261103T192051Z
=== 2026-11-03T19:20:51Z prefix run-a (arm base, lens 8192 1024, tail 64)
39ba270bcbef58aa480ee8fb514618acbc781acf5acc579f6d4ef8a7fd661a99
READY (waited 222 s here)
recorded prefix/run-a
--- steps/2.worker.log
=== 2026-11-03T19:24:53Z linear run-a (graph, ms 1 2 3 4 5 6 8 10 12 16, sweep 6 8 12 16)
cache clear: running (ceiling 90 s)
cache before clear: 
recorded linear/run-a
--- guard/cleanup-hook.log
cache clear: running (ceiling 90 s)
cache before clear: 135M /root/.cache/vllm/triton-linear
--- the two records
1816  <RESULTS_DIR>/acceptance-kernels/prefix/run-a/prefix.env
208  <RESULTS_DIR>/acceptance-kernels/prefix/run-a/prefixtest.txt
35737  <RESULTS_DIR>/acceptance-kernels/prefix/run-a/server.log
140  <RESULTS_DIR>/acceptance-kernels/prefix/run-a/summary.txt
1431  <RESULTS_DIR>/acceptance-kernels/linear/run-a/linear.env
13833  <RESULTS_DIR>/acceptance-kernels/linear/run-a/linear.log
14152  <RESULTS_DIR>/acceptance-kernels/linear/run-a/linear_bench.json
1333  <RESULTS_DIR>/acceptance-kernels/linear/run-a/summary.txt
```

Observed against predicted:

| | predicted | observed | held? |
|---|---|---|---|
| exit code | 0 | `rc=0` | yes |
| the two `done` lines | `1 done 0`, `2 done 0` | exactly those, and the two records `prefix/run-a/` and `linear/run-a/` | yes |
| stops and restores of the operator's server | one stop (step 1), one restore (the end) | one `stopped the operator's server (stop 1 of 3)` (19:20:51Z), two `admitted`, one `restored` (19:35:38Z); step 2's admission has no stop line | yes |
| the wall time | about 35 to 40 minutes | 14 min 54 s (`start` 20:20:44, `end` 20:35:38 CET): the prefix step 4 min 0 s, the linear step 6 min 41 s, the restore 4 min 4 s, and no quiet waits (the gate was off). Without the two quiet waits, the prediction's step times (6 to 8 minutes and about 6) are 12 to 14 minutes before the restore (the E3 plan said 12 to 15); observed before the restore: 10 min 41 s (19:20:51Z to 19:31:34Z) | **no** (the quiet gate was off; the prefix step was faster than predicted, 4 min against 6 to 8; the linear step slightly slower, 6 min 41 s against about 6) |
| a real RAM dip in the model load | possible: a guard stop and a retry | none: no guard stop, no failed try, the one `ram_guard.log` read of step 1 is 37053 MB | not seen |

The two steps agree with their own records. Step 1's prefix line: 8192 `A cold` 2.09 s, hits 0.46 s, ratio 4.4x; 1024 all 0.18 to 0.19 s, ratio 1.0x (inside the prediction of `research/ACCEPTANCE_prefixtest_2026-11-03.md`). Step 2's linear table is the one in `linear/run-a/summary.txt`: M 6 4.41 / 4.43 / 5.70 / 4.04 (-9 %), M 12 change -8 %, M 16 5.93 / 5.84 / 11.41 / 4.97 (-16 %), against 4.51 / 4.49 / 5.74 / 4.12 (-9 %), -5 % and 6.21 / 6.25 / 11.34 / 5.13 (-17 %) of the single run: the same difference as between the two runs of the same unit.

## Questions the run answers

- Is the operator's server stopped only once across two steps? Answer: yes. The supervisor log of run 2 has one `stopped the operator's server (stop 1 of 3)` line, two `admitted` lines and one `restored` line.
- Does the second step's admission list no server? Answer: inferred, not printed: the second admission's log is `disk gate: OK: no new disk event (newest 4566)` and `admitted` (19:24:52Z) with no `stopped the operator's server` line between, and the stop count stays at 1 of 3. The code charges a stop only when the server is listed, so the listing had no server. The log has no line that says "not listed".
- Does a forced RAM stop leave a clean state: no container, no session, one restore, no marker? Answer: one restore, yes (19:20:29Z, status `failed`). The container: the guard stopped the listed prefixed container by name without a `did not stop` line (above). Not checked directly: no `wslc list` after the run, no look at the state folder, and `POST_DEPLOY.md` items 5 to 7 were not run at that moment. Indirect: run 2 started 15 s after `restored`, nothing in its log shows a recovery restore (the code removes the marker before it logs `restored`), and it used the same container name without a clash.
- Does the step that follows a quiet wait start after exactly the three quiet checks of the log? Answer: not tested. The quiet gate was set to ONE check, so the log shows `quiet-checks=1/1` before each of the three admissions of the two runs. The rule of three checks 300 s apart was not run on the PC today.

## What this record does not settle

Two steps, one model, one image, two runs. It forces the RAM limit, so it says the guard stops the chain cleanly; it does not say what a real dip does to a night, and it does not exercise the deadline, `MAX_SERVER_STOPS` or a
busy-wait restore between steps (the stub tests R4, R18 and R19 of `tests/test_run.sh` do). It does not run `series`, `moe-tune` or a plan of more than two steps. It also does not show the quiet wait with three checks (the gate was off), nor the one-token request to the operator's own server after a run (nobody sent it).
