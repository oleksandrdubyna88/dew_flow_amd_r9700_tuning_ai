#!/usr/bin/env bash
# Shared by tests/test_comfy_bench.sh, tests/test_comfy_bench_evidence.sh and tests/test_comfy_bench_identity.sh (E2.S2): "a stub bench" of the ComfyUI arm-round and the helpers that read what
# it left. Sourced after tests/lib/assert.sh, stubcase.sh and lifecycle.sh; no t_ function in it. It builds on tests/lib/comfycase.sh (the stub world of the ComfyUI verb) and sources lib/comfy_bench.sh.
#
#   bench_setup <name>      comfy_setup, the quiet defaults of a step, the operator's server running, a non-empty log answer, bench.py placed where the containers see it, a run folder for the
#                           fingerprint's calls and the outdir OUTD (BWORK is the exchange root the containers see as /work/r9700/comfyui/bench)
#   bench_fp <workflow> <rounds> <arm>...   the supervisor's half before admission: comfy_bench_check, then comfy_bench_fingerprint (real)
#   cbp <workflow> <rounds> <arm>...        the worker as ONE step under `bin/r9700 step` (the verb `comfy bench` is E2.S3's); cb is bench_fp then cbp (SRC, SOUT, SERR); cb_bg the same in the background
#   newout <name> / knobs KEY=VALUE... / hook_stop <container> <script>   another outdir; lines of this case's machine.env; a script the stub runs when that container is stopped
#   rec <tag> <file> / reject_of <tag> / reason_of <tag> / wlog / bench_names / stops / call_line <regex> / last_call_line <regex> / tree_hash <dir> / env_val <file> <KEY> / listed <name>
#   argv_of_bench <tag> / has_pair <w1> <w2> / has_word <w>   the argument array of a bench container's run call and two scans of it
#   assert_match <text> <regex> <name>

# shellcheck source=tests/lib/comfycase.sh
source "$HERE/lib/comfycase.sh"
# shellcheck source=lib/comfy_bench.sh
source "$REPO/lib/comfy_bench.sh"

# bench_setup <name>: the stub world of a ComfyUI bench: the quiet defaults of a step, the operator's server running, the three volumes of the operator's ComfyUI (the bench cache volume is NOT
# there: the worker makes it), bench.py placed where the containers see it, a run folder for the fingerprint's calls, and the outdir $OUTD
bench_setup() {
  comfy_setup "$1"
  export R9700_QUIET_CHECKS=1 R9700_LOADAVG_FILE="$CASE/loadavg"
  printf '0.50 0.40 0.30 1/100 1\n' > "$CASE/loadavg"
  prod_running
  RUN_DIR="$CASE/fprun"
  mkdir -p "$RUN_DIR"
  OUTD="$R9700_RESULTS_DIR/cb"
  BWORK="$R9700_WORK_DIR/r9700/comfyui/bench"
  printf 'INFO stub server line 1\nINFO stub server line 2\n' > "$STUB/answers/logs" # a log is never empty: a container that wrote nothing is a fault the validation names
  local _MOE_PLACED_BY=comfy
  moe_place comfy_bench_assets
}

# bench_fp <workflow> <rounds> <arm>...: the supervisor's half before admission (the verb's): the checks (which load both tables), then the fingerprint, real
bench_fp() { comfy_bench_check "$@" && comfy_bench_fingerprint "$OUTD" "$1" "$2" real "${@:3}"; }

# cbp <workflow> <rounds> <arm>...: the worker as ONE step, as the verb will start it
cbp() { r9700 step --model "$MODEL_35B" comfy-bench -- bash "$REPO/lib/comfy_bench.sh" "$OUTD" "$@"; }

# cb <workflow> <rounds> <arm>...: the fingerprint, then the step; the result of the step in SRC, SOUT, SERR
cb() {
  bench_fp "$@" > "$CASE/fp.out" 2> "$CASE/fp.err" || { SRC=$?; SOUT="$(cat "$CASE/fp.out")"; SERR="$(cat "$CASE/fp.err")"; return "$SRC"; }
  cbp "$@" > "$CASE/sup.out" 2> "$CASE/sup.err"
  SRC=$?
  SOUT="$(cat "$CASE/sup.out")"
  SERR="$(cat "$CASE/sup.err")"
  return "$SRC"
}

# cb_bg <workflow> <rounds> <arm>...: the same in the background (SUP; then step_end)
cb_bg() {
  local -a drop=()
  local key
  bench_fp "$@" > /dev/null 2>&1 || return 1
  while read -r key; do drop+=(-u "R9700_$key"); done < <(config_keys | awk '{ print $2 }')
  ( exec env "${drop[@]}" "$REPO/bin/r9700" step --model "$MODEL_35B" comfy-bench -- bash "$REPO/lib/comfy_bench.sh" "$OUTD" "$@" ) > "$CASE/sup.out" 2> "$CASE/sup.err" &
  SUP=$!
  guard_pid "$SUP" "supervisor-$SUP"
}

# bench_names: the names of the detached bench containers the call log shows, in order (not the operator's server)
bench_names() { awk '$3 == "wslc" && $4 == "run" && $5 == "-d" { for (i = 6; i <= NF; i++) if ($i == "--name" && $(i + 1) != "vllm") { print $(i + 1); break } }' "$STUB/calls.log"; }

# wlog: the lines every worker start of the newest run wrote (the step log: the worker's stdout)
wlog() { cat "$(last_run_dir)"/steps/*.worker.log 2> /dev/null; }

# rec <tag> <file>: a file of a final record
rec() { printf '%s/rounds/%s/%s\n' "$OUTD" "$1" "$2"; }

env_val() { sed -n "s/^$2=//p" "$1" | head -n 1; }

# rejects: the rejected/ folders (sorted names)
rejects() { ls "$OUTD/rejected" 2> /dev/null; }

# reject_of <tag>: the folder of the (first) rejected attempt of the tag
reject_of() { ls -d "$OUTD"/rejected/"$1"-* 2> /dev/null | head -n 1; }

# alive_now <container>: the container is listed now
listed() { wslc list | tr -d '\r' | awk 'NR > 1 { print $NF }' | grep -Fxq -- "$1"; }


# newout <name>: another outdir for the same test (a rejected attempt of one scenario must not be the history of the next)
newout() { OUTD="$R9700_RESULTS_DIR/$1"; }

# knobs <KEY=VALUE>...: lines of this case's machine.env (a key is set once per file)
knobs() { step_cfg "$@"; }

# argv_of_bench <tag>: ARGV of the last `wslc run` call that names the container of the tag
argv_of_bench() { _argv_of_call run "${R9700_CONTAINER_PREFIX}comfy-$1"; }

# has_pair <word> <next word>: the ARGV holds the two words in a row, each a whole word; has_word <word>
has_pair() { local i; for ((i = 0; i + 1 < ${#ARGV[@]}; i++)); do [ "${ARGV[$i]}" = "$1" ] && [ "${ARGV[$i + 1]}" = "$2" ] && return 0; done; return 1; }
has_word() { local w; for w in "${ARGV[@]}"; do [ "$w" = "$1" ] && return 0; done; return 1; }

# stops: the targets of every `wslc stop` call, in order
stops() { awk '$3 == "wslc" && $4 == "stop" { print $5 }' "$STUB/calls.log"; }

# call_line <regex>: the number of the first call-log line that matches (empty when none)
call_line() { grep -nE -- "$1" "$STUB/calls.log" | head -n 1 | cut -d: -f1; }

# last_call_line <regex>
last_call_line() { grep -nE -- "$1" "$STUB/calls.log" | tail -n 1 | cut -d: -f1; }

# tree_hash <dir>: one hash of every file below a folder (names and contents)
tree_hash() { (cd "$1" && find . -type f | LC_ALL=C sort | xargs sha256sum | sha256sum | cut -c1-64); }

# hook <container> <script text>: the stub runs the script once that container has been stopped (on-stop-<name>)
hook_stop() { printf '%s\n' "$2" > "$STUB/on-stop-$1"; }

# reason_of <tag>: the reason file of the first rejected attempt of the tag
reason_of() { cat "$(reject_of "$1")/reason" 2> /dev/null; }


# assert_match <text> <regex> <name>: an extended regular expression matches the whole text
assert_match() {
  if [[ $1 =~ $2 ]]; then _assert_pass "$3"; else _assert_fail "$3" "text:    [$1]" "pattern: [$2]"; fi
}
