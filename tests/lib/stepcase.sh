#!/usr/bin/env bash
# Shared by tests/test_steps.sh, tests/test_guards.sh and tests/test_lifecycle.sh: the part (c) libraries, and helpers that wait for the
# stub worker and script the stub's answers while a supervisor runs. Sourced after tests/lib/lifecycle.sh; no t_ function in it.
#
#   step_setup <name>        lc_setup, plus the quiet defaults: one quiet check, a load file that says quiet, a time scale of 100
#   set_load <value>         the load file of this case
#   append_answer <name> <v> adds a line to answers/<name> (the stub's call k takes line k, the last repeats)
#   wait_for <file> [<n>]    waits (bounded: n * 0.1 s, default 100) for a file; 1 when it never appears
#   session_fixture          a worker stand-in: `setsid bash -c 'sleep 1000 & wait'`; sets SID, every member recorded for the killer
#   stub_container <name>    a running stub container
#   guard_dirs               RUN_DIR with steps/ and guard/, and the outcome and log paths of step 1 (OUTCOME, GLOG)
#   step_cfg KEY=VALUE...    appends lines to this case's machine.env (a variant of the fixture)
#   step_bg <args...>        `bin/r9700 step <args...>` in the background as a user runs it (the config variables of the test shell are
#                            not handed on); sets SUP, its pid; output in $CASE/sup.out and $CASE/sup.err
#   step_end [<seconds>]     waits (bounded, 60 s by default) for SUP; sets SRC (its exit code), SOUT and SERR
#   run_dir_of               the one run folder under RESULTS_DIR/runs (waits up to 10 s for it)
#   count_calls <stub> <word> lines of the call log of that stub that hold the word as an argument
#   stamp_of <regex>         the epoch stamp of the first call-log line matching the regex
#   stop_in <seconds>        an epoch second at least <seconds> from now: now + <seconds> rounded UP (never the floor of the start second)
#   prod_running             the operator's server runs (a stub container named vllm)

# shellcheck source=lib/guard_quiet.sh
source "$REPO/lib/guard_quiet.sh" 2> /dev/null
# shellcheck source=lib/disk_gate.sh
source "$REPO/lib/disk_gate.sh" 2> /dev/null
# shellcheck source=lib/guard_common.sh
source "$REPO/lib/guard_common.sh" 2> /dev/null
# shellcheck source=lib/guard_ram.sh
source "$REPO/lib/guard_ram.sh" 2> /dev/null
# shellcheck source=lib/guard_deadline.sh
source "$REPO/lib/guard_deadline.sh" 2> /dev/null
# shellcheck source=lib/wait_ready.sh
source "$REPO/lib/wait_ready.sh" 2> /dev/null
# shellcheck source=lib/step.sh
source "$REPO/lib/step.sh" 2> /dev/null

step_setup() {
  lc_setup "$1" "${2:-$MODEL_35B}"
  export R9700_QUIET_CHECKS=1 R9700_LOADAVG_FILE="$CASE/loadavg"
  printf '0.50 0.40 0.30 1/100 1\n' > "$CASE/loadavg"
}

set_load() { printf '%s 0.40 0.30 1/100 1\n' "$1" > "$CASE/loadavg"; }

append_answer() { printf '%s\n' "$2" >> "$STUB/answers/$1"; }

wait_for() {
  local i
  for i in $(seq 1 "${2:-100}"); do [ -e "$1" ] && return 0; sleep 0.1; done
  return 1
}

session_fixture() {
  local i pid
  setsid bash -c 'sleep 1000 < /dev/null > /dev/null 2>&1 & wait' < /dev/null > /dev/null 2>&1 &
  SID=$!
  disown "$SID"
  guard_pid "$SID" "session-$SID"
  for i in $(seq 1 50); do
    [ "$(session_pids "$SID" | wc -l)" -ge 2 ] && break
    sleep 0.1
  done
  for pid in $(session_pids "$SID"); do guard_pid "$pid" "member-$pid"; done
}

stub_container() { wslc run -d --rm --name "$1" img > /dev/null; }

guard_dirs() {
  RUN_DIR="$CASE/run"
  mkdir -p "$RUN_DIR/steps" "$RUN_DIR/guard"
  OUTCOME="$RUN_DIR/steps/1.outcome"
  GLOG="$RUN_DIR/steps/1.ram_guard.log"
}

step_cfg() { printf '%s\n' "$@" >> "$CASE/machine.env"; }

prod_running() { wslc run -d --rm --name vllm img > /dev/null; }

# stop_lines: how many `wslc stop` calls the call log holds (0 when nothing was called)
stop_lines() {
  [ -f "$STUB/calls.log" ] || { echo 0; return 0; }
  awk '$3 == "wslc" && $4 == "stop" { n++ } END { print n + 0 }' "$STUB/calls.log"
}

step_bg() {
  local -a drop=()
  local key
  while read -r key; do drop+=(-u "R9700_$key"); done < <(config_keys | awk '{ print $2 }')
  ( exec env "${drop[@]}" "$REPO/bin/r9700" step "$@" ) > "$CASE/sup.out" 2> "$CASE/sup.err" &
  SUP=$!
  guard_pid "$SUP" "supervisor-$SUP"
}

# step_end [<seconds>]: waits for the supervisor, at most 60 s by default (checked 10 times a second); a long chain says how long it may take (a starved CPU makes each of its steps slower)
step_end() {
  local i
  for i in $(seq 1 "$(( ${1:-60} * 10 ))"); do kill -0 "$SUP" 2> /dev/null || break; sleep 0.1; done
  if kill -0 "$SUP" 2> /dev/null; then kill -KILL "$SUP"; fi
  wait "$SUP" 2> /dev/null
  SRC=$?
  SOUT="$(cat "$CASE/sup.out")"
  SERR="$(cat "$CASE/sup.err")"
}

run_dir_of() {
  local i dir
  for i in $(seq 1 100); do
    for dir in "$R9700_RESULTS_DIR"/runs/*/; do
      [ -d "$dir" ] && { printf '%s\n' "${dir%/}"; return 0; }
    done
    sleep 0.1
  done
  return 1
}

count_calls() { log_count "$1" "$2"; }

stamp_of() { awk -v re="$1" '$0 ~ re { print $1; exit }' "$STUB/calls.log"; }

stop_in() { awk -v n="$(date +%s.%N)" -v s="$1" 'BEGIN { t = n + s; i = int(t); print (t > i ? i + 1 : i) }'; }
