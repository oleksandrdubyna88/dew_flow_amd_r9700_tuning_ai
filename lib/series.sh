#!/usr/bin/env bash
# lib/series.sh — a series of arm-rounds and the ship test read back from its records (E1.S3). Bash >= 4.4, `set -u` safe, no `set -e`.
# Two faces. SOURCED by bin/r9700: the supervisor's half (the fingerprint, the resume count, the checks before admission, the verdict). RUN as the
# worker, `bash lib/series.sh <outdir> <rounds> <arm>...`, which `bin/r9700 series` starts as ONE step of the supervisor (lib/step.sh): the
# worker's half, one arm-round after the other. The worker sets no trap and never stops the operator's server: the supervisor owns both.
#
#   series_fingerprint <outdir> <rounds> <real|dry> <arm>...   <outdir>/fingerprint.json: built from the inputs (lib/fingerprint.py), or compared
#                                                   with the stored one (a difference: the lines on stderr, return 2; a new arm or more rounds: an
#                                                   extension); `dry` writes nothing
#   series_dry_run <outdir> <rounds> <arm>...       the resolved commands of the first arm-round, printed
#   series_left <outdir> <rounds> <arm>...          the number of arm-rounds with no final record and no unsupported mark
#   series_recorded <outdir> <rounds> <arm>...      the number of final records
#   series_quality_sync <outdir>                    quality/gsm8k_<arm>.json from each round-1 record, where the copy is missing or differs
#   series_preflight <outdir> <rounds> <arm>...     before admission: harness.py placed in WORK_DIR, the GSM8K data checked (return 2)
#   series_verdict <outdir> [--base <arm>] [--no-quality] [--json <file>]   the ship test over the final records
#
# The arm-round record (decision 3). rounds/<arm>-<round>/ is final; while it is built it is rounds/<arm>-<round>.part-<run id>/. It becomes
# final by ONE rename(2) after the validation: the bench lines are exactly one complete block (lib/verdict.py check-block), the container is still
# listed, in round 1 both quality files pass lib/fingerprint.py check-quality, server.log is not empty. A failed validation moves the directory to
# rejected/<arm>-<round>-<UTC stamp>/ with a `reason` file, and the worker exits 1; nothing is ever deleted. A part directory a killed worker left is
# moved to rejected/ with an INTERRUPTED reason at the next start. An arm that does not start twice gets unsupported/<arm>-<stamp>.txt.
#
# The worker's exit codes: 0 done, 1 an arm-round was rejected or the disk gate stopped, 3 the PC is not quiet, 4 the next arm-round no longer
# fits before the deadline (the supervisor reads 0, 3 and 4 as `done`, `wait` and `deadline`; anything else is a failed try).
#
# Test knob (the environment only, never machine.env): R9700_ARM_SECONDS, the time one arm-round is allowed to need for the fit check (default
# 1500, the figure of the old night5.sh); it goes through t_scale. R9700_ARMS_CONF replaces config/arms.conf.

_SERIES_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SERIES_SERVER_CONFIG_RE="option 7: wide-N|Using configuration from|Using default MoE config|RDNAHybrid|GPU KV cache size|max_num_scheduled_tokens|Fused multi-step|attention backend|Cannot use ROCm"
_SERIES_SPEC_PY="import urllib.request;print(urllib.request.urlopen('http://127.0.0.1:8000/metrics').read().decode())"

# The program of the throwaway container: the model's file names and sizes, `---`, then every file under the generation config as
# `<path> <sha256>`. The model path and the generation config folder are ARGUMENTS ($1, $2), never text of the program (plan-gate E1 finding 1).
# ONE line: a newline inside an argument is not kept by every tool that records a call (the stub's call log writes it as <LF>).
_SERIES_PROBE_SH='find "$1" -type f -printf "%P %s\n" 2> /dev/null | LC_ALL=C sort; echo ---; cd "$2" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum | awk '"'"'{ h = $1; sub(/^[0-9a-f]+  (\.\/)?/, ""); print $0 " " h }'"'"

series_arms_conf() { printf '%s\n' "${R9700_ARMS_CONF:-$_SERIES_LIB/../config/arms.conf}"; }

_series_stamp() { date -u +%Y%m%dT%H%M%SZ 9>&-; }

_series_iso() { date -u +%FT%TZ 9>&-; }

_series_final() { [ -d "$1/rounds/$2-$3" ]; }

_series_unsupported() { compgen -G "$1/unsupported/$2-*.txt" > /dev/null; }

# series_left / series_recorded <outdir> <rounds> <arm>...: counts over the rounds x arms of the invocation (night5.sh line 30)
series_left() {
  local outdir="$1" rounds="$2" arm round n=0
  shift 2
  for ((round = 1; round <= rounds; round++)); do
    for arm in "$@"; do
      _series_final "$outdir" "$arm" "$round" || _series_unsupported "$outdir" "$arm" || n=$((n + 1))
    done
  done
  echo "$n"
}

series_recorded() {
  local outdir="$1" rounds="$2" arm round n=0
  shift 2
  for ((round = 1; round <= rounds; round++)); do
    for arm in "$@"; do _series_final "$outdir" "$arm" "$round" && n=$((n + 1)); done
  done
  echo "$n"
}

# ---------- the fingerprint (decisions 1 and 2) ----------
# _series_hash_path <path>: the sha256 of a file; of a folder, the sha256 of its files' `<hash>  <path>` lines in C order
_series_hash_path() {
  if [ -d "$1" ]; then
    (cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum | sha256sum | cut -c1-64) 9>&-
  else
    sha256sum < "$1" | cut -c1-64
  fi
}

# _series_write_patches <file> <arm>...: <relative source> <hash> for every mount of the model and of the given arms, sorted, once each
_series_write_patches() {
  local file="$1" word arm source
  shift
  {
    for word in $R9700_MOUNTS; do echo "${word%%:*}"; done
    for arm in "$@"; do while read -r word; do [ -n "$word" ] && echo "${word%%:*}"; done < <(arm_mounts "$arm"); done
  } | LC_ALL=C sort -u | while read -r source; do
    [ -n "$source" ] || continue
    printf '%s %s\n' "$source" "$(_series_hash_path "$R9700_PATCH_DIR/$source")"
  done > "$file"
}

# _series_probe <inputs dir>: runs the throwaway container and writes <inputs>/listing and <inputs>/genconfig; 2 with one `series:` line
_series_probe() {
  local inputs="$1" answer rc line listing genconfig cname
  cname="$(container_name "fp-$$")" || return 2
  # _rg_run, like every other call of the supervisor: a TERM during the (up to 120 s) call ends it at once, not after its ceiling
  _rg_run answer wslc_run_once 120 --name "$cname" -v "$R9700_HF_VOLUME:/root/.cache/huggingface" -v "$R9700_GENCONFIG_WIN:/genconfig:ro" \
    "$R9700_IMAGE" sh -c "$_SERIES_PROBE_SH" sh "$R9700_MODEL_DIR" /genconfig
  rc=$?
  if [ "$rc" -ne 0 ]; then echo "series: the throwaway container failed (code $rc): ${answer%%$'\n'*}" >&2; return 2; fi
  if ! grep -qx -- '---' <<< "$answer"; then echo "series: the throwaway container did not answer with a model listing: ${answer%%$'\n'*}" >&2; return 2; fi
  listing="$(sed '/^---$/,$d' <<< "$answer")"
  genconfig="$(sed '1,/^---$/d' <<< "$answer")"
  while IFS= read -r line; do
    [[ -z $line || $line =~ ^.+\ [0-9]+$ ]] || { echo "series: the throwaway container did not answer with a model listing: $line" >&2; return 2; }
  done <<< "$listing"
  [ -n "$listing" ] || { echo "series: the model listing of $R9700_MODEL_DIR is empty (the throwaway container found no file)" >&2; return 2; }
  [ -n "$genconfig" ] || { echo "series: /genconfig holds no file (GENCONFIG_WIN $R9700_GENCONFIG_WIN)" >&2; return 2; }
  printf '%s\n' "$listing" > "$inputs/listing"
  printf '%s\n' "$genconfig" > "$inputs/genconfig"
}

# _series_write_inputs <inputs dir> <rounds> <probe yes|no> <arm>...: one file per component group (lib/fingerprint.py reads them; no JSON is built
# here). `no` leaves out the throwaway container (the model listing and the generation config): the worker's re-check takes those from the stored file.
_series_write_inputs() {
  local inputs="$1" rounds="$2" probe="$3" arm
  shift 3
  mkdir -p "$inputs/arms" || return 2
  config_resolved > "$inputs/config.env" || return 2
  for arm in "$@"; do
    arm_args "$arm" > "$inputs/arms/$arm.args" && arm_env "$arm" > "$inputs/arms/$arm.env" && arm_mounts "$arm" > "$inputs/arms/$arm.mounts" || return 2
  done
  _series_write_patches "$inputs/patches" "$@" || return 2
  printf 'harness_py %s\nbench_sh %s\nseries_sh %s\nserve_sh %s\n' "$(_series_hash_path "$_SERIES_LIB/harness.py")" "$(_series_hash_path "$_SERIES_LIB/bench.sh")" \
    "$(_series_hash_path "$_SERIES_LIB/series.sh")" "$(_series_hash_path "$_SERIES_LIB/serve.sh")" > "$inputs/tools"
  printf 'base=%s\nrounds=%s\nprefill_lens=%s\n' "$1" "$rounds" "$R9700_PREFILL_LENS" > "$inputs/series"
  [ "$probe" = no ] || _series_probe "$inputs"
}

# series_fingerprint <outdir> <rounds> <real|dry> <arm>...: the supervisor's half, before admission. `real`: build fingerprint.json, or compare with the
# stored one and merge the extensions (a new arm, more rounds). A new fingerprint is never built over records (rounds/ or rejected/ exist but the file
# does not: its identity is lost, and old records must not be taken for the result of a new configuration). `dry`: the same checks and the same
# lines, but NOTHING is written in the outdir (no fingerprint.json, no merge, not even the folder): a dry run must never change a series.
series_fingerprint() {
  local outdir="$1" rounds="$2" mode="$3" inputs rc=0 out stored
  shift 3
  stored="$outdir/fingerprint.json"
  if [ "$mode" = dry ]; then
    inputs="${RUN_DIR:?}/fingerprint-inputs"
  else
    if [ ! -f "$stored" ] && { [ -d "$outdir/rounds" ] || [ -d "$outdir/rejected" ]; }; then
      echo "series: $outdir has rounds/ or rejected/ but no fingerprint.json: the identity of those records is lost, so this series cannot be resumed; use a new --out name (or put the fingerprint.json back from a copy)" >&2
      return 2
    fi
    mkdir -p "$outdir" || { echo "series: the outdir $outdir cannot be made" >&2; return 2; }
    find "$outdir" -maxdepth 1 -type d -name '.fingerprint-inputs.part-*' -exec rm -rf {} + 2> /dev/null # what a killed earlier run left; ours, temporary
    inputs="$outdir/.fingerprint-inputs.part-${RUN_ID:-$$}"
  fi
  _series_write_inputs "$inputs" "$rounds" yes "$@" || rc=2
  if [ "$rc" -eq 0 ] && [ ! -f "$stored" ]; then
    if [ "$mode" = dry ]; then
      python3 "$_SERIES_LIB/fingerprint.py" build "$inputs" --out "$inputs/new.json" > /dev/null || rc=2
    else
      python3 "$_SERIES_LIB/fingerprint.py" build "$inputs" --out "$stored" > /dev/null || rc=2
    fi
  elif [ "$rc" -eq 0 ]; then
    python3 "$_SERIES_LIB/fingerprint.py" build "$inputs" --out "$inputs/new.json" > /dev/null || rc=2
    if [ "$rc" -eq 0 ]; then
      if [ "$mode" = dry ]; then out="$(python3 "$_SERIES_LIB/fingerprint.py" compare "$stored" "$inputs/new.json")"; else out="$(python3 "$_SERIES_LIB/fingerprint.py" compare --merge "$stored" "$inputs/new.json")"; fi
      rc=$?
      if [ "$rc" -eq 0 ]; then [ -z "$out" ] || printf '%s\n' "$out"; else printf '%s\n' "$out" >&2; rc=2; fi
    fi
  fi
  rm -rf "${inputs:?}"
  return "$rc"
}

# ---------- the commands of an arm-round, shared by the worker and the dry run ----------
# _series_serve_options <envs array> <mounts array> <serve args array> <arm>: the words of serve_start. The tuned MoE folder of the model comes
# first and the arm's own environment after it, so an arm that names its own folder wins (wslc takes the last -e of a name).
_series_serve_options() {
  local -n _so_env="$1" _so_mounts="$2" _so_args="$3"
  local word
  _so_env=()
  _so_mounts=()
  [ -z "$R9700_TUNED_CONFIG_DIR" ] || _so_env+=(-e "VLLM_TUNED_CONFIG_FOLDER=$R9700_TUNED_CONFIG_DIR")
  while read -r word; do [ -n "$word" ] && _so_env+=(-e "$word"); done < <(arm_env "$4")
  while read -r word; do [ -n "$word" ] && _so_mounts+=(-v "$word"); done < <(arm_mounts "$4")
  mapfile -t _so_args < <(arm_args "$4")
}

# _series_quality_words <array> <collect|gsm8k> <arm> <series>: what runs inside the container for the round-1 quality files
_series_quality_words() {
  local -n _qw="$1"
  local file=gsm8k
  [ "$2" = collect ] && file=prompts
  _qw=(python3 /work/r9700/harness.py "$2" --url http://127.0.0.1:8000 --model "$R9700_SERVED_NAME")
  [ "$2" = gsm8k ] && _qw+=(--data "$R9700_GSM8K_DATA" --n 200)
  _qw+=(--out "/work/r9700/$4/${file}_$3.json")
}

series_dry_run() {
  local outdir="$1" arm="$3" name len sub
  local -a envs=() mounts=() sargs=() words=()
  name="$(container_name "sp-$arm-1")" || return 2
  _series_serve_options envs mounts sargs "$arm"
  echo "dry-run: $(serve_start --print "$name" /dev/null "${envs[@]}" "${mounts[@]}" -- "${sargs[@]}")"
  echo "dry-run: bench c=1 r=1: $(bench_argv_text "$name" 1 1)"
  for len in $R9700_PREFILL_LENS; do echo "dry-run: prefill $len r=1: $(prefill_argv_text "$name" "$len" 1)"; done
  for sub in collect gsm8k; do
    _series_quality_words words "$sub" "$arm" "$(basename "$outdir")"
    echo "dry-run: quality $sub: $(wslc_argv_text exec "$name" "${words[@]}")"
  done
}

# ---------- before admission ----------
series_quality_sync() {
  local outdir="$1" file arm dest
  for file in "$outdir"/rounds/*-1/gsm8k_*.json; do
    [ -f "$file" ] || continue
    arm="${file##*/gsm8k_}"
    arm="${arm%.json}"
    dest="$outdir/quality/gsm8k_$arm.json"
    cmp -s "$file" "$dest" 2> /dev/null && continue
    mkdir -p "$outdir/quality" && cp "$file" "$dest.part" && mv -f "$dest.part" "$dest"
  done
  return 0
}

# series_preflight <outdir> <rounds> <arm>...: only when round 1 has an arm-round to run (the quality files come from round 1)
series_preflight() {
  local outdir="$1" rounds="$2" arm need=no file dest want got
  shift 2
  for arm in "$@"; do _series_final "$outdir" "$arm" 1 || _series_unsupported "$outdir" "$arm" || need=yes; done
  [ "$need" = yes ] || return 0
  if [[ $R9700_GSM8K_DATA == /work/* ]]; then
    file="$R9700_WORK_DIR/${R9700_GSM8K_DATA#/work/}"
    [ -f "$file" ] || { echo "series: GSM8K_DATA $R9700_GSM8K_DATA not found at $file" >&2; return 2; }
  else
    echo "series: GSM8K_DATA $R9700_GSM8K_DATA is not under /work, not checked"
  fi
  dest="$R9700_WORK_DIR/r9700/harness.py"
  mkdir -p "$R9700_WORK_DIR/r9700" && cp "$_SERIES_LIB/harness.py" "$dest.part" && mv -f "$dest.part" "$dest" || { echo "series: harness.py cannot be placed in $R9700_WORK_DIR/r9700" >&2; return 2; }
  want="$(python3 "$_SERIES_LIB/fingerprint.py" show "$outdir/fingerprint.json" tools.harness_py)" || return 2
  got="$(_series_hash_path "$dest")"
  [ "$want" = "$got" ] || { echo "series: $dest is not the harness of the fingerprint ($got, expected $want)" >&2; return 2; }
}

# ---------- the worker ----------
# _series_reject <outdir> <tag> <part dir> <reason text>: moves the directory to rejected/<tag>-<UTC stamp>[-<n>]/ and writes `reason`; prints the
# new path in _SERIES_REJECTED
_series_reject() {
  local outdir="$1" tag="$2" part="$3" reason="$4" dest n=1
  mkdir -p "$outdir/rejected" || return 1
  dest="$outdir/rejected/$tag-$(_series_stamp)"
  while [ -e "$dest" ]; do n=$((n + 1)); dest="$outdir/rejected/$tag-$(_series_stamp)-$n"; done
  mv -T "$part" "$dest" || return 1
  printf '%s\n' "$reason" > "$dest/reason"
  _SERIES_REJECTED="$dest"
}

# series_sweep_parts <outdir>: the crash recovery of the worker: whatever an earlier worker left as a part directory is evidence, never a record
series_sweep_parts() {
  local outdir="$1" dir name
  for dir in "$outdir"/rounds/*.part-*; do
    [ -d "$dir" ] || continue
    name="${dir##*/}"
    _series_reject "$outdir" "${name%%.part-*}" "$dir" "INTERRUPTED: $name was left by an earlier worker that did not finish it" && echo "series: $name moved to ${_SERIES_REJECTED#"$outdir"/}"
  done
}

# _series_gate <arm> <round>: before every arm-round. 0 go on; 1 the disk gate stopped (the outcome says so); 3 not quiet; 4 it no longer fits
_series_gate() {
  local arm="$1" round="$2" line allow
  if ! line="$(disk_gate_check "${R9700_RUN_DIR:?}/disk_gate.state")"; then
    outcome_write "${R9700_OUTCOME_FILE:?}" KIND=disk_gate RC=1 "DETAIL=$line"
    echo "$line"
    return 1
  fi
  if ! line="$(quiet_check)"; then echo "NOT QUIET: $arm round $round ($line)"; return 3; fi
  allow="$(t_scale "${R9700_ARM_SECONDS:-1500}")" || return 2
  if ! awk -v now="$(date +%s.%N 9>&-)" -v a="$allow" -v stop="${R9700_T_STOP:-}" 'BEGIN { exit !(stop == "" || now + a <= stop + 0) }' 9>&-; then
    echo "series: $(series_left "$_SERIES_OUT" "$_SERIES_ROUNDS" "${_SERIES_ARMS[@]}") arm-rounds no longer fit before the deadline"
    return 4
  fi
}

# _series_try_start <arm> <round> <name> <part>: one start of the arm's server; 0 ready
_series_try_start() {
  local -a envs=() mounts=() sargs=()
  _series_serve_options envs mounts sargs "$1"
  serve_start "$3" "$4/server.log" "${envs[@]}" "${mounts[@]}" -- "${sargs[@]}"
}

# _series_unsupported_mark <outdir> <arm> <round> <rejected 1> <rejected 2>: unsupported/<arm>-<stamp>.txt, whole or not at all
_series_unsupported_mark() {
  local outdir="$1" arm="$2" file
  mkdir -p "$outdir/unsupported" || return 1
  file="$outdir/unsupported/$arm-$(_series_stamp).txt"
  {
    echo "UNSUPPORTED: $arm did not start twice (round $3)"
    echo "attempt 1: ${4#"$outdir"/}"
    echo "attempt 2: ${5#"$outdir"/}"
    grep -E "Error|error:" "$5/server.log" 2> /dev/null | tail -n 3 | cut -c1-300
  } > "$file.part" && mv -f "$file.part" "$file"
}

# _series_deadline_came <outdir> <arm> <round> <part>: 0 (and the attempt moved to rejected/) when R9700_T_STOP has passed. In the minutes before the
# deadline watcher acts the adapter refuses every call, so a start "fails" for no fault of the arm: it is never retried and never marks the arm
# unsupported (that mark outlives the series).
_series_deadline_came() {
  [ -n "${R9700_T_STOP:-}" ] && [ "$(date +%s 9>&-)" -ge "$R9700_T_STOP" ] || return 1
  _series_reject "$1" "$2-$3" "$4" "INTERRUPTED: the deadline (T_STOP) came while ${_SERIES_NAME} was starting; the arm is not judged"
}

# _series_start_server <outdir> <arm> <round> <part>: two tries, 60 s apart (speed_A.sh lines 62-67); the second has a container name of its own and
# every failed try is kept in rejected/ with its log. 0 started (_SERIES_NAME), 5 the arm is unsupported now, 4 the deadline came, 2 the identity
# of the series changed before the second try, 1 a start the worker cannot record.
_series_start_server() {
  local outdir="$1" arm="$2" round="$3" part="$4" first rejected1
  _SERIES_NAME="$(container_name "sp-$arm-$round")" || return 1
  _series_try_start "$arm" "$round" "$_SERIES_NAME" "$part" && return 0
  wslc_stop "$_SERIES_NAME" > /dev/null 2>&1
  _series_deadline_came "$outdir" "$arm" "$round" "$part" && return 4
  _series_reject "$outdir" "$arm-$round" "$part" "UNSTARTED: $_SERIES_NAME did not become ready (try 1 of 2)" || return 1
  rejected1="$_SERIES_REJECTED"
  echo "RETRY: $_SERIES_NAME did not start; trying once more"
  sleep "$(t_scale 60)" 9>&-
  mkdir "$part" || return 1
  _series_recheck || { rmdir "$part" 2> /dev/null; return 2; } # the first try was a minute ago: the identity is checked before EVERY start try
  _SERIES_NAME="$(container_name "sp-$arm-$round-r2")" || return 1
  _series_try_start "$arm" "$round" "$_SERIES_NAME" "$part" && return 0
  wslc_stop "$_SERIES_NAME" > /dev/null 2>&1
  _series_deadline_came "$outdir" "$arm" "$round" "$part" && return 4
  _series_reject "$outdir" "$arm-$round" "$part" "UNSTARTED: $_SERIES_NAME did not become ready (try 2 of 2)" || return 1
  _series_unsupported_mark "$outdir" "$arm" "$round" "$rejected1" "$_SERIES_REJECTED" || return 1
  echo "UNSUPPORTED: $arm did not start twice"
  sleep "$(t_scale 20)" 9>&-
  return 5
}

# _series_measure <name> <tag> <series> <arm> <round> <part>: the measurements; the problems found go to _SERIES_PROBLEMS (one line each)
_series_measure() {
  local name="$1" tag="$2" series="$3" arm="$4" round="$5" part="$6" len rc sub target
  local -a words=()
  grep -E "$_SERIES_SERVER_CONFIG_RE" "$part/server.log" | cut -c1-240 | sort -u > "$part/server_config.txt"
  bench_run "$name" "$tag" > "$part/bench.txt" || _SERIES_PROBLEMS+=("bench: the bench run failed (code $?)")
  if [ "${#_SERIES_PROBLEMS[@]}" -eq 0 ]; then
    for len in $R9700_PREFILL_LENS; do
      prefill_run "$name" "$tag" "$len" >> "$part/bench.txt" || { _SERIES_PROBLEMS+=("bench: the prefill run $len failed (code $?)"); break; }
    done
  fi
  wslc_exec 60 "$name" python3 -c "$_SERIES_SPEC_PY" | grep -E '^vllm:spec_decode' | sed "s/^/$tag /" > "$part/spec_metrics.txt"
  [ "$round" = 1 ] && [ "${#_SERIES_PROBLEMS[@]}" -eq 0 ] || return 0
  _SERIES_QUALITY_RAN=yes
  mkdir -p "$R9700_WORK_DIR/r9700/$series" || { _SERIES_PROBLEMS+=("quality: $R9700_WORK_DIR/r9700/$series cannot be made"); return 0; }
  for sub in collect gsm8k; do
    _series_quality_words words "$sub" "$arm" "$series"
    wslc_exec 1800 "$name" "${words[@]}" > "$part/$sub.out" 2>&1 || { _SERIES_PROBLEMS+=("quality: $sub failed (code $?)"); return 0; }
    target="${words[-1]}"
    mv "$R9700_WORK_DIR/${target#/work/}" "$part/" || { _SERIES_PROBLEMS+=("quality: $sub left no file at $target"); return 0; }
  done
}

# _series_validate <name> <tag> <arm> <round> <part>: (a) check-block, (b) the container is still listed, (c) in round 1 the quality files,
# (d) server.log is not empty; the logs are saved once more first and the container is stopped. 0 the record may become final; else the
# reason is in _SERIES_REASON
_series_validate() {
  local name="$1" tag="$2" arm="$3" round="$4" part="$5" alive=0 out rc line
  _series_alive "$name" && alive=1
  if wslc_logs "$name" > "$part/server.log.new" 2> /dev/null && [ -s "$part/server.log.new" ]; then mv -f "$part/server.log.new" "$part/server.log"; else rm -f "$part/server.log.new"; fi
  wslc_stop "$name" > /dev/null 2>&1
  out="$(python3 "$_SERIES_LIB/verdict.py" check-block --tag "$tag" --prefill-lens "$R9700_PREFILL_LENS" "$part/bench.txt" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    while IFS= read -r line; do [ -n "$line" ] && _SERIES_PROBLEMS+=("check-block: ${line/missing: /missing }"); done <<< "$out"
  fi
  if [ "$_SERIES_QUALITY_RAN" = yes ] && [ "${#_SERIES_PROBLEMS[@]}" -eq 0 ]; then
    out="$(python3 "$_SERIES_LIB/fingerprint.py" check-quality "$part/prompts_$arm.json" "$part/gsm8k_$arm.json")" || while IFS= read -r line; do _SERIES_PROBLEMS+=("$line"); done <<< "$out"
  fi
  [ -s "$part/server.log" ] || _SERIES_PROBLEMS+=("server.log: empty")
  if [ "$alive" -eq 0 ]; then _SERIES_REASON="LOST: server alive 0"; else _SERIES_REASON="REJECTED: server alive 1"; fi
  [ "$alive" -eq 1 ] && [ "${#_SERIES_PROBLEMS[@]}" -eq 0 ] && return 0
  for line in "${_SERIES_PROBLEMS[@]}"; do _SERIES_REASON+=$'\n'"$line"; done
  return 1
}

_series_alive() { wslc_list 2> /dev/null | grep -Fxq -- "$1"; }

# _series_record_env <part> <arm> <round> <started>: record.env, the run identity of the record
_series_record_env() {
  local fp
  fp="$(python3 "$_SERIES_LIB/fingerprint.py" show "$_SERIES_OUT/fingerprint.json" sha256)"
  printf 'ARM=%s\nROUND=%s\nRUN_ID=%s\nCONTAINER=%s\nSTARTED_AT=%s\nFINGERPRINT=%s\nSERIES_SH=%s\n' "$2" "$3" "$RUN_ID" "$_SERIES_NAME" "$4" "$fp" \
    "$(python3 "$_SERIES_LIB/fingerprint.py" show "$_SERIES_OUT/fingerprint.json" tools.series_sh)" > "$1/record.env"
}

# _series_recheck: the identity of the series against fingerprint.json, at the start of EVERY arm-round, in the worker. The supervisor computed the
# fingerprint once, but one step can restart this worker many times, hours apart, and the worker re-reads arms.conf, re-sources lib/*.sh and the
# containers mount the patch files live: an edit in between would be measured under the old identity. The cheap components (config, arms, patches,
# tools) are built again; the throwaway container is not run (the listing and the generation config are taken from the stored file). A difference:
# the lines go to stdout and to the outcome (KIND=refused RC=2, which the supervisor reads as a refusal: exit 2, no retry), return 2.
_series_recheck() {
  local inputs="$_SERIES_OUT/.fingerprint-inputs.part-$RUN_ID-w" out rc=0 detail
  arms_load "$(series_arms_conf)" || return 2
  _series_write_inputs "$inputs" "$_SERIES_ROUNDS" no "${_SERIES_ARMS[@]}" || rc=2
  [ "$rc" -ne 0 ] || python3 "$_SERIES_LIB/fingerprint.py" build "$inputs" --out "$inputs/now.json" --probe-from "$_SERIES_OUT/fingerprint.json" > /dev/null || rc=2
  if [ "$rc" -eq 0 ]; then
    out="$(python3 "$_SERIES_LIB/fingerprint.py" compare "$_SERIES_OUT/fingerprint.json" "$inputs/now.json")"
    rc=$?
  else
    out="series: the identity of the series could not be re-checked"
  fi
  rm -rf "${inputs:?}"
  [ "$rc" -eq 0 ] && return 0
  printf '%s\n' "$out"
  detail="${out//$'\n'/; }"
  outcome_write "${R9700_OUTCOME_FILE:?}" KIND=refused RC=2 "DETAIL=$detail"
  return 2
}

# series_unit <arm> <round>: one arm-round. 0 go on (recorded, skipped or unsupported); else the worker's exit code
series_unit() {
  local arm="$1" round="$2" tag="$1-$2" part started rc series="${_SERIES_OUT##*/}"
  _series_final "$_SERIES_OUT" "$arm" "$round" && return 0
  _series_unsupported "$_SERIES_OUT" "$arm" && return 0
  _series_gate "$arm" "$round" || return $?
  _series_recheck || return 2
  part="$_SERIES_OUT/rounds/$tag.part-$RUN_ID"
  mkdir -p "$_SERIES_OUT/rounds" && mkdir "$part" || { echo "series: $part cannot be made"; return 1; }
  started="$(_series_iso)"
  echo "=== $started $arm round $round (load $(cut -d' ' -f1-3 "${R9700_LOADAVG_FILE:-/proc/loadavg}" 2> /dev/null))"
  _SERIES_PROBLEMS=()
  _SERIES_QUALITY_RAN=no
  _series_start_server "$_SERIES_OUT" "$arm" "$round" "$part"
  rc=$?
  [ "$rc" -eq 5 ] && return 0
  [ "$rc" -eq 4 ] && return 4
  [ "$rc" -eq 2 ] && return 2
  [ "$rc" -eq 0 ] || return 1
  _series_record_env "$part" "$arm" "$round" "$started"
  _series_measure "$_SERIES_NAME" "$tag" "$series" "$arm" "$round" "$part"
  if ! _series_validate "$_SERIES_NAME" "$tag" "$arm" "$round" "$part"; then
    _series_reject "$_SERIES_OUT" "$tag" "$part" "$_SERIES_REASON"
    echo "$_SERIES_REASON" | sed "s/^/$tag: /"
    return 1
  fi
  printf 'FINISHED_AT=%s\n' "$(_series_iso)" >> "$part/record.env"
  mv -T "$part" "$_SERIES_OUT/rounds/$tag" || { echo "series: $part cannot become $tag"; return 1; }
  series_quality_sync "$_SERIES_OUT"
  echo "recorded $tag"
  sleep "$(t_scale 10)" 9>&-
}

# series_main <outdir> <rounds> <arm>...: the worker
series_main() {
  local line rc round arm
  _SERIES_OUT="$1" _SERIES_ROUNDS="$2"
  shift 2
  _SERIES_ARMS=("$@")
  RUN_ID="$(basename "${R9700_RUN_DIR:?R9700_RUN_DIR is not set (run by the supervisor only)}")"
  arms_load "$(series_arms_conf)" || exit 2
  series_sweep_parts "$_SERIES_OUT"
  for ((round = 1; round <= _SERIES_ROUNDS; round++)); do
    for arm in "${_SERIES_ARMS[@]}"; do
      series_unit "$arm" "$round"
      rc=$?
      [ "$rc" -eq 0 ] || exit "$rc"
    done
  done
  if ! line="$(disk_gate_check "$R9700_RUN_DIR/disk_gate.state")"; then
    outcome_write "$R9700_OUTCOME_FILE" KIND=disk_gate RC=1 "DETAIL=$line"
    echo "$line"
    exit 1
  fi
  echo "series: every arm-round of this invocation is recorded"
}

# ---------- the verdict (decisions 4, 6 and 7) ----------
_series_fp() { python3 "$_SERIES_LIB/fingerprint.py" show "$1/fingerprint.json" "$2"; }

# series_verdict <outdir> [--base <arm>] [--no-quality] [--json <file>]
series_verdict() {
  local outdir="" base="" quality=yes json="" fp rounds lens sha arm round stamp file rc
  local -a fp_arms=() judged=() bench=() unsupported=() cmd=()
  while [ "$#" -gt 0 ]; do
    case $1 in
      --base) [ "$#" -ge 2 ] || { echo "r9700: verdict: --base needs a value" >&2; return 2; }; base="$2"; shift 2 ;;
      --json) [ "$#" -ge 2 ] || { echo "r9700: verdict: --json needs a value" >&2; return 2; }; json="$2"; shift 2 ;;
      --no-quality) quality=no; shift ;;
      -*) echo "r9700: verdict: unknown option \"$1\"; legal: --base <arm>, --no-quality, --json <file>" >&2; return 2 ;;
      *) [ -z "$outdir" ] || { echo "r9700: verdict: one outdir only (\"$outdir\" and \"$1\")" >&2; return 2; }; outdir="$1"; shift ;;
    esac
  done
  if [ ! -d "$outdir" ]; then echo "r9700: verdict: \"$outdir\" is not an outdir (a directory of series results)" >&2; return 2; fi
  fp="$outdir/fingerprint.json"
  [ -f "$fp" ] || { echo "r9700: verdict: $fp not found (is $outdir the outdir of a series?)" >&2; return 2; }
  [ -n "$base" ] || base="$(_series_fp "$outdir" base)" || return 2
  rounds="$(_series_fp "$outdir" rounds)" || return 2
  lens="$(_series_fp "$outdir" workload.prefill.lens)" || return 2
  sha="$(_series_fp "$outdir" sha256)" || return 2
  mapfile -t fp_arms < <(_series_fp "$outdir" arms)
  echo "series $outdir: base $base, $rounds rounds, fingerprint ${sha:0:12}"
  [ "$rounds" -ne 1 ] || echo "note: 1 round, 3 values per concurrency; the recorded ship test used 3 rounds (9)"
  for arm in "${fp_arms[@]}"; do
    if _series_unsupported "$outdir" "$arm"; then
      file="$(ls "$outdir"/unsupported/"$arm"-*.txt | LC_ALL=C sort | tail -n 1)"
      stamp="${file##*/$arm-}"
      echo "verdict $arm: UNSUPPORTED (did not start twice, ${stamp%.txt})"
      unsupported+=("$arm")
      [ "$arm" = "$base" ] && { echo "r9700: verdict: base arm $base is unsupported" >&2; return 2; }
    elif [ "$arm" != "$base" ]; then
      judged+=("$arm")
    fi
    for ((round = 1; round <= rounds; round++)); do [ -f "$outdir/rounds/$arm-$round/bench.txt" ] && bench+=(--bench "$outdir/rounds/$arm-$round/bench.txt"); done
  done
  if [ "${#bench[@]}" -eq 0 ]; then echo "r9700: verdict: base arm \"$base\" has no complete arm-round in the inputs" >&2; return 2; fi
  if [ "${#judged[@]}" -eq 0 ]; then echo "verdict: no arm besides the base to judge"; return 0; fi
  cmd=(python3 "$_SERIES_LIB/verdict.py" ship --base "$base")
  for arm in "${judged[@]}"; do cmd+=(--arm "$arm"); done
  cmd+=("${bench[@]}" --prefill-lens "$lens" --rounds "$rounds")
  if [ "$quality" = yes ]; then cmd+=(--gsm8k-dir "$outdir/quality"); else cmd+=(--no-quality); fi
  [ -z "$json" ] || cmd+=(--json "$json")
  echo "invoking: ${cmd[*]}"
  "${cmd[@]}"
}

# run as the worker only when executed, not when sourced
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -u
  for _series_lib in config run_guarded adapter serve wait_ready bench disk_gate guard_quiet; do
    # shellcheck source=/dev/null
    source "$_SERIES_LIB/$_series_lib.sh" || exit 2
  done
  series_main "$@"
fi
