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
| `comfy build` (the lock, the placement, `wslc_build`, the check container) and `comfy fetch` (no lock, no GPU, the non-prefixed name) | S3 | the lock entry and the owner check it calls are S2's |
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
  exactly the seven words `build -t img:x -f X:\a b\Containerfile --build-arg BASE=b:1 X:\a b`; stdout has the 60 lines and no CR.
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
  the parse of `wslc_list` (`:305–309`): the last column after the header. A comment says the shape is UNVERIFIED for `wslc`
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
  of `fail-list`, `:193–203`, for this file); else the header `DRIVER    VOLUME NAME` and `local     <name>` per file of
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
back when this invocation stopped it. `comfy stop` and `comfy status` work without the lock. No verb ever stops the
operator's ComfyUI by itself, and the cleanup of a run never reaches it or a fetch in progress. And the one place that starts
the operator's vLLM — the restore from the recovery marker — never starts it beside the operator's ComfyUI either.

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
  `comfy_locked <mode> <body function> [args...]` the modes that take the lock share (lock, restore-first, the machine config,
  the body, the release; S3's `build` uses it).
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
- The stub answers these modes need (`tests/stubs/wslc`): the ComfyUI probe in `exec_in` (`:262`), `remove`, `inspect`, a
  stopped container that keeps its name.
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
`lib/run_guarded.sh` (`comfy_owner_check`, `_rg_listing_tries`, `_rg_card_free`, one line in `supervise`); `lib/step.sh` (one check in
`_step_admit`); `lib/restore.sh` (the marker key `COMFY_CONTAINER`, `_restore_comfy_free`, the three optional arguments of
`ready_wait`); `lib/adapter.sh` (`wslc_remove`, `wslc_inspect`, `comfy_probe`, `comfy_probe_program`, the header table);
`lib/config.sh` (`_cfg_cross`, `_COMFY_FETCH_SUFFIX`); `tests/stubs/wslc` and `tests/stubs/stub_common.sh`;
`tests/test_comfy.sh` (new: OC, NR7, RM2–RM4, CS, CT, CU); `tests/test_config.sh` (NR1–NR6); `tests/test_restore.sh` (RM1,
AW6); `tests/test_adapter.sh` (AW1–AW5); `tests/test_stubs.sh` (SW1–SW4); `tests/test_lifecycle.sh` (L20's legal-verb line);
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
  `stop comfyui` (nothing ran), the lock free. RED first: without the remove, the planted stopped container makes the run fail.
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
- `comfy_locked <mode> <body> [args...]`: `lock_take comfy || return $?`; `restore_first`; `config_load_machine
  "${R9700_MACHINE_ENV:-./machine.env}" || { lock_release; return 2; }`; `"$body" "$@"`; `rc=$?`; `lock_release`; `return $rc`.
  The modes without the lock (`stop`, `status`) load the machine config themselves and never call `restore_first`.
- `comfy_volume_ensure <name> <listing>`: creates the volume when it is not a whole line of `<listing>` (`wslc_volume_create`),
  prints `comfy: start: created volume <name>`; a failed create: `_COMFY_ERR="volume create <name> failed (code <rc>): <last line>"`
  and 1. S3's `fetch` calls it (one helper, not two).
- `comfy_tails_prune <keep>`: over `$(state_dir)/comfy-start-*.tail.log`, regular files only, names matching
  `^comfy-start-[0-9]{8}T[0-9]{6}Z-[0-9]+\.tail\.log$`, newest `<keep>` by mtime kept, the rest removed by exact name (the
  `restore_dirs_prune` shape).
- `comfy_start_args <args...>`: `--stop-vllm` sets `_COMFY_STOP_VLLM=yes`; `--` ends the options and the rest is `_COMFY_EXTRA`
  (an array); any other word is 2 with `r9700: comfy: start: unknown argument "<x>"; legal: --stop-vllm, -- <main.py args>`.
- `comfy_mode_start`: `comfy_start_args "$@" || return 2`, then `comfy_locked start comfy_start_body`.
- `comfy_start_body`, in this order, with `_COMFY_RAN=no _COMFY_STOPPED_PROD=no` reset first and the traps
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
  8. `wslc_run "$R9700_COMFY_CONTAINER" --gpus all -p "$R9700_COMFY_PORT:8188" -v "$R9700_COMFY_MODELS_VOLUME:/models"
     -v "$R9700_COMFY_DATA_VOLUME:/data" -v "$R9700_COMFY_CACHE_VOLUME:/cache" [-v "$R9700_COMFY_OUTPUT_WIN:/data/output" when
     set] --shm-size 8g "$R9700_COMFY_IMAGE" "${_COMFY_EXTRA[@]}"`; rc ≠ 0 → `comfy_start_fail 1 "the run of <name> failed (code
     <rc>): <last line>"`; else `_COMFY_RAN=yes`.
  9. `ready_wait "$R9700_COMFY_CONTAINER" "$R9700_READY_TIMEOUT_S" comfy_probe ready -`; 5 → `comfy_start_fail 5 "$READY_LINE"`
     (the failure path appends the tail file to the line); 0 → stdout `<name> ready after $READY_ELAPSED_S s`,
     `device <…>` (the `device ` line of `READY_ANSWER`), `open http://127.0.0.1:<port>`; with `_COMFY_STOPPED_PROD=yes`:
     `marker_remove "$(marker_path)"` and stdout `<prod> stays down; start it by hand when ComfyUI is done`. Return 0.
- `comfy_start_fail <code> <line>` — the ONE failure path; `trap '' INT TERM HUP` first (a signal must not cut it in half):
  (a) `_COMFY_RAN=yes`: `comfy_tails_prune 10`; `wslc_logs <name> | tail -n 200 > <file>` (an empty file when the logs call
  fails); stdout `saved the last 200 log lines of <name> to <file>`; `wslc_stop <name>`; list; still listed → the line becomes
  `<name> is still listed after the stop; stop it by hand`, code 5, and the restore is NOT run (the restore's guard would refuse
  it; the marker stays and says so); else stdout `stopped <name>`. (b) `_COMFY_STOPPED_PROD=yes`: `restore_from_marker
  "$(marker_path)" "<the RUN_DIR of step 4>"`; 5 → the code becomes 5 (the restore's own line is already printed; the marker
  stays). (c) `echo "r9700: comfy: start: <line>[; its last 200 log lines are in <file>]" >&2`; return `<code>`. The lock is
  released by `comfy_locked` after this returns — last.
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
when this invocation stopped it)`.

**8. The stub.** `tests/stubs/wslc`: a `remove)` branch (SW1: `stopped/<name>` → `rm`, print the name with CRLF; a running
record → 1 and its line; neither → 1 and its line; `answers/remove_rc` first); in `run_container`, for a detached run, before
`stub_alive`: `[ -f "$R9700_STUB_DIR/stopped/$name" ]` → `stub: container name in use (a stopped container): $name` on stderr,
exit 1; an `inspect)` branch (SW3, `moe_answer inspect_rc 0`); in `exec_in`, BEFORE the `*urlopen*` branch: `[[ ${3:-} == *system_stats* ]]`
→ `word="$(stub_answer comfy_ready)"`; `hang` → `stub_hang`; `ok` → the two lines with CRLF, 0; else `system_stats: URLError`
with CRLF, 1. `tests/stubs/stub_common.sh`'s header gains `stopped/<name>`, `answers/comfy_ready`, `answers/inspect`,
`answers/inspect_rc`, `answers/remove_rc`.

**9. Tests.** `tests/test_comfy.sh` (new; sources `assert.sh`, `stubcase.sh`, `lifecycle.sh`, `kernelcase.sh`, and
`lib/comfy.sh` for `comfy_modes` / `comfy_fetch_name`): `comfy_setup`, `comfy`, `comfy_bg`, `comfy_end`, `comfy_run_argv` as
*Test scenarios* defines them; every wait is a bounded `wait_for` on a call-log line or a file, never a fixed sleep; every
started process is recorded for the killer (`guard_pid`) and `kill_recorded_pids "$CASE"` ends the tests that leave containers.
The other files as the scenario headings say. A test that plants a tail file or a stopped container writes only below
`$R9700_TEST_ROOT`.

**10. Documents.** `research/architecture.md`: the sentence of `:5` becomes ten verbs in five groups, the fifth `ComfyUI on the
same card, one owner at a time (comfy)`; a module row `ComfyUI (E1.S2)` naming `lib/comfy.sh`, `bin/r9700` (`comfy`),
`lib/run_guarded.sh` (`comfy_owner_check`, `_rg_card_free`, `_rg_listing_tries`), `lib/step.sh` (the admission's check),
`lib/restore.sh` (`_restore_comfy_free`, the marker key, `ready_wait`'s probe argument), `lib/adapter.sh` (`wslc_remove`,
`wslc_inspect`, `comfy_probe`) with the three modes and the two halves of the rule; a verb row `bin/r9700 comfy` (`start`: the
lock, held through the readiness wait; `stop`, `status`: none); the *Recovery marker* paragraph (`:57`) names `COMFY_CONTAINER`
and the *Restore* paragraph (`:59`) the refusal to start beside it; the exit rows 1, 2, 4, 5 as step 7 words them (the three
places must agree, `tests/test_lifecycle.sh:432`). `README.md`: the line `| \`bin/r9700 comfy <mode>\` | the operator's ComfyUI on
the same card, one owner at a time: \`start\`, \`stop\`, \`status\` |` after the `run` line; the exit list's `1`, `2`, `4`, `5`
items extended in the same words. `research/module_config.md`: the `COMFY_CONTAINER` row's second cell gains `must not start
with CONTAINER_PREFIX and must differ from PROD_CONTAINER, and so must <name>-fetch`, and the sentence of `:25` names both.
`research/module_tests.md`: the `tests/test_comfy.sh` row (`:7–60`); the flow catalogue row `| \`bin/r9700 comfy\` — \`start\`,
\`stop\`, \`status\`; the owner check of every verb under the supervisor; the restore's refusal beside ComfyUI | covered |
\`tests/test_comfy.sh\` (OC1–OC5, NR7, RM2–RM4, CS1–CS14, CT1–CT5, CU1–CU3), \`tests/test_config.sh\` (NR1–NR6),
\`tests/test_restore.sh\` (RM1, AW6) |`; the *Test knobs* rows for the five stub files of step 8; in *What it does not prove*:
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
marked RED first (the failing line, then the pass); for OC3 both symptoms.

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
code. `bin/r9700 comfy fetch <set>...` puts a named model set where ComfyUI reads it, every file accepted only when its
sha256 equals the one pinned in the repository. The hand-made folder is no longer needed to run ComfyUI on this PC.

### Files

| File | Change |
|---|---|
| `comfyui/Containerfile` | new: the hand-made `Containerfile` lines 11–57 with the machine values out (brief 1) |
| `comfyui/entrypoint.sh` | new: the hand-made `entrypoint.sh` with two test knobs (brief 2) |
| `comfyui/fetch_model.sh` | new: the hand-made `tests/fetch_model.sh` rewritten around the pinned hash (brief 3) |
| `comfyui/models.conf` | new: the three sets with pinned sha256 (brief 4) |
| `lib/comfy.sh` | `comfy_assets`, `comfy_win_dir`, `comfy_models_conf`, `comfy_models_load`, `comfy_sets`, the `build` and `fetch` bodies, the check program (brief 5) |
| `bin/r9700` | the rows `build` and `fetch` in S2's mode dispatch; the exit comment rows 1 and 2 (brief 6) |
| `tests/stubs/wslc`, `tests/stubs/stub_common.sh` | the check container's and the fetch container's foreground answers (brief 7) |
| `tests/test_comfy.sh` | scenarios IM1–IM5, FM1–FM12, MC1–MC3, BU1–BU8, FE1–FE7 (appended to S2's file) |
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
  the source publishes none and the pin decides.
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
`torch 2.13.0+rocm10.1.0`, `hip 10.1.0`, `device AMD Radeon AI PRO R9700`, `matmul ok`)

- BU1 *The build places its files, hash-checked, before it builds.* With no placed copy: after `bin/r9700 comfy build` (exit
  0), `$WORK_DIR/r9700/comfyui/{Containerfile,entrypoint.sh,fetch_model.sh}` equal the repository's files by sha256. With a
  stale placed copy (other bytes): it is rewritten before the `build` call (the call log's order).
- BU2 *The build argv is the config's, one word each.* `argv_of wslc` for the `build` call is exactly `build -t
  <COMFY_IMAGE> -f <WIN>\r9700\comfyui\Containerfile --build-arg BASE=<COMFY_BASE_IMAGE> --build-arg COMFYUI_REF=<COMFY_REF>
  <WIN>\r9700\comfyui`, the values read from the loaded config; `--no-cache` appears only with `comfy build --no-cache`.
  A `WORK_DIR_WIN` that ends in `\` (`X:\`) gives `X:\r9700\comfyui`, never a doubled backslash.
- BU3 *The built image is checked by a throwaway container on the card.* After the build, one foreground `run --rm --name
  <CONTAINER_PREFIX>comfy-check --gpus all --entrypoint python3 <COMFY_IMAGE> -c <program>` (its words read with `argv_of`);
  stdout holds `comfy: build: device AMD Radeon AI PRO R9700`; exit 0.
- BU4 *A built image without a ROCm device is refused.* `answers/comfy_check` with `hip None`, then with
  `device none`, then with `matmul nan`: each exit 1 and one line `r9700: comfy: build: the built image <COMFY_IMAGE> is not
  usable on the card: <the check's line>`. `answers/comfy_check_rc` 1: exit 1 too. RED first.
- BU5 *A failed build starts no check container.* `answers/build_rc` 1: exit 1, one line naming the build's code, no `run`
  call in the log. A build cut by its ceiling (`answers/build_seconds` 100, `COMFY_BUILD_MAX_S=600` with
  `R9700_CEILING_SCALE=100`: a 6 s ceiling; not `mode`, which would hang the verb's other calls too): exit 1, the line says
  the ceiling ended it, and no check container is started.
- BU6 *A placement that cannot be written is refused before any call.* `$WORK_DIR/r9700` is a file: exit 2 with the
  placement's line, no `wslc` call at all.
- BU7 *`build` takes the lock.* Another holder of the lock (the shape of the lifecycle tests' held lock): exit 4, no `wslc`
  call; after a successful build the lock is free (a second `build` takes it).
- BU8 *The grammar is checked before the lock.* `comfy build --frob` and `comfy build extra`: exit 2, one line with the legal
  options, no lock file, no call. No `--model` is needed with two model files in `models/` (the machine config alone).

**`comfy fetch`** (the stub answers the fetch container with `answers/comfy_fetch.log` and `answers/comfy_fetch_rc`)

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
- FE6 *`fetch` takes no lock.* While another holder has the lock, `comfy fetch zimage` runs (exit 0, the `run` call made).
- FE7 *The models volume is made when it is missing, and only then.* No stub volume: one `volume create <COMFY_MODELS_VOLUME>`
  before the `run`; the volume present: no create.

### Brief for the Sonnet coder

Read first: this section and *Facts every story uses*; the parent's *The `comfyui/` folder*, the verb-table rows `build` and
`fetch`, *Records and growth*; the hand-made files (the main session gives their location); `lib/moe_verb.sh:31–49`
(`moe_place`), `lib/moe.sh:35–61` and `:94–99` (`_MOE_REPO`, `moe_placed_dir`, `_moe_sha`, `moe_assets`), `lib/kernels.sh:40`
and `lib/kernels_verb.sh:166–169` (how another assets function reuses `moe_place`); S2's merged `lib/comfy.sh` and
`verb_comfy`; `tests/stubs/wslc:143–173`. Reuse, never copy: `moe_place <assets fn>` for the placement, `container_name`
(`lib/serve.sh:104`) for the check container's name, `wslc_build` / `wslc_run_once` / `wslc_volume_list` /
`wslc_volume_create` for every call, S2's lock entry and volume helper (if S2 wrote no volume helper, write
`comfy_volume_ensure <name>` here and make `start` call it — one helper, not two).

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
  `curl -sIL --connect-timeout 30 --max-time 120 "$url"` (the hand-made line 25 pattern; a failed `HEAD` gives none: `|| true`).
  Published and different from the pin → exit 3 with the FM3 line, before any GET. Published equal, or none → go on (FM2's
  line when none).
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
- The build body: the lock through S2's entry (it also does what S2's spec says about the recovery marker and a listed
  `COMFY_CONTAINER`); `config_load_machine`; the placement (2 on failure, before any call); `wslc_build "$R9700_COMFY_BUILD_MAX_S"
  -t … -f "$(comfy_win_dir)\Containerfile" --build-arg BASE=… --build-arg COMFYUI_REF=… [--no-cache] "$(comfy_win_dir)"`;
  rc ≠ 0 → exit 1 (`timeout after <n> s` for 124/137, else the code); then the check: `wslc_run_once 600 --name
  "$(container_name comfy-check)" --gpus all --entrypoint python3 "$R9700_COMFY_IMAGE" -c "$_COMFY_CHECK_PY"`. The program
  (a constant, stdlib + torch) prints exactly four lines: `torch <torch.__version__>`, `hip <torch.version.hip>`, `device
  <torch.cuda.get_device_name(0) or none>`, `matmul ok|nan` (a 1024×1024 fp16 `x @ x` on the device, its float sum finite),
  and exits 1 when `hip` is `None`, no device is available or the sum is not finite. The verb accepts only rc 0 AND `hip`
  not `None` AND a device line not `none` AND `matmul ok` (BU4: the artefact, not the exit code), then prints `comfy: build:
  device <name>` and releases the lock.
- The fetch body: no lock; `config_load_machine`; the sets checked against `comfy_sets` (FE4) after `comfy_models_load` (MC2);
  the placement; the models volume ensured (FE7); `wslc_run_once "$R9700_COMFY_FETCH_MAX_S" --name "$R9700_COMFY_CONTAINER-fetch"
  -v "$R9700_COMFY_MODELS_VOLUME:/models" [-v "$R9700_COMFY_STORE_WIN:/store"] -v "$R9700_WORK_DIR_WIN:/work:ro"
  --entrypoint bash "$R9700_COMFY_IMAGE" /work/r9700/comfyui/fetch_model.sh <triples>`; the output printed; rc 0 → 0, 3 → 2,
  anything else → 1 (FE5). The fetch name is the one S2's name rules check; do not build it anywhere else.
- Messages start `r9700: comfy: build:` / `r9700: comfy: fetch:`; no line of the file names `wslc` as a word (the seam).

**6. `bin/r9700`.** The rows `build [--no-cache]` and `fetch <set>...` in S2's dispatch, with their grammar checked before any
lock (BU8, FE4). The exit comment (`:10–27`): row 1 gains `comfy build: the build or the check of the built image failed;
comfy fetch: a file did not arrive with its pinned sha256`; row 2 gains `comfy fetch: an unknown set, a malformed
comfyui/models.conf, or a source that publishes another sha256 than the pinned one`.

**7. The stub.** In `run_container` (`tests/stubs/wslc:145`), for a foreground run, BEFORE the generic `answers/find` branch
(`:156`): an argv with `--entrypoint python3` whose `-c` program contains `torch.version.hip` → print `answers/comfy_check`
(default the four R9700 lines) with CRLF, exit `$(moe_answer comfy_check_rc 0)`; an argv with a word ending in
`/fetch_model.sh` → print `answers/comfy_fetch.log` (default one `stub fetch` line) with CRLF, exit
`$(moe_answer comfy_fetch_rc 0)`. Header lines in `stub_common.sh`.

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
  the five modes against the lock, the operator's vLLM and the volumes; `models.conf` and the pinned-hash rule; *Growth*
  (the rows of this document's growth table that are S3's and S2's); *Acceptance on the R9700 (E1)* (below). Not a word about
  `bench`.
- `research/README.md`: its row. `research/architecture.md`: the `comfyui/` files and `lib/comfy.sh`'s new functions in S2's
  module row; `build` and `fetch` in S2's verb row; exit row 1 and row 2 extended. `research/module_tests.md`: the row of
  `tests/test_comfy.sh` with this story's scenario ids; the flow catalogue rows `bin/r9700 comfy build` and `bin/r9700 comfy
  fetch` (covered: `tests/test_comfy.sh` …) and three `not covered` rows — the real build, the real start, the real fetch —
  each with its reason (the card, the network and hours of download) and the acceptance section that records it; the knobs
  `R9700_COMFY_MODELS_CONF`, `R9700_TEST_COMFY_ROOT`, `R9700_TEST_ENTRY_DRY`, `R9700_TEST_FETCH_STORE`,
  `R9700_TEST_FETCH_MODELS` and the stub files. `README.md`: a ComfyUI section (the five modes, the fields, the sets, the
  pinned hashes, one owner of the card). None of the four documents of `check_static.sh --unfinished` may hold `planned`.

**Commands.**

```bash
node tests/run.mjs tests/test_comfy.sh
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
   under `COMFY_BUILD_MAX_S`. Recorded: the wall time, the check's four lines, the image size the PC reports (the growth row's
   number).
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

- IM1–IM5, FM1–FM12, MC1–MC3, BU1–BU8 and FE1–FE7 pass through `node tests/run.mjs`; each refusal marked RED first was seen
  failing first; every other test unchanged and green.
- `comfyui/` holds no machine value: `bash tests/check_static.sh` exits 0 (personal paths, syntax, seam, documents); CI green.
- `research/module_comfyui.md` exists and is linked; the architecture rows, the flow catalogue and the README section name
  `build` and `fetch`; nothing in them describes `bench`.
- The three acceptance runs are recorded as above.

---

## Growth surfaces of these stories

| Surface | Story | Size | Who retires it | Interrupted |
|---|---|---|---|---|
| The volume `COMFY_MODELS_VOLUME` | S3 (`fetch`) | 2.1 GB (`sd15`), 20.7 GB (`zimage`), 18.1 GB (`wan5b`): ≈ 41 GB with the three sets | the operator, by hand (`wslc volume remove`); the toolkit never removes a volume (a download costs hours) | a killed fetch leaves `<name>.part`; the next fetch of the set resumes it, and a wrong one is removed when it fails its pin |
| The store `COMFY_STORE_WIN` | S3 | the same ≈ 41 GB | the operator | as above |
| The volume `COMFY_DATA_VOLUME` | S2 (`start` makes it) | ≈ 0 until a custom node installs packages; one `venv.python-<version>.<stamp>` folder per change of the image's Python | the operator, by hand | — |
| The volume `COMFY_CACHE_VOLUME` | S2 | at most 2 GB projected (the parent), measured in E2 | the operator, by hand (ComfyUI rebuilds the caches) | — |
| The placed copies `$WORK_DIR/r9700/comfyui/` | S3 | three files, ≈ 9 KB | rewritten when the repository's file changes (`moe_place`) | a `.part` left by a kill is replaced by the next placement |
| The failed-start log tail in the state folder | S2 | ≈ 20 KB per failed start (200 lines) | the retention S2's spec names | — |
| The image `COMFY_IMAGE` | S3 | measured at acceptance run 1 and written into the growth row; each rebuild leaves the previous image untagged | the operator, by hand; the toolkit removes no image | a killed build leaves the build cache of `wslc` |
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
- [ ] S3: IM, FM, MC, BU, FE pass in CI; `comfyui/` holds no machine value; `research/module_comfyui.md` exists; the three
      acceptance runs are recorded.
- [ ] Every story: the seam and personal-path checks pass; `research/architecture.md` and `research/module_tests.md` describe
      what exists; `node .agents/conventions/tools/plan-lifecycle.mjs` is clean.
