#!/usr/bin/env bash
# bin/r9700 as a user runs it, for the verbs commands, init, and verdict as the restore-first shell (E1.S2 part (b); the verdict itself is E1.S3's). The scenarios L1-L22
# of the story are marked in each test name; the ones that drive the `step` verb (L1-L3, L11-L14, L19, L22, the bad-label half of L20, the
# TERM half of L8, the real L21) are tests/test_step.sh. Every test body is a function t_<guarantee>; each runs in its own subshell and writes
# only below $R9700_TEST_ROOT. Nothing under tests/stubs is started except through the stubs on PATH and tests/lib/fake_supervisor.sh.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"
# shellcheck source=tests/lib/lifecycle.sh
source "$HERE/lib/lifecycle.sh"
# shellcheck source=tests/lib/stepcase.sh
source "$HERE/lib/stepcase.sh"

wait_file() { local i; for i in $(seq 1 100); do [ -e "$1" ] && return 0; sleep 0.1; done; return 1; }
boot_id() { cat /proc/sys/kernel/random/boot_id; }

# ---- L1 (init form): a refused config stops nothing ---------------------------------------------------------------------------------------

t_l1_an_invalid_config_is_refused_before_any_server_is_stopped() {
  lc_setup "$FUNCNAME"
  printf 'DISK_GATE=maybe\n' >> "$CASE/machine.env"
  prod_running
  wslc run -d --rm --name r9700tune-old img > /dev/null
  assert_exit 2 "init with DISK_GATE=maybe" -- r9700 init --model "$MODEL_35B"
  assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "one stderr line"
  assert_contains "$ERR" "config: " "a config: line"
  assert_contains "$ERR" "DISK_GATE" "naming the field"
  assert_eq "0" "$(stop_lines)" "the call log has no stop line"
  assert_exit 0 "the operator's server still runs" -- test -f "$STUB/containers/vllm.pid"
  assert_eq "r9700tune-old vllm" "$(wslc_list | sort | tr '\n' ' ' | sed 's/ $//')" "and so does the leftover (init stops it only after the config is accepted)"
  kill_recorded_pids "$CASE"
}

# ---- the model is resolved AFTER the restore; only the syntax of the arguments is checked before the lock ------------------------------------------

t_init_without_a_model_and_two_files_in_models_still_restores_first_and_then_refuses() {
  lc_setup "$FUNCNAME"
  write_marker PROD_WAS_RUNNING=no
  assert_exit 2 "init with a marker and no --model (two example models)" -- r9700 init
  assert_contains "$ERR" "--model" "refused for the missing model"
  assert_missing "$MARKER_FILE" "but the restore ran first and finished"
  write_marker PROD_WAS_RUNNING=no
  assert_exit 2 "init with a marker and a model that is not there" -- r9700 init --model nosuch
  assert_contains "$ERR" 'model "nosuch"' "refused for that model"
  assert_missing "$MARKER_FILE" "the restore ran first here too"
}

t_init_refuses_a_bad_argument_before_the_lock_and_the_restore() {
  lc_setup "$FUNCNAME"
  write_marker
  assert_exit 2 "an unknown argument" -- r9700 init --frobnicate
  assert_exit 2 "--model without a value" -- r9700 init --model
  assert_exit 0 "the marker is untouched: a syntax error never starts a restore" -- test -f "$MARKER_FILE"
  assert_missing "$STUB/calls.log" "nothing was called"
  assert_missing "$R9700_STATE_DIR/lock" "and no lock was taken"
}

# ---- a corrupt marker: its own exit code and the remedy -----------------------------------------------------------------------------------------------

t_a_corrupt_marker_stops_the_invocation_with_exit_11_and_names_the_remedy() {
  lc_setup "$FUNCNAME"
  write_marker EXTRA=1
  assert_exit 11 "init with a marker that cannot be read" -- r9700 init --model "$MODEL_35B"
  assert_contains "$ERR" "marker: $MARKER_FILE:" "the line that says what is wrong"
  assert_contains "$ERR" "check the operator's server by hand, then remove $MARKER_FILE" "the remedy"
  assert_exit 0 "the marker is kept" -- test -f "$MARKER_FILE"
  assert_missing "$STUB/calls.log" "nothing was called"
  assert_exit 11 "verdict the same" -- r9700 verdict "$CASE"
  assert_contains "$ERR" "then remove $MARKER_FILE" "with the remedy"
  assert_exit 0 "and the lock is not held afterwards" -- flock -n "$R9700_STATE_DIR/lock" true
}

# ---- init prunes the restore folders -----------------------------------------------------------------------------------------------------------------

t_init_keeps_the_newest_ten_restore_folders_and_removes_only_older_ones_by_exact_name() {
  lc_setup "$FUNCNAME"
  local i
  for i in $(seq 1 13); do
    mkdir "$R9700_STATE_DIR/restore-run$i"
    : > "$R9700_STATE_DIR/restore-run$i/a.tail.log"
    touch -d "2026-10-$(printf '%02d' "$i") 10:00:00" "$R9700_STATE_DIR/restore-run$i"
  done
  mkdir "$R9700_STATE_DIR/restore" "$R9700_STATE_DIR/restore-" "$R9700_STATE_DIR/other-1" "$R9700_STATE_DIR/restore-has space"
  : > "$R9700_STATE_DIR/restore-afile"
  touch -d "2020-01-01 10:00:00" "$R9700_STATE_DIR/restore" "$R9700_STATE_DIR/other-1" "$R9700_STATE_DIR/restore-afile" "$R9700_STATE_DIR/restore-has space" "$R9700_STATE_DIR/restore-"
  assert_exit 0 "init" -- r9700 init --model "$MODEL_35B"
  assert_eq "10" "$(ls -d "$R9700_STATE_DIR"/restore-run* | wc -l | tr -d ' ')" "ten run folders are left"
  assert_missing "$R9700_STATE_DIR/restore-run1" "the oldest is gone"
  assert_missing "$R9700_STATE_DIR/restore-run3" "so is the third oldest"
  assert_exit 0 "the fourth oldest stays (the newest ten: 4..13)" -- test -d "$R9700_STATE_DIR/restore-run4"
  assert_exit 0 "the newest stays" -- test -d "$R9700_STATE_DIR/restore-run13"
  assert_exit 0 "a folder named plain restore is not ours to remove" -- test -d "$R9700_STATE_DIR/restore"
  assert_exit 0 "restore- with no id is not a run folder" -- test -d "$R9700_STATE_DIR/restore-"
  assert_exit 0 "a name with a space is not a run folder" -- test -d "$R9700_STATE_DIR/restore-has space"
  assert_exit 0 "an unrelated folder stays" -- test -d "$R9700_STATE_DIR/other-1"
  assert_exit 0 "a file stays" -- test -f "$R9700_STATE_DIR/restore-afile"
}

# ---- L4, L5 (restore-first form): a restore that is not ready exits 5, one stderr line, marker kept -----------------------------------------

t_l4_a_restore_that_never_becomes_ready_stops_the_invocation_with_exit_5() {
  lc_setup "$FUNCNAME"
  write_marker
  printf 'fail\n' > "$STUB/answers/ready"
  assert_exit 5 "init after a marker whose restore never gets ready" -- r9700 init --model "$MODEL_35B"
  assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "exactly one stderr line"
  if [[ $ERR =~ ^r9700:\ restore:\ vllm\ not\ ready\ after\ [0-9]+\ s\ \( ]]; then assert_eq ok ok "r9700: restore: vllm not ready after <n> s ("; else assert_eq "r9700: restore: vllm not ready after <n> s (" "$ERR" "r9700: restore: vllm not ready after <n> s ("; fi
  assert_exit 0 "the marker exists" -- test -f "$MARKER_FILE"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "exactly one start (no second start on a loading server)"
  assert_not_contains "$OUT" "init:" "init went no further"
  kill_recorded_pids "$CASE"
}

t_l5_a_server_that_answers_models_but_not_a_completion_is_not_ready() {
  lc_setup "$FUNCNAME"
  write_marker
  printf 'models-only\n' > "$STUB/answers/ready"
  assert_exit 5 "init" -- r9700 init --model "$MODEL_35B"
  assert_contains "$ERR" "completion: HTTP 500)" "the stderr line ends with the failing check"
  kill_recorded_pids "$CASE"
}

# ---- decision 4: lock, then restore, then config ----------------------------------------------------------------------------------------------

t_decision_4_the_restore_runs_before_the_config_is_read_so_a_broken_config_cannot_block_it() {
  lc_setup "$FUNCNAME"
  write_marker
  printf 'DISK_GATE=maybe\n' >> "$CASE/machine.env"
  assert_exit 2 "init with a marker and a broken config" -- r9700 init --model "$MODEL_35B"
  assert_contains "$ERR" "DISK_GATE" "the config error is reported (exit 2, as in S1)"
  assert_missing "$MARKER_FILE" "but the restore ran first and finished"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the server was started once"
  kill_recorded_pids "$CASE"
}

t_decision_4_the_lock_comes_before_the_restore_two_invocations_never_restore_at_once() {
  lc_setup "$FUNCNAME"
  ( exec 9> "$R9700_STATE_DIR/lock"; flock -n 9; : > "$CASE/held"; exec sleep 30 ) &
  local holder=$!
  disown "$holder"
  guard_pid "$holder" "holder-$holder"
  wait_file "$CASE/held"
  write_marker
  assert_exit 4 "init with a marker while another run holds the lock" -- r9700 init --model "$MODEL_35B"
  assert_exit 0 "the marker is untouched" -- test -f "$MARKER_FILE"
  assert_missing "$STUB/calls.log" "nothing was called"
  kill -KILL "$holder"
}

# ---- L6: a hard kill of the supervisor leaves the marker; the next invocation of any verb restores first ------------------------------------------

t_l6_a_hard_kill_leaves_the_marker_and_the_next_verb_restores_first() {
  lc_setup "$FUNCNAME"
  prod_running
  fake_supervisor run || return
  local worker child
  assert_exit 0 "the marker exists while the supervisor runs" -- test -f "$MARKER_FILE"
  marker_read "$MARKER_FILE"
  worker="${MARKER[WORKER_PGID]}"
  child="$(cat "$STUB/child.pid")"
  assert_eq "$(boot_id)" "${MARKER[BOOT_ID]}" "BOOT_ID is the machine's"
  assert_exit 0 "the worker pid named in the marker is a live process" -- kill -0 "$worker"
  assert_exit 1 "no descriptor 9 in the worker: the lock stays with the supervisor (amendment A1)" -- test -e "/proc/$worker/fd/9"
  assert_exit 0 "the supervisor itself holds descriptor 9" -- test -e "/proc/$SUP/fd/9"
  assert_exit 0 "the stub server was stopped at admission" -- test ! -f "$STUB/containers/vllm.pid"
  assert_exit 0 "the gate file is the step's own (amendment A14)" -- test -f "$SUP_DIR/run/steps/1.gate"
  assert_missing "$SUP_DIR/gate" "not a shared name"
  kill -KILL "$SUP"
  gone "$SUP"
  assert_exit 0 "the worker outlives the supervisor" -- kill -0 "$worker"
  assert_exit 0 "and so does its child" -- kill -0 "$child"
  assert_exit 0 "the lock is free after the SIGKILL (amendment A1)" -- flock -n "$R9700_STATE_DIR/lock" true
  assert_exit 0 "the marker is still there" -- test -f "$MARKER_FILE"
  assert_eq "$worker" "${MARKER[WORKER_PGID]}" "naming the worker"
  assert_exit 2 "verdict on a folder that is no outdir" -- r9700 verdict "$CASE/nodir"
  local verdict_out="$OUT" verdict_err="$ERR" # the next assertions overwrite $OUT and $ERR
  assert_eq "r9700: recovery marker found (run ${MARKER[RUN_ID]}), restoring first" "$(printf '%s\n' "$verdict_out" | head -n 1)" "its first stdout line"
  assert_exit 0 "the worker is gone" -- gone "$worker"
  assert_exit 0 "and its child" -- gone "$child"
  assert_exit 0 "the operator's server is back" -- test -f "$STUB/containers/vllm.pid"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the start script ran once"
  assert_contains "$verdict_err" "nodir" "the verb's own argument check ran AFTER the restore, and named the folder"
  kill_recorded_pids "$CASE"
}

# ---- L7: a reused pid is not killed -----------------------------------------------------------------------------------------------------------------

t_l7_a_marker_whose_worker_pid_was_reused_is_not_killed() {
  lc_setup "$FUNCNAME"
  setsid sleep 1000 < /dev/null > /dev/null 2>&1 &
  local sleeper=$!
  disown "$sleeper"
  guard_pid "$sleeper" "sleeper-$sleeper"
  write_marker "WORKER_PGID=$sleeper" "WORKER_START_TICKS=1" "BOOT_ID=$(boot_id)"
  assert_exit 0 "init" -- r9700 init --model "$MODEL_35B"
  assert_exit 0 "the sleep is still alive" -- kill -0 "$sleeper"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the restore ran"
  assert_missing "$MARKER_FILE" "the marker is gone"
  kill -KILL "$sleeper"
  kill_recorded_pids "$CASE"
}

# ---- L8 (lock half): a second invocation is refused while the lock is held, naming the holder ------------------------------------------------

t_l8_a_second_invocation_is_refused_while_the_lock_is_held_naming_the_holder() {
  lc_setup "$FUNCNAME"
  prod_running
  fake_supervisor run || return
  local before
  before="$(stop_lines)"
  assert_exit 4 "init while a run holds the lock" -- r9700 init --model "$MODEL_35B"
  if [[ $ERR =~ ^r9700:\ another\ run\ holds\ $R9700_STATE_DIR/lock:\ pid\ $SUP,\ step,\ since\ [0-9T:Z-]+$ ]]; then assert_eq ok ok "r9700: another run holds <state>/lock: pid <pid>, step, since <time>"; else assert_eq "r9700: another run holds <state>/lock: pid $SUP, step, since <time>" "$ERR" "the refusal"; fi
  assert_eq "$before" "$(stop_lines)" "the second invocation stopped nothing"
  assert_exit 4 "the same for verdict while a marker exists" -- r9700 verdict "$CASE"
  assert_exit 0 "commands needs no lock" -- r9700 commands
  kill -KILL "$SUP"
  kill -KILL -- "-$(cat "$STUB/child.pid" > /dev/null; awk '{ print $1 }' "$STUB"/workers/containers/worker-*.pid | head -n 1)" 2> /dev/null
  kill_recorded_pids "$CASE"
}

# ---- L9: verdict takes the lock only to restore -----------------------------------------------------------------------------------------------------

t_l9_verdict_takes_the_lock_only_to_restore() {
  lc_setup "$FUNCNAME"
  ( exec 9> "$R9700_STATE_DIR/lock"; flock -n 9; : > "$CASE/held"; exec sleep 30 ) &
  local holder=$!
  disown "$holder"
  guard_pid "$holder" "holder-$holder"
  wait_file "$CASE/held"
  write_marker
  assert_exit 4 "(a) a marker and a lock held elsewhere: verdict must restore first and cannot" -- r9700 verdict "$CASE"
  rm "$MARKER_FILE"
  mkdir "$CASE/empty"
  assert_exit 2 "(b) no marker and the lock held: verdict reaches its own argument check" -- r9700 verdict "$CASE/nodir"
  assert_contains "$ERR" "$CASE/nodir" "the line names the folder"
  assert_exit 2 "(b) an existing folder that is no series outdir: the verdict stops with its own line" -- r9700 verdict "$CASE/empty"
  assert_contains "$ERR" "fingerprint.json not found" "naming the missing file"
  kill -KILL "$holder"
}

t_l9_verdict_releases_the_lock_as_soon_as_the_restore_is_done_not_at_the_end_of_the_process() {
  lc_setup "$FUNCNAME"
  write_marker PROD_WAS_RUNNING=no
  # verb_verdict ends in `exit`; the EXIT trap looks at descriptor 9 at that moment: it must be closed already
  ( source "$REPO/bin/r9700"; trap 'if [ -e /proc/$BASHPID/fd/9 ]; then echo held > "$CASE/fd9"; else echo free > "$CASE/fd9"; fi' EXIT; verb_verdict "$CASE/nodir" ) > /dev/null 2>&1
  assert_eq "free" "$(cat "$CASE/fd9")" "descriptor 9 was closed before the verb went on"
  assert_missing "$MARKER_FILE" "(the restore did run)"
}

t_l9_verdict_without_a_marker_never_creates_state_and_a_restore_releases_the_lock_before_the_verb_goes_on() {
  lc_setup "$FUNCNAME"
  rmdir "$R9700_STATE_DIR"
  assert_exit 2 "verdict without a marker" -- r9700 verdict "$CASE/nodir"
  assert_missing "$R9700_STATE_DIR" "no state directory was made: nothing needed the lock"
  mkdir "$R9700_STATE_DIR"
  write_marker PROD_WAS_RUNNING=no
  assert_exit 2 "verdict with a marker" -- r9700 verdict "$CASE/nodir"
  assert_missing "$MARKER_FILE" "restored first"
  assert_exit 0 "the lock was released before the verb went on" -- flock -n "$R9700_STATE_DIR/lock" true
}

# ---- L10 (restore form): a server that was not running is not started by the restore --------------------------------------------------------------

t_l10_a_server_that_was_not_running_is_not_started_by_the_restore() {
  lc_setup "$FUNCNAME"
  write_marker PROD_WAS_RUNNING=no
  wslc run -d --rm --name r9700tune-old img > /dev/null
  assert_exit 0 "init" -- r9700 init --model "$MODEL_35B"
  assert_eq "0" "$(grep -c ' pwsh.exe ' "$STUB/calls.log")" "no start script call"
  assert_eq "0" "$(grep -c ' wslc stop vllm' "$STUB/calls.log")" "no stop of vllm"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_contains "$OUT" "init: vllm: not running" "init reports the server as not running"
  kill_recorded_pids "$CASE"
}

# ---- L15-L17: init -----------------------------------------------------------------------------------------------------------------------------------

t_l15_init_reports_every_check_and_stops_only_the_leftover_prefixed_containers() {
  lc_setup "$FUNCNAME"
  prod_running
  wslc run -d --rm --name r9700tune-old img > /dev/null
  wslc run -d --rm --name other-x img > /dev/null
  local other_pid
  other_pid="$(pid_of other-x)"
  assert_exit 0 "init" -- r9700 init --model "$MODEL_35B"
  assert_contains "$OUT" "init: config: ok" "config"
  assert_contains "$OUT" "init: results dir: ok" "results dir"
  assert_contains "$OUT" "init: state dir: ok" "state dir"
  assert_contains "$OUT" "init: wslc: ok" "wslc"
  assert_contains "$OUT" "init: ram telemetry: ok (8000 MB)" "ram"
  assert_contains "$OUT" "init: disk telemetry: ok (record 100)" "disk"
  assert_contains "$OUT" "init: vllm: running" "the server"
  assert_contains "$OUT" "init: leftover containers: stopped r9700tune-old" "the leftover"
  assert_eq "1" "$(grep -c ' wslc stop r9700tune-old' "$STUB/calls.log")" "the leftover was stopped"
  assert_eq "0" "$(grep -c ' wslc stop other-x' "$STUB/calls.log")" "the foreign container was not"
  assert_exit 0 "the foreign container is alive" -- kill -0 "$other_pid"
  assert_exit 0 "init made the results directory" -- test -d "$CASE/results"
  assert_eq "" "$ERR" "nothing on stderr"
  kill_recorded_pids "$CASE"
}

t_l15_init_with_nothing_to_clean_and_the_disk_gate_off() {
  lc_setup "$FUNCNAME"
  printf 'DISK_GATE=off\n' >> "$CASE/machine.env"
  assert_exit 0 "init" -- r9700 init --model "$MODEL_35B"
  assert_contains "$OUT" "init: leftover containers: none" "none"
  assert_contains "$OUT" "init: vllm: not running" "the server is not running"
  assert_contains "$OUT" "init: disk telemetry: skipped (DISK_GATE=off)" "no disk call is made"
  assert_eq "0" "$(grep -c 'Get-WinEvent' "$STUB/calls.log")" "no Get-WinEvent in the call log"
}

t_l16_init_fails_loudly_when_the_adapter_is_unreachable() {
  lc_setup "$FUNCNAME"
  sed -i 's|^WSLC=.*|WSLC=/nonexistent/wslc|' "$CASE/machine.env"
  PATH="/usr/bin:/bin" assert_exit 10 "init without stubs on PATH and a wslc that is not there" -- r9700 init --model "$MODEL_35B"
  assert_contains "$OUT" "init: wslc: " "stdout has the line"
  assert_contains "$ERR" "init: wslc: " "and so has stderr"
  assert_contains "$ERR" "/nonexistent/wslc" "naming the problem"
}

t_l17_init_finds_unreadable_telemetry() {
  lc_setup "$FUNCNAME"
  printf 'garbage\n' > "$STUB/answers/ram"
  assert_exit 10 "init" -- r9700 init --model "$MODEL_35B"
  assert_contains "$OUT" 'init: ram telemetry: unreadable ("garbage")' "the line"
  assert_contains "$ERR" 'init: ram telemetry: unreadable ("garbage")' "also on stderr"
  assert_contains "$OUT" "init: wslc: ok" "the other checks still ran"
}

t_g13_init_reports_a_hung_adapter_call_after_its_ceiling() {
  lc_setup "$FUNCNAME"
  printf 'hang\n' > "$STUB/mode"
  export R9700_CEILING_SCALE=100
  local started ended
  started="$(date +%s.%N)"
  assert_exit 10 "init against a hung wslc" -- r9700 init --model "$MODEL_35B"
  ended="$(date +%s.%N)"
  assert_contains "$OUT" "init: wslc: timeout after 1 s" "the line"
  assert_exit 0 "init ended within about 60 s / 100 + the other hung calls" -- awk -v a="$started" -v b="$ended" 'BEGIN { exit !(b - a < 12) }'
  local file pid
  for file in "$STUB"/hung/containers/*.pid; do
    [ -e "$file" ] || continue
    read -r pid _ < "$file"
    assert_exit 0 "no hung stub is left (pid file $(basename "$file"))" -- gone "$pid"
  done
}

t_init_holds_the_lock_while_it_works_and_releases_it_at_the_end() {
  lc_setup "$FUNCNAME"
  assert_exit 0 "init" -- r9700 init --model "$MODEL_35B"
  assert_exit 0 "the lock is free again" -- flock -n "$R9700_STATE_DIR/lock" true
  assert_contains "$(cat "$R9700_STATE_DIR/lock")" " init " "the last holder line was init's"
}

t_init_resolves_the_model_by_file_by_name_or_by_the_only_file_and_refuses_the_rest() {
  lc_setup "$FUNCNAME"
  assert_exit 0 "a model by bare name" -- r9700 init --model qwen3.6-35b-a3b-gptq
  assert_exit 2 "a name that is not in models/" -- r9700 init --model nosuch
  assert_contains "$ERR" 'model "nosuch"' "the line names it"
  assert_exit 2 "no model, and two files in models/" -- r9700 init
  assert_contains "$ERR" "--model" "the line says how to name one"
  assert_exit 2 "an unknown argument" -- r9700 init --frobnicate
  assert_contains "$ERR" "legal: --model" "names the legal ones"
  assert_exit 2 "--model without a value" -- r9700 init --model
}

t_init_refuses_a_machine_file_that_is_not_there() {
  lc_setup "$FUNCNAME"
  R9700_MACHINE_ENV="$CASE/none.env"
  assert_exit 2 "init" -- r9700 init --model "$MODEL_35B"
  assert_contains "$ERR" "none.env" "the loader names the file"
}

# ---- L18: the verb list is derived, and the catalogue matches it ----------------------------------------------------------------------------------

t_l18_the_verb_list_is_derived_and_the_catalogue_matches_it() {
  lc_setup "$FUNCNAME"
  local expected catalogue
  expected="$(grep -oE '^verb_[a-z]+\(\)' "$REPO/bin/r9700" | sed -e 's/^verb_//' -e 's/()$//' | sort)"
  assert_exit 0 "commands" -- r9700 commands
  assert_eq "$expected" "$OUT" "exactly the verb_* functions, sorted, one per line"
  catalogue="$(grep -oE '^\| `bin/r9700 [a-z]+`' "$REPO/research/module_tests.md" | sed -E 's/^\| `bin\/r9700 ([a-z]+)`/\1/' | sort)"
  assert_eq "$expected" "$catalogue" "every verb is a row of the flow catalogue in research/module_tests.md, and every verb row is a verb"
  assert_contains "$(printf '%s\n' "$expected")" "step" "step is a verb since part (c)"
  assert_contains "$(printf '%s\n' "$expected")" "series" "series is a verb since E1.S3"
}

# ---- L20: an unknown verb is refused ----------------------------------------------------------------------------------------------------------------

t_l20_an_unknown_verb_is_refused_naming_the_legal_ones() {
  lc_setup "$FUNCNAME"
  assert_exit 2 "an unknown verb" -- r9700 nosuch
  assert_eq 'r9700: unknown verb "nosuch"; legal: commands init series step verdict' "$ERR" "the line"
  assert_exit 2 "no verb" -- r9700
  assert_contains "$ERR" "legal: commands init series step verdict" "the same list"
  assert_exit 2 "a verb that only looks like one" -- r9700 'verb_init'
  assert_missing "$STUB/calls.log" "nothing was called"
}

# ---- L21: the supervisor killed before the gate file exists ------------------------------------------------------------------------------------------

t_l21_a_worker_whose_supervisor_died_before_the_gate_exits_4_by_itself_and_touches_nothing() {
  lc_setup "$FUNCNAME"
  prod_running
  fake_supervisor kill-before-gate || return
  gone "$SUP"
  assert_exit 0 "the marker exists" -- test -f "$MARKER_FILE"
  marker_read "$MARKER_FILE"
  assert_eq "" "${MARKER[WORKER_PGID]:-}" "without worker keys (the second write never happened)"
  local i worker
  for i in $(seq 1 100); do [ -s "$SUP_DIR/run/steps/1.worker.log" ] && break; sleep 0.1; done
  assert_contains "$(cat "$SUP_DIR/run/steps/1.worker.log")" "gate" "the worker gave up at the gate and said so"
  assert_missing "$STUB/worker.calls" "the worker never ran its command"
  assert_missing "$STUB/child.pid" "no child of the worker"
  assert_eq "1" "$(grep -c ' wslc run ' "$STUB/calls.log")" "(the only wslc run call is the test's own prod_running)"
  assert_exit 2 "the next invocation restores first" -- r9700 verdict "$CASE/nodir"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_exit 0 "and the server is back" -- test -f "$STUB/containers/vllm.pid"
  kill_recorded_pids "$CASE"
}

# ---- the exit codes are listed in three places and the three agree ----------------------------------------------------------------------------------

t_the_exit_codes_are_listed_in_the_readme_the_entry_point_header_and_the_architecture_table_and_all_agree() {
  lc_setup "$FUNCNAME"
  local codes="0 1 2 4 5 6 7 8 9 10 11 129 130 143" code header readme table
  header="$(sed -n '/^# Exit codes/,/^set -u/p' "$REPO/bin/r9700" | grep -E '^#   [0-9]+ ' | sed -E 's/^#   ([0-9]+) .*/\1/' | sort -n | tr '\n' ' ' | sed 's/ $//')"
  readme="$(sed -n '/^Exit codes/,/^Tests:/p' "$REPO/README.md" | grep -E '^- `[0-9]+` ' | sed -E 's/^- `([0-9]+)` .*/\1/' | sort -n | tr '\n' ' ' | sed 's/ $//')"
  table="$(sed -n '/^\*\*Exit codes of `bin\/r9700`\*\*/,/^\*\*Growth/p' "$REPO/research/architecture.md" | grep -E '^\| [0-9]' | sed -E 's/^\| ([^|]*) \|.*/\1/' | grep -oE '[0-9]+' | sort -un | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "$(printf '%s\n' $codes | sort -n | tr '\n' ' ' | sed 's/ $//')" "$header" "the header of bin/r9700 lists every code, one per line"
  assert_eq "$header" "$readme" "the README's exit list has the same codes"
  assert_eq "$header" "$table" "and the architecture table too"
  for code in 1 5 7 8 11 129; do
    assert_contains " $header " " $code " "code $code is in the header"
  done
}

run_all_tests
