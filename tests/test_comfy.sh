#!/usr/bin/env bash
# `bin/r9700 comfy` and the one owner of the card (E1.S2): the owner check of every verb under the supervisor (OC1-OC5), the two-owner admission of the locked entry (OC6-OC8),
# the cleanup and `init` never stopping the operator's ComfyUI (NR7), the restore's half and the marker (RM2-RM4), `comfy stop` (CT1-CT5) and `comfy status` (CU1-CU3).
# `comfy start` is tests/test_comfy_start.sh, the name rules are tests/test_config_comfy.sh. Every test body is a function t_<guarantee>; each runs in its own subshell and
# writes only below $R9700_TEST_ROOT. Waits are bounded polls on a call-log line or a file, never a fixed sleep.
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

WORKER="$STUBS/worker.sh"

# ---- the owner check of the existing verbs (OC1-OC5) --------------------------------------------------------------------------------------------------

# the verbs under the supervisor, derived from the CODE lines of bin/r9700 and lib/*.sh (comments, whole and trailing, are cut): the word after `supervise`
supervised_verbs() {
  cat "$REPO/bin/r9700" "$REPO"/lib/*.sh | sed -E -e 's/^[[:space:]]*#.*$//' -e 's/[[:space:]]#.*$//' | grep -oE 'supervise [a-z-]+ ' | awk '{ print $2 }' | LC_ALL=C sort -u | tr '\n' ' ' | sed 's/ $//'
}

# the verbs OC1 holds a legal command line for; a verb added to `supervise` without a row here fails the first assertion of OC1
OC1_ROWS="linear-bench moe-tune prefixtest run series step"

# oc1_run <verb>: the one legal command line of the verb (the setup of tests/lib/runcase.sh makes the prepares pass)
oc1_run() {
  case $1 in
    step) r9700 step --model "$MODEL_35B" t -- "$WORKER" ok ;;
    series) r9700 series "$MODEL_35B" base ;;
    moe-tune) r9700 moe-tune chunk "$MODEL_35B" --keys 24 ;;
    linear-bench) r9700 linear-bench "$MODEL_35B" ;;
    prefixtest) r9700 prefixtest "$MODEL_35B" ;;
    run) plan_write oc1 "linear-bench $KMODEL"; r9700 run "$PLAN" ;;
  esac
}

# no_runs: 0 when no run folder was made under RESULTS_DIR/runs
no_runs() { [ -z "$(ls -A "$R9700_RESULTS_DIR/runs" 2> /dev/null)" ]; }

# OC1
t_every_verb_under_supervise_is_refused_before_anything_is_stopped_and_the_set_is_derived() {
  local derived verb missing
  derived="$(supervised_verbs)"
  assert_contains " $derived " " step " "the scan is alive: the derived set holds step"
  assert_contains " $derived " " run " "and run"
  missing=""
  for verb in $derived; do [[ " $OC1_ROWS " == *" $verb "* ]] || missing+="$verb "; done
  assert_eq "" "$missing" "every verb under supervise has a row (add a row for: $missing)"
  assert_eq "$derived" "$(printf '%s\n' $OC1_ROWS | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')" "and the rows are exactly the derived set"
  for verb in $derived; do
    run_setup "$FUNCNAME-$verb"
    comfy_listed
    assert_exit 2 "[$verb] is refused" -- oc1_run "$verb"
    assert_contains "$ERR" "$(comfy_owner_line)" "[$verb] stderr holds the owner line"
    assert_contains "$ERR" "bin/r9700 comfy stop" "[$verb] and names the remedy"
    assert_eq "0" "$(stop_lines)" "[$verb] nothing was stopped"
    assert_eq "2" "$(log_count wslc run)" "[$verb] nothing was run (the two runs are the test's own: the server and ComfyUI)"
    assert_missing "$MARKER_FILE" "[$verb] no marker"
    assert_exit 0 "[$verb] no run folder" -- no_runs
    assert_exit 0 "[$verb] the operator's server still runs" -- alive vllm
    kill_recorded_pids "$CASE"
  done
  run_setup "$FUNCNAME-activate"
  comfy_listed
  assert_exit 2 "moe-tune activate is refused too" -- r9700 moe-tune activate "$MODEL_35B" stamp1
  assert_contains "$ERR" "$(comfy_owner_line)" "with the owner line"
  assert_eq "0" "$(stop_lines)" "and nothing stopped"
  kill_recorded_pids "$CASE"
}

# OC2
t_step_is_refused_with_exactly_one_stderr_line_and_touches_nothing() {
  step_setup "$FUNCNAME"
  prod_running
  comfy_listed
  assert_exit 2 "step beside a listed ComfyUI" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  assert_eq "$(comfy_owner_line)" "$ERR" "exactly one stderr line, the owner line"
  assert_eq "0" "$(stop_lines)" "no stop"
  assert_missing "$MARKER_FILE" "no marker"
  assert_exit 0 "no run folder" -- no_runs
  assert_missing "$STUB/worker.calls" "the worker never ran"
  kill_recorded_pids "$CASE"
  step_setup "$FUNCNAME-b"
  comfy_listed
  assert_exit 2 "the same with the operator's server not running" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  assert_eq "$(comfy_owner_line)" "$ERR" "the same line"
  assert_eq "0" "$(stop_lines)" "still no stop"
  kill_recorded_pids "$CASE"
}

# OC3
t_a_comfyui_started_in_the_middle_of_a_run_is_caught_at_the_next_admission_and_the_restore_waits() {
  step_setup "$FUNCNAME"
  prod_running
  printf '%s\n' '#!/usr/bin/env bash' 'wslc run -d --rm --name comfyui img > /dev/null' > "$STUB/on-stop-vllm"
  assert_exit 5 "a failed try, then a retry whose admission meets ComfyUI" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" fail
  assert_contains "$ERR" "$(comfy_owner_line)" "the owner line"
  assert_contains "$ERR" "$(comfy_restore_line)" "and the restore's line"
  assert_eq "1" "$(grep -c ' wslc stop vllm$' "$STUB/calls.log")" "exactly one stop of vllm"
  assert_eq "1" "$(wc -l < "$STUB/worker.calls" | tr -d ' ')" "one worker only: the second admission started none"
  assert_eq "0" "$(log_count pwsh.exe -Detach)" "the operator's server was not started beside ComfyUI"
  assert_exit 0 "the marker exists" -- test -f "$MARKER_FILE"
  marker_read "$MARKER_FILE"
  assert_eq "comfyui" "${MARKER[COMFY_CONTAINER]:-}" "and names COMFY_CONTAINER"
  assert_exit 0 "comfyui is still listed: a run never stops it" -- alive comfyui
  assert_exit 0 "comfy stop" -- comfy stop
  assert_exit 0 "init restores" -- r9700 init --model "$MODEL_35B"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_exit 0 "and vllm is listed again" -- alive vllm
  kill_recorded_pids "$CASE"
}

# OC4
t_nothing_changes_when_the_operators_comfyui_is_not_listed_and_the_match_is_the_whole_name() {
  local variant
  for variant in none comfyuix; do
    step_setup "$FUNCNAME-$variant"
    prod_running
    [ "$variant" = none ] || comfy_listed "$variant"
    assert_exit 0 "[$variant] step runs as before" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
    assert_eq "1" "$(count_calls wslc stop)" "[$variant] one stop"
    assert_eq "1" "$(log_count pwsh.exe -Detach)" "[$variant] one restore"
    assert_missing "$MARKER_FILE" "[$variant] no marker"
    kill_recorded_pids "$CASE"
  done
}

# OC5
t_a_container_list_that_cannot_be_read_at_the_check_refuses_the_run_after_three_tries() {
  step_setup "$FUNCNAME"
  prod_running
  printf '3\n' > "$STUB/fail-list"
  assert_exit 2 "three failing lists" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "one stderr line"
  assert_contains "$ERR" "r9700: the container list failed 3 times (" "its shape"
  assert_contains "$ERR" "): cannot tell whether the operator's ComfyUI runs; nothing was started" "and its end"
  assert_eq "3" "$(count_calls wslc list)" "three list calls"
  local gaps
  gaps="$(awk '$3 == "wslc" && $4 == "list" { if (p != "") printf "%d ", (($1 - p) >= 0.09); p = $1 }' "$STUB/calls.log")"
  assert_eq "1 1 " "$gaps" "t_scale 10 apart (0.1 s at this scale)"
  assert_eq "0" "$(stop_lines)" "no stop"
  assert_exit 0 "no run folder" -- no_runs
  kill_recorded_pids "$CASE"
  step_setup "$FUNCNAME-two"
  prod_running
  printf '2\n' > "$STUB/fail-list"
  assert_exit 0 "two failing lists: the third answers and the step runs" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  kill_recorded_pids "$CASE"
}

# ---- the two-owner mode of the locked entry (OC6-OC8) -------------------------------------------------------------------------------------------------

# the double of a body: records that it ran and whether the lock was held while it did
body_double() {
  : > "$CASE/body.ran"
  if flock -n "$R9700_STATE_DIR/lock" true 2> /dev/null; then : > "$CASE/body.lock-free"; else : > "$CASE/body.lock-held"; fi
}

# OC6
t_the_card_free_admission_refuses_while_the_operators_comfyui_is_listed_before_the_body() {
  comfy_setup "$FUNCNAME"
  comfy_listed
  assert_exit 2 "comfy_locked probe card-free" -- comfy_locked probe card-free body_double
  assert_eq "$(comfy_owner_line)" "$ERR" "exactly one stderr line, the owner line"
  assert_missing "$CASE/body.ran" "the body never ran"
  assert_eq "0" "$(stop_lines)" "no stop"
  assert_eq "1" "$(log_count wslc run)" "no run (the one is the test's own)"
  assert_missing "$MARKER_FILE" "no marker"
  assert_exit 0 "the lock is free afterwards" -- lock_free
  assert_exit 2 "comfy_owners_check alone, ComfyUI listed" -- comfy_owners_check $'comfyui\nother'
  assert_eq "$(comfy_owner_line)" "$ERR" "the owner line"
  assert_exit 0 "a listing of comfyuix and vllmx" -- comfy_owners_check $'comfyuix\nvllmx'
  kill_recorded_pids "$CASE"
}

# OC7
t_the_card_free_admission_refuses_while_the_operators_server_is_listed_and_a_marker_restores_first() {
  comfy_setup "$FUNCNAME-a"
  prod_running
  assert_exit 2 "comfy_locked probe card-free, the server listed" -- comfy_locked probe card-free body_double
  assert_eq "$(comfy_server_line)" "$ERR" "exactly one stderr line, the server line"
  assert_missing "$CASE/body.ran" "the body never ran"
  assert_eq "0" "$(stop_lines)" "no stop"
  assert_eq "0" "$(log_count pwsh.exe -Detach)" "no start"
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-b"
  write_marker
  assert_exit 2 "a standing marker, nothing listed" -- comfy_locked probe card-free body_double
  local refusal="$ERR"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the restore ran first"
  assert_exit 0 "vllm is listed" -- alive vllm
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_eq "$(comfy_server_line)" "$refusal" "and then the server line, correctly"
  assert_missing "$CASE/body.ran" "the body never ran"
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-c"
  prod_running
  comfy_listed
  assert_exit 2 "both owners listed" -- comfy_locked probe card-free body_double
  assert_eq "$(comfy_owner_line)" "$ERR" "ComfyUI's line, one line only"
  kill_recorded_pids "$CASE"
}

# OC8
t_with_neither_owner_listed_the_body_runs_under_the_lock_and_a_list_that_cannot_be_read_refuses() {
  local variant
  for variant in none comfyuix; do
    comfy_setup "$FUNCNAME-$variant"
    [ "$variant" = none ] || comfy_listed "$variant"
    assert_exit 0 "[$variant] the body runs" -- comfy_locked probe card-free body_double
    assert_exit 0 "[$variant] body.ran exists" -- test -f "$CASE/body.ran"
    assert_exit 0 "[$variant] the lock was held while the body ran" -- test -f "$CASE/body.lock-held"
    assert_exit 0 "[$variant] and is free afterwards" -- lock_free
    kill_recorded_pids "$CASE"
  done
  comfy_setup "$FUNCNAME-fail"
  printf '3\n' > "$STUB/fail-list"
  assert_exit 2 "a list that cannot be read" -- comfy_locked probe card-free body_double
  assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "one stderr line"
  assert_contains "$ERR" "r9700: comfy: probe: the container list failed 3 times (" "its shape"
  assert_missing "$CASE/body.ran" "the body never ran"
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-body"
  prod_running
  comfy_listed
  assert_exit 0 "the body word admits nothing" -- comfy_locked probe body body_double
  assert_exit 0 "body.ran exists" -- test -f "$CASE/body.ran"
  kill_recorded_pids "$CASE"
}

# ---- the cleanup, a guard and init never stop the operator's ComfyUI or a fetch in progress (NR7) ---------------------------------------------------

t_the_cleanup_and_init_never_stop_the_operators_comfyui_or_a_fetch_in_progress() {
  step_setup "$FUNCNAME"
  comfy_listed comfyui
  comfy_listed comfyui-fetch
  comfy_listed r9700tune-x
  mkdir -p "$CASE/run"
  assert_exit 0 "container_stop_all" -- container_stop_all "$CASE/run"
  assert_exit 1 "r9700tune-x is gone" -- alive r9700tune-x
  assert_exit 0 "comfyui is still listed" -- alive comfyui
  assert_exit 0 "and the fetch container" -- alive comfyui-fetch
  assert_eq "1" "$(ls "$CASE/run/guard" | wc -l | tr -d ' ')" "one tail was written"
  assert_contains "$(ls "$CASE/run/guard")" "r9700tune-x.tail.log" "for r9700tune-x"
  comfy_listed r9700tune-x
  assert_exit 0 "init" -- r9700 init --model "$MODEL_35B"
  assert_contains "$OUT" "stopped r9700tune-x" "init reports the prefixed container it stopped"
  assert_exit 0 "comfyui is still listed after init" -- alive comfyui
  assert_exit 0 "and the fetch container" -- alive comfyui-fetch
  kill_recorded_pids "$CASE"
}

# ---- the restore's half and the marker (RM2-RM4) ------------------------------------------------------------------------------------------------

# RM2
t_a_restore_never_starts_the_operators_server_beside_the_operators_comfyui() {
  lc_setup "$FUNCNAME"
  write_marker COMFY_CONTAINER=comfyui
  comfy_listed
  comfy_listed r9700tune-old
  assert_exit 5 "init with a marker beside a listed ComfyUI" -- r9700 init --model "$MODEL_35B"
  assert_eq "$(comfy_restore_line)" "$ERR" "one stderr line, the restore's"
  assert_eq "0" "$(log_count pwsh.exe -Detach)" "the server was not started"
  assert_exit 0 "the marker stays" -- test -f "$MARKER_FILE"
  assert_exit 1 "the toolkit's own container is stopped" -- alive r9700tune-old
  assert_eq "1" "$(ls "$R9700_STATE_DIR"/restore-hand-1/guard/*r9700tune-old.tail.log 2> /dev/null | wc -l | tr -d ' ')" "its tail is saved under the restore's folder"
  assert_exit 0 "comfyui is still listed" -- alive comfyui
  assert_exit 5 "verdict does the same" -- r9700 verdict "$CASE/nodir"
  assert_eq "$(comfy_restore_line)" "$ERR" "with the same line"
  assert_exit 0 "comfy stop" -- comfy stop
  assert_exit 0 "init after comfy stop" -- r9700 init --model "$MODEL_35B"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one start"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_exit 0 "and vllm is listed" -- alive vllm
  kill_recorded_pids "$CASE"
}

# RM3
t_a_marker_written_before_this_story_restores_as_it_always_did() {
  lc_setup "$FUNCNAME"
  write_marker
  comfy_listed
  assert_exit 0 "init with an old marker beside a listed ComfyUI" -- r9700 init --model "$MODEL_35B"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one start"
  assert_missing "$MARKER_FILE" "the marker is gone"
  kill_recorded_pids "$CASE"
}

# RM4
t_a_comfy_start_stop_vllm_killed_hard_is_restored_by_the_next_verb_after_comfy_stop() {
  comfy_setup "$FUNCNAME"
  step_cfg READY_TIMEOUT_S=3235 CLEANUP_BUDGET_S=3600
  prod_running
  { for _ in $(seq 1 30); do echo fail; done; echo ok; } > "$STUB/answers/comfy_ready"
  comfy_bg start --stop-vllm
  wait_call ' wslc exec comfyui ' 200
  kill -KILL "$SUP"
  gone "$SUP"
  assert_exit 0 "the marker exists" -- test -f "$MARKER_FILE"
  marker_read "$MARKER_FILE"
  assert_contains "${MARKER[RUN_ID]}" "comfy-" "its run id starts with comfy-"
  assert_eq "yes" "${MARKER[PROD_WAS_RUNNING]}" "the server was running"
  assert_eq "comfyui" "${MARKER[COMFY_CONTAINER]:-}" "COMFY_CONTAINER"
  assert_eq "" "${MARKER[WORKER_PGID]:-}" "no worker keys"
  assert_exit 0 "comfyui is still listed (a container outlives its starter)" -- alive comfyui
  assert_exit 5 "init" -- r9700 init --model "$MODEL_35B"
  assert_eq "$(comfy_restore_line)" "$ERR" "with the restore line"
  assert_exit 0 "comfy stop" -- comfy stop
  assert_exit 0 "init again" -- r9700 init --model "$MODEL_35B"
  assert_exit 0 "vllm is back" -- alive vllm
  assert_missing "$MARKER_FILE" "and the marker is gone"
  kill_recorded_pids "$CASE"
}

# ---- comfy stop (CT1-CT5) -----------------------------------------------------------------------------------------------------------------------------

# CT1
t_a_listed_comfyui_is_stopped() {
  comfy_setup "$FUNCNAME"
  comfy_listed
  assert_exit 0 "comfy stop" -- comfy stop
  assert_eq "1" "$(grep -c ' wslc stop comfyui$' "$STUB/calls.log")" "one stop of comfyui"
  assert_eq "comfy: stop: stopped comfyui" "$OUT" "stdout"
  assert_exit 1 "not alive afterwards" -- alive comfyui
  assert_missing "$R9700_STATE_DIR/lock" "no lock file was made"
  assert_missing "$MARKER_FILE" "no marker"
  assert_eq "0" "$(log_count pwsh.exe -Detach)" "no start of the server"
  kill_recorded_pids "$CASE"
}

# CT2
t_a_comfyui_that_is_not_listed_is_not_an_error() {
  comfy_setup "$FUNCNAME"
  assert_exit 0 "comfy stop" -- comfy stop
  assert_eq "comfy: stop: comfyui is not running, nothing to do" "$OUT" "stdout"
  assert_eq "0" "$(stop_lines)" "no stop call"
}

# CT3
t_a_stop_that_returns_1_while_the_container_is_gone_is_counted_as_stopped() {
  comfy_setup "$FUNCNAME"
  comfy_listed
  printf '1\n' > "$STUB/stop-gone-comfyui"
  assert_exit 0 "comfy stop" -- comfy stop
  assert_eq "comfy: stop: the stop returned 1 but comfyui is gone: counted as stopped" "$OUT" "stdout"
  kill_recorded_pids "$CASE"
}

# CT4
t_a_stop_that_fails_and_leaves_it_listed_is_reported_with_the_engines_text() {
  comfy_setup "$FUNCNAME"
  comfy_listed
  printf '1\n' > "$STUB/stop-fail-comfyui"
  assert_exit 1 "comfy stop" -- comfy stop
  assert_eq "r9700: comfy: stop: comfyui did not stop (code 1): stub: stop failed (scripted): comfyui" "$ERR" "one stderr line with the engine's text"
  assert_exit 0 "comfyui is still there" -- alive comfyui
  kill_recorded_pids "$CASE"
  comfy_setup "$FUNCNAME-list"
  printf '3\n' > "$STUB/fail-list"
  assert_exit 1 "a list that cannot be read" -- comfy stop
  assert_contains "$ERR" "r9700: comfy: stop: the container list failed 3 times (" "the line names the list"
  assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "one line"
}

# CT5
t_comfy_stop_takes_no_lock_restores_nothing_and_works_while_a_run_holds_the_lock() {
  comfy_setup "$FUNCNAME"
  write_marker
  comfy_listed
  local before
  before="$(cat "$MARKER_FILE")"
  assert_exit 0 "comfy stop beside a standing marker" -- comfy stop
  assert_eq "$before" "$(cat "$MARKER_FILE")" "the marker is untouched"
  assert_eq "0" "$(log_count pwsh.exe -Detach)" "nothing is restored"
  kill_recorded_pids "$CASE"
  step_setup "$FUNCNAME-lock"
  prod_running
  step_bg --model "$MODEL_35B" t -- "$WORKER" child
  wait_for "$STUB/child.pid" 100
  comfy_listed
  assert_exit 0 "comfy stop while a step holds the lock" -- comfy stop
  assert_exit 1 "comfyui is stopped" -- alive comfyui
  kill -TERM "$SUP"
  step_end
  kill_recorded_pids "$CASE"
}

# ---- comfy status (CU1-CU3) ---------------------------------------------------------------------------------------------------------------------------

# CU1
t_status_prints_both_containers_the_images_creation_time_and_the_volumes() {
  comfy_setup "$FUNCNAME"
  comfy_listed
  prod_running
  assert_exit 0 "comfy status" -- comfy status
  assert_eq "comfy: status: comfyui: running
comfy: status: vllm: running
comfy: status: image comfyui-r9700:local: created 2026-11-07T10:00:00.000000000Z
comfy: status: volume comfy-models: present
comfy: status: volume comfy-data: present
comfy: status: volume comfy-cache: present; size: not known (the engine reports no volume size)" "$OUT" "exactly the six lines"
  _argv_of_call inspect comfyui-r9700:local
  assert_eq "inspect|comfyui-r9700:local" "$(IFS='|'; echo "${ARGV[*]}")" "the inspect argv"
  assert_missing "$R9700_STATE_DIR/lock" "no lock file"
  assert_eq "0" "$(stop_lines)" "no stop"
  assert_eq "2" "$(log_count wslc run)" "no run (the two are the test's own)"
  kill_recorded_pids "$CASE"
}

# CU2
t_status_says_absence_when_it_is_a_known_fact() {
  comfy_setup "$FUNCNAME"
  rm -f "$STUB/volumes"/*
  printf '1\n' > "$STUB/answers/inspect_rc"
  assert_exit 0 "comfy status" -- comfy status
  assert_eq "comfy: status: comfyui: not running
comfy: status: vllm: not running
comfy: status: image comfyui-r9700:local: not present
comfy: status: volume comfy-models: absent
comfy: status: volume comfy-data: absent
comfy: status: volume comfy-cache: absent" "$OUT" "not running twice, not present, absent three times"
}

# CU3
t_status_says_not_known_for_what_it_could_not_read_and_exits_1() {
  comfy_setup "$FUNCNAME"
  printf '3\n' > "$STUB/fail-list"
  assert_exit 1 "a container list that cannot be read" -- comfy status
  assert_contains "$OUT" "comfy: status: containers: not known (" "says not known"
  assert_contains "$OUT" "comfy: status: image comfyui-r9700:local: created 2026-11-07T10:00:00.000000000Z" "the other lines are still printed"
  assert_contains "$OUT" "comfy: status: volume comfy-models: present" "the volumes too"
  comfy_setup "$FUNCNAME-created"
  printf '[{"Id": "sha256:stub"}]\n' > "$STUB/answers/inspect"
  assert_exit 1 "an answer without a Created field" -- comfy status
  assert_contains "$OUT" "comfy: status: image comfyui-r9700:local: created: not known (no Created in the answer)" "says so"
  comfy_setup "$FUNCNAME-volumes"
  printf '3\n' > "$STUB/fail-volume-list"
  assert_exit 1 "a volume list that cannot be read" -- comfy status
  assert_contains "$OUT" "comfy: status: volumes: not known (" "says not known"
  assert_not_contains "$OUT" "comfy: status: volume comfy-models" "and prints no volume line"
}

# CU4
t_status_does_not_call_an_inspect_that_timed_out_or_could_not_be_made_absent() {
  local rc
  for rc in 124 137 10; do
    comfy_setup "$FUNCNAME-$rc"
    printf '%s\n' "$rc" > "$STUB/answers/inspect_rc"
    assert_exit 1 "[$rc] an inspect that ended with the code $rc" -- comfy status
    assert_contains "$OUT" "comfy: status: image comfyui-r9700:local: created: not known (code $rc)" "[$rc] says not known with the code"
    assert_not_contains "$OUT" "not present" "[$rc] and does not call the image absent"
  done
}

# CT4b
t_a_stop_that_fails_followed_by_a_list_that_fails_says_the_list_failed() {
  comfy_setup "$FUNCNAME"
  comfy_listed
  printf '1\n' > "$STUB/stop-fail-comfyui"
  printf '1 3\n' > "$STUB/fail-list"
  assert_exit 1 "comfy stop" -- comfy stop
  assert_eq 1 "$(printf '%s\n' "$ERR" | wc -l | tr -d ' ')" "one stderr line"
  assert_contains "$ERR" "comfyui did not stop (code 1)" "the stop failed"
  assert_contains "$ERR" "the container list failed 3 times (" "and the list after it failed too, which the line says"
  kill_recorded_pids "$CASE"
}

run_all_tests
