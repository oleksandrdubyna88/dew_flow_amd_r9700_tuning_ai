#!/usr/bin/env bash
# Helpers of the ownership-and-recovery tests (tests/test_restore.sh, tests/test_lifecycle.sh). Sourced after tests/lib/stubcase.sh;
# no t_ function in it.
#
#   lc_setup <name>            setup_case, plus a state directory, the machine file named for bin/r9700, a supervisor-less world
#   write_marker [KEY=VALUE]   the recovery marker, written BY HAND as text (so the parser is tested against text, not against
#                              marker_write); overrides replace a default key, `-KEY` drops one; READY_TIMEOUT_S defaults to 3300 (a window the CPU cannot use up)
#   r9700 <args...>            bin/r9700 as a user runs it: the config variables of this test shell are not handed on
#   fake_supervisor <mode>     tests/lib/fake_supervisor.sh in the background: a test double of part (c)'s `step`

# shellcheck source=lib/restore.sh
source "$REPO/lib/restore.sh"

lc_setup() {
  setup_case "$1" "${2:-$MODEL_35B}"
  export R9700_STATE_DIR="$CASE/state"
  export R9700_MACHINE_ENV="$CASE/machine.env"
  MARKER_FILE="$R9700_STATE_DIR/recovery.env"
  mkdir -p "$R9700_STATE_DIR"
  # The adapter's ceilings are divided by 2, not by setup_case's 10: a `wslc list` gets 60 s / 2 = 30 s, not 6 s. On a starved CPU (2026-11-05, 4 busy loops beside the suite: list calls
  # about 10 s apart) one list ran past 6 s while it only waited for the CPU, and each of the three tries of the restore's preparation ended `the container list failed ()`: exit 5,
  # the server not started. The same value and reason as run_setup (R3b, 2026-11-04). A test that needs a ceiling to FIRE sets R9700_CEILING_SCALE itself, after this call.
  # (observed to work: t_a_restore_whose_preparation_lists_each_take_7_s_... fails with the line above and exit 5 when this line is removed)
  export R9700_CEILING_SCALE=2
}

write_marker() {
  local -a keys=(MARKER_VERSION RUN_ID WRITTEN_AT PROD_CONTAINER PROD_WAS_RUNNING WSLC RESTORE_SHELL RESTORE_SCRIPT_WIN RESTORE_ARGS CONTAINER_PREFIX READY_TIMEOUT_S)
  local -A val=(
    [MARKER_VERSION]=1 [RUN_ID]=hand-1 [WRITTEN_AT]=2026-11-01T10:00:00Z [PROD_CONTAINER]=vllm [PROD_WAS_RUNNING]=yes [WSLC]=wslc
    [RESTORE_SHELL]=pwsh.exe [RESTORE_SCRIPT_WIN]='C:\r9700\start-vllm.ps1'
    [RESTORE_ARGS]='"-Model /root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ -ServedName qwen3.6-35b-a3b -MaxModelLen 131072 -MaxNumSeqs 4 -Detach"'
    [CONTAINER_PREFIX]=r9700tune- [READY_TIMEOUT_S]=3300
  )
  # READY_TIMEOUT_S=3300, the marker's largest value (33 s at scale 100), not 60 (0.6 s): a restore that is meant to become ready must not lose to a CPU that is busy for
  # 0.6 s (2026-11-04: `vllm not ready after 67 s` for a server that was up). A test whose SUBJECT is "not ready" writes READY_TIMEOUT_S=60 itself, so that it stays as fast as it was.
  # (observed to work: t_a_restore_whose_first_list_in_ready_wait_takes_2_s_... fails with `not ready after` when the default is 60)
  local arg key
  for arg in "$@"; do
    key="${arg%%=*}"
    case $key in
      -*) unset "val[${key#-}]" ;;
      *) [[ " ${keys[*]} " == *" $key "* ]] || keys+=("$key"); val[$key]="${arg#*=}" ;;
    esac
  done
  : > "$MARKER_FILE"
  for key in "${keys[@]}"; do
    [ -n "${val[$key]+set}" ] && printf '%s=%s\n' "$key" "${val[$key]}" >> "$MARKER_FILE"
  done
  return 0
}

# r9700 <args...>: the config variables exported by setup_case are removed from the environment of the program under test
r9700() {
  local -a drop=()
  local key
  while read -r key; do drop+=(-u "R9700_$key"); done < <(config_keys | awk '{ print $2 }')
  env "${drop[@]}" "$REPO/bin/r9700" "$@"
}

# fake_supervisor <mode> [<label>]: starts the double and waits (bounded) for its ready file; sets SUP (its pid) and SUP_DIR
fake_supervisor() {
  local i
  SUP_DIR="$CASE/sup"
  mkdir -p "$SUP_DIR"
  bash "$HERE/lib/fake_supervisor.sh" "$1" "$SUP_DIR" "$CASE/machine.env" "$MODEL_35B" > "$SUP_DIR/out" 2>&1 &
  SUP=$!
  disown "$SUP"
  guard_pid "$SUP" "supervisor-$SUP"
  for i in $(seq 1 100); do [ -f "$SUP_DIR/ready" ] && return 0; sleep 0.1; done
  _assert_fail "fake supervisor" "never became ready: $(cat "$SUP_DIR/out")"
  return 1
}
