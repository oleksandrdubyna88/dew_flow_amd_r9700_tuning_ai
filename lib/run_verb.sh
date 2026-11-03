#!/usr/bin/env bash
# lib/run_verb.sh — the supervisor's half of `bin/r9700 run` (E3.S2): the table of steps, the validation of a plan, `--check`, the prepare of every step and the chain. SOURCED by
# bin/r9700 after the verbs it dispatches to (series, moe-tune, linear-bench, prefixtest) and after lib/run_plan.sh. Bash >= 4.4, `set -u` safe, no `set -e`. Nothing here takes the
# lock or sets a trap: the lock, the restore-first, the deadline, the run folder and the ONE cleanup belong to `supervise`; a step is the verb's own `<verb>_body`, which ends in
# ONE `step_run`. `run` is `supervise` around several of them, and adds no exit code.
#
#   run_step_kind <verb> <mode>        prints the kind of a step, 1 for a verb that is not one; run_step_legal prints the legal words (both read _RUN_STEPS, the ONE table)
#   run_validate <file>                the SYNTAX of every step, by the verb's own `<verb>_args`, every problem as `r9700: run: <file>:<line>: <the verb's line>`; 2 after the pass
#   run_check <file>                   `--check`: run_validate's work plus every step's config and prepare, WITHOUT the lock and without placing a file; 0 or 2
#   run_prepare                        what `supervise` calls after the restore-first: every step's args, prepare and placement, so that a typo in step 3 is refused before step 1
#                                      stops anything
#   run_body                           the body of `supervise`: the chain (decision 5); run.txt records every state change (run_record_write, lib/run_guarded.sh)
#
# Test knobs (the environment only, never machine.env): R9700_TEST_RUN_HOLD_S, a pause (a whole or decimal number of seconds, a signal ends it at once) at a step boundary, after
# <run dir>/hold-<k> is made: the only way a test can send a signal BEFORE the first step or BETWEEN two steps without a race; R9700_TEST_RUN_HOLD_AT limits it to boundary <k>.
#
# THE EXIT CODE OF A CHAIN is the NORMALIZED result of the step that stopped it, never a raw worker code: the body of a step returns what `step_run` returns after
# `_step_settle` (lib/step.sh) or what the verb itself refuses with. The supervisor's own codes keep their meaning; `run` adds none. The rows (tests/test_run.sh R17 reads
# this block and fails when a row has no case there):
#
# map worker-0        the worker ended 0                                        body 0   run.txt `done 0`          run goes on; 0 at the end
# map worker-3        the worker ended 3 (not quiet)                            not returned: the step waits and repeats; stays `running`; not a failed try
# map worker-4        the worker ended 4 (nothing more fits)                    body 6   run.txt `stopped 6`       run exits 6, never 4
# map deadline        KIND=deadline (the watcher stopped the worker)            body 6   run.txt `stopped 6`       run exits 6
# map worker-5        the worker ended 5 (its gate never opened) or any other   a failed try; after MAX_FAILED_TRIES: body 7   `stopped 7`   run exits 7, never 5
# map ram_guard       KIND=ram_guard                                            a failed try; after MAX_FAILED_TRIES: body 7   `stopped 7`   run exits 7
# map refused         KIND=refused, a refused argument or config, a differing fingerprint, a record of another experiment   body 2   `stopped 2`   run exits 2
# map disk_gate       KIND=disk_gate                                            body 9   run.txt `stopped 9`       run exits 9
# map not-quiet       not quiet before the deadline                             body 8   run.txt `stopped 8`       run exits 8
# map cap             the stop cap MAX_SERVER_STOPS would be passed             body 8   run.txt `stopped 8`       run exits 8
# map restore-5       a busy-wait restore that did not become ready             body 5   run.txt `stopped 5`       run exits 5
# map other           a body that returns any other non-zero code               normalized to 7 (a failed step)   `stopped 7`   run exits 7
# map signal          INT, TERM, HUP                                            the handler exits   `interrupted -`   130, 143, 129
# map lock            the lock is held (before any step)                        no run folder                         run exits 4
# map final-restore   the FINAL restore did not become ready                    run.txt keeps the step's own outcome   run exits 5 (supervise: a cleanup code replaces the body's)

# The ONE table of steps (decision 2): `<words that name it>|<kind>|<args function>|<prepare function>|<body function>|<dry variable>|<first word handed to args>`. `series`
# is the verb's words after `series`; the moe-tune row keeps its mode as the first word (moe_tune_args takes the mode); kernels_args takes the verb itself.
_RUN_STEPS=(
  "series|series|series_args|series_prepare|series_body|_SERIES_DRY|1"
  "moe-tune chunk|moe-chunk|moe_tune_args|moe_prepare|moe_chunk_body|_MOE_DRY|1"
  "moe-tune ab|moe-ab|moe_tune_args|moe_prepare|moe_ab_body|_MOE_DRY|1"
  "linear-bench|linear-bench|kernels_args|kernels_prepare|kernels_linear_body|_KERN_DRY|0"
  "prefixtest|prefixtest|kernels_args|kernels_prepare|kernels_prefix_body|_KERN_DRY|0"
)
_RUN_USAGE="r9700: run: usage: run <plan file> [--check] [--dry-run]"

# _run_row <verb> <mode>: sets _RR_KEY _RR_KIND _RR_ARGS _RR_PREPARE _RR_BODY _RR_DRY _RR_FROM from the row that names the words; 1 when there is none
_run_row() {
  local key="$1" row
  [ "$1" != moe-tune ] || key="moe-tune ${2:-}"
  for row in "${_RUN_STEPS[@]}"; do
    [ "${row%%|*}" = "$key" ] || continue
    IFS='|' read -r _RR_KEY _RR_KIND _RR_ARGS _RR_PREPARE _RR_BODY _RR_DRY _RR_FROM <<< "$row"
    return 0
  done
  return 1
}

run_step_kind() {
  _run_row "$@" || return 1
  printf '%s\n' "$_RR_KIND"
}

run_step_legal() {
  local row out=""
  for row in "${_RUN_STEPS[@]}"; do out+="${row%%|*}, "; done
  printf '%s\n' "${out%, }"
}

# _run_load <index>: the words of plan step <index> (0-based) and its row; 1 when it is not a step (a plan edited after it was read)
_run_load() {
  plan_words "${_PLAN_TEXT[$1]}" _RUN_WORDS || return 1
  _run_row "${_RUN_WORDS[0]}" "${_RUN_WORDS[1]:-}"
}

# _run_args: the verb's own syntax check of the loaded step, in THIS shell (it sets the verb's variables)
_run_args() { "$_RR_ARGS" "${_RUN_WORDS[@]:$_RR_FROM}"; }

# _run_say <file> <index> <text lines>: `r9700: run: <file>:<line>: <line>` for every line; a leading `r9700: ` of the verb's own line is dropped
_run_say() {
  local file="$1" i="$2" line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf 'r9700: run: %s:%s: %s\n' "$file" "${_PLAN_LINES[$i]}" "${line#r9700: }" >&2
  done <<< "$3"
}

run_validate() {
  local file="$1" i out bad=0
  for i in "${!_PLAN_TEXT[@]}"; do
    _run_load "$i" || { echo "r9700: run: $file:${_PLAN_LINES[$i]}: the line is not a step" >&2; bad=1; continue; }
    out="$(_run_args 2>&1)" || { _run_say "$file" "$i" "$out"; bad=1; }
  done
  [ "$bad" -eq 0 ] || return 2
}

# run_check <file>: validation, then every step's config and prepare. The prepare functions place no file (the placement is the bodies' and run_prepare's), so nothing is written.
run_check() {
  local file="$1" i bad=0 k
  for i in "${!_PLAN_TEXT[@]}"; do
    k=$((i + 1))
    _run_load "$i" && _run_args > /dev/null 2>&1 || { bad=1; continue; }
    if "$_RR_PREPARE"; then
      echo "run: step $k: ok (${_PLAN_TEXT[$i]})"
    else
      echo "r9700: run: $file:${_PLAN_LINES[$i]}: step $k is refused (see the lines above)" >&2
      bad=1
    fi
  done
  [ "$bad" -eq 0 ] || return 2
  echo "run: at most ${#_PLAN_TEXT[@]} stops of the operator's server if every step is admitted after a busy wait; MAX_SERVER_STOPS=${R9700_MAX_SERVER_STOPS:-?}"
}

# _run_place: the files of the loaded step in the placed folder, hash-checked (the bodies do it again, a hash compare that finds nothing to do)
_run_place() {
  case $_RR_KIND in
    moe-chunk | moe-ab) _MOE_PLACED_BY=moe-tune moe_place ;;
    linear-bench | prefixtest) _MOE_PLACED_BY="$_KERN_VERB" moe_place kernels_assets ;;
    *) return 0 ;;
  esac
}

run_prepare() {
  local i
  for i in "${!_PLAN_TEXT[@]}"; do
    _run_load "$i" && _run_args && "$_RR_PREPARE" && _run_place && continue
    echo "r9700: run: step $((i + 1)) (${_PLAN_TEXT[$i]}) is refused" >&2
    return 2
  done
}

# _run_hold <k>: the test knob of the header
_run_hold() {
  [[ ${R9700_TEST_RUN_HOLD_S:-} =~ ^[0-9]+(\.[0-9]+)?$ ]] || return 0
  [ -z "${R9700_TEST_RUN_HOLD_AT:-}" ] || [ "$R9700_TEST_RUN_HOLD_AT" = "$1" ] || return 0
  : > "${RUN_DIR:?}/hold-$1"
  _rg_sleep "$R9700_TEST_RUN_HOLD_S"
}

# _run_step <index>: one step with the files of ITS model as they are now: the words, the verb's arguments, a check of the config in a subshell (a failed config_load leaves the
# loaded config unset, and the cleanup still needs it), the prepare, then the verb's body (the dry flag set first for `run --dry-run`)
_run_step() {
  _run_load "$1" && _run_args || return 2
  ( "$_RR_PREPARE" ) 9>&- || return 2
  "$_RR_PREPARE" || return 2
  [ "${_RUN_DRY:-no}" != yes ] || printf -v "$_RR_DRY" '%s' yes
  "$_RR_BODY"
}

run_body() {
  local i k n="${#_PLAN_TEXT[@]}" rc=0 text
  run_plan_copy "$_RUN_FILE" || return 2
  run_record_init "$_RUN_FILE" "$n" || return 2
  for i in "${!_PLAN_TEXT[@]}"; do
    k=$((i + 1))
    text="${_PLAN_TEXT[$i]}"
    _run_hold "$k"
    step_budget_reset # the failed tries of this step; the stop count is run-wide and is not reset (lib/step.sh)
    _RG_RUN_STEP="$k"
    run_record_write "$k" running
    if [ "${_RUN_DRY:-no}" = yes ]; then echo "run: step $k ($text):"; else echo "run: step $k of $n ($text)"; fi
    _run_step "$i"
    rc=$?
    _RG_RUN_STEP=""
    case $rc in
      0) run_record_write "$k" done 0; continue ;;
      2 | 5 | 6 | 7 | 8 | 9) ;;
      *) rg_log "step $k returned $rc: counted as a failed step (7)"; rc=7 ;;
    esac
    run_record_write "$k" stopped "$rc"
    rg_err "r9700: run: stopped at step $k of $n ($text): $rc"
    return "$rc"
  done
  return 0
}
