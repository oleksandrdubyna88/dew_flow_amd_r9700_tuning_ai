#!/usr/bin/env bash
# Shared by tests/test_adapter.sh, tests/test_stubs.sh and tests/test_serve_bench.sh. Sourced, never run; no t_ function in it.
# It sources the libraries under test, so the test files need not (lib/run_guarded.sh defines t_scale, which run_all_tests no longer
# mistakes for a test: it runs only the functions defined in the test file itself).
#
#   setup_case <name> [<model file>]   a fresh folder, the stubs first on PATH, the scripted answers, the config loaded
#   log_args <stub> / log_count <stub> <word> / argv_of <stub> (sets ARGV and HDR) / pid_of <container> / pgrp_of <pid> / sid_of <pid>

# shellcheck source=lib/config.sh
source "$REPO/lib/config.sh"
# shellcheck source=lib/run_guarded.sh
source "$REPO/lib/run_guarded.sh"
# shellcheck source=lib/adapter.sh
source "$REPO/lib/adapter.sh"
# shellcheck source=lib/serve.sh
source "$REPO/lib/serve.sh"
# shellcheck source=lib/bench.sh
source "$REPO/lib/bench.sh"

FIXTURE="$HERE/fixtures/config/machine.env.in"
MODEL_35B="$REPO/models/qwen3.6-35b-a3b-gptq.env"
STUBS="$HERE/stubs"
CR=$'\r'

# wait_ready is part (b)'s; serve_start calls it by name, so this file stands in a double that records its arguments.
wait_ready() {
  printf '%s\n' "$*" >> "$CASE/wait_ready.calls"
  return "${DOUBLE_READY_RC:-0}"
}

# setup_case <name> [<model file>]: a fresh folder, the stubs first on PATH, the scripted answers, the config loaded.
setup_case() {
  CASE="$R9700_TEST_ROOT/$1"
  STUB="$CASE/stub"
  mkdir -p "$STUB/answers" "$CASE/work" "$CASE/patches/C" "$CASE/results"
  : > "$CASE/patches/C/auto_gptq.py"
  : > "$CASE/patches/C/gptq_utils.py"
  sed "s|@ROOT@|$CASE|g" "$FIXTURE" > "$CASE/machine.env"
  printf '8000\n' > "$STUB/answers/ram"
  printf '100\n' > "$STUB/answers/disk"
  printf 'ok\n' > "$STUB/answers/ready"
  # Sleeps run 100 times faster (as in the lifecycle tests); the adapter's ceilings only 10 times (amendment A10): a stub call takes 39 ms
  # idle and up to 227 ms under load, and a 0.3 s ceiling would be a flaky test. A test that wants a ceiling to fire sets R9700_CEILING_SCALE.
  export R9700_STUB_DIR="$STUB" R9700_TIME_SCALE=100 R9700_CEILING_SCALE=10
  PATH="$STUBS:$PATH"
  export PATH
  config_load "$CASE/machine.env" "${2:-$MODEL_35B}" || { echo "setup_case: config_load failed" >&2; exit 2; }
}

# log_args <stub>: the arguments of the LAST call of a stub as the call log shows them (one line, joined by single spaces)
log_args() {
  awk -v s="$1" '$3 == s { l = $0 } END { sub(/^[^ ]+ [^ ]+ [^ ]+ ?/, "", l); print l }' "$STUB/calls.log"
}

# log_count <stub> <word>: how many call lines of a stub contain <word> as a whole argument
log_count() {
  awk -v s="$1" -v w="$2" '$3 == s { for (i = 4; i <= NF; i++) if ($i == w) { n++; break } } END { print n + 0 }' "$STUB/calls.log"
}

# argv_of <stub>: the arguments of the last block of that stub in calls.argv, one array element each, in ARGV; HDR is the header line
argv_of() {
  local want="$1" line name in=0
  ARGV=()
  HDR=""
  while IFS= read -r line; do
    if [[ $line == '@@ '* ]]; then
      read -r _ _ name _ <<< "$line"
      if [ "$name" = "$want" ]; then in=1; ARGV=(); HDR="$line"; else in=0; fi
    elif [ "$in" = 1 ]; then
      ARGV+=("$line")
    fi
  done < "$STUB/calls.argv"
  if [ "${#ARGV[@]}" -gt 0 ] && [ -z "${ARGV[-1]}" ]; then unset 'ARGV[-1]'; fi
}

# pid_of <container> / pgrp_of <pid> / sid_of <pid>: fields 3 and 4 of /proc/<pid>/stat after the last ")" (process group, session)
pid_of() { local pid _t; read -r pid _t < "$STUB/containers/$1.pid"; echo "$pid"; }

pgrp_of() {
  local stat
  stat="$(cat "/proc/$1/stat")"
  stat="${stat##*) }"
  set -- $stat
  echo "$3"
}

sid_of() {
  local stat
  stat="$(cat "/proc/$1/stat")"
  stat="${stat##*) }"
  set -- $stat
  echo "$4"
}

