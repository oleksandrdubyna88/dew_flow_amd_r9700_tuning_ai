# dew_flow_amd_r9700_tuning_ai

Tune and measure vLLM on an AMD Radeon AI PRO R9700 under Windows + WSL2, where containers run with `wslc`. A series compares server
configurations ("arms") against a base arm and ends with a ship test; the toolkit also tunes the fused-MoE kernel config, times the linear kernels, checks the prefix cache,
and runs a whole night of those steps from one plan file. A new model is one file in `models/`, not a new script. The system as it is lives in `research/` (start with `research/architecture.md`).

A run stops the operator's own vLLM server for its own duration and restores it once, at the end. Run it on a PC nobody is using.

## The commands

| Command | What it does |
|---|---|
| `bin/r9700 init` | checks the machine file, the folders, `wslc` and the telemetry; stops every leftover test container |
| `bin/r9700 series <model> <arm>...` | the arms of a comparison, alternating, resumable, each arm-round recorded only when complete |
| `bin/r9700 verdict <results folder>` | the ship test over the finished arm-rounds |
| `bin/r9700 moe-tune <mode> <model>` | MoE config tuning: `chunk`, `merge`, `activate`, `ab` |
| `bin/r9700 linear-bench <model>` | times the model's linear shapes (the hybrid W4A16 kernel) |
| `bin/r9700 prefixtest <model>` | twelve prefix-cache requests against one measured server |
| `bin/r9700 run <plan>` | a night: the steps of a plan file under ONE supervisor |
| `bin/r9700 comfy <mode>` | the operator's ComfyUI on the same card, one owner at a time: `start`, `stop`, `status` |
| `bin/r9700 step <label> -- <command...>` | one command as a guarded step (the engine under the other verbs; for tests and by hand) |
| `bin/r9700 commands` | prints the verbs |

The sections below go through them in this order. Where every script of the old harness folder went is in `research/INPUTS_homes.md`.

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
bin/r9700 moe-tune ab qwen3.6-35b-a3b-gptq --keys "8 12 16 24" --rule median --rule-keys "24" --out acceptance-moe
```

Options: `chunk` takes `--keys "<k...>"` (required), `--coarse` (the 82 candidates of `config/coarse_candidates.json`, not the full search), `--layer experts|draft`,
`--chunk <name>` (default `<layer>-<coarse|full>-<keys joined by ->`, for example `experts-coarse-24`) and `--dry-run`. `ab` takes `--keys`, `--rule each|median`
and `--rule-keys` (the keys the decision is about; both required), `--reps` (default 3), `--layer` and `--dry-run`. `merge` takes the chunk names,
`--layer` (refuses a chunk of another layer), `--base auto|none|<file>`. `activate` takes the stamp, `--layer experts|draft` (only for a record that has no layer in its `merge.env`, such as one made by hand) and `--force`. All take `--out <name>` (default
`moe-<model name>`). `--dry-run` prints the resolved container lines; it starts no container and does not stop your server, but it is not read-only: like `activate` it runs under the supervisor, so it takes the lock (exit 4 when another run holds it), restores your server first when a recovery marker is left, makes a run folder under `<RESULTS_DIR>/runs/`, copies the two vendored files into the work folder, and is refused (exit 2) when the deadline leaves no room. The draft layer (`--layer draft`) is for an MTP draft MoE layer, the
35B model's case. A model with no MoE layers sets `MOE_DTYPE=none` in its model file; `moe-tune` then refuses it before it stops anything.

**Which activation dtype the experts layer is tuned for.** The benchmark forces FP16 activations on ROCm, while the 35B model serves BF16, and a file tuned for the wrong dtype can be slower than vLLM's default
(`dew_flow_benchmark`, `research/RESULTS_vllm_029_r9700_speed_options.md` § 15.3: 16.4 % slower at M=640). The model file's `MOE_ACT_DTYPE` (`bfloat16`, the default, or `float16`) says which dtype your server serves:
with `bfloat16`, `chunk` and `ab` of the experts layer set the vendored benchmark's hook `MOE_TUNE_ACT_DTYPE=bfloat16` (`--dry-run` shows it); with `float16` they set no word, and the benchmark's own FP16 runs. The draft layer is always BF16.
`chunk.env` and `ab.env` record the value (`ACT_DTYPE`), and `merge` refuses chunks that differ in it. `models/qwen3.6-35b-a3b-gptq.env` sets `bfloat16` with the evidence; `models/qwen3.8-27b-awq.env` keeps the default, which was NOT measured
for that model: set `float16` there if your server runs FP16. An EXPERTS chunk recorded by an older version names no dtype and is never taken for a match: running its command again is refused (exit 2, before anything is stopped, and also with `--dry-run`) and asks for another `--out`;
a recorded chunk of another dtype, or of another layer, or with no `LAYER`, is refused the same way. Old DRAFT records hold `bfloat16` (the draft layer was always BF16) and still match.
Nothing checks `MOE_ACT_DTYPE` against the running server, because the server's start script is yours: set it to match any `--dtype` your server uses.
`merge` still merges, but it says and records what it mixes: `merge.env` holds `ACT_DTYPE` (the chunks' common value, or `unknown` when they name none) and `BASE_ACT_DTYPE` (`none` without a base, `unknown` with one: a production file is not a record),
and it prints one `note:` line when a base of unknown dtype is merged (`--base none` keeps it out), when the chunks name no dtype, or when the experts chunks were tuned for another dtype than the model's `MOE_ACT_DTYPE`. `activate` copies both words into `activate.env`
(`unknown` for a record that has none), and `ab` writes them to `ab.env` as `FILE_ACT_DTYPE` and `FILE_BASE_ACT_DTYPE` and prints one `note:` when the activated file's dtype is not the run's or its base's is not `none`; `ab.env`'s `ACT_DTYPE` stays what the A/B ran with. The toolkit tunes and measures; whether the hook changes the real kernel's activations is known from the draft-layer chunks of 2026-10-28..31 and has not been observed through the toolkit yet (`vendor/README.md`).

Where things are:

- The records: `<RESULTS_DIR>/moe-<model>/chunks/<chunk>/` (the tuned JSON, the log, `chunk.env`), `merged/<stamp>/` (the merged file, `merge.env`), `ab/<stamp>/`
  (six logs, the table, `decision.txt`) and `rejected/` (a failed attempt, with its reason). Nothing there is deleted.
- The ACTIVE file: `<WORK_DIR>/r9700/moe/<model>/merged/`. Inside a container that is `/work/r9700/moe/<model>/merged`: set it as `TUNED_CONFIG_DIR` of the
  model file, or copy the file into the folder your own server mounts. `activate.env` there says which stamp is active.
- A merge never changes the active file. `activate` does, atomically (the file is written beside and renamed over, so a reader sees the old bytes or the new
  ones), and keeps the file it replaced under `merged/previous/`. It is refused (exit 2) while your own server or a test container is listed, because such a
  container may read the folder; `--force` is your word that it does not (it is logged). Activating the stamp that is already active does nothing.
- `merge --base auto` fails with `duplicate key` when a chunk holds a key that the production file already has: use `--base none` for such a chunk. When the model's `TUNED_CONFIG_DIR` is not under `/work` the production file cannot be read from WSL: `merge` refuses and asks for `--base <file>` or `--base none`.
- `ab` reads the layer and the file name from `activate.env` (written by `activate`), so it works in any `--out`. If you activated a record of the other layer last, `ab` refuses and says which record to activate again. If a run was killed in the middle of an activation, the next `activate` (or the start of an `ab`) finishes it.

To resume, run the same `chunk` command (with the same `MOE_ACT_DTYPE`): a recorded chunk is skipped before anything is stopped. Name another `--chunk` for a second search. For a long search
set `MAX_RUN_MINUTES` (up to 2880) and `MOE_CHUNK_MAX_S` in `machine.env`.

## Kernels and the prefix check

Two more single steps, each one supervised run (one lock, ONE stop of your server, ONE restore), each recorded only when its result is complete and valid:

- `bin/r9700 linear-bench <model>` times the model's hybrid W4A16 linear shapes (the model file's `LINEAR_SHAPES`, no shape is typed in a script) in one foreground container with
  the CUDA-graph timer: per shape and M the vLLM default dispatch, the HIP op split into chunks of at most five rows, and the best of a 144-tile Triton sweep at the sweep Ms. It records the
  rows and prints the table of the results document (§ 12.1: per M, the sum over the shapes in ms, and the change of the tuned kernel against the default). The recorded graph-timer run took about 6 minutes (00:12 to 00:18 of the night of 2026-10-30); the eager run took 11.
- `bin/r9700 prefixtest <model>` starts one measured server for one arm (`--arm`, default `base`) and sends twelve prefix-cache requests (per length: A cold, A hit twice, B cold, B hit, A
  with its last 64 tokens changed). It records the two lines and prints their cold/hit ratios. It applies no threshold: it is the measurement behind the § 6.1 question.

```bash
bin/r9700 linear-bench qwen3.6-35b-a3b-gptq --name first
bin/r9700 prefixtest qwen3.6-35b-a3b-gptq --name first --arm base
```

Options: `linear-bench` takes `--ms "…"` (default `1 2 3 4 5 6 8 10 12 16`), `--sweep-ms "…"` (default `6 8 12 16`, each also in `--ms`) and `--timer graph|eager` (default `graph`;
the eager timer includes launch overhead and its sum is not a decode time). `prefixtest` takes `--lens "…"` (default `8192 1024`; each plus one must fit `MAX_MODEL_LEN`) and `--tail <n>`
(default 64, below the shortest length). Both take `--name <name>` (default the UTC stamp: a new record every run), `--out <name>` (default `kernels-<model name>`) and `--dry-run`, which
prints the resolved container lines and starts nothing (like `moe-tune --dry-run` it takes the lock and restores first).

The records are `<RESULTS_DIR>/kernels-<model>/linear/<name>/` (`linear_bench.json`, `linear.log`, `summary.txt`, `linear.env`) and `prefix/<name>/` (`prefixtest.txt`, `summary.txt`,
`server.log`, `prefix.env`); a failed attempt is kept in `rejected/` with a `reason`. Nothing there is deleted. With `--name`, the same command again skips a recorded name before anything is
stopped, but only when it is the same experiment: when the model, the image, a parameter or a placed file differs, the command refuses and names the key (`the record linear/first is
another experiment: MS "1 2 6" -> "1 2"`).

`linear-bench` refuses a model whose `LINEAR_SHAPES` is empty: the 27B AWQ file leaves it empty because nobody has measured whether that model takes the hybrid W4A16 kernel. The 35B file
carries the five shapes of the speed-options runs. A new model gets its shapes in its model file (`LINEAR_SHAPES`, `LINEAR_GROUP_SIZE`; `research/module_config.md`).

## A night: `run`

`bin/r9700 run <plan>` runs a whole night from a text file: one step per line, each line the command line of a toolkit verb. The steps run in order under ONE supervisor: one lock, the
restore of your own server first when a marker is left, your server stopped once at the first step and restored once at the end, one deadline for the whole chain. Blank lines and lines
starting with `#` are skipped. A line is what you would type after `bin/r9700`, with words split on spaces (put a word that holds spaces in one pair of double quotes). The characters
`$`, a backtick, `'`, `;`, `|`, `&`, `<`, `>`, `(`, `)` and a tab are refused: the file is never given to a shell. The plan is YOUR file; keep it outside the repository.

```
# night.plan
prefixtest qwen3.6-35b-a3b-gptq --name p1
series qwen3.6-35b-a3b-gptq base --rounds 1
linear-bench qwen3.6-35b-a3b-gptq --name n1
moe-tune chunk qwen3.6-35b-a3b-gptq --keys "24 32" --coarse --chunk night-24-32
```

- **Check before you leave.** `bin/r9700 run night.plan --check` validates every line and every step's config, takes no lock and starts nothing. It prints `run: step <k>: ok (<line>)`
  per step and the worst case: `run: at most <n> stops of the operator's server if every step is admitted after a busy wait; MAX_SERVER_STOPS=<n>`. `--dry-run` takes the lock and prints
  the dry run of every step.
- **The steps.** `series`, `moe-tune chunk`, `moe-tune ab`, `linear-bench` and `prefixtest`. Four verbs are refused as steps, each with its reason: `init` (the machine check you run before a night),
  `verdict` (a reading verb: run it in the morning), `moe-tune merge` (it reads chunks that you choose after reading them) and `moe-tune activate` (it changes what your own server reads: a chain at
  night must not decide that). `--dry-run` inside a plan line is refused.
- **Stops and budgets.** A quiet chain stops your server ONCE and restores it ONCE, however many steps it has. `MAX_SERVER_STOPS` is the cap for the whole run and counts real stops: the only
  other stop is after your server was given back while the PC was busy (a step that exits 3 waits for a quiet PC; it is not a failed try). A step that would pass the cap is refused before it starts
  anything, and your server is still restored. If `wslc stop` returns an error code but your server is no longer listed, the stop counts as done (the supervisor log says `stop returned <code> but the server is gone: counted as stopped`); if it is still listed, the step counts a failed try and the log shows what `wslc` printed (`stop output: <line>`). `MAX_FAILED_TRIES` is per step. A step whose worker exits 3 more than 3 x `MAX_FAILED_TRIES` times ends with exit 8. Do not edit `machine.env` during a night: the next step is refused (exit 2). The deadline is per run: a step that ends with 6 ends the chain, and the later steps are not started.
- **How a stop reads.** The exit code is the code of the step that stopped the chain (the table below; `run` adds no code), and stderr says where: `r9700: run: stopped at step 2 of 3 (<the line>): 7`.
  `<RESULTS_DIR>/runs/<id>/run.txt` has the plan's path and hash and one line per step: `<k> <state> <code> <line>`, the state one of `not-started`, `running`, `done`, `stopped`, `interrupted`;
  `plan.txt` beside it is the plan as it was run.
- **Resume.** Run the same command again: every step skips what it recorded. Give every `linear-bench` and `prefixtest` step a `--name`, or it runs again (without a name the record is named by the time).
  A step whose model, image or patch changed since its records is refused by its own identity check (exit 2).
- **Each step has its own model file.** The files are read again when the step starts: a model file edited after the check is refused at its step (exit 2), after the earlier steps' records are final.

Where the records of a series are: `<RESULTS_DIR>/<name>/rounds/<arm>-<round>/` is one arm-round and exists only when it is complete; an attempt that failed
its checks is kept, with a `reason`, in `rejected/`; an arm that did not start twice is in `unsupported/`; `fingerprint.json` is the identity of the
series; `<RESULTS_DIR>/runs/` has one folder per invocation (the supervisor's log, the guards' logs). Nothing under `<RESULTS_DIR>` is ever deleted
by the toolkit.

Exit codes of `bin/r9700` (the table with the line each prints is in `research/architecture.md`):

- `0` done.
- `1` `verdict`: at least one arm is INCOMPLETE (a round is missing); `comfy start`: your server could not be stopped, or a volume, the remove or the run call failed (nothing of ComfyUI is left running; your server was restored when this invocation had stopped it); `comfy stop`: the container did not stop; `comfy status`: a state could not be read.
- `2` refused: a bad argument or config, a series whose identity changed (`fingerprint differs: …`), a `verdict` input error; `moe-tune`: a bad argument, a model with `MOE_DTYPE=none`, a recorded chunk of another activation dtype (or of none, as the older ones), a merge input error, an activation that is refused; `linear-bench`: a model with no `LINEAR_SHAPES`; `linear-bench` and `prefixtest`: a bad argument, a length that does not fit the context, a `--name` that names the record of another experiment; `run`: a refused plan (a line that is not a step, a refused character, a refused argument, no step), or a step whose config or identity is refused when it starts; `comfy`: a refused argument or mode, a machine config refused (`COMFY_CONTAINER` must not start with `CONTAINER_PREFIX` and must differ from `PROD_CONTAINER`), a start beside your listed server without `--stop-vllm`, a container list that failed three times; every verb that runs under the supervisor: your ComfyUI is listed (the line names `bin/r9700 comfy stop`).
- `4` another run holds the lock (`comfy start` holds it through its readiness wait).
- `5` the restore of your own server did not become ready, or was not started beside your ComfyUI (the marker stays: `bin/r9700 comfy stop`, then any verb restores it): look at the server by hand; `comfy start`: ComfyUI did not become ready (its log tail is saved, it is stopped, your server is restored when this invocation stopped it), or the container list could not be read after the launch (nothing was stopped; the line names `comfy stop` and `init`).
- `6` the deadline stopped the run (or the next arm-round no longer fits before it): run the same command again.
- `7` the step failed `MAX_FAILED_TRIES` times.
- `8` the PC was not quiet before the deadline, your server was already stopped `MAX_SERVER_STOPS` times in this run (the next stop is refused), or a worker exited 3 more often than the repeat bound.
- `9` the disk gate stopped the run (a new disk event in the Windows log).
- `10` `init` found a problem.
- `11` the recovery marker cannot be read: check the server by hand, then remove the marker.
- `129` interrupted by `HUP`; the server was restored.
- `130` interrupted by `INT` (Ctrl-C); the server was restored.
- `143` interrupted by `TERM`; the server was restored.

Tests: `node tests/run.mjs` (stubs only: no container and no GPU) and `bash tests/check_static.sh`; `research/module_tests.md` says what they prove and what they do not. Run every test command under a process cap, as that file says
(`bash -c 'ulimit -u $(( $(ps -L -u $(id -u) --no-headers | wc -l) + 3000 )); exec nice -n 19 node tests/run.mjs'`).

## Acceptance on the GPU

CI uses stubs, so every flow that needs the GPU, the real `wslc` and the real image has a record in `research/`, made by the operator's session on the R9700 PC before a release: the prediction is written first, the observed sections are filled after the run,
and a record that was not run says NOT RUN in its title and keeps its observed sections empty. `research/ACCEPTANCE_series_2026-11-02.md` was run on 2026-11-02; `research/ACCEPTANCE_moe_tune_2026-11-02.md`, `research/ACCEPTANCE_linear_bench_2026-11-03.md`,
`research/ACCEPTANCE_prefixtest_2026-11-03.md` and `research/ACCEPTANCE_run_2026-11-03.md` were run on 2026-11-03, so all five are filled in, each with its observed-against-predicted table (where the run differed from the prediction, the record says so). `POST_DEPLOY.md` is the short list to run on the PC after every install or update.

## The family

This repository is public and a consumer of the shared rules of `dew_flow_conventions`: they are mounted at `.agents/conventions` (the `release` branch; fresh clone: `git submodule update --init .agents/conventions` and
`npm ci --ignore-scripts --prefix .agents/conventions`), and the consumers table in that repository's README lists this repository (test-leftovers token `r9700`). Both facts were read on 2026-11-03: the row at the pinned release of the rules, and the visibility
with `gh repo view <owner>/dew_flow_amd_r9700_tuning_ai --json visibility` (PUBLIC). Machine specifics are never committed: they live in the untracked `machine.env` made from `machine.env.example`, and `bash tests/check_static.sh` fails when a tracked file holds a personal path.
CI (`.github/workflows/tests.yml`) runs the tests, the static checks, the leftovers guard, the plan check and the shape check of `POST_DEPLOY.md`.
