#!/usr/bin/env bash
# `bin/r9700 run` (E3.S2): a plan file of steps under ONE supervisor, in the stub world. Scenarios R1-R21 of the story (R18b is a second case of R18). The plan grammar is also tested as
# functions (tests/test_run.sh PG*). Every test body is a function t_<guarantee>; each runs in its own subshell and writes only below $R9700_TEST_ROOT. Every wait is a bounded wait_for on a
# file or a log line, every deadline test uses the time scale 25 and a stop time derived from now; nothing sleeps for a fixed time. A test that needs a stand-in worker as ONE step of the
# chain overrides that verb's body AFTER sourcing bin/r9700 (run_inline): it tests the chain, not the verb.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"
# shellcheck source=tests/lib/lifecycle.sh
source "$HERE/lib/lifecycle.sh"
# shellcheck source=tests/lib/runcase.sh
source "$HERE/lib/runcase.sh"
# shellcheck source=lib/run_plan.sh
source "$REPO/lib/run_plan.sh"

WORKER="$HERE/stubs/worker.sh"
MODEL_27B="$REPO/models/qwen3.8-27b-awq.env"
BUSY_LINE='9.0 0.40 0.30 1/100 1'
RESTORE_WAIT_LINE="restoring the operator's server while the PC is not quiet"

# supervisor_log_has <regex>: the newest run folder's supervisor log holds a line matching
supervisor_log_has() { grep -qE -- "$1" "$(last_run_dir)/supervisor.log" 2> /dev/null; }

# wait_log <regex> [<n>]: waits (bounded: n * 0.05 s, default 1200) for the line in the newest run folder's supervisor log
wait_log() {
  local i
  for i in $(seq 1 "${2:-1200}"); do supervisor_log_has "$1" && return 0; sleep 0.05; done
  return 1
}

# busy_hook <container name>: the stub runs this script when that container is stopped: the PC turns busy at the end of that step
busy_hook() { printf 'printf "%s\\n" > "%s"\n' "$BUSY_LINE" "$CASE/loadavg" > "$STUB/on-stop-${R9700_CONTAINER_PREFIX}$1"; }

# quiet_after_each_restore: a bounded background watcher: every time the supervisor log shows one more busy-wait restore, the PC turns quiet again. It ends when the supervisor
# ($SUP, set by run_bg) ends, and in any case after 2000 polls 0.2 s apart (400 s: above the 300 s of the longest run_end); it polls slowly because it must not add load to the
# starved CPU it exists for (the supervisor's quiet check ticks every 3 s, so 0.2 s is quick enough).
quiet_after_each_restore() {
  (
    local seen=0 n i
    for i in $(seq 1 2000); do
      kill -0 "$SUP" 2> /dev/null || break
      n="$(grep -c "$RESTORE_WAIT_LINE" "$(last_run_dir)/supervisor.log" 2> /dev/null)"
      if [ "${n:-0}" -gt "$seen" ]; then seen="$n"; printf '0.50 0.40 0.30 1/100 1\n' > "$CASE/loadavg"; fi
      sleep 0.2
    done
  ) &
  guard_pid "$!" "watcher-$!"
}

# ---- the plan grammar, as functions -----------------------------------------------------------------------------------------------------------------------------------

t_pg1_a_quoted_word_with_spaces_is_one_word_and_a_bare_word_is_split_on_spaces() {
  local -a w=()
  plan_words 'series m base --keys "24 32" --rounds 1' w
  assert_eq "series|m|base|--keys|24 32|--rounds|1" "$(IFS='|'; echo "${w[*]}")" "the words of a line with one quoted word"
  plan_words '   prefixtest    m   ' w
  assert_eq "prefixtest|m" "$(IFS='|'; echo "${w[*]}")" "extra spaces are no words"
}

t_pg2_every_refused_character_is_refused_and_named() {
  local -a w=()
  local ch name
  for ch in '$' '`' "'" ';' '|' '&' '<' '>' '(' ')'; do
    assert_exit 1 "the character $ch in a plan line" -- plan_words "series m x${ch}y" w
    assert_contains "$_PLAN_WHY" "\"$ch\"" "the reason names the character $ch"
    assert_eq "0" "${#w[@]}" "no word is handed on for $ch"
  done
  assert_exit 1 "a tab" -- plan_words $'series\tm' w
  assert_contains "$_PLAN_WHY" "a tab" "named"
  assert_exit 1 "a carriage return" -- plan_words $'series m\r' w
  assert_contains "$_PLAN_WHY" "a carriage return" "named"
  name="a positive control: a line with none of them"
  assert_exit 0 "$name" -- plan_words 'series m base --out a.b-c_d' w
}

t_pg3_a_quote_that_is_not_closed_or_is_followed_by_text_is_refused() {
  local -a w=()
  assert_exit 1 "an unterminated quote" -- plan_words 'series m --keys "24 32' w
  assert_contains "$_PLAN_WHY" "not closed" "the reason"
  assert_exit 1 "text after the closing quote" -- plan_words 'series m --keys "24 32"x' w
  assert_contains "$_PLAN_WHY" "after the closing quote" "the reason"
  assert_exit 1 "a quote inside a bare word" -- plan_words 'series m ab"cd' w
  assert_contains "$_PLAN_WHY" "a quote inside the word" "the reason"
  assert_exit 1 "an empty quoted word" -- plan_words 'series m ""' w
}

t_pg4_every_step_of_the_table_has_its_functions_and_every_refused_verb_is_a_verb() {
  local row key kind args prepare body dry from verb
  while IFS= read -r row; do
    IFS='|' read -r key kind args prepare body dry from <<< "$row"
    for f in "$args" "$prepare" "$body"; do
      assert_exit 0 "the table row \"$key\" names the function $f" -- bash -c 'source "$1"; declare -F "$2" > /dev/null' _ "$REPO/bin/r9700" "$f"
    done
    assert_eq "yes" "$([[ $from =~ ^[01]$ ]] && echo yes)" "\"$key\": the first handed word is 0 or 1"
  done < <(bash -c 'source "$1"; printf "%s\n" "${_RUN_STEPS[@]}"' _ "$REPO/bin/r9700")
  assert_eq "5" "$(bash -c 'source "$1"; echo "${#_RUN_STEPS[@]}"' _ "$REPO/bin/r9700")" "five steps: series, moe-tune chunk, moe-tune ab, linear-bench, prefixtest"
  for verb in init verdict moe-tune; do
    assert_exit 0 "the refused verb $verb is a verb of the toolkit" -- bash -c 'source "$1"; declare -F "verb_${2//-/_}" > /dev/null' _ "$REPO/bin/r9700" "$verb"
  done
}

t_pg5_the_plan_hash_is_the_hash_of_the_bytes_that_were_parsed_whatever_the_line_ends() {
  setup_case "$FUNCNAME"
  local file="$CASE/pg5.plan" want got
  printf 'prefixtest m --name a\n\n\n# c' > "$file" # no final newline, blank lines, a last comment
  want="$(sha256sum "$file" | cut -d' ' -f1)"
  got="$(source "$REPO/bin/r9700"; plan_parse "$file" && printf '%s|%s' "$_PLAN_SHA" "${#_PLAN_TEXT[@]}")"
  assert_eq "$want|1" "$got" "plan_parse: the hash is of the file's bytes and the one step is found"
  printf 'prefixtest m --name a\n\n\n' > "$file"
  want="$(sha256sum "$file" | cut -d' ' -f1)"
  got="$(source "$REPO/bin/r9700"; plan_parse "$file" && printf '%s' "$_PLAN_SHA")"
  assert_eq "$want" "$got" "and with trailing newlines kept"
}

t_pg6_a_signal_never_overwrites_the_final_state_of_a_step_and_marks_a_running_one_interrupted() {
  setup_case "$FUNCNAME"
  RUN_DIR="$CASE/rd"
  mkdir -p "$RUN_DIR"
  _PLAN_TEXT=("one" "two")
  _PLAN_SHA=abc
  run_record_init "$CASE/x.plan" 2
  run_record_write 1 running
  run_record_interrupt 1
  assert_eq "interrupted -" "$(awk '$1 == 1 { print $2, $3 }' "$RUN_DIR/run.txt")" "a running step is marked interrupted"
  run_record_write 2 running
  run_record_write 2 done 0
  run_record_interrupt 2
  assert_eq "done 0" "$(awk '$1 == 2 { print $2, $3 }' "$RUN_DIR/run.txt")" "a step whose final state is written stays done"
  run_record_write 2 stopped 7
  run_record_interrupt 2
  assert_eq "stopped 7" "$(awk '$1 == 2 { print $2, $3 }' "$RUN_DIR/run.txt")" "and stays stopped"
}

# ---- R1: one lifecycle ------------------------------------------------------------------------------------------------------------------------------------------------

t_r1_a_three_step_plan_runs_to_the_end_under_one_lifecycle() {
  run_setup "$FUNCNAME"
  plan_fixture three_steps
  assert_exit 0 "the three-step plan" -- r9700 run "$PLAN"
  assert_eq "1" "$(prod_stops)" "the operator's server was stopped once, at step 1's admission"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "and restored once, at the end"
  assert_exit 0 "the prefix record" -- test -d "$RECS/prefix/p1"
  assert_exit 0 "the series record" -- test -d "$SDIR/rounds/base-1"
  assert_exit 0 "the linear record" -- test -d "$RECS/linear/n1"
  assert_eq "done 0|done 0|done 0" "$(printf '%s|%s|%s' "$(run_state 1)" "$(run_state 2)" "$(run_state 3)")" "run.txt: three done lines"
  assert_eq "3" "$(grep -c ' admitted$' "$(last_run_dir)/supervisor.log")" "the supervisor log shows an admission per step"
  assert_eq "1" "$(grep -c "stopped the operator's server (stop " "$(last_run_dir)/supervisor.log")" "and ONE charge line"
  assert_eq "done" "$(cat "$(last_run_dir)/status")" "the status is done"
  assert_exit 0 "the server is back" -- test -f "$STUB/containers/vllm.pid"
}

# ---- R2: the parent's done-when --------------------------------------------------------------------------------------------------------------------------------------

t_r2_a_ram_stop_in_step_two_kills_the_worker_group_stops_every_container_restores_once_and_the_code_names_the_step() {
  run_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  plan_fixture three_steps
  export R9700_STUB_DELAY_S=0.3
  run_bg "$PLAN"
  wait_for "$STUB/containers/${R9700_CONTAINER_PREFIX}sp-base-1.pid" 300
  append_answer ram 100 # only now: the guard of step 2 reads a low value once the series' container exists
  run_end
  local run sid
  run="$(last_run_dir)"
  assert_eq "7" "$SRC" "exit 7"
  assert_contains "$SERR" "r9700: step failed 1 times, last: ram_guard" "the cause"
  assert_contains "$SERR" "r9700: run: stopped at step 2 of 3 (series qwen3.6-35b-a3b-gptq base --rounds 1): 7" "and the place"
  assert_eq "done 0|stopped 7|not-started -" "$(printf '%s|%s|%s' "$(run_state 1)" "$(run_state 2)" "$(run_state 3)")" "run.txt"
  marker_read "$run/steps/2.marker"
  sid="${MARKER[WORKER_PGID]}"
  assert_eq "" "$(session_pids "$sid" | tr '\n' ' ')" "no process of step 2's session is left"
  assert_eq "0" "$(wslc list | grep -c "^${R9700_CONTAINER_PREFIX}")" "no prefixed container is listed"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
  assert_exit 0 "step 1's record is final" -- test -d "$RECS/prefix/p1"
  assert_missing "$RECS/linear/n1" "step 3 never ran"
  echo "--- stderr of R2:" >&2
  printf '%s\n' "$SERR" | grep -E 'step failed|stopped at step' >&2
  echo "--- run.txt of R2:" >&2
  cat "$run/run.txt" >&2
}

# ---- R3: exit 3 is waited out ----------------------------------------------------------------------------------------------------------------------------------------

t_r3_a_step_that_exits_3_is_repeated_after_the_quiet_wait_and_is_not_counted_as_a_failure() {
  run_setup "$FUNCNAME"
  plan_fixture three_steps
  # the stand-in of step 2 (the series): its first start makes the PC busy and exits 3, the second ends 0 (the series' own exit 3 is E1's S12; this is the CHAIN's rule)
  series_body() {
    step_run series -- bash -c "n=0; [ -f '$CASE/c3.count' ] && read -r n < '$CASE/c3.count'; echo \$((n + 1)) > '$CASE/c3.count'; [ \$n -eq 0 ] && { printf '%s\\n' '$BUSY_LINE' > '$CASE/loadavg'; exit 3; }; exit 0"
  }
  run_inline_bg "$PLAN" series_body
  local i
  for i in $(seq 1 1200); do supervisor_log_has 'not quiet at a unit start, waiting' && break; sleep 0.05; done
  wait_log 'quiet-checks=0/1' 600 # the quiet phase that follows saw the busy PC (the stand-in made it busy before it exited 3)
  set_load 0.5
  run_end
  local log
  log="$(cat "$(last_run_dir)/supervisor.log")"
  assert_eq "0" "$SRC" "exit 0"
  assert_contains "$log" "not quiet at a unit start, waiting" "the wait is in the log"
  assert_not_contains "$log" "failed try" "and no failed try"
  assert_eq "4" "$(grep -c ' admitted$' <<< "$log")" "admitted: step 1, step 2 twice, step 3"
  assert_eq "done 0|done 0|done 0" "$(printf '%s|%s|%s' "$(run_state 1)" "$(run_state 2)" "$(run_state 3)")" "run.txt: three done"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore: the wait stayed under the 900 s phase, so the mid-run restore did not fire"
  assert_eq "1" "$(prod_stops)" "one stop"
  assert_eq "2" "$(cat "$CASE/c3.count")" "the stand-in ran twice"
}

# ---- R3b: a slow stub call under the ceilings of the chain tests ----------------------------------------------------------------------------------------------------------

t_r3b_a_wslc_list_slower_than_6_s_and_faster_than_30_s_is_not_a_failed_try() {
  run_setup "$FUNCNAME"
  plan_write r3b "prefixtest $KMODEL --name p1"
  # The chain tests run with R9700_CEILING_SCALE=2 (run_setup), so a `wslc list` has a ceiling of 60 s / 2 = 30 s; with the scale 10 of setup_case it would be 6 s and this
  # 8 s list would be cut (code 124, `admit the container list failed ()`): the failed try that a starved CPU caused in CI (R3, R17 restore-5). The sleeps run at scale 100,
  # so the 8 s are 800 s of the run: far inside the deadline (MAX_RUN_MINUTES), which therefore cannot be what the test sees.
  printf '8\n' > "$STUB/list-delay-once"
  assert_exit 0 "a one-step chain whose first wslc list takes 8 s" -- r9700 run "$PLAN"
  local run log
  run="$(last_run_dir)"
  log="$(cat "$run/supervisor.log")"
  assert_missing "$STUB/list-delay-once" "the delay was used by a wslc list call (the stub removes the file when it sleeps)"
  assert_not_contains "$log" "failed try" "no failed try"
  assert_not_contains "$log" "deadline" "and no deadline in the log"
  assert_eq "1" "$(grep -c ' admitted$' <<< "$log")" "one admission"
  assert_eq "done 0" "$(run_state 1)" "run.txt: done"
  assert_eq "1" "$(prod_stops)" "one stop"
}

# ---- R4: the deadline ------------------------------------------------------------------------------------------------------------------------------------------------

t_r4_the_deadline_ends_the_chain_and_the_restore_is_inside_the_budget() {
  run_setup "$FUNCNAME"
  short_variant
  plan_fixture three_steps
  export R9700_STUB_DELAY_S=30
  local start budget restored
  start="$(date +%s.%N)"
  assert_exit 6 "step 1 holds until the deadline" -- r9700 run "$PLAN"
  assert_eq "stopped 6|not-started -|not-started -" "$(printf '%s|%s|%s' "$(run_state 1)" "$(run_state 2)" "$(run_state 3)")" "run.txt"
  assert_contains "$ERR" "r9700: run: stopped at step 1 of 3 (prefixtest qwen3.6-35b-a3b-gptq --name p1): 6" "the line names the step"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
  restored="$(stamp_of ' pwsh.exe ')"
  budget="$(awk 'BEGIN { print 11 * 60 / 25 }')" # T_END: MAX_RUN_MINUTES at the time scale
  if awk -v a="$start" -v b="$restored" -v m="$budget" 'BEGIN { exit !(b - a < m) }'; then assert_eq ok ok "the restore came before T_END"; else assert_eq "< $budget s" "$(awk -v a="$start" -v b="$restored" 'BEGIN { print b - a }')" "the restore came before T_END"; fi
  assert_eq "deadline" "$(cat "$(last_run_dir)/status")" "the status is deadline"
  assert_missing "$SDIR" "no later step ran"
}

# ---- R5, R6: refused before the lock ---------------------------------------------------------------------------------------------------------------------------------

t_r5_check_refuses_a_bad_plan_before_the_lock_with_every_problem_in_one_pass_and_passes_a_good_one() {
  run_setup "$FUNCNAME"
  plan_fixture bad
  assert_exit 2 "a plan with three problems" -- r9700 run "$PLAN" --check
  assert_eq "3" "$(grep -c "^r9700: run: $PLAN:[0-9]*: " <<< "$ERR")" "three lines, one per problem"
  assert_contains "$ERR" "$PLAN:3: \"frobnicate\" is not a step; legal: series, moe-tune chunk, moe-tune ab, linear-bench, prefixtest" "the unknown verb, with the legal ones"
  assert_contains "$ERR" "$PLAN:5: not allowed: the character \"\$\"" "the character is named"
  assert_contains "$ERR" "$PLAN:6: moe-tune activate is not a step" "activate"
  assert_missing "$R9700_STATE_DIR/lock" "no lock file"
  assert_missing "$R9700_RESULTS_DIR/runs" "no run folder"
  plan_fixture three_steps
  assert_exit 0 "a good plan" -- r9700 run "$PLAN" --check
  assert_eq "3" "$(grep -c '^run: step [0-9]: ok (' <<< "$OUT")" "one ok line per step"
  assert_contains "$OUT" "run: step 2: ok (series qwen3.6-35b-a3b-gptq base --rounds 1)" "with the line"
  assert_missing "$R9700_STATE_DIR/lock" "still no lock file"
  assert_missing "$R9700_RESULTS_DIR/runs" "still no run folder"
  assert_eq "0" "$(stop_lines)" "nothing was stopped"
  assert_missing "$WORK/benchmark_moe.py" "nothing was placed"
}

t_r5b_the_syntax_of_every_step_is_the_verbs_own_and_names_the_line() {
  run_setup "$FUNCNAME"
  plan_write syntax "series $KMODEL base --rounds 99" "linear-bench $KMODEL --timer x" "prefixtest $KMODEL --arm Base"
  assert_exit 2 "three refused arguments" -- r9700 run "$PLAN"
  assert_contains "$ERR" "$PLAN:1: series: --rounds \"99\" is not a whole number from 1 to 20" "series"
  assert_contains "$ERR" "$PLAN:2: linear-bench: --timer \"x\" is not one of: graph eager" "linear-bench"
  assert_contains "$ERR" "$PLAN:3: prefixtest: --arm \"Base\" is not an arm name" "prefixtest"
  assert_missing "$R9700_STATE_DIR/lock" "no lock file"
  assert_exit 2 "the arguments of run itself" -- r9700 run
  assert_contains "$ERR" "usage: run <plan file> [--check] [--dry-run]" "usage"
  assert_exit 2 "a missing file" -- r9700 run "$CASE/nosuch.plan"
  assert_contains "$ERR" "nosuch.plan: cannot read" "named"
  assert_exit 2 "an unknown option" -- r9700 run "$PLAN" --frob
  assert_contains "$ERR" 'unknown option "--frob"; legal: --check, --dry-run' "legal options"
  assert_exit 2 "both ways to look" -- r9700 run "$PLAN" --check --dry-run
}

t_r6_a_dry_run_in_a_plan_is_refused_and_so_are_the_four_verbs_that_are_not_steps() {
  run_setup "$FUNCNAME"
  local line want
  while IFS='|' read -r line want; do
    plan_write six "$line"
    assert_exit 2 "the line: $line" -- r9700 run "$PLAN"
    assert_contains "$ERR" "$PLAN:1: " "the file and the line"
    assert_contains "$ERR" "$want" "the reason for: $line"
  done <<EOF
prefixtest $KMODEL --name x --dry-run|--dry-run is not allowed in a plan line
init|init is not a step: it is the machine check
verdict $CASE/out|verdict is not a step: it reads results
moe-tune merge $KMODEL a|moe-tune merge is not a step
moe-tune activate $KMODEL 20261102t010203z|moe-tune activate is not a step: it changes what the operator's own server reads
EOF
  assert_missing "$R9700_STATE_DIR/lock" "no lock was ever taken"
}

# ---- R7: the dry run -------------------------------------------------------------------------------------------------------------------------------------------------

t_r7_run_dry_run_prints_every_steps_dry_run_under_one_supervisor_and_writes_nothing() {
  run_setup "$FUNCNAME"
  plan_fixture three_steps
  export R9700_TEST_RUN_HOLD_S=2 R9700_TEST_RUN_HOLD_AT=1
  local before run
  before="$(wc -l < "$STUB/calls.log" | tr -d ' ')"
  run_bg "$PLAN" --dry-run
  run="$(run_dir_of)"
  wait_for "$run/hold-1" 100
  assert_exit 4 "a second verb while the dry run holds the lock" -- r9700 init
  assert_contains "$ERR" "another run holds $R9700_STATE_DIR/lock" "the dry run took the lock"
  run_end
  assert_eq "0" "$SRC" "exit 0"
  assert_contains "$SOUT" "run: step 1 (prefixtest $KMODEL --name p1):" "step 1's header"
  assert_contains "$SOUT" "run: step 3 (linear-bench $KMODEL --name n1 --ms \"1 2 6\" --sweep-ms 6):" "step 3's header"
  assert_contains "$SOUT" "dry-run: wslc run -d --rm --name ${R9700_CONTAINER_PREFIX}prefix-base-1 " "the prefix serve line"
  assert_contains "$SOUT" "dry-run: wslc run --rm --name ${R9700_CONTAINER_PREFIX}linear-bench-1 " "the linear line"
  # list calls, and the series fingerprint's read-only throwaway container (`run --rm`, no -d: the same call E1's dry run makes); never a stop, an exec, a detached run or a restore
  assert_eq "" "$(tail -n +"$((before + 1))" "$STUB/calls.log" | awk '$3 != "wslc" || $4 == "stop" || $4 == "exec" || ($4 == "run" && $5 == "-d")')" "no stop, no exec, no server start, no restore"
  assert_eq "0" "$(tail -n +"$((before + 1))" "$STUB/calls.log" | awk '$3 == "wslc" && $4 == "run" && $5 != "--rm" { n++ } END { print n + 0 }')" "every run call is a foreground --rm one"
  assert_missing "$RECS" "nothing under the kernels outdir"
  assert_missing "$SDIR" "nothing under the series outdir (no fingerprint.json)"
  assert_eq "done" "$(cat "$run/status")" "the status is done"
  assert_eq "done 0|done 0|done 0" "$(printf '%s|%s|%s' "$(run_state 1)" "$(run_state 2)" "$(run_state 3)")" "run.txt is written in the run folder"
}

# ---- R8: the stop cap counts real stops ------------------------------------------------------------------------------------------------------------------------------

t_r8_charging_every_admission_would_refuse_the_fourth_step_and_that_is_the_point() {
  run_setup "$FUNCNAME"
  step_cfg MAX_SERVER_STOPS=3
  plan_fixture four_steps
  assert_exit 0 "four continuously quiet steps with MAX_SERVER_STOPS=3 (the first draft charged an admission each and refused the fourth)" -- r9700 run "$PLAN"
  assert_eq "1" "$(prod_stops)" "the operator's server was stopped once (the other stops are the four prefix servers)"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
  assert_eq "4" "$(grep -c ' admitted$' "$(last_run_dir)/supervisor.log")" "four admissions"
  assert_eq "1" "$(grep -c "stopped the operator's server (stop " "$(last_run_dir)/supervisor.log")" "ONE charge line"
  assert_eq "done 0|done 0|done 0|done 0" "$(printf '%s|%s|%s|%s' "$(run_state 1)" "$(run_state 2)" "$(run_state 3)" "$(run_state 4)")" "four done"
}

# ---- R9: identity ----------------------------------------------------------------------------------------------------------------------------------------------------

t_r9_a_step_refused_by_its_identity_ends_the_chain_with_2_after_the_earlier_records_are_final() {
  run_setup "$FUNCNAME"
  plan_fixture three_steps
  assert_exit 0 "a series first, so that a fingerprint exists" -- r9700 series "$KMODEL" base --rounds 1
  printf 'x' >> "$CASE/patches/C/auto_gptq.py" # a patch file edited before run
  local restores
  restores="$(log_count pwsh.exe -Detach)"
  assert_exit 2 "the plan" -- r9700 run "$PLAN"
  local err="$ERR"
  assert_eq "done 0|stopped 2|not-started -" "$(printf '%s|%s|%s' "$(run_state 1)" "$(run_state 2)" "$(run_state 3)")" "run.txt"
  assert_exit 0 "step 1's record is final" -- test -d "$RECS/prefix/p1"
  assert_contains "$err" "fingerprint differs" "the reason is on stderr"
  assert_contains "$err" "r9700: run: stopped at step 2 of 3 (series $KMODEL base --rounds 1): 2" "and the place"
  assert_eq "$((restores + 1))" "$(log_count pwsh.exe -Detach)" "one restore of this run"
  plan_write first "series $KMODEL base --rounds 1"
  local stops
  stops="$(prod_stops)"
  assert_exit 2 "the same edit with the series as step 1" -- r9700 run "$PLAN"
  assert_eq "$stops" "$(prod_stops)" "nothing was stopped: the refusal is before the admission"
  assert_eq "stopped 2" "$(run_state 1)" "run.txt"
}

# ---- R10: a signal during step 2 -------------------------------------------------------------------------------------------------------------------------------------

t_r10_a_term_during_step_2_ends_the_chain_with_143_one_restore_and_run_txt_says_interrupted() {
  run_setup "$FUNCNAME"
  plan_fixture three_steps
  export R9700_STUB_DELAY_S=0.3
  run_bg "$PLAN"
  wait_for "$STUB/containers/${R9700_CONTAINER_PREFIX}sp-base-1.pid" 300
  kill -TERM "$SUP"
  run_end
  assert_eq "143" "$SRC" "exit 143"
  assert_eq "done 0|interrupted -|not-started -" "$(printf '%s|%s|%s' "$(run_state 1)" "$(run_state 2)" "$(run_state 3)")" "run.txt"
  assert_eq "0" "$(wslc list | grep -c "^${R9700_CONTAINER_PREFIX}")" "no prefixed container is listed"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
  assert_eq "interrupted" "$(cat "$(last_run_dir)/status")" "the status is interrupted"
  assert_missing "$MARKER_FILE" "the marker is gone"
}

# ---- R11: resume -----------------------------------------------------------------------------------------------------------------------------------------------------

t_r11_running_the_plan_again_after_a_stop_runs_only_what_is_left() {
  run_setup "$FUNCNAME"
  step_cfg MAX_FAILED_TRIES=1
  plan_fixture three_steps
  export R9700_STUB_DELAY_S=0.3
  run_bg "$PLAN"
  wait_for "$STUB/containers/${R9700_CONTAINER_PREFIX}sp-base-1.pid" 300
  append_answer ram 100
  run_end
  assert_eq "7" "$SRC" "the first run stopped at step 2"
  unset R9700_STUB_DELAY_S
  printf '8000\n' > "$STUB/answers/ram"
  assert_exit 0 "the same plan again" -- r9700 run "$PLAN"
  assert_contains "$OUT" "recorded prefix/p1, nothing to do" "step 1 is not run again"
  assert_eq "2" "$(grep -c ' admitted$' "$(last_run_dir)/supervisor.log")" "two admissions: step 2 and step 3"
  assert_eq "done 0|done 0|done 0" "$(printf '%s|%s|%s' "$(run_state 1)" "$(run_state 2)" "$(run_state 3)")" "run.txt"
}

# ---- R12, R13: one model per step ------------------------------------------------------------------------------------------------------------------------------------

t_r12_each_step_runs_with_the_config_of_its_own_model() {
  run_setup "$FUNCNAME"
  plan_fixture two_models
  assert_exit 0 "a two-model plan" -- r9700 run "$PLAN"
  local m35="qwen3.6-35b-a3b-gptq" m27="qwen3.8-27b-awq"
  serve_argv prefix-base-1
  assert_contains "${ARGV[*]}" "$(env_get "$MODEL_35B" SERVED_NAME)" "step 1's server carries the 35B served name"
  assert_contains "${ARGV[*]}" "$(env_get "$MODEL_35B" MODEL_DIR)" "and its model directory"
  serve_argv prefix-base-2
  assert_contains "${ARGV[*]}" "$(env_get "$MODEL_27B" SERVED_NAME)" "step 2's server carries the 27B served name"
  assert_contains "${ARGV[*]}" "$(env_get "$MODEL_27B" MODEL_DIR)" "and its model directory"
  assert_eq "$m35" "$(env_get "$R9700_RESULTS_DIR/kernels-$m35/prefix/a/prefix.env" MODEL)" "prefix.env of the first record names its model"
  assert_eq "$m27" "$(env_get "$R9700_RESULTS_DIR/kernels-$m27/prefix/b/prefix.env" MODEL)" "and the second one's"
}

t_r13_a_model_file_edited_after_the_validation_is_refused_at_its_step() {
  run_setup "$FUNCNAME"
  cp "$MODEL_27B" "$CASE/m27.env"
  plan_write r13 "linear-bench $KMODEL --name a --ms \"1 2 6\" --sweep-ms 6" "prefixtest $CASE/m27.env --name b"
  # the file is edited once step 1's container has started (the stub's on-start hook of a foreground container)
  printf 'sed -i "s/^MAX_NUM_SEQS=.*/MAX_NUM_SEQS=none/" "%s"\n' "$CASE/m27.env" > "$STUB/on-start-${R9700_CONTAINER_PREFIX}linear-bench-1"
  assert_exit 2 "the plan" -- r9700 run "$PLAN"
  local err="$ERR"
  assert_contains "$err" "config: $CASE/m27.env:" "the loader's line names the file"
  assert_contains "$err" "MAX_NUM_SEQS" "and the field"
  assert_contains "$err" "r9700: run: stopped at step 2 of 2 (prefixtest $CASE/m27.env --name b): 2" "the place"
  assert_eq "done 0|stopped 2" "$(printf '%s|%s' "$(run_state 1)" "$(run_state 2)")" "run.txt"
  assert_exit 0 "step 1's record is final" -- test -d "$RECS/linear/a"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
  # the cleanup hook of step 1 (the cache clear) runs in the ONE cleanup and needs the config of the last step that loaded: a refused load must not leave it unset
  assert_contains "$(cat "$(last_run_dir)/supervisor.log")" "cleanup hook: moe_cache_clear rc=0" "the hook ran with a loaded config"
  assert_exit 0 "the server is back" -- test -f "$STUB/containers/vllm.pid"
}

# ---- R14, R15, R16 ---------------------------------------------------------------------------------------------------------------------------------------------------

t_r14_the_plan_is_copied_into_the_run_folder_with_its_hash() {
  run_setup "$FUNCNAME"
  plan_write r14 "# a night" "" "prefixtest $KMODEL --name p1" "   " "# last"
  assert_exit 0 "a dry run of a plan with comments and blank lines" -- r9700 run "$PLAN" --dry-run
  local run
  run="$(last_run_dir)"
  assert_exit 0 "plan.txt equals the plan file byte for byte, comments and blank lines kept" -- cmp "$PLAN" "$run/plan.txt"
  assert_contains "$(head -n 1 "$run/run.txt")" "SHA256=$(sha256sum "$PLAN" | cut -d' ' -f1)" "run.txt's header carries the hash"
  assert_contains "$(head -n 1 "$run/run.txt")" "PLAN=$PLAN SHA256=" "and the plan"
  assert_contains "$(head -n 1 "$run/run.txt")" " STEPS=1" "and the step count"
}

t_r15_a_plan_with_no_step_is_refused() {
  run_setup "$FUNCNAME"
  : > "$CASE/empty.plan"
  printf '# only a comment\n\n   \n' > "$CASE/comments.plan"
  assert_exit 2 "an empty file" -- r9700 run "$CASE/empty.plan"
  assert_contains "$ERR" "r9700: run: $CASE/empty.plan: no step" "named"
  assert_exit 2 "a comments-only file" -- r9700 run "$CASE/comments.plan"
  assert_contains "$ERR" "r9700: run: $CASE/comments.plan: no step" "named"
  assert_missing "$R9700_STATE_DIR/lock" "no lock"
}

t_r16_run_is_a_verb_and_a_row_of_the_catalogue_and_adds_no_exit_code() {
  run_setup "$FUNCNAME"
  assert_exit 0 "commands" -- r9700 commands
  assert_exit 0 "run is listed" -- grep -qx run <<< "$OUT"
  assert_contains "$(grep -oE '^\| `bin/r9700 [a-z-]+' "$REPO/research/module_tests.md")" 'bin/r9700 run' "and has its row in the flow catalogue"
  assert_eq "0 1 2 4 5 6 7 8 9 10 11 129 130 143" "$(sed -n '/^# Exit codes/,/^set -u/p' "$REPO/bin/r9700" | grep -E '^#   [0-9]+ ' | sed -E 's/^#   ([0-9]+) .*/\1/' | sort -n | tr '\n' ' ' | sed 's/ $//')" "the header lists the codes it listed before this story: run adds none"
}

# ---- R17: the exit code of a chain is the normalized step result ------------------------------------------------------------------------------------------------------

# r17_chain <series_body function name> [<expected exit>] [<state>]: runs the one-line plan with that stand-in; sets nothing else
r17_one() {
  plan_write r17 "series $KMODEL base --rounds 1"
  run_inline "$PLAN" series_body
}

# one function per row of the mapping comment in lib/run_verb.sh: r17_<row with - as _>; r17_row dispatches (a row without a function is a failure of its own)
r17_worker_0() {
  series_body() { step_run series -- "$WORKER" ok; }
  r17_one
  assert_eq "0" "$SRC" "worker-0: exit 0"
  assert_eq "done 0" "$(run_state 1)" "worker-0: run.txt"
}

r17_worker_3() {
  series_body() { step_run series -- "$WORKER" exit3-then-ok; }
  r17_one
  assert_eq "0" "$SRC" "worker-3: exit 0 after the repeat"
  assert_not_contains "$(cat "$(last_run_dir)/supervisor.log")" "failed try" "worker-3: not a failed try"
}

r17_worker_4() {
  series_body() { step_run series -- "$WORKER" exit4; }
  r17_one
  assert_eq "6" "$SRC" "worker-4: a worker that ended 4 ends the chain with 6, never 4"
  assert_eq "stopped 6" "$(run_state 1)" "worker-4: run.txt"
}

r17_worker_5() {
  step_cfg MAX_FAILED_TRIES=1
  series_body() { step_run series -- bash -c 'exit 5'; }
  r17_one
  assert_eq "7" "$SRC" "worker-5: a worker that ended 5 is a failed try: 7, never 5"
  assert_eq "stopped 7" "$(run_state 1)" "worker-5: run.txt"
}

r17_refused() {
  series_body() { step_run series -- bash -c 'source "$1"; outcome_write "$R9700_OUTCOME_FILE" KIND=refused RC=2 DETAIL=identity; exit 1' _ "$REPO/lib/run_guarded.sh"; }
  r17_one
  assert_eq "2" "$SRC" "refused: a refused worker is 2"
  assert_eq "stopped 2" "$(run_state 1)" "refused: run.txt"
}

r17_disk_gate() {
  series_body() { step_run series -- bash -c 'source "$1"; outcome_write "$R9700_OUTCOME_FILE" KIND=disk_gate RC=1 DETAIL=event; exit 1' _ "$REPO/lib/run_guarded.sh"; }
  r17_one
  assert_eq "9" "$SRC" "disk_gate: the disk gate is 9"
  assert_eq "stopped 9" "$(run_state 1)" "disk_gate: run.txt"
}

r17_not_quiet() {
  short_variant
  set_load 9.0
  series_body() { step_run series -- "$WORKER" ok; }
  r17_one
  assert_eq "8" "$SRC" "not-quiet: not quiet before the deadline is 8"
  assert_eq "stopped 8" "$(run_state 1)" "not-quiet: run.txt"
}

r17_restore_5() {
  step_cfg MAX_FAILED_TRIES=1
  series_body() { step_run series -- bash -c "echo 99 > '$STUB/fail-list'; printf '%s\\n' '$BUSY_LINE' > '$CASE/loadavg'; exit 3"; }
  r17_one
  assert_eq "5" "$SRC" "restore-5: a busy-wait restore that did not become ready is 5"
  assert_eq "stopped 5" "$(run_state 1)" "restore-5: run.txt"
}

r17_other() {
  series_body() { return 1; }
  r17_one
  assert_eq "7" "$SRC" "other: any other non-zero code is a failed step, 7"
  assert_eq "stopped 7" "$(run_state 1)" "other: run.txt"
}

r17_lock() {
  fake_supervisor run || return
  plan_write r17 "series $KMODEL base --rounds 1"
  assert_exit 4 "lock: the lock is held" -- r9700 run "$PLAN"
  assert_missing "$R9700_RESULTS_DIR/runs" "lock: no run folder"
  kill -KILL "$SUP"
  kill_recorded_pids "$CASE"
}

r17_deadline() { assert_exit 0 "deadline is covered by R4" -- declare -F t_r4_the_deadline_ends_the_chain_and_the_restore_is_inside_the_budget; }
r17_ram_guard() { assert_exit 0 "ram_guard is covered by R2" -- declare -F t_r2_a_ram_stop_in_step_two_kills_the_worker_group_stops_every_container_restores_once_and_the_code_names_the_step; }
r17_cap() { assert_exit 0 "cap is covered by R18" -- declare -F t_r18_the_stop_cap_is_reached_only_by_real_stops_and_a_refused_admission_launches_nothing; }
r17_signal() { assert_exit 0 "signal is covered by R10 and R20" -- declare -F t_r10_a_term_during_step_2_ends_the_chain_with_143_one_restore_and_run_txt_says_interrupted; }
r17_final_restore() { assert_exit 0 "final-restore is covered by R19" -- declare -F t_r19_a_final_restore_failure_returns_5_while_run_txt_keeps_the_steps_own_outcome; }

r17_row() {
  local fn="r17_${1//-/_}"
  if declare -F "$fn" > /dev/null; then "$fn"; else _assert_fail "row $1" "tests/test_run.sh has no function $fn for this row of the mapping in lib/run_verb.sh"; fi
}

t_r17_the_exit_code_of_a_chain_is_the_normalized_step_result_row_by_row() {
  local rows row n=0
  rows="$(grep -E '^# map [a-z0-9_-]+ ' "$REPO/lib/run_verb.sh" | awk '{ print $3 }')"
  assert_eq "yes" "$([ "$(wc -l <<< "$rows")" -ge 10 ] && echo yes)" "the scan still finds the rows of the mapping comment (a scan of nothing proves nothing)"
  for row in $rows; do
    n=$((n + 1))
    ( run_setup "$FUNCNAME-$row" && r17_row "$row" )
  done
  assert_eq "$n" "$(grep -cE '^# map [a-z0-9_-]+ ' "$REPO/lib/run_verb.sh")" "every row was visited"
}

# ---- R18: the stop cap is reached only by real stops -----------------------------------------------------------------------------------------------------------------------

t_r18_the_stop_cap_is_reached_only_by_real_stops_and_a_refused_admission_launches_nothing() {
  run_setup "$FUNCNAME"
  step_cfg MAX_SERVER_STOPS=3
  plan_fixture four_steps
  local n
  for n in 1 2 3; do busy_hook "prefix-base-$n"; done
  run_bg "$PLAN"
  wait_for "$R9700_RESULTS_DIR/runs" 100
  quiet_after_each_restore
  run_end 300 # four steps and three busy waits: 15 s idle, over 60 s on a starved CPU (2026-11-04: the 60 s end killed the supervisor, exit 137); the watcher above polls for 400 s
  local run
  run="$(last_run_dir)"
  assert_eq "8" "$SRC" "exit 8"
  assert_contains "$SERR" "r9700: stopped the operator's server 3 times, limit MAX_SERVER_STOPS=3" "the refusal"
  assert_contains "$SERR" "r9700: run: stopped at step 4 of 4 (prefixtest qwen3.6-35b-a3b-gptq --name p4): 8" "and the place"
  assert_eq "done 0|done 0|done 0|stopped 8" "$(printf '%s|%s|%s|%s' "$(run_state 1)" "$(run_state 2)" "$(run_state 3)" "$(run_state 4)")" "run.txt"
  assert_eq "3" "$(prod_stops)" "three stop vllm calls, no fourth"
  assert_eq "3" "$(grep -c "stopped the operator's server (stop " "$run/supervisor.log")" "three charge lines"
  assert_eq "3" "$(grep -c ' admitted$' "$run/supervisor.log")" "three admissions: the fourth was refused before it was one"
  assert_eq "0" "$(ls "$run/steps" | grep -c '^4\.')" "no fourth worker start, no marker write: steps/4.* does not exist"
  assert_eq "3" "$(grep -c " wslc run -d --rm --name ${R9700_CONTAINER_PREFIX}prefix" "$STUB/calls.log")" "no fourth server start in the call log"
  assert_eq "3" "$(log_count pwsh.exe -Detach)" "three restores: the busy-wait ones (the fourth step's wait restored the server, so no marker stood at the refusal)"
  assert_exit 0 "the operator's server is listed at the end" -- test -f "$STUB/containers/vllm.pid"
  assert_missing "$MARKER_FILE" "no marker"
  assert_eq "not-quiet" "$(cat "$run/status")" "the status"
}

t_r18b_a_refused_admission_never_prevents_the_final_restore_when_the_marker_stands() {
  run_setup "$FUNCNAME"
  step_cfg MAX_SERVER_STOPS=1 MAX_FAILED_TRIES=1
  plan_write r18b "prefixtest $KMODEL --name p1" "prefixtest $KMODEL --name p2"
  # the operator starts their own server by hand while step 1 runs: it is listed at step 2's admission while the marker of step 1's stop stands
  printf 'wslc run -d --rm --name %s img > /dev/null\n' "$R9700_PROD_CONTAINER" > "$STUB/on-stop-${R9700_CONTAINER_PREFIX}prefix-base-1"
  assert_exit 8 "the second admission would be the second stop" -- r9700 run "$PLAN"
  local run
  run="$(last_run_dir)"
  assert_contains "$ERR" "r9700: stopped the operator's server 1 times, limit MAX_SERVER_STOPS=1" "the refusal"
  assert_eq "done 0|stopped 8" "$(printf '%s|%s' "$(run_state 1)" "$(run_state 2)")" "run.txt"
  assert_eq "1" "$(prod_stops)" "no second stop"
  assert_eq "0" "$(ls "$run/steps" | grep -c '^2\.')" "no marker copy, no worker of step 2"
  assert_contains "$(cat "$run/supervisor.log")" " restored" "the final restore ran"
  assert_missing "$MARKER_FILE" "and the marker of step 1's stop is gone"
  assert_exit 0 "the operator's server is listed" -- test -f "$STUB/containers/vllm.pid"
}

# ---- R19: the final restore ------------------------------------------------------------------------------------------------------------------------------------------

t_r19_a_final_restore_failure_returns_5_while_run_txt_keeps_the_steps_own_outcome() {
  run_setup "$FUNCNAME"
  plan_write r19 "prefixtest $KMODEL --name p1" "prefixtest $KMODEL --name p2" "prefixtest $KMODEL --name p3"
  printf 'echo 99 > "%s/fail-list"\n' "$STUB" > "$STUB/on-stop-${R9700_CONTAINER_PREFIX}prefix-base-3" # the lists fail from the last step's end on: past A22's three tries
  assert_exit 5 "a chain that finished, then a restore whose lists fail" -- r9700 run "$PLAN"
  local err="$ERR"
  assert_eq "done 0|done 0|done 0" "$(printf '%s|%s|%s' "$(run_state 1)" "$(run_state 2)" "$(run_state 3)")" "run.txt keeps the steps' own outcome"
  assert_eq "restore-failed" "$(cat "$(last_run_dir)/status")" "the status is restore-failed"
  assert_exit 0 "the marker stays" -- test -f "$MARKER_FILE"
  assert_contains "$err" "r9700: restore: vllm not ready after" "the restore's own line"
  # the same after a RAM stop at step 2
  rm -f "$STUB/fail-list" "$MARKER_FILE"
  prod_running 2> /dev/null || true
  rm -rf "$RECS"
  step_cfg MAX_FAILED_TRIES=1
  printf 'echo 99 > "%s/fail-list"\n' "$STUB" > "$STUB/on-stop-${R9700_CONTAINER_PREFIX}prefix-base-2"
  rm -f "$STUB/on-stop-${R9700_CONTAINER_PREFIX}prefix-base-3"
  export R9700_STUB_DELAY_S=0.3
  run_bg "$PLAN"
  wait_for "$STUB/containers/${R9700_CONTAINER_PREFIX}prefix-base-2.pid" 300
  append_answer ram 100
  run_end
  assert_eq "5" "$SRC" "a RAM stop at step 2 and a restore that fails: 5"
  assert_eq "done 0|stopped 7|not-started -" "$(printf '%s|%s|%s' "$(run_state 1)" "$(run_state 2)" "$(run_state 3)")" "run.txt keeps step 2's own code"
}

# ---- R20: a signal before the first step and between steps -----------------------------------------------------------------------------------------------------------

t_r20_a_signal_before_the_first_step_and_between_steps_is_clean() {
  run_setup "$FUNCNAME"
  plan_fixture three_steps
  export R9700_TEST_RUN_HOLD_S=30 R9700_TEST_RUN_HOLD_AT=1
  run_bg "$PLAN"
  local run
  run="$(run_dir_of)"
  wait_for "$run/hold-1" 200
  kill -TERM "$SUP"
  run_end
  assert_eq "143" "$SRC" "(a) exit 143"
  assert_eq "not-started -|not-started -|not-started -" "$(printf '%s|%s|%s' "$(run_state 1)" "$(run_state 2)" "$(run_state 3)")" "(a) run.txt: every step not-started"
  assert_not_contains "$(cat "$run/run.txt")" "interrupted" "(a) no interrupted line"
  assert_missing "$MARKER_FILE" "(a) no marker"
  assert_eq "0" "$(log_count pwsh.exe -Detach)" "(a) no restore call: nothing was stopped"
  assert_eq "0" "$(stop_lines)" "(a) and no stop"
  assert_exit 0 "(a) the lock is free" -- bash -c 'flock -n 9' 9>> "$R9700_STATE_DIR/lock"
  # (b) between two steps
  rm -rf "$R9700_RESULTS_DIR/runs" "$RECS"
  export R9700_TEST_RUN_HOLD_AT=2
  run_bg "$PLAN"
  run="$(run_dir_of)"
  wait_for "$run/hold-2" 600
  kill -TERM "$SUP"
  run_end
  assert_eq "143" "$SRC" "(b) exit 143"
  assert_eq "done 0|not-started -|not-started -" "$(printf '%s|%s|%s' "$(run_state 1)" "$(run_state 2)" "$(run_state 3)")" "(b) run.txt: step 1 done, no interrupted line"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "(b) one restore"
  assert_missing "$MARKER_FILE" "(b) the marker is gone"
  assert_exit 0 "(b) the lock is free" -- bash -c 'flock -n 9' 9>> "$R9700_STATE_DIR/lock"
  assert_exit 0 "(c) R10 stays the during-a-step case" -- declare -F t_r10_a_term_during_step_2_ends_the_chain_with_143_one_restore_and_run_txt_says_interrupted
}

t_r20d_a_signal_between_a_steps_final_state_and_the_next_step_leaves_that_state() {
  run_setup "$FUNCNAME"
  plan_fixture three_steps
  export R9700_TEST_RUN_HOLD_S=30 R9700_TEST_RUN_HOLD_AT=1-end
  run_bg "$PLAN"
  local run
  run="$(run_dir_of)"
  assert_exit 0 "step 1 reached its end hold" -- wait_for "$run/hold-1-end" 600
  assert_eq "done 0" "$(run_state 1)" "step 1's final state is written before the hold"
  kill -TERM "$SUP"
  run_end
  assert_eq "143" "$SRC" "exit 143"
  assert_eq "done 0|not-started -|not-started -" "$(printf '%s|%s|%s' "$(run_state 1)" "$(run_state 2)" "$(run_state 3)")" "run.txt: step 1 stays done, never interrupted or running"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
}

# ---- R23: the machine file is the same for the whole night ------------------------------------------------------------------------------------------------------------

t_r23_a_machine_file_edited_during_the_night_is_refused_at_the_next_step() {
  run_setup "$FUNCNAME"
  plan_write r23 "prefixtest $KMODEL --name a" "prefixtest $KMODEL --name b"
  # MAX_SERVER_STOPS, PROD_CONTAINER and the RESTORE_* fields of the final restore are in machine.env: an edit between two steps must not change them under a running chain
  printf 'printf "# edited in the night\\n" >> "%s"\n' "$CASE/machine.env" > "$STUB/on-stop-${R9700_CONTAINER_PREFIX}prefix-base-1"
  assert_exit 2 "the plan" -- r9700 run "$PLAN"
  local err="$ERR"
  assert_contains "$err" "r9700: run: $CASE/machine.env changed since the run began" "named, with the file"
  assert_contains "$err" "r9700: run: stopped at step 2 of 2 (prefixtest $KMODEL --name b): 2" "the place"
  assert_eq "done 0|stopped 2" "$(printf '%s|%s' "$(run_state 1)" "$(run_state 2)")" "run.txt"
  assert_exit 0 "step 1's record is final" -- test -d "$RECS/prefix/a"
  assert_eq "1" "$(grep -c ' admitted$' "$(last_run_dir)/supervisor.log")" "step 2 was never admitted"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "one restore"
  assert_exit 0 "the server is back" -- test -f "$STUB/containers/vllm.pid"
}

# ---- R21: the worst case is printed, not refused ---------------------------------------------------------------------------------------------------------------------

t_r21_check_prints_the_worst_case_and_refuses_nothing_for_it() {
  run_setup "$FUNCNAME"
  local n lines=()
  for n in 1 2 3 4 5 6 7 8 9 10; do lines+=("prefixtest $KMODEL --name p$n"); done
  plan_write ten "${lines[@]}"
  assert_exit 0 "a ten-step plan with MAX_SERVER_STOPS=3" -- r9700 run "$PLAN" --check
  assert_contains "$OUT" "run: at most 10 stops of the operator's server if every step is admitted after a busy wait; MAX_SERVER_STOPS=3" "the worst case, in one line"
  assert_eq "10" "$(grep -c '^run: step [0-9]*: ok (' <<< "$OUT")" "every step is ok"
}

# ---- the README's example is a plan ----------------------------------------------------------------------------------------------------------------------------------

t_r22_the_example_plan_of_the_readme_passes_check_and_the_scan_still_finds_it() {
  run_setup "$FUNCNAME"
  awk '/^# night.plan$/ { go = 1; next } go && /^```/ { exit } go { print }' "$REPO/README.md" > "$CASE/readme.plan"
  assert_eq "yes" "$([ "$(grep -c '^[a-z]' "$CASE/readme.plan")" -ge 4 ] && echo yes)" "the scan found the example's four steps (a scan of nothing proves nothing)"
  assert_exit 0 "run --check of the README's example" -- r9700 run "$CASE/readme.plan" --check
  assert_eq "4" "$(grep -c '^run: step [0-9]: ok (' <<< "$OUT")" "every step is ok"
}

run_all_tests
