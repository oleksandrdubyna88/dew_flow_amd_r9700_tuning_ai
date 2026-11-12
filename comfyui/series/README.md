# comfyui/series — the pipelines that made the film series

These are the hand-run scripts of the operator's ComfyUI on the R9700 (Qwen-Image, FLUX.2 klein, SDXL, Wan 2.2 14B, FILM, VoxCPM and the trainers of the character LoRAs), kept as the record of how the pictures, clips, sound and LoRAs of `research/SCREENING_comfyui_2026-11-08.md` were made. They are not toolkit code: nothing in `bin/` or `lib/` calls them and no test runs them (`research/module_tests.md`). They changed with every night's work; a script is here as it was on 2026-11-13.

| Folder | What |
|---|---|
| `*.py`, `*.sh` | the drivers. Python ones run inside the ComfyUI container (`wslc exec comfyui python /opt/tests/<script>.py …`) or in a one-off container of the same image. The shell ones are trainers and set-ups that run in a one-off container (`lora_train*.sh`, `lora_setup.sh`, `instantid_setup.sh`, `fetch_model*.sh`) |
| `chains/` | the queue scripts of the nights (`run_*.sh`): a chain waits for the marker line of the one before it, restarts ComfyUI for each job, runs the driver, and writes its own log and a `… DONE` line. `guard_ram.sh` (the RAM guard of §33) and `gpumem.sh` are the helpers many chains call |
| `EP3_SCRIPT.md`, `SCRIPTS_ep1_ep2_ep3.md` | the story text of episodes 1 to 3 (the owner decided on 2026-11-10 that episodes 1 to 4 may be public here; episode 5 and later stay private) |

## Setting up

1. **The scripts folder is mounted at `/opt/tests`.** Every driver names its files as `/opt/tests/<script>`. Put the contents of this folder (or a link to it) in the `tests` folder of your ComfyUI folder, which is `COMFY_HOME_WIN` in `machine.env`, so that `<COMFY_HOME_WIN>\tests` is mounted read-only at `/opt/tests`. `output` (mounted at `/data/output`), `input` and `secrets` sit beside it.
2. **Machine values come from `machine.env`, never from a script.** The chains source `chains/_env.sh`, which loads `machine.env` with the toolkit's own parser (`lib/config.sh`, `config_load_machine`) and passes the keys a chain needs: `COMFY_HOME_WIN`, `COMFY_STORE_WIN` (the weights master), `NAS_BACKUP_WIN`, `NAS_IMAGES_WIN`, `WSLC_SETTINGS_WIN`. A chain whose key is empty stops at once and names it. The WSL forms of the paths are made with `wslpath -u`. `R9700_MACHINE_ENV` names another machine file; `R9700_ROOT` the repository root when the chains are run from a copy.
3. **Logs, pid files and stop files are written next to the chain** (`chains/*.log`, `.pid`, `.guard_off_*`); `chains/.gitignore` keeps them out of git.
4. **Run a chain with the GPU free.** A chain stops and restarts the operator's ComfyUI (`wslc stop comfyui`, `start-comfyui.ps1`) and some change the wslc VM memory (`WSLC_SETTINGS_WIN`). They do not use the toolkit's lock or guards: start one only on a PC nobody else is using, and read the lessons in the screening record first (§29 and §33: one big model per server session, a RAM guard; §44: waiting on a marker line, `pgrep -f` matching its own launcher).

## Which tool for new work

Two scripts here have a newer, tested twin in the toolkit and the twin is the one to use: `fetch_model.sh` (the first fetch, by sha256 published by the source) is replaced by `comfyui/fetch_model.sh` (`bin/r9700 comfy fetch`, files accepted only by the pinned sha256), and `sheets.py` (picking sheets of one episode) by `comfyui/tools/sheets.py`. The copies here stay because the recorded chains call them by these names. `fetch_model_pinned.sh` is byte-identical to `comfyui/fetch_model.sh` on 2026-11-13 and is here only because `chains/run_fetch_audio_local.sh` calls it by that name.

## What is not here

No picture, audio, video or LoRA weight; no generated list of files (the NAS copy lists, the 360 compare lists); no token. `run_klein9b_download.sh` mounts a `secrets` folder read-only and reads a token FILE inside the container (the token goes to curl as a header file, never on a command line); the script holds no token value, and the file is deleted after the download.
