#!/usr/bin/env bash
# The shared part of the CI stubs (wslc, powershell.exe, pwsh.exe, worker.sh). SOURCED by them, never run. Found through the real
# path of the stub, so a symbolic link to a stub works.
#
# A stub reads and writes only below $R9700_STUB_DIR (the test sets it inside its R9700_TEST_ROOT); with it unset or empty the
# stub exits 99 at once, so a stub can never run against a real machine by accident. Files below it:
#   calls.log      append-only, one line per call: <epoch.ns> <n> <stub> <argv words joined by single spaces>
#   calls.argv     one block per call: "@@ <n> <stub> <path the stub was started by>", one line per argument, a blank line
#   answers/<x>    scripted answers, written by the test BEFORE the call (ram, disk, ready: call k takes line k, the last repeats)
#   containers/<name>.pid   a stub container: "<pid> <start ticks>" of a real `setsid sleep` (amendment A4)
#   mode           `hang` makes every call sleep (to prove the adapter's ceilings); the sleeper is recorded in hung/containers.
#                  `hang-ignore-term` the same, but the stub and its sleeper ignore TERM (to prove --kill-after).
#                  `eat-stdin` makes every call read its standard input to the end (to prove the adapter never hands its caller's input on)
#   stop-delay-<name>  seconds `wslc stop <name>` sleeps before it stops the container (a slow stop, for a test that interrupts one)
#   counters/<x>   the call counters

STUB_HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=tests/lib/assert.sh
source "$STUB_HERE/../lib/assert.sh"

if [ -z "${R9700_STUB_DIR:-}" ]; then
  echo "stub: R9700_STUB_DIR unset" >&2
  exit 99
fi
# The stub directory is made by the test and removed by the runner; a stub never makes it or a parent of it (a stub that outlives its
# run would otherwise bring a removed run folder back). Its own subfolders are made with a plain `mkdir`, which fails without the parent.
if [ ! -d "$R9700_STUB_DIR" ]; then
  echo "stub: R9700_STUB_DIR is not a directory: $R9700_STUB_DIR" >&2
  exit 99
fi

# stub_mkdir <folder>...: a plain mkdir; a missing parent ends the stub (the run folder is gone)
stub_mkdir() {
  local dir
  for dir in "$@"; do
    [ -d "$dir" ] || mkdir "$dir" 2> /dev/null || [ -d "$dir" ] || exit 99
  done
}

# stub_record_pid <file> <pid>: "<pid> <start ticks>" like record_pid, but its folders are made without their parents
stub_record_pid() {
  stub_mkdir "$(dirname "$(dirname "$1")")" "$(dirname "$1")"
  printf '%s %s\n' "$2" "$(_start_ticks "$2")" > "$1" 2> /dev/null || exit 99
}

# stub_next <counter>: prints 1, 2, 3, ... one number per call, atomically (flock on calls.lock)
stub_next() {
  local file="$R9700_STUB_DIR/counters/$1" n=0
  [ -d "$R9700_STUB_DIR/counters" ] || mkdir "$R9700_STUB_DIR/counters" 2> /dev/null || [ -d "$R9700_STUB_DIR/counters" ] || return 99
  (
    flock 8
    [ -f "$file" ] && read -r n < "$file"
    n=$((n + 1))
    printf '%s\n' "$n" > "$file"
    printf '%s\n' "$n"
  ) 8>> "$R9700_STUB_DIR/calls.lock"
}

# stub_log <stub name> <argv...>: appends the call to calls.log and calls.argv (a newline inside an argument is written as <LF>)
stub_log() {
  local name="$1" n arg joined="" block
  shift
  n="$(stub_next calls)" || exit 99
  for arg in "$@"; do joined+="${joined:+ }${arg//$'\n'/<LF>}"; done
  block="@@ $n $name $0"$'\n'
  for arg in "$@"; do block+="${arg//$'\n'/<LF>}"$'\n'; done
  (
    flock 8
    printf '%s %s %s%s\n' "$(date +%s.%N)" "$n" "$name" "${joined:+ $joined}" >> "$R9700_STUB_DIR/calls.log"
    printf '%s\n' "$block" >> "$R9700_STUB_DIR/calls.argv"
  ) 8>> "$R9700_STUB_DIR/calls.lock"
}

# stub_hang: sleeps 1000 s and records the sleeper (the caller's ceiling is what ends it); also the answer word `hang` of answers/ready.
# stub_mode_if_asked: the test-scripted misbehaviour of the `mode` file. `hang` sleeps 1000 s; the sleeper is recorded so a test can prove
# that the caller's ceiling killed it. `eat-stdin` reads standard input to its end.
stub_hang() {
  sleep 1000 > /dev/null 2>&1 &
  stub_record_pid "$R9700_STUB_DIR/hung/containers/$(stub_next hung || echo 0).pid" "$!"
  wait "$!"
}

stub_mode_if_asked() {
  local mode=""
  [ -f "$R9700_STUB_DIR/mode" ] && mode="$(cat "$R9700_STUB_DIR/mode")"
  case $mode in
    hang) stub_hang ;;
    hang-ignore-term)
      # the stub itself (record 1) and its sleeper (record 2) ignore TERM; an ignored signal stays ignored across exec. `timeout` sends the
      # KILL of --kill-after to the stub (its direct child) only, so the sleeper is left for the test's own cleanup.
      trap '' TERM
      stub_record_pid "$R9700_STUB_DIR/hung/containers/$(stub_next hung || echo 0).pid" "$$"
      sleep 1000 > /dev/null 2>&1 &
      stub_record_pid "$R9700_STUB_DIR/hung/containers/$(stub_next hung || echo 0).pid" "$!"
      wait "$!"
      ;;
    eat-stdin) cat > /dev/null ;;
  esac
}

# stub_answer <name>: prints the next line of answers/<name> (call k takes line k, the last line repeats) without a trailing CR; exits 99
# when the test scripted nothing
stub_answer() {
  local file="$R9700_STUB_DIR/answers/$1" k
  if [ ! -f "$file" ]; then
    echo "stub: answers/$1 missing" >&2
    exit 99
  fi
  k="$(stub_next "answer-$1")"
  awk -v k="$k" 'NR == k { line = $0; found = 1 } { last = $0 } END { out = found ? line : last; sub(/\r$/, "", out); print out }' "$file"
}

# stub_alive <pid file>: 0 while the recorded process is running (same pid, same start ticks, not a zombie)
stub_alive() {
  local pid ticks stat
  [ -f "$1" ] || return 1
  { read -r pid ticks < "$1"; } 2> /dev/null || return 1
  [ -n "$pid" ] && [ -n "$ticks" ] && [ "$(_start_ticks "$pid")" = "$ticks" ] || return 1
  stat="$(cat "/proc/$pid/stat" 2> /dev/null)" || return 1
  stat="${stat##*) }"
  [ "${stat%% *}" != Z ]
}

# stub_container_start <name>: a container is a real process outside the caller's group, exactly like the real one: `setsid sleep`,
# no inherited descriptor (a held pipe would hang the caller's $(...))
stub_container_start() {
  local file="$R9700_STUB_DIR/containers/$1.pid" pid
  stub_mkdir "$R9700_STUB_DIR/containers" # before the process starts: with the run folder gone, no process may be left behind
  setsid sleep 1000 < /dev/null > /dev/null 2>&1 &
  pid=$!
  stub_record_pid "$file" "$pid"
  if ! stub_alive "$file"; then
    echo "stub: the container process did not start" >&2
    exit 1
  fi
}

# stub_require_running <name>: the real wslc refuses exec and logs on a container that is not running
stub_require_running() {
  stub_alive "$R9700_STUB_DIR/containers/$1.pid" && return 0
  echo "stub: container not running: $1" >&2
  return 1
}

# stub_container_stop <name>: TERM, then waits until the process is gone; 1 when there was no such running container
stub_container_stop() {
  local file="$R9700_STUB_DIR/containers/$1.pid" pid _ticks i
  if ! stub_alive "$file"; then
    echo "stub: no such running container: $1" >&2
    return 1
  fi
  read -r pid _ticks < "$file"
  kill -TERM "$pid" 2> /dev/null
  for i in $(seq 1 30); do stub_alive "$file" || break; sleep 0.1; done
  # A container started during a cleanup phase (the restore) inherits the ignored TERM of the supervisor's cleanup, as any child of a shell
  # that ran `trap '' TERM` does: stopping it takes the KILL, as `wslc stop` ends a container that does not leave in time.
  stub_alive "$file" && kill -KILL "$pid" 2> /dev/null
  for i in $(seq 1 30); do stub_alive "$file" || break; sleep 0.1; done
  rm -f "$file"
}
