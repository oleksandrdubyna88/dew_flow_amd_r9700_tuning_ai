# Config contract — every field

Three kinds of file hold the configuration. Nothing else does.

| File | Tracked | Holds |
|---|---|---|
| `machine.env` | no (`.gitignore`); made from `machine.env.example` | the values of THIS PC: commands, folders, the operator's restore command, the guard limits |
| `models/<name>.env` | yes | one model: its path, served name, context, sequences, prefill lengths, mounts |
| `config/arms.conf` | yes | the arms of a comparison: serve arguments, environment, extra mounts |

`lib/config.sh` loads and validates them. The field table in that file (one `_field` call per field) is the single source
of truth: `config_keys` prints it, and `tests/test_config.sh` fails when this document and the table disagree. Run a
check by hand: `bash -c 'source lib/config.sh; config_load machine.env models/<name>.env && config_resolved'`.

## Rules every file follows

- One `KEY=VALUE` per line, matching `^([A-Z][A-Z0-9_]*)=(.*)$`; blank lines and lines starting with `#` are skipped.
- A value is bare (no spaces, no quotes) or wrapped in ONE pair of double quotes. A `$` or a backtick anywhere in a value, a
  quote inside a quoted value, a single quote, a carriage return and text after the closing quote are all refused.
- The files are data. Nothing is sourced, evaluated or expanded; a value reaches a variable only for a key of the table.
- A key of the other file's scope is unknown here (`IMAGE` in a model file is refused). A key set twice is refused.
- Every error names the file, the line, the field and the legal values (`config: <file>:<line>: <KEY>: <problem>; legal:
  <legal>`). All errors are printed in one pass; the exit status is 2. Nothing is stopped or started before the config is valid.
- After the single-field checks, the cross-field checks run (also when a single field is wrong; a field that failed its own check is skipped): every `PREFILL_LENS` value + 128 ≤ `MAX_MODEL_LEN`; every
  `MOUNTS` source exists under `PATCH_DIR`; every `LINEAR_SHAPES` K is a multiple of `LINEAR_GROUP_SIZE` (E3.S1); `PROD_CONTAINER` does not start with `CONTAINER_PREFIX` (the toolkit stops every container with that prefix, so the operator's own server must stay outside it); `CLEANUP_BUDGET_S` ≥ `READY_TIMEOUT_S` + 300 (the budget must hold the restore
  and its readiness wait); `MAX_FAILED_TRIES` ≤ `MAX_SERVER_STOPS` (a retry after a busy-wait restore stops the operator's server again, so more tries than stops could not all happen; E1 amendment A20). `MAX_SERVER_STOPS` counts ACTUAL stops of the operator's server over the whole invocation, a chain of `run` included (E3.S2 decision 4); an admission that finds the server already down charges nothing.

## `machine.env`

| Key | Type and legal values | Default | What it does | Replaces |
|---|---|---|---|---|
| `WSLC` | command: a bare name starting with a letter or digit (looked up on `PATH`), or an absolute path | `wslc` | the command for wslc, a bare name looked up on PATH, or an absolute path | `serve.sh` line 8 |
| `POWERSHELL` | command (same shape as `WSLC`) | `powershell.exe` | Windows PowerShell, for the RAM and disk probes | `ram_guard_all.sh` line 8, `disk_gate.sh` line 7 |
| `RESTORE_SHELL` | command (same shape as `WSLC`) | `pwsh.exe` | the shell that runs the operator's start script when the server is restored | `restore_server.sh` line 19 |
| `IMAGE` | image reference `^[a-z0-9][a-z0-9./_-]*:[A-Za-z0-9._-]+$` | required | the container image of the test servers | `serve.sh` line 8 |
| `HF_VOLUME` | name `^[a-z0-9][a-z0-9._-]*$` | `hf-cache` | the named volume that holds the model cache | `serve.sh` line 10 |
| `CACHE_VOLUME` | name `^[a-z0-9][a-z0-9._-]*$` | `vllm-cache` | the named volume that holds the compile caches | `serve.sh` line 10 |
| `WORK_DIR` | WSL directory, absolute, must exist | required | the work directory, as a WSL path; it must exist | `serve.sh` lines 9–10 (the Windows form) |
| `WORK_DIR_WIN` | Windows path: a drive letter, `:` and `\`, then no `:` `*` `?` `"` `<` `>` and no pipe character — the same directory, mounted at `/work` | required | the same work directory as a Windows path; it is mounted at /work | `serve.sh` lines 9–10 |
| `PATCH_DIR` | WSL directory, absolute, must exist — the base of every mount source | required | the base directory of every mount source, as a WSL path; it must exist | `serve.sh` lines 13–16; `speed_A.sh` lines 13, 15 |
| `PATCH_DIR_WIN` | Windows path of the same directory | required | the same patch directory as a Windows path | as `PATCH_DIR` |
| `GENCONFIG_WIN` | Windows path of the operator's generation-config directory | required | the operator's generation-config directory, as a Windows path; mounted at /genconfig | `speed_A.sh` line 19 |
| `GSM8K_DATA` | container path `^/` | `/work/gsm8k/test.jsonl` | the GSM8K test file, as a path inside the container | `speed_A.sh` line 83 |
| `RESULTS_DIR` | WSL path, absolute; its parent must exist | required | where series results go, as a WSL path; its parent must exist | new (series output directory) |
| `PROD_CONTAINER` | name (same shape as `HF_VOLUME`); must not start with `CONTAINER_PREFIX` | `vllm` | the name of the operator's own server container | `restore_server.sh` line 14; `speed_A.sh` line 44 |
| `RESTORE_SCRIPT_WIN` | Windows path | required | the operator's start script, as a Windows path | `restore_server.sh` line 19 |
| `RESTORE_ARGS` | words separated by single spaces, at least one (quote it: it holds spaces); quotes, tabs and `*` `?` `[` are refused (the type `args`, as `EXTRA_SERVE_ARGS`) | required | the arguments of the start script that bring the operator's server back | `restore_server.sh` lines 16, 20–21 (and its `restore_args` file) |
| `CONTAINER_PREFIX` | `^[a-z0-9][a-z0-9-]{0,15}-$`: 2 to 17 characters; must not be a prefix of `PROD_CONTAINER` | `r9700tune-` | the name prefix of every test container the toolkit starts | the `vllmprtest-` literal (`ram_guard_all.sh` line 11, `restore_server.sh` line 11) |
| `RAM_MIN_MB` | integer 512..65536 | `2048` | stop the run when the free RAM of the PC falls below this many MB | `night5.sh` line 20 (`ram_guard_all.sh` line 6 had 4096) |
| `QUIET_LOAD_MAX` | decimal 0.1..64 | `4` | the 1-minute load below which the PC counts as quiet | `wait_quiet.sh` line 9 |
| `QUIET_BUSY_PATTERN` | string; empty = no process check | empty | a process command-line pattern that means the PC is busy; empty means no process check | `wait_quiet.sh` line 7 |
| `QUIET_BUSY_IGNORE` | string; a command-line substring that excludes a match | empty | a command-line substring that excludes a match of the busy pattern | `wait_quiet.sh` line 7 |
| `DISK_GATE` | enum `on` `off` | `on` | check the disk event log before each unit: on or off | `disk_gate.sh` |
| `DEADLINE` | `HH:MM` 24 h, or empty = none | empty | the clock time (HH:MM, 24 h) by which a run must be over; empty means none | `night5.sh` line 10 |
| `MAX_RUN_MINUTES` | integer 10..2880 — the ceiling when `DEADLINE` is empty or later | `720` | the ceiling of a run in minutes when DEADLINE is empty or later | new (every wait has a ceiling) |
| `READY_TIMEOUT_S` | integer 60..3235 (the largest `CLEANUP_BUDGET_S`, 3600, minus 365; was 3300 before E2.S2 decision 6) | `1200` | how long a server may take to become ready, in seconds | `wait_ready.sh` line 6 (120 × 10 s); `serve.sh` line 3 (E1.S2 decision 5) |
| `MAX_FAILED_TRIES` | integer 1..20 | `3` | how many failed tries a step gets before the run gives up; at most MAX_SERVER_STOPS | `night5.sh` line 36 (E1.S2 decision 6) |
| `MAX_SERVER_STOPS` | integer 1..10 | `3` | how many times one invocation may stop the operator's server | new (E1.S2 decision 15) |
| `CLEANUP_BUDGET_S` | integer 60..3600; cross-field: at least `READY_TIMEOUT_S` + 365 (300 for the restore, 65 for the cleanup hook) | `1565` | seconds kept free before the deadline for cleanup and restore; at least READY_TIMEOUT_S + 365 | new (E1 done-when); default 1565 since E2.S2 decision 6 (was 1500 since E1.S2 decision 8, 900 before) |
| `MOE_CHUNK_MAX_S` | integer 600..86400 | `43200` | the ceiling of one MoE tuning chunk container, in seconds | new (E2.S2 decision 7; the longest measured chunk was 214 min, a full bs-24 search was estimated at 11 h) |

## `models/<name>.env`

| Key | Type and legal values | Default | What it does | Replaces |
|---|---|---|---|---|
| `MODEL_DIR` | container path `^/` | required | the model directory, as a path inside the container | `serve.sh` line 19 |
| `SERVED_NAME` | name `^[a-z0-9][a-z0-9._-]*$` | required | the served model name | `serve.sh` line 19 |
| `MAX_MODEL_LEN` | integer 2048..1048576 (a bench needs at least 1536: 1024 input + 512 output) | required | the context length of the server, in tokens | `speed_A.sh` line 11 |
| `MAX_NUM_SEQS` | integer 1..256 | required | the number of concurrent sequences of the server | `serve.sh` line 20 |
| `GPU_MEM_UTIL` | decimal 0.10..0.95 | `0.85` | the GPU memory fraction of the server | `serve.sh` line 20 |
| `PREFILL_LENS` | list of distinct positive integers of at most 9 digits, separated by spaces; each + 128 output tokens must be ≤ `MAX_MODEL_LEN` | required | the prefill lengths to measure, in tokens; each plus 128 must fit MAX_MODEL_LEN | `speed_A.sh` line 12 |
| `MOE_DTYPE` | enum `auto` `fp8_w8a8` `int8_w8a16` `int4_w4a16` `none` | `int4_w4a16` | the weight dtype of the model's MoE layers for tuning; none means no MoE layers | `tune_chunk.sh` line 4 (`TUNE_DTYPE`), `benchmark_moe.py` line 1155 (E2.S2 decision 7) |
| `MOE_ACT_DTYPE` | enum `bfloat16` `float16` | `bfloat16` | the activation dtype the model serves, which moe-tune tunes the experts layer for: bfloat16 sets the hook MOE_TUNE_ACT_DTYPE, float16 is the benchmark's own ROCm default | new: `bfloat16` sets the benchmark's hook `MOE_TUNE_ACT_DTYPE=bfloat16`, `float16` sets no word; the draft layer is always `bfloat16`; `chunk.env` and `ab.env` record the value as `ACT_DTYPE`. The 35B model serves BF16 while the benchmark forces FP16 on ROCm (`dew_flow_benchmark` `RESULTS_vllm_029_r9700_speed_options.md` § 15.3). The default is the one measured model's; for the 27B file it is unmeasured |
| `TUNED_CONFIG_DIR` | container path `^/`, or empty | empty | the folder of tuned MoE configs, as a path inside the container; empty means none | `speed_A.sh` line 58 |
| `MOUNTS` | list of `<relative source>:<container path>[:ro]` words; the source is relative to `PATCH_DIR`, has no `..`, no leading `/`, and must exist | empty | extra mounts: <source relative to PATCH_DIR>:<container path>[:ro], separated by spaces | `serve.sh` lines 13–16 |
| `EXTRA_SERVE_ARGS` | string, split on spaces; quotes, tabs and `*` `?` `[` are refused | empty | extra arguments of the serve command, split on spaces; quotes are refused | `serve.sh` line 21 |
| `LINEAR_SHAPES` | list of `<name>:<K>:<N>:<layers>` words separated by spaces, or empty: a name of letters, digits and `. _ + -` (no space; `+` joins layers that share a shape) and once; K, N, layers positive integers of at most 9 digits; K a multiple of 8 and of `LINEAR_GROUP_SIZE`, N a multiple of 16 (cross-field for the group size). The same grammar as `parse_shapes` in `lib/linear_bench.py`; `tests/fixtures/kernels/shapes_cases.txt` feeds both | empty | the hybrid W4A16 linear shapes for linear-bench: <name>:<K>:<N>:<layers> words separated by spaces; empty means none known | `linear_bench.py` lines 22–28 |
| `LINEAR_GROUP_SIZE` | integer 32..1024 | `128` | the quantization group size of the linear shapes (every K must be a multiple of it) | `linear_bench.py` line 20 (`GS`) |

Two examples ship from the measured runs: `models/qwen3.6-35b-a3b-gptq.env` and `models/qwen3.8-27b-awq.env`. The 27B file
keeps the 35B file's `MOUNTS` and `TUNED_CONFIG_DIR` because that is how it was measured.

## `config/arms.conf`

One arm per line, four fields separated by ` | `: the arm name (`^[a-z0-9]+$`), the serve arguments, the environment
(`KEY=VALUE` words), the extra mounts (the grammar of `MOUNTS`). A `#` starts a comment line. Arguments and environment may
not contain quotes, `$` or a backtick. `--generation-config /genconfig` is NOT in the table: the server start adds it for
every arm, because MTP acceptance depends on the operator's sampling defaults. Functions: `arms_load`, `arms_names`,
`arm_args` (one argument per line), `arm_env`, `arm_mounts`, `arms_check` (the arm exists, each mount source exists under
`PATCH_DIR`).

| Arm | Serve arguments (after `--generation-config /genconfig`) | Environment | Extra mounts |
|---|---|---|---|
| base, fbase | MTP 2 | | |
| mtp1 | MTP 1 | | |
| mtp3, ra3 | MTP 3 | | |
| mnbt8k | MTP 2, `--max-num-batched-tokens 8192` | | |
| tattn | MTP 2, `--attention-backend TRITON_ATTN` | | |
| fp8kv | MTP 2, `--kv-cache-dtype fp8` | | |
| fcombo, o7ref, ta3 | MTP 3, `--attention-backend TRITON_ATTN` | | |
| ta3mb | MTP 3, `--attention-backend TRITON_ATTN --max-num-batched-tokens 8192` | | |
| fb1 | MTP 2 | `VLLM_TUNED_CONFIG_FOLDER=/work/moe/tune/merged_b1` | |
| o7 | MTP 3, `--attention-backend TRITON_ATTN` | | the `rdna_hybrid_w4a16.py` tile patch |
| ra3opt | MTP 3 | | the `rocm_attn.py` fused-draft patch |

"MTP N" is `--speculative-config.method mtp --speculative-config.num_speculative_tokens N`. The names `q27old` and
`q27new` of the old series script are dropped: with a model file they are `base` and `ta3`.
