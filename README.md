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
   (default: the model's name, no date; the first line of the output says which); `--dry-run` prints the commands of the first arm-round and starts no server. A new model is a new file in `models/`.
4. **Read the verdict.** `bin/r9700 verdict <RESULTS_DIR>/<name>` prints the ship test over the finished arm-rounds: the first arm is the base, and an
   arm passes when its speed is higher than the base's spread allows to call noise and its GSM8K accuracy is within twice the larger standard error.
   A series of one round says so in a `note:` line.
5. **Resume.** If a run stops (the deadline, a busy PC, a power cut), run the SAME command again (without `--out` the folder is named after the model, so it is found on any day): arm-rounds that are recorded are skipped, the rest
   run. A resume must be the same experiment: when the model, the image, a patch file, the generation config, an arm or the base changed, the command
   refuses and names what differs (`fingerprint differs: <path>: <old> -> <new>`) before it stops anything. Adding an arm, or asking for more
   rounds, is allowed.

## MoE tuning

`bin/r9700 moe-tune` tunes the fused-MoE kernel config for one model, in four steps. Each step that uses the GPU is one supervised run: one lock, the
restore of your own server first when a marker is left, ONE stop of your server, ONE restore at the end (the same lifecycle as `series`).

- `chunk` tunes some batch sizes ("keys") in one container and records the result only when it is complete and valid. A coarse chunk of four keys takes
  about 21 minutes; a full search of one key takes 1 to 3.6 hours (key 24 was estimated at 11 hours).
- `merge` joins recorded chunks (and, by default, the production file of the model's `TUNED_CONFIG_DIR` when that folder is under `/work`) into a NEW
  versioned record `merged/<stamp>/`. It uses no GPU and replaces nothing.
- `activate` copies one merged record into the model's exchange folder. It is the only step that changes what a server or an A/B reads.
- `ab` measures the kernel with vLLM's default config against the activated file, three repeats, and prints a decision (`KERNEL: faster` or `not faster`).
  About 5 minutes.

```bash
bin/r9700 moe-tune chunk qwen3.6-35b-a3b-gptq --keys "24" --coarse --out acceptance-moe
bin/r9700 moe-tune merge qwen3.6-35b-a3b-gptq --out acceptance-moe experts-coarse-24
bin/r9700 moe-tune activate qwen3.6-35b-a3b-gptq <the stamp the merge printed> --out acceptance-moe
bin/r9700 moe-tune ab qwen3.6-35b-a3b-gptq --keys "8 16 24 32" --rule median --rule-keys "24" --out acceptance-moe
```

Options: `chunk` takes `--keys "<k...>"` (required), `--coarse` (the 82 candidates of `config/coarse_candidates.json`, not the full search), `--layer experts|draft`,
`--chunk <name>` (default `<layer>-<coarse|full>-<keys joined by ->`, for example `experts-coarse-24`) and `--dry-run`. `ab` takes `--keys`, `--rule each|median`
and `--rule-keys` (the keys the decision is about; both required), `--reps` (default 3), `--layer` and `--dry-run`. `merge` takes the chunk names,
`--layer` (refuses a chunk of another layer), `--base auto|none|<file>`. `activate` takes the stamp and `--force`. All take `--out <name>` (default
`moe-<model name>`). `--dry-run` prints the resolved container lines and starts nothing. The draft layer (`--layer draft`) is for an MTP draft MoE layer, the
35B model's case. A model with no MoE layers sets `MOE_DTYPE=none` in its model file; `moe-tune` then refuses it before it stops anything.

Where things are:

- The records: `<RESULTS_DIR>/moe-<model>/chunks/<chunk>/` (the tuned JSON, the log, `chunk.env`), `merged/<stamp>/` (the merged file, `merge.env`), `ab/<stamp>/`
  (six logs, the table, `decision.txt`) and `rejected/` (a failed attempt, with its reason). Nothing there is deleted.
- The ACTIVE file: `<WORK_DIR>/r9700/moe/<model>/merged/`. Inside a container that is `/work/r9700/moe/<model>/merged`: set it as `TUNED_CONFIG_DIR` of the
  model file, or copy the file into the folder your own server mounts. `activate.env` there says which stamp is active.
- A merge never changes the active file. `activate` does, atomically (the file is written beside and renamed over, so a reader sees the old bytes or the new
  ones), and keeps the file it replaced under `merged/previous/`. It is refused (exit 2) while your own server or a test container is listed, because such a
  container may read the folder; `--force` is your word that it does not (it is logged). Activating the stamp that is already active does nothing.
- `merge --base auto` fails with `duplicate key` when a chunk holds a key that the production file already has: use `--base none` for such a chunk.

To resume, run the same `chunk` command: a recorded chunk is skipped before anything is stopped. Name another `--chunk` for a second search. For a long search
set `MAX_RUN_MINUTES` (up to 2880) and `MOE_CHUNK_MAX_S` in `machine.env`.

Where the records of a series are: `<RESULTS_DIR>/<name>/rounds/<arm>-<round>/` is one arm-round and exists only when it is complete; an attempt that failed
its checks is kept, with a `reason`, in `rejected/`; an arm that did not start twice is in `unsupported/`; `fingerprint.json` is the identity of the
series; `<RESULTS_DIR>/runs/` has one folder per invocation (the supervisor's log, the guards' logs). Nothing under `<RESULTS_DIR>` is ever deleted
by the toolkit.

Exit codes of `bin/r9700` (the table with the line each prints is in `research/architecture.md`):

- `0` done.
- `1` `verdict`: at least one arm is INCOMPLETE (a round is missing).
- `2` refused: a bad argument or config, a series whose identity changed (`fingerprint differs: …`), a `verdict` input error; `moe-tune`: a bad argument, a model with `MOE_DTYPE=none`, a merge input error, an activation that is refused.
- `4` another run holds the lock.
- `5` the restore of your own server did not become ready: look at the server by hand; the recovery marker stays.
- `6` the deadline stopped the run (or the next arm-round no longer fits before it): run the same command again.
- `7` the step failed `MAX_FAILED_TRIES` times.
- `8` the PC was not quiet before the deadline, or the server was stopped `MAX_SERVER_STOPS` times.
- `9` the disk gate stopped the run (a new disk event in the Windows log).
- `10` `init` found a problem.
- `11` the recovery marker cannot be read: check the server by hand, then remove the marker.
- `129` interrupted by `HUP`; the server was restored.
- `130` interrupted by `INT` (Ctrl-C); the server was restored.
- `143` interrupted by `TERM`; the server was restored.

Tests: `node tests/run.mjs` (stubs only: no container and no GPU) and `bash tests/check_static.sh`; `research/module_tests.md` says what they prove.
