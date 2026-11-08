#!/usr/bin/env bash
# `bin/r9700 comfy` and the one owner of the card (E1.S2): the owner check of every verb under the supervisor (OC1-OC5), the two-owner admission of the locked entry (OC6-OC8),
# the cleanup and `init` never stopping the operator's ComfyUI (NR7), the restore's half and the marker (RM2-RM4), `comfy stop` (CT1-CT5) and `comfy status` (CU1-CU3).
# The image files (IM1-IM5) and comfyui/models.conf (MC1-MC3) of E1.S3 are here too. `comfy start` is tests/test_comfy_start.sh, the name rules are tests/test_config_comfy.sh,
# `comfy build` is tests/test_comfy_build.sh, `comfy fetch` tests/test_comfy_fetch.sh and comfyui/fetch_model.sh tests/test_comfy_fetch_model.sh. Every test body is a function t_<guarantee>; each runs in its own subshell and
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
# shellcheck source=tests/lib/hostile.sh
source "$HERE/lib/hostile.sh"

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

# ---- the image files (E1.S3: IM1-IM5) -----------------------------------------------------------------------------------------------------------------

CF="$REPO/comfyui/Containerfile"
EP="$REPO/comfyui/entrypoint.sh"

# code_lines <file>: the lines that are not comments (a comment line starts with #, after any blanks)
code_lines() { grep -vE '^[[:space:]]*#' "$1"; }

# comment_block_with <file> <word> <word>: 0 when ONE block of consecutive comment lines holds both words
comment_block_with() {
  awk -v a="$2" -v b="$3" '
    /^[[:space:]]*#/ { blk = blk "\n" $0; next }
    { if (index(blk, a) && index(blk, b)) f = 1; blk = "" }
    END { if (index(blk, a) && index(blk, b)) f = 1; exit !f }' "$1"
}

# arg_default <Containerfile> <ARG name>: the default of an `ARG <name>=<value>` line
arg_default() { sed -n "s/^ARG $2=//p" "$1" | head -n 1; }

# field_default <KEY>: the default config_keys prints for a field (read, never typed)
field_default() { config_keys | awk -v k="$1" '$2 == k { print $4 }'; }

# IM1
t_the_image_never_sets_the_hip_allocator_option_and_says_why() {
  comfy_setup "$FUNCNAME"
  assert_eq "" "$(code_lines "$CF" | grep -n 'PYTORCH_HIP_ALLOC_CONF')" "no code line of the Containerfile names PYTORCH_HIP_ALLOC_CONF"
  assert_eq "" "$(code_lines "$EP" | grep -n 'PYTORCH_HIP_ALLOC_CONF')" "no code line of entrypoint.sh names it"
  assert_exit 0 "a comment block of the Containerfile names it with hipErrorInvalidValue" -- comment_block_with "$CF" PYTORCH_HIP_ALLOC_CONF hipErrorInvalidValue
  # the scan is alive: a planted copy that sets it in its ENV line is found by the same grep
  { cat "$CF"; printf 'ENV PYTORCH_HIP_ALLOC_CONF=expandable_segments:True\n'; } > "$CASE/planted.Containerfile"
  assert_contains "$(code_lines "$CASE/planted.Containerfile" | grep -n 'PYTORCH_HIP_ALLOC_CONF')" "PYTORCH_HIP_ALLOC_CONF" "the same grep finds it in a planted copy"
}

# IM2
t_the_builds_defaults_are_the_field_tables() {
  comfy_setup "$FUNCNAME"
  assert_eq "$(field_default COMFY_BASE_IMAGE)" "$(arg_default "$CF" BASE)" "ARG BASE equals the default of COMFY_BASE_IMAGE"
  assert_eq "$(field_default COMFY_REF)" "$(arg_default "$CF" COMFYUI_REF)" "ARG COMFYUI_REF equals the default of COMFY_REF"
  assert_contains "$(field_default COMFY_REF)" "v" "the field default was read (a scan that reads nothing would pass)"
  sed 's/^ARG COMFYUI_REF=.*/ARG COMFYUI_REF=v0.0.1/' "$CF" > "$CASE/planted.Containerfile"
  assert_eq "no" "$([ "$(field_default COMFY_REF)" = "$(arg_default "$CASE/planted.Containerfile" COMFYUI_REF)" ] && echo yes || echo no)" "a planted copy with another tag fails the same comparison"
}

# entry_world <name>: a case folder, a root for the entrypoint and a python3 in front of PATH that adds --without-pip to `-m venv` (the host may have no ensurepip; the image has python3.12-venv).
# The shim follows testing.md's shim clause: it resolves the real python3 ONCE, at its first install, with its own folder removed from the lookup, compares REAL paths, refuses a result inside its own folder and
# bakes the absolute path in; a later install keeps what the first one baked, and the shim never looks python3 up at run time (two shims that re-resolve would bake each other).
entry_world() {
  comfy_setup "$1"
  ROOT="$CASE/root"
  SHIM="$CASE/shim"
  mkdir -p "$ROOT" "$SHIM"
  local real shim_real dir path_without="" IFS_SAVE="$IFS"
  shim_real="$(readlink -f "$SHIM")"
  if [ ! -e "$SHIM/python3" ]; then
    IFS=:
    for dir in $PATH; do
      [ "$(readlink -f "${dir:-.}" 2> /dev/null)" = "$shim_real" ] || path_without+="${path_without:+:}$dir"
    done
    IFS="$IFS_SAVE"
    real="$(PATH="$path_without" command -v python3)" || { _assert_fail "entry_world" "no python3 outside the shim folder"; return 1; }
    real="$(readlink -f "$real")"
    case $real/ in
      "$shim_real"/*) _assert_fail "entry_world" "the real python3 resolved to $real, inside the shim folder"; return 1 ;;
    esac
    printf '%s\n' '#!/usr/bin/env bash' "if [ \"\${1:-}\" = -m ] && [ \"\${2:-}\" = venv ]; then exec \"$real\" -m venv --without-pip \"\${@:3}\"; fi" "exec \"$real\" \"\$@\"" > "$SHIM/python3"
    chmod 755 "$SHIM/python3"
  fi
  PATH="$SHIM:$PATH"
  export PATH
}

# entry_run [<extra arg>...]: the entrypoint in dry mode against $ROOT
entry_run() { R9700_TEST_COMFY_ROOT="$ROOT" R9700_TEST_ENTRY_DRY=1 bash "$EP" "$@"; }

# IM3a
t_the_python_shim_never_resolves_to_itself_when_it_is_installed_twice() {
  entry_world "$FUNCNAME"
  local first
  first="$(cat "$SHIM/python3")"
  entry_world "$FUNCNAME"
  assert_eq "$first" "$(cat "$SHIM/python3")" "a later install keeps what the first one baked"
  assert_not_contains "$(cat "$SHIM/python3")" "$SHIM" "the baked program is not inside the shim folder"
  assert_exit 0 "the shim runs (a shim that baked itself would exec itself without end)" -- timeout 20 python3 -c 'print(1)'
  assert_eq "1" "$OUT" "and reaches the real python3"
}

# IM3
t_the_manager_uses_pip_in_each_of_its_three_starting_states() {
  entry_world "$FUNCNAME"
  local cfg="$ROOT/data/user/__manager/config.ini"
  assert_exit 0 "no config.ini" -- entry_run
  assert_eq "[default]|use_uv = False" "$(tr '\n' '|' < "$cfg" | sed 's/|$//')" "the file is made with [default] and use_uv = False"
  printf '[default]\nuse_uv = True\nother = 1\n' > "$cfg"
  assert_exit 0 "use_uv = True" -- entry_run
  assert_eq "[default]|use_uv = False|other = 1" "$(tr '\n' '|' < "$cfg" | sed 's/|$//')" "that line becomes use_uv = False"
  printf '[default]\nother = 1\n' > "$cfg"
  assert_exit 0 "a [default] section and no use_uv line" -- entry_run
  assert_eq "[default]|use_uv = False|other = 1" "$(tr '\n' '|' < "$cfg" | sed 's/|$//')" "the line is added under it"
  assert_exit 0 "and a run again changes nothing" -- entry_run
  assert_eq "1" "$(grep -c '^use_uv' "$cfg")" "one use_uv line"
}

# IM4
t_a_venv_of_another_python_version_is_moved_aside_never_deleted_and_one_of_this_version_is_kept() {
  entry_world "$FUNCNAME"
  local host other aside
  host="$(python3 -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])')"
  other=3.11.0
  [ "$host" != "$other" ] || other=3.10.0
  mkdir -p "$ROOT/data/venv"
  printf 'home = /usr/bin\nversion = %s\n' "$other" > "$ROOT/data/venv/pyvenv.cfg"
  : > "$ROOT/data/venv/marker"
  assert_exit 0 "a venv made with Python $other" -- entry_run
  aside="$(ls -d "$ROOT/data/venv.python-$other."* 2> /dev/null | head -n 1)"
  assert_exit 0 "the old venv is in venv.python-$other.<stamp>" -- test -f "$aside/marker"
  if [[ ${aside##*.} =~ ^[0-9]{8}T[0-9]{6}Z$ ]]; then assert_eq ok ok "its stamp is a UTC stamp"; else assert_eq "<YYYYMMDDTHHMMSSZ>" "${aside##*.}" "its stamp is a UTC stamp"; fi
  assert_exit 0 "a new venv was made" -- test -x "$ROOT/data/venv/bin/python"
  assert_exit 0 "with the system site packages of the image (torch and ROCm come from it)" -- grep -qx 'include-system-site-packages = true' "$ROOT/data/venv/pyvenv.cfg"
  assert_missing "$ROOT/data/venv/marker" "without the old files"
  : > "$ROOT/data/venv/kept"
  assert_exit 0 "a second run" -- entry_run
  assert_exit 0 "keeps the venv of this version (a marker planted in it survives)" -- test -f "$ROOT/data/venv/kept"
  assert_eq "1" "$(ls -d "$ROOT/data/venv.python-"* | wc -l | tr -d ' ')" "and moves nothing else aside"
}

# IM5
t_comfyui_starts_with_the_volumes_folders_and_the_extra_arguments() {
  entry_world "$FUNCNAME"
  local -a want got
  local d
  assert_exit 0 "the dry run with extra arguments" -- entry_run --reserve-vram 2
  mapfile -t got <<< "$OUT"
  want=("$ROOT/data/venv/bin/python" /opt/ComfyUI/main.py --listen 0.0.0.0 --port 8188 --base-directory "$ROOT/data" --models-directory "$ROOT/models" --enable-manager --reserve-vram 2)
  assert_eq "$(printf '%s|' "${want[@]}")" "$(printf '%s|' "${got[@]}")" "one word per line: the venv's python, main.py, ComfyUI's arguments, then the extra ones"
  for d in data/custom_nodes data/user data/input data/output data/temp cache/miopen cache/triton; do
    assert_exit 0 "$d exists below the root" -- test -d "$ROOT/$d"
  done
  for d in checkpoints loras vae text_encoders diffusion_models clip_vision controlnet upscale_models embeddings audio_encoders latent_upscale_models model_patches; do
    assert_exit 0 "models/$d exists below the root" -- test -d "$ROOT/models/$d"
  done
  assert_missing "/data/venv.python-never" "nothing was made outside the root (a root-less path is not touched)"
}

# ---- comfyui/models.conf (E1.S3: MC1-MC3) -------------------------------------------------------------------------------------------------------------

# mc_conf <name> <line>...: a models.conf copy of the test; sets R9700_COMFY_MODELS_CONF (the test knob of comfy_models_conf) and MC_FILE
mc_conf() {
  local name="$1"
  shift
  MC_FILE="$CASE/$name.conf"
  printf '%s\n' "$@" > "$MC_FILE"
  export R9700_COMFY_MODELS_CONF="$MC_FILE"
}

# MC1
t_every_line_of_the_real_models_conf_is_well_formed() {
  comfy_setup "$FUNCNAME"
  local conf="$REPO/comfyui/models.conf" set dir url sha rest n=0 bad="" dup
  while read -r set dir url sha rest; do
    n=$((n + 1))
    [[ $set =~ ^[a-z0-9]+$ && $dir =~ ^[a-z_]+$ && $url =~ ^https://[^[:space:]]+$ && $sha =~ ^[0-9a-f]{64}$ && -z $rest ]] || bad+="$set/$dir "
  done < <(grep -vE '^[[:space:]]*(#|$)' "$conf")
  assert_eq "" "$bad" "every non-comment line has a set, a folder, an https URL and a 64-character lower-case sha256"
  assert_exit 0 "the scan is alive: the file has lines" -- test "$n" -ge 7
  dup="$(grep -vE '^[[:space:]]*(#|$)' "$conf" | awk '{ n = split($3, p, "/"); print $2, p[n] }' | sort | uniq -d)"
  assert_eq "" "$dup" "no basename twice in one folder"
  assert_exit 0 "comfy_models_load returns 0 on the real file" -- comfy_models_load "$conf"
  assert_contains "$(grep 'z_image_turbo_bf16.safetensors' "$conf")" "2407613050b809ffdff18a4ac99af83ea6b95443ecebdf80e064a79c825574a6" "parity row: the pin of z_image_turbo_bf16.safetensors"
  assert_eq "$n" "${#_COMFY_M_SHA[@]}" "the parse read every line"
}

# MC2
t_a_malformed_line_is_refused_with_its_place() {
  comfy_setup "$FUNCNAME"
  local good="zimage vae https://h.example/r/ae.safetensors $(printf 'a%.0s' $(seq 1 64))" short
  short="$(printf 'a%.0s' $(seq 1 63))"
  mc_conf short "# header" "$good" "zimage vae https://h.example/r/b.safetensors $short"
  assert_exit 2 "a 63-character hash" -- comfy_models_load "$MC_FILE"
  assert_eq "r9700: comfy: $MC_FILE:3: the sha256 is not 64 lower-case hex characters" "$ERR" "names the file, the line and the problem"
  mc_conf three "zimage vae https://h.example/r/b.safetensors"
  assert_exit 2 "three words" -- comfy_models_load "$MC_FILE"
  assert_contains "$ERR" "r9700: comfy: $MC_FILE:1: " "names the place"
  assert_contains "$ERR" "four words" "and says four words"
  mc_conf upper "Zimage vae https://h.example/r/b.safetensors $(printf 'a%.0s' $(seq 1 64))"
  assert_exit 2 "a set Zimage" -- comfy_models_load "$MC_FILE"
  assert_contains "$ERR" "r9700: comfy: $MC_FILE:1: the set" "names the place and the set"
  mc_conf twice "$good" "zimage vae https://other.example/x/ae.safetensors $(printf 'b%.0s' $(seq 1 64))"
  assert_exit 2 "the same file twice in a folder" -- comfy_models_load "$MC_FILE"
  assert_contains "$ERR" "r9700: comfy: $MC_FILE:2: " "the second place"
  assert_contains "$ERR" "ae.safetensors" "names the file"
  mc_conf more "zimage vae http://h.example/r/b.safetensors $(printf 'a%.0s' $(seq 1 64))" "zimage ../x https://h.example/r/c.safetensors $(printf 'a%.0s' $(seq 1 64))" "zimage vae https://h.example/r/d.safetensors $short"
  assert_exit 2 "three bad lines in one file" -- comfy_models_load "$MC_FILE"
  assert_eq "3" "$(grep -c "^r9700: comfy: $MC_FILE:" <<< "$ERR")" "all are reported in one pass, one line each"
  local pin hostile
  pin="$(printf 'a%.0s' $(seq 1 64))"
  for hostile in "${HOSTILE_URL_TAILS[@]}"; do
    mc_conf hostile "zimage vae https://h.example/$hostile $pin"
    assert_exit 2 "a hostile file name or url [$hostile]" -- comfy_models_load "$MC_FILE"
    assert_contains "$ERR" "r9700: comfy: $MC_FILE:1: " "[$hostile] names the place"
  done
  assert_exit 0 "the scan is alive: the shared list is not empty" -- test "${#HOSTILE_URL_TAILS[@]}" -ge 11
  mc_conf good "zimage vae https://h.example/r/a-b_c.1.bin?download=true $pin"
  assert_exit 0 "a plain name with a query is accepted (the scan is alive: the same shapes are not all refused)" -- comfy_models_load "$MC_FILE"
}

# MC3
t_the_legal_sets_are_the_files() {
  comfy_setup "$FUNCNAME"
  local conf="$REPO/comfyui/models.conf" want
  want="$(grep -vE '^[[:space:]]*(#|$)' "$conf" | awk '!seen[$1]++ { printf "%s%s", sep, $1; sep = " " }')"
  assert_contains " $want " " zimage " "the scan is alive: the awk over the file finds zimage"
  comfy_models_load "$conf"
  assert_eq "$want" "$(comfy_sets | tr '\n' ' ' | sed 's/ $//')" "comfy_sets prints the set names in file order, each once"
  mc_conf custom "b vae https://h.example/r/x.bin $(printf 'a%.0s' $(seq 1 64))" "a vae https://h.example/r/y.bin $(printf 'a%.0s' $(seq 1 64))" "b vae https://h.example/r/z.bin $(printf 'a%.0s' $(seq 1 64))"
  comfy_models_load "$MC_FILE"
  assert_eq "b a" "$(comfy_sets | tr '\n' ' ' | sed 's/ $//')" "a copy named by R9700_COMFY_MODELS_CONF: file order, once each"
}

# MC4
t_the_hosts_and_the_scripts_derivations_of_a_file_name_agree() {
  comfy_setup "$FUNCNAME"
  local pair url want host script fn
  # the script runs inside the image and cannot source lib/comfy.sh, so it holds its own derivation; the test takes it from the script's text and runs both over the same urls
  fn="$(sed -n '/^url_file_name() /p' "$REPO/comfyui/fetch_model.sh")"
  assert_contains "$fn" "url_file_name()" "the scan is alive: the script's derivation was read"
  eval "script_$fn"
  for pair in "${NAME_DERIVATION_URLS[@]}"; do
    url="${pair%%|*}" want="${pair#*|}"
    host="$(_comfy_url_file_name "$url")"
    script="$(script_url_file_name "$url")"
    assert_eq "$want" "$host" "[$url] the host's derivation"
    assert_eq "$host" "$script" "[$url] the script's derivation equals the host's"
  done
}

run_all_tests
