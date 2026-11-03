#!/usr/bin/env bash
# The verbs `bin/r9700 linear-bench` and `bin/r9700 prefixtest` (E3.S1): the argument grammar and its refusals before the lock, the checks with the config, the files
# placed, the record of a name counted before admission and refused when it is another experiment, the dry runs, the two model fields. Scenarios KV1-KV8 and KW10 of
# the story, plus the two verbs end to end. Every test body is a function t_<guarantee>; each runs in its own subshell and writes only below $R9700_TEST_ROOT.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"
# shellcheck source=tests/lib/lifecycle.sh
source "$HERE/lib/lifecycle.sh"
# shellcheck source=tests/lib/kernelcase.sh
source "$HERE/lib/kernelcase.sh"

MODEL_27B="$REPO/models/qwen3.8-27b-awq.env"

# kv_setup <name> [<model file>]: kernels_setup, with the placed files REMOVED: the verb places them
kv_setup() {
  kernels_setup "$1" "${2:-}"
  rm -f "$WORK/linear_bench.py" "$WORK/prefixtest.py"
}

lb() { r9700 linear-bench "$KMODEL" "$@"; }

pt() { r9700 prefixtest "$KMODEL" "$@"; }

calls_n() { wc -l < "$STUB/calls.log" | tr -d ' '; }

# refused_before_lock <name> <expected stderr text> <verb> <args...>: exit 2, the text on stderr, no lock file, no call at all
refused_before_lock() {
  local name="$1" want="$2" before
  shift 2
  before="$(calls_n)"
  assert_exit 2 "$name" -- r9700 "$@"
  assert_contains "$ERR" "$want" "$name: the line says what is wrong"
  assert_eq "1" "$(printf '%s\n' "$ERR" | grep -c .)" "$name: one line"
  assert_missing "$R9700_STATE_DIR/lock" "$name: no lock was taken"
  assert_eq "$before" "$(calls_n)" "$name: nothing was called"
}

# ---- KV1: every refusal of the grammar is before the lock -----------------------------------------------------------------------------------------------------------------

t_kv1_every_refusal_of_the_grammar_comes_before_the_lock_with_one_line() {
  kv_setup "$FUNCNAME"
  local m="$KMODEL"
  refused_before_lock "linear-bench without a model" "r9700: linear-bench: usage: linear-bench <model file or name> [options]" linear-bench
  refused_before_lock "an unknown option" 'r9700: linear-bench: unknown option "--frob"; legal: --name, --ms, --sweep-ms, --timer, --out, --dry-run' linear-bench "$m" --frob
  refused_before_lock "an option of the other verb" 'unknown option "--arm"; legal: --name, --ms' linear-bench "$m" --arm base
  refused_before_lock "a name with a bad character" '--name "N_1" is not ^[a-z0-9][a-z0-9-]{0,30}$' linear-bench "$m" --name N_1
  refused_before_lock "a timer that is not one" '--timer "x" is not one of: graph eager' linear-bench "$m" --timer x
  refused_before_lock "a sweep M outside --ms" 'sweep M 7 is not in --ms "1 2"' linear-bench "$m" --ms "1 2" --sweep-ms 7
  refused_before_lock "an --ms that is not numbers" '--ms "1 x" is not a list of positive integers' linear-bench "$m" --ms "1 x"
  refused_before_lock "a repeated M" 'repeats a value' linear-bench "$m" --ms "1 1"
  refused_before_lock "an option without its value" "--ms needs a value" linear-bench "$m" --ms
  refused_before_lock "an outdir that is a path" '--out "../x" is not a name' linear-bench "$m" --out ../x
  refused_before_lock "a second model" 'unexpected argument "other"' linear-bench "$m" other
  refused_before_lock "prefixtest without a model" "r9700: prefixtest: usage: prefixtest <model file or name> [options]" prefixtest
  refused_before_lock "an unknown option of prefixtest" 'unknown option "--timer"; legal: --name, --arm, --lens, --tail, --out, --dry-run' prefixtest "$m" --timer graph
  refused_before_lock "an arm that is not a name" '--arm "Base" is not an arm name' prefixtest "$m" --arm Base
  refused_before_lock "lens that are not numbers" '--lens "x" is not a list of positive integers' prefixtest "$m" --lens x
  refused_before_lock "a tail that is not below the shortest length" '--tail 1024 is not below the shortest length 1024' prefixtest "$m" --lens "8192 1024" --tail 1024
  refused_before_lock "a tail of zero" '--tail "0" is not a positive whole number' prefixtest "$m" --tail 0
  assert_exit 0 "the operator's server is untouched" -- test -f "$STUB/containers/vllm.pid"
}

# ---- KV2, KV3: what needs the config is refused after the restore-first and before any stop ---------------------------------------------------------------------------

t_kv2_an_empty_linear_shapes_is_refused_after_the_restore_first_and_before_any_stop() {
  kv_setup "$FUNCNAME" "$MODEL_27B"
  wslc stop vllm > /dev/null
  write_marker
  assert_exit 2 "linear-bench of the 27B file (LINEAR_SHAPES is empty)" -- lb --ms "1 2" --sweep-ms 1
  assert_eq "r9700: recovery marker found (run hand-1), restoring first" "$(printf '%s\n' "$OUT" | head -n 1)" "the first stdout line is the marker's: the restore came first"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the restore ran"
  assert_contains "$ERR" "r9700: linear-bench: qwen3.8-27b-awq: LINEAR_SHAPES is empty: no shapes to time" "then the refusal names the model and the field"
  assert_eq "1" "$(stop_lines)" "no stop but the test's own"
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_exit 0 "prefixtest of the same file is not refused for it (it measures a server)" -- pt --dry-run
}

t_kv3_a_length_that_does_not_fit_the_context_is_refused_with_the_config() {
  kv_setup "$FUNCNAME" "$MODEL_27B"
  local before
  before="$(calls_n)"
  assert_exit 2 "the 27B file (MAX_MODEL_LEN=16384) with --lens 16384" -- pt --lens "16384" --tail 64
  assert_contains "$ERR" "len 16384 + 1 > MAX_MODEL_LEN 16384" "the line says why"
  assert_eq "0" "$(stop_lines)" "nothing was stopped"
  assert_exit 0 "a length that fits is not refused" -- pt --lens "16383" --tail 64 --dry-run
  assert_exit 2 "an arm that is not in the table" -- pt --arm nosuch --dry-run
  assert_contains "$ERR" 'arm "nosuch" is not in' "the arm table says so"
}

# ---- KV4: the dry runs print the real calls' words and start nothing ------------------------------------------------------------------------------------------------

t_kv4_the_dry_runs_print_the_words_of_the_real_calls_and_start_nothing() {
  kv_setup "$FUNCNAME"
  local before dry line
  before="$(calls_n)"
  assert_exit 0 "a linear dry run" -- lb --name n1 --ms "1 2 6" --sweep-ms 6 --dry-run
  dry="$(printf '%s\n' "$OUT" | grep '^dry-run: wslc run --rm --name r9700tune-linear-bench-1 ')"
  assert_contains "$OUT" "kernels: outdir $RECS" "the first line names the outdir"
  assert_eq "1" "$(printf '%s\n' "$OUT" | grep -c '^dry-run: wslc run --rm --name r9700tune-moe-clear ')" "and the clear's line"
  assert_eq "0" "$(calls_since "$before" | awk '$3 == "wslc" && $4 == "run" { n++ } END { print n + 0 }')" "no container was started"
  assert_eq "0" "$(stop_lines | tr -d ' ')" "nothing was stopped"
  assert_missing "$RECS" "nothing under the outdir"
  assert_exit 0 "the files are placed (a hash-checked copy, no record), as moe-tune does" -- cmp "$REPO/lib/linear_bench.py" "$WORK/linear_bench.py"
  assert_exit 0 "the same command for real" -- lb --name n1 --ms "1 2 6" --sweep-ms 6
  run_argv linear-bench-1
  line="dry-run: wslc ${ARGV[*]}"
  assert_eq "$line" "$dry" "the dry-run line is the real call's words"
  rm -rf "$RECS"
  before="$(calls_n)"
  assert_exit 0 "a prefix dry run" -- pt --name p1 --dry-run
  dry="$OUT"
  assert_eq "0" "$(calls_since "$before" | awk '$3 == "wslc" && $4 == "run" { n++ } END { print n + 0 }')" "no container was started"
  assert_missing "$RECS" "nothing under the outdir"
  assert_exit 0 "the same command for real" -- pt --name p1
  serve_argv prefix-base-1
  assert_contains "$dry" "dry-run: wslc ${ARGV[*]}" "the serve line is the real start's words"
  exec_argv prefix-base-1
  assert_contains "$dry" "dry-run: wslc ${ARGV[*]}" "the exec line is the real call's words"
  assert_contains "$dry" "dry-run: wslc stop r9700tune-prefix-base-1" "and the stop"
}

t_kv4b_a_dry_run_takes_the_lock() {
  kv_setup "$FUNCNAME"
  fake_supervisor run || return
  assert_exit 4 "a dry run while a run holds the lock" -- lb --dry-run
  assert_contains "$ERR" "r9700: another run holds $R9700_STATE_DIR/lock: pid $SUP, step" "the holder line"
  kill -KILL "$SUP"
  kill -KILL -- "-$(awk '{ print $1 }' "$STUB"/workers/containers/worker-*.pid | head -n 1)" 2> /dev/null
  kill_recorded_pids "$CASE"
}

# ---- the verbs end to end ----------------------------------------------------------------------------------------------------------------------------------------------

t_kv9_a_linear_bench_verb_places_the_files_records_the_unit_and_prints_the_table() {
  kv_setup "$FUNCNAME"
  assert_missing "$WORK/linear_bench.py" "the benchmark is not placed before"
  assert_exit 0 "linear-bench" -- lb --name n1 --ms "1 2 6" --sweep-ms 6
  assert_eq "kernels: outdir $RECS" "$(printf '%s\n' "$OUT" | head -n 1)" "the first stdout line names the outdir"
  assert_contains "$OUT" "recorded linear/n1" "the record is named"
  assert_contains "$OUT" "M  default_ms  triton_default_ms  split_ms  tuned_ms  change" "and the table follows"
  assert_exit 0 "linear_bench.py is placed, byte for byte" -- cmp "$REPO/lib/linear_bench.py" "$WORK/linear_bench.py"
  assert_exit 0 "prefixtest.py is placed too" -- cmp "$REPO/lib/prefixtest.py" "$WORK/prefixtest.py"
  assert_eq "1" "$(prod_stops)" "the operator's server was stopped once"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "and restored once"
  assert_contains "$(sup_log)" "cleanup hook: moe_cache_clear rc=0" "the cache clear ran in the exit path"
  assert_exit 0 "the record" -- test -s "$RECS/linear/n1/linear.env"
}

t_kv10_a_prefixtest_verb_records_the_unit_and_prints_the_ratios() {
  kv_setup "$FUNCNAME"
  assert_exit 0 "prefixtest" -- pt --name p1
  assert_contains "$OUT" "recorded prefix/p1" "the record is named"
  assert_contains "$OUT" "PREFIX p1 len=8192: cold 2.13 s, hit 0.50 s (4.3x), partial 0.49 s" "and the ratios follow"
  assert_eq "1" "$(prod_stops)" "the operator's server was stopped once"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "and restored once"
  assert_eq "0" "$(run_lines moe-clear | wc -l | tr -d ' ')" "no cache clear: this verb fills no Triton cache"
}

# ---- KV6, KW10: a recorded name is counted before admission; another experiment is refused ------------------------------------------------------------------------------

t_kv6_a_recorded_name_is_counted_before_admission_and_nothing_is_stopped() {
  kv_setup "$FUNCNAME"
  assert_exit 0 "a recorded linear/n1" -- lb --name n1 --ms "1 2 6" --sweep-ms 6
  local before
  before="$(calls_n)"
  assert_exit 0 "the same command again" -- lb --name n1 --ms "1 2 6" --sweep-ms 6
  assert_contains "$OUT" "recorded linear/n1, nothing to do" "it says so"
  assert_eq "0" "$(calls_since "$before" | awk '$3 == "wslc" && ($4 == "run" || $4 == "stop") { n++ } END { print n + 0 }')" "no run and no stop since"
  assert_missing "$MARKER_FILE" "no marker"
  assert_exit 0 "a recorded prefix/p1" -- pt --name p1
  before="$(calls_n)"
  assert_exit 0 "the same prefix command again" -- pt --name p1
  assert_contains "$OUT" "recorded prefix/p1, nothing to do" "it says so"
  assert_eq "0" "$(calls_since "$before" | awk '$3 == "wslc" && ($4 == "run" || $4 == "stop") { n++ } END { print n + 0 }')" "no run and no stop since"
}

t_kw10_a_reused_name_is_the_same_experiment_or_it_is_refused_naming_the_key() {
  kv_setup "$FUNCNAME"
  assert_exit 0 "linear/n1 recorded" -- lb --name n1 --ms "1 2 6" --sweep-ms 6
  local before stops sha
  stops="$(stop_lines)"
  before="$(calls_n)"
  assert_exit 2 "n1 again with another --ms" -- lb --name n1 --ms "1 2" --sweep-ms 1
  assert_contains "$ERR" 'r9700: linear-bench: the record linear/n1 is another experiment: MS "1 2 6" -> "1 2"; use another --name' "the line names the key, both values and the remedy"
  assert_exit 2 "n1 again with another timer" -- lb --name n1 --ms "1 2 6" --sweep-ms 6 --timer eager
  assert_contains "$ERR" 'TIMER "graph" -> "eager"' "TIMER"
  mkdir -p "$CASE/v"
  sed 's|^MODEL_DIR=.*|MODEL_DIR=/root/.cache/huggingface/local/Another|' "$MODEL_35B" > "$CASE/v/$KMODEL.env"
  assert_exit 2 "n1 again for a model file with another MODEL_DIR" -- r9700 linear-bench "$CASE/v/$KMODEL.env" --name n1 --ms "1 2 6" --sweep-ms 6
  assert_contains "$ERR" 'MODEL_DIR "/root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ" -> "/root/.cache/huggingface/local/Another"' "MODEL_DIR"
  sha="$(env_get "$RECS/linear/n1/linear.env" LINEAR_BENCH_SHA256)"
  sed -i "s/^LINEAR_BENCH_SHA256=.*/LINEAR_BENCH_SHA256=0000/" "$RECS/linear/n1/linear.env"
  assert_exit 2 "n1 again after the record's asset hash was edited (another asset)" -- lb --name n1 --ms "1 2 6" --sweep-ms 6
  assert_contains "$ERR" "LINEAR_BENCH_SHA256 \"0000\" -> \"$sha\"" "the asset key"
  assert_eq "$stops" "$(stop_lines)" "no refusal stopped anything"
  assert_eq "0" "$(calls_since "$before" | awk '$3 == "wslc" && $4 == "run" { n++ } END { print n + 0 }')" "and no container ran"
  assert_exit 0 "p1 recorded" -- pt --name p1
  assert_exit 2 "p1 again with another arm" -- pt --name p1 --arm ta3
  assert_contains "$ERR" 'the record prefix/p1 is another experiment: ARM "base" -> "ta3"' "the prefix twin names ARM"
  assert_contains "$ERR" "ARM_ARGS" "and the arm's words"
  assert_exit 2 "p1 again with another tail" -- pt --name p1 --tail 32
  assert_contains "$ERR" 'TAIL "64" -> "32"' "TAIL"
}

t_kw10b_an_edited_model_or_machine_field_that_changes_the_container_command_is_another_experiment() {
  kv_setup "$FUNCNAME"
  assert_exit 0 "linear/n1 recorded" -- lb --name n1 --ms "1 2 6" --sweep-ms 6
  step_cfg CACHE_VOLUME=other-cache
  assert_exit 2 "n1 again after the cache volume of machine.env was edited" -- lb --name n1 --ms "1 2 6" --sweep-ms 6
  assert_contains "$ERR" "LINEAR_ARGV " "the key of the whole container command differs"
  assert_exit 0 "p1 recorded" -- pt --name p1
  mkdir -p "$CASE/v"
  sed -e 's|^MAX_MODEL_LEN=.*|MAX_MODEL_LEN=65536|' -e 's|^EXTRA_SERVE_ARGS=.*|EXTRA_SERVE_ARGS="--limit-mm-per-prompt.image 1"|' "$MODEL_35B" > "$CASE/v/$KMODEL.env"
  assert_exit 2 "p1 again for a model file with another MAX_MODEL_LEN and EXTRA_SERVE_ARGS" -- r9700 prefixtest "$CASE/v/$KMODEL.env" --name p1
  assert_contains "$ERR" "the record prefix/p1 is another experiment: SERVE_LINE " "the whole serve line differs"
  assert_eq "1" "$(printf '%s\n' "$ERR" | grep -c .)" "one line"
}

t_kv11_the_placement_word_does_not_leak_out_of_a_body() {
  kv_setup "$FUNCNAME"
  source "$REPO/lib/kernels_verb.sh"
  unset _MOE_PLACED_BY
  kernels_args linear-bench "$KMODEL" --dry-run
  assert_exit 0 "a linear dry-run body in this shell" -- kernels_linear_body
  assert_eq "unset" "${_MOE_PLACED_BY-unset}" "_MOE_PLACED_BY is not left set for the next step of a chain"
  kernels_args prefixtest "$KMODEL" --dry-run
  assert_exit 0 "a prefix dry-run body" -- kernels_prefix_body
  assert_eq "unset" "${_MOE_PLACED_BY-unset}" "nor after the prefix body"
}

# ---- KV5, KV7: the fields and the verb list -----------------------------------------------------------------------------------------------------------------------------

# shape_cases: <verdict>|<group>|<words> of the file both implementations of the grammar read
shape_cases() { grep -v '^#' "$KERNELS_FIXTURES/shapes_cases.txt" | grep -v '^$'; }

t_kv5_the_loader_judges_every_shared_shape_case_as_the_python_grammar_does() {
  kv_setup "$FUNCNAME"
  local verdict group words n=0 rc
  while IFS='|' read -r verdict group words; do
    n=$((n + 1))
    mkdir -p "$CASE/m"
    { grep -v -e '^LINEAR_SHAPES=' -e '^LINEAR_GROUP_SIZE=' "$MODEL_35B"; printf 'LINEAR_SHAPES="%s"\nLINEAR_GROUP_SIZE=%s\n' "$words" "$group"; } > "$CASE/m/model.env"
    config_load "$CASE/machine.env" "$CASE/m/model.env" > /dev/null 2>&1
    rc=$?
    if [ "$verdict" = good ]; then assert_eq "0" "$rc" "the loader accepts: $words (group $group)"; else assert_eq "2" "$rc" "the loader refuses: $words (group $group)"; fi
    python3 - "$REPO/lib/linear_bench.py" "$group" "$words" << 'PYEND'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("lb", sys.argv[1]); module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
try:
    module.parse_shapes(sys.argv[3], int(sys.argv[2])); sys.exit(0)
except module.LinearError:
    sys.exit(2)
PYEND
    assert_eq "$rc" "$?" "and the Python grammar says the same of: $words (group $group)"
  done < <(shape_cases)
  [ "$n" -ge 15 ] && assert_eq ok ok "the loop read the shared file ($n cases)" || assert_eq ">= 15" "$n" "the shared case file has cases"
  { grep -v '^LINEAR_GROUP_SIZE=' "$MODEL_35B"; echo "LINEAR_GROUP_SIZE=16"; } > "$CASE/m/model.env"
  assert_exit 2 "LINEAR_GROUP_SIZE=16 is refused" -- config_load "$CASE/machine.env" "$CASE/m/model.env"
  assert_contains "$ERR" "LINEAR_GROUP_SIZE: \"16\" is outside 32..1024" "with the range"
  { grep -v '^LINEAR_SHAPES=' "$MODEL_35B"; echo 'LINEAR_SHAPES="a:100:16:1"'; } > "$CASE/m/model.env"
  assert_exit 2 "a K that is not a multiple of the group size" -- config_load "$CASE/machine.env" "$CASE/m/model.env"
  assert_contains "$ERR" "LINEAR_SHAPES: \"a:100:16:1\": K 100 is not a multiple of 8" "the line names the field and the word"
  { grep -v '^LINEAR_SHAPES=' "$MODEL_35B"; echo 'LINEAR_SHAPES="a:64:16:1"'; } > "$CASE/m/model.env"
  assert_exit 2 "a K that is a multiple of 8 but not of the group size 128" -- config_load "$CASE/machine.env" "$CASE/m/model.env"
  assert_contains "$ERR" "K 64 is not a multiple of LINEAR_GROUP_SIZE 128" "the cross-field line"
  assert_exit 0 "the 35B file loads" -- config_load "$CASE/machine.env" "$MODEL_35B"
  assert_eq "5" "$(printf '%s\n' $R9700_LINEAR_SHAPES | wc -l | tr -d ' ')" "with its five shapes"
  assert_exit 0 "the 27B file loads with LINEAR_SHAPES empty" -- config_load "$CASE/machine.env" "$MODEL_27B"
  assert_eq "" "$R9700_LINEAR_SHAPES" "empty"
  assert_eq "128" "$R9700_LINEAR_GROUP_SIZE" "and the default group size"
}

t_kv5b_the_defaults_of_the_verbs_are_the_defaults_of_the_programs() {
  kv_setup "$FUNCNAME"
  local got
  got="$(python3 - "$REPO/lib/linear_bench.py" "$REPO/lib/prefixtest.py" << 'PYEND'
import importlib.util, sys
def load(path):
    spec = importlib.util.spec_from_file_location("m" + str(abs(hash(path))), path); module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module); return module
lb, pt = load(sys.argv[1]), load(sys.argv[2])
print(lb.DEFAULT_MS); print(lb.DEFAULT_SWEEP_MS); print(pt.DEFAULT_LENS); print(pt.DEFAULT_TAIL); print(lb.TIMERS[0])
PYEND
)"
  assert_eq "$_KERN_DEFAULT_MS
$_KERN_DEFAULT_SWEEP
$_KERN_DEFAULT_LENS
$_KERN_DEFAULT_TAIL
$_KERN_DEFAULT_TIMER" "$got" "kernels.sh and the two programs hold the same defaults (ms, sweep, lens, tail, the timer)"
}

t_kv7_the_verb_list_names_the_two_verbs_and_each_has_its_row() {
  kv_setup "$FUNCNAME"
  assert_exit 0 "commands" -- r9700 commands
  assert_contains "$OUT" "linear-bench" "linear-bench is a verb"
  assert_contains "$OUT" "prefixtest" "prefixtest is a verb"
  assert_exit 0 "linear-bench has a row of the flow catalogue" -- grep -q '^| `bin/r9700 linear-bench`' "$REPO/research/module_tests.md"
  assert_exit 0 "prefixtest has a row of the flow catalogue" -- grep -q '^| `bin/r9700 prefixtest`' "$REPO/research/module_tests.md"
}

run_all_tests
