#!/usr/bin/env bash
# `bin/r9700 comfy guard` (CW1-CW5) and `bin/r9700 comfy timeline` (CW6-CW9) of lib/comfy_watch.sh, through bin/r9700 as a user runs them, against the stub world of
# tests/lib/comfycase.sh: Windows' available MBytes come from $STUB/answers/ram (call k takes line k, the last repeats), the container log from $STUB/answers/logs
# (an on-logs hook may change it between calls). Every test body is a function t_<guarantee>; each runs in its own subshell and writes only below $R9700_TEST_ROOT.
# The sleeps run at R9700_TIME_SCALE=100 (a 5 s tick is 0.05 s); --max-s is real seconds, so the ceilings below are small.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"
# shellcheck source=tests/lib/lifecycle.sh
source "$HERE/lib/lifecycle.sh"
# shellcheck source=tests/lib/comfycase.sh
source "$HERE/lib/comfycase.sh"
# shellcheck source=lib/comfy_watch.sh
source "$REPO/lib/comfy_watch.sh"

# the counts read the call log through cat, so a log that does not exist yet (no call made) counts 0, never an empty string
stops_of() { cat "$STUB/calls.log" 2> /dev/null | grep -c " wslc stop $1\$"; }
ram_reads() { cat "$STUB/calls.log" 2> /dev/null | grep -c "Available MBytes"; }

# ---- comfy guard (CW1-CW5) ----------------------------------------------------------------------------------------------------------------------------

# CW1
t_a_read_below_the_limit_stops_the_listed_comfyui_and_the_guard_keeps_watching() {
  comfy_setup "$FUNCNAME"
  comfy_listed
  printf '9000\n2000\n9000\n' > "$STUB/answers/ram"
  assert_exit 0 "comfy guard ends at its ceiling" -- comfy guard --max-s 2
  assert_eq "1" "$(stops_of comfyui)" "exactly one stop, at the one low read"
  assert_contains "$OUT" "comfy: guard: on: comfyui is stopped below 6000 MB available" "the first line says what it watches"
  assert_contains "$OUT" "GUARD STOP: available 2000 MB < 6000 MB — comfyui stopped" "the stop line names the read and the limit"
  assert_eq "" "$ERR" "nothing on stderr"
  # from here on: assert_exit replaces OUT and ERR with the output of its own command
  assert_exit 0 "it read again after the stop (the cool-down is 0.6 s at scale 100)" -- test "$(ram_reads)" -ge 3
  assert_exit 1 "comfyui is stopped" -- alive comfyui
}

# CW2
t_three_unreadable_reads_in_a_row_stop_comfyui_and_two_followed_by_a_good_read_do_not() {
  comfy_setup "$FUNCNAME"
  comfy_listed
  printf 'garbage\ngarbage\n9000\n' > "$STUB/answers/ram"
  assert_exit 0 "two misses, then good reads" -- comfy guard --max-s 1
  assert_eq "0" "$(stops_of comfyui)" "two misses do not stop it"
  assert_contains "$OUT" "telemetry unreadable (2 of 3)" "each miss is counted aloud"
  assert_exit 0 "comfyui still runs" -- alive comfyui
  printf 'garbage\n' > "$STUB/answers/ram"
  assert_exit 0 "only misses" -- comfy guard --max-s 1
  assert_contains "$OUT" "GUARD STOP: telemetry unreadable 3 times — comfyui stopped" "three misses are unsafe: nothing counts an unreadable value as fine"
  assert_eq "1" "$(stops_of comfyui)" "one stop"
}

# CW3
t_a_low_read_while_comfyui_is_not_listed_stops_nothing_and_says_so() {
  comfy_setup "$FUNCNAME"
  printf '2000\n' > "$STUB/answers/ram"
  assert_exit 0 "comfy guard" -- comfy guard --max-s 1
  assert_contains "$OUT" "available 2000 MB < 6000 MB; comfyui is not running" "the line says why nothing was stopped"
  assert_eq "0" "$(calls_of_verb stop)" "no stop call"
}

# CW4
t_a_bad_argument_is_refused_with_one_line_before_any_read() {
  comfy_setup "$FUNCNAME"
  printf '9000\n' > "$STUB/answers/ram"
  local args
  for args in "--min-mb abc" "--min-mb 0" "--max-s -1" "--until" "--bogus 1"; do
    # shellcheck disable=SC2086 # the words of each case are meant to split
    assert_exit 2 "[$args]" -- comfy guard $args
    assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "[$args] one stderr line"
    assert_contains "$ERR" "r9700: comfy: guard: " "[$args] names the mode"
  done
  assert_contains "$ERR" "legal: --min-mb <n> --until <file> --max-s <s>" "an unknown argument names the legal ones"
  assert_eq "0" "$(ram_reads)" "no read was made"
}

# CW5
t_the_guard_ends_at_its_ceiling_or_at_its_file_and_reads_again_at_its_tick() {
  comfy_setup "$FUNCNAME"
  printf '9000\n' > "$STUB/answers/ram"
  assert_exit 0 "comfy guard" -- comfy guard --min-mb 4000 --max-s 2
  assert_contains "$OUT" "comfy: guard: off: the ceiling of 2 s" "the ceiling ends it"
  assert_contains "$OUT" "available 9000 MB" "the first read is printed"
  # 8 reads were seen in one second on an idle machine (2026-11-10); 2 seconds and at least 3 leave room for a loaded CI runner
  assert_exit 0 "several reads at the scaled 5 s tick" -- test "$(ram_reads)" -ge 3
  : > "$CASE/queue-done"
  assert_exit 0 "comfy guard with its file already there" -- comfy guard --until "$CASE/queue-done" --max-s 20
  assert_contains "$OUT" "comfy: guard: off: $CASE/queue-done exists" "a queue script ends it by making the file"
}

# CW10
t_a_stop_that_fails_is_tried_again_at_the_next_tick_and_the_guard_ends_with_1_saying_it_did_not_hold() {
  comfy_setup "$FUNCNAME"
  comfy_listed
  printf '100\n' > "$STUB/stop-fail-comfyui" # every stop of the run fails (the stub's count)
  printf '2000\n' > "$STUB/answers/ram"
  assert_exit 1 "comfy guard" -- comfy guard --max-s 3
  assert_contains "$ERR" "available 2000 MB < 6000 MB; the stop of comfyui failed (code 1): stub: stop failed (scripted): comfyui" "the failed stop is one line with the engine's text"
  assert_contains "$ERR" "r9700: comfy: guard: a stop of comfyui failed during this run (the lines above): the guard did not hold" "the end says the guard did not hold"
  assert_contains "$OUT" "comfy: guard: off: the ceiling of 3 s" "the off line still comes"
  # last: assert_exit replaces OUT and ERR with the output of its own command. A failed stop is retried at the next tick, not after the cool-down: measured
  # 2026-11-10 in 3 s, 9 attempts this way and 3 with the cool-down after a failed stop; 6 parts the two with room for a loaded runner
  assert_exit 0 "it tried again at the next tick" -- test "$(stops_of comfyui)" -ge 6
  assert_exit 0 "comfyui is still listed (no stop worked)" -- alive comfyui
  kill_recorded_pids "$CASE"
}

# ---- comfy timeline (CW6-CW9)-------------------------------------------------------------------------------------------------------------------------

# on_logs <lines per call...>: an on-logs hook that appends the k-th argument's lines (joined by `|`) to the log at the k-th call
on_logs() {
  local i=0 batch
  : > "$STUB/answers/logs"
  for batch in "$@"; do
    i=$((i + 1))
    printf '%s\n' "${batch//|/$'\n'}" > "$STUB/batch-$i"
  done
  cat > "$STUB/on-logs-comfyui" << EOF
n=\$(( \$(cat "$STUB/logs-calls" 2> /dev/null || echo 0) + 1 ))
printf '%s\n' "\$n" > "$STUB/logs-calls"
[ -f "$STUB/batch-\$n" ] && cat "$STUB/batch-\$n" >> "$STUB/answers/logs"
exit 0
EOF
}

# CW6
t_each_new_log_line_is_written_once_with_its_utc_time_and_the_timeline_ends_at_the_marker() {
  comfy_setup "$FUNCNAME"
  comfy_listed
  on_logs $'\e[32m[INFO]\e[0m Requested to load WanTEModel|loaded' "Sampling 1/2" "Prompt executed in 12.3 seconds|after"
  assert_exit 0 "comfy timeline" -- comfy timeline --out "$CASE/timeline.log" --max-s 20
  assert_contains "$OUT" "comfy: timeline: done: a line contains \"Prompt executed\"" "it ends at the marker"
  assert_eq 4 "$(wc -l < "$CASE/timeline.log" | tr -d ' ')" "four lines: each new line once, nothing after the marker"
  assert_eq "0" "$(grep -cvE '^[0-9]{2}:[0-9]{2}:[0-9]{2}Z ' "$CASE/timeline.log")" "every line starts with a UTC time"
  assert_eq "1" "$(grep -c 'Requested to load WanTEModel' "$CASE/timeline.log")" "a line seen in an earlier read is not written again"
  assert_not_contains "$(cat "$CASE/timeline.log")" $'\e' "the colour codes are removed"
}

# CW7
t_a_log_that_gets_shorter_is_a_restarted_container_and_is_read_from_its_start() {
  comfy_setup "$FUNCNAME"
  comfy_listed
  printf 'one\ntwo\nthree\n' > "$STUB/answers/logs"
  cat > "$STUB/on-logs-comfyui" << EOF
n=\$(( \$(cat "$STUB/logs-calls" 2> /dev/null || echo 0) + 1 ))
printf '%s\n' "\$n" > "$STUB/logs-calls"
[ "\$n" -eq 3 ] && printf 'fresh\nPrompt executed\n' > "$STUB/answers/logs"
exit 0
EOF
  assert_exit 0 "comfy timeline" -- comfy timeline --max-s 20
  assert_contains "$OUT" "comfy: timeline: the log got shorter: comfyui restarted; reading it from its start" "the restart is named"
  assert_contains "$OUT" "Z fresh" "the new log's first line is written"
}

# CW8
t_three_failed_log_reads_end_the_timeline_with_1_and_one_line() {
  comfy_setup "$FUNCNAME"
  assert_exit 1 "comfy timeline with comfyui not running" -- comfy timeline --max-s 20
  assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "one stderr line"
  assert_contains "$ERR" "r9700: comfy: timeline: the log of comfyui could not be read 3 times in a row (code" "it names the reads"
}

# CW9
t_the_timeline_ends_with_1_at_its_ceiling_when_no_line_has_the_marker_and_a_bad_argument_is_2() {
  comfy_setup "$FUNCNAME"
  comfy_listed
  printf 'loading\n' > "$STUB/answers/logs"
  assert_exit 1 "comfy timeline" -- comfy timeline --until "never there" --max-s 1
  assert_contains "$ERR" "the ceiling of 1 s: no line contained \"never there\"" "the ceiling is named with the marker"
  assert_exit 2 "an unknown argument" -- comfy timeline --bogus
  assert_contains "$ERR" "legal: --out <file> --until <text> --max-s <s>" "names the legal ones"
}

run_all_tests
