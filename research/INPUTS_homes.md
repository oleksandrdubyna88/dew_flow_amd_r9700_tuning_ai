# Inputs — the home of every script of the old harness folder

The scripts that the R9700 speed-options work (2026-10-25 to 2026-11-01) was run with are published in the folder
`research/vllm-r9700-speed-options/harness/` of the repository `dew_flow_benchmark`. This file reads that folder at commit
`c466652` (date of the reading: 2026-11-03) and gives every name in it a home in this toolkit, or says why it has none. It is the
record that the parent plan's definition of done asks for ("every script listed in *Inputs* has a home in `lib/`, `vendor/` or `bin/`, or is named as dropped with the reason").

**33 names.** The folder holds 31 files at that commit (`git ls-tree`). Two more names are in the plans and not in the folder: `wait_ready.sh` (the parent plan's *Inputs* table lists it;
`serve.sh` calls it) and `e2e_moe.sh` (the E3 brief names it). Both are rows below, with what was checked. The list of the 33 names is `tests/fixtures/static/harness_files.txt`; `tests/test_docs.sh`
fails when a name has no row here, when a row has no home and no reason, or when a home that is a path of this repository does not exist (or names a verb that `bin/r9700 commands` does not print).

How to read a row: the first cell is the old file; the second is its home (`lib/…`, `config/…`, `vendor/…`, `bin/r9700 <verb>`) or `**dropped**` or `**does not exist**`; the third says what changed, and every
word that matters when a person asks "where did that go". No old path, account or machine name was copied into this repository: every path, image tag and start script of the old scripts is a field of `machine.env` or of a model file now.

## The harness folder

| Old file | Home | What changed |
|---|---|---|
| `serve.sh` | `lib/serve.sh` | the serve command is built from the machine file, the model file and the arm table (`serve_start`, also `--print`); nothing is typed in the script. It calls the readiness wait below |
| `wait_ready.sh` | `lib/wait_ready.sh` | NOT in the harness folder at `c466652`: `serve.sh` (line 22) calls it and the parent plan lists it (14 lines). Checked 2026-11-03: `git grep wait_ready` at that commit finds only `serve.sh`; the file is in no commit of that repository (`git log --all`). NOT checked: the operator's session scratchpad of the nights. The home is the toolkit's own readiness wait, built from `serve.sh`'s call and the results document |
| `bench.sh` | `lib/bench.sh` | the six measured `vllm bench serve` runs and the prefill runs; the numbers of the run are the model file's |
| `restore_server.sh` | `lib/restore.sh` | the start script and its arguments are `machine.env` (`RESTORE_ARGS`); the restore is idempotent and waits for the server to answer a one-token request. `skip_restore` (line 9) has no home: the ONE restore is the supervisor's, at every exit path (the restore skipped as "a planned restart" left production down from 17:28 to 18:07, results § 14.4 lines 781-783) |
| `speed_A.sh` | `lib/series.sh` | the arm `case` table is `config/arms.conf`; the `PREFIXTEST` hook is the verb `bin/r9700 prefixtest`; the done marker is the final arm-round record (`rounds/<arm>-<round>/`), written by one rename only when the record is complete |
| `ram_guard_all.sh` | `lib/guard_ram.sh` | stops the worker's whole session and every prefixed container, not only the top script |
| `wait_quiet.sh` | `lib/guard_quiet.sh` | the quiet check, repeated `R9700_QUIET_CHECKS` times; an unreadable load is "not quiet" |
| `disk_gate.sh` | `lib/disk_gate.sh` | a baseline at the first admission, a check at every later one |
| `tune_chunk.sh` | `lib/moe.sh` | the chunk unit (one of the two units of that file); the record is made only when the JSON passes `lib/merge_moe.py check` |
| `moe_kernel_ab.sh` | `lib/moe.sh` | the A/B unit (the other unit of that file), proven to load the activated file |
| `merge_b1.py` | `lib/merge_moe.py` | the three merge scripts that differed only in their chunk list and file name are one script with arguments; a merge writes a NEW record and replaces nothing |
| `merge_b2.py` | `lib/merge_moe.py` | the same one script |
| `moe_kernel_ab.py` | `lib/moe_kernel_ab.py` | `decide`: the table, the config lines and the decision of the six logs |
| `harness.py` | `lib/harness.py` | the quality collection of round 1 (20 greedy prompts, GSM8K-200) and the two comparisons |
| `linear_bench.py` | `lib/linear_bench.py` | the shapes are the model file's `LINEAR_SHAPES`; the Ms and the sweep Ms are options; the arguments are checked before torch is imported |
| `linear_bench_graph.py` | `lib/linear_bench.py` | the two files are one: the CUDA-graph timer is `--timer graph` (the default), the eager timer `--timer eager`; the `/work/speed` path of the second file is gone |
| `prefixtest.py` | `lib/prefixtest.py` | arguments in place of positional words, a pure `summarize`, a `check` of the result file; the verb is `bin/r9700 prefixtest` |
| `night.sh` | `bin/r9700 run` | the first night: `prodcheck.sh`, a quiet wait, `speed_A.sh`, `speed_CB.sh`, a TERM to one pid only. Now a plan file; every guard it lacked is the supervisor's |
| `night2.sh` | `bin/r9700 run` | phase C, then a loop that took the A/B when quiet and when it fitted, else the next chunk: a plan file of steps; the fit is the worker's own check |
| `night3.sh` | `bin/r9700 run` | the same shape as `night2.sh` with the graph-timer linear benchmark: `linear-bench` is a step |
| `night4.sh` | `bin/r9700 run` | the kernel A/B, `fb1` added when the A/B said faster, the A/B loop: steps of a plan; "added when faster" is the operator's reading of `decision.txt`, not a rule of the chain |
| `night4_extra.sh` | `bin/r9700 run` | one series step (`speed_A.sh speedO7 o7ref o7` with the prefix check off): one `series` line |
| `night5.sh` | `bin/r9700 run` | the pattern of the later nights: each step in its own process group, the RAM guard and the deadline stopping the group, exit 3 = not quiet (wait, no try counted), 6 failed tries, ONE restore; all of it is built into the supervisor, and the `SERIES` array is the plan file |
| `night6.sh` | `bin/r9700 run` | one series step |
| `night7.sh` | `bin/r9700 run` | two series steps; the per-series environment words of its `SERIES` array (model directory, served name, sequences, length, prefill lengths) are the fields of the model file now (`models/qwen3.8-27b-awq.env`) |
| `night8.sh` | `bin/r9700 run` | as `night7.sh`, with "no quiet gate" (line 22: the operator's decision for that night). **Dropped on purpose:** the toolkit has no switch that turns the quiet gate off. The fields are `QUIET_LOAD_MAX` and `QUIET_BUSY_PATTERN`; the practical way to let a run go on a busier PC is to raise `QUIET_LOAD_MAX` in `machine.env` (the acceptance run of 2026-11-02 used `QUIET_LOAD_MAX=16`, with the test knob `R9700_QUIET_CHECKS=1`, which is environment only and never a gate switch) |
| `night9.sh` | `bin/r9700 run` | one series step; its `settled()` wait is NOT kept as a gate (below) |
| `night10.sh` | `bin/r9700 run` | as `night9.sh` |
| `resume_AC.sh` | `bin/r9700 run` | a resume is the same plan run again: every step skips what it recorded |
| `speed_CB.sh` | `bin/r9700 moe-tune chunk`, `bin/r9700 linear-bench` | phase C (the linear benchmark) and the B chunks as steps of a plan. The `fits()` deadline test of lines 25-26 is dropped: the worker's fit check and the run's one deadline take its place (E2.S2 decision 5) |
| `b2.sh` | `bin/r9700 moe-tune` | `chunk`, the cache clear (the exit-path hook of `lib/moe.sh`), `merge` and `ab` of one night; `activate` is the explicit step between the last two, which the script did by giving the A/B two folders. The chain refuses `merge` and `activate` as steps of a plan: they change what a server reads, so the operator runs them |
| `prodcheck.sh` | **dropped** | it measured the operator's PRODUCTION server (the TTFT of 8192 and 32768 token prompts with `--save-detailed`) for the stall of results § 6.1, without stopping it. The toolkit never measures the production server (it stops it only for its own duration and restores it), and its prefill measurement is the series' `prefill_run` against a test server. The cause of the stall is still unknown (results § 13.3 line 642); a person who needs that check runs `vllm bench serve` against the server by hand, as the script did |
| `e2e_moe.sh` | **does not exist** | the E3 brief names it. Checked 2026-11-03: not in the harness folder at `c466652`, not in the `dew_flow_benchmark` working tree, not in that repository's history (`git log --all` finds no file of that name), not in the results document. NOT checked: the operator's session scratchpad and other repositories. There was nothing to place |

## Inputs that are not in the harness folder

The parent plan's *Inputs* table also lists three files of the earlier MoE tuning work (the other repository's work of 2026-10-26 to 2026-10-27).

| Old file | Home | What changed |
|---|---|---|
| `benchmark_moe.py` | `vendor/benchmark_moe.py` | vLLM's benchmark (Apache-2.0, header kept) plus three marked local hooks; `vendor/README.md` has the upstream commit, the hashes and the diff |
| `coarse_candidates.json` | `config/coarse_candidates.json` | the 82 candidates of the coarse search, pinned by its hash in a test |
| `merge_moe.py` | `lib/merge_moe.py` | the earlier merge script of that work; the same one script as the two `merge_b*.py` rows above |

## Two decisions that rest on a check

- **`settled()` of `night9.sh` and `night10.sh` is not kept.** It waited up to 20 minutes before a start until no test container was listed and the available RAM was at least 24 GB. The toolkit waits for the
  stopped container before a retry (the supervisor stops the containers of a failed try first) and the quiet wait stands between tries; a RAM floor before a start is not measured as useful. Checked: results § 14.4
  lines 793-798 report the gate, not its effect. NOT checked: a run with and without the floor. If one is measured, the plan file or the supervisor gets it, not a script.
- **`prodcheck.sh` is dropped, not lost.** Its question (a stall of 12 to 14 seconds on a cold 8k request) is the one `bin/r9700 prefixtest` asks of a test server; the acceptance template of that verb
  (`ACCEPTANCE_prefixtest_2026-11-03.md`) says whether the stall shows on a fresh server. The same question about the PRODUCTION server stays a by-hand measurement.
