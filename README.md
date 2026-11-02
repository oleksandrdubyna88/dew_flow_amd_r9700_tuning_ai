# dew_flow_amd_r9700_tuning_ai

Tune and measure vLLM on an AMD Radeon AI PRO R9700 under Windows + WSL2, where containers run with `wslc`. A series compares server
configurations ("arms") against a base arm and ends with a ship test. (Work in progress — see `todo/`; the system as it is lives in `research/`.)

A run stops the operator's own vLLM server for its own duration and restores it once, at the end. Run it on a PC nobody is using.

## Quick start

1. **Machine file.** Copy `machine.env.example` to `machine.env` and fill in the values of this PC (the image, the work and patch folders as WSL
   and Windows paths, the results folder, the operator's start script and its arguments). `machine.env` is never committed. Every key is in
   `research/module_config.md`.
2. **Check the machine.** `bin/r9700 init` loads the config, checks the folders, wslc, the RAM and disk telemetry, and stops every leftover test
   container. It prints one `init:` line per check and exits 10 when one failed.
3. **Run a series.** `bin/r9700 series qwen3.6-35b-a3b-gptq base ta3 --rounds 1` measures the arms `base` and `ta3` (rows of `config/arms.conf`) on the
   model in `models/qwen3.6-35b-a3b-gptq.env`: per arm-round the 1024/512 bench at concurrency 1 and 4, the prefill runs, the spec-decode metrics and, in
   round 1, 20 greedy prompts and GSM8K-200. Arms alternate inside a round. `--rounds` defaults to 3; `--out <name>` names the results folder
   (default `<model>-<UTC date>`); `--dry-run` prints the commands of the first arm-round and starts no server. A new model is a new file in `models/`.
4. **Read the verdict.** `bin/r9700 verdict <RESULTS_DIR>/<name>` prints the ship test over the finished arm-rounds: the first arm is the base, and an
   arm passes when its speed is higher than the base's spread allows to call noise and its GSM8K accuracy is within twice the larger standard error.
   A series of one round says so in a `note:` line.
5. **Resume.** If a run stops (the deadline, a busy PC, a power cut), run the SAME command again: arm-rounds that are recorded are skipped, the rest
   run. A resume must be the same experiment: when the model, the image, a patch file, the generation config, an arm or the base changed, the command
   refuses and names what differs (`fingerprint differs: <path>: <old> -> <new>`) before it stops anything. Adding an arm, or asking for more
   rounds, is allowed.

Where the records are: `<RESULTS_DIR>/<name>/rounds/<arm>-<round>/` is one arm-round and exists only when it is complete; an attempt that failed
its checks is kept, with a `reason`, in `rejected/`; an arm that did not start twice is in `unsupported/`; `fingerprint.json` is the identity of the
series; `<RESULTS_DIR>/runs/` has one folder per invocation (the supervisor's log, the guards' logs). Nothing under `<RESULTS_DIR>` is ever deleted
by the toolkit.

Exit codes of `bin/r9700` (0 done, 2 refused, 4 another run holds the lock, 5 the restore did not become ready, 6 the deadline, 7 the step failed
too often, 8 not quiet or the stop budget is used, 9 the disk gate stopped the run, 10 `init` found a problem, 130 and 143 interrupted): the table
with the lines each prints is in `research/architecture.md`.

Tests: `node tests/run.mjs` (stubs only: no container and no GPU) and `bash tests/check_static.sh`; `research/module_tests.md` says what they prove.
