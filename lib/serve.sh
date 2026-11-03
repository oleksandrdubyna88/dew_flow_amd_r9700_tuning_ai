#!/usr/bin/env bash
# lib/serve.sh — starts a measured test server. SOURCED; defines functions and runs nothing. Bash >= 4.4, `set -u` safe, no `set -e`.
# Needs lib/config.sh (its mounts and environment-word checks), lib/adapter.sh and a loaded config (config_load exports R9700_*).
#
#   serve_start <name> <log> [-e KEY=VALUE]... [-v <rel>:<container path>[:ro]]... -- <serve args...>
#
# The argv of the old serve.sh (lines 17-21) built from the config: the fixed environment, the named volumes, the work folder, the
# operator's generation-config folder (always, read-only, at /genconfig), then the model's MOUNTS, then the given mounts — each
# source turned into R9700_PATCH_DIR_WIN\<the relative source with / replaced by \> — the image, and `vllm serve` with the model,
# the served name, the fixed port, the context, the GPU fraction, the sequences, `--generation-config /genconfig` (for every arm), the
# model's EXTRA_SERVE_ARGS split on spaces, then the given serve arguments. It starts the container (wslc_run) and returns the code of
# `wait_ready <name> <log>` (lib/wait_ready.sh). When wslc cannot start the container it says so and returns that code, without waiting.
# The named container must be a name wslc_run accepts. With `--print` first, nothing is started and nothing is waited for: the line the real
# start would run is printed (wslc_argv_text), for a dry run.
#
#   container_name <label>       prints <CONTAINER_PREFIX><label>; the label is ^[a-z0-9][a-z0-9-]{0,39}$ (2 and one line otherwise), so the
#                                name is at most 56 characters and every guard that lists by prefix finds it

# _serve_mount_arg <rel>:<dst>[:ro]: prints the -v value with the source as a Windows path under PATCH_DIR_WIN; 2 when it is not a mount
_serve_mount_arg() {
  local word="$1" source rest
  if ! _cfg_mounts_problem "$word"; then
    echo "serve: mount: $_PE; legal: <source relative to PATCH_DIR>:<container path>[:ro]" >&2
    return 2
  fi
  source="${word%%:*}"
  rest="${word#*:}"
  printf '%s\\%s:%s\n' "$R9700_PATCH_DIR_WIN" "${source//\//\\}" "$rest"
}

# _serve_options <envs> <mounts> <serve args> <argument...>: parses [-e KEY=VALUE]... [-v <rel>:<dst>[:ro]]... [-- <serve args...>] into three arrays
# (named by the first three arguments); 2 with one `serve:` line on the first thing wrong.
_serve_options() {
  local -n _o_envs="$1" _o_mounts="$2" _o_args="$3"
  local value
  shift 3
  while [ "$#" -gt 0 ] && [ "$1" != -- ]; do
    case $1 in
      -e)
        value="${2-}"
        if ! [[ $value =~ $_RE_ENVWORD ]]; then
          echo "serve: environment word \"$value\" is not KEY=VALUE without spaces (KEY: capital letters, digits, _)" >&2
          return 2
        fi
        _o_envs+=(-e "$value")
        shift 2 || break
        ;;
      -v)
        value="$(_serve_mount_arg "${2-}")" || return 2
        _o_mounts+=(-v "$value")
        shift 2 || break
        ;;
      *)
        echo "serve: unknown option \"$1\"; legal: -e KEY=VALUE, -v <rel>:<container path>[:ro], --" >&2
        return 2
        ;;
    esac
  done
  [ "${1:-}" = -- ] && shift
  _o_args=("$@")
}

# _serve_argv <argv array> <envs array> <mounts array> <serve args array>: the argument list after `run -d --rm --name <name>`, from the config
_serve_argv() {
  local -n _a_argv="$1" _a_envs="$2" _a_mounts="$3" _a_serve="$4"
  local arg value
  local -a model_mounts=() model_words=() extra=()
  read -r -a model_words <<< "$R9700_MOUNTS"
  for arg in "${model_words[@]}"; do
    value="$(_serve_mount_arg "$arg")" || return 2
    model_mounts+=(-v "$value")
  done
  read -r -a extra <<< "$R9700_EXTRA_SERVE_ARGS"
  _a_argv=(
    --gpus all --shm-size 16g
    -e HIP_VISIBLE_DEVICES=0 -e TRITON_CACHE_DIR=/root/.cache/vllm/triton -e PYTHONPYCACHEPREFIX=/tmp/pyc-fresh -e PYTHONDONTWRITEBYTECODE=1
    "${_a_envs[@]}"
    -v "$R9700_HF_VOLUME:/root/.cache/huggingface" -v "$R9700_CACHE_VOLUME:/root/.cache/vllm" -v "$R9700_WORK_DIR_WIN:/work"
    -v "$R9700_GENCONFIG_WIN:/genconfig:ro"
    "${model_mounts[@]}" "${_a_mounts[@]}"
    "$R9700_IMAGE"
    vllm serve "$R9700_MODEL_DIR" --served-model-name "$R9700_SERVED_NAME" --host 0.0.0.0 --port 8000
    --max-model-len "$R9700_MAX_MODEL_LEN" --gpu-memory-utilization "$R9700_GPU_MEM_UTIL" --max-num-seqs "$R9700_MAX_NUM_SEQS"
    --generation-config /genconfig
    "${extra[@]}" "${_a_serve[@]}"
  )
}

# container_host_path <path inside a container>: the host (WSL) path of a file under the mount `/work` (WORK_DIR and WORK_DIR_WIN are one folder, mounted at /work).
# The ONE translation of a container path to a host path: every caller uses it. 1 with one line on stderr for a path that is not under /work (or holds `..`):
# such a path cannot be read from here and is never silently taken for "no file".
container_host_path() {
  local path="${1:-}"
  if [[ $path != /work/?* || $path == *..* ]]; then
    echo "container_host_path: \"$path\" is not under /work (or holds ..): it cannot be read from the host" >&2
    return 1
  fi
  printf '%s/%s\n' "${R9700_WORK_DIR:?}" "${path#/work/}"
}

_SERVE_LABEL_RE='^[a-z0-9][a-z0-9-]{0,39}$'

container_name() {
  local label="${1:-}"
  if ! [[ $label =~ $_SERVE_LABEL_RE ]]; then
    echo "container_name: the label \"$label\" is not $_SERVE_LABEL_RE" >&2
    return 2
  fi
  printf '%s%s\n' "$R9700_CONTAINER_PREFIX" "$label"
}

serve_start() {
  local name log rc print=no
  local -a envs=() mounts=() serve_args=() argv=()
  if [ "${1:-}" = --print ]; then print=yes; shift; fi
  name="${1:-}" log="${2:-}"
  if [ "$#" -lt 2 ]; then
    echo "serve_start: usage: serve_start [--print] <name> <log> [-e KEY=VALUE]... [-v <rel>:<dst>[:ro]]... -- <serve args...>" >&2
    return 2
  fi
  _adapter_name_ok serve_start "$name" || return 2
  shift 2
  _serve_options envs mounts serve_args "$@" || return 2
  _serve_argv argv envs mounts serve_args || return 2
  if [ "$print" = yes ]; then wslc_argv_text run -d --rm --name "$name" "${argv[@]}"; return 0; fi
  wslc_run "$name" "${argv[@]}"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "serve: starting $name failed (code $rc); not waiting for it" >&2
    return "$rc"
  fi
  wait_ready "$name" "$log"
}
