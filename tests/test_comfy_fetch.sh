#!/usr/bin/env bash
# `bin/r9700 comfy fetch <set>...` (E1.S3, scenarios FE1-FE9): one foreground container without the card, the pinned triples of comfyui/models.conf, a lock of its own (never the GPU
# lock), a refusal beside a fetch container that is still listed. The stub answers the fetch container with answers/comfy_fetch.log, comfy_fetch_rc and comfy_fetch_seconds and keeps it
# listed for as long as it runs. Every test body is a function t_<guarantee>; each runs in its own subshell and writes only below $R9700_TEST_ROOT. Waits are bounded polls.
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
FETCH_LOCK_NAME=comfy-fetch.lock

# fe_setup <name>: the ComfyUI stub world (the three volumes present) with the quiet defaults a step needs
fe_setup() {
  comfy_setup "$1"
  export R9700_QUIET_CHECKS=1 R9700_LOADAVG_FILE="$CASE/loadavg"
  printf '0.50 0.40 0.30 1/100 1\n' > "$CASE/loadavg"
  PLACED="$R9700_WORK_DIR/r9700/comfyui"
  FETCH_NAME="$R9700_COMFY_CONTAINER-fetch"
}

# triples <set>...: the `<folder> <url> <sha256>` words of the sets, from comfy_models_load (read, never typed), each file once, the sets in the order given
triples() {
  local set i
  local -A seen=()
  comfy_models_load "$REPO/comfyui/models.conf" || return 1
  for set in "$@"; do
    [ -z "${seen[$set]+set}" ] || continue
    seen[$set]=1
    for i in "${!_COMFY_M_SET[@]}"; do
      [ "${_COMFY_M_SET[$i]}" = "$set" ] && printf '%s\n%s\n%s\n' "${_COMFY_M_DIR[$i]}" "${_COMFY_M_URL[$i]}" "${_COMFY_M_SHA[$i]}"
    done
  done
}

fetch_lock_free() { flock -n "$R9700_STATE_DIR/$FETCH_LOCK_NAME" true; }

line_count() { grep -c . <<< "$1"; }

# FE1
t_one_foreground_container_not_prefixed_without_the_card_with_the_pinned_triples() {
  fe_setup "$FUNCNAME"
  local -a want
  assert_exit 0 "comfy fetch zimage" -- comfy fetch zimage
  argv_of_verb run
  mapfile -t want < <(printf '%s\n' run --rm --name "$FETCH_NAME" -v "$R9700_COMFY_MODELS_VOLUME:/models" -v "$R9700_WORK_DIR_WIN:/work:ro" --entrypoint bash "$R9700_COMFY_IMAGE" /work/r9700/comfyui/fetch_model.sh; triples zimage)
  assert_eq "$(printf '%s|' "${want[@]}")" "$(printf '%s|' "${ARGV[@]}")" "the argv word by word: the name, the volume, the work folder, the entrypoint, the image, the script, the triples in file order"
  assert_eq "21" "${#ARGV[@]}" "twelve words of the call and nine of the three files (the scan is alive: zimage has three files)"
  assert_not_contains "${ARGV[*]}" "--gpus" "no --gpus"
  assert_not_contains "${ARGV[*]}" "/store" "no /store mount"
  assert_eq "1" "$(calls_of_verb run)" "one run call"
  assert_not_contains "${ARGV[2]}" "$R9700_CONTAINER_PREFIX" "the name is not under the toolkit's prefix (container_stop_all never sees it)"
  assert_eq "$(cd "$REPO/comfyui" && sha256sum fetch_model.sh)" "$(cd "$PLACED" && sha256sum fetch_model.sh)" "fetch_model.sh is placed, equal to the repository's"
}

# FE2
t_a_store_adds_its_mount() {
  fe_setup "$FUNCNAME"
  step_cfg 'COMFY_STORE_WIN=X:\models-store'
  assert_exit 0 "comfy fetch zimage with COMFY_STORE_WIN" -- comfy fetch zimage
  argv_of_verb run
  assert_eq "-v|X:\\models-store:/store|-v|$R9700_WORK_DIR_WIN:/work:ro" "$(IFS='|'; echo "${ARGV[*]:6:4}")" "the store mount follows the models volume, before the work folder"
  assert_eq "1" "$(printf '%s\n' "${ARGV[@]}" | grep -cx 'X:\\models-store:/store')" "exactly one such mount"
  assert_eq "$R9700_COMFY_IMAGE" "${ARGV[12]}" "and the image follows the entrypoint, after the mounts"
}

# FE3
t_several_sets_each_file_once() {
  fe_setup "$FUNCNAME"
  assert_exit 0 "comfy fetch zimage wan5b zimage" -- comfy fetch zimage wan5b zimage
  argv_of_verb run
  local -a want got
  mapfile -t want < <(triples zimage wan5b)
  got=("${ARGV[@]:12}")
  assert_eq "$(printf '%s|' "${want[@]}")" "$(printf '%s|' "${got[@]}")" "the triples are zimage's, then wan5b's"
  assert_eq "18" "${#got[@]}" "six triples: none twice"
}

# FE4
t_an_unknown_set_is_refused_before_any_call() {
  fe_setup "$FUNCNAME"
  local legal
  assert_exit 2 "comfy fetch nosuch" -- comfy fetch nosuch
  comfy_models_load "$REPO/comfyui/models.conf"
  legal="$(comfy_sets | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "r9700: comfy: fetch: unknown set \"nosuch\"; legal: $legal" "$ERR" "one line, the legal sets from comfy_sets"
  assert_contains "$legal" "zimage" "the scan is alive: the legal sets name zimage"
  assert_exit 2 "comfy fetch zimage nosuch" -- comfy fetch zimage nosuch
  assert_eq "r9700: comfy: fetch: unknown set \"nosuch\"; legal: $legal" "$ERR" "a good set beside a bad one: still refused whole"
  assert_exit 2 "comfy fetch with no set" -- comfy fetch
  assert_eq "r9700: comfy: fetch: usage: bin/r9700 comfy fetch <set>...; legal sets: $legal" "$ERR" "the usage"
  assert_missing "$STUB/calls.log" "no call"
  assert_missing "$R9700_STATE_DIR/$FETCH_LOCK_NAME" "no lock file"
}

# FE5
t_the_containers_verdict_becomes_the_verbs() {
  fe_setup "$FUNCNAME"
  printf 'fetch: a line of the container\n' > "$STUB/answers/comfy_fetch.log"
  printf '3\n' > "$STUB/answers/comfy_fetch_rc"
  assert_exit 2 "the container exits 3" -- comfy fetch zimage
  assert_contains "$OUT" "fetch: a line of the container" "the container's lines are printed"
  assert_eq "1" "$(line_count "$ERR")" "one stderr line"
  assert_contains "$ERR" "another sha256 than comfyui/models.conf pins" "it says the source publishes another sha256 than the file pins"
  printf '4\n' > "$STUB/answers/comfy_fetch_rc"
  assert_exit 1 "the container exits 4" -- comfy fetch zimage
  assert_contains "$OUT" "fetch: a line of the container" "its lines are printed"
  printf '124\n' > "$STUB/answers/comfy_fetch_rc"
  assert_exit 1 "the container is ended by the ceiling (124)" -- comfy fetch zimage
  assert_contains "$ERR" "ceiling" "the line says the ceiling ended it"
}

# FE6
t_fetch_takes_its_own_lock_and_never_the_gpu_lock() {
  fe_setup "$FUNCNAME"
  local holder_line
  step_bg --model "$MODEL_35B" t -- "$WORKER" child
  wait_for "$STUB/child.pid" 100
  local step_pid="$SUP"
  holder_line="$(cat "$R9700_STATE_DIR/lock")"
  assert_exit 0 "comfy fetch zimage while a step holds the GPU lock" -- comfy fetch zimage
  assert_eq "1" "$(calls_of_verb run)" "the run call was made"
  assert_eq "$holder_line" "$(cat "$R9700_STATE_DIR/lock")" "the GPU lock's holder line is still the step's"
  assert_contains "$(cat "$R9700_STATE_DIR/lock")" "$step_pid step " "naming the step"
  kill -TERM "$step_pid"
  SUP="$step_pid"
  step_end
  kill_recorded_pids "$CASE"
  fe_setup "$FUNCNAME-b"
  printf '30\n' > "$STUB/answers/comfy_fetch_seconds"
  comfy_bg fetch zimage
  local fetch_pid="$SUP"
  wait_call ' wslc run --rm --name comfyui-fetch ' 100
  assert_exit 0 "a step takes the GPU lock while a fetch runs" -- r9700 step --model "$MODEL_35B" t -- "$WORKER" ok
  kill_recorded_pids "$CASE"
  SUP="$fetch_pid"
  comfy_end 30
  fe_setup "$FUNCNAME-c"
  assert_exit 0 "a fetch" -- comfy fetch zimage
  assert_exit 0 "after a fetch the fetch lock is free" -- fetch_lock_free
  if [[ "$(cat "$R9700_STATE_DIR/$FETCH_LOCK_NAME")" =~ ^[0-9]+\ comfy-fetch\ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$ ]]; then assert_eq ok ok "its holder line is <pid> comfy-fetch <UTC time>"; else assert_eq "<pid> comfy-fetch <time>" "$(cat "$R9700_STATE_DIR/$FETCH_LOCK_NAME")" "its holder line is <pid> comfy-fetch <UTC time>"; fi
  assert_exit 0 "and the GPU lock was never taken by it" -- test ! -s "$R9700_STATE_DIR/lock"
}

# FE7
t_the_models_volume_is_made_when_it_is_missing_and_only_then() {
  fe_setup "$FUNCNAME-missing"
  rm -f "$STUB/volumes/$R9700_COMFY_MODELS_VOLUME"
  assert_exit 0 "no stub volume" -- comfy fetch zimage
  assert_eq "1" "$(grep -c " wslc volume create $R9700_COMFY_MODELS_VOLUME\$" "$STUB/calls.log")" "one volume create of the models volume"
  assert_exit 0 "before the run" -- call_order " wslc volume create $R9700_COMFY_MODELS_VOLUME\$" ' wslc run --rm '
  assert_eq "1" "$(grep -c ' wslc volume create ' "$STUB/calls.log")" "and no other volume is made"
  fe_setup "$FUNCNAME-present"
  assert_exit 0 "the volume present" -- comfy fetch zimage
  assert_eq "0" "$(grep -c ' wslc volume create ' "$STUB/calls.log")" "no create"
}

# FE8
t_a_second_fetch_while_one_runs_is_refused_with_exit_4_naming_the_holder() {
  fe_setup "$FUNCNAME"
  local first volumes
  printf '10\n' > "$STUB/answers/comfy_fetch_seconds"
  comfy_bg fetch zimage
  first="$SUP"
  wait_call ' wslc run --rm --name comfyui-fetch ' 100
  rm -f "$PLACED/entrypoint.sh"
  volumes="$(calls_of_verb volume)"
  assert_exit 4 "comfy fetch wan5b beside the first" -- comfy fetch wan5b
  assert_eq "1" "$(line_count "$ERR")" "exactly one stderr line"
  if [[ $ERR =~ ^r9700:\ another\ run\ holds\ $R9700_STATE_DIR/$FETCH_LOCK_NAME:\ pid\ $first,\ comfy-fetch,\ since\ [0-9T:Z-]+$ ]]; then assert_eq ok ok "it names the file, the first fetch's pid, comfy-fetch and the time"; else assert_eq "r9700: another run holds <state>/$FETCH_LOCK_NAME: pid $first, comfy-fetch, since <time>" "$ERR" "the lock_take line"; fi
  assert_eq "1" "$(calls_of_verb run)" "one run call, not two"
  assert_missing "$PLACED/entrypoint.sh" "no placement rewrite by the second"
  assert_eq "$volumes" "$(calls_of_verb volume)" "no volume call by the second"
  assert_exit 2 "an unknown set while the first runs is exit 2: the sets are checked before the lock" -- comfy fetch nosuch
  SUP="$first"
  comfy_end 40
  assert_eq "0" "$SRC" "the first fetch ends 0"
}

# FE9
t_a_fetch_container_left_running_by_a_killed_fetch_is_refused_the_next_fetch_never_touches_its_part() {
  fe_setup "$FUNCNAME-killed"
  printf '30\n' > "$STUB/answers/comfy_fetch_seconds"
  comfy_bg fetch zimage
  wait_call ' wslc run --rm --name comfyui-fetch ' 100
  local i
  for i in $(seq 1 50); do alive comfyui-fetch && break; sleep 0.1; done
  assert_exit 0 "the fetch container is recorded alive" -- alive comfyui-fetch
  kill -KILL "$SUP"
  wait "$SUP" 2> /dev/null
  assert_exit 0 "the killed verb left no lock behind (descriptor 9 is closed for every child)" -- fetch_lock_free
  assert_exit 0 "and the container lives on" -- alive comfyui-fetch
  assert_exit 4 "the next fetch" -- comfy fetch zimage
  assert_eq "r9700: comfy: fetch: a fetch container is still running: comfyui-fetch; wait for it or stop it" "$ERR" "exactly one line"
  assert_eq "1" "$(calls_of_verb run)" "one run call in the log (the first's), no second"
  assert_exit 0 "the fetch lock is free afterwards" -- fetch_lock_free
  kill_recorded_pids "$CASE"
  fe_setup "$FUNCNAME-planted"
  wslc run -d --rm --name comfyui-fetch img > /dev/null
  assert_exit 4 "a fetch container planted by hand, no fetch ever ran" -- comfy fetch zimage
  assert_eq "r9700: comfy: fetch: a fetch container is still running: comfyui-fetch; wait for it or stop it" "$ERR" "the same line"
  kill_recorded_pids "$CASE"
  fe_setup "$FUNCNAME-whole"
  wslc run -d --rm --name comfyui-fetchx img > /dev/null
  assert_exit 0 "a container named comfyui-fetchx is listed: a whole name" -- comfy fetch zimage
  kill_recorded_pids "$CASE"
  fe_setup "$FUNCNAME-list"
  printf '3\n' > "$STUB/fail-list"
  assert_exit 2 "a container list that fails 3 times" -- comfy fetch zimage
  assert_eq "1" "$(line_count "$ERR")" "one line"
  assert_contains "$ERR" "r9700: comfy: fetch: the container list failed 3 times (" "its shape"
  assert_eq "0" "$(calls_of_verb run)" "no run"
  assert_exit 0 "the fetch lock is free" -- fetch_lock_free
}

run_all_tests
