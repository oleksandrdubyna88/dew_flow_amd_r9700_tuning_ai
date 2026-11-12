#!/usr/bin/env bash
# _env.sh — SOURCED by every chain script of this folder, as its first command:
#   . "$(dirname "$0")/_env.sh" [KEY...]
# It loads machine.env with the repository's own parser (lib/config.sh, config_load_machine: the same rules and the same refusals as
# `bin/r9700 comfy`), so no chain carries a path of one PC. KEY is a machine.env key the chain needs; one that is empty makes the chain
# stop at once (exit 2), naming the key. Sets, for the keys that are set:
#   COMFY_HOME_WIN  NAS_BACKUP_WIN  NAS_IMAGES_WIN  WSLC_SETTINGS_WIN  COMFY_STORE_WIN      the Windows values, without a closing backslash
#   COMFY_HOME      NAS_BACKUP      NAS_IMAGES      WSLC_SETTINGS                            the WSL forms, made with `wslpath -u`
# R9700_ROOT (the repository root) defaults to three folders above this file; R9700_MACHINE_ENV names another machine file
# (default: <root>/machine.env). Nothing here starts a container or touches the GPU.

_SERIES_HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
R9700_ROOT="${R9700_ROOT:-$(cd "$_SERIES_HERE/../../.." && pwd)}"
# shellcheck source=/dev/null
. "$R9700_ROOT/lib/config.sh" || { echo "series: cannot load $R9700_ROOT/lib/config.sh (set R9700_ROOT to the repository root)" >&2; exit 2; }
config_load_machine "${R9700_MACHINE_ENV:-$R9700_ROOT/machine.env}" || exit 2

_series_set() { # <name> <key>: <name> = the value of R9700_<key> without a closing backslash
  local value="R9700_$2"
  value="${!value:-}"
  printf -v "$1" '%s' "${value%\\}"
}
_series_set COMFY_HOME_WIN COMFY_HOME_WIN
_series_set COMFY_STORE_WIN COMFY_STORE_WIN
_series_set NAS_BACKUP_WIN NAS_BACKUP_WIN
_series_set NAS_IMAGES_WIN NAS_IMAGES_WIN
_series_set WSLC_SETTINGS_WIN WSLC_SETTINGS_WIN

_series_need() { # <KEY>...: stop the calling chain when a key it needs is empty
  local key name
  for key in "$@"; do
    name="$key"
    if [ -z "${!name:-}" ]; then
      echo "$(basename "$0"): $key is not set in machine.env (see machine.env.example)" >&2
      exit 2
    fi
  done
}
_series_need "$@"

_series_wsl() { # <name> <windows value>: <name> = its WSL form, empty when the value is empty
  [ -n "$2" ] || { printf -v "$1" '%s' ""; return 0; }
  command -v wslpath > /dev/null 2>&1 || { echo "$(basename "$0"): wslpath is not available (the chains run in WSL)" >&2; exit 2; }
  printf -v "$1" '%s' "$(wslpath -u "$2")"
}
_series_wsl COMFY_HOME "$COMFY_HOME_WIN"
_series_wsl NAS_BACKUP "$NAS_BACKUP_WIN"
_series_wsl NAS_IMAGES "$NAS_IMAGES_WIN"
_series_wsl WSLC_SETTINGS "$WSLC_SETTINGS_WIN"
