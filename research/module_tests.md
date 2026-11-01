# Module — tests

The test harness of the R9700 vLLM tuning toolkit, as built by E1.S1: the runner, the assertion file, the fixtures, the
static checks and the CI workflow. Later stories add their test files to the same runner; there is no second one.

## Where it is

| Path | What |
|---|---|
| `tests/run.mjs` | the one runner: sweeps what a killed run left, claims one owned run folder, runs every `tests/test_*.py` and `tests/test_*.sh` one after the other, removes the folder |
| `tests/test_config.sh` | the config loader and the arm table (`lib/config.sh`) |
| `tests/test_verdict.py` | the ship test and the block check (`lib/verdict.py`) |
| `tests/test_harness.py` | the quality harness (`lib/harness.py`), against an HTTP stub |
| `tests/test_assert.sh` | `tests/lib/assert.sh` itself: a test function that dies early, exits early or asserts nothing fails its file; the pid killer |
| `tests/test_runner.sh` | `tests/run.mjs`: SIGINT, SIGTERM and SIGHUP end the run cleanly; a recorded pid is killed only while its start ticks match |
| `tests/test_static.sh`, `tests/check_static.sh` | the static checks: bash and Python syntax, personal paths, `machine.env` ignored, vendored helper |
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
SIGINT, SIGTERM and SIGHUP make the runner end the current file's process group, kill the recorded processes, remove the run
folder, print one `run: interrupted (<signal>)` line (no FAIL line, no summary) and exit 130, 143 and 129. A closed output pipe
(`node tests/run.mjs | head -3`) is handled the same way, silently, with exit 141; a test file ended by a signal is reported as
`FAIL <file> (signal <name>)`. A test that starts a process outside every group also records it with `guard_pid <pid> <name>`
(its real start ticks, in `$R9700_TEST_ROOT/guard/containers/`, a folder no killer under test is given), so the EXIT trap and the
runner end it on every path; `gone <pid>` polls until a process is gone.

## Test knobs

`R9700_RUNNER_TESTS_DIR` makes the runner discover its `test_*.py` and `test_*.sh` in another folder; `tests/test_runner.sh` uses it
so a signal test never puts a sleeping file into `tests/`. It is read from the environment only, never from `machine.env`.

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
| the runner (`tests/run.mjs`): signals end the run cleanly, recorded pids are killed by start ticks | covered | `tests/test_runner.sh` |
| the runner: one owned folder, removed after a run, swept after a `kill -9` | covered by hand, below | — |
| the assertion file (`tests/lib/assert.sh`) | covered | `tests/test_assert.sh` |

Not built yet, so not in the catalogue: the supervisor, the guards, the series and `bin/r9700` (E1.S2, E1.S3).

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

## What it does not prove

- **No GPU, no real `wslc`, no real vLLM server.** `lib/harness.py` is tested against a Python `http.server` stub on
  `127.0.0.1` that answers the two routes with fixed bodies; the real server's logprobs and chat template are not exercised.
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
