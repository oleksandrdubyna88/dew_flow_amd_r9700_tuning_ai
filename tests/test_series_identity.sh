#!/usr/bin/env bash
# `bin/r9700 series` (E1.S3): the run identity. Scenarios S7-S10, S19 and S20 of the story, F7 and F8 (the generation config and the model path in
# the throwaway container), and the refusals of the arguments. A resume skips exactly what is recorded and refuses an experiment that is not the
# same one, naming what differs, BEFORE anything is stopped. Every test body is a function t_<guarantee>; each runs in its own subshell.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"
# shellcheck source=tests/lib/lifecycle.sh
source "$HERE/lib/lifecycle.sh"
# shellcheck source=tests/lib/seriescase.sh
source "$HERE/lib/seriescase.sh"

MODEL_27B="$REPO/models/qwen3.8-27b-awq.env"

# ---- S7: a resume skips exactly the recorded arm-rounds -------------------------------------------------------------------------------------------

t_s7_a_resume_skips_exactly_the_recorded_arm_rounds_and_a_finished_series_admits_nothing() {
  series_setup "$FUNCNAME"
  local out n m sums
  out="$(outdir)"
  sr fbase fcombo --out s --rounds 1 > /dev/null 2>&1
  n="$(wc -l < "$STUB/calls.log")"
  assert_exit 0 "the same command again" -- sr fbase fcombo --out s --rounds 1
  assert_contains "$OUT" "series: 2 of 2 arm-rounds recorded, nothing to do" "it says so"
  assert_eq "0" "$(calls_since "$n" | grep -c ' wslc run -d \| wslc stop vllm\|pwsh.exe')" "no run -d, no stop vllm and no pwsh.exe in the second call log"
  m="$(wc -l < "$STUB/calls.log")"
  sums="$(cd "$out/rounds" && stat -c '%n %Y' fbase-1 fcombo-1)"
  sleep 1.1 # the next records get a modification time the first ones cannot have
  assert_exit 0 "the same series with two rounds" -- sr fbase fcombo --out s --rounds 2
  assert_contains "$OUT" "fingerprint: rounds extended 1 -> 2" "more rounds are said to be an extension"
  assert_eq "r9700tune-sp-fbase-2 r9700tune-sp-fcombo-2" "$(starts | tail -n 2 | tr '\n' ' ' | sed 's/ $//')" "the container starts are exactly fbase-2, fcombo-2"
  assert_eq "4" "$(starts | wc -l | tr -d ' ')" "four starts in all"
  assert_eq "1" "$(calls_since "$m" | grep -c ' wslc stop vllm')" "one stop of the operator's server for the second invocation"
  assert_eq "$sums" "$(cd "$out/rounds" && stat -c '%n %Y' fbase-1 fcombo-1)" "the round-1 records were not touched (same modification times)"
  assert_eq "2" "$(json_get "$out/fingerprint.json" 'd["components"]["rounds"]')" "the fingerprint holds the larger count now"
  assert_exit 2 "fewer rounds than the fingerprint holds are a difference" -- sr fbase fcombo --out s --rounds 1
  assert_contains "$ERR" "fingerprint differs: rounds: 2 -> 1" "named"
}

# ---- S8-S10: what differs is refused, naming it, before anything is stopped ------------------------------------------------------------------------

t_s8_a_resume_with_a_changed_max_num_seqs_is_refused_naming_the_component_before_any_stop() {
  series_setup "$FUNCNAME"
  local n pidmtime
  sr fbase fcombo --out s --rounds 1 > /dev/null 2>&1
  sed 's/^MAX_NUM_SEQS=4$/MAX_NUM_SEQS=8/' "$MODEL_35B" > "$CASE/model8.env"
  n="$(wc -l < "$STUB/calls.log")"
  pidmtime="$(stat -c %Y "$STUB/containers/vllm.pid")"
  assert_exit 2 "a model variant with MAX_NUM_SEQS=8" -- srm "$CASE/model8.env" fbase fcombo --out s --rounds 1
  assert_contains "$ERR" "fingerprint differs: model.max_num_seqs: 4 -> 8" "the line names the component, old and new"
  assert_eq "0" "$(calls_since "$n" | grep -c ' wslc stop ')" "no stop of anything"
  assert_eq "$pidmtime" "$(stat -c %Y "$STUB/containers/vllm.pid")" "the operator's server was never touched"
  assert_eq "0" "$(calls_since "$n" | grep -c 'pwsh.exe')" "and never restarted"
}

t_s9_a_changed_patch_file_is_refused_naming_the_file() {
  series_setup "$FUNCNAME"
  sr fbase fcombo --out s --rounds 1 > /dev/null 2>&1
  printf 'x' >> "$CASE/patches/C/auto_gptq.py"
  assert_exit 2 "a patch file with one byte more" -- sr fbase fcombo --out s --rounds 1
  if [[ $ERR =~ fingerprint\ differs:\ patches\.C/auto_gptq\.py:\ ([0-9a-f]{64})\ -\>\ ([0-9a-f]{64}) && ${BASH_REMATCH[1]} != "${BASH_REMATCH[2]}" ]]; then assert_eq ok ok "the line names the file, both hashes 64 hex and different"; else assert_eq "patches.C/auto_gptq.py: <old> -> <new>" "$ERR" "the line names the file"; fi
}

t_s10_a_changed_model_listing_is_refused_and_a_new_arm_is_an_extension_and_another_base_is_refused() {
  series_setup "$FUNCNAME"
  local out before after
  out="$(outdir)"
  sr fbase fcombo --out s --rounds 1 > /dev/null 2>&1
  printf 'a.safetensors 101\nconfig.json 10\n' > "$STUB/answers/find"
  assert_exit 2 "a file of the model listing with another size" -- sr fbase fcombo --out s --rounds 1
  assert_contains "$ERR" "fingerprint differs: model.listing: " "named"
  printf 'a.safetensors 100\nconfig.json 10\n' > "$STUB/answers/find"
  before="$(json_get "$out/fingerprint.json" 'json.dumps([d["components"]["arms"]["fbase"], d["components"]["arms"]["fcombo"]], sort_keys=True)')"
  assert_exit 0 "the original listing and a third arm" -- sr fbase fcombo fb1 --out s --rounds 1
  assert_contains "$OUT" "fingerprint: arm fb1 added" "the extension is said"
  after="$(json_get "$out/fingerprint.json" 'json.dumps([d["components"]["arms"]["fbase"], d["components"]["arms"]["fcombo"]], sort_keys=True)')"
  assert_eq "$before" "$after" "the old arms are unchanged"
  assert_eq "['VLLM_TUNED_CONFIG_FOLDER=/work/moe/tune/merged_b1']" "$(json_get "$out/fingerprint.json" 'd["components"]["arms"]["fb1"]["env"]')" "fingerprint.json now holds arms.fb1 with its environment"
  assert_exit 0 "rounds/fb1-1 exists" -- test -f "$out/rounds/fb1-1/record.env"
  assert_eq "True" "$(json_get "$out/fingerprint.json" 'd["sha256"] == __import__("hashlib").sha256(json.dumps(d["components"], sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()).hexdigest()')" "the rewritten document's hash is the hash of its components"
  assert_exit 2 "another base" -- sr fcombo fbase --out s --rounds 1
  assert_contains "$ERR" "fingerprint differs: base: fbase -> fcombo" "named"
}

# ---- F7, F8: the throwaway container's program -------------------------------------------------------------------------------------------------

t_f7_a_changed_generation_config_is_refused_and_the_program_reads_nested_and_hidden_files() {
  series_setup "$FUNCNAME"
  local program gen tree out
  sr fbase --out s --rounds 1 > /dev/null 2>&1
  printf 'generation_config.json %s\nsub/.hidden.json %s\n' "$(printf '0%.0s' $(seq 1 64))" "$(printf '1%.0s' $(seq 1 64))" > "$STUB/answers/genconfig"
  assert_exit 2 "a generation config that changed" -- sr fbase --out s --rounds 1
  assert_contains "$ERR" "fingerprint differs: genconfig: " "named"
  # the program the container runs is real shell: run it here on a tree with a nested and a hidden file (and a space in a name)
  argv_of wslc
  program=""
  local i
  for i in "${!ARGV[@]}"; do [ "${ARGV[$i]}" = -c ] && program="${ARGV[$((i + 1))]}"; done
  assert_contains "$program" 'find . -type f -print0' "it walks everything under /genconfig, hidden files included"
  tree="$CASE/gen"
  mkdir -p "$tree/sub/deeper" "$CASE/model/inner"
  printf 'a' > "$tree/generation_config.json"
  printf 'b' > "$tree/sub/.hidden.json"
  printf 'c' > "$tree/sub/deeper/with space.txt"
  printf '1234567' > "$CASE/model/inner/w.bin"
  printf '1' > "$CASE/model/config.json"
  out="$(sh -c "$program" sh "$CASE/model" "$tree")"
  assert_eq "config.json 1|inner/w.bin 7" "$(sed '/^---$/,$d' <<< "$out" | tr '\n' '|' | sed 's/|$//')" "the listing: relative path and size, sorted"
  assert_eq "generation_config.json $(printf a | sha256sum | cut -c1-64)|sub/.hidden.json $(printf b | sha256sum | cut -c1-64)|sub/deeper/with space.txt $(printf c | sha256sum | cut -c1-64)" "$(sed '1,/^---$/d' <<< "$out" | tr '\n' '|' | sed 's/|$//')" "the generation config: every file, nested and hidden included, <path> <sha256>, sorted"
}

t_f8_the_model_path_reaches_the_throwaway_container_as_one_argument_and_no_command_runs() {
  series_setup "$FUNCNAME"
  local out bad="/m; touch $CASE/pwned; #" program i
  sed "s|^MODEL_DIR=.*|MODEL_DIR=\"$bad\"|" "$MODEL_35B" > "$CASE/modelbad.env"
  assert_exit 0 "a series whose MODEL_DIR holds ; and #" -- srm "$CASE/modelbad.env" fbase --out s --rounds 1
  assert_missing "$CASE/pwned" "no command ran"
  mapfile -t ARGV < <(awk 'BEGIN { RS = ""; ORS = "\n" } { n = split($0, l, "\n"); if (l[2] == "run" && l[3] == "--rm") for (i = 2; i <= n; i++) if (l[i] != "") print l[i] }' "$STUB/calls.argv")
  assert_eq "1" "$(printf '%s\n' "${ARGV[@]}" | grep -cxF -- "$bad")" "the path is ONE element of the argv"
  program=""
  for i in "${!ARGV[@]}"; do [ "${ARGV[$i]}" = -c ] && program="${ARGV[$((i + 1))]}"; done
  assert_not_contains "$program" "pwned" "and it is not text inside the program"
  assert_not_contains "$program" "touch" "not even a part of it"
  out="$(outdir)"
  assert_eq "$bad" "$(json_get "$out/fingerprint.json" 'd["components"]["model"]["dir"]')" "the fingerprint holds the path as it is"
}

t_a_model_listing_or_a_generation_config_that_is_missing_or_garbled_is_refused_before_anything_is_stopped() {
  series_setup "$FUNCNAME"
  : > "$STUB/answers/find"
  assert_exit 2 "an empty model listing" -- sr fbase --out s --rounds 1
  assert_contains "$ERR" "series: the model listing of /root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ is empty" "named"
  printf 'a.safetensors 100\n' > "$STUB/answers/find"
  : > "$STUB/answers/genconfig"
  assert_exit 2 "a generation config folder with no file" -- sr fbase --out s --rounds 1
  assert_contains "$ERR" "series: /genconfig holds no file" "named"
  printf 'wslc: image not found\n' > "$STUB/answers/find"
  printf 'g %s\n' "$(printf '0%.0s' $(seq 1 64))" > "$STUB/answers/genconfig"
  assert_exit 2 "an answer that is not a listing" -- sr fbase --out s --rounds 1
  assert_contains "$ERR" "series: the throwaway container did not answer with a model listing" "named"
  assert_eq "0" "$(prod_stops)" "nothing was stopped"
  assert_eq "0" "$(starts | wc -l | tr -d ' ')" "and nothing was started"
}

# ---- S19, S20: the dry run and the files the container needs ------------------------------------------------------------------------------------

t_s19_dry_run_prints_the_resolved_commands_and_starts_no_server() {
  series_setup "$FUNCNAME" "$MODEL_27B"
  local out
  out="$(outdir d)"
  assert_exit 0 "series --dry-run with the 27B model file" -- srm "$MODEL_27B" fbase --out d --rounds 1 --dry-run
  assert_eq "1" "$(grep -c ' wslc run --rm ' "$STUB/calls.log")" "the call log has the one throwaway run --rm"
  assert_eq "0" "$(starts | wc -l | tr -d ' ')" "no run -d of a test container"
  assert_eq "0" "$(prod_stops)" "no stop vllm"
  assert_eq "0" "$(log_count pwsh.exe -Detach)" "no pwsh.exe"
  assert_contains "$OUT" "dry-run: wslc run -d --rm --name r9700tune-sp-fbase-1 " "the resolved run line, with the arm's container name"
  assert_contains "$OUT" "--max-model-len 16384" "the 27B context"
  assert_contains "$OUT" "--max-num-seqs 16" "the 27B sequences"
  assert_contains "$OUT" "--speculative-config.num_speculative_tokens 2" "the arm's own arguments"
  assert_contains "$OUT" "dry-run: bench c=1 r=1: wslc exec r9700tune-sp-fbase-1 vllm bench serve " "the bench command"
  assert_contains "$OUT" "--model qwen3.8-27b" "with the 27B served name"
  assert_contains "$OUT" "dry-run: prefill 8192 r=1: wslc exec r9700tune-sp-fbase-1 vllm bench serve " "the prefill command of the one length"
  assert_not_contains "$OUT" "prefill 32768" "and no other length"
  assert_contains "$OUT" "dry-run: quality collect: wslc exec r9700tune-sp-fbase-1 python3 /work/r9700/harness.py collect " "the quality commands"
  assert_contains "$OUT" "dry-run: quality gsm8k: wslc exec r9700tune-sp-fbase-1 python3 /work/r9700/harness.py gsm8k " "both"
  assert_missing "$out" "a dry run on a new outdir writes nothing: not even the folder"
  assert_eq "0" "$(find "$R9700_RESULTS_DIR" -name 'fingerprint.json' | wc -l | tr -d ' ')" "and no fingerprint.json anywhere"
}

t_s20_harness_py_is_placed_in_the_work_directory_with_its_hash_checked_and_missing_gsm8k_data_is_refused_before_round_1() {
  series_setup "$FUNCNAME"
  local n
  assert_exit 0 "a stub series" -- sr fbase --out s --rounds 1
  assert_eq "$(sha256sum < "$REPO/lib/harness.py")" "$(sha256sum < "$R9700_WORK_DIR/r9700/harness.py")" "r9700/harness.py in the work directory equals lib/harness.py"
  assert_eq "$(json_get "$(outdir)/fingerprint.json" 'd["components"]["tools"]["harness_py"]')" "$(sha256sum < "$R9700_WORK_DIR/r9700/harness.py" | cut -c1-64)" "and the fingerprint's hash"
  assert_eq "0" "$(ls "$R9700_WORK_DIR/r9700" | grep -c '\.part$')" "no part file is left"
  rm "$CASE/work/gsm8k/test.jsonl"
  n="$(wc -l < "$STUB/calls.log")"
  assert_exit 2 "with the GSM8K file missing and round 1 to run (a new arm)" -- sr fbase fcombo --out s --rounds 1
  assert_contains "$ERR" "series: GSM8K_DATA /work/gsm8k/test.jsonl not found at $CASE/work/gsm8k/test.jsonl" "the line names the file"
  assert_eq "0" "$(calls_since "$n" | grep -c ' wslc run -d \| wslc stop vllm')" "before any run -d and any stop"
  step_cfg GSM8K_DATA=/data/x.jsonl
  assert_exit 0 "a GSM8K file outside /work" -- sr fbase --out s2 --rounds 1
  assert_contains "$OUT" "series: GSM8K_DATA /data/x.jsonl is not under /work, not checked" "is not checked, and says so"
  assert_exit 0 "and the series proceeds" -- test -f "$(outdir s2)/rounds/fbase-1/record.env"
}

# ---- the arguments ---------------------------------------------------------------------------------------------------------------------------------

t_the_arguments_of_series_are_checked_before_the_lock_and_name_the_legal_values() {
  series_setup "$FUNCNAME"
  rmdir "$R9700_STATE_DIR" 2> /dev/null || rm -rf "$R9700_STATE_DIR"
  local before
  before="$(wc -l < "$STUB/calls.log")"
  assert_exit 2 "no model" -- r9700 series
  assert_contains "$ERR" "r9700: series: usage: " "the usage line"
  assert_exit 2 "a model and no arm" -- r9700 series "$SERIES_MODEL"
  assert_contains "$ERR" "at least one arm" "an arm is needed"
  assert_exit 2 "rounds that is not a number" -- sr fbase --rounds x
  assert_contains "$ERR" "--rounds" "names the option"
  assert_exit 2 "zero rounds" -- sr fbase --rounds 0
  assert_exit 2 "too many rounds" -- sr fbase --rounds 21
  assert_exit 2 "a name that is a path" -- sr fbase --out ../x
  assert_contains "$ERR" "--out" "names the option"
  assert_exit 2 "an arm name that is not one" -- sr 'Fb ase'
  assert_exit 2 "the same arm twice" -- sr fbase fbase
  assert_contains "$ERR" "twice" "named"
  assert_exit 2 "an unknown option" -- sr fbase --nosuch
  assert_contains "$ERR" "legal: " "the legal options"
  assert_exit 2 "--out without a value" -- sr fbase --out
  assert_missing "$R9700_STATE_DIR" "none of them took the lock or made the state directory"
  assert_eq "$before" "$(wc -l < "$STUB/calls.log")" "and none called a stub"
}

t_an_arm_that_is_not_in_the_arm_table_or_has_a_name_too_long_for_a_container_is_refused_before_anything_is_stopped() {
  series_setup "$FUNCNAME"
  assert_exit 2 "an arm that is not in config/arms.conf" -- sr nosucharm --out s --rounds 1
  assert_contains "$ERR" 'arm "nosucharm" is not in' "named"
  assert_contains "$ERR" "legal: " "with the legal ones"
  assert_eq "0" "$(prod_stops)" "nothing was stopped"
  cp "$REPO/config/arms.conf" "$CASE/arms.conf"
  printf 'a%.0s' $(seq 1 40) > "$CASE/longname"
  printf '%s | --x | |\n' "$(cat "$CASE/longname")" >> "$CASE/arms.conf"
  assert_exit 2 "an arm whose container label would be longer than 40 characters" -- env R9700_ARMS_CONF="$CASE/arms.conf" "$REPO/bin/r9700" series "$SERIES_MODEL" "$(cat "$CASE/longname")" --out s --rounds 1
  assert_contains "$ERR" "container_name:" "container_name refuses it"
  assert_eq "0" "$(prod_stops)" "still nothing was stopped"
}

t_series_takes_the_lock_and_a_second_series_is_refused_with_exit_4() {
  series_setup "$FUNCNAME"
  ( exec 9> "$R9700_STATE_DIR/lock"; flock -n 9; : > "$CASE/held"; exec sleep 30 ) &
  local holder=$!
  disown "$holder"
  guard_pid "$holder" "holder-$holder"
  wait_for "$CASE/held"
  assert_exit 4 "a series while the lock is held" -- sr fbase --out s --rounds 1
  assert_contains "$ERR" "r9700: another run holds " "the S2 line"
  assert_eq "0" "$(prod_stops)" "nothing was stopped"
  kill -KILL "$holder"
}

# ---- a dry run never changes the identity of a series -------------------------------------------------------------------------------------------

t_a_dry_run_with_more_rounds_and_an_extra_arm_leaves_fingerprint_json_byte_identical_and_still_refuses_a_difference() {
  series_setup "$FUNCNAME"
  local out sum
  out="$(outdir)"
  sr fbase fcombo --out s --rounds 3 --dry-run > /dev/null 2>&1
  assert_missing "$out/fingerprint.json" "a dry run on a folder with no fingerprint writes none"
  sr fbase fcombo --out s --rounds 1 > /dev/null 2>&1
  sum="$(sha256sum < "$out/fingerprint.json")"
  assert_exit 0 "a dry run asking for 5 rounds and a third arm" -- sr fbase fcombo fb1 --out s --rounds 5 --dry-run
  assert_contains "$OUT" "fingerprint: arm fb1 added" "it still says what it would extend"
  assert_eq "$sum" "$(sha256sum < "$out/fingerprint.json")" "fingerprint.json is byte-identical"
  assert_eq "1" "$(json_get "$out/fingerprint.json" 'd["components"]["rounds"]')" "the round count is still 1"
  assert_exit 2 "a dry run with another base is refused like a real one" -- sr fcombo fbase --out s --rounds 1 --dry-run
  assert_contains "$ERR" "fingerprint differs: base: fbase -> fcombo" "naming it"
  assert_eq "$sum" "$(sha256sum < "$out/fingerprint.json")" "and still nothing was written"
  assert_eq "0" "$(find "$out" -maxdepth 1 -name '.fingerprint-inputs*' | wc -l | tr -d ' ')" "no input folder is left in the outdir"
}

t_a_deleted_fingerprint_json_refuses_the_start_when_records_exist_and_names_the_remedy() {
  series_setup "$FUNCNAME"
  local out n
  out="$(outdir)"
  sr fbase --out s --rounds 1 > /dev/null 2>&1
  rm "$out/fingerprint.json"
  n="$(wc -l < "$STUB/calls.log")"
  assert_exit 2 "an outdir with records and no fingerprint" -- sr fbase fcombo --out s --rounds 1
  assert_contains "$ERR" "series: $out has rounds/ or rejected/ but no fingerprint.json" "the line says what is missing"
  assert_contains "$ERR" "--out" "and names the remedy: a new --out name"
  assert_missing "$out/fingerprint.json" "nothing was built over the records"
  assert_eq "0" "$(calls_since "$n" | grep -c ' wslc stop \| wslc run -d ')" "before any stop"
  mkdir "$CASE/results/r" "$CASE/results/r/rejected"
  assert_exit 2 "a folder with only rejected/ is refused too" -- sr fbase --out r --rounds 1
  mkdir "$CASE/results/r2" "$CASE/results/r2/rounds"
  assert_exit 2 "a DRY run is refused the same way" -- sr fbase --out r2 --rounds 1 --dry-run
  assert_contains "$ERR" "has rounds/ or rejected/ but no fingerprint.json" "with the same line"
  assert_missing "$CASE/results/r2/fingerprint.json" "and writes nothing"
  mkdir "$CASE/results/e"
  assert_exit 0 "an empty folder is a new series" -- sr fbase --out e --rounds 1
}

# ---- a TERM during the throwaway container --------------------------------------------------------------------------------------------------------

t_a_term_during_a_hanging_throwaway_container_ends_the_supervisor_within_seconds_with_143_and_nothing_stopped() {
  series_setup "$FUNCNAME"
  : > "$STUB/hang-foreground-run"
  local i start end pid
  start="$(date +%s.%N)"
  series_bg fbase --out s --rounds 1
  for i in $(seq 1 100); do grep -q ' wslc run --rm ' "$STUB/calls.log" 2> /dev/null && break; sleep 0.1; done
  assert_exit 0 "the probe is running (and hangs)" -- grep -q ' wslc run --rm ' "$STUB/calls.log"
  sleep 0.3
  kill -TERM "$SUP"
  step_end
  end="$(date +%s.%N)"
  assert_eq "143" "$SRC" "exit 143"
  assert_exit 0 "within 6 s of the start (the probe's own ceiling is 12 s here)" -- awk -v a="$start" -v b="$end" 'BEGIN { exit !(b - a < 6) }'
  assert_eq "0" "$(prod_stops)" "the operator's server was never stopped"
  assert_eq "0" "$(log_count pwsh.exe -Detach)" "so nothing was restored"
  assert_exit 0 "and it still runs" -- test -f "$STUB/containers/vllm.pid"
  for i in $(seq 1 20); do ls "$STUB"/hung/containers/*.pid > /dev/null 2>&1 && break; sleep 0.1; done
  read -r pid _ < "$(ls "$STUB"/hung/containers/*.pid | head -n 1)"
  assert_exit 0 "the hung call's process is gone" -- gone "$pid"
}

# ---- A23: resume by name ------------------------------------------------------------------------------------------------------------------------

t_the_default_out_is_the_model_name_without_a_date_the_outdir_is_the_first_line_and_the_same_command_resumes() {
  series_setup "$FUNCNAME"
  local out="$R9700_RESULTS_DIR/$SERIES_MODEL" first
  assert_exit 0 "a series with no --out" -- r9700 series "$SERIES_MODEL" fbase --rounds 1
  first="$(sed -n 1p <<< "$OUT")"
  assert_eq "series: outdir $out" "$first" "the first line of stdout names the outdir"
  assert_exit 0 "fbase-1 is recorded under the model's name" -- test -f "$out/rounds/fbase-1/record.env"
  assert_exit 0 "the same command again (the name has no date, so it is the same on any day)" -- r9700 series "$SERIES_MODEL" fbase --rounds 1
  assert_contains "$OUT" "nothing to do" "it resumes the same outdir"
  assert_eq "1" "$(ls "$R9700_RESULTS_DIR" | grep -vc '^runs$')" "one results folder, no second one with a date"
  mkdir -p "$CASE/m"
  cp "$MODEL_35B" "$CASE/m/mymodel.env"
  assert_exit 0 "a model FILE: the name is the file's name without .env" -- srm "$CASE/m/mymodel.env" fbase --rounds 1 --dry-run
  assert_eq "series: outdir $R9700_RESULTS_DIR/mymodel" "$(sed -n 1p <<< "$OUT")" "also for a dry run"
}

# ---- A24: the fingerprint's tools are every module a unit runs ----------------------------------------------------------------------------------

t_the_tools_component_hashes_every_module_a_unit_sources_or_calls() {
  series_setup "$FUNCNAME"
  local out keys mod
  out="$(outdir)"
  assert_exit 0 "a stub series" -- sr fbase --out s --rounds 1
  keys="$(json_get "$out/fingerprint.json" '" ".join(sorted(d["components"]["tools"]))')"
  for mod in adapter_sh bench_sh config_sh disk_gate_sh guard_quiet_sh run_guarded_sh serve_sh series_sh wait_ready_sh fingerprint_py harness_py verdict_py; do
    assert_contains " $keys " " $mod " "tools.$mod is hashed"
  done
  assert_eq "$(sha256sum < "$REPO/lib/wait_ready.sh" | cut -c1-64)" "$(json_get "$out/fingerprint.json" 'd["components"]["tools"]["wait_ready_sh"]')" "and its value is the sha256 of the file"
}

t_a_module_changed_between_two_arm_rounds_makes_the_second_refuse() {
  series_setup "$FUNCNAME"
  mkdir -p "$CASE/repo"
  cp -r "$REPO/bin" "$REPO/lib" "$REPO/config" "$REPO/models" "$CASE/repo/" # a copy of the toolkit: the test edits ITS lib, never the repository's
  REPO="$CASE/repo"
  printf 'printf "# edited\\n" >> "%s/repo/lib/wait_ready.sh"\n' "$CASE" > "$STUB/on-stop-r9700tune-sp-fbase-1"
  local out
  out="$(outdir)"
  assert_exit 2 "lib/wait_ready.sh is edited while the first arm-round runs" -- sr fbase fcombo --out s --rounds 1
  assert_contains "$ERR" "fingerprint differs: tools.wait_ready_sh: " "the line names the module"
  assert_exit 0 "fbase-1 is recorded" -- test -f "$out/rounds/fbase-1/record.env"
  assert_missing "$out/rounds/fcombo-1" "fcombo-1 is not"
}

run_all_tests
