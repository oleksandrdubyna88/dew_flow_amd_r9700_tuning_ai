#!/usr/bin/env bash
# lib/comfy_bench.sh — the arm-round of a ComfyUI arm and its measurement contract (E2.S2 of the ComfyUI plan). Bash >= 4.4, `set -u` safe, no `set -e`.
# Two faces, like lib/series.sh. SOURCED (by bin/r9700 and the tests): the seam the verb `comfy bench` uses; RUN as the worker, `bash lib/comfy_bench.sh <outdir> <workflow> <rounds> <arm>...`,
# which `step_run` starts as ONE step of the supervisor (E2.S3): the arm-rounds of the invocation that have no final record, in the balanced order. The worker sets no trap, takes no lock
# and never stops or starts the operator's ComfyUI or vLLM: it stops only the containers it started, and every one of them is prefixed (the supervisor's cleanup can stop it).
#
# The seam (what the verb calls):
#   comfy_bench_workflows / comfy_bench_metrics     the legal workflow names / the metrics of a block, from comfyui/bench.py (never typed twice; the standard library only)
#   comfy_bench_arms_conf / comfy_bench_evidence_conf   ${R9700_COMFY_ARMS_CONF:-<repository>/comfyui/arms.conf}, ${R9700_COMFY_EVIDENCE_CONF:-<repository>/comfyui/arm_evidence.conf}
#   comfy_bench_check <workflow> <rounds> <arm>...  after the machine config: both tables load, every arm of each is in the other, no forbidden word, every container label fits; 2 and a line per problem
#   comfy_bench_assets                              `<placed name> <repository source> <required|optional>` per line: comfyui/bench.py (moe_place places it under $WORK_DIR/r9700/comfyui)
#   comfy_bench_fingerprint <outdir> <workflow> <rounds> <real|dry> <arm>...   <outdir>/fingerprint.json: built (lib/fingerprint.py build-comfy), or compared and merged (a new arm, more
#                                                   rounds); another experiment: `fingerprint differs: ...` on stderr and 2; `dry` writes nothing
#   comfy_bench_left / comfy_bench_recorded <outdir> <rounds> <arm>...   the arm-rounds with no final record / with one
#   comfy_bench_dry_run <outdir> <workflow> <rounds> <arm>...   `dry-run: <command>` lines of the first arm-round; nothing is started
#
# One arm-round (comfy_bench_unit), the contract of the parent plan: the gate (disk, quiet, fit), the identity re-checked, rounds/<arm>-<round>.part-<run id>/, the bench cache volume (made when
# missing) cleared by a prefixed throwaway container, ONE fresh prefixed container (`--tmpfs /data:exec,size=8g`, the models volume `:ro`, the arm's arguments and environment, ComfyUI's default
# memory mode), the readiness and the free-card wait, one cold run and three measured runs of comfyui/bench.py through `exec` (the log saved after each; the cut of a run is what it added),
# the flags (a model load, a recompile), the drift, the validation, a CLEAN stop (SIGINT to the server, so that TunableOp writes its file) and the cache report, the evidence, then ONE rename into
# rounds/<arm>-<round>/. A failed validation or a ceiling stops the container (hard, and sees it gone) and moves the part to rejected/<tag>-<UTC stamp>/ with a `reason` file; nothing is deleted.
#
# The worker's exit codes: 0 every arm-round of the invocation recorded; 1 an arm-round was rejected, the disk gate stopped (KIND=disk_gate) or a container could not be started; 2 a refusal
# (KIND=refused: the identity changed, the bench cache could not be cleared, a container could not be stopped); 3 not quiet; 4 the next arm-round no longer fits before the deadline.
# Messages: `comfy-bench: <text>` on stdout (the step log), `r9700: comfy: bench: <text>` on stderr for the seam's refusals.
#
# Test knobs (the environment only, never machine.env): R9700_COMFY_ARMS_CONF, R9700_COMFY_EVIDENCE_CONF (copies of the two tables), R9700_COMFY_ARM_SECONDS (replaces the time one arm-round
# is allowed to need for the fit check; it goes through t_scale), R9700_COMFY_TEST_EXEC_S (replaces the adapter's ceiling of the exec of a run).

_CB_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CB_REPO="$(dirname "$_CB_LIB")"
_CB_UNIT_SH="config run_guarded adapter serve restore wait_ready disk_gate guard_quiet series comfy comfy_bench_evidence" # the libraries the worker sources AND the fingerprint's `tools` (the A24 rule)
_CB_UNIT_PY="fingerprint verdict"
_CB_EXCHANGE=/work/r9700/comfyui/bench # the exchange folder as the containers see it: ComfyUI's --output-directory and the run JSONs
_CB_ROUND_OVERHEAD_S=600               # the cache clear, the start and readiness, the free-card wait, the report: added to the ceilings for the fit check
_CB_CARD_WAIT_S=300                    # the free-card wait: probes t_scale 10 apart, vram_free x 10 >= vram_total x 9
_CB_STOP_WAIT_S=60                     # the clean stop's wait for the container to leave
# The programs of the throwaway containers: no variable in them (a path or a name is an ARGUMENT). One line each.
_CB_CLEAR_SH='du -s /cache/miopen /cache/triton /cache/tunableop /cache/inductor 2> /dev/null; rm -rf /cache/miopen /cache/triton /cache/tunableop /cache/inductor; mkdir -p /cache/miopen /cache/triton /cache/tunableop /cache/inductor'
_CB_REPORT_SH='du -s /cache/miopen /cache/triton /cache/tunableop /cache/inductor 2> /dev/null; for f in /cache/tunableop/tunableop_results*.csv; do [ -f "$f" ] || continue; echo "--- ${f##*/}"; cat "$f"; done' # TunableOp writes <name><device>.csv
_CB_LIST_SH='for f in "$@"; do case "$f" in dir:*) [ -d "/models/${f#dir:}" ] || echo "missing-dir ${f#dir:}" ;; *) if [ -f "/models/$f" ]; then echo "$f $(stat -c %s "/models/$f")"; fi ;; esac; done'
_CB_SIGINT_PY='import os, signal; os.kill(1, signal.SIGINT)' # pid 1 is the server (entrypoint.sh execs it): ComfyUI catches the interrupt and exits normally, which is when TunableOp writes its file

# the evidence table's functions: sourced here in both faces (the worker's loop below sources it too; it is in _CB_UNIT_SH for the fingerprint)
if ! declare -F comfy_evidence_load > /dev/null; then
  # shellcheck source=lib/comfy_bench_evidence.sh
  source "$_CB_LIB/comfy_bench_evidence.sh" || { echo "comfy_bench: comfy_bench_evidence.sh cannot be sourced" >&2; return 2 2> /dev/null || exit 2; }
fi

_cb_say() { echo "comfy-bench: $*"; }

_cb_err() { echo "r9700: comfy: bench: $*" >&2; }

comfy_bench_arms_conf() { printf '%s\n' "${R9700_COMFY_ARMS_CONF:-$_CB_REPO/comfyui/arms.conf}"; }

comfy_bench_evidence_conf() { printf '%s\n' "${R9700_COMFY_EVIDENCE_CONF:-$_CB_REPO/comfyui/arm_evidence.conf}"; }

comfy_bench_workflows() { python3 -I -S "$_CB_REPO/comfyui/bench.py" workflows; }

comfy_bench_metrics() { python3 -I -S "$_CB_REPO/comfyui/bench.py" metrics; }

comfy_bench_words() { python3 -I -S "$_CB_REPO/comfyui/bench.py" words; }

comfy_bench_assets() { printf '%s\n' "comfyui/bench.py comfyui/bench.py required"; }

# the copy the container runs: the placed one (the identity of the experiment is what runs, so it is what is hashed and asked for its constants)
_cb_placed() { container_host_path "$_COMFY_CONTAINER_DIR/bench.py"; }

_cb_stamp() { _series_stamp; }

comfy_bench_left() { series_left "$@"; }

comfy_bench_recorded() { series_recorded "$@"; }

# ---------- the checks before the lock ----------
comfy_bench_check() {
  local workflow="${1:-}" rounds="${2:-}" arm word bad=0 legal row
  shift 2 2> /dev/null
  legal="$(comfy_bench_workflows | tr '\n' ' ' | sed 's/ $//')"
  [[ " $legal " == *" $workflow "* ]] || { _cb_err "\"$workflow\" is not a workflow; legal: $legal"; return 2; }
  [[ $rounds =~ ^([1-9]|1[0-9]|20)$ ]] || { _cb_err "rounds \"$rounds\" is not a whole number from 1 to 20"; return 2; }
  arms_load "$(comfy_bench_arms_conf)" || return 2
  comfy_evidence_load "$(comfy_bench_evidence_conf)" || return 2
  for arm in "${_A_ORDER[@]}"; do [ -n "${_CE_LINE[$arm]+set}" ] || { _cb_err "arm \"$arm\" has no row in arm_evidence.conf"; bad=1; }; done
  for arm in "${_CE_ORDER[@]}"; do [ -n "${_A_LINE[$arm]+set}" ] || { _cb_err "arm_evidence.conf names \"$arm\", which is not an arm of arms.conf"; bad=1; }; done
  for arm in "${_A_ORDER[@]}"; do
    while read -r word; do
      [ -n "$word" ] || continue
      if [[ ${word%%=*} == COMFY_BENCH_* ]] && ! comfy_bench_words | grep -Fxq -- "${word%%=*}"; then
        _cb_err "arm \"$arm\" sets ${word%%=*}: only $(comfy_bench_words | tr '\n' ' ' | sed 's/ $//; s/ /, /') are words of an arm (no row relaxes its own ceilings or moves the API)"
        bad=1
      fi
      case ${word%%=*} in PYTORCH_HIP_ALLOC_CONF) _cb_err "arm \"$arm\" sets PYTORCH_HIP_ALLOC_CONF: trap 1 of the plan (it breaks the first allocation under /dev/dxg); no arm sets it"; bad=1 ;; esac
    done < <(arm_env "$arm")
    while read -r word; do
      case $word in
        --listen | --port | --base-directory | --models-directory | --output-directory) _cb_err "arm \"$arm\" sets $word, which is the worker's own"; bad=1 ;;
        --highvram | --lowvram | --normalvram | --gpu-only | --novram | --cpu | --disable-smart-memory | --reserve-vram | --cache-*)
          _cb_err "arm \"$arm\" sets $word, a memory or cache mode: ComfyUI's default memory mode is pinned for every arm (an arm is a flag of the server, an environment word, or how the model is loaded)"
          bad=1 ;;
      esac
    done < <(arm_args "$arm")
    [ -z "$(arm_mounts "$arm")" ] || { _cb_err "arm \"$arm\" has a mount: a bench container mounts only what the worker gives it"; bad=1; }
  done
  for arm in "${_CE_ORDER[@]}"; do
    [ -n "${_CE_ACT[$arm]}" ] || { _cb_err "arm_evidence.conf: $arm: the activation field is -: every arm, base included, names the evidence that it took effect"; bad=1; }
    comfy_evidence_argv_alone "$arm" && { _cb_err "arm_evidence.conf: $arm: the activation evidence is the argv alone; a passed flag is never proof it acted"; bad=1; }
  done
  [ "$bad" -eq 0 ] || return 2
  for arm in "$@"; do
    _arm_known "$arm" || return 2
    container_name "comfy-$arm-$rounds" > /dev/null || { _cb_err "the arm \"$arm\" makes a container label that is too long"; return 2; }
  done
  container_name "comfy-clear-$$" > /dev/null || return 2
}

# ---------- the identity (the fingerprint) ----------
# _cb_image_id: the engine's Id of COMFY_IMAGE in _CB_IMAGE_ID; 2 and one line when the image is not there
_cb_image_id() {
  local out rc
  out="$(wslc_inspect "$R9700_COMFY_IMAGE" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then _cb_err "the image $R9700_COMFY_IMAGE is not there (inspect code $rc); run bin/r9700 comfy build first"; return 2; fi
  _CB_IMAGE_ID="$(python3 -c 'import json, sys
d = json.load(sys.stdin)
print((d[0] if isinstance(d, list) else d)["Id"])' <<< "$out" 2> /dev/null)"
  [ -n "$_CB_IMAGE_ID" ] || { _cb_err "the engine's answer for the image $R9700_COMFY_IMAGE holds no Id"; return 2; }
}

# _cb_pins <workflow> <file>: `<folder>/<file> <sha256> <set>` for every model file the workflow loads (from the pinned lines of models.conf); 2 and one line when a file is not a line of it
_cb_pins() {
  local workflow="$1" key i found
  comfy_models_load "$(comfy_models_conf)" || return 2
  while read -r key; do
    found=no
    for i in "${!_COMFY_M_DIR[@]}"; do
      [ "${_COMFY_M_DIR[$i]}/$(_comfy_url_file_name "${_COMFY_M_URL[$i]}")" = "$key" ] || continue
      printf '%s %s %s\n' "$key" "${_COMFY_M_SHA[$i]}" "${_COMFY_M_SET[$i]}"
      found=yes
      break
    done
    [ "$found" = yes ] || { _cb_err "$key is not a line of comfyui/models.conf: the pinned identity of a model file is its line there"; return 2; }
  done < <(python3 -I -S "$(_cb_placed)" models "$workflow")
}

# _cb_entry_folders: the model folders comfyui/entrypoint.sh makes at every start (read from the script, never typed): `mkdir -p` on a READ-ONLY models volume fails for one that is missing
_cb_entry_folders() {
  sed -n '/^for d in /,/; do$/p' "$_CB_REPO/comfyui/entrypoint.sh" | tr -d '\\' | sed -e 's/^for d in //' -e 's/; do$//' | tr -s ' \n' '\n\n' | grep -v '^$'
}

# _cb_probe_models <inputs> <pins>: one throwaway container lists the workflow's files in the models volume (read-only, no card) and checks the folders the entrypoint of a bench container makes;
# a file or a folder that is not there refuses before anything is stopped (the listing stays in <inputs>/models_listing)
_cb_probe_models() {
  local inputs="$1" pins="$2" answer rc key sha set cname line folder missing=""
  local -a words=()
  while read -r key _; do words+=("$key"); done <<< "$pins"
  while read -r folder; do words+=("dir:$folder"); done < <(_cb_entry_folders)
  [ "${#words[@]}" -gt "$(wc -l <<< "$pins")" ] || { _cb_err "the folders of comfyui/entrypoint.sh could not be read (a bench container could not be checked)"; return 2; }
  cname="$(container_name "comfy-fp-$$")" || return 2
  _rg_run answer wslc_run_once 120 --name "$cname" -v "$R9700_COMFY_MODELS_VOLUME:/models:ro" --entrypoint sh "$R9700_COMFY_IMAGE" -c "$_CB_LIST_SH" sh "${words[@]}"
  rc=$?
  if [ "$rc" -ne 0 ]; then _cb_err "the throwaway container that lists the models failed (code $rc): ${answer%%$'\n'*}"; return 2; fi
  while IFS= read -r line; do
    [[ -z $line || $line =~ ^[^[:space:]]+\ [0-9]+$ || $line =~ ^missing-dir\ [a-z_]+$ ]] || { _cb_err "the throwaway container did not answer with a model listing: $line"; return 2; }
  done <<< "$answer"
  printf '%s\n' "$answer" > "$inputs/models_listing"
  while read -r key sha set; do
    grep -Fxq -- "$key" <(awk '{ print $1 }' <<< "$answer") || { _cb_err "/models/$key is not in the models volume ($set of comfyui/models.conf); run bin/r9700 comfy fetch $set first"; return 2; }
  done <<< "$pins"
  while read -r _ folder; do missing+="$folder "; done < <(grep '^missing-dir ' <<< "$answer")
  [ -z "$missing" ] || { _cb_err "/models/${missing%% *} is not a folder of the models volume: the entrypoint of a bench container makes the model folders and cannot on a read-only volume; run bin/r9700 comfy start once (it creates them)"; return 2; }
}

# _cb_write_tools <file>: `<module>_sh|_py <sha256>` for the shell libraries of the unit, the worker, the Python programs, and bench_py (the placed copy), arms_conf, evidence_conf
_cb_write_tools() {
  local mod
  {
    for mod in $_CB_UNIT_SH comfy_bench; do printf '%s_sh %s\n' "$mod" "$(_series_hash_path "$_CB_LIB/$mod.sh")"; done
    for mod in $_CB_UNIT_PY; do printf '%s_py %s\n' "$mod" "$(_series_hash_path "$_CB_LIB/$mod.py")"; done
    printf 'bench_py %s\n' "$(_series_hash_path "$(_cb_placed)")"
    printf 'arms_conf %s\n' "$(_series_hash_path "$(comfy_bench_arms_conf)")"
    printf 'evidence_conf %s\n' "$(_series_hash_path "$(comfy_bench_evidence_conf)")"
  } > "$1"
}

# _cb_write_inputs <inputs dir> <workflow> <rounds> <probe yes|no> <arm>...: one file per component group (lib/fingerprint.py build-comfy reads them). `no` leaves out the throwaway container.
_cb_write_inputs() {
  local inputs="$1" workflow="$2" rounds="$3" probe="$4" arm placed pins
  shift 4
  placed="$(_cb_placed)" || return 2
  [ -f "$placed" ] || { _cb_err "$placed is missing: comfyui/bench.py is placed there before the bench runs"; return 2; }
  mkdir -p "$inputs/arms" || return 2
  _cb_image_id || return 2
  for arm in "$@"; do
    arm_args "$arm" > "$inputs/arms/$arm.args" && arm_env "$arm" > "$inputs/arms/$arm.env" && arm_mounts "$arm" > "$inputs/arms/$arm.mounts" || return 2
  done
  python3 -I -S "$placed" constants "$workflow" > "$inputs/constants.json" || return 2
  pins="$(_cb_pins "$workflow")" || return 2
  awk '{ print $1, $2 }' <<< "$pins" > "$inputs/models"
  _cb_write_tools "$inputs/tools"
  printf 'KIND=comfy\nWORKFLOW=%s\nIMAGE_REF=%s\nIMAGE_ID=%s\nCOMFY_REF=%s\nBASE=base\nROUNDS=%s\nCONTAINER_PREFIX=%s\n' "$workflow" "$R9700_COMFY_IMAGE" "$_CB_IMAGE_ID" "$R9700_COMFY_REF" "$rounds" "$R9700_CONTAINER_PREFIX" > "$inputs/comfy.env"
  [ "$probe" = no ] || _cb_probe_models "$inputs" "$pins"
}

# _cb_keep_listing <inputs dir> <mode>: the models listing of the throwaway container is kept in the record: appended, with its time, to <outdir>/models_listing.txt (a real call only; a
# dry run writes nothing)
_cb_keep_listing() {
  [ "$2" = real ] && [ -f "$1/models_listing" ] || return 0
  { printf '# %s %s\n' "$(_series_iso)" "$_CB_FP_WORKFLOW"; cat "$1/models_listing"; } >> "$_CB_FP_OUT/models_listing.txt"
}

# comfy_bench_fingerprint <outdir> <workflow> <rounds> <real|dry> <arm>...: see the header. The steps are series_fingerprint's (lib/series.sh), with the comfy inputs and `build-comfy`.
comfy_bench_fingerprint() {
  local outdir="$1" workflow="$2" rounds="$3" mode="$4"
  shift 4
  _CB_FP_OUT="$outdir" _CB_FP_WORKFLOW="$workflow"
  _series_fingerprint_run "$outdir" "$mode" build-comfy "r9700: comfy: bench:" bench _cb_keep_listing _cb_write_inputs "$workflow" "$rounds" yes "$@"
}

# ---------- the words of an arm-round, shared by the worker and the dry run ----------
_cb_exch_c() { printf '%s/%s/%s\n' "$_CB_EXCHANGE" "${_CB_OUTNAME:?}" "$1"; }

_cb_exch_h() { container_host_path "$(_cb_exch_c "$1")"; }

_cb_cache_volume() { printf '%scomfy-cache\n' "$R9700_CONTAINER_PREFIX"; }

# _cb_run_args <array> <arm> <tag>: the words after `run -d --rm --name <name>`: the card, the empty /data in memory (exec: the entrypoint runs Python from a venv under it), the models volume
# read-only, the arm's own bench cache, the work folder, the arm's environment, the image, then ComfyUI's arguments (the output folder, then the arm's)
_cb_run_args() {
  local -n _ra="$1"
  local word
  _ra=(--gpus all --tmpfs /data:exec,size=8g -v "$R9700_COMFY_MODELS_VOLUME:/models:ro" -v "$(_cb_cache_volume):/cache" -v "$R9700_WORK_DIR_WIN:/work" --shm-size 8g)
  while read -r word; do [ -n "$word" ] && _ra+=(-e "$word"); done < <(arm_env "$2")
  _ra+=("$R9700_COMFY_IMAGE" --output-directory "$(_cb_exch_c "$3")")
  while read -r word; do [ -n "$word" ] && _ra+=("$word"); done < <(arm_args "$2")
}

# _cb_exec_words <array> <arm> <command words...>: `env <COMFY_BENCH_* words> python3 <placed bench.py> <words>` (the program reads its own environment, whatever `exec` hands on)
_cb_exec_words() {
  local -n _ew="$1"
  local arm="$2" word
  shift 2
  _ew=(env)
  while read -r word; do [[ $word == COMFY_BENCH_* ]] && _ew+=("$word"); done < <(arm_env "$arm")
  _ew+=(python3 "$_COMFY_CONTAINER_DIR/bench.py" "$@")
}

_cb_run_words() { printf '%s\n' --tag "$1" --run "$2" --out "$(_cb_exch_c "$1")"; }

comfy_bench_dry_run() {
  local outdir="$1" workflow="$2" arm="$4" name tag
  local -a run_args=() words=() rest=()
  local run
  _CB_OUTNAME="${outdir##*/}"
  tag="$arm-1"
  name="$(container_name "comfy-$arm-1")" || return 2
  echo "dry-run: $(wslc_argv_text run --rm --name "$(container_name "comfy-clear-1")" -v "$(_cb_cache_volume):/cache" --entrypoint sh "$R9700_COMFY_IMAGE" -c "$_CB_CLEAR_SH")"
  _cb_run_args run_args "$arm" "$tag"
  echo "dry-run: $(wslc_argv_text run -d --rm --name "$name" "${run_args[@]}")"
  for run in cold 1 2 3; do
    mapfile -t rest < <(_cb_run_words "$tag" "$run")
    _cb_exec_words words "$arm" run "$workflow" "${rest[@]}"
    echo "dry-run: run $run: $(wslc_argv_text exec "$name" "${words[@]}")"
  done
}

# ---------- the worker ----------
# _cb_refuse <detail>: the worker's own word that it will not go on (KIND=refused: the supervisor stops at once, no retry); 2
_cb_refuse() {
  _cb_say "$1"
  [ -z "${R9700_OUTCOME_FILE:-}" ] || outcome_write "$R9700_OUTCOME_FILE" KIND=refused RC=2 "DETAIL=comfy-bench: $1"
  return 2
}

_cb_const() { python3 -c 'import json, sys
d = json.load(open(sys.argv[1]))
for part in sys.argv[2].split("."):
    d = d[part]
print(d)' "$_CB_CONST_FILE" "$1"; }

# _cb_fit: the production seconds one arm-round is allowed to need: the cold ceiling, three measured ceilings and the overhead; R9700_COMFY_ARM_SECONDS replaces the sum
_cb_fit() { echo "${R9700_COMFY_ARM_SECONDS:-$(($(_cb_const ceilings.cold_max_s) + 3 * $(_cb_const ceilings.run_max_s) + _CB_ROUND_OVERHEAD_S))}"; }

# _cb_order <round>: the arms as given for an odd round, reversed for an even one
_cb_order() {
  local i
  if [ $(($1 % 2)) -eq 1 ]; then printf '%s\n' "${_CB_ARMS[@]}"; else for ((i = ${#_CB_ARMS[@]} - 1; i >= 0; i--)); do echo "${_CB_ARMS[$i]}"; done; fi
}

# _cb_gate <arm> <round>: before every arm-round: _series_gate (lib/series.sh) with the fit of an arm-round of this bench. 0 go on; 1 the disk gate stopped; 3 not quiet; 4 it no longer fits
_cb_gate() { _series_gate "$1" "$2" "$(_cb_fit)"; }

# _cb_recheck: the identity against fingerprint.json at the start of EVERY arm-round (one step can restart this worker for hours): the cheap components are built again (the tables, the
# constants, the hashes, the pins, the image id), the throwaway container is not run. A difference: the lines to stdout and the outcome KIND=refused (2: no retry).
_cb_recheck() {
  local inputs="$_CB_OUT/.fingerprint-inputs.part-$RUN_ID-w" out rc=0 detail
  arms_load "$(comfy_bench_arms_conf)" || return 2
  comfy_evidence_load "$(comfy_bench_evidence_conf)" || return 2
  _cb_write_inputs "$inputs" "$_CB_WORKFLOW" "$_CB_ROUNDS" no "${_CB_ARMS[@]}" || rc=2
  [ "$rc" -ne 0 ] || python3 "$_CB_LIB/fingerprint.py" build-comfy "$inputs" --out "$inputs/now.json" > /dev/null || rc=2
  if [ "$rc" -eq 0 ]; then
    out="$(python3 "$_CB_LIB/fingerprint.py" compare "$_CB_OUT/fingerprint.json" "$inputs/now.json")"
    rc=$?
  else
    out="the identity of the experiment could not be re-checked"
  fi
  rm -rf "${inputs:?}"
  [ "$rc" -eq 0 ] && return 0
  printf '%s\n' "$out"
  detail="${out//$'\n'/; }"
  [ -z "${R9700_OUTCOME_FILE:-}" ] || outcome_write "$R9700_OUTCOME_FILE" KIND=refused RC=2 "DETAIL=$detail"
  return 2
}

# _cb_part_reason <part dir> <name>: the reason of a part a killed worker left: the run that left it and what that run's status file says
_cb_part_reason() {
  local id status="not found" file
  id="$(sed -n 's/^RUN_ID=//p' "$1/record.env" 2> /dev/null | head -n 1)"
  [ -n "$id" ] || id="${2##*.part-}"
  file="$R9700_RESULTS_DIR/runs/$id/status"
  [ -f "$file" ] && status="$(head -n 1 "$file")"
  printf 'INTERRUPTED: %s was left by run %s (its status: %s)\n' "$2" "$id" "$status"
}

_cb_rec() { printf '%s\n' "$@" >> "$_CB_PART/record.env"; }

_cb_listed_gone() {
  local out
  out="$(wslc_list 2> /dev/null)" || return 1 # a list that cannot be read cannot show the container gone
  ! grep -Fxq -- "$1" <<< "$out"
}

# _cb_gone <container>: stops it (the stop time does not apply: a stop must work after T_STOP too) and checks it is no longer LISTED, up to 3 stops; 0 gone; else the refusal of the worker
_cb_gone() {
  local R9700_T_STOP="" try
  for try in 1 2 3; do
    wslc_stop "$1" > /dev/null 2>&1
    _cb_listed_gone "$1" && return 0
    [ "$try" -lt 3 ] && sleep "$(t_scale 2)" 9>&-
  done
  _cb_refuse "the container $1 is still listed after the stop; stop it by hand"
}

# _cb_save_log: the container's whole log again into <part>/server.log, replaced whole (never half written); 1 when the engine has none to give (the older file stays)
_cb_save_log() {
  local new="$_CB_PART/server.log.new"
  if wslc_logs "$_CB_NAME" > "$new" 2> /dev/null && [ -s "$new" ]; then mv -f "$new" "$_CB_PART/server.log"; else rm -f "$new"; return 1; fi
}

# _cb_cut <k>: runs/<k>.log is the lines the log gained since the save before it (an append-only log: a cut is a line range)
_cb_cut() {
  local total
  total="$(wc -l < "$_CB_PART/server.log" 2> /dev/null || echo 0)"
  tail -n "+$((_CB_LOG_N + 1))" "$_CB_PART/server.log" > "$_CB_PART/runs/$1.log" 2> /dev/null || : > "$_CB_PART/runs/$1.log"
  _CB_LOG_N="$total"
}

# _cb_collect <tag>: what the exchange folder holds goes into the part: the run JSONs into runs/, every other file into outputs/
_cb_collect() {
  local dir file name
  dir="$(_cb_exch_h "$1")"
  mkdir -p "$_CB_PART/runs" "$_CB_PART/outputs"
  for file in "$dir"/*; do
    [ -f "$file" ] || continue
    name="${file##*/}"
    if [[ $name == run-*.json ]]; then mv -f "$file" "$_CB_PART/runs/${name#run-}"; else mv -f "$file" "$_CB_PART/outputs/$name"; fi
  done
}

_cb_rm_exch() { rm -rf "$(_cb_exch_h "$1")" "$(dirname "$(_cb_exch_h "$1")")/ref"; }

# _cb_abort <tag> <reason>: the arm-round is rejected: the log is saved, the container is stopped and seen gone (before anything else happens), the exchange files kept in the part, the part moved
# to rejected/ with its reason. 1 rejected; 2 the container could not be stopped (the refusal is said)
_cb_abort() {
  local tag="$1" reason="$2"
  [ -z "$_CB_NAME" ] || { _cb_save_log; _cb_gone "$_CB_NAME" || return 2; }
  _cb_collect "$tag"
  _cb_rm_exch "$tag"
  _series_reject "$_CB_OUT" "$tag" "$_CB_PART" "$reason" || return 1
  sed "s/^/$tag: /" <<< "$reason"
  return 1
}

# _cb_cache <tag>: the bench cache volume (list first, create only when missing) and the clear before the arm-round: a prefixed throwaway container with only that volume. 0; 1 rejected; 2 refused
_cb_cache() {
  local tag="$1" listing out rc line
  listing="$(wslc_volume_list 2>&1)"
  rc=$?
  [ "$rc" -eq 0 ] || { _cb_abort "$tag" "VOLUME: the volume list failed (code $rc)${listing:+: ${listing##*$'\n'}}"; return $?; }
  comfy_volume_ensure "$(_cb_cache_volume)" "$listing" bench || { _cb_abort "$tag" "VOLUME: ${_COMFY_ERR:-the volume could not be made}"; return $?; }
  out="$(wslc_run_once 90 --name "$(container_name "comfy-clear-$$")" -v "$(_cb_cache_volume):/cache" --entrypoint sh "$R9700_COMFY_IMAGE" -c "$_CB_CLEAR_SH")"
  rc=$?
  while IFS= read -r line; do [ -z "$line" ] || printf 'before clear: %s\n' "${line//$'\t'/ }" >> "$_CB_PART/cache.txt"; done <<< "$out"
  [ "$rc" -eq 0 ] && return 0
  _cb_abort "$tag" "REFUSED: the bench cache could not be cleared before the arm-round (code $rc): a stale cache would be measured"
  _cb_refuse "the bench cache could not be cleared before the arm-round: a stale cache would be measured"
}

# _cb_exchange <arm> <round> <tag>: the exchange folder of the tag made empty, and the drift's references copied into <exchange>/ref: the base's round-1 outputs of the three seeds
_cb_exchange() {
  local arm="$1" round="$2" tag="$3" dir ref file
  dir="$(_cb_exch_h "$tag")"
  ref="$(dirname "$dir")/ref"
  rm -rf "$dir" "$ref"
  mkdir -p "$dir" || return 1
  _CB_DRIFT=ok
  if [ "$arm" = base ] && [ "$round" = 1 ]; then _CB_DRIFT="base-1 is the reference"
  elif [ ! -d "$_CB_OUT/rounds/base-1" ]; then
    _CB_DRIFT="no base-1 record" # missing, or rejected (a rejected attempt is in rejected/, never a reference)
  else
    mkdir -p "$ref" || return 1
    for file in "$_CB_OUT"/rounds/base-1/outputs/*_r[123]_*; do [ -f "$file" ] && cp -- "$file" "$ref/"; done
  fi
}

# _cb_card_free <tag>: the probe every t_scale 10 for at most 300 s until vram_free x 10 >= vram_total x 9, one progress line every 30 s; the last reading in _CB_VRAM_FREE/_TOTAL. 0 free; 1 and _CB_WHY
_cb_card_free() {
  local tag="$1" waited=0 out rc free total
  while :; do
    out="$(comfy_probe "$_CB_NAME" 2>&1)"
    rc=$?
    free="$(sed -n 's/^vram_free //p' <<< "$out" | head -n 1)"
    total="$(sed -n 's/^vram_total //p' <<< "$out" | head -n 1)"
    if [ "$rc" -ne 0 ]; then _CB_WHY="UNSTARTED: the card probe of $_CB_NAME failed (code $rc): ${out##*$'\n'}"; return 1; fi
    if ! [[ $free =~ ^[0-9]+$ && $total =~ ^[1-9][0-9]*$ ]]; then _CB_WHY="CARD: vram not reported by /system_stats"; return 1; fi
    _CB_VRAM_FREE="$free" _CB_VRAM_TOTAL="$total"
    [ $((free * 10)) -ge $((total * 9)) ] && return 0
    if [ "$waited" -ge "$_CB_CARD_WAIT_S" ]; then
      _CB_WHY="UNSTARTED: the card is not free (vram_free $free of $total after $waited s); another container may hold it (the engine's container list shows which), or the operator's ComfyUI (bin/r9700 comfy stop)"
      return 1
    fi
    if [ "$waited" -gt 0 ] && [ $((waited % 30)) -eq 0 ]; then echo "comfy: bench: $tag: waiting for the card: vram_free $free of $total (${waited}s)"; fi
    sleep "$(t_scale 10)" 9>&-
    waited=$((waited + 10))
  done
}

# _cb_start <arm> <tag>: the container (ONE attempt; the list decides what a failed call left), its readiness, the free card. 0; 1 rejected; 2 refused
_cb_start() {
  local arm="$1" tag="$2" out rc
  local -a run_args=()
  _cb_run_args run_args "$arm" "$tag"
  _CB_NAME="$_CB_CNAME" # the attempt is recorded before the call: a run that fails may still have made the container, and the list decides
  out="$(wslc_run "$_CB_NAME" "${run_args[@]}" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then _cb_abort "$tag" "UNSTARTED: the run of $_CB_NAME failed (code $rc): ${out##*$'\n'}"; return $?; fi
  ready_wait "$_CB_NAME" "$R9700_READY_TIMEOUT_S" comfy_probe ready -
  rc=$?
  if [ "$rc" -ne 0 ]; then _cb_abort "$tag" "UNSTARTED: ${READY_LINE:-$_CB_NAME did not become ready (code $rc)}"; return $?; fi
  _cb_rec "VRAM_FREE_FIRST=$(sed -n 's/^vram_free //p' <<< "$READY_ANSWER" | head -n 1)" "VRAM_TOTAL_FIRST=$(sed -n 's/^vram_total //p' <<< "$READY_ANSWER" | head -n 1)"
  if ! _cb_card_free "$tag"; then _cb_abort "$tag" "$_CB_WHY"; return $?; fi
  _cb_rec "VRAM_FREE_BEFORE=$_CB_VRAM_FREE" "VRAM_TOTAL_BEFORE=$_CB_VRAM_TOTAL"
}

# _cb_run <arm> <tag> <k>: one run of bench.py through exec (k: cold, 1, 2, 3); the log saved and cut; the lines kept. 0; 1 rejected; 2 refused
_cb_run() {
  local arm="$1" tag="$2" k="$3" ceiling out rc last reached key
  local -a words=() rest=()
  if [ "$k" = cold ]; then key=cold_max_s; else key=run_max_s; fi
  ceiling="${R9700_COMFY_TEST_EXEC_S:-$(($(_cb_const "ceilings.$key") + 60))}"
  mapfile -t rest < <(_cb_run_words "$tag" "$k")
  _cb_exec_words words "$arm" run "$_CB_WORKFLOW" "${rest[@]}"
  out="$(wslc_exec "$ceiling" "$_CB_NAME" "${words[@]}")"
  rc=$?
  printf '%s\n' "$out" > "$_CB_PART/runs/$k.out"
  if [ "$k" = cold ]; then grep '^cold: ' <<< "$out" >> "$_CB_PART/runs/cold.txt"; else grep "^$tag " <<< "$out" >> "$_CB_PART/bench.txt"; fi
  _cb_save_log
  _cb_cut "$k"
  [ "$rc" -eq 0 ] && return 0
  last="$(grep -v '^[[:space:]]*$' <<< "$out" | tail -n 1)"
  reached="$(grep -oE '(COLD|RUN)_TIMEOUT [0-9.]+' <<< "$out" | tail -n 1 | cut -d' ' -f2)"
  case "$rc:$last" in
    3:COLD_TIMEOUT*) _cb_abort "$tag" "COLD_TIMEOUT: the cold run reached $reached s of cold_max_s $(_cb_const ceilings.cold_max_s)" ;;
    3:RUN_TIMEOUT*) _cb_abort "$tag" "CEILING: run $k reached $reached s of run_max_s $(_cb_const ceilings.run_max_s)" ;;
    124:* | 137:*) _cb_abort "$tag" "CEILING: the exec of run $k was ended by the adapter" ;;
    1:*) _cb_abort "$tag" "${last:-bench.py failed without a line}" ;;
    *) _cb_abort "$tag" "RUN: the exec of run $k ended with code $rc: ${last:-no line}" ;;
  esac
}

# _cb_flags: the load and recompile counts of each measured run's cut, to flags.txt and record.env; never into bench.txt (its grammar admits no other line)
_cb_flags() {
  local k line
  : > "$_CB_PART/flags.txt"
  for k in 1 2 3; do
    line="$(_cb_flags_line "$_CB_PART/runs/$k.log")"
    printf 'run %s: %s\n' "$k" "$line" >> "$_CB_PART/flags.txt"
    _cb_rec "FLAGS_RUN_$k=$(sed -E 's/load ([0-9]+), recompile ([0-9]+)/load=\1,recompile=\2/' <<< "$line")"
  done
}

# _cb_drift: per measured seed the mean absolute difference and the PSNR against the base's round-1 output of the same seed (computed in the container with the image's numpy and Pillow);
# `unavailable (<why>)` when the reference is missing; recorded, never gating
_cb_drift() {
  local out rc ref
  ref="$(dirname "$(_cb_exch_c x)")/ref"
  if [ "$_CB_DRIFT" != ok ]; then echo "drift: unavailable ($_CB_DRIFT)" > "$_CB_PART/drift.txt"; return 0; fi
  out="$(wslc_exec 300 "$_CB_NAME" python3 "$_COMFY_CONTAINER_DIR/bench.py" drift "$_CB_WORKFLOW" --out "$(_cb_exch_c "$1")" --ref "$ref")"
  rc=$?
  if [ "$rc" -eq 0 ]; then printf '%s\n' "$out" > "$_CB_PART/drift.txt"; else echo "drift: unavailable (the drift run failed (code $rc))" > "$_CB_PART/drift.txt"; fi
}

# _cb_clean_stop: SIGINT to the server (pid 1), then the wait until the container has left (--rm removes it); a container that stays gets the hard stop and STOP=forced
_cb_clean_stop() {
  local waited=0
  wslc_exec 30 "$_CB_NAME" python3 -c "$_CB_SIGINT_PY" > /dev/null 2>&1
  while [ "$waited" -lt "$_CB_STOP_WAIT_S" ]; do
    _cb_listed_gone "$_CB_NAME" && { _CB_STOP=clean; return 0; }
    sleep "$(t_scale 10)" 9>&-
    waited=$((waited + 10))
  done
  _cb_listed_gone "$_CB_NAME" && { _CB_STOP=clean; return 0; }
  _CB_STOP=forced
  _cb_gone "$_CB_NAME"
}

# _cb_report: the bench cache after the arm-round: one throwaway container prints the sizes and every TunableOp results file (`--- <file name>`, then its lines: TunableOp writes
# <name><device number>.csv, so the name is read, never typed); the sizes go to cache.txt, each file to <part>/<its name>
_cb_report() {
  local out rc line file=""
  out="$(wslc_run_once 120 --name "$(container_name "comfy-report-$$")" -v "$(_cb_cache_volume):/cache" --entrypoint sh "$R9700_COMFY_IMAGE" -c "$_CB_REPORT_SH")"
  rc=$?
  if [ "$rc" -ne 0 ]; then _CB_PROBLEMS+=("CACHE: the report of the bench cache failed (code $rc): ${out%%$'\n'*}"); return 0; fi
  while IFS= read -r line; do
    if [[ $line == '--- '* ]]; then
      file="${line#--- }"
      [[ $file =~ ^tunableop_results[A-Za-z0-9._-]*\.csv$ ]] || { _CB_PROBLEMS+=("CACHE: the report names a file \"$file\" that is not a TunableOp results file"); file=""; continue; }
      : > "$_CB_PART/$file"
    elif [ -n "$file" ]; then printf '%s\n' "$line" >> "$_CB_PART/$file"
    elif [ -n "$line" ]; then printf 'after run: %s\n' "${line//$'\t'/ }" >> "$_CB_PART/cache.txt"; fi
  done <<< "$out"
}

# _cb_evidence <arm>: the activation checks of the arm against the record's own files (missing: a problem, EVIDENCE: activation <check>: missing (<where>)); the inertness checks (all present:
# INERT=yes and the matched lines). The argv alone is never activation evidence (comfy_bench_check refuses such a row). evidence.txt holds every line.
_cb_evidence() {
  local arm="$1" check kind arg detail n line inert=yes any=no
  local -a matched=()
  : > "$_CB_PART/evidence.txt"
  while IFS= read -r check; do
    kind="${check%%=*}" arg="${check#*=}"
    detail="$(_cb_check_one "$kind" "$arg" "$_CB_PART" "$_CB_STOP")" && printf 'activation %s: %s\n' "$check" "$detail" >> "$_CB_PART/evidence.txt" \
      || { printf 'activation %s: %s\n' "$check" "$detail" >> "$_CB_PART/evidence.txt"; _CB_PROBLEMS+=("EVIDENCE: activation $check: $detail"); }
  done < <(comfy_evidence_checks "${_CE_ACT[$arm]:-}")
  while IFS= read -r check; do
    any=yes
    kind="${check%%=*}" arg="${check#*=}"
    if detail="$(_cb_check_one "$kind" "$arg" "$_CB_PART" "$_CB_STOP")"; then
      n="$(grep -oE 'server\.log:[0-9]+' <<< "$detail" | cut -d: -f2)"
      line="$(sed -n "${n:-0}p" "$_CB_PART/server.log" 2> /dev/null)"
      matched+=("$line")
      printf 'inertness %s: %s %s\n' "$check" "$detail" "$line" >> "$_CB_PART/evidence.txt"
    else
      inert=no
      printf 'inertness %s: %s\n' "$check" "$detail" >> "$_CB_PART/evidence.txt"
    fi
  done < <(comfy_evidence_checks "${_CE_INERT[$arm]:-}")
  [ "$any" = yes ] || inert=no
  _CB_INERT="$inert"
  _CB_INERT_LINES="$(IFS=';'; printf '%s' "${matched[*]}" | sed 's/;/ ; /g')"
  [ "$inert" = no ] || echo "inert on $_CB_WORKFLOW: ${_CB_INERT_LINES}" >> "$_CB_PART/evidence.txt"
}

# _cb_validate <tag> <arm>: the checks before the record becomes final: the container is still listed, the log saved a last time, the bench lines are exactly one complete block, four run
# JSONs and four outputs are there; only then the CLEAN stop, the cache report and the evidence; the log is not empty. 0 the record may become final; 1 the reasons are in _CB_PROBLEMS
_cb_validate() {
  local tag="$1" arm="$2" out rc line files k alive=1
  _cb_listed_gone "$_CB_NAME" && alive=0
  [ "$alive" -eq 0 ] || _cb_save_log
  out="$(python3 "$_CB_LIB/verdict.py" comfy-check-block --tag "$tag" --workflow "$_CB_WORKFLOW" --metrics "$(comfy_bench_metrics)" "$_CB_PART/bench.txt" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then while IFS= read -r line; do [ -n "$line" ] && _CB_PROBLEMS+=("check-block: ${line/missing: /missing }"); done <<< "$out"; fi
  _cb_collect "$tag"
  for k in cold 1 2 3; do [ -s "$_CB_PART/runs/$k.json" ] || _CB_PROBLEMS+=("RUN: runs/$k.json is missing"); done
  files="$(find "$_CB_PART/outputs" -maxdepth 1 -type f | wc -l | tr -d ' ')"
  [ "$files" -eq 4 ] || _CB_PROBLEMS+=("OUTPUT: $files output files, expected 4 (the cold run's and the three measured)")
  if [ "$alive" -eq 1 ] && [ "${#_CB_PROBLEMS[@]}" -eq 0 ]; then
    _cb_clean_stop || return 2
    _cb_report
    _cb_rec "STOP=$_CB_STOP"
    _cb_evidence "$arm"
  elif [ "$alive" -eq 1 ]; then
    _cb_gone "$_CB_NAME" || return 2
  fi
  [ -s "$_CB_PART/server.log" ] || _CB_PROBLEMS+=("server.log: empty")
  [ "$alive" -eq 1 ] || _CB_PROBLEMS=("LOST: server alive 0" "${_CB_PROBLEMS[@]}")
  [ "${#_CB_PROBLEMS[@]}" -eq 0 ]
}

# comfy_bench_unit <arm> <round>: one arm-round. 0 go on (recorded, or already recorded); else the worker's exit code
comfy_bench_unit() {
  local arm="$1" round="$2" tag="$1-$2" started rc k reason
  _series_final "$_CB_OUT" "$arm" "$round" && return 0
  _cb_gate "$arm" "$round" || return $?
  _cb_recheck || return 2
  _CB_PART="$_CB_OUT/rounds/$tag.part-$RUN_ID"
  mkdir -p "$_CB_OUT/rounds" && mkdir "$_CB_PART" && mkdir "$_CB_PART/runs" && : > "$_CB_PART/bench.txt" || { _cb_say "$_CB_PART cannot be made"; return 1; }
  started="$(_series_iso)"
  echo "=== $started $arm round $round (load $(cut -d' ' -f1-3 "${R9700_LOADAVG_FILE:-/proc/loadavg}" 2> /dev/null))"
  _CB_CNAME="$(container_name "comfy-$arm-$round")" || return 1
  _CB_NAME="" # set when the container is about to be started: a stop or a log call names only a container that may exist
  _CB_PROBLEMS=() _CB_STOP=clean _CB_LOG_N=0 _CB_INERT=no _CB_INERT_LINES=""
  printf 'ARM=%s\nROUND=%s\nRUN_ID=%s\nCONTAINER=%s\nSTARTED_AT=%s\nFINGERPRINT=%s\nWORKFLOW=%s\nIMAGE_ID=%s\n' "$arm" "$round" "$RUN_ID" "$_CB_CNAME" "$started" \
    "$(python3 "$_CB_LIB/fingerprint.py" show "$_CB_OUT/fingerprint.json" sha256)" "$_CB_WORKFLOW" "$(python3 "$_CB_LIB/fingerprint.py" show "$_CB_OUT/fingerprint.json" image.id)" > "$_CB_PART/record.env"
  _cb_cache "$tag" || return $?
  _cb_exchange "$arm" "$round" "$tag" || { _cb_say "the exchange folder cannot be made"; return 1; }
  _cb_start "$arm" "$tag" || return $?
  for k in cold 1 2 3; do _cb_run "$arm" "$tag" "$k" || return $?; done
  _cb_flags
  _cb_drift "$tag"
  _cb_validate "$tag" "$arm"
  rc=$?
  [ "$rc" -ne 2 ] || return 2
  if [ "$rc" -ne 0 ]; then
    reason="$(printf '%s\n' "${_CB_PROBLEMS[@]}")"
    _CB_NAME="" # the container is stopped and seen gone already
    _cb_abort "$tag" "$reason"
    return $?
  fi
  _cb_rec "INERT=$_CB_INERT" "INERT_EVIDENCE=$_CB_INERT_LINES" "FINISHED_AT=$(_series_iso)"
  _cb_rm_exch "$tag"
  mv -T "$_CB_PART" "$_CB_OUT/rounds/$tag" || { _cb_say "$_CB_PART cannot become $tag"; return 1; }
  echo "recorded $tag"
  [ "$_CB_INERT" != yes ] || echo "$tag: inert on $_CB_WORKFLOW ($_CB_INERT_LINES)"
  sleep "$(t_scale 10)" 9>&-
}

# comfy_bench_main <outdir> <workflow> <rounds> <arm>...: the worker
comfy_bench_main() {
  local rc round arm
  _CB_OUT="$1" _CB_WORKFLOW="$2" _CB_ROUNDS="$3"
  shift 3
  _CB_ARMS=("$@")
  _CB_OUTNAME="${_CB_OUT##*/}"
  RUN_ID="$(basename "${R9700_RUN_DIR:?R9700_RUN_DIR is not set (run by the supervisor only)}")"
  _SERIES_WHO=comfy-bench _SERIES_OUT="$_CB_OUT" _SERIES_ROUNDS="$_CB_ROUNDS" _SERIES_ARMS=("${_CB_ARMS[@]}") # the globals the series helpers (the gate, the sweep) read
  arms_load "$(comfy_bench_arms_conf)" || exit 2
  comfy_evidence_load "$(comfy_bench_evidence_conf)" || exit 2
  _CB_CONST_FILE="$R9700_RUN_DIR/comfy-constants.json"
  python3 -I -S "$(_cb_placed)" constants "$_CB_WORKFLOW" > "$_CB_CONST_FILE" || { _cb_say "bench.py constants failed for $_CB_WORKFLOW"; exit 2; }
  _cb_say "fit: $(_cb_fit) s per arm-round"
  series_sweep_parts "$_CB_OUT" _cb_part_reason
  rm -rf "$(dirname "$(_cb_exch_h x)")" # the exchange folders an earlier worker left: scratch, ours
  for ((round = 1; round <= _CB_ROUNDS; round++)); do
    for arm in $(_cb_order "$round"); do
      comfy_bench_unit "$arm" "$round"
      rc=$?
      [ "$rc" -eq 0 ] || exit "$rc"
    done
  done
  _series_disk_gate || exit 1
  _cb_say "every arm-round of this invocation is recorded"
}

# run as the worker only when executed, not when sourced
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -u
  for _cb_lib in $_CB_UNIT_SH; do
    # shellcheck source=/dev/null
    source "$_CB_LIB/$_cb_lib.sh" || exit 2
  done
  comfy_bench_main "$@"
fi
