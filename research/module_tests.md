# Module — tests

The test harness of the R9700 vLLM tuning toolkit, as built by E1.S1: the runner, the assertion file, the fixtures, the
static checks and the CI workflow. E1.S2 part (a) adds the adapter's test file and the stub executables. Later parts and stories
add their test files to the same runner; there is no second one.

## Where it is

| Path | What |
|---|---|
| `tests/run.mjs` | the one runner: sweeps what a killed run left, claims one owned run folder, runs every `tests/test_*.py` and `tests/test_*.sh` one after the other, removes the folder |
| `tests/test_config.sh` | the config loader and the arm table (`lib/config.sh`) |
| `tests/test_verdict.py` | the ship test and the block check (`lib/verdict.py`) |
| `tests/test_harness.py` | the quality harness (`lib/harness.py`), against an HTTP stub |
| `tests/test_assert.sh` | `tests/lib/assert.sh` itself: a test function that dies early, exits early or asserts nothing fails its file; the pid killer |
| `tests/test_runner.sh` | `tests/run.mjs`: SIGINT, SIGTERM and SIGHUP end the run cleanly; a recorded pid is killed only while its start ticks match |
| `tests/test_adapter.sh` | the adapter seam (`lib/adapter.sh`) and `t_scale`, `t_ceiling` (`lib/run_guarded.sh`): argv, CR removal, the ceilings that kill the child, the `R9700_T_STOP` cut, the refusals (E1.S2 part (a): scenarios A2-A5, A7) |
| `tests/test_serve_bench.sh` | `serve_start` (`lib/serve.sh`) and `bench_run` (`lib/bench.sh`): the measured commands (scenario A8) |
| `tests/test_restore.sh` | the lock, the recovery marker (write, read, refusals), the worker gate and `worker_start`, the session stop, `container_stop_all`, `restore_from_marker` and `ready_wait` (E1.S2 part (b)) |
| `tests/test_lifecycle.sh` | `bin/r9700` for part (b): `commands`, `init`, `verdict` as the restore-first shell; scenarios L1, L4–L10, L15–L18, L20, L21 in their restore-first or `init` forms |
| `tests/test_step.sh` | `bin/r9700 step` (part (c)): scenarios L1–L3 (L3: the marker copy holds the worker keys and the pre-stop time), L4/L19, L6, L8, L10–L14, L20 (the label), L21 (the real hook), L22; the `INT`, `TERM` and `HUP` rules, a second signal during the cleanup, a `TERM` during a quiet wait and during a hung adapter call, the lock descriptor in every child, the one cleanup |
| `tests/test_guards.sh` | the guards through `step`: G1–G12 (the RAM stop leaves no process of the session, also with the worker in a hung adapter call; containers and log tails; unreadable telemetry; the limit; the deadline and its budget; the quiet check; the disk gate) and G14 (`wait_ready` through the `serve` worker). G13 is `tests/test_adapter.sh` and the `init` test of `tests/test_lifecycle.sh` |
| `tests/test_steps.sh` | the pieces of the step engine as functions: the outcome file (first writer wins), the deadline arithmetic, the supervisor log and the run folder, `quiet_check` and `quiet_wait`, the disk gate, `guard_ram`, `deadline_watch`, `wait_ready` and its probe program |
| `tests/lib/stepcase.sh` | the helpers of part (c): `step_setup`, `step_bg`/`step_end`, `session_fixture`, `append_answer`; it sources the part (c) libraries |
| `tests/lib/lifecycle.sh`, `tests/lib/fake_supervisor.sh` | helpers: a marker written by hand, `bin/r9700` as a user runs it, and a TEST DOUBLE of part (c)'s `step` (lock, marker, stop, worker behind the gate, kill) used to kill a supervisor |
| `tests/test_stubs.sh` | the stubs: A1, the call log, the scripted answers, containers that refuse what the real `wslc` refuses, the stub worker, a stub never makes its directory |
| `tests/stubs/wslc`, `powershell.exe`, `pwsh.exe`, `worker.sh`, `stub_common.sh` | the CI stand-ins for `wslc.exe`, Windows PowerShell and the restore shell, and the stub worker. Scripted by files below `$R9700_STUB_DIR`; an append-only call log; a "container" is a real `setsid sleep` recorded with its start ticks |
| `tests/lib/stubcase.sh` | the helpers of the three files above (`setup_case`, `argv_of`, `log_args`, ...); it sources the libraries under test |
| `tests/test_static.sh`, `tests/check_static.sh` | the static checks: bash and Python syntax, personal paths, `machine.env` ignored, vendored helper, the adapter seam (`--seam`: only `lib/adapter.sh` expands the executable variables or runs `wslc`, `powershell.exe`, `pwsh.exe`; comment lines are not scanned; quotes around the word, `.exe` and `name=wslc` assignments are caught; the one named exception is the three default declarations of the field table in `lib/config.sh`, matched exactly; every scan is shown alive by fixture trees) |
| `tests/lib/assert.sh` | the bash assertions (`assert_eq`, `assert_contains`, `assert_exit`, `t_finish`, `run_all_tests`) |
| `tools/lib/owned.mjs`, `git.mjs`, `leftovers-sweep.mjs`, `owned-token.mjs` | the leftovers helper: byte-identical copies of the shared files, plus this repository's own token file. They sit in `tools/lib/` because that is where the leftovers guard recognises a copied helper (product code, never scanned as a test) |
| `tests/lib/lower-priority.mjs` | the priority preload (the shared template with its `MOUNT` line edited) |
| `tests/fixtures/` | measured bench lines and quality files of 2026-10-28..31 (`ship_test/`, `prompts/`) and the machine fixture (`config/`) |
| `.github/workflows/tests.yml` | CI: the same commands as below, then the leftovers guard and the plan check |

Python is `pytest`, the only third-party package, pinned in `tests/requirements.txt`. Shell tests are plain bash with
`tests/lib/assert.sh`. A shell test is a set of functions named `t_<guarantee>`; `run_all_tests` runs each in its own
subshell and ends with `t_finish`, which fails a file that ran no assertion. A function that dies, exits before its end or records no assertion is a failure of its own.

## How it is run — the commands CI runs

```bash
python3 -m venv .venv && .venv/bin/python -m pip install -r tests/requirements.txt   # once
node tests/run.mjs                                   # every test, lowered priority, one worker
node tests/run.mjs tests/test_verdict.py             # one file (a name that matches no file is an error, exit 2)
bash tests/check_static.sh                           # static checks (also run inside tests/test_static.sh)
node .agents/conventions/tools/leftovers-check.mjs --repo . --token r9700 --identity "the R9700 vLLM tuning toolkit" --profile node
node .agents/conventions/tools/plan-lifecycle.mjs
```

The runner lowers its own priority first (`tests/lib/lower-priority.mjs`), so every child inherits it; it runs one file at a
time (one worker, below the cap of 8) and gives each file a ceiling of 10 minutes, after which the child's whole process
group is killed. It starts every child from an argv array, never a shell string. CI throttles nothing.

## Test leftovers

Every test file writes only inside ONE folder per run, `testsToDelete-<owner>-r9700-run-<id>`, which `tests/run.mjs` claims,
creates and removes; pytest gets a subfolder as `--basetemp`, a bash test gets its own as `R9700_TEST_ROOT`. No test makes a
temp path of its own and none changes the temp-folder environment variables. A run killed with `kill -9` leaves its folder;
the next run's sweep lists it as `removed` once the folder is more than 10 minutes old (the sweep's age selector) and its
owner process is gone. A test that records the pid of a process outside every process group writes it to
`$R9700_TEST_ROOT/containers/<name>.pid`; the EXIT trap of `run_all_tests` (`kill_recorded_pids`, searching every `containers/` folder below the test root) and the
runner's `finally` kill every recorded process before the folder is removed (E1.S2 amendment A4; S1 builds the two killers, S2
writes the stubs that record). A record is `<pid> <start ticks>` (field 22 of `/proc/<pid>/stat`, read after the last `)`); a pid
is killed only while it still has those ticks, so a reused pid is never killed; `record_pid <file> <pid>` writes the record.
SIGINT, SIGTERM and SIGHUP make the runner end the current file's process group AND its whole session (every process whose session id is the file's own pid; GNU `timeout` gives its child a process group of its own but not a session, so a stub call is outside the group and inside the session; the same at the 10-minute ceiling and after every file ends, so a passing file cannot leave a disowned subshell behind). The runner records the child's start ticks at spawn and skips a group or session kill when a process with that pid has other ticks (a reused pid), kill the recorded processes, remove the run
folder, print one `run: interrupted (<signal>)` line (no FAIL line, no summary) and exit 130, 143 and 129. A closed output pipe
(`node tests/run.mjs | head -3`) is handled the same way, silently, with exit 141; a test file ended by a signal is reported as
`FAIL <file> (signal <name>)`. A test that starts a process outside every group also records it with `guard_pid <pid> <name>`
(its real start ticks, in `$R9700_TEST_ROOT/guard/containers/`, a folder no killer under test is given), so the EXIT trap and the
runner end it on every path; `gone <pid>` polls until a process is gone.

## Test knobs

All of them are read from the environment only, never from `machine.env` and never listed in `research/module_config.md`.

| Knob | Read by | Meaning |
|---|---|---|
| `R9700_RUNNER_TESTS_DIR` | `tests/run.mjs` | discover `test_*.py` and `test_*.sh` in another folder; `tests/test_runner.sh` uses it so a signal test never puts a sleeping file into `tests/` |
| `R9700_TIME_SCALE` | `t_scale` in `lib/run_guarded.sh` | a positive integer; every sleep in `lib/` is divided by it (default 1); it is also the default of the ceiling scale |
| `R9700_CEILING_SCALE` | `t_ceiling` in `lib/run_guarded.sh` | a positive integer; divides only the adapter's ceilings and its kill-after grace (default: `R9700_TIME_SCALE`). The adapter tests set it to 10 while the sleeps run 100 times faster (a bash stub call takes 39 ms idle and up to 227 ms under load; a 0.3 s ceiling would be a flaky test), and set it to 100 in the tests that must see a ceiling fire |
| `R9700_T_STOP` | `lib/adapter.sh` | an epoch second, set by the supervisor: no adapter call waits past it (its ceiling is the smaller of its own and the time left) and none is made at or after it. Tested directly |
| `R9700_RUNNER_CEILING_MS` | `tests/run.mjs` | replaces the 10-minute ceiling of one test file (`tests/test_runner.sh` uses it to reach the ceiling in seconds) |
| `R9700_STUB_DIR` | the stubs | the only place a stub reads or writes; unset or empty: the stub exits 99 at once, so it can never run against a real machine |
| `R9700_STUB_PROD` | `pwsh.exe` stub | the name of the operator's server container the restore creates (default `vllm`) |
| `R9700_STUB_OK_HOLD` | `worker.sh ok` | seconds the stub worker holds before it exits 0 (default 0.3, so a guard gets reads) |
| `R9700_QUIET_CHECKS` | `quiet_wait` in `lib/guard_quiet.sh` | the number of quiet checks in a row, 1..10 (default 3); the lifecycle and guard tests set it to 1, and the test of the check count sets 3 (amendment A3). Never in `machine.env` |
| `R9700_LOADAVG_FILE` | `quiet_check` in `lib/guard_quiet.sh` | the file the 1-minute load is read from (default `/proc/loadavg`); every part (c) test points it at its own file, so the PC's real load never decides a test |
| `R9700_TEST_KILL_BEFORE_GATE` | `step_run` in `lib/step.sh` | `1` makes the supervisor `kill -KILL` itself right after the worker start, before the gate file exists (scenario L21) |
| `R9700_STUB_SERVE_HOLD` | `worker.sh serve` | seconds the serve worker holds after the server is ready (default 1000: it stays up until it is stopped) |
| `<stub dir>/stop-delay-<name>` | the `wslc` stub | seconds `wslc stop <name>` sleeps before it stops the container (a slow stop that a test interrupts) |
| `<stub dir>/mode` | the stubs | the file holds `hang` (every call sleeps; the sleeper is recorded in `hung/containers`), `hang-ignore-term` (the stub and its sleeper ignore `TERM`: only the kill-after ends the stub) or `eat-stdin` (every call reads its standard input) |

## Flow catalogue

One row per flow of what S1 builds. The command rows are derived from the programs' own parsers: a test in each Python file
fails when a command is added without a `covered` row here. `covered` names the test file.

| Flow | Status | Test |
|---|---|---|
| `lib/verdict.py ship` — the ship test, the three recorded verdicts, rule 1 and rule 2, GSM8K, `--json`, incomplete and input errors | covered | `tests/test_verdict.py` |
| `lib/verdict.py check-block` — one complete arm-round block | covered | `tests/test_verdict.py` |
| `lib/harness.py collect` — 20 greedy prompts | covered | `tests/test_harness.py` |
| `lib/harness.py compare` — greedy results against a reference | covered | `tests/test_harness.py` |
| `lib/harness.py gsm8k` — GSM8K scoring from a server | covered | `tests/test_harness.py` |
| `lib/harness.py gsm8k-compare` — the quality check of the ship test | covered | `tests/test_harness.py` |
| `lib/harness.py --selftest` — the original offline checks | covered | `tests/test_harness.py` |
| the config loader (`config_load`, `config_keys`, `config_resolved`) | covered | `tests/test_config.sh` |
| the arm table (`arms_load`, `arm_args`, `arm_env`, `arm_mounts`, `arms_check`) | covered | `tests/test_config.sh` |
| the static checks (`tests/check_static.sh`) | covered | `tests/test_static.sh` |
| `bin/r9700 commands` — the verb list, derived from the `verb_*` functions | covered | `tests/test_lifecycle.sh` (L18, L20) |
| `bin/r9700 init` — lock, restore first, config, the checks, the leftover containers | covered | `tests/test_lifecycle.sh` (L1, L4–L10, L15–L17, L21) |
| `bin/r9700 step` — one guarded step: the quiet wait, the disk gate, admission (marker, stop), the worker behind its gate, the guards, the typed outcome, retries, the one cleanup | covered | `tests/test_step.sh` (L1–L3, L6, L8, L10–L14, L19–L22), `tests/test_guards.sh` (G1–G12) |
| `bin/r9700 verdict` — only the restore-first shell until E1.S3 | covered | `tests/test_lifecycle.sh` (L6, L9) |
| the lock, the recovery marker, the worker gate, the session stop, the restore and its readiness wait (`lib/run_guarded.sh`, `lib/restore.sh`, `lib/worker_gate.sh`) | covered | `tests/test_restore.sh` |
| the adapter functions (`wslc_run`, `wslc_exec`, `wslc_list`, `wslc_stop`, `wslc_logs`, `win_ram_mb`, `win_disk_newest`, `restore_start`, `restore_probe`): argv, CR removal, ceilings that kill the child, refusals | covered | `tests/test_adapter.sh` |
| the adapter seam: only `lib/adapter.sh` expands the executable variables or runs the executables (`tests/check_static.sh --seam`) | covered | `tests/test_static.sh` |
| `serve_start` (the measured container command) and `bench_run` (the six measured runs) | covered; `serve_start` runs against a `wait_ready` double here, and against the real one in G14 | `tests/test_serve_bench.sh`, `tests/test_guards.sh` (G14) |
| the supervisor engine: `supervise`, `step_run`, `cleanup_once`, the outcome file, the deadline, the run folder (`lib/run_guarded.sh`, `lib/step.sh`) | covered | `tests/test_steps.sh`, `tests/test_step.sh`, `tests/test_guards.sh` |
| the guards: `guard_ram`, `deadline_watch`, `quiet_check`/`quiet_wait`, the disk gate, `wait_ready` | covered | `tests/test_steps.sh`, `tests/test_guards.sh` |
| the stubs and the stub worker (`tests/stubs/`) | covered | `tests/test_stubs.sh` |
| the runner ends the test file's whole session (not only its process group) at a signal and at a ceiling | covered | `tests/test_runner.sh` |
| the runner (`tests/run.mjs`): signals end the run cleanly, recorded pids are killed by start ticks | covered | `tests/test_runner.sh` |
| the runner: one owned folder, removed after a run, swept after a `kill -9` | covered by hand, below | — |
| the assertion file (`tests/lib/assert.sh`) | covered | `tests/test_assert.sh` |

Not built yet, so not in the catalogue: the series (E1.S3).

## The runner check, by hand (scenario 46)

Checked once on 2026-11-01 with Node 26 on Linux, by hand, because a test file cannot observe its own runner's exit:

1. After `node tests/run.mjs` ended, no folder named `testsToDelete-<owner token>-r9700-` was left in the temp root.
2. A run was started on a test file that sleeps 90 s, and the runner was ended with `kill -9` during the pytest step. The
   folder and its `.owner` claim stayed. The pytest child, started in its own process group, stayed too and was ended by
   hand with `kill -- -<pgid>`. The folder was then given the age of 20 minutes (`touch -d`), because the sweep leaves
   anything younger than 10 minutes alone; the first line of the next run was
   `leftovers: removed /<temp root>/testsToDelete-<owner token>-r9700-run-<id>` and the folder was gone.
3. The stub-pid killing and the signal handling are no longer by hand: `tests/test_runner.sh` covers them (the first two steps above stay by hand,
   because they need a runner that is killed without a handler).

## Lifecycle scenarios

Every scenario L1–L22 and G1–G14 of the story is covered. L1, L4 and L5 have an `init` form (part (b)) and a `step` form (part (c)); L21 has the real hook (`R9700_TEST_KILL_BEFORE_GATE`) beside part (b)'s double; L8 has its `TERM` half. Where a scenario fixed a number the machine's load could break (the sixth read of G3, the timing of G9), the test keeps the scenario and takes the number from a time scale chosen for that test; the guards' faults are triggered after the worker is up (`steps/<n>.ready`, or a line appended to `answers/ram` while the worker runs), never after a fixed time.

## What it does not prove

- **No GPU, no real `wslc`, no real vLLM server.** `lib/harness.py` is tested against a Python `http.server` stub on
  `127.0.0.1` that answers the two routes with fixed bodies; the real server's logprobs and chat template are not exercised.
- **The stubs are our idea of `wslc` and PowerShell, not theirs.** `wslc list` is assumed to print a header line and the container name as
  the last column (the old scripts' `awk 'NR>1{print $NF}'`); `run`, `logs`, `exec` and the PowerShell answers are scripted. A real
  `wslc` that prints another shape is found only on the machine.
- **The readiness program runs against a fake `urlopen`.** `tests/test_adapter.sh` runs the adapter's Python program under `python3` with
  `urllib.request.urlopen` replaced, so its logic and its output are tested (both checks, the status, the exception class), but no HTTP
  request is made; the first run on the R9700 closes that gap.
- **The worker's readiness program (`wait_ready_probe_program`) runs against a fake `urlopen` too**, in `tests/test_steps.sh`: its 200 and non-200
  paths and the route and the 5 s timeout it asks for are tested; whether the real server's `/v1/models` answers 200 on loopback port 8000 inside
  its container is found only on the machine.
- **The signal rules are proven for the supervisor's own waits, the admission calls and the worker, not for every call.** A `TERM` ends a quiet
  wait and an admission call at once; the restore inside a run and the readiness sleep are foreground commands, so a signal there waits for the
  current call (at most its ceiling) before the handler runs. A terminal's `Ctrl-C` goes to the whole foreground group and ends them at once; a
  `kill -TERM <pid>` of the supervisor alone is the case that waits. The tests send `TERM`, `HUP` and, through a python launcher that resets the
  ignored `SIGINT` of a background job, `INT`.
- **The time scale shortens sleeps and deadlines, not the kernel.** The tests run ten minutes as six seconds; the arithmetic is proven, the
  behaviour of a ten-hour night is not.
- **The adapter's ceilings are proven on a hung stub**, not on a hung `wslc.exe`: `timeout` ends the stub and its children with `TERM`, and the stub itself with `KILL` after the grace (GNU `timeout` sends the second signal to the child only: a grandchild that ignores `TERM` survives. Whether `wslc.exe` has such children is an UNVERIFIED ASSUMPTION: nobody has observed it either way). The calls the supervisor makes itself are stopped by session (amendment A8) in E1.S2 part (b), which covers a hung adapter call under a guard stop. A Windows process started through WSL interop may need more than a signal to end.
- **The stubs refuse what we know the real `wslc` refuses** (exec and logs on a container that is not running, a second run of a name in use); the exact error texts of the real one are not known.
- **No Windows.** The static checks and the runner are exercised on Linux only. The path and priority code of the runner is
  shared with other repositories, where Windows is covered.
- **The verdict is checked against recorded runs, not against a new measurement.** The three recorded verdicts (`fcombo`
  passes, `fb1` and `o7` fail) are reproduced from the stored lines; whether the rule itself is the right rule is a design
  decision of the plan, not a test result.
- **The config loader checks shape, not meaning.** It cannot know that a Windows path names the same folder as its WSL
  twin, or that an image reference exists in a registry.
- **The leftovers guard is red on the token row until the token is released** in the shared rules (the `## Tokens` table of the
  mounted detail rule); it is expected to name only that row.

## Known items

- CI runs Node 20 (the story's choice); the local runs of this story used a newer Node. The runner and the shared helper use no feature
  newer than Node 20, but no CI run has been made yet.
- The two-file output-pipe test cannot force the second file to be running when the pipe error arrives; it asserts that nothing is left
  whichever way the race goes.

## When it runs

CI runs the whole list above on every push and pull request. A developer runs `node tests/run.mjs` and
`bash tests/check_static.sh` before every commit. Nothing in this module needs the R9700; the series acceptance run on the
GPU belongs to E1.S3.
