#!/usr/bin/env bash
# The marker's key COMFY_CONTAINER (RM1) and the three optional arguments of ready_wait (AW6), E1.S2. A separate file because tests/test_restore.sh would pass the
# file-size limit. Every test body is a function t_<guarantee>; each runs in its own subshell and writes only below $R9700_TEST_ROOT.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"
# shellcheck source=tests/lib/lifecycle.sh
source "$HERE/lib/lifecycle.sh"

# RM1
t_the_marker_records_the_comfy_container_and_a_marker_without_it_still_reads() {
  lc_setup "$FUNCNAME"
  assert_exit 0 "marker_write_base" -- marker_write_base "$MARKER_FILE" run-9 yes "$CASE/run"
  marker_read "$MARKER_FILE"
  assert_eq "comfyui" "${MARKER[COMFY_CONTAINER]:-}" "the marker records COMFY_CONTAINER"
  assert_eq "run-9" "${MARKER[RUN_ID]}" "and the rest is as it was"
  assert_exit 0 "marker_add_worker" -- marker_add_worker "$MARKER_FILE" 4242 98765
  marker_read "$MARKER_FILE"
  assert_eq "comfyui" "${MARKER[COMFY_CONTAINER]:-}" "marker_add_worker keeps it"
  assert_eq "4242" "${MARKER[WORKER_PGID]}" "next to the worker keys"
  write_marker
  assert_exit 0 "a hand-written marker without the key reads" -- marker_read "$MARKER_FILE"
  assert_eq "unset" "${MARKER[COMFY_CONTAINER]-unset}" "and the key is unset (an older marker has no check)"
  write_marker COMFY_CONTAINER=comfyui
  assert_exit 0 "a hand-written marker with the key reads" -- marker_read "$MARKER_FILE"
  assert_eq "comfyui" "${MARKER[COMFY_CONTAINER]}" "and holds it"
  write_marker COMFY_CONTAINER=Bad
  assert_exit 2 "COMFY_CONTAINER=Bad in a hand-written marker is refused" -- marker_read "$MARKER_FILE"
  assert_contains "$ERR" "marker: $MARKER_FILE:12: COMFY_CONTAINER:" "naming the file, the line and the key"
}

# holder_named <verb> <lock file name>: a process that holds that lock file of the state directory (exec'd sleep, so its pid is the holder's); sets HOLDER
holder_named() {
  ( lock_take "$1" "$2" || exit 1; : > "$CASE/held-$2"; exec sleep 30 ) &
  HOLDER=$!
  disown "$HOLDER"
  guard_pid "$HOLDER" "holder-$HOLDER"
  local i
  for i in $(seq 1 100); do [ -e "$CASE/held-$2" ] && return 0; sleep 0.1; done
  return 1
}

# FL1
t_lock_take_takes_a_named_lock_file_of_the_state_directory_and_the_default_is_unchanged() {
  lc_setup "$FUNCNAME"
  local line bad
  holder_named comfy-fetch comfy-fetch.lock
  read -r line < "$R9700_STATE_DIR/comfy-fetch.lock"
  if [[ $line =~ ^$HOLDER\ comfy-fetch\ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$ ]]; then assert_eq ok ok "comfy-fetch.lock holds <pid> comfy-fetch <time>"; else assert_eq "$HOLDER comfy-fetch <time>" "$line" "comfy-fetch.lock holds <pid> comfy-fetch <time>"; fi
  assert_exit 4 "a second taker of the same file is refused" -- lock_take comfy-fetch comfy-fetch.lock
  local since="${line##* }"
  assert_eq "r9700: another run holds $R9700_STATE_DIR/comfy-fetch.lock: pid $HOLDER, comfy-fetch, since $since" "$ERR" "its line names the file, the pid, the verb and the time"
  holder_named step lock
  assert_exit 0 "meanwhile the GPU lock was taken by another process: the two files are two locks" -- test -f "$R9700_STATE_DIR/lock"
  read -r line < "$R9700_STATE_DIR/lock"
  assert_contains "$line" "$HOLDER step" "the GPU lock's holder line is the step's"
  kill -KILL "$HOLDER"
  for bad in "a/b" ".hidden" "-x" "" "../lock" "a b" "lock/"; do
    assert_exit 2 "lock_take with the name [$bad] is refused" -- lock_take x "$bad"
    assert_eq "lock_take: \"$bad\" is not a lock file name" "$ERR" "[$bad] one line"
  done
  assert_eq "comfy-fetch.lock lock" "$(ls "$R9700_STATE_DIR" | grep -v '^restore' | tr '\n' ' ' | sed 's/ $//')" "no file was made for a refused name"
  assert_exit 0 "one argument: the default file lock is free again" -- lock_take step
  read -r line < "$R9700_STATE_DIR/lock"
  assert_contains "$line" " step " "and holds the line of its taker"
}

# a probe double: prints what the test scripted in $CASE/probe.words, one word per line
probe_double() { cat "$CASE/probe.words"; }

# AW6
t_ready_wait_takes_a_probe_a_ready_word_and_a_line_prefix_and_keeps_its_defaults() {
  lc_setup "$FUNCNAME"
  wslc_run vllm img > /dev/null
  printf 'x\nready\n' > "$CASE/probe.words"
  assert_exit 0 "a probe that prints x then ready" -- ready_wait vllm 60 probe_double ready "r9700: comfy: start:"
  assert_eq "x
ready" "$READY_ANSWER" "READY_ANSWER is the two lines"
  [[ $READY_ELAPSED_S =~ ^[0-9]+$ ]] && assert_eq ok ok "READY_ELAPSED_S is a whole number" || assert_eq "<digits>" "$READY_ELAPSED_S" "READY_ELAPSED_S is a whole number"
  assert_eq "" "$ERR" "nothing on stderr"
  printf 'x\nnope\n' > "$CASE/probe.words"
  assert_exit 5 "a probe that prints x then nope" -- ready_wait vllm 60 probe_double ready "r9700: comfy: start:"
  assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "one stderr line"
  assert_contains "$ERR" "r9700: comfy: start: vllm not ready after " "it starts with the caller's prefix"
  assert_eq "$ERR" "r9700: comfy: start: $READY_LINE" "READY_LINE is that line without the prefix"
  assert_contains "$READY_LINE" "(nope)" "and names the last answer"
  assert_eq "" "$READY_ANSWER" "READY_ANSWER is empty when the wait failed"
  [[ $READY_ELAPSED_S =~ ^[0-9]+$ ]] && assert_eq ok ok "READY_ELAPSED_S is set on failure too" || assert_eq "<digits>" "$READY_ELAPSED_S" "READY_ELAPSED_S is set on failure too"
  assert_exit 5 "the prefix - prints no line" -- ready_wait vllm 60 probe_double ready -
  assert_eq "" "$ERR" "no stderr line"
  assert_contains "$READY_LINE" "vllm not ready after " "and READY_LINE is still set"
  # the defaults: the restore's probe, the word completion and the prefix r9700: restore:
  printf 'ok\n' > "$STUB/answers/ready"
  assert_exit 0 "the default probe and word" -- ready_wait vllm 60
  assert_eq "models
completion" "$READY_ANSWER" "READY_ANSWER holds the restore probe's two lines"
  printf 'fail\n' > "$STUB/answers/ready"
  assert_exit 5 "the default prefix" -- ready_wait vllm 60
  assert_contains "$ERR" "r9700: restore: vllm not ready after " "is r9700: restore:"
  kill_recorded_pids "$CASE"
}

t_a_restore_with_the_server_already_listed_beside_comfyui_starts_nothing_and_says_nothing_false() {
  lc_setup "$FUNCNAME"
  write_marker COMFY_CONTAINER=comfyui
  wslc_run comfyui img > /dev/null
  wslc_run vllm img > /dev/null
  mkdir -p "$CASE/run"
  assert_exit 0 "restore_from_marker with the server and ComfyUI both listed" -- restore_from_marker "$MARKER_FILE" "$CASE/run"
  assert_not_contains "$ERR" "not started" "no line claims the server was not started"
  assert_eq "0" "$(log_count pwsh.exe -Detach)" "nothing was started"
  assert_missing "$MARKER_FILE" "the marker is gone: the server runs"
  kill_recorded_pids "$CASE"
}

run_all_tests
