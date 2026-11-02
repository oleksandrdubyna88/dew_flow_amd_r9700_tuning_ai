#!/usr/bin/env bash
# Helpers of the ownership-and-recovery tests (tests/test_restore.sh, tests/test_lifecycle.sh). Sourced after tests/lib/stubcase.sh;
# no t_ function in it.
#
#   lc_setup <name>            setup_case, plus a state directory, the machine file named for bin/r9700, a supervisor-less world
#   write_marker [KEY=VALUE]   the recovery marker, written BY HAND as text (so the parser is tested against text, not against
#                              marker_write); overrides replace a default key, `-KEY` drops one
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
}

write_marker() {
  local -a keys=(MARKER_VERSION RUN_ID WRITTEN_AT PROD_CONTAINER PROD_WAS_RUNNING WSLC RESTORE_SHELL RESTORE_SCRIPT_WIN RESTORE_ARGS CONTAINER_PREFIX READY_TIMEOUT_S)
  local -A val=(
    [MARKER_VERSION]=1 [RUN_ID]=hand-1 [WRITTEN_AT]=2026-11-01T10:00:00Z [PROD_CONTAINER]=vllm [PROD_WAS_RUNNING]=yes [WSLC]=wslc
    [RESTORE_SHELL]=pwsh.exe [RESTORE_SCRIPT_WIN]='C:\r9700\start-vllm.ps1'
    [RESTORE_ARGS]='"-Model /root/.cache/huggingface/local/Qwen3.6-35B-A3B-GPTQ -ServedName qwen3.6-35b-a3b -MaxModelLen 131072 -MaxNumSeqs 4 -Detach"'
    [CONTAINER_PREFIX]=r9700tune- [READY_TIMEOUT_S]=60
  )
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
