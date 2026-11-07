# PLAN — E1 stories: ComfyUI from the repository, with one owner of the card

> Status: **plan only, nothing implemented yet, 2026-11-07.** Scope: the three stories of epic E1 of
> [PLAN_comfyui_r9700.md](PLAN_comfyui_r9700.md), section
> [E1 — ComfyUI from the repository](PLAN_comfyui_r9700.md#e1--comfyui-from-the-repository-fields-adapter-image-five-verbs-one-owner-of-the-card):
> the machine fields and three adapter calls, the GPU ownership of the card, the image and the model sets with their two verbs.
> Cornerstone: E1.S2 (`model: fable`), recorded in the parent's ledger line.

This document splits E1 into stories. It adds no scope to E1 and removes none. The parent plan keeps the change ledger; this
document has none of its own (plan-change-control: a stories document keeps no ledger).

## Stories at a glance

| Story | Title | Spec by | Code by | Depends on | Cornerstone |
|---|---|---|---|---|---|
| E1.S1 | Machine fields, a machine-only config load, three adapter calls and the stub that answers them | Opus (this document) | Sonnet | nothing in E1 | no |
| E1.S2 | One owner of the card: the admission refusal, the name rules, `comfy start\|stop\|status` | **Fable** — `model: fable` | Sonnet | E1.S1 | **yes** — the parent's area *GPU ownership* |
| E1.S3 | The image and the model sets from the repository: `comfyui/`, `comfy build`, `comfy fetch`, the documents, the acceptance on the R9700 | Opus (this document) | Sonnet | E1.S1; E1.S2 for the two verb modes | no |

Order: S1, then S2, then S3. Fable may write the S2 spec while S1 is coded (it needs only S1's interface, below). S3's
`comfyui/` files, `fetch_model.sh` and their tests may be coded once S1 is merged; its two verb modes (`build`, `fetch`) are
coded after S2 is merged, because they live in the verb S2 creates and take the lock through S2's entry. Every story is
reviewed by Opus and fixed by Sonnet (subagent-models, per-story pipeline).

**The cut, and the one change to the suggested one.** The two cross-field rules of `COMFY_CONTAINER` (no prefix, not
`PROD_CONTAINER`) are in S2, not S1: the parent's cornerstone area names "the prefix and name rules that keep
`container_stop_all` away from the operator's ComfyUI and from a fetch in progress" as part of GPU ownership, so Fable
specifies them with the refusal they protect. S1 adds the fields; S2 adds the rules between them.

## Coverage — every E1 item is in exactly one story

The parent's E1 *Scope* and *Done when*, item by item. Where a later story extends a file an earlier one creates, the row says
which part each writes. Nothing below is in two stories.

| E1 item (parent plan) | Story | The other stories' part |
|---|---|---|
| The field table: the twelve `COMFY_*` keys, the type `win?` (and `ref`, for "a git tag word") | S1 | — |
| A machine-only config load (`comfy` has no vLLM model; `config_load` needs a model file, `lib/config.sh:393`) | S1 | S2 and S3 call it |
| The two cross-field rules of `COMFY_CONTAINER` (and the same rules for the fetch name derived from it) | S2 | — |
| The three adapter calls `wslc_build`, `wslc_volume_list`, `wslc_volume_create`; the stub learns `build`, `volume list`, `volume create` | S1 | S2 and S3 add the stub answers of their own containers (readiness, the check container, the fetch container) |
| The admission refusal of every existing GPU verb while `COMFY_CONTAINER` is listed (prepare, before any stop; every admission in `step_run`) | S2 | — |
| `lib/comfy.sh` and the verb `bin/r9700 comfy` with its mode dispatch; the modes `start`, `stop`, `status` | S2 | S3 adds the modes `build` and `fetch` to the same dispatch |
| `comfyui/Containerfile`, `comfyui/entrypoint.sh`, `comfyui/fetch_model.sh`, `comfyui/models.conf` moved in with the machine values taken out; `comfy_assets` placement through `moe_place` | S3 | — |
| `comfy build` (the lock, the placement, `wslc_build`, the check container) and `comfy fetch` (its own lock, not the GPU lock; no GPU; the non-prefixed name) | S3 | the lock entry and the owner check it calls are S2's |
| The tests of the Tests section for these items, and the `fetch_model.sh` fixtures | each story its own | — |
| `research/module_config.md` (the fields) | S1 | S2 writes the rule text into the `COMFY_CONTAINER` row |
| `research/architecture.md` (a module row, a verb row, the exit table) | S2 (the rows exist the moment `lib/comfy.sh` and `verb_comfy` do: `tests/test_docs.sh:141`, `:154`) | S3 extends both rows with `build`, `fetch` and the `comfyui/` files, and the exit row 1 |
| `research/module_tests.md` (rows, the flow catalogue, the knobs, what it does not prove) | each story its own rows | — |
| `README.md`: the `bin/r9700 comfy` line of *The commands* (`tests/test_docs.sh:154`) | S2 | S3 writes the ComfyUI section |
| `research/module_comfyui.md` (new: purpose, the three traps with their evidence, the flows, the Mermaid diagram, the growth); its `research/README.md` row (`tests/test_docs.sh:101`) | S3 | S2's flows are written from S2's merged code |
| The growth rows of the volumes and the placed copies | S3 (in `research/module_comfyui.md`) | — |
| The three acceptance runs: the real build (its check container prints the R9700), the real start with a `zimage` smoke, the real fetch | S3 (the record) | run by the operator's session, after S2 and S3 are merged |
| The seam check and the personal-path check over the new files; CI green | every story | — |

Out of E1 (E2, E3; not to be built here): `comfyui/bench.py`, `comfyui/arms.conf`, `comfy bench`, the verdict mode of
`lib/verdict.py`, the bench cache, the results folder, `research/ACCEPTANCE_comfy_<date>.md`, `POST_DEPLOY.md`. No document
written in E1 describes `bench` (the documents of the system as it is may not say that something is still to come:
`tests/check_static.sh:32`).

## Facts every story uses (read 2026-11-07)

**The operator's hand-made folder** (outside every repository; the main session gives a coder or a spec writer its location —
it is not written in a tracked file). It holds the behaviour to keep:

- `Containerfile`, 57 lines. Lines 11–14 `ARG BASE` / `FROM` / `ARG COMFYUI_REF`; 17–19 the apt packages; 23–26 the ROCm
  constraints file; 28–30 the clone and the two requirement files; 32–33 the entrypoint; 35–44 the volume comments and the
  trap-1 comment (`PYTORCH_HIP_ALLOC_CONF` NOT set, with the observation); 45–52 the `ENV` block; 54–57 `WORKDIR`, `EXPOSE`,
  `ENTRYPOINT`, `CMD`. **Machine values to take out:** lines 6–7 (the build and start commands name the operator's folder) and
  the fallback note of lines 8–9.
- `entrypoint.sh`, 46 lines. Lines 5–9 the folders of `/data`, `/cache` and `/models`; 14–26 the venv (another Python version
  is moved aside to `venv.python-<version>.<UTC stamp>`, never deleted); 31–39 the Manager's `use_uv = False` (trap 2) in its
  three starting states; 41–46 the `exec` of `main.py`. No machine value.
- `tests/fetch_model.sh`, 47 lines. Pairs `<dir> <url>`; line 10 refuses without `/store`; line 25 reads `X-Linked-ETag`;
  line 26 refuses a source that publishes none; 28–45 store first, then the local copy, each checked; 35 the resumable
  download. **Machine values to take out:** lines 3, 7–8 and 10 (the store's drive letter and share, the operator's folder).
- `start-comfyui.ps1`, 111 lines. Lines 43–57 the vLLM check (`wslc inspect`) and `-StopVllm`; 59–61 `wslc stop` and
  `wslc remove` of an old container; 62–65 `wslc volume list` and `wslc volume create` of the three volumes; 67–84 the run
  argv (`--gpus all`, `-p <port>:8188`, the three volumes, a `tests` mount, `--shm-size 8g`, the output mount, `-e` words, `-d`);
  86–96 the retry after "already in use" with `wslc system session terminate`; 102–111 a backup of the folder to the
  operator's NAS. **Not moved in:** the backup (the repository is the copy now), the session terminate (it stops EVERY
  container of the session, the operator's vLLM and a night run included), the interactive `-it` mode, the `tests` mount.
- The folder's `tests/` also holds `bench.py` (E2's), `kitchen_caps.py` (a one-off probe of the comfy-kitchen backends; its
  observation is in the parent) and `smoke_txt2img.py` (a hand smoke; E1's smoke is the browser run of S3). None is moved in by E1.

**The `wslc` calls.** The argv shapes of `wslc build -t <tag> -f <file> <context>`, `wslc volume list`, `wslc volume create
<name>` and `--entrypoint <program>` are taken from the hand-made files above, where the operator ran them. Their OUTPUT
shapes were observed on the operator's PC on 2026-11-07 (`wslc` through `pwsh.exe`):

- `wslc volume list` prints a header `DRIVER    VOLUME NAME` and one line per volume, `guest     <name>` (the driver is
  `guest`, not Docker's `local`); the name is the last column.
- `wslc volume create <name>` for a volume that EXISTS exits **1** and prints `Cannot create a file when that file already
  exists.` and `Error code: ERROR_ALREADY_EXISTS` — not Docker's silent 0. So a caller lists first and creates only a missing
  volume, and the stub (SB2) answers an existing name with exit 1 and those two lines.
- `wslc volume inspect <name>` prints a JSON array with `CreatedAt`, `Driver`, `Mountpoint`, `Name`; no size.
- `wslc inspect <image>` prints a JSON array with the image's `Created` (UTC, ISO 8601); `wslc image list` has a `CREATED`
  column in relative words ("3 hours ago"), not a time.
- `wslc remove <container>` exists (aliases `rm`, `delete`).

The S3 acceptance records the real outputs once more; a shape that differs from S1's parse is a fix and a deviation.

**The model files** (read with `curl -sIL <url>` on 2026-11-07). Every URL below the Comfy-Org names the caller gave answers
`307` to a renamed repository (`stable-diffusion-v1-5-archive` → `stable-diffusion-1.5`, `z_image_turbo` → `Z-Image-Turbo`,
`Wan_2.2_ComfyUI_Repackaged` → `Wan-2.2`, `Wan_2.1_ComfyUI_repackaged` → `Wan-2.1`), then `302` to the CDN with
`x-linked-etag` (the sha256) and `x-linked-size`. `comfyui/models.conf` pins the renamed (current) names, so a fetch does not
depend on a redirect the source may drop; S3's brief has the table.

**The static checks a new file meets** (`tests/check_static.sh`). The personal-path scan (`:19`) runs over every tracked
file: no profile path, no home directory. Every `*.sh` gets `bash -n` and every `*.py` a compile (`:130–139`), so
`comfyui/*.sh` and the test fixtures are checked. The seam (`:78`): in the CODE lines of `lib/*.sh` and `bin/*` only
`lib/adapter.sh` may expand `$R9700_WSLC` or name `wslc` as a command word — a description in `lib/config.sh` or a message in
`lib/comfy.sh` that says "the ceiling of one wslc build" is a finding; write "the build" instead. `README.md`,
`research/architecture.md`, `research/module_tests.md` and `research/module_config.md` may not contain the word `planned`,
`E3 will` or `not built yet` (`:32`).

**Test knobs** are read from the environment only, never from `machine.env`, and each gets a row in the *Test knobs* table of
`research/module_tests.md` (the shape of `R9700_ARMS_CONF`, `lib/series.sh:44`). Stub answers live under `$R9700_STUB_DIR`
and are listed in the header of `tests/stubs/stub_common.sh` (`:5–22`).

**Test leftovers.** A test writes only below its `$R9700_TEST_ROOT`; no `mktemp`, `mkdtemp` or `TMPDIR` (the leftovers
guard's raw-temp class); a process a test starts is recorded like a stub container (`tests/run.mjs`, `PID_FOLDER`) so the
runner kills it when the test dies.

**Public repository.** No personal path, account name, machine name or share address in a tracked file. Examples and fixtures
use placeholders (`X:\comfy-out`, `X:\models-store`, `C:\r9700\work` as the existing examples do).

---

## E1.S1 — Machine fields, a machine-only config load, three adapter calls and the stub that answers them

**Cornerstone:** no. **Depends on:** nothing in E1. **Spec:** this section (Opus). **Code:** one Sonnet coder.

### Goal

Every machine value of ComfyUI is a validated, documented, optional field of `machine.env` with the default the hand-made
setup used, so an existing `machine.env` stays valid; a verb that has no vLLM model can load the machine file alone; and the
three `wslc` calls ComfyUI needs exist in the adapter seam, with ceilings, and are answered by the CI stub. No behaviour of an
existing verb changes.

### Files

| File | Change |
|---|---|
| `lib/config.sh` | twelve `_field machine COMFY_*` lines after `MOE_CHUNK_MAX_S` (`:65`); the types `win?` and `ref` in `_cfg_check` (`:227`), `_cfg_legal` (`:198`) and the type comment (`:27`); `config_load_machine` beside `config_load` (`:393`), with `_cfg_fill_and_check` (`:325`) and `_cfg_cross` (`:350`) taking a scope instead of being copied |
| `machine.env.example` | the twelve keys, each commented out at its default, under its description line |
| `lib/adapter.sh` | `wslc_build`, `wslc_volume_list`, `wslc_volume_create` after `wslc_logs` (`:329`); the header table (`:7–20`); `_adapter_name_ok` (`:245`) widened with an optional noun |
| `tests/stubs/wslc` | `build` and `volume list\|create` in the dispatch (`:297–338`) |
| `tests/stubs/stub_common.sh` | the header lines of the new stub files (`:5–22`) |
| `tests/test_config.sh` | scenarios CF1–CF9; two `TYPE_CASES` rows (`:475`) |
| `tests/test_adapter.sh` | scenarios AD1–AD6; AD7 and AD8 extend `:297` and `:84` |
| `tests/test_stubs.sh` | scenarios SB1–SB3 |
| `research/module_config.md` | twelve rows in the `## machine.env` table (`:30`); `win?` and `ref` in *Rules every file follows* (`:15`) |
| `research/module_tests.md` | the new scenario ids in the rows of the three test files; the stub files in *Test knobs*; the three functions in the adapter line of *What it does not prove* (`:216`), with the unverified output shapes |

### The fields

All `machine` scope, all optional, in this order after `MOE_CHUNK_MAX_S`. The description is the one string the example
comment and the doc column repeat exactly (`tests/test_config.sh:635`); it holds no `"`, `$`, backtick, and not the word
`wslc` (the seam).

| Key | Type | Default | Description |
|---|---|---|---|
| `COMFY_IMAGE` | `image` | `comfyui-r9700:local` | the image comfy build writes and every comfy container runs |
| `COMFY_BASE_IMAGE` | `image` | `rocm/pytorch:rocm10.1.0_ubuntu24.04_py3.12_pytorch_release_2.13.0` | the base image of comfy build (its BASE argument) |
| `COMFY_REF` | `ref` | `v0.44.0` | the ComfyUI git tag the build clones |
| `COMFY_CONTAINER` | `name` | `comfyui` | the name of the operator's own ComfyUI container |
| `COMFY_PORT` | `int:1024:65535` | `8188` | the Windows loopback port the operator's ComfyUI is published on |
| `COMFY_MODELS_VOLUME` | `name` | `comfy-models` | the volume that holds the models ComfyUI reads |
| `COMFY_DATA_VOLUME` | `name` | `comfy-data` | the volume that holds custom nodes, workflows, inputs and the venv of the operator's ComfyUI |
| `COMFY_CACHE_VOLUME` | `name` | `comfy-cache` | the volume that holds the MIOpen and Triton caches of the operator's ComfyUI |
| `COMFY_OUTPUT_WIN` | `win?` | empty | a Windows folder mounted at /data/output so results appear in Windows; empty means they stay in the data volume |
| `COMFY_STORE_WIN` | `win?` | empty | the master model store comfy fetch writes first, as a Windows path; empty means straight into the models volume |
| `COMFY_BUILD_MAX_S` | `int:600:14400` | `5400` | the ceiling of one comfy build, in seconds |
| `COMFY_FETCH_MAX_S` | `int:600:86400` | `21600` | the ceiling of one comfy fetch container, in seconds |

`ref` is the parent's "a git tag word": `^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$`, legal text `a git tag: letters, digits, . _ -
(starting with a letter or digit), at most 64 characters`. Not `name`: `name` refuses an upper-case tag. The value reaches
`git clone --branch` inside a `RUN` line of the Containerfile, so the type admits no shell character. `win?` is `win` or empty,
legal text `X:\…, or empty`.

"Replaces" column of `module_config.md` (the hand-made files by name and line, never by path): `COMFY_IMAGE` `start-comfyui.ps1`
line 32; `COMFY_BASE_IMAGE` `Containerfile` line 11; `COMFY_REF` `Containerfile` line 14; `COMFY_CONTAINER`
`start-comfyui.ps1` line 41; `COMFY_PORT` line 31; the three volumes lines 63 and 71–73; `COMFY_OUTPUT_WIN` lines 37 and 77–80;
`COMFY_STORE_WIN` `fetch_model.sh` lines 3 and 7; the two ceilings: new (every wait has a ceiling).

### Test scenarios

"The machine fixture" is `tests/fixtures/config/machine.env.in` as `setup_case` (`tests/lib/stubcase.sh:31`) or the config
tests' own `machine` helper writes it; it names no `COMFY_*` key and is not changed. A "variant" is the fixture with one line
added or changed by the test. RED first means: the test is written and run before the code it needs, and the failure message
is the real symptom (recorded in the coder's summary).

**Config (`tests/test_config.sh`)**

- CF1 *The comfy fields load at their defaults from a machine file that names none of them.* Machine fixture, the 35B model:
  `config_load` returns 0, no stderr; for every key of `config_keys` whose name starts `COMFY_` (the list is DERIVED), the
  exported `R9700_<KEY>` equals its default (`""` printed for empty). Parity: `R9700_COMFY_PORT=8188`,
  `R9700_COMFY_CONTAINER=comfyui`, `R9700_COMFY_REF=v0.44.0`. The derived list is asserted to contain `COMFY_IMAGE` (the scan
  is alive). RED first: before the `_field` lines the derived list is empty.
- CF2 *An optional Windows path is empty or a Windows path, and nothing else.* `COMFY_OUTPUT_WIN=` loads with the value
  empty; `COMFY_OUTPUT_WIN="X:\comfy out"` loads; `COMFY_STORE_WIN=/mnt/x/store` returns 2 with one line containing
  `COMFY_STORE_WIN: "/mnt/x/store" is not a Windows path; legal: X:\…, or empty`; `COMFY_STORE_WIN=X:` returns 2. RED first:
  the type-table test `t_every_field_type_has_a_refusal_and_a_boundary_good_value_and_the_loader_applies_them` (`:496`) fails
  with `add a row for the type "win?" to TYPE_CASES` once the field exists; then the row
  `'win?|machine|COMFY_OUTPUT_WIN|COMFY_OUTPUT_WIN=|COMFY_OUTPUT_WIN=X:'` is added.
- CF3 *A git tag is one safe word.* `COMFY_REF=V1.2_rc-3` loads; a 64-character tag loads and a 65-character one is refused;
  `COMFY_REF=v1/x`, `COMFY_REF=-v1`, `COMFY_REF="v1 v2"`, `COMFY_REF=v1;x` are each refused with exit 2 and the legal text
  above. TYPE_CASES row `'ref|machine|COMFY_REF|COMFY_REF=V1.2_rc-3|COMFY_REF=v1/x'` (RED first as in CF2).
- CF4 *The port and the two ceilings keep their ranges.* `COMFY_PORT` 1024 and 65535 load, 1023 and 65536 are refused with
  `outside 1024..65535`; `COMFY_BUILD_MAX_S` 600 and 14400 load, 599 and 14401 are refused; `COMFY_FETCH_MAX_S` 86400 loads,
  86401 is refused.
- CF5 *The image fields refuse what is not an image reference.* `COMFY_IMAGE=Comfy:local` and
  `COMFY_BASE_IMAGE=rocm/pytorch` (no tag) each return 2 naming the key.
- CF6 *The documents follow the table.* No new test: the existing `:435` (every field documented), `:443` and `:453` (the
  example holds every key, optional ones commented out), `:465` (the example loads) and `:635` (the example comment and the
  doc column equal the description) cover the twelve keys by derivation. Each is seen RED after the `_field` lines and before
  the doc rows and example lines exist (the coder records the failing lines), then green.
- CF7 *The machine file loads alone.* `config_load_machine <fixture>` returns 0 with no stderr; `R9700_COMFY_CONTAINER`,
  `R9700_WORK_DIR`, `R9700_PROD_CONTAINER` are set; `R9700_MODEL_DIR`, `R9700_SERVED_NAME` and `R9700_PREFILL_LENS` are unset
  (`${R9700_MODEL_DIR+set}` is empty) — also when a full `config_load` ran earlier in the same shell (the reset, `:265`).
- CF8 *Named for the refuted approach:*
  `t_loading_the_machine_through_config_load_with_no_model_file_would_refuse_and_that_is_the_point` — `config_load <fixture> ""`
  returns 2 with a `cannot read` line and `MODEL_DIR: required`; `config_load_machine <fixture>` on the same file returns 0.
  RED first: a first `config_load_machine` that calls `config_load "$1" ""` fails CF7 with these lines.
- CF9 *A machine-only load keeps every machine rule and reports in one pass.* Variants: `PROD_CONTAINER=r9700tune-vllm`
  → 2 with the `PROD_CONTAINER` cross-field line (`:375`); `MAX_FAILED_TRIES=5` → 2 (`:380`); `MODEL_DIR=/x` in the machine
  file → 2, `MODEL_DIR: unknown key`; both `RAM_MIN_MB=x` and `COMFY_PORT=1` → exactly two `config:` lines; a missing file →
  2 with one `cannot read` line. The full load is unchanged: every existing scenario of the file passes without an edit
  other than the two `TYPE_CASES` rows.

**Adapter (`tests/test_adapter.sh`)** — `setup_case` puts the stubs first on `PATH`.

- AD1 *`wslc_build` hands every word on as one argument and prints every line.* `answers/build.log` holds 60 lines with CRLF
  ends. `wslc_build 100 -t img:x -f 'X:\a b\Containerfile' --build-arg BASE=b:1 'X:\a b'` returns 0; `argv_of wslc` gives
  exactly the eight words `build -t img:x -f X:\a b\Containerfile --build-arg BASE=b:1 X:\a b`; stdout has the 60 lines and no CR.
- AD2 *A failing build returns its own code and still prints.* `answers/build_rc` 3: `wslc_build` returns 3 and prints the log.
- AD3 *`wslc_build` refuses a bad ceiling or no words before any call.* `wslc_build x -t a`, `wslc_build 0 -t a` and
  `wslc_build 100` each return 2 with one line starting `wslc_build:`, and `calls.log` holds no `build` line. RED first: the
  call path is written first and the test shows a `build` line in the log; then the checks are added.
- AD4 *A hung build is killed at its ceiling and leaves no process.* The shape of
  `t_wslc_run_once_is_killed_at_its_ceiling_and_leaves_no_process` (`:595`) with `wslc_build`: `mode` is `hang`, the return is
  124 (or 137), no recorded hung sleeper is alive afterwards.
- AD5 *`wslc_volume_list` prints the names, one per line.* Stub volumes `comfy-models` and `comfy-data`: the output is
  `comfy-data` and `comfy-models` (the stub's order), no header, no CR. No volume: empty output, 0. `fail-volume-list` 1:
  non-zero, nothing on stdout.
- AD6 *`wslc_volume_create` creates exactly the named volume.* `wslc_volume_create comfy-cache` returns 0, `argv_of wslc`
  is `volume create comfy-cache`, and `wslc_volume_list` then lists it. `wslc_volume_create -x`, `''` and `'a b'` each return
  2 with one line naming `wslc_volume_create` and `volume name`, and no call is made. `answers/volume_create_rc` 1: returns 1
  and prints the stub's line.
- AD7 *The ceilings are the documented ones.* `t_the_ceiling_is_the_documented_one_for_each_function` (`:297`) also calls
  `wslc_build 77 -t a`, `wslc_volume_list` and `wslc_volume_create v`; the expected sequence gains `5 77 5 60 5 60`.
- AD8 *No carriage return from the new functions.* `t_carriage_returns_are_removed_by_every_adapter_function` (`:84`) calls
  the three and asserts no CR in each output.
- (The seam: `tests/test_static.sh` runs `bash tests/check_static.sh --seam` as it is; the new functions keep it at exactly
  `lib/adapter.sh`.)

**Stub (`tests/test_stubs.sh`)**

- SB1 *The stub's build is logged and answers as scripted.* Default: three lines with CRLF ends, exit 0; with
  `answers/build.log` that file with CRLF ends; with `answers/build_rc` that code; with `answers/build_seconds` 1 it answers
  after about a second. The call is in `calls.log` and `calls.argv`.
- SB2 *The stub keeps volumes as files.* `wslc volume create a` makes `$R9700_STUB_DIR/volumes/a` and prints `a` with CRLF;
  `wslc volume list` prints the header `DRIVER    VOLUME NAME` and one `guest     a` line; creating `a` again exits 1 with
  `Cannot create a file when that file already exists.` and `Error code: ERROR_ALREADY_EXISTS` (observed on the real `wslc`,
  2026-11-07), and the list still holds one `a`; callers create only a volume the list does not hold.
- SB3 *An unknown or incomplete volume call is refused.* `wslc volume frob` and `wslc volume create` (no name) exit 2 with one
  `stub: wslc:` line.

### Brief for the Sonnet coder

Read first: this section and *Facts every story uses*; the parent's *New `machine.env` fields*; `lib/config.sh` whole;
`lib/adapter.sh:1–30` and `:208–334`; `tests/stubs/wslc:143–173` and `:297–338`; `tests/stubs/stub_common.sh`;
`tests/lib/stubcase.sh`; the tests named in the scenarios. Do not touch the lifecycle, the step, or any verb.

**1. `lib/config.sh`.**

- The twelve `_field machine …` lines of the table above, after line 65, in that order; the descriptions verbatim.
- `_RE_REF='^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'` beside the other expressions (`:81–89`). In `_cfg_check`: `'win?') [[ -z $v ||
  $v =~ $_RE_WIN ]] || _PE="\"$v\" is not a Windows path" ;;` and `ref) [[ $v =~ $_RE_REF ]] || _PE="\"$v\" is not a git tag" ;;`.
  In `_cfg_legal` the two legal texts above. Add both to the type comment of line 27.
- `config_load_machine <machine.env>`: the machine scope alone. Do NOT copy the loops: give `_cfg_fill_and_check` and
  `_cfg_cross` one argument, the scope (`all` default, or `machine`). In `machine` scope the fill loop skips every key whose
  `_F_SCOPE` is `model`, and `_cfg_cross` skips the three rules that read a model key (`PREFILL_LENS`, `MOUNTS`,
  `LINEAR_SHAPES`, `:353–374`); the machine rules (`:375–390`) run in both. Export only the machine keys; `_cfg_reset`
  already unsets every key. `config_load` keeps its behaviour exactly (it passes `all`).
- Nothing else in the file changes; no `COMFY_*` default appears anywhere but the `_field` line.

**2. `machine.env.example`** — after the `MOE_CHUNK_MAX_S` block, one block per key in table order: the description as a
`# ` line, then `# KEY=<default>` (empty: `# COMFY_OUTPUT_WIN=`), a blank line between blocks, the shape of `:57–91`.

**3. `research/module_config.md`** — twelve rows in the `## machine.env` table, the columns as the existing rows: Key, Type and
legal values (written out: `image reference …`, `name (same shape as HF_VOLUME)`, `a git tag …`, `Windows path, or empty`,
`integer 1024..65535`), Default, What it does (the description, exactly), Replaces (the list above). In *Rules every file
follows*, one sentence each for `win?` and `ref`. S2 adds the rule text of `COMFY_CONTAINER`; leave that cell to the rule's
author (write only the type).

**4. `lib/adapter.sh`.** After `wslc_logs`, each function starting with `_adapter_drop_lock`, the shapes of the neighbours:

- `wslc_build <ceiling-s> <args...>` — the checks of `wslc_run_once` (`:280–290`: a positive integer ceiling, at least one
  word; 2 and one `wslc_build:` line), then `_adapter_call --merge "$_adapter_ceiling" "$R9700_WSLC" build "$@" | tr -d '\r' 9>&-`
  and `return "${PIPESTATUS[0]}"`. Every line is printed as it comes; nothing is cut (a caller that wants a tail cuts it).
- `wslc_volume_list` — `_adapter_call --quiet 60 "$R9700_WSLC" volume list | tr -d '\r' 9>&- | awk 'NR > 1 && NF { print $NF }' 9>&-`,
  the parse of `wslc_list` (`:305–309`): the last column after the header. A comment says the shape was observed once by hand on 2026-11-07 (Facts), never by the suite,
  and is checked by E1's acceptance.
- `wslc_volume_create <name>` — `_adapter_name_ok wslc_volume_create "${1:-}" "volume name" || return 2`, then
  `_adapter_call --merge 60 "$R9700_WSLC" volume create "$1" | tr -d '\r' 9>&-`, `return "${PIPESTATUS[0]}"`.
- `_adapter_name_ok <function> <name> [<what>]`: the third argument defaults to `container name`; the message becomes
  `<function>: "<name>" is not a <what> (letters, digits, . _ -; no leading -)`. Every existing caller is unchanged.
- Three rows in the header table (`:7–20`): `wslc_build <ceiling-s> <args...>` (the argument), `wslc_volume_list` (60 s),
  `wslc_volume_create <name>` (60 s).

**5. The stub.** In `tests/stubs/wslc`'s dispatch: `build) shift; build_image "$@" ;;` and `volume) shift; volume_call "$@" ;;`.

- `build_image`: sleeps `$(moe_answer build_seconds 0)` first (a sleeper in the background and `wait`, the shape of
  `linear_bench`, `:82–84`, so a ceiling ends it), then prints `answers/build.log` with CRLF ends (`sed "s/\$/$CRLF/"`), else
  three lines `stub build line <n>` with CRLF; returns `$(moe_answer build_rc 0)` (`moe_answer`, `:104`, is the existing
  reader of a one-line answer; reuse it). `mode` `hang` already applies to every call (`stub_mode_if_asked`, `:8`).
- `volume_call list`: `fail-volume-list` — a count, the next that many lists exit 1 with one `stub:` line (the counting shape
  of `fail-list`, `:193–203`, for this file); else the header `DRIVER    VOLUME NAME` and `guest     <name>` per file of
  `$R9700_STUB_DIR/volumes/`, sorted, CRLF ends. `volume_call create <name>`: no name → exit 2; `answers/volume_create_rc`
  non-zero → one `stub: volume create failed (scripted)` line and that code; else `stub_mkdir "$R9700_STUB_DIR/volumes"`,
  `: > volumes/<name>`, prints the name. Anything else → exit 2 `stub: wslc: unknown volume subcommand "<x>"`.
- The header of `stub_common.sh` gains `volumes/<name>`, `fail-volume-list`, `answers/build.log`, `answers/build_rc`,
  `answers/build_seconds`, `answers/volume_create_rc`.

**6. Documents.** `research/module_tests.md`: the scenario ids in the rows of `tests/test_config.sh`, `tests/test_adapter.sh`,
`tests/test_stubs.sh`; one *Test knobs* row per stub file of step 5; the three functions in the adapter line of *What it does
not prove*, with the sentence that the output shapes of `volume list` and `volume create` are taken from the hand-made
script and not from `wslc` itself.

**Commands.**

```bash
node tests/run.mjs tests/test_config.sh tests/test_adapter.sh tests/test_stubs.sh   # the three files
node tests/run.mjs                                                                  # every test
bash tests/check_static.sh                                                          # syntax, personal paths, seam, documents
node .agents/conventions/tools/leftovers-check.mjs --repo . --token r9700 --identity "the R9700 vLLM tuning toolkit" --profile node
node .agents/conventions/tools/plan-lifecycle.mjs
```

Report the runner's PASS line per file and its total, the static check's exit code, and each RED observation of the
scenarios marked RED first (the failing line, then the pass).

### Done when

- CF1–CF9, AD1–AD8 and SB1–SB3 pass through `node tests/run.mjs`; every other test passes unchanged; each RED observation is
  in the summary.
- Every new field has its default, type and description in `lib/config.sh`, `machine.env.example` and `module_config.md`
  (the derived tests prove it); an existing `machine.env` without a `COMFY_*` key loads unchanged.
- `bash tests/check_static.sh` exits 0 (the seam is still exactly `lib/adapter.sh`); CI green.

---

## E1.S2 — One owner of the card: the admission refusal, the name rules, `comfy start|stop|status` (cornerstone, `model: fable`)

**Cornerstone:** **yes** — the parent's E1 area *GPU ownership*. **Depends on:** E1.S1 (`config_load_machine`,
`wslc_volume_list`, `wslc_volume_create`, the twelve fields). **Spec:** this section (Fable, cornerstone). **Code:** one Sonnet
coder; review Opus.

### Goal

While the operator's ComfyUI (`COMFY_CONTAINER`) is listed, no GPU verb of the toolkit starts a run beside it: each refuses
with exit 2 and one line naming `bin/r9700 comfy stop`, before anything is stopped, and again at every admission of a long
run. `bin/r9700 comfy start` brings the operator's ComfyUI up under the toolkit's lock, held through the readiness wait, so
no check-then-start window is left; a start that does not become ready leaves nothing running and puts the operator's vLLM
back when this invocation stopped it — and "nothing running" is decided by the container list, never by what the launch
call returned: a detached run the engine completed while the client timed out, returned non-zero or was cut by a signal is
found listed, stopped, and only then is vLLM restored. `comfy stop` and `comfy status` work without the lock. No verb ever
stops the operator's ComfyUI by itself, and the cleanup of a run never reaches it or a fetch in progress. And the one place
that starts the operator's vLLM — the restore from the recovery marker — never starts it beside the operator's ComfyUI
either. The locked entry the modes share has a card-free admission for a mode that needs the card without taking either
owner down (S3's `build`): it refuses, before the body starts, while EITHER the operator's ComfyUI or the operator's vLLM is
listed, naming what to stop.

### Scope

In (the parent's verb section *One owner of the card at a time, decided under the lock*, its verb-table rows `start`, `stop`,
`status`, and the cornerstone area):

- The refusal of every existing GPU verb while `COMFY_CONTAINER` is listed. It lives in ONE function, `comfy_owner_check`
  (`lib/run_guarded.sh`), called from two places: `supervise` right after the prepare returned 0 (`lib/run_guarded.sh:440`:
  the config is loaded there, the deadline, the run folder and the traps are not yet made, nothing is stopped), and
  `_step_admit` right after the container list is read (`lib/step.sh:114–115`, before the stop cap, the marker and the stop).
  Every `supervise` user is a GPU verb for this rule: `step`, `series`, `moe-tune chunk|ab|activate`, `linear-bench`,
  `prefixtest`, `run` (the code lines of `bin/r9700` that read `supervise <verb> …`; the test derives the set from them,
  OC1). `activate` is refused too, `--force` or not: it already refuses while any container is listed (`lib/moe_verb.sh:225`),
  and one rule for every `supervise` invocation is simpler than an exception for the one that uses no card. `verdict`,
  `moe-tune merge`, `init` and the three `comfy` modes of this story are not under `supervise` and are unchanged by this
  check; `init` keeps stopping the prefixed containers only (`bin/r9700:134–137`).
- The restore's own half of the rule. `supervise` runs `restore_first` BEFORE the prepare (`lib/run_guarded.sh:438–440`), on
  purpose: a broken config must not block a restore (`bin/r9700:6–8`). So with a recovery marker left by a hard-killed run
  and the operator's ComfyUI started by hand since, the restore would start the operator's vLLM beside ComfyUI before any
  prepare-stage check could run — and `init`, `verdict`, `moe-tune merge` and the end-of-run `cleanup_once` run the same
  restore. The check therefore sits INSIDE the restore, config-free, the way every other value of the restore is
  (decision 3: the marker carries what the restore needs): `marker_write_base` records `COMFY_CONTAINER` as an optional key
  (`lib/restore.sh:115–124`; a marker without it, written by an older version, has no check), and `restore_from_marker`
  (`lib/restore.sh:278–289`), after `_restore_prepare` stopped the worker and every prefixed container and listed, refuses to
  START the server while the marker's `COMFY_CONTAINER` is in that listing: one line naming `bin/r9700 comfy stop`, the marker
  stays, return 5 (the code of "the restore did not finish"). Nothing of the toolkit's is left on the card, the operator's
  vLLM is still owed and recorded, and the next invocation after `comfy stop` restores. `comfy start` meets the same marker
  with the same order: lock, `restore_first`, then its config and checks (RM2, CS14).
- The cross-field rules: `COMFY_CONTAINER` must not start with `CONTAINER_PREFIX` and must differ from `PROD_CONTAINER`, in
  `_cfg_cross` beside the `PROD_CONTAINER` rule (`lib/config.sh:375`), because `container_stop_all` (`lib/restore.sh:152`,
  the prefix match at `:160`) and `init_check_containers` (`bin/r9700:126`) stop every prefixed container. The same two rules
  for the fetch name `<COMFY_CONTAINER>-fetch` that S3 uses (with `CONTAINER_PREFIX=r9700tune-`, a `COMFY_CONTAINER=r9700tune`
  passes the first rule while its fetch name `r9700tune-fetch` is prefixed; a `PROD_CONTAINER=comfyui-fetch` would be stopped
  as the operator's server). The suffix is ONE constant, `_COMFY_FETCH_SUFFIX` in `lib/config.sh`, which `comfy_fetch_name`
  (`lib/comfy.sh`) uses too, so S3 builds the name nowhere else.
- `lib/comfy.sh` (new), sourced by `bin/r9700` (the library list, `:32`); `verb_comfy` in `bin/r9700` with its mode dispatch
  over the functions `comfy_mode_<mode>` of `lib/comfy.sh` (the legal-modes list derived from `declare -F`, the shape of
  `verb_commands`, `bin/r9700:75–77`, never typed), so S3 adds `build` and `fetch` as two functions; the lock entry
  `comfy_locked <mode> <admit> <body function> [args...]` the modes that take the lock share (lock, restore-first, the machine
  config, the admission named by `<admit>`, the body, the release; S3's `build` uses it).
- The two-owner check of the entry. `<admit>` is one of two words: `body` (the body admits itself: `start`, whose steps 2–4
  decide between a listed ComfyUI, a listed vLLM and `--stop-vllm`) and `card-free` (the entry refuses while EITHER owner is
  listed: `build`, which runs its GPU check container under the lock and stops nobody). `card-free` is a second check
  function, `comfy_owners_check <listing>` (`lib/run_guarded.sh`, beside `comfy_owner_check`): the owner line of ComfyUI when
  `COMFY_CONTAINER` is a whole line of the listing, else the server line `r9700: the operator's server (<PROD_CONTAINER>) is
  listed and holds the card; stop it by hand first (no verb of the toolkit stops it for a build)` when `PROD_CONTAINER` is,
  else 0. It runs right after the machine config is loaded and BEFORE the body (a build takes minutes; a refusal after it is
  waste): exit 2, one line, the body never called — no placement, no `build` call, no check container. The recovery-marker
  case is correct as it falls out of the order lock → `restore_first` → config → check: a marker that records vLLM as owed
  restores it FIRST (`bin/r9700:6–8` holds for every verb), and the check then refuses because vLLM is now listed — the
  operator's server is back and the line names it; a marker beside a listed ComfyUI ends the entry at 5 by `restore_first`'s
  own exit (the RM2 line), before the check. S3's own `build` scenario is S3's; S2 proves the entry and the function (OC6–OC8).
- `comfy start [--stop-vllm] [-- <main.py args>]`, `comfy stop`, `comfy status`, exactly as the parent's verb table says,
  with the machine config only (`config_load_machine`).
- The readiness of ComfyUI: `ready_wait` (`lib/restore.sh:177–213`) probes vLLM through `restore_probe` (`/v1/models` and a
  completion, `lib/adapter.sh:38–67`, `:378–382`) and looks for the last word `completion`. It is NOT copied: it takes three
  optional arguments (the probe function, the ready word, the line prefix), defaulting to what it does today, and sets three
  variables the caller may read (`READY_ANSWER`, `READY_LINE`, `READY_ELAPSED_S`). ComfyUI's probe is `comfy_probe <name>` in `lib/adapter.sh`:
  ONE Python program (`_COMFY_PROBE_PY`, the `adapter_probe_program` pattern, `:69–70`) that does `GET /system_stats` on
  `127.0.0.1:8188` inside the container with a 5 s timeout, prints `device <devices[0].name>` and then `ready`, or
  `system_stats: HTTP <status>` / `system_stats: <exception class>` and exits 1; through `wslc_exec 20` (5 s of HTTP plus the
  interpreter's start; the restore's probe has 70 s because of its 60 s completion). Interval `t_scale 10`, window
  `READY_TIMEOUT_S` as `R9700_T_STOP` for every call inside it (amendment A13, `sleep_in_window`), a container not listed three
  times in a row reported at once — all `ready_wait`'s own.
- Two more adapter calls (the parent named three; S1 wrote them; the hand-made script needed these): `wslc_remove <name>`
  (`remove <name>`, 60 s) because `wslc_run` always passes `--rm` (`lib/adapter.sh:256`) but the operator's container may
  exist STOPPED from the hand-made script era, and a stopped container keeps its name (the script's lines 59–61 needed
  `wslc remove` before every start); and `wslc_inspect <reference>` (`inspect <reference>`, 60 s) for the image's `Created`
  (`status`). Both are S2's coder's. The hand-made script's `wslc system session terminate` (its lines 88–95) is NOT moved in:
  it stops every container of the session, the operator's vLLM and a night run included.
- `status` prints what can be known: the two containers' listed states, the image's `Created` from `wslc_inspect`, and for
  each of the three volumes whether `wslc_volume_list` holds it; the cache volume's SIZE is not known (the volume inspect
  reports none, *Facts every story uses*) and is printed as `size: not known`, never as 0 (coding-style: absent is not zero).
- The failed-start log tail: `<state dir>/comfy-start-<UTC yyyymmddThhmmssZ>-<pid>.tail.log` (the last 200 lines of
  `wslc_logs`, the restore's tail size); `comfy start` is the owner of that growth: before it writes one it keeps the newest 10
  by modification time and removes older ones by exact name (`comfy_tails_prune 10`, the shape of `restore_dirs_prune`,
  `lib/restore.sh:294–308`, over files).
- `--stop-vllm`: the recovery marker is written BEFORE the stop of `PROD_CONTAINER` (`marker_write_base`, run id
  `comfy-<UTC stamp>-<pid>`, `PROD_WAS_RUNNING=yes`, `RUN_DIR=<state dir>/restore-<run id>`, the folder `init` prunes) so a
  hard kill anywhere in the start — the readiness wait can be twenty minutes — leaves the debt recorded; then `wslc_stop`,
  with the lesson of `_step_stop_prod` (`lib/step.sh:94–106`): a non-zero stop reads the list again and a server that is gone
  counts as stopped. On a start that does not become ready, the restore is the existing `restore_from_marker` (the worker
  keys are absent, the prefixed containers are stopped, `restore_start` + `ready_wait`, the marker removed on success, kept on
  failure). On a start that became ready the marker is REMOVED: the operator asked for vLLM down with `--stop-vllm`, this is
  the manual workstation mode, and a marker left standing would make every reading verb refuse its restore while ComfyUI runs.
  The line says that vLLM stays down until the operator starts it. `comfy stop` never starts vLLM (the parent's row).
- The failure path reconciles against the container list, not against a flag. `wslc_run` is a detached `run -d` under the
  adapter's 120 s client ceiling (`lib/adapter.sh:251–258`): the engine can create the container and the client still time
  out (124), return non-zero, or be cut by TERM before any "it ran" flag could be set. So the launch ATTEMPT is recorded
  before the run call (`_COMFY_LAUNCHED=yes`), and the one failure path, whenever a launch was attempted, lists
  (`_rg_listing_tries`) whatever the call returned: `COMFY_CONTAINER` listed → its tail saved, `wslc_stop`, listed again and
  found gone; not listed → nothing to stop, said in one stdout line; and only after ComfyUI is known gone is vLLM restored
  (when this invocation stopped it — the restore's guard would otherwise refuse, correctly, and leave vLLM down with the
  marker standing and ComfyUI running after a start that reported failure). A listing that cannot be read during that
  cleanup stops nothing, leaves the marker where it stands and says so: exit 5, one line naming `bin/r9700 comfy stop` and
  `bin/r9700 init` (the next reading verb restores). CS15–CS18.
- The stub answers these modes need (`tests/stubs/wslc`): the ComfyUI probe in `exec_in` (`:262`), `remove`, `inspect`, a
  stopped container that keeps its name, and a detached run that starts the container and still fails or delays
  (`run-fail-<name>`, `run-delay-<name>`: the engine's half done, the client's half not).
- The exit-table rows of `start`, `stop` and `status` in `bin/r9700`'s header comment (`:10–27`), `research/architecture.md`
  (`:106–117`) and `README.md` (`:161–176`; no NEW code: rows 1, 2, 4 and 5 are extended); the verb row and the module row of
  `research/architecture.md` (`:7–39`, and the sentence of `:5` that counts the verbs); the `bin/r9700 comfy` line of
  `README.md` *The commands* (`:9–21`); the `COMFY_CONTAINER` rule text in `research/module_config.md` (`:25`, `:45`); the
  marker's new key in the *Recovery marker* paragraph of `research/architecture.md` (`:57`); its rows in
  `research/module_tests.md`.

Out: `build`, `fetch`, the `comfyui/` files, the placement (S3); `bench` and its own refusal before the lock (E2); the
volumes' contents; a `comfy stop` that starts vLLM (not in the parent's table).

### Files

`lib/comfy.sh` (new); `bin/r9700` (the library list, `verb_comfy`, the header's verb list and exit comment);
`lib/run_guarded.sh` (`comfy_owner_check`, `comfy_owners_check`, `_rg_listing_tries`, `_rg_card_free`, one line in `supervise`); `lib/step.sh` (one check in
`_step_admit`); `lib/restore.sh` (the marker key `COMFY_CONTAINER`, `_restore_comfy_free`, the three optional arguments of
`ready_wait`); `lib/adapter.sh` (`wslc_remove`, `wslc_inspect`, `comfy_probe`, `comfy_probe_program`, the header table);
`lib/config.sh` (`_cfg_cross`, `_COMFY_FETCH_SUFFIX`); `tests/stubs/wslc` and `tests/stubs/stub_common.sh`;
`tests/test_comfy.sh` (new: OC1–OC8, NR7, RM2–RM4, CS1–CS18, CT, CU); `tests/test_config.sh` (NR1–NR6); `tests/test_restore.sh` (RM1,
AW6); `tests/test_adapter.sh` (AW1–AW5); `tests/test_stubs.sh` (SW1–SW6); `tests/test_lifecycle.sh` (L20's legal-verb line);
`research/architecture.md`, `research/module_config.md`, `research/module_tests.md`, `README.md` (the rows above).

### Test scenarios

Verb scenarios run `bin/r9700` as a user runs it (the `r9700` helper of `tests/lib/lifecycle.sh:54`, which drops the test
shell's config variables) in the stub world of `lc_setup` / `step_setup`; the machine fixture names no `COMFY_*` key, so the
defaults hold: `comfyui`, `vllm`, port `8188`, the three volumes `comfy-models`, `comfy-data`, `comfy-cache`, the image
`comfyui-r9700:local`. "ComfyUI is listed" means a stub container named `comfyui` runs (`wslc run -d --rm --name comfyui img`,
the shape of `prod_running`). The call log is `$STUB/calls.log` (`log_count`, `count_calls`, `stop_lines`, `argv_of`). RED
first means: the test is written and run before the code it needs, the failure message is the real symptom, and the coder's
summary records it. The one owner line is, exactly:

```text
r9700: the operator's ComfyUI (<COMFY_CONTAINER>) is listed and holds the card; run bin/r9700 comfy stop first
```

**The owner check of the existing verbs (`tests/test_comfy.sh`)** — `step_setup`, the operator's server running, ComfyUI listed.

- OC1 *Every verb under `supervise` is refused before anything is stopped, and the set of verbs is derived.* The set is read
  from the code lines (not comments) of `bin/r9700` and `lib/*.sh` that match `supervise [a-z-]+ ` (the word after `supervise`,
  unique, sorted): today `linear-bench moe-tune prefixtest run series step`. The test holds ONE legal command line per verb
  (`step --model <35B> t -- worker.sh ok`; `series <35B> base`; `moe-tune chunk <35B> --keys 24`; `linear-bench <35B>`;
  `prefixtest <35B>`; `run <plan>` with the one line `linear-bench <35B name>`), keyed by verb, and asserts first that its keys
  equal the derived set (a verb added to `supervise` without a row fails with `add a row for <verb>`; the companion: the set
  holds `step` and `run`). Then, per verb: exit 2; stderr holds the owner line with `comfyui` and `bin/r9700 comfy stop`;
  the stop count is unchanged; the `run` count is unchanged (no fingerprint, check or unit container); no marker; no run folder
  under `RESULTS_DIR/runs` (`run_dir_new` comes after the check); the operator's server still runs. Needs the kernels, series
  and MoE setups (`tests/lib/kernelcase.sh`, which brings the others) for the prepares to pass; the refusal comes before every
  body. RED first: every verb runs its body (the stop count rises).
- OC2 *`step` is refused with exactly one stderr line and touches nothing* (the L1 shape, `tests/test_step.sh:26`): exit 2,
  exactly one stderr line equal to the owner line, no `stop`, no marker, no run folder, `worker.calls` absent. With the
  operator's server NOT running the same (nothing to stop, still refused). RED first.
- OC3 *A ComfyUI started in the middle of a run is caught at the next admission, and the one restore at the end does not start
  the operator's vLLM beside it.* Worker `fail` (a failed try, then a retry: a second admission); the stub's `on-stop-vllm`
  script (`tests/stubs/wslc:327–330`) starts the `comfyui` stub container, so ComfyUI appears after the first admission's stop.
  Result: exit **5** (the cleanup's code replaces the body's, `lib/run_guarded.sh:451`); stderr holds the owner line AND the
  restore's line `r9700: restore: vllm not started: the operator's ComfyUI (comfyui) is listed; run bin/r9700 comfy stop, then
  any verb restores vllm (the marker stays)`; exactly one `stop vllm`; `worker.calls` has one line (no second worker); no
  `pwsh.exe` call; the marker exists and names `COMFY_CONTAINER=comfyui`; `comfyui` is still listed (never stopped by a run).
  Then `bin/r9700 comfy stop` (exit 0) and `bin/r9700 init --model <35B>`: the marker is gone and `vllm` is listed again. RED
  first: the second admission stops nothing (the server is already down) and starts the worker again; and, separately,
  before the restore's half exists, the end-of-run restore starts vLLM (a `pwsh.exe` call) beside `comfyui` — the coder records
  both symptoms.
- OC4 *Nothing changes when the operator's ComfyUI is not listed, and the match is the whole name.* No `comfyui` container:
  `step … worker.sh ok` behaves as L2 (`tests/test_step.sh:40`): exit 0, one stop, one restore, no marker. With a container
  named `comfyuix` listed (and none named `comfyui`): the same — `grep -Fxq`, a whole line, never a substring.
- OC5 *A container list that cannot be read at the prepare-stage check refuses the run after three tries and stops nothing.*
  `fail-list 3` (`tests/stubs/wslc:193–203`): exit 2, one stderr line `r9700: the container list failed 3 times (<the stub's
  line>): cannot tell whether the operator's ComfyUI runs; nothing was started`, three `list` calls `t_scale 10` apart, no stop,
  no run folder. `fail-list 2`: the third list answers, the step runs (exit 0). RED first for the retry: a check with one try
  refuses the `fail-list 2` case.

**The two-owner mode of the locked entry (`tests/test_comfy.sh`)** — `comfy_setup`; `lib/comfy.sh` sourced in the test shell
with the machine fixture's config; the body is a double `body_double` that writes `$CASE/body.ran` and returns 0; the entry is
called as `comfy_locked probe card-free body_double` (the mode word `probe` is only the lock's holder word) so the scenarios need
no `build`, which S3 writes. The server line is, exactly:

```text
r9700: the operator's server (<PROD_CONTAINER>) is listed and holds the card; stop it by hand first (no verb of the toolkit stops it for a build)
```

- OC6 *The card-free admission refuses while the operator's ComfyUI is listed, before the body.* `comfyui` listed: return 2,
  exactly one stderr line equal to the owner line (with `comfyui`), `body.ran` absent, no `stop`, no `run`, no marker, the lock
  free afterwards (`flock -n <state>/lock true`); `comfy_owners_check` alone with a listing that holds `comfyui` → 2 and the
  owner line, with a listing that holds `comfyuix` and `vllmx` → 0 (whole lines, OC4's rule). RED first (the function).
- OC7 *The card-free admission refuses while the operator's vLLM is listed, naming it, and a standing marker restores vLLM
  first and is then refused — correctly.* `vllm` listed: return 2, one stderr line equal to the server line (with `vllm`),
  `body.ran` absent, no `stop`, no `pwsh.exe`. Then `write_marker` (vLLM was running, down now), nothing listed: the restore
  ran (one `pwsh.exe -Detach`, `vllm` listed, the marker gone), THEN return 2 with the server line, `body.ran` absent — the
  operator's server is back and the entry says what holds the card. With both `comfyui` and `vllm` listed: the owner line
  (ComfyUI's), one line only. RED first: the body runs beside `vllm`.
- OC8 *With neither owner listed the body runs under the lock, and a list that cannot be read refuses.* Nothing listed:
  return 0, `body.ran` exists, the lock was held while the body ran (the double records `flock -n <state>/lock true` failing
  from a subshell) and is free afterwards; a container named `comfyuix` listed: the same. `fail-list 3`: return 2, one line
  `r9700: comfy: probe: the container list failed 3 times (<the stub's line>)`, `body.ran` absent. And `comfy_locked probe
  body body_double` with `comfyui` and `vllm` both listed: return 0 and `body.ran` exists — the `body` word admits nothing
  (that is `start`'s own business, CS4–CS5).

**The name rules (`tests/test_config.sh`, beside `t_the_operator_server_name_must_not_start_with_the_container_prefix`,
`:549`; and `tests/test_comfy.sh` for NR7)**

- NR1 *`COMFY_CONTAINER` must not start with `CONTAINER_PREFIX`.* `COMFY_CONTAINER=r9700tune-comfy` → `config_load` 2 with one
  `config:` line naming `COMFY_CONTAINER`, `starts with the container prefix "r9700tune-"` and the legal text `COMFY_CONTAINER
  must not start with CONTAINER_PREFIX (the toolkit stops every container with that prefix)`; with `CONTAINER_PREFIX=x-` and
  `COMFY_CONTAINER=x-comfy` the same. RED first.
- NR2 *`COMFY_CONTAINER` must differ from `PROD_CONTAINER`.* `COMFY_CONTAINER=vllm` → 2, the line says `"vllm" is also
  PROD_CONTAINER`, legal `COMFY_CONTAINER must differ from PROD_CONTAINER (the toolkit stops and restores one, never the
  other)`; `PROD_CONTAINER=comfyui` with the default `COMFY_CONTAINER` → 2 too (the error is attributed to `COMFY_CONTAINER`,
  with the machine file and no line, `_cfg_where`). RED first.
- NR3 *The fetch name is checked by the same rules.* `COMFY_CONTAINER=r9700tune` (passes NR1: no closing dash) → 2, the line
  says `"r9700tune-fetch" (the fetch container's name) starts with the container prefix "r9700tune-"`; `PROD_CONTAINER=comfyui-fetch`
  → 2, `"comfyui-fetch" (the fetch container's name) is also PROD_CONTAINER`. RED first.
- NR4 *A legal pair loads.* `COMFY_CONTAINER=comfy-ui` with the default prefix and server → 0; `comfy_fetch_name` (after
  `config_load_machine`) prints `comfy-ui-fetch`, and `_COMFY_FETCH_SUFFIX` is `-fetch` (the one constant, read, not typed:
  the test builds the expected name from the constant).
- NR5 *The rules run over fields that passed their own check and report in one pass* (the shape of
  `t_cross_field_checks_run_even_when_a_single_field_is_wrong`, `:561`): `RAM_MIN_MB=x` and `COMFY_CONTAINER=vllm` → exactly
  two `config:` lines; `COMFY_CONTAINER=Bad` (fails its own type) → one line, no cross-field line about it.
- NR6 *`config_load_machine` applies both rules* (S1's CF9 shape): the NR1 and NR2 variants through `config_load_machine`
  → 2 with the same lines.
- NR7 *The cleanup, a guard and `init` never stop the operator's ComfyUI or a fetch in progress* (`tests/test_comfy.sh`):
  `comfyui`, `comfyui-fetch` and `r9700tune-x` listed; `container_stop_all <run>` (the `t_container_stop_all_…touches_only_the_prefix`
  shape, `tests/test_restore.sh:419`) stops `r9700tune-x` only and writes one tail; `bin/r9700 init --model <35B>` reports
  `stopped r9700tune-x` and the two others are still listed. Not RED first (it holds today by the prefix match; the scenario
  is the guarantee the name rules protect, and it goes red when someone widens the match).

**The restore's half and the marker (`tests/test_restore.sh` for RM1; `tests/test_comfy.sh` for RM2–RM4)**

- RM1 *The marker records `COMFY_CONTAINER` and a marker without it still reads.* `marker_write_base` (the `:274` test extended):
  `MARKER[COMFY_CONTAINER]` is `comfyui`; `marker_add_worker` keeps it (`:295`); `marker_read` of a hand-written marker without the
  key (`write_marker`, `tests/lib/lifecycle.sh:27`) returns 0 and the key is unset; `COMFY_CONTAINER=Bad` in a hand-written
  marker is refused naming the line. RED first: the write test fails with an empty value.
- RM2 *A restore never starts the operator's vLLM beside the operator's ComfyUI; the marker stays; the toolkit's own containers
  are still stopped.* `write_marker COMFY_CONTAINER=comfyui` (the server was running), `comfyui` and `r9700tune-old` listed:
  `bin/r9700 init --model <35B>` → exit 5, one stderr line (the restore line of OC3), no `pwsh.exe` call, the marker exists,
  `r9700tune-old` is stopped (its tail saved under `<state dir>/restore-hand-1/guard/`), `comfyui` still listed. `bin/r9700
  verdict <dir>` the same (5, the line). Then `comfy stop`, then `init`: one `pwsh.exe -Detach`, the marker gone, `vllm` listed.
  RED first: `init` starts vLLM (a `pwsh.exe` call) beside `comfyui`.
- RM3 *A marker written before this story has no name to check and restores as it always did.* `write_marker` without the
  key, `comfyui` listed: `init` → 0, one `pwsh.exe -Detach`, the marker gone (the documented limit of an older marker; L4–L7
  keep covering the rest).
- RM4 *A `comfy start --stop-vllm` killed hard after it stopped vLLM is restored by the next verb, after `comfy stop`.*
  `comfy_bg start --stop-vllm` with the server running and a slow readiness (`answers/comfy_ready`: thirty `fail` lines then
  `ok`; `READY_TIMEOUT_S=3235`), wait (bounded) for the first `exec comfyui` call, `kill -KILL $SUP`: the marker exists with
  `RUN_ID` starting `comfy-`, `PROD_WAS_RUNNING=yes`, `COMFY_CONTAINER=comfyui`, no worker keys; `comfyui` is still listed (a
  stub container outlives its starter). `init` → 5 with the restore line; `comfy stop`; `init` → 0, `vllm` back, marker gone.

**`comfy start` (`tests/test_comfy.sh`)** — `comfy_setup` is `lc_setup`, `printf 'ok\n' > answers/comfy_ready`, the three
volumes present as files `$STUB/volumes/<name>` (S1's SB2 shape, no call logged), and `comfy <args>` is `r9700 comfy "$@"`;
`comfy_bg` / `comfy_end` are `step_bg` / `step_end` (`tests/lib/stepcase.sh:85–106`) for the `comfy` verb; `comfy_run_argv`
gives ARGV of the `run -d --rm --name comfyui` call (the shape of `serve_argv`, `tests/lib/kernelcase.sh`).

- CS1 *The grammar is refused before the lock, and the modes are derived.* `comfy` (no mode), `comfy nosuch`, `comfy start
  --frob`, `comfy start extra`, `comfy stop extra`, `comfy status --x`: each exit 2 with one line; the mode line is `r9700:
  comfy: unknown mode "nosuch"; legal: start status stop` where the legal list is read from `comfy_modes` (and the test
  asserts that list equals the `comfy_mode_*` functions of `lib/comfy.sh`, derived, and holds `start`); no lock file, no call.
  `comfy start -- --reserve-vram 2` is legal (the words after `--` are ComfyUI's). RED first (the mode dispatch).
- CS2 *A start holds the lock through the launch and the readiness wait, runs the hand-made argv from the config, and prints
  the device.* Server not running. `comfy start` → exit 0; the run argv is exactly `run -d --rm --name comfyui --gpus all -p
  8188:8188 -v comfy-models:/models -v comfy-data:/data -v comfy-cache:/cache --shm-size 8g comfyui-r9700:local`; one `exec
  comfyui python3 -c <program>` whose program holds `/system_stats` (ARGV); stdout holds `comfy: start: comfyui ready after
  <n> s`, `comfy: start: device cuda:0 AMD Radeon AI PRO R9700 : native` (the stub's default answer) and `comfy: start: open
  http://127.0.0.1:8188`; afterwards the lock is free (`flock -n <state>/lock true`), no marker, no `pwsh.exe` call, `comfyui`
  listed, no `volume create` (all present), no `stop`. Variants: `COMFY_OUTPUT_WIN="X:\comfy-out"` adds `-v
  X:\comfy-out:/data/output` right after the cache volume; `COMFY_PORT=8288` gives `-p 8288:8188` and the URL `:8288`; `-- --reserve-vram 2`
  puts the two words after the image. The lock: `comfy_bg start` with a slow readiness (ten `fail` lines then `ok`,
  `READY_TIMEOUT_S=3235`), wait for the first `exec` call, then `r9700 step --model <35B> t -- worker.sh ok` → 4 with the
  holder line naming `comfy` (the L8 shape, `tests/test_step.sh:111`); `comfy_end` → 0. RED first (the verb).
- CS3 *A start is refused under a held lock.* A `step_bg … worker.sh child` holds it: `comfy start` → 4, the holder line
  `pid <SUP>, step`, no call, no marker. RED first.
- CS4 *Beside the operator's listed server a start is refused unless `--stop-vllm`, which stops it once, marker first, and
  logs it.* Server running: `comfy start` → 2, one stderr line `r9700: comfy: start: the operator's server vllm is listed and
  holds the card; pass --stop-vllm, or stop it by hand`, no `stop`, no `run`, no marker. `comfy start --stop-vllm` → 0; exactly
  one `stop vllm`; stdout has `comfy: start: stopped the operator's server vllm` and `comfy: start: vllm stays down; start it by
  hand when ComfyUI is done`; the stub's `on-stop-vllm` script copied the marker at the moment of the stop: the copy reads with
  `PROD_WAS_RUNNING=yes`, `RUN_ID` starting `comfy-`, `COMFY_CONTAINER=comfyui`, `RUN_DIR=<state dir>/restore-<RUN_ID>`; at the
  end no marker, `vllm` not listed, `comfyui` listed. A stop that returns 1 while the server is gone (`stop-gone-vllm 1`) is
  counted as stopped (stdout says so); a stop that fails and leaves it listed (`stop-fail-vllm 1`) → exit 1, one stderr line
  `r9700: comfy: start: stopping the operator's server vllm failed (code 1): <the stub's line>`, no `run`, no marker left
  (vLLM is up, nothing is owed). RED first for the refusal and for the marker-before-stop (the copy is missing).
- CS5 *A start finds ComfyUI already running and does nothing.* `comfyui` listed: `comfy start` → 0, stdout `comfy: start:
  comfyui is already running, nothing to do`; with `-- --x` the line ends `(the arguments after -- were not applied)`; no
  `run`, no `remove`, no `stop`.
- CS6 *Missing volumes are created by list-then-create, and only the missing ones.* No volume file: three `volume create`
  calls, `comfy-models`, `comfy-data`, `comfy-cache` in that order, every one before the `run` (call-log order), stdout one
  `comfy: start: created volume <name>` each; only `comfy-data` present: two creates, not that one. `fail-volume-list 3` → exit
  1, no `run`, the line names the volume list; `answers/volume_create_rc 1` → exit 1, no `run`, the line names the volume and
  the code; in both, with `--stop-vllm` and the server running, the restore ran afterwards (one `pwsh.exe -Detach`, `vllm`
  listed, no marker). RED first (the creates).
- CS7 *A stopped container of the name is removed before the run.* `$STUB/stopped/comfyui` planted (SW2): `comfy start` → 0,
  the `remove comfyui` call precedes the `run` call, stdout `comfy: start: removed the stopped container comfyui`. Without a
  stopped container the remove is still called before every run (the hand-made shape) and its failure prints nothing (exit 0
  overall). `answers/remove_rc 1` with the stopped container planted: the run is refused by the stub (`name in use (a stopped
  container)`), exit 1, one stderr line `r9700: comfy: start: the run of comfyui failed (code 1): <the stub's last line>`, no
  `stop comfyui` (the failure path listed after the launch and found `comfyui` absent: a stopped record is not a listed
  container; stdout says `comfyui is not listed after the failed launch; nothing to stop`), the lock free. RED first: without
  the remove, the planted stopped container makes the run fail.
- CS8 *A start that does not become ready saves the log tail, stops the container, sees it gone, restores vLLM only when this
  invocation stopped it, releases the lock last, and exits 5 with one line naming the saved log.* `answers/comfy_ready` = `fail`,
  `READY_TIMEOUT_S=60` (the window is the subject, as in L4), 250 lines in `answers/logs`: exit 5; exactly one stderr line
  `r9700: comfy: start: comfyui not ready after <n> s (<reason>); its last 200 log lines are in <state dir>/comfy-start-<stamp>-<pid>.tail.log`;
  that file exists, has 200 lines and ends with line 250; the call order is `logs comfyui` < `stop comfyui` < the last `list`;
  `comfyui` is not alive; the lock is free; stdout has `saved the last 200 log lines` and `stopped comfyui`; no `pwsh.exe`
  (vLLM was not ours to restore). With `--stop-vllm` and the server running: the same, plus one `pwsh.exe -Detach` AFTER the
  `stop comfyui`, `vllm` listed again, no marker. With `--stop-vllm` and `answers/ready` = `fail` (vLLM's restore fails too):
  exit 5, the restore's `vllm not ready` line too, the marker stays. Eleven tail files planted: after the start only ten
  `comfy-start-*.tail.log` exist, the oldest gone, a planted `comfy-start-notours` (a folder) and `other.tail.log` untouched.
  RED first: the tail file and the stop.
- CS9 *A container that exits during the wait is reported at once, not at the window.* `answers/comfy_ready` = `fail`,
  `READY_TIMEOUT_S=3235` (32 s): `comfy_bg start`, wait for the first `exec` call, kill the recorded container process
  (`pid_of comfyui`); `comfy_end 10` → 5 within those seconds, the reason `comfyui not listed 3 times in a row`, the tail saved
  (the `logs` call may fail on a gone container: the file is then empty, and the line still names it).
- CS10 *A probe that hangs is cut by the window and leaves no process.* `answers/comfy_ready` = `hang`, `READY_TIMEOUT_S=60`:
  exit 5 within a few seconds, the reason `the probe timed out` or `the readiness window ended`, every pid recorded under
  `hung/containers` gone (the `t_a_probe_that_hangs_at_the_limit_ends_the_wait_within_one_grace` shape, `tests/test_restore.sh:139`).
- CS11 *A signal during a start runs the same failure path.* `comfy_bg start --stop-vllm` (server running, thirty `fail` lines
  then `ok`), wait for the first `exec`, `kill -TERM $SUP`: exit 143, stderr `r9700: comfy: start: interrupted by TERM`,
  `comfyui` not alive, one `pwsh.exe -Detach`, `vllm` listed, no marker, the lock free. `INT` → 130. A `TERM` before the run
  (during the vLLM stop, `stop-delay-vllm 3`): exit 143, no `run`, the restore ran.
- CS12 *A bad `COMFY_CONTAINER` is refused at config load before any call.* `COMFY_CONTAINER=r9700tune-comfy` in the machine
  file: `comfy start` → 2, the NR1 line, no `wslc` call at all; `comfy stop` and `comfy status` the same.
- CS13 *A start needs no model file.* Two model files in `models/` (the repository's): `comfy start` loads the machine file
  alone (exit 0, no `--model`), the S1 `config_load_machine` guarantee through the verb.
- CS14 *A start after a hard-killed run restores first, then does what it was asked.* `write_marker` (vLLM was running, down
  now), `comfy start` → the restore ran (one `pwsh.exe -Detach`, `vllm` listed, marker gone), then refused 2 by CS4's line
  (vLLM is listed and no `--stop-vllm`). `comfy start --stop-vllm` → the restore ran, then one `stop vllm`, ComfyUI started,
  exit 0: the cost after a hard kill is one load of vLLM, and the invariant of `bin/r9700:6–8` holds for this verb too.
- CS15 *A run call that fails AFTER the engine created the container leaves nothing running: the failure path reconciles
  against the list, not against a flag.* Server not running; `run-fail-comfyui 1` (SW5: the stub starts `comfyui` and still
  returns 1 with its line): `comfy start` → exit 1; exactly one stderr line `r9700: comfy: start: the run of comfyui failed
  (code 1): <the stub's line>; comfyui was listed after the failed launch and was stopped; its last 200 log lines are in
  <state dir>/comfy-start-<stamp>-<pid>.tail.log`; the call order is `run` < `logs comfyui` < `stop comfyui` < the last `list`;
  stdout has `saved the last 200 log lines` and `stopped comfyui`; `comfyui` is not alive; no marker; no `pwsh.exe`; the lock
  free. RED first: `comfyui` is alive after the exit (the "it ran" flag was never set, so the failure path stopped nothing) —
  the coder records that symptom.
- CS16 *The same with `--stop-vllm` beside the operator's server: vLLM is restored only after ComfyUI is gone.* Server
  running, `run-fail-comfyui 1`: `comfy start --stop-vllm` → exit 1, the CS15 line; exactly one `stop vllm`, then `stop
  comfyui`, then one `pwsh.exe -Detach` AFTER the `stop comfyui` (call-log order); `vllm` listed, `comfyui` not alive, no
  marker, the lock free. RED first: the restore's guard refuses (the RM2 line beside `comfyui`), exit 5, the marker stays and
  `vllm` is down while `comfyui` runs — a start that reported failure and left the card to the wrong owner; the coder records
  that symptom too.
- CS17 *A run call cut by TERM after the engine created the container is reconciled the same way.* Server not running;
  `run-delay-comfyui 30` (SW6: the stub starts `comfyui`, then sleeps before it answers): `comfy_bg start`, `wait_for` the
  recorded container (`$STUB/containers/comfyui.pid` alive), `kill -TERM $SUP`; `comfy_end 15` → 143, stderr `r9700: comfy:
  start: interrupted by TERM` (the one line; the tail file named when `logs` answered), `stop comfyui` in the log after the
  `run`, `comfyui` not alive, no marker, the lock free. With `--stop-vllm` and the server running: the same plus one `pwsh.exe
  -Detach` after the `stop comfyui`, `vllm` listed, no marker. RED first: `comfyui` alive after the exit; with `--stop-vllm`
  also the refused restore and the standing marker.
- CS18 *A listing that cannot be read during that cleanup stops nothing, leaves the marker where it stands and names both
  commands.* Server running, `run-fail-comfyui 1`, and `fail-list` armed to pass the lists before the launch and fail the three
  after it (`fail-list "<skip> 3"`, the skip count being the lists the start makes before the run call — the test counts them
  from the CS16 log rather than typing a number): `comfy start --stop-vllm` → exit 5; exactly one stderr line `r9700: comfy:
  start: the run of comfyui failed (code 1): <the stub's line>; the container list failed 3 times (<the stub's line>) after the
  launch: whether comfyui runs is not known; run bin/r9700 comfy stop, then bin/r9700 init (the marker stays)`; no `stop
  comfyui`, no `logs`, no `pwsh.exe`; the marker exists with `COMFY_CONTAINER=comfyui` and `PROD_WAS_RUNNING=yes`; `comfyui`
  still alive (the test ends it); the lock free. Then `comfy stop` → 0 and `init --model <35B>` → 0, `vllm` back, the marker
  gone. Without `--stop-vllm` (server not running): exit 5, the same line without `(the marker stays)`, no marker. RED first.

**`comfy stop` (`tests/test_comfy.sh`)**

- CT1 *A listed ComfyUI is stopped.* `comfyui` listed: exit 0, one `stop comfyui`, stdout `comfy: stop: stopped comfyui`,
  not alive afterwards; no lock file is made, no marker, no `pwsh.exe`. RED first.
- CT2 *A ComfyUI that is not listed is not an error.* Exit 0, stdout `comfy: stop: comfyui is not running, nothing to do`,
  no `stop` call. RED first: a stop of an absent container returns 1 from the stub.
- CT3 *A stop that returns 1 while the container is gone is counted as stopped.* `stop-gone-comfyui 1`: exit 0, stdout `comfy:
  stop: the stop returned 1 but comfyui is gone: counted as stopped`.
- CT4 *A stop that fails and leaves it listed is reported with the engine's text.* `stop-fail-comfyui 1`: exit 1, one stderr
  line `r9700: comfy: stop: comfyui did not stop (code 1): <the stub's line>`; `fail-list 3`: exit 1, the line names the list.
- CT5 *`stop` takes no lock, restores nothing and works while a run holds the lock.* `write_marker` standing and `comfyui`
  listed: `comfy stop` → 0, the marker untouched, no `pwsh.exe`; a `step_bg … child` holding the lock: `comfy stop` → 0.

**`comfy status` (`tests/test_comfy.sh`)**

- CU1 *Status prints both containers, the image's creation time and the volumes, and says what it cannot know.* `comfyui` and
  `vllm` listed, three volume files: exit 0, stdout exactly the six lines `comfy: status: comfyui: running`, `comfy: status:
  vllm: running`, `comfy: status: image comfyui-r9700:local: created 2026-11-07T10:00:00.000000000Z` (the stub's default
  `inspect` answer, SW3, parsed from `"Created"`), `comfy: status: volume comfy-models: present`, `comfy: status: volume
  comfy-data: present`, `comfy: status: volume comfy-cache: present; size: not known (the engine reports no volume size)`; the
  `inspect` argv is `inspect comfyui-r9700:local`; no lock file, no `stop`, no `run`. RED first.
- CU2 *Absence is a known fact.* Nothing listed, `answers/inspect_rc 1`, no volume file: `not running` twice, `image
  comfyui-r9700:local: not present`, `absent` three times; exit 0.
- CU3 *What could not be read says `not known` and exits 1.* `fail-list 3`: `comfy: status: containers: not known (<line>)`
  and exit 1, the other lines still printed; `answers/inspect` without a `Created` field: `image …: created: not known (no
  Created in the answer)`, exit 1; `fail-volume-list 3`: `comfy: status: volumes: not known (<line>)`, exit 1. The cache
  volume's `size: not known` alone never makes the exit 1 (CU1).

**Adapter (`tests/test_adapter.sh`; AW6 in `tests/test_restore.sh`)**

- AW1 *`wslc_remove` removes exactly the named container and keeps the name check.* `wslc_remove comfyui` → `argv_of wslc` is
  `remove comfyui`, the code is the child's, its lines printed without CR; `wslc_remove -x`, `''`, `'a b'` → 2 with one line
  naming `wslc_remove` and `container name`, no call.
- AW2 *`wslc_inspect` takes an image or container reference.* `wslc_inspect comfyui-r9700:local` → argv `inspect
  comfyui-r9700:local`, the JSON printed, no CR; `wslc_inspect -x`, `''`, `'a b'` → 2, one line naming `wslc_inspect` and
  `reference`, no call; `answers/inspect_rc 1` → 1.
- AW3 *The ceilings are the documented ones* (`:297` extended): `wslc_remove a`, `wslc_inspect a`, `comfy_probe a` add
  `5 60 5 60 5 20` to the expected sequence.
- AW4 *No carriage return from the new functions* (`:84` extended).
- AW5 *The ComfyUI probe program names the device or the failing step* (the `adapter_probe_run` shape, `:351`, for
  `comfy_probe_program`): a 200 with `{"devices": [{"name": "cuda:0 X : native"}]}` → prints `device cuda:0 X : native` then
  `ready`, exit 0, the request was `GET http://127.0.0.1:8188/system_stats` with timeout 5; an `HTTPError` 500 → `system_stats:
  HTTP 500`, 1; a 204 → `system_stats: HTTP 204`, 1; a `URLError` → `system_stats: URLError`, 1; a 200 with `nope` →
  `system_stats: JSONDecodeError`, 1; a 200 with `{}` → `system_stats: KeyError`, 1; `{"devices": []}` → `IndexError`, 1.
- AW6 *`ready_wait` takes a probe, a ready word and a line prefix, and keeps its defaults.* A probe double that prints `x` then
  `ready`: `ready_wait vllm 60 probe_double ready "r9700: comfy: start:"` → 0, `READY_ANSWER` is the two lines, `READY_ELAPSED_S`
  a whole number; a double that prints `x` then `nope`: 5, the stderr line starts `r9700: comfy: start: vllm not ready after`,
  `READY_LINE` is that line without the prefix, `READY_ANSWER` empty; the prefix `-` prints no line and still sets `READY_LINE`.
  Every existing `ready_wait` test passes without an edit.

**Stub (`tests/test_stubs.sh`)**

- SW1 *`remove` answers by the container's state.* A planted `stopped/a`: `wslc remove a` removes it, prints `a` with CRLF, 0;
  a running `a`: 1 with `stub: cannot remove a running container: a`, still running; neither: 1 with `stub: no such container:
  a`; `answers/remove_rc 1`: 1 with `stub: remove failed (scripted)` and `stopped/a` kept.
- SW2 *A stopped container keeps its name.* `stopped/a` planted: `wslc run -d --rm --name a img` → 1, `stub: container name in
  use (a stopped container): a`, nothing started; after `wslc remove a` the run works. (The real engine's refusal is the
  hand-made script's observation; the stub repeats it so CS7 has teeth.)
- SW3 *`inspect` is scripted.* Default: `[{"Id": "sha256:stub", "Created": "2026-11-07T10:00:00.000000000Z"}]` with CRLF, 0;
  `answers/inspect`: that file; `answers/inspect_rc`: that code with one `stub: inspect:` line.
- SW4 *The ComfyUI readiness probe is answered from `answers/comfy_ready`* (call k takes line k, the last repeats, as `ready`):
  `ok` → `device cuda:0 AMD Radeon AI PRO R9700 : native` and `ready`, 0; `fail` → `system_stats: URLError`, 1; `hang` → the
  recorded sleeper (`stub_hang`); the file missing → exit 99. The vLLM probe (`answers/ready`) is untouched.
- SW5 *A detached run can start the container and still fail.* `run-fail-a 1` (a count): `wslc run -d --rm --name a img` → 1,
  stderr `stub: run: the client failed after the container started (scripted): a`, and `a` IS running afterwards (its record
  alive, listed by `wslc list`); the count is used up: a second run of `b` with no such file works as before. (The real engine's
  shape: `run -d` creates the container, the client's answer is lost to a ceiling or an error — the case CS15 exists for.)
- SW6 *A detached run can start the container and then delay its answer.* `run-delay-a 2` (seconds): the container is
  recorded and alive BEFORE the sleep (a reader polling `containers/a.pid` sees it within the first second), the three lines
  come after; the file is read, not removed, so every run of `a` is delayed while it stands. A TERM to the stub during the
  sleep ends the stub and leaves `a` running (a `setsid` container outlives its starter) — the case CS17 exists for.

**Documents (DC)** — no new test: `tests/test_docs.sh` DOC7 (`:131`, the test file row), DOC8 (`:141`, every lib file named),
DOC9 (`:154`, the verb in the README and the architecture verb table), `tests/test_lifecycle.sh` L18 (`:381`, the verb in the
catalogue) and the exit-code test (`:432`) are each seen RED after `verb_comfy` and `lib/comfy.sh` exist and before the rows are
written, then green; L20 (`:397`) changes its exact legal list to `comfy commands init linear-bench moe-tune prefixtest run series
step verdict` (`LC_ALL=C sort`: `comfy` sorts before `commands`).

### Brief for the Sonnet coder

Read first: this section and *Facts every story uses*; the parent's *The verb `bin/r9700 comfy <mode>`* and *Records and
growth*; the hand-made start script (the main session gives its location; its lines 43–84 are the behaviour to keep, 86–96 the
behaviour NOT to copy); `lib/run_guarded.sh:81–116` and `:427–462`; `lib/step.sh:89–156`; `lib/restore.sh` whole;
`lib/adapter.sh:1–70` and `:244–334`; `lib/config.sh:350–392` as S1 left it; `bin/r9700:75–77`, `:141–215`, `:574–586`;
`tests/stubs/wslc:143–173`, `:262–338`; `tests/stubs/stub_common.sh`; `tests/lib/stepcase.sh`; `tests/lib/kernelcase.sh`; the
tests named in the scenarios. Reuse, never copy: `lock_take` / `lock_release`, `restore_first`, `restore_from_marker`,
`marker_write_base`, `marker_remove`, `ready_wait`, `wslc_*`, `t_scale`, `sleep_in_window`, `ceil_seconds`, `state_dir`,
`marker_path`. No line of `lib/comfy.sh`, `lib/run_guarded.sh`, `lib/step.sh` or `bin/r9700` names `wslc` as a word (the seam:
write "the engine" or "the container list").

**1. The owner check (`lib/run_guarded.sh`, beside `supervise`).**

- `comfy_owner_check <listing>`: 0 when `$R9700_COMFY_CONTAINER` is not a whole line of `<listing>` (`grep -Fxq`); else
  `rg_err` of the owner line (the exact text of *Test scenarios*) and 2. An empty `R9700_COMFY_CONTAINER` is a programming
  error (the config was not loaded): one `rg_err` line saying so and 2 — never a silent pass.
- `_rg_listing_tries`: up to 3 `wslc_list` tries, `t_scale 10` apart (the A22 shape of `_restore_prepare`,
  `lib/restore.sh:246–259`); prints the listing and returns 0, or returns 1 with the first line of the last answer in
  `_RG_LIST_ERR`. A plain command substitution (no `_rg_run`: there is no run folder yet). `lib/comfy.sh` uses it too (step 6).
- `_rg_card_free`: `listing="$(_rg_listing_tries)"` — on 1 the OC5 line (with `$_RG_LIST_ERR`) through `rg_err` and 2 — then
  `comfy_owner_check "$listing"`.
- `comfy_owners_check <listing>`: the two-owner check of the locked entry's `card-free` admission (S3's `build`). In this
  order: `comfy_owner_check "$listing" || return 2` (ComfyUI's line wins when both are listed); then, when
  `$R9700_PROD_CONTAINER` is a whole line of `<listing>` (`grep -Fxq`), `rg_err` of the server line (the exact text of *Test
  scenarios*, OC6–OC8) and 2; else 0. An empty `R9700_PROD_CONTAINER` is the same programming error as an empty
  `R9700_COMFY_CONTAINER`: one `rg_err` line and 2. It is NOT called by `supervise` or `_step_admit` (those verbs stop vLLM
  themselves and own the restore); only `comfy_locked` calls it.
- `supervise`: after `if ! "$prepare"; then lock_release; return 2; fi` add `if ! _rg_card_free; then lock_release; return 2; fi`.
  The header comment of the file lists both functions.

**2. The admission (`lib/step.sh`).** In `_step_admit`, right after `grep -Fxq -- "$R9700_PROD_CONTAINER" <<< "$listing" && listed=yes`:
`comfy_owner_check "$listing" || return 2` (the step's `case` returns it: `step_run` ends 2, the body ends, `cleanup_once`
restores what an earlier admission stopped). The header comment's exit table gains `2 … or the operator's ComfyUI is listed`.

**3. The restore's half (`lib/restore.sh`).**

- `_MARKER_ORDER` gains `COMFY_CONTAINER` between `READY_TIMEOUT_S` and `RUN_DIR` (optional: not in `_MARKER_REQUIRED`);
  `_marker_check`: `COMFY_CONTAINER) _cfg_check name "$v" ;;`; `marker_write_base` writes `"COMFY_CONTAINER=$R9700_COMFY_CONTAINER"`
  after `READY_TIMEOUT_S`; the header's key list names it. `marker_add_worker` copies it through `_MARKER_ORDER` unchanged.
- `_restore_comfy_free <prod>`: 0 when `${MARKER[COMFY_CONTAINER]:-}` is empty or not a whole line of `_RESTORE_LISTING`; else
  the restore line of OC3 on stderr and 5. In `restore_from_marker`: `if [ "$was" = yes ]; then _restore_comfy_free "$prod" || return 5;
  _restore_server "$prod" || return 5; fi`. Nothing else in the restore changes.
- `ready_wait <container> <timeout s> [<probe function> [<ready word> [<line prefix>]]]`: defaults `restore_probe`,
  `completion`, `r9700: restore:`; `READY_ANSWER` = the probe's whole output on 0 (empty otherwise); `READY_ELAPSED_S` = the
  production seconds the wait took (the `n` of `:209`, computed before the return of `:192` too); `READY_LINE` = `<container>
  not ready after <n> s (<reason>)` on 5; the line printed is `<prefix> <READY_LINE>`, and the prefix `-` prints none. A few
  lines change in the function and nothing in its loop; the header comment names the three variables.

**4. The adapter (`lib/adapter.sh`).** After `wslc_logs`, each starting with `_adapter_drop_lock`:

- `wslc_remove <name>`: `_adapter_name_ok wslc_remove "${1:-}" || return 2`, `_adapter_call --merge 60 "$R9700_WSLC" remove "$1" | tr -d '\r' 9>&-`,
  `return "${PIPESTATUS[0]}"`.
- `wslc_inspect <reference>`: `_ADAPTER_REF_RE='^[A-Za-z0-9][A-Za-z0-9._:/-]*$'` (an image reference has `/` and `:`; no leading
  `-`, no space); a refusal is one line `wslc_inspect: "<x>" is not a reference (letters, digits, . _ : / -; no leading -)`;
  `_adapter_call --merge 60 "$R9700_WSLC" inspect "$1" | tr -d '\r' 9>&-`.
- `_COMFY_PROBE_PY` beside `_ADAPTER_PROBE_PY`: the program of AW5 (stdlib only: `json`, `sys`, `urllib.error`, `urllib.request`;
  the `fetch` shape of the vLLM probe; `devices[0]["name"]`; the two last lines `device <name>` and `ready`);
  `comfy_probe_program` prints it; `comfy_probe <name>`: `_adapter_name_ok comfy_probe …`, `wslc_exec 20 "$1" python3 -c "$_COMFY_PROBE_PY"`.
- Three rows in the header table.

**5. The name rules (`lib/config.sh`).** `_COMFY_FETCH_SUFFIX='-fetch'` beside the expressions (`:81–89`). In `_cfg_cross`,
after the `PROD_CONTAINER` rule, when `COMFY_CONTAINER`, `CONTAINER_PREFIX` and `PROD_CONTAINER` all passed their own check, a
loop over the two names `"${_C_VAL[COMFY_CONTAINER]}"` (label empty) and `"${_C_VAL[COMFY_CONTAINER]}$_COMFY_FETCH_SUFFIX"`
(label ` (the fetch container's name)`): the prefix rule, then the equality rule, each `_cfg_error "$(_cfg_where COMFY_CONTAINER)"
"${_C_LINE[COMFY_CONTAINER]-}" COMFY_CONTAINER "<problem>" "<legal>"` with the texts of NR1–NR3. It is a machine rule: it runs in
both scopes of S1's `_cfg_cross`.

**6. `lib/comfy.sh`** (new; header in the style of `lib/kernels_verb.sh`: what each function is, the exit codes, "nothing here
sets a trap except `comfy start`, which owns its one failure path"). Messages start `r9700: comfy: <mode>:` (stderr) and
`comfy: <mode>:` (stdout).

- `comfy_modes`: `declare -F | awk '{ print $3 }' | grep '^comfy_mode_' | sed 's/^comfy_mode_//' | LC_ALL=C sort`.
- `comfy_fetch_name`: `printf '%s%s\n' "$R9700_COMFY_CONTAINER" "$_COMFY_FETCH_SUFFIX"`.
- The container list is always `_rg_listing_tries` (step 1): one loop, one failure text (`_RG_LIST_ERR`), no copy here.
- `comfy_locked <mode> <admit> <body> [args...]`: `<admit>` is `body` or `card-free` (any other word: one stderr line
  `comfy_locked: "<x>" is not an admission (body, card-free)`, an internal error, 2, nothing taken). Then `lock_take comfy ||
  return $?`; `restore_first`; `config_load_machine "${R9700_MACHINE_ENV:-./machine.env}" || { lock_release; return 2; }`;
  with `card-free`: `listing="$(_rg_listing_tries)" || { echo "r9700: comfy: <mode>: the container list failed 3 times
  ($_RG_LIST_ERR)" >&2; lock_release; return 2; }` and `comfy_owners_check "$listing" || { lock_release; return 2; }` (its own
  line is already printed) — BEFORE the body, so a refused `build` has placed nothing and built nothing; `"$body" "$@"`;
  `rc=$?`; `lock_release`; `return $rc`. `start` passes `body` (its steps 1–4 are its admission); S3's `build` passes
  `card-free`. The modes without the lock (`stop`, `status`) load the machine config themselves and never call `restore_first`.
- `comfy_volume_ensure <name> <listing>`: creates the volume when it is not a whole line of `<listing>` (`wslc_volume_create`),
  prints `comfy: start: created volume <name>`; a failed create: `_COMFY_ERR="volume create <name> failed (code <rc>): <last line>"`
  and 1. S3's `fetch` calls it (one helper, not two).
- `comfy_tails_prune <keep>`: over `$(state_dir)/comfy-start-*.tail.log`, regular files only, names matching
  `^comfy-start-[0-9]{8}T[0-9]{6}Z-[0-9]+\.tail\.log$`, newest `<keep>` by mtime kept, the rest removed by exact name (the
  `restore_dirs_prune` shape).
- `comfy_start_args <args...>`: `--stop-vllm` sets `_COMFY_STOP_VLLM=yes`; `--` ends the options and the rest is `_COMFY_EXTRA`
  (an array); any other word is 2 with `r9700: comfy: start: unknown argument "<x>"; legal: --stop-vllm, -- <main.py args>`.
- `comfy_mode_start`: `comfy_start_args "$@" || return 2`, then `comfy_locked start body comfy_start_body`.
- `comfy_start_body`, in this order, with `_COMFY_LAUNCHED=no _COMFY_STOPPED_PROD=no` reset first and the traps
  `trap '_comfy_on_signal INT' INT` (TERM, HUP alike) set right after the reset and removed before the return:
  1. `listing="$(_rg_listing_tries)"` → on 1 the stderr line `r9700: comfy: start: the container list failed 3 times
     ($_RG_LIST_ERR)`, return 2.
  2. `COMFY_CONTAINER` listed → the CS5 line, return 0.
  3. `PROD_CONTAINER` listed and `_COMFY_STOP_VLLM=no` → the CS4 line on stderr, return 2.
  4. `PROD_CONTAINER` listed and `--stop-vllm`: `marker_write_base "$(marker_path)" "comfy-$(date -u +%Y%m%dT%H%M%SZ)-$$" yes
     "$(state_dir)/restore-comfy-<that stamp>-$$"` (2 with a line when it cannot be written: nothing stopped); `_COMFY_STOPPED_PROD=yes`;
     `wslc_stop "$R9700_PROD_CONTAINER"`; a non-zero stop: list again; gone → stdout `the stop returned <rc> but <prod> is gone:
     counted as stopped`; still listed → `marker_remove`, `_COMFY_STOPPED_PROD=no`, the CS4 failure line, return 1; the list
     failed → the marker stays, the line, return 1. Then stdout `stopped the operator's server <prod>`.
  5. `wslc_volume_list` (a failure: `comfy_start_fail 1 "the volume list failed (code <rc>): <line>"`); `comfy_volume_ensure`
     for `COMFY_MODELS_VOLUME`, `COMFY_DATA_VOLUME`, `COMFY_CACHE_VOLUME` in that order (a failure: `comfy_start_fail 1 "$_COMFY_ERR"`).
  6. `comfy_tails_prune 10`.
  7. `out="$(wslc_remove "$R9700_COMFY_CONTAINER" 2>&1)"`: rc 0 → stdout `removed the stopped container <name>`; else nothing.
  8. `_COMFY_LAUNCHED=yes` FIRST — the attempt is recorded before the call, never after it (the call is a detached `run -d`
     under a 120 s client ceiling: the engine may create the container while the call returns 124, non-zero, or not at all
     because a signal cut it); then `wslc_run "$R9700_COMFY_CONTAINER" --gpus all -p "$R9700_COMFY_PORT:8188" -v
     "$R9700_COMFY_MODELS_VOLUME:/models" -v "$R9700_COMFY_DATA_VOLUME:/data" -v "$R9700_COMFY_CACHE_VOLUME:/cache" [-v
     "$R9700_COMFY_OUTPUT_WIN:/data/output" when set] --shm-size 8g "$R9700_COMFY_IMAGE" "${_COMFY_EXTRA[@]}"`; rc ≠ 0 →
     `comfy_start_fail 1 "the run of <name> failed (code <rc>): <last line>"` (the failure path reconciles against the list:
     CS15–CS18).
  9. `ready_wait "$R9700_COMFY_CONTAINER" "$R9700_READY_TIMEOUT_S" comfy_probe ready -`; 5 → `comfy_start_fail 5 "$READY_LINE"`
     (the failure path appends the tail file to the line); 0 → stdout `<name> ready after $READY_ELAPSED_S s`,
     `device <…>` (the `device ` line of `READY_ANSWER`), `open http://127.0.0.1:<port>`; with `_COMFY_STOPPED_PROD=yes`:
     `marker_remove "$(marker_path)"` and stdout `<prod> stays down; start it by hand when ComfyUI is done`. Return 0.
- `comfy_start_fail <code> <line>` — the ONE failure path; `trap '' INT TERM HUP` first (a signal must not cut it in half):
  (a) `_COMFY_LAUNCHED=yes` — whatever the run call returned, the LIST decides: `listing="$(_rg_listing_tries)"`; the list
  failed → the line becomes `<line>; the container list failed 3 times ($_RG_LIST_ERR) after the launch: whether <name> runs
  is not known; run bin/r9700 comfy stop, then bin/r9700 init[ (the marker stays)]` (the bracket with `_COMFY_STOPPED_PROD=yes`),
  code 5, nothing stopped, no tail, the marker untouched, and (b) is skipped (the restore needs the same list and would refuse
  or, worse, start vLLM beside a ComfyUI it cannot see); `<name>` not a whole line of the listing → stdout `<name> is not
  listed after the failed launch; nothing to stop`, no tail, no stop; `<name>` listed → `comfy_tails_prune 10`; `wslc_logs
  <name> | tail -n 200 > <file>` (an empty file when the logs call fails); stdout `saved the last 200 log lines of <name> to
  <file>`; `wslc_stop <name>`; list again (a list failure here: the same "not known" line, code 5, (b) skipped); still listed →
  the line becomes `<name> is still listed after the stop; stop it by hand`, code 5, and the restore is NOT run (the restore's
  guard would refuse it; the marker stays and says so); else stdout `stopped <name>` and, when `<code>` is 1 (a failed run
  call), the line gains `; <name> was listed after the failed launch and was stopped`. (b) `_COMFY_STOPPED_PROD=yes` and
  ComfyUI known gone (or never launched): `restore_from_marker "$(marker_path)" "<the RUN_DIR of step 4>"`; 5 → the code becomes
  5 (the restore's own line is already printed; the marker stays). (c) `echo "r9700: comfy: start: <line>[; its last 200 log
  lines are in <file>]" >&2`; return `<code>`. The lock is released by `comfy_locked` after this returns — last. A signal that
  cut the run call reaches this path through `_comfy_on_signal` (the adapter's interrupt chain, `lib/adapter.sh:139–206`, runs
  the caller's TERM action after it killed the call's group; the calls this path makes are the nested wait that chain allows).
- `_comfy_on_signal <SIG>`: `trap '' INT TERM HUP`; `comfy_start_fail <130|143|129> "interrupted by <SIG>"`; `lock_release`;
  `exit <code>`.
- `comfy_mode_stop`: no argument allowed (2); `config_load_machine` (2); `_rg_listing_tries` (1 with the line); not listed → CT2's
  line, 0; `wslc_stop`; rc 0 → `stopped <name>`, 0; else list again: gone → CT3's line, 0; else CT4's line, 1.
- `comfy_mode_status`: no argument (2); `config_load_machine` (2); `status=0`; the listing (CU3's `containers: not known` and
  `status=1` when it fails; else the two `running|not running` lines); `wslc_inspect "$R9700_COMFY_IMAGE"`: rc ≠ 0 → `not present`;
  else `sed -n 's/.*"Created": *"\([^"]*\)".*/\1/p' | head -n 1`, empty → `created: not known (no Created in the answer)` and
  `status=1`; `wslc_volume_list`: failed → `volumes: not known (<line>)`, `status=1`; else `present|absent` per volume, the cache
  line with `; size: not known (the engine reports no volume size)`. Return `$status`.

**7. `bin/r9700`.** `comfy` in the library list after `run_verb`; the header's verb list (lines 2–4) gains `comfy (E1.S2 of the
ComfyUI plan: start, stop, status)`; `verb_comfy`: the dispatch of CS1 (`[[ $mode =~ ^[a-z]+$ ]]` and `declare -F
"comfy_mode_$mode"`, else the CS1 line with `comfy_modes`), then `"comfy_mode_$mode" "$@"; exit $?`. The exit comment rows: 1
gains `comfy start: the operator's server could not be stopped, or a volume, the remove or the run call failed (nothing of
ComfyUI is left running; the operator's server was restored when this invocation had stopped it); comfy stop: the container did
not stop; comfy status: a state could not be read`; 2 gains `comfy: a refused argument or mode, a machine config refused (the two
name rules of COMFY_CONTAINER among them), a start beside the operator's listed server without --stop-vllm, a container list that
failed three times; every verb under the supervisor: the operator's ComfyUI is listed (the line names bin/r9700 comfy stop)`; 4
gains `(comfy start holds the lock through its readiness wait)`; 5 gains `or was not started beside the operator's ComfyUI (the
marker stays); comfy start: ComfyUI did not become ready (its log tail is saved, it is stopped, the operator's server is restored
when this invocation stopped it), or the container list could not be read after the launch (nothing stopped; the line names
comfy stop and init; the marker stays when the operator's server is owed)`. The `card-free` refusal's words of exit 2 (`the
operator's ComfyUI or the operator's server is listed`) are S3's to add with its `build` row — not here, where no mode uses it yet.

**8. The stub.** `tests/stubs/wslc`: a `remove)` branch (SW1: `stopped/<name>` → `rm`, print the name with CRLF; a running
record → 1 and its line; neither → 1 and its line; `answers/remove_rc` first); in `run_container`, for a detached run, before
`stub_alive`: `[ -f "$R9700_STUB_DIR/stopped/$name" ]` → `stub: container name in use (a stopped container): $name` on stderr,
exit 1; an `inspect)` branch (SW3, `moe_answer inspect_rc 0`); in `exec_in`, BEFORE the `*urlopen*` branch: `[[ ${3:-} == *system_stats* ]]`
→ `word="$(stub_answer comfy_ready)"`; `hang` → `stub_hang`; `ok` → the two lines with CRLF, 0; else `system_stats: URLError`
with CRLF, 1. In `run_container`, for a detached run, AFTER `stub_container_start "$name"` (the container is real and listed
first): `run-delay-<name>` (seconds; read, not removed) → `sleep` that long before the three lines; then `run-fail-<name>` (a
count, the `stop-fail-<name>` shape) → the line `stub: run: the client failed after the container started (scripted): <name>` on
stderr and exit 1 with the container left running. `tests/stubs/stub_common.sh`'s header gains `stopped/<name>`,
`answers/comfy_ready`, `answers/inspect`, `answers/inspect_rc`, `answers/remove_rc`, `run-fail-<name>`, `run-delay-<name>`.

**9. Tests.** `tests/test_comfy.sh` (new; sources `assert.sh`, `stubcase.sh`, `lifecycle.sh`, `kernelcase.sh`, and
`lib/comfy.sh` for `comfy_modes` / `comfy_fetch_name`): `comfy_setup`, `comfy`, `comfy_bg`, `comfy_end`, `comfy_run_argv` as
*Test scenarios* defines them; every wait is a bounded `wait_for` on a call-log line or a file, never a fixed sleep; every
started process is recorded for the killer (`guard_pid`) and `kill_recorded_pids "$CASE"` ends the tests that leave containers.
The other files as the scenario headings say. A test that plants a tail file or a stopped container writes only below
`$R9700_TEST_ROOT`.

**10. Documents.** `research/architecture.md`: the sentence of `:5` becomes ten verbs in five groups, the fifth `ComfyUI on the
same card, one owner at a time (comfy)`; a module row `ComfyUI (E1.S2)` naming `lib/comfy.sh`, `bin/r9700` (`comfy`),
`lib/run_guarded.sh` (`comfy_owner_check`, `comfy_owners_check`, `_rg_card_free`, `_rg_listing_tries`), `lib/step.sh` (the admission's check),
`lib/restore.sh` (`_restore_comfy_free`, the marker key, `ready_wait`'s probe argument), `lib/adapter.sh` (`wslc_remove`,
`wslc_inspect`, `comfy_probe`) with the three modes and the two halves of the rule; a verb row `bin/r9700 comfy` (`start`: the
lock, held through the readiness wait; `stop`, `status`: none); the *Recovery marker* paragraph (`:57`) names `COMFY_CONTAINER`
and the *Restore* paragraph (`:59`) the refusal to start beside it; the exit rows 1, 2, 4, 5 as step 7 words them (the three
places must agree, `tests/test_lifecycle.sh:432`). `README.md`: the line `| \`bin/r9700 comfy <mode>\` | the operator's ComfyUI on
the same card, one owner at a time: \`start\`, \`stop\`, \`status\` |` after the `run` line; the exit list's `1`, `2`, `4`, `5`
items extended in the same words. `research/module_config.md`: the `COMFY_CONTAINER` row's second cell gains `must not start
with CONTAINER_PREFIX and must differ from PROD_CONTAINER, and so must <name>-fetch`, and the sentence of `:25` names both.
`research/module_tests.md`: the `tests/test_comfy.sh` row (`:7–60`); the flow catalogue row `| \`bin/r9700 comfy\` — \`start\`,
\`stop\`, \`status\`; the owner check of every verb under the supervisor; the two-owner admission of the locked entry; the
restore's refusal beside ComfyUI; the failed start reconciled by the container list | covered | \`tests/test_comfy.sh\`
(OC1–OC8, NR7, RM2–RM4, CS1–CS18, CT1–CT5, CU1–CU3), \`tests/test_config.sh\` (NR1–NR6), \`tests/test_restore.sh\` (RM1,
AW6), \`tests/test_stubs.sh\` (SW1–SW6) |`; the *Test knobs* rows for the seven stub files of step 8; in *What it does not prove*:
the `/system_stats` JSON shape (`devices[0].name`) is taken from ComfyUI's source, not observed here — S3's acceptance run 3
records the real device line; the output of `remove` and the refusal of a run whose name a stopped container holds are the
hand-made script's observations, not the toolkit's; `inspect`'s `Created` was observed once (2026-11-07) and its exact format is
re-read at that run. None of the four documents of `check_static.sh --unfinished` may hold `planned`.

**Commands.**

```bash
node tests/run.mjs tests/test_comfy.sh tests/test_config.sh tests/test_restore.sh tests/test_adapter.sh tests/test_stubs.sh tests/test_lifecycle.sh
node tests/run.mjs                                                                  # every test
bash tests/check_static.sh                                                          # syntax, personal paths, seam, documents
node .agents/conventions/tools/leftovers-check.mjs --repo . --token r9700 --identity "the R9700 vLLM tuning toolkit" --profile node
node .agents/conventions/tools/plan-lifecycle.mjs
```

Report the runner's PASS line per file and its total, the static check's exit code, and each RED observation of the scenarios
marked RED first (the failing line, then the pass); for OC3 both symptoms, for CS15–CS17 the container found alive after the
exit and, with `--stop-vllm`, the refused restore with the standing marker.

### Done when

- A `COMFY_CONTAINER` that starts with `CONTAINER_PREFIX` or equals `PROD_CONTAINER` (and the fetch name's two edges) is
  refused at config load, exit 2, before any container is touched (the stub's call log holds no call); NR1–NR7 pass.
- Every verb under `supervise` (the set derived in OC1) exits 2 with the one owner line naming `bin/r9700 comfy stop` while
  `COMFY_CONTAINER` is listed — refused after the prepare with no `stop` in the stub log and no run folder — and behaves
  exactly as before when it is not listed; a ComfyUI started mid-run ends the run at the next admission with the same line,
  starts no further worker, and the one restore at the end does not start the operator's vLLM beside it (exit 5, the marker
  stays, the restore's line names `comfy stop`); a restore after a hard kill does the same (RM2); each seen failing before its
  code existed.
- `comfy start` under a held lock exits 4; beside a listed `PROD_CONTAINER` exits 2, and `--stop-vllm` stops it (marker
  first, logged); missing volumes are made; a stopped container of the name is removed; the readiness wait is `ready_wait` with
  the ComfyUI probe and its ceiling; a start that does not become ready saves the log tail, stops the container and sees it no
  longer listed, restores the operator's vLLM when this invocation stopped it, then releases the lock and exits 5 with one line
  naming the saved log; a signal runs the same path; each refusal seen failing first.
- The failure path decides by the container list, never by the launch call's return: a run call that fails, times out or is
  cut by TERM after the engine created the container ends with `COMFY_CONTAINER` stopped and not listed, and the operator's
  vLLM restored after that stop when this invocation stopped it (CS15–CS17, each seen leaving the container alive before the
  code existed); a list that cannot be read during that cleanup stops nothing, keeps the marker and exits 5 naming `comfy stop`
  and `init` (CS18).
- The locked entry's `card-free` admission (`comfy_owners_check`) exits 2 before the body while either the operator's
  ComfyUI or the operator's vLLM is listed — one line naming what to stop — and runs the body when neither is; a standing
  marker restores vLLM first and the refusal then names it (OC6–OC8, the first two seen failing first). S3's `build` has an
  admission to call and nothing of its own to write for it.
- `comfy stop` of a container that is not listed is not an error; `comfy status` prints the listed states of both containers,
  the image's creation time and the volumes with `size: not known` for the cache; no verb, cleanup or `init` stops
  `COMFY_CONTAINER` or `<COMFY_CONTAINER>-fetch` (NR7).
- `bin/r9700 commands` lists `comfy`; the verb row, the module row, the README line, the marker paragraph and the exit rows
  exist (`tests/test_docs.sh` and `tests/test_lifecycle.sh` green); `bash tests/check_static.sh` exits 0 (the seam is still
  exactly `lib/adapter.sh`); CI green.

---

## E1.S3 — The image and the model sets from the repository: `comfyui/`, `comfy build`, `comfy fetch`, the documents, the acceptance

**Cornerstone:** no. **Depends on:** E1.S1; E1.S2 merged before the two verb modes are coded (they are rows of S2's dispatch
and take the lock through S2's entry). **Spec:** this section (Opus). **Code:** one Sonnet coder; the acceptance runs by the
operator's session.

### Goal

The image recipe, the program that starts ComfyUI inside it, the model download and the pinned model sets live in
`comfyui/`, with no machine value in them. `bin/r9700 comfy build` makes the image on any PC this toolkit's `machine.env`
describes and checks the ARTEFACT — a throwaway container of the built image must see a ROCm device — not the build's exit
code. It enters through S2's `comfy_locked build card-free …`, so it refuses (exit 2) while the operator's ComfyUI or the
operator's vLLM is listed, before anything is placed or built (a build takes minutes). It builds to a stamped tag
`<repository of COMFY_IMAGE>:<UTC stamp>`, checks THAT tag, and only a passed check points `COMFY_IMAGE` at it; a rejected
build leaves `COMFY_IMAGE` and the earlier stamped tags as they were. The newest four stamped tags are kept (the current one
plus three to roll back to) and older ones are removed by their exact tag. `bin/r9700 comfy fetch <set>...` puts a named model
set where ComfyUI reads it, every file accepted only when its own sha256 equals the one pinned in the repository; a fetch takes
a lock of its own (never the GPU lock, so it still runs beside a series) and refuses while a fetch container is still listed,
so no two downloads ever write one `.part`. The hand-made folder is no longer needed to run ComfyUI on this PC.

Out of scope: `comfy build --rollback`. A rollback is one command by hand, written in the README's ComfyUI section and in
`research/module_comfyui.md`: `wslc tag <repository>:<older stamp> <COMFY_IMAGE>`, then `bin/r9700 comfy start`.

### Files

| File | Change |
|---|---|
| `comfyui/Containerfile` | new: the hand-made `Containerfile` lines 11–57 with the machine values out (brief 1) |
| `comfyui/entrypoint.sh` | new: the hand-made `entrypoint.sh` with two test knobs (brief 2) |
| `comfyui/fetch_model.sh` | new: the hand-made `tests/fetch_model.sh` rewritten around the pinned hash (brief 3) |
| `comfyui/models.conf` | new: the three sets with pinned sha256 (brief 4) |
| `lib/comfy.sh` | `comfy_assets`, `comfy_win_dir`, `comfy_models_conf`, `comfy_models_load`, `comfy_sets`, `comfy_build_stamp`, `comfy_images_prune`, the `build` and `fetch` modes and bodies, the check program (brief 5) |
| `lib/adapter.sh` | `wslc_tag`, `wslc_rmi`, `wslc_image_list` after S2's `wslc_inspect`; three rows in the header table (brief 5a) |
| `lib/run_guarded.sh` | `lock_take` gains an optional second argument, the lock file's name in the state directory; S2's `_rg_listing_tries` an optional lister (brief 5b) |
| `bin/r9700` | the rows `build` and `fetch` in S2's mode dispatch; the exit comment rows 1, 2 and 4 (brief 6) |
| `tests/stubs/wslc`, `tests/stubs/stub_common.sh` | the image records (`build -t`, `tag`, `image list`, `rmi`), the check container's answer, the fetch container as a recorded foreground container (brief 7) |
| `tests/test_comfy.sh` | scenarios IM1–IM5, FM1–FM12, MC1–MC3, BU1–BU16, FE1–FE9 (appended to S2's file) |
| `tests/test_adapter.sh`, `tests/test_stubs.sh`, `tests/test_restore.sh` | AI1–AI5; SI1–SI5; FL1 |
| `tests/fixtures/comfy/file_server.py` | new: the local file server of the `fetch_model.sh` tests (brief 8) |
| `research/module_comfyui.md` | new (brief 9) |
| `research/README.md` | its row (`tests/test_docs.sh:101`) |
| `research/architecture.md`, `research/module_tests.md`, `README.md` | the rows and the section of brief 9 |

### Test scenarios

All in `tests/test_comfy.sh`, through `tests/run.mjs`. Verb scenarios use `setup_case` and the stub; `fetch_model.sh`
scenarios run the script on the host with `bash comfyui/fetch_model.sh …` against `file_server.py`, with the test knobs
`R9700_TEST_FETCH_STORE` and `R9700_TEST_FETCH_MODELS` pointing below `$R9700_TEST_ROOT`, and the proxy variables
(`http_proxy`, `https_proxy`, `HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `no_proxy`) unset for the call. A file's sha256 in a
test is computed with `sha256sum` from the bytes the test wrote (never typed).

**The image files**

- IM1 *The image never sets `PYTORCH_HIP_ALLOC_CONF` (trap 1) and says why.* No code line (a line not starting with `#`) of
  `comfyui/Containerfile` or `comfyui/entrypoint.sh` names `PYTORCH_HIP_ALLOC_CONF`; a comment line of the Containerfile
  does, with `hipErrorInvalidValue` in the same comment block. Companion (the scan is alive): the same grep finds the name in
  a planted copy that sets it in its `ENV` line.
- IM2 *The build's defaults are the field table's.* The `ARG BASE=` and `ARG COMFYUI_REF=` values of `comfyui/Containerfile`
  equal the defaults `config_keys` prints for `COMFY_BASE_IMAGE` and `COMFY_REF` (read, never typed). RED first: a planted
  copy with another tag fails.
- IM3 *The Manager uses pip in each of its three starting states (trap 2).* `R9700_TEST_COMFY_ROOT=<case>/root`,
  `R9700_TEST_ENTRY_DRY=1`, `bash comfyui/entrypoint.sh`: with no `config.ini`, the file is made with `[default]` and
  `use_uv = False`; with `use_uv = True`, that line becomes `use_uv = False`; with a `[default]` section and no `use_uv` line,
  the line is added under it. Each exits 0.
- IM4 *A venv of another Python version is moved aside, never deleted; a venv of this version is kept.* A planted
  `<root>/data/venv/pyvenv.cfg` with `version = 3.11.0` and a marker file: after the run the marker is in
  `<root>/data/venv.python-3.11.0.<stamp>/` and a new `<root>/data/venv/bin/python` exists. A second run keeps the new venv
  (a marker planted in it survives). The planted version is not the host's (`python3 -c` prints the host's; the test picks
  one that differs).
- IM5 *ComfyUI starts with the volumes' folders and the extra arguments.* The dry run prints, one word per line, the venv's
  python, `/opt/ComfyUI/main.py`, `--listen 0.0.0.0 --port 8188 --base-directory <root>/data --models-directory <root>/models
  --enable-manager`, then the test's extra `--reserve-vram 2`; every folder of the hand-made lines 5–9 exists below `<root>`.

**`fetch_model.sh` against the local file server** (the server serves a folder of the test; a file `<name>.etag` beside a
file makes the server send `X-Linked-Etag: "<content>"` for it; `/r/<name>` answers `302` to `/<name>` with that header, the
way the source does; `Range: bytes=<n>-` answers `206`; every request is logged as `<METHOD> <path> <range or ->`).

- FM1 *A file the source publishes with the pinned sha256 goes to the store, then to the models folder.* Store folder
  present, the request through `/r/`: exit 0; `<store>/vae/x.bin` and `<models>/vae/x.bin` hold the bytes; no `.part` is
  left; the last line is `fetch: done vae/x.bin <size> sha256 <hash>`.
- FM2 *A source that publishes no sha256 is accepted when the bytes match the pin.* No `.etag` file: exit 0, one line says
  the source publishes none and the pin decides; the file is kept because the download's own sha256 equals the pin (the
  header's absence never refuses, and its presence never replaces the check of FM4).
- FM3 *A source that publishes another sha256 is refused before anything is downloaded.* `.etag` holds another hash:
  exit 3; one line names `vae/x.bin`, both hashes and `nothing downloaded`; the server log holds only `HEAD` requests for it;
  no file and no `.part` in the store or the models folder. RED first: against the hand-made script's logic (it trusts the
  published hash) the file is downloaded.
- FM4 *Bytes that do not match the pin are not kept.* The server serves other bytes and no `.etag`: exit 4; one line names
  both hashes; the `.part` is removed (a kept wrong `.part` would be resumed from its end at the next fetch and never match);
  the models folder has no file. RED first.
- FM5 *A partial download is resumed.* A `.part` with the first half of the bytes in the store: the server log holds one GET
  with `bytes=<half>-`; exit 0; the file matches.
- FM6 *A `.part` that is already whole is moved into place without a request.* A `.part` with the whole bytes: no GET in the
  server log; exit 0.
- FM7 *A file already right in the store is not downloaded again.* No GET; the models folder gets a checked copy when it lacks
  the file, and nothing when it has the right one (`fetch: local ok`).
- FM8 *A right file in the models folder fills a store that lacks it, without a download* (the hand-made lines 30–32). No GET.
- FM9 *Without a store, the file goes straight to the models folder.* `R9700_TEST_FETCH_STORE` names a folder that does not
  exist: exit 0, no folder of that name is made, the file is in the models folder, the `.part` moved by one rename.
- FM10 *Bad arguments are refused before any request.* An argument count that is not a multiple of three, a sha256 of 63
  characters, an upper-case sha256, a folder `../x` or `a/b`, a URL without `http://` or `https://`: each exit 2 with one line,
  and the server log is empty.
- FM11 *A copy that fails is not kept.* A store file whose bytes match the pin while the copy target's folder is a
  read-only folder: exit 4 with one line naming the folder; no `.part` is left in the models folder. (If the host
  cannot make a folder read-only for the test's user — root in a container — the scenario is skipped with that reason printed.)
- FM12 *Two files in one call: the second's refusal leaves the first done.* The first file right, the second with another
  published hash: exit 3; the first is in both places, the second nowhere.

**`comfyui/models.conf`**

- MC1 *Every line of the real file is well formed.* Every non-comment line has four words: a set `^[a-z0-9]+$`, a folder
  `^[a-z_]+$`, an `https://` URL, a sha256 `^[0-9a-f]{64}$`; no basename twice in one folder; `comfy_models_load` returns 0
  on it. Parity row (the parse reads real lines): the line of `z_image_turbo_bf16.safetensors` carries
  `2407613050b809ffdff18a4ac99af83ea6b95443ecebdf80e064a79c825574a6`.
- MC2 *A malformed line is refused with its place.* Copies written by the test (`R9700_COMFY_MODELS_CONF` names the copy):
  a 63-character hash, three words, a set `Zimage`, the same file twice in a folder — each `comfy_models_load` returns 2 with
  `r9700: comfy: <file>:<line>: <problem>`.
- MC3 *The legal sets are the file's.* `comfy_sets` prints the set names in file order, each once (derived; the test compares
  them with an `awk` over the same file, not with a typed list).

**`comfy build`** (the stub answers the check container with `answers/comfy_check`, default the four lines of an R9700:
`torch 2.13.0+rocm10.1.0`, `hip 10.1.0`, `device AMD Radeon AI PRO R9700`, `matmul ok`; the stub keeps its images as records,
SI1–SI4; every build scenario sets `R9700_TEST_COMFY_STAMP` so its stamp is known, `20261107T120000Z` unless it says
otherwise; "the stamped tag" is `comfyui-r9700:<that stamp>` with the default `COMFY_IMAGE=comfyui-r9700:local`; "four
planted stamped tags" are records `comfyui-r9700:2026110<k>T100000Z` for k = 1..4, each with an image id of its own, and
`comfyui-r9700:local` on the id of k = 4, the state a run of four passed builds leaves)

- BU1 *The build places its files, hash-checked, before it builds.* With no placed copy: after `bin/r9700 comfy build` (exit
  0), `$WORK_DIR/r9700/comfyui/{Containerfile,entrypoint.sh,fetch_model.sh}` equal the repository's files by sha256. With a
  stale placed copy (other bytes): it is rewritten before the `build` call (the call log's order).
- BU2 *The build argv is the config's, one word each, and it names the stamped tag, never `COMFY_IMAGE`.* `argv_of wslc` for
  the `build` call is exactly `build -t comfyui-r9700:20261107T120000Z -f <WIN>\r9700\comfyui\Containerfile --build-arg
  BASE=<COMFY_BASE_IMAGE> --build-arg COMFYUI_REF=<COMFY_REF> <WIN>\r9700\comfyui`, the values read from the loaded config
  (the repository is `COMFY_IMAGE` without its `:<tag>`, computed from the config, not typed); `--no-cache` appears only with
  `comfy build --no-cache`. A `WORK_DIR_WIN` that ends in `\` (`X:\`) gives `X:\r9700\comfyui`, never a doubled backslash.
  Without the knob the stamp is the UTC clock's, `^[0-9]{8}T[0-9]{6}Z$`.
- BU3 *The stamped image is checked by a throwaway container on the card.* After the build, one foreground `run --rm --name
  <CONTAINER_PREFIX>comfy-check --gpus all --entrypoint python3 comfyui-r9700:20261107T120000Z -c <program>` (its words read
  with `argv_of`: the check runs the STAMPED tag, the image just built, never `COMFY_IMAGE`); stdout holds `comfy: build:
  device AMD Radeon AI PRO R9700`; exit 0.
- BU4 *A built image without a ROCm device is refused, and nothing it was about to replace moves.* Four planted stamped tags;
  `answers/comfy_check` with `hip None`, then with `device none`, then with `matmul nan`: each exit 1 and one line `r9700:
  comfy: build: the built image comfyui-r9700:20261107T120000Z is not usable on the card: <the check's line>; comfyui-r9700:local
  was not moved`; no `tag` call; exactly one `rmi`, its argv exactly `rmi comfyui-r9700:20261107T120000Z` (the rejected
  stamped tag, by its exact name); afterwards the stub's records are the planted ones exactly (the four stamped tags and
  `comfyui-r9700:local` on the id of k = 4, compared record by record). `answers/comfy_check_rc` 1: the same. RED first: the
  build written the old way (`-t <COMFY_IMAGE>`) leaves `comfyui-r9700:local` on the rejected image.
- BU5 *A failed build starts no check container and moves nothing.* Four planted stamped tags. `answers/build_rc` 1: exit 1,
  one line naming the build's code, no `run` call in the log, no `tag` call, the records unchanged (the stub records no tag
  for a failed build, so no `rmi` is made; a stamped tag the image list DOES show after a failed build is removed by its
  exact name: `answers/build_tags_on_failure` 1, the stub's way to say the engine tagged before it failed, gives one `rmi
  comfyui-r9700:20261107T120000Z`). A build cut by its ceiling (`answers/build_seconds` 100, `COMFY_BUILD_MAX_S=600` with
  `R9700_CEILING_SCALE=100`: a 6 s ceiling; not `mode`, which would hang the verb's other calls too): exit 1, the line says
  the ceiling ended it, no check container is started, no `tag` call.
- BU6 *A placement that cannot be written is refused before any engine call after the admission.* `$WORK_DIR/r9700` is a
  file: exit 2 with the placement's line; the call log holds the entry's container `list` calls (S2's card-free admission
  comes first) and no `image`, `build`, `run`, `tag` or `rmi` call.
- BU7 *`build` takes the lock.* Another holder of the lock (the shape of the lifecycle tests' held lock): exit 4, no `wslc`
  call; after a successful build the lock is free (a second `build`, with another stamp, takes it).
- BU8 *The grammar is checked before the lock.* `comfy build --frob` and `comfy build extra`: exit 2, one line with the legal
  options, no lock file, no call. No `--model` is needed with two model files in `models/` (the machine config alone).
- BU9 *A build is refused while the operator's ComfyUI is listed, before the placement and before the build.* `comfyui`
  listed (S2's shape): exit 2; exactly one stderr line, S2's owner line with `comfyui` and `bin/r9700 comfy stop`; no placed
  copy under `$WORK_DIR/r9700/comfyui/` (none was there before); no `image`, `build`, `run`, `tag` or `rmi` call; no `stop`;
  `comfyui` still listed; the lock free afterwards. A container named `comfyuix` listed instead: exit 0 (a whole name, S2's
  rule). RED first: the build runs beside `comfyui` (a `build` call in the log).
- BU10 *A build is refused while the operator's vLLM is listed, naming it — and a standing marker restores vLLM first and is
  then refused.* `vllm` listed: exit 2; exactly one stderr line, S2's server line with `vllm`; no placement, no `image`,
  `build` or `run` call, no `stop`, no `pwsh.exe`; `vllm` still listed. Then `write_marker` (vLLM was running, down now),
  nothing listed: the restore ran first (one `pwsh.exe -Detach`, `vllm` listed, the marker gone), THEN exit 2 with the server
  line, and no `build` call: the build never starts beside the server the restore just brought back. Both `comfyui` and
  `vllm` listed: the owner line (ComfyUI's), one line only. RED first: the build runs beside `vllm`.
- BU11 *A good build is promoted only after its check, and the image it replaces keeps its stamped tag.* Four planted stamped
  tags; `answers/build_id` names the new image's id: exit 0; the call order is `build` < the check's `run` < `tag`; the `tag`
  argv is exactly `tag comfyui-r9700:20261107T120000Z comfyui-r9700:local`; afterwards `comfyui-r9700:local` is on the new id
  and `comfyui-r9700:20261104T100000Z` still on the id `comfyui-r9700:local` had before (the replaced image is not left
  untagged); stdout holds `comfy: build: comfyui-r9700:local now names comfyui-r9700:20261107T120000Z`. With no planted record
  at all (the first build on a PC): exit 0, the two records `comfyui-r9700:20261107T120000Z` and `comfyui-r9700:local`, no
  `rmi`. RED first (the promotion).
- BU12 *A fifth passed build removes exactly the oldest stamped tag, by its exact name, after the promotion.* Four planted
  stamped tags plus `rocm/pytorch:<tag>` and an untagged `<none> <none>` record (another repository and the engine's leftovers,
  never ours to remove): exit 0; exactly one `rmi`, its argv exactly `rmi comfyui-r9700:20261101T100000Z`, after the `tag`
  call; stdout `comfy: build: removed comfyui-r9700:20261101T100000Z`; afterwards four stamped tags (k = 2..4 and the new one),
  `rocm/pytorch` and the untagged record untouched. Six planted (k = 1..6, `comfyui-r9700:local` on k = 6): two `rmi` calls,
  k = 1 and k = 2, each one exact tag. Every `rmi` argv of the file's scenarios is two words, `rmi` and one
  `comfyui-r9700:<stamp>` — never an id, never a pattern, never `-f` (the test reads every `rmi` line of `calls.argv`). A
  record `comfyui-r9700:old-build` (not stamp-shaped) is never removed. RED first (the retention).
- BU13 *A stamped tag whose image is the one `COMFY_IMAGE` names is never removed.* Five planted stamped tags (k = 1..5) where
  `answers/build_id` gives the new build the id of k = 1 (a cached rebuild of the same image): after the promotion
  `comfyui-r9700:local` is on that id, and k = 1, the oldest, is NOT removed: no `rmi` of it, stdout `comfy: build: kept
  comfyui-r9700:20261101T100000Z: it is the image comfyui-r9700:local names`; k = 2, the next oldest past the four, is removed.
  The same guard on the rejected tag: `answers/build_id` = the id `comfyui-r9700:local` names, and the check fails (`hip
  None`): exit 1, no `rmi` at all, the line says the rejected tag `is the image comfyui-r9700:local already names; kept`.
- BU14 *The retention runs only on a view it can trust.* A passed build with `fail-image-list "1 3"` (the list before the
  build answers, the three after the promotion fail): exit 0 (the image passed and is promoted), one stderr line `r9700: comfy:
  build: warning: the image list failed 3 times (<the stub's line>); no old image was removed`, no `rmi`. `answers/image_list`
  (a scripted listing, SI3) that lacks the new stamped tag after the promotion: exit 0, one warning line `the image list does
  not show comfyui-r9700:20261107T120000Z; no old image was removed`, no `rmi`. An `rmi` that fails (`answers/rmi_rc 1`): exit
  0, one warning line naming the tag and the code, the other removals still made.
- BU15 *The stamp is checked before anything is built.* `COMFY_IMAGE=comfyui-r9700:20261101T100000Z` (a stamp-shaped tag:
  the retention would count it as one of its own) → exit 2, one line `r9700: comfy: build: COMFY_IMAGE's tag
  "20261101T100000Z" has the shape of a build stamp; give it another tag`, no placement,
  no `image` or `build` call. `R9700_TEST_COMFY_STAMP=bad` → exit 2 naming the knob. The stamped tag already listed (planted
  with the knob's stamp: two builds in one second, or a clock that went back) → exit 1, one line `the tag
  comfyui-r9700:20261107T120000Z exists already; nothing was built`, no `build` call. A pre-build image list that fails 3
  times → exit 1, the line names the list, no `build` call.
- BU16 *A promotion that fails leaves the passed image to tag by hand.* `answers/tag_rc 1`: exit 1, one line `r9700: comfy:
  build: comfyui-r9700:20261107T120000Z passed its check but comfyui-r9700:local was not moved (code 1): <the stub's line>; tag
  it by hand (README, ComfyUI)`; no `rmi` (neither the passed tag nor an old one), the records otherwise unchanged.

**`comfy fetch`** (the stub answers the fetch container with `answers/comfy_fetch.log`, `answers/comfy_fetch_rc` and
`answers/comfy_fetch_seconds`, and records it as a listed container for as long as it runs, SI5; "the fetch lock" is
`<state dir>/comfy-fetch.lock`, "the GPU lock" `<state dir>/lock`)

- FE1 *One foreground container, not prefixed, without the card, with the pinned triples.* `comfy fetch zimage`: one call
  `run --rm --name <COMFY_CONTAINER>-fetch -v <COMFY_MODELS_VOLUME>:/models -v <WORK_DIR_WIN>:/work:ro --entrypoint bash
  <COMFY_IMAGE> /work/r9700/comfyui/fetch_model.sh` followed by the set's `<folder> <url> <sha256>` triples in file order (read
  from `comfy_models_load`, compared word by word); no `--gpus`; no `/store` mount; `fetch_model.sh` placed first; exit 0.
- FE2 *A store adds its mount.* `COMFY_STORE_WIN="X:\models-store"`: the argv gains `-v X:\models-store:/store` before the
  image.
- FE3 *Several sets, each file once.* `comfy fetch zimage wan5b zimage`: six triples, `zimage`'s first, none twice.
- FE4 *An unknown set is refused before any call.* `comfy fetch nosuch`: exit 2, one line `r9700: comfy: fetch: unknown set
  "nosuch"; legal: <comfy_sets output, space-separated>`, no `wslc` call. `comfy fetch` with no set: exit 2 with the usage.
  RED first.
- FE5 *The container's verdict becomes the verb's.* `answers/comfy_fetch_rc` 3: exit 2, the container's lines printed and one
  line saying the source publishes another sha256 than `comfyui/models.conf` pins; 4: exit 1; 124 (the ceiling): exit 1 and
  the line says the ceiling ended it.
- FE6 *`fetch` takes its own lock and never the GPU lock.* While a `step_bg … worker.sh child` holds the GPU lock, `comfy
  fetch zimage` runs (exit 0, the `run` call made) and the GPU lock's holder line is still the step's; while a fetch runs
  (`comfy_bg fetch zimage`, `answers/comfy_fetch_seconds` 30, wait for the `run` call), `r9700 step --model <35B> t --
  worker.sh ok` takes the GPU lock and exits 0. After a fetch the fetch lock is free (`flock -n <state>/comfy-fetch.lock
  true`) and holds the holder line `<pid> comfy-fetch <UTC time>`. RED first: a fetch without the lock of its own passes FE8's
  second-fetch case.
- FE7 *The models volume is made when it is missing, and only then.* No stub volume: one `volume create <COMFY_MODELS_VOLUME>`
  before the `run`; the volume present: no create.
- FE8 *A second fetch while one runs is refused with exit 4, naming the holder.* `comfy_bg fetch zimage` with
  `answers/comfy_fetch_seconds` 30; `wait_for` the first `run` call; `comfy fetch wan5b` → exit 4, exactly one stderr line
  `r9700: another run holds <state>/comfy-fetch.lock: pid <the first fetch's pid>, comfy-fetch, since <UTC time>` (the
  `lock_take` line, FL1); one `run` call in the log, not two; no placement rewrite and no `volume` call by the second; `comfy_end`
  of the first → 0. A `comfy fetch` refused for an unknown set (FE4) while the first runs is still exit 2: the grammar and
  the sets are checked before the lock. RED first.
- FE9 *A fetch container left running by a killed fetch is refused — the next fetch never touches its `.part`.* `comfy_bg
  fetch zimage` (`answers/comfy_fetch_seconds` 30), `wait_for` the stub's record `containers/comfyui-fetch.pid` alive, `kill
  -KILL $SUP`: the stub's fetch container lives on (its `timeout` group is not the verb's), and the fetch lock is FREE
  (`flock -n <state>/comfy-fetch.lock true` → 0: descriptor 9 is closed for every child, amendment A1, so a killed verb leaves
  no lock behind). Then `comfy fetch zimage` → exit 4, exactly one stderr line `r9700: comfy: fetch: a fetch container is
  still running: comfyui-fetch; wait for it or stop it`; one `run` call in the log (the first's), no second; the fetch lock
  free afterwards; the test ends the container (`kill_recorded_pids`). The same with the fetch container planted by hand
  (`wslc run -d --rm --name comfyui-fetch img`, no fetch ever ran, no lock held): exit 4 and the line. A container named
  `comfyui-fetchx` listed: exit 0 (a whole name). `fail-list 3`: exit 2, one line `r9700: comfy: fetch: the container list
  failed 3 times (<the stub's line>)`, no `run`, the fetch lock free. RED first: the second fetch starts a `run` whose
  container would write the first's `.part` (in the stub it is refused by name, exit 1 — the engine's backstop, not ours).

**The image calls of the adapter (`tests/test_adapter.sh`)** — `setup_case` puts the stubs first on `PATH`.

- AI1 *`wslc_tag` hands on two references and refuses anything else before a call.* `wslc_tag comfyui-r9700:20261107T120000Z
  comfyui-r9700:local` → `argv_of wslc` is exactly `tag comfyui-r9700:20261107T120000Z comfyui-r9700:local`, the child's code,
  its lines without CR. `wslc_tag -x a:b`, `wslc_tag a:b ''`, `wslc_tag 'a b' c:d`, `wslc_tag a:b` (one word) → 2, one line
  naming `wslc_tag` and `reference`, no call.
- AI2 *`wslc_rmi` removes ONE exact tag and nothing that could mean more.* `wslc_rmi comfyui-r9700:20261107T120000Z` → argv
  exactly `rmi comfyui-r9700:20261107T120000Z`. Refused with 2, one line naming `wslc_rmi` and `exact image tag
  (<repository>:<tag>; never an id, a pattern or an option)`, and no call: `comfyui-r9700` (no tag: the engine would read
  `:latest`), `sha256:5662f4cbd417` (an id form), `5662f4cbd417`, `-f`, `comfyui-r9700:*`, `''`, and two words (`wslc_rmi a:b
  c:d`). RED first: a first version that only checks the reference shape of AI1 passes `sha256:…` and `5662f4cbd417`.
- AI3 *`wslc_image_list` prints repository, tag and id, one image per line.* `answers/image_list` holds the header and three rows
  of the `--no-trunc` listing observed on 2026-11-07 (brief 5a, copied into the fixture as they stand there) with CRLF ends:
  the output is exactly three lines, `comfyui-r9700 local sha256:5662f4cb…`, `<none> <none> sha256:7ce514fe…`, `<none> <none>
  sha256:b6251d53…` (the whole ids; the expected words are cut from the fixture's own rows by the test, not typed a second
  time), no header, no CR, no CREATED or SIZE word (`6 hours ago` is three words and is never read); argv `image list
  --no-trunc`. `fail-image-list 1`: non-zero, nothing on stdout.
- AI4 *The ceilings are the documented ones* (`:297`, as S1 and S2 extended it): `wslc_tag a:b c:d`, `wslc_rmi a:b`,
  `wslc_image_list` add `5 60 5 60 5 60`.
- AI5 *No carriage return from the three* (`:84` extended).

**The stub's images and the fetch container (`tests/test_stubs.sh`)**

- SI1 *A build records its tag only when it succeeds.* `wslc build -t r:t1 -f F C` → `images` gains the record `r t1 <id>`,
  the id `sha256:` and 64 hex characters (`answers/build_id` when present, else made from the stub's call counter, distinct per
  build); a second build with `-t r:t1` moves the record to the new id (the engine's way: the old image would be left
  untagged); `answers/build_rc 1` → no record, unless `answers/build_tags_on_failure` 1.
- SI2 *`tag` points a second name at an existing image.* `wslc tag r:t1 r:local` → `r local <id of r:t1>`, 0, prints nothing;
  a missing source → 1 with `stub: tag: no such image: <source>`; `answers/tag_rc 1` → 1, one `stub: tag failed (scripted)`
  line, no record changed.
- SI3 *`image list` prints the observed table.* The header `REPOSITORY      TAG      IMAGE ID      CREATED       SIZE` and one
  row per record, `<repository>   <tag>   <id>   6 hours ago   27.3GB`, CRLF ends; with `--no-trunc` the id is the whole
  `sha256:<64 hex>`, without it the first 12 hex characters (both observed, brief 5a); `answers/image_list` present → that
  file printed instead (CRLF added); `fail-image-list` → the counting shape of `fail-volume-list` (`"<count>"` or `"<skip>
  <count>"`, as `fail-list`), one `stub:` line, exit 1.
- SI4 *`rmi` removes exactly the named record.* `wslc rmi r:t1` with records `r t1`, `r local` on one id → only `r t1` goes,
  `r local` stays, 0, prints `Untagged: r:t1` with CRLF; a missing reference → 1 with `stub: rmi: no such image: <ref>`;
  `answers/rmi_rc 1` → 1, `stub: rmi failed (scripted)`, nothing removed; more than one reference or a word starting `-` → 2
  (`stub: rmi: one exact reference only`, so a caller that passes `-f` or a list fails loudly in CI).
- SI5 *The fetch container is a listed container for as long as it runs.* `wslc run --rm --name f --entrypoint bash img
  /work/r9700/comfyui/fetch_model.sh a b c` with `answers/comfy_fetch_seconds` 3: `wslc list` from another process shows `f`
  within the first second, the record goes when the run ends (however it ends: the shape of `moe_foreground`), the output is
  `answers/comfy_fetch.log` (default one `stub fetch` line) with CRLF, the code `answers/comfy_fetch_rc` (default 0); a second
  such run named `f` while the first lives → 1, `stub: container name in use: f`; a KILL of the process that started the
  first leaves `f` listed until its own sleep ends.

**The lock file argument (`tests/test_restore.sh`, beside `t_lock_take_writes_the_holder_line_…`, `:33`)**

- FL1 *`lock_take` takes a named lock file of the state directory and the default is unchanged.* `holder comfy-fetch` with
  `lock_take comfy-fetch comfy-fetch.lock`: `<state>/comfy-fetch.lock` holds `<pid> comfy-fetch <time>`; a second `lock_take
  comfy-fetch comfy-fetch.lock` → 4 with `r9700: another run holds <state>/comfy-fetch.lock: pid <pid>, comfy-fetch, since
  <time>`; meanwhile `lock_take step` in another process takes `<state>/lock` (0): the two files are two locks. A name with a
  `/`, a leading `.` or `-`, or empty → 2, one line `lock_take: "<x>" is not a lock file name`, no file made. Every existing
  lock test of the file passes without an edit (one argument: `lock`, as today).

### Brief for the Sonnet coder

Read first: this section and *Facts every story uses*; the parent's *The `comfyui/` folder*, the verb-table rows `build` and
`fetch`, *Records and growth*; the hand-made files (the main session gives their location); `lib/moe_verb.sh:31–49`
(`moe_place`), `lib/moe.sh:35–61` and `:94–99` (`_MOE_REPO`, `moe_placed_dir`, `_moe_sha`, `moe_assets`), `lib/kernels.sh:40`
and `lib/kernels_verb.sh:166–169` (how another assets function reuses `moe_place`); S2's merged `lib/comfy.sh` and
`verb_comfy` (`comfy_locked`, `comfy_owners_check`, `_rg_listing_tries`, `comfy_fetch_name`, `comfy_volume_ensure`);
`lib/run_guarded.sh:88–116` (`lock_take`, `lock_release`); `lib/adapter.sh:111–116` (`_adapter_drop_lock`) and `:244–334`
with S2's `wslc_inspect` and `_ADAPTER_REF_RE`; `tests/stubs/wslc:28–60` (`moe_foreground`) and `:143–173`. Reuse, never copy:
`moe_place <assets fn>` for the placement, `container_name` (`lib/serve.sh:104`) for the check container's name, `wslc_build` /
`wslc_run_once` / `wslc_volume_list` / `wslc_volume_create` and this story's `wslc_tag` / `wslc_rmi` / `wslc_image_list` for
every call, S2's lock entry, its two-owner admission and its volume helper (if S2 wrote no volume helper, write
`comfy_volume_ensure <name>` here and make `start` call it — one helper, not two), `lock_take` for the fetch lock (widened,
5b — never a second flock routine).

**1. `comfyui/Containerfile`.** The hand-made lines 11–57, with: a header that says what the file is and that
`bin/r9700 comfy build` (`lib/comfy.sh`) builds it from `$WORK_DIR/r9700/comfyui/` with `BASE` and `COMFYUI_REF` from
`COMFY_BASE_IMAGE` and `COMFY_REF` (no command line with a folder, no fallback note); `curl` added to the apt list of line 18
(`fetch_model.sh` runs in this image; the hand-made folder relied on the base having it); the trap-1 comment (lines 42–44)
kept word for word with its date; nothing else changed. The defaults of `ARG BASE` and `ARG COMFYUI_REF` stay equal to the
field table's (IM2).

**2. `comfyui/entrypoint.sh`.** The hand-made 46 lines, with two test knobs (environment only): `R9700_TEST_COMFY_ROOT`
(default empty) is put in front of `/data`, `/models` and `/cache` everywhere, the `main.py` arguments included;
`R9700_TEST_ENTRY_DRY=1` prints the final argv one word per line instead of the `exec`. The comments of lines 11–13 and 28–30
stay. The `/opt/ComfyUI/main.py` path does not take the root (it is the image's).

**3. `comfyui/fetch_model.sh`.** `set -euo pipefail`; arguments are triples `<folder> <url> <sha256>`; ALL are checked before
the first request (FM10; exit 2). `STORE="${R9700_TEST_FETCH_STORE:-/store}"`, `MODELS="${R9700_TEST_FETCH_MODELS:-/models}"`;
the store is used when the folder exists, never made. Per file, in order:

- `name` = the URL's basename without a query; the published hash = the LAST `x-linked-etag` value of
  `curl -sIL --connect-timeout 30 --max-time 120 "$url"` (the hand-made line 25 pattern; a failed `HEAD` gives none: `|| true`),
  its quotes and spaces stripped and lower-cased before the comparison. Published and different from the pin → exit 3 with
  the FM3 line, before any GET. Published equal, or none → go on (FM2's line when none). The pin is the authority either way:
  the file is kept only when the download's own sha256 equals it (FM4); the header is a pre-flight cross-check, never the
  acceptance.
- Store present: `ok_hash store` → `fetch: store ok`; else `ok_hash models` → checked copy models → store (FM8); else a
  `.part` that already has the pin → `mv` (FM6); else `curl -sSfL --connect-timeout 30 -C - -o "$store.part" "$url"`, then
  `ok_hash .part` or remove the `.part` and exit 4 with both hashes (FM4), then `mv`. Then the models copy: `ok_hash models` →
  `fetch: local ok`, else the checked copy (`copy_checked`: `cp` to `<dest>.part`, check, `mv`; on a mismatch or a failed `cp`
  remove `<dest>.part` and exit 4 — FM11).
- No store: the same download into `"$MODELS/$folder/$name.part"`, checked, one `mv` (FM9).
- The last line per file: `fetch: done <folder>/<name> <size from du -h> sha256 <pin>`.

The hand-made behaviours kept: resume, store first, store from a right local copy, no copy of a file already right. Removed:
the refusal without a store (line 10), the refusal of a source that publishes no hash (line 26), the operator's paths.

**4. `comfyui/models.conf`.** A comment header: the line format `<set> <folder> <url> <sha256>`; that the sha256 is PINNED
(read once from the source's `X-Linked-ETag` on 2026-11-07 and checked by every download), that `fetch` refuses a source
that now publishes another one, and that a pin is changed only by a reviewed commit; the sizes per set. Then, exactly:

```text
# set    folder            url                                                                                                                      sha256
sd15     checkpoints       https://huggingface.co/Comfy-Org/stable-diffusion-1.5/resolve/main/v1-5-pruned-emaonly-fp16.safetensors                  e9476a13728cd75d8279f6ec8bad753a66a1957ca375a1464dc63b37db6e3916
zimage   vae               https://huggingface.co/Comfy-Org/Z-Image-Turbo/resolve/main/split_files/vae/ae.safetensors                               afc8e28272cd15db3919bacdb6918ce9c1ed22e96cb12c4d5ed0fba823529e38
zimage   text_encoders     https://huggingface.co/Comfy-Org/Z-Image-Turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors              6c671498573ac2f7a5501502ccce8d2b08ea6ca2f661c458e708f36b36edfc5a
zimage   diffusion_models  https://huggingface.co/Comfy-Org/Z-Image-Turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors  2407613050b809ffdff18a4ac99af83ea6b95443ecebdf80e064a79c825574a6
wan5b    vae               https://huggingface.co/Comfy-Org/Wan-2.2/resolve/main/split_files/vae/wan2.2_vae.safetensors                             e40321bd36b9709991dae2530eb4ac303dd168276980d3e9bc4b6e2b75fed156
wan5b    diffusion_models  https://huggingface.co/Comfy-Org/Wan-2.2/resolve/main/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors      456f901338bd9eadbded3828b819109a9b68e8a525ca5cf8d0049a69fcfeca1e
wan5b    text_encoders     https://huggingface.co/Comfy-Org/Wan-2.1/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors   c3355d30191f1f066b26d93fba017ae9809dce6c627dda5f6a66eaa651204f68
```

Sizes read with the hashes (`x-linked-size`, bytes): sd15 2 132 696 762 (≈ 2.1 GB); zimage 335 304 388 + 8 044 982 048 +
12 309 866 400 (≈ 20.7 GB); wan5b 1 409 400 960 + 9 999 658 848 + 6 735 906 897 (≈ 18.1 GB). The names the sets were asked
under (`stable-diffusion-v1-5-archive`, `z_image_turbo`, `Wan_2.2_ComfyUI_Repackaged`, `Wan_2.1_ComfyUI_repackaged`) redirect
to these; the header says so in one line.

**5. `lib/comfy.sh`** (S2's file; add, do not restructure):

- `comfy_assets`: `comfyui/Containerfile comfyui/Containerfile required`, `comfyui/entrypoint.sh comfyui/entrypoint.sh
  required`, `comfyui/fetch_model.sh comfyui/fetch_model.sh required` — `moe_place` makes `$(moe_placed_dir)/comfyui/` itself
  (`mkdir -p "${dest%/*}"`, `lib/moe_verb.sh:43`). Call it as `_MOE_PLACED_BY=comfy moe_place comfy_assets` in a `local`
  (the shape of `lib/kernels_verb.sh:166–169`).
- `comfy_win_dir`: `printf '%s\\r9700\\comfyui\n' "${R9700_WORK_DIR_WIN%\\}"` (BU2).
- `comfy_models_conf`: `${R9700_COMFY_MODELS_CONF:-<repo>/comfyui/models.conf}` (a test knob, the shape of
  `series_arms_conf`). `comfy_models_load <file>`: every problem of MC2 with `<file>:<line>`, all in one pass, 2; on 0 the
  arrays of the lines in file order. `comfy_sets`: the names, file order, once each.
- Two constants: `_COMFY_STAMP_RE='^[0-9]{8}T[0-9]{6}Z$'` (a build stamp, `YYYYMMDDTHHMMSSZ`, UTC: its text order is its time
  order, so the retention sorts the TAG, never the engine's `CREATED`, which is relative words) and `_COMFY_IMAGES_KEEP=4` (the
  current image plus three to roll back to: development-workflow's rollback depth, and the retention IS that trail).
- `comfy_build_stamp`: `${R9700_TEST_COMFY_STAMP:-$(date -u +%Y%m%dT%H%M%SZ)}` (the knob is environment only, a *Test knobs*
  row); a value that is not `_COMFY_STAMP_RE` → one line naming `R9700_TEST_COMFY_STAMP`, 2.
- `comfy_mode_build [--no-cache]`: the grammar first (any other word: 2, `r9700: comfy: build: unknown argument "<x>"; legal:
  --no-cache`, no lock — BU8), then `comfy_locked build card-free comfy_build_body`. The entry is S2's and does, in this
  order, the lock (4), `restore_first`, `config_load_machine` (2) and the two-owner admission `comfy_owners_check` (2: the
  owner line or the server line) — all BEFORE the body, so a refused build has placed nothing and built nothing (BU9, BU10).
  The build writes no admission of its own.
- `comfy_build_body`, in this order (every failure path ends with the entry's `lock_release`, which `comfy_locked` does):
  1. `repo="${R9700_COMFY_IMAGE%:*}"`, `tag="${R9700_COMFY_IMAGE##*:}"` (S1's `image` type admits no `:` in the repository
     part, `lib/config.sh:82`, so the last `:` is the tag's). `tag` matching `_COMFY_STAMP_RE` → the BU15 line, 2.
  2. `stamp="$(comfy_build_stamp)" || return 2`; `stamped="$repo:$stamp"`.
  3. The placement (2 on failure, before any engine call — BU6).
  4. The view before the build: `_rg_listing_tries wslc_image_list` then `images="$_RG_LISTING"` (S2's three tries, widened with the lister as
     an optional argument, default `wslc_list` — one loop, not a second); a failure → `the image list failed 3 times
     ($_RG_LIST_ERR); nothing was built`, 1. `$stamped` already a row (`$1 == repo && $2 == stamp`) → the BU15 line, 1.
     `cur_id` = the id of the row `repo tag` (empty when `COMFY_IMAGE` does not exist yet).
  5. `wslc_build "$R9700_COMFY_BUILD_MAX_S" -t "$stamped" -f "$(comfy_win_dir)\Containerfile" --build-arg BASE=…
     --build-arg COMFYUI_REF=… [--no-cache] "$(comfy_win_dir)"` — the stamped tag, NEVER `COMFY_IMAGE` (a fixed tag moved by
     every build is what left three untagged 27.3 GB images on the operator's PC, observed 2026-11-07); rc ≠ 0 →
     `comfy_build_reject "the build failed (<timeout after <n> s> for 124/137, else code <rc>)"`, 1.
  6. The check of the STAMPED tag: `wslc_run_once 600 --name "$(container_name comfy-check)" --gpus all --entrypoint python3
     "$stamped" -c "$_COMFY_CHECK_PY"`. The program (a constant, stdlib + torch) prints exactly four lines: `torch
     <torch.__version__>`, `hip <torch.version.hip>`, `device <torch.cuda.get_device_name(0) or none>`, `matmul ok|nan` (a
     1024×1024 fp16 `x @ x` on the device, its float sum finite), and exits 1 when `hip` is `None`, no device is available or
     the sum is not finite. Accepted only on rc 0 AND `hip` not `None` AND a device line not `none` AND `matmul ok` (BU4: the
     artefact, not the exit code); else `comfy_build_reject "the built image $stamped is not usable on the card: <the check's
     line>; $R9700_COMFY_IMAGE was not moved"`, 1.
  7. The promotion, only now: `wslc_tag "$stamped" "$R9700_COMFY_IMAGE"`; rc ≠ 0 → the BU16 line, 1 (the passed tag is kept:
     it is a good image, one hand command from being current; no removal runs).
  8. stdout `comfy: build: device <name>` and `comfy: build: $R9700_COMFY_IMAGE now names $stamped`.
  9. `comfy_images_prune "$repo" "$stamped"`; return 0 whatever it reports (the new image passed and is current; a removal
     that did not happen is a warning line, and the next build's retention catches up).
- `comfy_build_reject <line>`: the rejected stamped tag goes, by its exact name, and nothing else: `_rg_listing_tries
  wslc_image_list`; the list failed → the line gains `; whether $stamped was tagged is not known (the image list failed):
  remove it by hand if the list shows it`; `$stamped` not a row → nothing to remove (a failed build normally tags nothing);
  a row whose id is `cur_id` → kept, the line gains `; $stamped is the image $R9700_COMFY_IMAGE already names; kept` (BU13);
  else `wslc_rmi "$stamped"` (a failure: the line gains `; $stamped could not be removed (code <rc>): remove it by hand`).
  Then the one stderr line `r9700: comfy: build: <line>`.
- `comfy_images_prune <repository> <new stamped>`: never before the promotion, never on a view it cannot trust (development-
  workflow: retention must never empty the shelf). `_rg_listing_tries wslc_image_list`; failed → the BU14 warning, 0; the
  new stamped not a row → the BU14 warning, 0. `cur_id` = the id of the `COMFY_IMAGE` row. The stamped tags = the rows with
  `$1 == repository` and `$2` matching `_COMFY_STAMP_RE` (nothing else is ever a candidate: another repository, an untagged
  `<none>` row and a tag of another shape are not ours), sorted by the tag, newest first (`LC_ALL=C sort -r`); the first
  `_COMFY_IMAGES_KEEP` are kept; for each older one: its id is `cur_id` → stdout `kept <tag>: it is the image <COMFY_IMAGE>
  names` (a cached rebuild has the id of an older build; whether the engine's `rmi` of a shared id only untags is not observed,
  so it is never asked); else `wslc_rmi "<repository>:<tag>"` — one exact tag per call, never an id, a pattern or `-f` — rc 0 →
  stdout `removed <repository>:<tag>`; else the warning `r9700: comfy: build: warning: <repository>:<tag> could not be removed
  (code <rc>): <last line>`. Return 0.
- `comfy_mode_fetch <set>...`, in decision 4's order without the restore (parse → lock → config → work): no set → 2, `r9700:
  comfy: fetch: usage: bin/r9700 comfy fetch <set>...; legal sets: <comfy_sets, space-separated>`; `comfy_models_load
  "$(comfy_models_conf)"` (MC2, 2); every set in `comfy_sets` (FE4, 2) — all before the lock, so a refused argument never
  waits on a running fetch (FE8). Then `lock_take comfy-fetch comfy-fetch.lock || return $?` (5b: 4 with the holder line when
  another fetch holds it). Then, each failure releasing the fetch lock first: `config_load_machine` (2);
  `_rg_listing_tries` then `listing="$_RG_LISTING"` (2, `r9700: comfy: fetch: the container list failed 3 times ($_RG_LIST_ERR)`);
  `$(comfy_fetch_name)` a whole line of the listing → 4, `r9700: comfy: fetch: a fetch container is still running: <name>;
  wait for it or stop it` (FE9: a fetch whose host process was killed leaves its container running, the lock released with the
  process; starting a second container would resume the same `.part` beside the first — the engine's refusal of a second run
  of the name is the backstop, never the check); the placement (2); `wslc_volume_list` and `comfy_volume_ensure
  "$R9700_COMFY_MODELS_VOLUME"` (FE7, 1); `wslc_run_once "$R9700_COMFY_FETCH_MAX_S" --name "$(comfy_fetch_name)" -v
  "$R9700_COMFY_MODELS_VOLUME:/models" [-v "$R9700_COMFY_STORE_WIN:/store"] -v "$R9700_WORK_DIR_WIN:/work:ro" --entrypoint bash
  "$R9700_COMFY_IMAGE" /work/r9700/comfyui/fetch_model.sh <triples>`; the output printed; `lock_release`; rc 0 → 0, 3 → 2,
  anything else → 1 (FE5). `fetch` never calls `restore_first`: it holds no GPU lock, and the next GPU verb restores. The fetch
  name is `comfy_fetch_name` (S2's, the one its name rules check); do not build it anywhere else.
- Messages start `r9700: comfy: build:` / `r9700: comfy: fetch:`; no line of the file names `wslc` as a word (the seam: the
  BU16 line says `tag it by hand (README, ComfyUI)`, the README holds the command).

**5a. `lib/adapter.sh`** — three calls after S2's `wslc_inspect`, each starting with `_adapter_drop_lock`, the shapes of the
neighbours; three rows in the header table (`:7–20`). The argv shapes were read from the engine's own help on the operator's
PC on 2026-11-07 (`wslc tag [options] <source> <target>`, alias `wslc image tag`; `wslc rmi [options] <image>...`, aliases
`wslc image remove|delete|rm`, with `-f` and `--no-prune`, neither used here; `wslc image list` with `--no-trunc`, alias
`wslc images`), and the `image list` output was observed the same day, `--no-trunc` (the whole header and the first three rows;
the fixture of AI3 is these lines):

```text
REPOSITORY      TAG                                                        IMAGE ID                                                                  CREATED       SIZE
comfyui-r9700   local                                                      sha256:5662f4cbd4173b5a2b276b1c58a47a1309f4e632e3dab2e5a84bdd0d02c0d1e1   6 hours ago   27.3GB
<none>          <none>                                                     sha256:7ce514fe9121a6d276d5cab9abd4b19b7130c67ebde69c39ed92694156afe72d   6 hours ago   27.3GB
<none>          <none>                                                     sha256:b6251d5327b051b0a71560fb87cc960f249861611c6a0cd1a665d95b2da4bebc   6 hours ago   27.3GB
```

(without `--no-trunc` the id is its first 12 hex characters, `5662f4cbd417`). The two untagged rows, and a third not shown,
are what three builds with the fixed tag `comfyui-r9700:local` left: 27.3 GB each as listed, the ROCm base layers shared, about
2 GB each of their own (the parent's *Records and growth*). The output of `tag` and `rmi` on success and on failure was NOT
observed; the acceptance run 1 records it.

- `wslc_tag <source> <target>` (60 s): both words through S2's reference check (`_ADAPTER_REF_RE`; the refusal `wslc_tag:
  "<x>" is not a reference (…)`, 2, no call); exactly two words (else 2); `_adapter_call --merge 60 "$R9700_WSLC" tag "$1"
  "$2" | tr -d '\r' 9>&-`, `return "${PIPESTATUS[0]}"`.
- `wslc_rmi <exact tag>` (60 s): exactly one word, matching `_ADAPTER_TAGGED_RE='^[A-Za-z0-9][A-Za-z0-9._/-]*:[A-Za-z0-9._-]+$'`
  and not starting `sha256:` (an id form) — so no bare repository (the engine would read `:latest`), no id, no pattern, no
  option; else `wslc_rmi: "<x>" is not an exact image tag (<repository>:<tag>; never an id, a pattern or an option)`, 2, no
  call; `_adapter_call --merge 60 "$R9700_WSLC" rmi "$1" | tr -d '\r' 9>&-`, `return "${PIPESTATUS[0]}"`.
- `wslc_image_list` (60 s): `_adapter_call --quiet 60 "$R9700_WSLC" image list --no-trunc | tr -d '\r' 9>&- | awk 'NR > 1 &&
  NF { print $1, $2, $3 }' 9>&-`, `return "${PIPESTATUS[0]}"`: the first three columns (no space inside any of them), the
  header dropped, `CREATED` (several words) and `SIZE` never read. A comment cites the observation above.

**5b. `lib/run_guarded.sh`** — `lock_take <verb> [<lock file name>]`: the second argument (default `lock`) is a file name of
the state directory, `^[A-Za-z0-9][A-Za-z0-9_-]*(\.[A-Za-z0-9_-]+)*$` (no `/`, no leading `.` or `-`; else `lock_take: "<x>" is
not a lock file name`, 2); everything else is as it is — descriptor 9, the holder line, the refusal text with the file's path,
`_RG_LOCK_OWNER`. The fetch lock uses descriptor 9 ON PURPOSE: the adapter already closes 9 in every child and every fork
(`_adapter_drop_lock`, `9>&-` in `_adapter_call`, amendment A1), so a SIGKILL of the fetch verb releases its lock at once and
no long-running fetch client holds it (FE9). A process holds at most one of the two locks — `fetch` never takes the GPU lock
and no verb under the GPU lock calls `fetch` — and the header comment of the file says so in one line. `lock_release` is
unchanged. `_rg_listing_tries [<lister>]` (S2's): the optional lister function, default `wslc_list`; it is called directly, never in `$(…)`, and hands its result back in `_RG_LISTING` (on success) or `_RG_LIST_ERR` (on failure) — a command substitution would lose `_RG_LIST_ERR` in its subshell (the S2 review, 2026-11-07).

**6. `bin/r9700`.** The rows `build [--no-cache]` and `fetch <set>...` in S2's dispatch, with their grammar checked before any
lock (BU8, FE4). The exit comment (`:10–27`): row 1 gains `comfy build: the build or the check of the built image failed
(COMFY_IMAGE is not moved and the rejected stamped tag is removed), the image list could not be read before the build, the
stamped tag exists already, or the promotion's tag failed; comfy fetch: a file did not arrive with its pinned sha256`; row 2
gains `comfy build: the operator's ComfyUI or the operator's server is listed (nothing was placed or built), or COMFY_IMAGE's
tag has the shape of a build stamp; comfy fetch: an unknown set, a malformed comfyui/models.conf, a source that publishes
another sha256 than the pinned one, or a container list that failed three times` (the `card-free` words S2 left to this
story); row 4 gains `comfy fetch: another fetch holds <state dir>/comfy-fetch.lock, or a fetch container is still running`. The
three places of the exit table agree (`tests/test_lifecycle.sh:432`; brief 9).

**7. The stub** (`tests/stubs/wslc`; every new file in the header of `stub_common.sh`).

- The images: one file `$R9700_STUB_DIR/images`, a line `<repository> <tag> <id>` per tagged image (the id `sha256:` and 64
  hex). S1's `build_image`: on rc 0 (or `answers/build_tags_on_failure` 1) and a `-t <ref>` word pair, the record of `<ref>` is
  set to `answers/build_id` when present, else `sha256:` + the stub's call counter zero-padded to 64 digits (SI1). `tag)`:
  SI2. `image)` with `list [--no-trunc]`: SI3 (`fail-image-list`, `answers/image_list`), any other `image` word → 2 with one
  `stub: wslc: unknown image subcommand` line. `rmi)`: SI4 (`answers/rmi_rc`). A test plants records by writing the file.
- In `run_container` (`:145`), for a foreground run, BEFORE the generic `answers/find` branch (`:156`): an argv with
  `--entrypoint python3` whose `-c` program contains `torch.version.hip` → print `answers/comfy_check` (default the four R9700
  lines) with CRLF, exit `$(moe_answer comfy_check_rc 0)`; an argv with a word ending in `/fetch_model.sh` → the fetch
  container, recorded the way `moe_foreground` records a foreground container (`containers/<name>.pid` = the stub's own pid,
  removed on EXIT; a live record of the name → `stub: container name in use: <name>`, exit 1), then a sleeper of
  `$(moe_answer comfy_fetch_seconds 0)` seconds in the background and `wait` (a ceiling or a TERM ends it), then
  `answers/comfy_fetch.log` (default one `stub fetch` line) with CRLF, exit `$(moe_answer comfy_fetch_rc 0)` (SI5). Reuse
  `stub_record_pid` and the EXIT-trap shape of `moe_foreground`; do not copy its MoE branches.
- Header lines: `images`, `answers/build_id`, `answers/build_tags_on_failure`, `answers/tag_rc`, `answers/image_list`,
  `fail-image-list`, `answers/rmi_rc`, `answers/comfy_check`, `answers/comfy_check_rc`, `answers/comfy_fetch.log`,
  `answers/comfy_fetch_rc`, `answers/comfy_fetch_seconds`.

**8. `tests/fixtures/comfy/file_server.py`.** Stdlib only (`http.server`, `ThreadingHTTPServer`); argv: the folder, the log
file, the port file; binds `127.0.0.1` port 0 and writes the port to the port file; `HEAD` and `GET`; `<name>.etag` → the
`X-Linked-Etag` header; `/r/<name>` → `302` to `/<name>` with the same header; `Range: bytes=<n>-` → `206` with
`Content-Range`; a request for a missing file → 404; one log line per request. The test starts it in the background,
records its pid like a stub container so the runner kills it if the test dies, waits for the port file (bounded), and stops
it at the end of the test. No temp files (`tempfile` is the raw-temp class).

**9. Documents.**

- `research/module_comfyui.md` (new): purpose (one owner of the card; vLLM and ComfyUI one at a time); the image (the base,
  why it and not AMD's `rocm/comfyui`, from the parent's *What exists today*); the three traps, each with its observation and
  where the repository keeps the fix (trap 1: the Containerfile comment; trap 2: `entrypoint.sh`; trap 3: the venv on
  `/data`); the flows of `build`, `fetch`, `start`, `stop`, `status` (S2's three from S2's merged code); a Mermaid diagram of
  the five modes against the lock, the fetch lock, the operator's vLLM and the volumes; the stamped tags, the promotion after
  the check and the retention of four (with the observation of 2026-11-07 that a fixed tag left three untagged images); the
  rollback by hand in one line, `wslc tag <repository>:<older stamp> <COMFY_IMAGE>`, then `bin/r9700 comfy start` (no
  `--rollback` mode exists); `models.conf` and the pinned-hash rule; *Growth* (the rows of this document's growth table that
  are S3's and S2's); *Acceptance on the R9700 (E1)* (below). Not a word about `bench`.
- `research/README.md`: its row. `research/architecture.md`: the `comfyui/` files and `lib/comfy.sh`'s new functions in S2's
  module row, and `wslc_tag`, `wslc_rmi`, `wslc_image_list` and `lock_take`'s lock file argument in it; `build` (the GPU lock,
  the card-free admission, the stamped tag, the promotion) and `fetch` (its own lock, `<state dir>/comfy-fetch.lock`) in S2's
  verb row; exit rows 1, 2 and 4 extended in brief 6's words. `research/module_tests.md`: the row of `tests/test_comfy.sh` with
  this story's scenario ids and the rows of `tests/test_adapter.sh` (AI1–AI5), `tests/test_stubs.sh` (SI1–SI5) and
  `tests/test_restore.sh` (FL1); the flow catalogue rows `bin/r9700 comfy build` and `bin/r9700 comfy fetch` (covered:
  `tests/test_comfy.sh` …) and three `not covered` rows — the real build, the real start, the real fetch — each with its reason
  (the card, the network and hours of download) and the acceptance section that records it; the knobs
  `R9700_COMFY_MODELS_CONF`, `R9700_TEST_COMFY_ROOT`, `R9700_TEST_ENTRY_DRY`, `R9700_TEST_FETCH_STORE`,
  `R9700_TEST_FETCH_MODELS`, `R9700_TEST_COMFY_STAMP` and the stub files of brief 7; in *What it does not prove*: the outputs
  of `tag` and `rmi` are the stub's, not observed (the acceptance run 1 records them), and whether the engine's `rmi` of a tag
  that shares its id with another only untags is not known (the retention never asks it). `README.md`: a ComfyUI section (the
  five modes, the fields, the sets, the pinned hashes, one owner of the card, the stamped tags and the one-line rollback by
  hand); the exit list's `1`, `2` and `4` items in brief 6's words. None of the four documents of `check_static.sh
  --unfinished` may hold `planned`.

**Commands.**

```bash
node tests/run.mjs tests/test_comfy.sh tests/test_adapter.sh tests/test_stubs.sh tests/test_restore.sh
node tests/run.mjs
bash tests/check_static.sh
node .agents/conventions/tools/leftovers-check.mjs --repo . --token r9700 --identity "the R9700 vLLM tuning toolkit" --profile node
node .agents/conventions/tools/plan-lifecycle.mjs
```

Report the runner's lines, the static check's exit code and each RED observation.

### Acceptance on the R9700 (the operator's session, after S2 and S3 are merged)

Recorded in `research/module_comfyui.md` § *Acceptance on the R9700 (E1)*, the prediction written there BEFORE the first
command; each command with its output in a fenced block, the commit it ran at, the date, and what the record does not
settle. Not an `ACCEPTANCE_*.md` file: the parent gives its one acceptance record to E3, and a second file would also pull
`POST_DEPLOY.md`, whose change the parent restricts, through `tests/test_docs.sh:110`.

1. `bin/r9700 comfy build` — prediction: the check prints `device AMD Radeon AI PRO R9700` and `matmul ok`; the build takes
   under `COMFY_BUILD_MAX_S`; `COMFY_IMAGE` then names the stamped tag, and the image it named before (the hand-made build)
   is left untagged, the one untagged image this story adds, removed by the operator by its id. Recorded: the wall time, the
   check's four lines, the raw `wslc image list` before and after (it checks AI3's parse and the size the growth row
   carries), and the raw output of the promotion's `tag`. A real `rmi` runs first at the fifth passed build; its output is
   added to the same section then (until then the stub's text stands, as *What it does not prove* says).
2. `bin/r9700 comfy fetch zimage wan5b` with `COMFY_STORE_WIN` set — prediction: every file ends `fetch: done … sha256 <the
   pin>`, the store first. Recorded: the lines, the wall time, the raw output of `wslc volume list` once (it checks S1's
   parse; a different shape is a fix and a deviation).
3. `bin/r9700 comfy start --stop-vllm`, then by hand in the Windows browser on `127.0.0.1:<COMFY_PORT>` ComfyUI's own
   Z-Image Turbo workflow at 1024×1024 — prediction: the start prints the R9700 device line, the log shows `Using pytorch
   attention`, the image is correct. While it runs, the cornerstone on the real machine: `bin/r9700 step --model <a model
   file> probe -- true` exits 2 naming `bin/r9700 comfy stop`, and `bin/r9700 comfy status` afterwards still lists
   `COMFY_CONTAINER` (nothing was stopped). Then `bin/r9700 comfy stop`. Recorded: the lines, the image's time, the log line,
   and that the operator looked at the image.

The hand-made folder is not used for any of the three; the operator decides whether to delete it (the parent's DoD).

### Done when

- IM1–IM5, FM1–FM12, MC1–MC3, BU1–BU16, FE1–FE9, AI1–AI5, SI1–SI5 and FL1 pass through `node tests/run.mjs`; each refusal
  marked RED first was seen failing first; every other test unchanged and green.
- `comfy build` is refused (exit 2) while the operator's ComfyUI or vLLM is listed, before anything is placed or built, and a
  standing marker restores vLLM first and is then refused (BU9, BU10); it builds to a stamped tag, checks that tag, and only a
  passed check moves `COMFY_IMAGE`; a rejected build leaves `COMFY_IMAGE` and every earlier stamped tag as they were and
  removes its own stamped tag by exact name (BU4, BU5, BU11); after a passed build the newest four stamped tags stay and older
  ones are removed by exact tag, never the image `COMFY_IMAGE` names, never on a view the list could not give (BU12–BU14).
- `comfy fetch` holds `<state dir>/comfy-fetch.lock` and never the GPU lock: a second fetch is exit 4 naming the holder, and a
  fetch container still listed after its fetch was killed is exit 4 naming it — the next fetch never writes the same `.part`
  (FE6, FE8, FE9); a file is kept only when its own sha256 equals the pin, a source that publishes another refuses before
  any download (FM2–FM4, FE5).
- `comfyui/` holds no machine value: `bash tests/check_static.sh` exits 0 (personal paths, syntax, seam, documents); CI green.
- `research/module_comfyui.md` exists and is linked; the architecture rows, the flow catalogue and the README section name
  `build` and `fetch`; nothing in them describes `bench`.
- The three acceptance runs are recorded as above.

---

## Growth surfaces of these stories

| Surface | Story | Size | Who retires it | Interrupted |
|---|---|---|---|---|
| The volume `COMFY_MODELS_VOLUME` | S3 (`fetch`) | 2.1 GB (`sd15`), 20.7 GB (`zimage`), 18.1 GB (`wan5b`): ≈ 41 GB with the three sets | the operator, by hand (`wslc volume remove`); the toolkit never removes a volume (a download costs hours) | a killed fetch leaves `<name>.part`; the next fetch of the set resumes it, and a wrong one is removed when it fails its pin; a fetch whose host process was killed while its container lives on is not resumed beside it: the next fetch refuses while `<COMFY_CONTAINER>-fetch` is listed (FE9) |
| The store `COMFY_STORE_WIN` | S3 | the same ≈ 41 GB | the operator | as above |
| The volume `COMFY_DATA_VOLUME` | S2 (`start` makes it) | ≈ 0 until a custom node installs packages; one `venv.python-<version>.<stamp>` folder per change of the image's Python | the operator, by hand | — |
| The volume `COMFY_CACHE_VOLUME` | S2 | at most 2 GB projected (the parent), measured in E2 | the operator, by hand (ComfyUI rebuilds the caches) | — |
| The placed copies `$WORK_DIR/r9700/comfyui/` | S3 | three files, ≈ 9 KB | rewritten when the repository's file changes (`moe_place`) | a `.part` left by a kill is replaced by the next placement |
| The failed-start log tail in the state folder | S2 | ≈ 20 KB per failed start (200 lines) | the retention S2's spec names | — |
| The images of `COMFY_IMAGE`'s repository, one stamped tag `<repository>:<YYYYMMDDTHHMMSSZ>` per passed build | S3 (`build`) | 27.3 GB each as listed, but the ROCm base layers are shared, so a kept build costs its own layers, about 2 GB: four kept ≈ 8 GB beyond the base (the parent's measurement, 2026-11-07). The stamped tags replace what the fixed tag did: on the operator's PC on 2026-11-07 three builds with the fixed tag left three untagged images of 27.3 GB listed size (observed with `wslc image list`) | the build itself, after the new image passed its check and `COMFY_IMAGE` names it: the newest four stamped tags stay (the current one plus three to roll back to), older ones are removed by their exact tag — never by pattern or id, never the image `COMFY_IMAGE` names, never on a list that failed or does not show the new tag; a rejected build's stamped tag is removed at once. The three untagged leftovers of the hand-made builds, and the image the first stamped build untags, are the operator's to remove by id; the toolkit never prunes the engine's untagged images (other images' parents are among them) | a build killed, or cut by its ceiling, may leave its stamped tag (the engine can finish after the client is gone): never `COMFY_IMAGE`, counted by the next passed build's retention like any other; the engine's build cache is the engine's |
| The fetch lock `<state dir>/comfy-fetch.lock` | S3 (`fetch`) | one file, one holder line (≈ 50 B) | kept, like the GPU lock file; each taker rewrites its line | a SIGKILL releases the flock with the process (descriptor 9 is never inherited by a child); the stale holder line is rewritten by the next taker |
| Test files | S1, S3 | a few KB per run (the fetch tests' files, the fixture server's log) | the runner removes its run folder | the runner's sweep |

## Build order

1. E1.S1 — Sonnet codes the S1 section; Opus reviews; Sonnet fixes.
2. E1.S2 — Fable writes the spec (it may start while S1 is coded); the ledger line names it; Sonnet codes after S1 is
   merged; Opus reviews; Sonnet fixes.
3. E1.S3 — Sonnet codes the `comfyui/` files, `fetch_model.sh`, `models.conf` and their tests after S1 is merged, and the
   two verb modes after S2 is merged; Opus reviews; Sonnet fixes. Then the operator's session runs the three acceptance runs
   and records them.

## Definition of Done (E1, by story)

- [ ] S1: CF1–CF9, AD1–AD8, SB1–SB3 pass in CI; every field is in the table, `machine.env.example` and `module_config.md`;
      the RED observations are in the summary.
- [ ] S2: the refusals and the start path of its *Done when* pass in CI with the stub, each seen failing first (spec by Fable).
- [ ] S3: IM, FM, MC, BU, FE, AI, SI and FL pass in CI; `build` refuses beside either owner before it places or builds,
      promotes only a checked stamped tag and keeps four; `fetch` holds its own lock and refuses beside a live fetch
      container; `comfyui/` holds no machine value; `research/module_comfyui.md` exists; the three acceptance runs are
      recorded.
- [ ] Every story: the seam and personal-path checks pass; `research/architecture.md` and `research/module_tests.md` describe
      what exists; `node .agents/conventions/tools/plan-lifecycle.mjs` is clean.

## Follow-ups found while building E1 (not in E1's scope)

- **A signal before `supervise`'s traps** (the S2 review, 2026-11-07). Between `lock_take` and `_rg_traps_on`, `supervise` keeps
  the default signal handling: a TERM ends it at once while `restore_first` (up to `READY_TIMEOUT_S`) or the owner check's list
  calls are in flight; each call then ends at its own ceiling (`timeout --kill-after`), the lock goes with the process, and
  nothing has been stopped yet, so nothing is owed. Bounded, and older than E1 (E1 adds up to ~3×60 s + 20 s to the window).
  The fix — a handler set right after `lock_take` that kills `_RG_BG` and exits 128+n, with the pre-trap calls going through
  `_rg_run` — belongs to its own change; S2 states the window in `supervise`'s header.
