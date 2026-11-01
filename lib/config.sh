#!/usr/bin/env bash
# lib/config.sh — the config contract: the field table, the loader, the arm table. SOURCED; it defines functions and the
# field table and runs nothing else. Bash >= 4.4, `set -u` safe, no `set -e` inside a function.
#
#   config_load <machine.env> <model.env>   parse both, apply defaults, validate every field, export R9700_<KEY>; 0 or 2
#   config_keys                              "<scope> <KEY> <type> <default>" per field (empty default shown as "")
#   config_resolved                          every R9700_<KEY>=<value>, sorted by key (the fingerprint of S3 hashes it)
#   arms_load <file>  arms_names  arm_args <arm>  arm_env <arm>  arm_mounts <arm>  arms_check <arm>...
#
# The files are DATA. They are parsed line by line against `^([A-Z][A-Z0-9_]*)=(.*)$`; a value is bare (no spaces, no
# quotes) or wrapped in ONE pair of double quotes; `$` and the backtick are refused anywhere; nothing is ever sourced,
# evaluated or declared from file content. A value reaches a variable with printf -v, and only for a key of the table.
# Every error names the file, the line, the field and the legal values; all errors are reported in one pass, exit 2.

# _cfg_bash_guard <major> <minor>: one line and status 1 when the bash is older than 4.4 (associative arrays, namerefs, declare -g).
_cfg_bash_guard() {
  if [ "$1" -gt 4 ] || { [ "$1" -eq 4 ] && [ "$2" -ge 4 ]; }; then return 0; fi
  echo "config.sh: bash 4.4 or newer is required (this is bash $1.$2)" >&2
  return 1
}
_cfg_bash_guard "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}" || return 1

declare -ga _F_ORDER=()
declare -gA _F_SCOPE=() _F_TYPE=() _F_DEF=() _F_DESC=()

# _field <scope> <KEY> <type> <default-or-"required"> "<one-line description>"
# Types: cmd image name prefix dir path win cpath cpath? int:<min>:<max> dec:<min>:<max> enum:<a>,<b> hhmm? str? ints mounts args
# A required field is also refused when its value is empty or only spaces.
_field() {
  _F_ORDER+=("$2")
  _F_SCOPE[$2]="$1"
  _F_TYPE[$2]="$3"
  _F_DEF[$2]="$4"
  _F_DESC[$2]="$5"
}

_field machine WSLC cmd "wslc" "the command for wslc, a bare name looked up on PATH, or an absolute path"
_field machine POWERSHELL cmd "powershell.exe" "Windows PowerShell, for the RAM and disk probes"
_field machine RESTORE_SHELL cmd "pwsh.exe" "the shell that runs the operator's start script when the server is restored"
_field machine IMAGE image required "the container image of the test servers"
_field machine HF_VOLUME name hf-cache "the named volume that holds the model cache"
_field machine CACHE_VOLUME name vllm-cache "the named volume that holds the compile caches"
_field machine WORK_DIR dir required "the work directory, as a WSL path; it must exist"
_field machine WORK_DIR_WIN win required "the same work directory as a Windows path; it is mounted at /work"
_field machine PATCH_DIR dir required "the base directory of every mount source, as a WSL path; it must exist"
_field machine PATCH_DIR_WIN win required "the same patch directory as a Windows path"
_field machine GENCONFIG_WIN win required "the operator's generation-config directory, as a Windows path; mounted at /genconfig"
_field machine GSM8K_DATA cpath /work/gsm8k/test.jsonl "the GSM8K test file, as a path inside the container"
_field machine RESULTS_DIR path required "where series results go, as a WSL path; its parent must exist"
_field machine PROD_CONTAINER name vllm "the name of the operator's own server container"
_field machine RESTORE_SCRIPT_WIN win required "the operator's start script, as a Windows path"
_field machine RESTORE_ARGS args required "the arguments of the start script that bring the operator's server back"
_field machine CONTAINER_PREFIX prefix r9700tune- "the name prefix of every test container the toolkit starts"
_field machine RAM_MIN_MB int:512:65536 2048 "stop the run when the free RAM of the PC falls below this many MB"
_field machine QUIET_LOAD_MAX dec:0.1:64 4 "the 1-minute load below which the PC counts as quiet"
_field machine QUIET_BUSY_PATTERN str? "" "a process command-line pattern that means the PC is busy; empty means no process check"
_field machine QUIET_BUSY_IGNORE str? "" "a command-line substring that excludes a match of the busy pattern"
_field machine DISK_GATE enum:on,off on "check the disk event log before each unit: on or off"
_field machine DEADLINE hhmm? "" "the clock time (HH:MM, 24 h) by which a run must be over; empty means none"
_field machine MAX_RUN_MINUTES int:10:2880 720 "the ceiling of a run in minutes when DEADLINE is empty or later"
_field machine READY_TIMEOUT_S int:60:3480 1200 "how long a server may take to become ready, in seconds"
_field machine MAX_FAILED_TRIES int:1:20 6 "how many failed tries a step gets before the run gives up"
_field machine MAX_SERVER_STOPS int:1:10 3 "how many times one invocation may stop the operator's server"
_field machine CLEANUP_BUDGET_S int:60:3600 1500 "seconds kept free before the deadline for cleanup and restore; at least READY_TIMEOUT_S + 120"

_field model MODEL_DIR cpath required "the model directory, as a path inside the container"
_field model SERVED_NAME name required "the served model name"
_field model MAX_MODEL_LEN int:2048:1048576 required "the context length of the server, in tokens"
_field model MAX_NUM_SEQS int:1:256 required "the number of concurrent sequences of the server"
_field model GPU_MEM_UTIL dec:0.10:0.95 0.85 "the GPU memory fraction of the server"
_field model PREFILL_LENS ints required "the prefill lengths to measure, in tokens; each plus 128 must fit MAX_MODEL_LEN"
_field model TUNED_CONFIG_DIR cpath? "" "the folder of tuned MoE configs, as a path inside the container; empty means none"
_field model MOUNTS mounts "" "extra mounts: <source relative to PATCH_DIR>:<container path>[:ro], separated by spaces"
_field model EXTRA_SERVE_ARGS args "" "extra arguments of the serve command, split on spaces; quotes are refused"

_RE_LINE='^([A-Z][A-Z0-9_]*)=(.*)$'
_RE_IMAGE='^[a-z0-9][a-z0-9./_-]*:[A-Za-z0-9._-]+$'
_RE_NAME='^[a-z0-9][a-z0-9._-]*$'
_RE_PREFIX='^[a-z0-9][a-z0-9-]{0,15}-$'
_RE_WIN='^[A-Za-z]:\\[^:*?"<>|]*$'
_RE_HHMM='^([01][0-9]|2[0-3]):[0-5][0-9]$'
_RE_CMD='^[A-Za-z0-9][A-Za-z0-9._+-]*$'
_RE_ARM='^[a-z0-9]+$'
_RE_ENVWORD='^[A-Z_][A-Z0-9_]*=[^[:space:]]*$'
_VALUE_LEGAL='a bare value without spaces or quotes, or one pair of double quotes'
_BANNED='"$" and "`" are not allowed (values are never expanded)'
_OUTPUT_TOKENS=128

# ---------- errors ----------
declare -ga _C_ERRORS=()

# _cfg_error <file> <line or ""> <key> <problem> <legal>
_cfg_error() {
  local where="$1"
  [ -n "$2" ] && where+=":$2"
  _C_ERRORS+=("config: $where: $3: $4; legal: $5")
}

_cfg_flush() {
  local line
  for line in "${_C_ERRORS[@]}"; do printf '%s\n' "$line" >&2; done
}

# ---------- values ----------
# _cfg_value <raw>: sets _PV (the value) or _PE (the refusal) and returns 1.
_cfg_value() {
  local raw="$1" quotes inner rest
  _PV=""
  _PE=""
  case $raw in *'$'* | *'`'*) _PE="$_BANNED"; return 1 ;; esac
  case $raw in *$'\r'*) _PE="a carriage return is not allowed (the file must have LF line ends)"; return 1 ;; esac
  case $raw in *"'"*) _PE="a single quote is not allowed"; return 1 ;; esac
  if [[ $raw == \"* ]]; then
    quotes="${raw//[^\"]/}"
    if [ "${#quotes}" -lt 2 ]; then _PE="unterminated double quote"; return 1; fi
    if [ "${#quotes}" -gt 2 ]; then _PE="a quote inside a quoted value is not allowed"; return 1; fi
    inner="${raw#\"}"
    rest="${inner#*\"}"
    inner="${inner%%\"*}"
    if [ -n "$rest" ]; then _PE="trailing text after the closing quote"; return 1; fi
    _PV="$inner"
    return 0
  fi
  case $raw in *[[:space:]]* | *'"'*) _PE="a bare value must not hold spaces or quotes; wrap it in one pair of double quotes"; return 1 ;; esac
  _PV="$raw"
}

# _cfg_mounts_problem <value>: sets _PE and returns 1 for the first word that is not <relative source>:<container path>[:ro].
_cfg_mounts_problem() {
  local -a words
  local word source
  _PE=""
  read -r -a words <<< "$1"
  for word in "${words[@]}"; do
    if ! [[ $word =~ ^([^:]+):(/[^:]*)(:ro)?$ ]]; then
      _PE="\"$word\" is not <relative source>:<container path>[:ro]"
      return 1
    fi
    source="${BASH_REMATCH[1]}"
    if [[ $source == /* || /$source/ == */../* ]]; then
      _PE="\"$source\" leaves PATCH_DIR"
      return 1
    fi
  done
  return 0
}

# _cfg_args_problem <value>: sets _PE and returns 1 when serve arguments hold a tab or one of * ? [ (words are split on spaces and
# never globbed). The ONE check of EXTRA_SERVE_ARGS and of the serve arguments of an arm.
_cfg_args_problem() {
  _PE=""
  [[ $1 != *[\*\?\[]* && $1 != *$'\t'* ]] || _PE="\"$1\" holds a tab or one of * ? ["
  [ -z "$_PE" ]
}

# _cfg_ints_problem <value>: sets _PE and returns 1 unless the value is distinct positive integers of at most 9 digits.
_cfg_ints_problem() {
  local -a words
  _PE=""
  if ! [[ $1 =~ ^[1-9][0-9]{0,8}( [1-9][0-9]{0,8})*$ ]]; then
    _PE="\"$1\" is not a list of positive integers of at most 9 digits"
    return 1
  fi
  read -r -a words <<< "$1"
  [ "$(printf '%s\n' "${words[@]}" | sort | uniq -d | head -n 1)" = "" ] || _PE="\"$1\" repeats a value"
  [ -z "$_PE" ]
}

_cfg_legal() { # <type>
  local lo hi
  case $1 in
    cmd) echo "a command name on PATH or an absolute path" ;;
    image) echo "image reference <repository>:<tag>" ;;
    name) echo "lower-case letters, digits, . _ - (starting with a letter or digit)" ;;
    prefix) echo "lower-case letters, digits and - (2 to 17 characters), starting with a letter or digit and ending in -" ;;
    dir) echo "an absolute directory that exists" ;;
    path) echo "an absolute path whose parent directory exists" ;;
    win) echo 'X:\…' ;;
    cpath) echo "an absolute container path starting with /" ;;
    'cpath?') echo "an absolute container path starting with /, or empty" ;;
    int:*) IFS=: read -r _ lo hi <<< "$1"; echo "$lo..$hi" ;;
    dec:*) IFS=: read -r _ lo hi <<< "$1"; echo "$lo..$hi (a decimal)" ;;
    enum:*) echo "${1#enum:}" | tr ',' ' ' ;;
    'hhmm?') echo "HH:MM (24 h), or empty" ;;
    'str?') echo "any string, or empty" ;;
    ints) echo "distinct positive integers of at most 9 digits, separated by spaces" ;;
    mounts) echo "<relative source>:<container path>[:ro] words separated by spaces, or empty" ;;
    args) echo "words separated by single spaces; no quotes, tabs or * ? [" ;;
  esac
}

_cfg_decimal_in_range() { # <value> <lo> <hi>
  LC_ALL=C awk -v v="$1" -v lo="$2" -v hi="$3" 'BEGIN { exit !(v + 0 >= lo + 0 && v + 0 <= hi + 0) }'
}

# _cfg_check <type> <value>: returns 0, or 1 with the problem in _PE.
_cfg_check() {
  local type="$1" v="$2" lo hi parent allowed
  _PE=""
  case $type in
    cmd) [[ $v =~ $_RE_CMD || $v == /?* ]] || _PE="\"$v\" is not a command name or an absolute path" ;;
    image) [[ $v =~ $_RE_IMAGE ]] || _PE="\"$v\" is not an image reference" ;;
    name) [[ $v =~ $_RE_NAME ]] || _PE="\"$v\" is not a valid name" ;;
    prefix) [[ $v =~ $_RE_PREFIX ]] || _PE="\"$v\" is not a valid container name prefix" ;;
    dir) [[ $v == /* && -d $v ]] || _PE="\"$v\" is not an existing absolute directory" ;;
    path)
      parent="${v%/*}"
      [ -z "$parent" ] && parent=/
      [[ $v == /* && -d $parent ]] || _PE="\"$v\" is not an absolute path with an existing parent" ;;
    win) [[ $v =~ $_RE_WIN ]] || _PE="\"$v\" is not a Windows path" ;;
    cpath) [[ $v == /* ]] || _PE="\"$v\" is not an absolute container path" ;;
    'cpath?') [[ -z $v || $v == /* ]] || _PE="\"$v\" is not an absolute container path" ;;
    int:*)
      IFS=: read -r _ lo hi <<< "$type"
      if ! [[ $v =~ ^(0|[1-9][0-9]{0,8})$ ]]; then _PE="\"$v\" is not an integer"
      elif ((v < lo || v > hi)); then _PE="\"$v\" is outside $lo..$hi"; fi ;;
    dec:*)
      IFS=: read -r _ lo hi <<< "$type"
      if ! [[ $v =~ ^[0-9]+(\.[0-9]+)?$ ]]; then _PE="\"$v\" is not a decimal number"
      elif ! _cfg_decimal_in_range "$v" "$lo" "$hi"; then _PE="\"$v\" is outside $lo..$hi"; fi ;;
    enum:*)
      allowed=" ${type#enum:} "
      allowed="${allowed//,/ }"
      [[ $allowed == *" $v "* ]] || _PE="\"$v\" is not one of: ${allowed# }" ;;
    'hhmm?') [[ -z $v || $v =~ $_RE_HHMM ]] || _PE="\"$v\" is not a clock time" ;;
    ints) _cfg_ints_problem "$v" ;;
    args) _cfg_args_problem "$v" ;;
    mounts) _cfg_mounts_problem "$v" ;;
  esac
  [ -z "$_PE" ]
}

# ---------- parsing ----------
_cfg_reset() {
  local key
  for key in "${_F_ORDER[@]}"; do unset "R9700_$key"; done
  declare -gA _C_VAL=() _C_FILE=() _C_LINE=() _C_BAD=() _C_SRC=()
  _C_ERRORS=()
}

# _cfg_parse_file <scope> <file>
_cfg_parse_file() {
  local scope="$1" file="$2" line key n=0
  _C_SRC[$scope]="$file"
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    _C_ERRORS+=("config: $file: cannot read (it is missing or not a readable file)")
    return
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    if [ "$n" -eq 1 ] && [[ $line == $'\xef\xbb\xbf'* ]]; then
      _cfg_error "$file" "$n" "file" "file starts with a UTF-8 byte-order mark" "UTF-8 without a byte-order mark"
      line="${line#$'\xef\xbb\xbf'}"
      [ -n "$line" ] || continue
      [[ $line =~ $_RE_LINE ]] || continue
    fi
    [[ $line =~ ^[[:space:]]*(#.*)?$ ]] && continue
    if ! [[ $line =~ $_RE_LINE ]]; then
      _cfg_error "$file" "$n" "line" "not a comment and not KEY=VALUE" "KEY=value or KEY=\"value with spaces\""
      continue
    fi
    _cfg_take "$scope" "$file" "$n" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  done < "$file"
}

_cfg_take() { # <scope> <file> <line> <key> <raw>
  local scope="$1" file="$2" n="$3" key="$4" raw="$5" keys
  if [ "${_F_SCOPE[$key]-}" != "$scope" ]; then
    keys="$(_cfg_keys_of "$scope")"
    _cfg_error "$file" "$n" "$key" "unknown key" "$keys"
    return
  fi
  if [ -n "${_C_FILE[$key]+set}" ]; then
    _cfg_error "$file" "$n" "$key" "set twice (first on line ${_C_LINE[$key]})" "each key once per file"
    return
  fi
  _C_FILE[$key]="$file"
  _C_LINE[$key]="$n"
  if _cfg_value "$raw"; then
    _C_VAL[$key]="$_PV"
  else
    _C_BAD[$key]=1
    _cfg_error "$file" "$n" "$key" "$_PE" "$_VALUE_LEGAL"
  fi
}

_cfg_keys_of() { # <scope>: the keys of one scope, in table order, separated by spaces
  local key out=""
  for key in "${_F_ORDER[@]}"; do [ "${_F_SCOPE[$key]}" = "$1" ] && out+="$key "; done
  printf '%s' "${out% }"
}

# Defaults for absent optional keys, "required" errors for absent required ones, then the type of every value read.
_cfg_fill_and_check() {
  local key type
  for key in "${_F_ORDER[@]}"; do
    type="${_F_TYPE[$key]}"
    if [ -z "${_C_FILE[$key]+set}" ]; then
      if [ "${_F_DEF[$key]}" = required ]; then
        _cfg_error "${_C_SRC[${_F_SCOPE[$key]}]}" "" "$key" "required" "$(_cfg_legal "$type")"
        _C_BAD[$key]=1
      else
        _C_VAL[$key]="${_F_DEF[$key]}"
      fi
    elif [ -z "${_C_BAD[$key]+set}" ] && ! _cfg_check "$type" "${_C_VAL[$key]}"; then
      _C_BAD[$key]=1
      _cfg_error "${_C_FILE[$key]}" "${_C_LINE[$key]}" "$key" "$_PE" "$(_cfg_legal "$type")"
    elif [ -z "${_C_BAD[$key]+set}" ] && [ "${_F_DEF[$key]}" = required ] && [[ ${_C_VAL[$key]} != *[![:space:]]* ]]; then
      _C_BAD[$key]=1
      _cfg_error "${_C_FILE[$key]}" "${_C_LINE[$key]}" "$key" "the value is empty or only spaces" "$(_cfg_legal "$type")"
    fi
  done
}

# _cfg_where <key>: the file of a key's value (the file of its scope when the value is a default).
_cfg_where() { printf '%s' "${_C_FILE[$1]:-${_C_SRC[${_F_SCOPE[$1]}]}}"; }

# Cross-field checks: only over fields that passed their own check.
_cfg_cross() {
  local n word source
  local -a words
  if [ -z "${_C_BAD[PREFILL_LENS]+set}${_C_BAD[MAX_MODEL_LEN]+set}" ]; then
    for n in ${_C_VAL[PREFILL_LENS]}; do
      ((n + _OUTPUT_TOKENS > _C_VAL[MAX_MODEL_LEN])) && _cfg_error "$(_cfg_where PREFILL_LENS)" "${_C_LINE[PREFILL_LENS]-}" PREFILL_LENS \
        "$n + $_OUTPUT_TOKENS output tokens exceed MAX_MODEL_LEN ${_C_VAL[MAX_MODEL_LEN]}" "each value + $_OUTPUT_TOKENS <= MAX_MODEL_LEN"
    done
  fi
  if [ -z "${_C_BAD[MOUNTS]+set}${_C_BAD[PATCH_DIR]+set}" ]; then
    read -r -a words <<< "${_C_VAL[MOUNTS]}"
    for word in "${words[@]}"; do
      source="${word%%:*}"
      [ -e "${_C_VAL[PATCH_DIR]}/$source" ] || _cfg_error "$(_cfg_where MOUNTS)" "${_C_LINE[MOUNTS]-}" MOUNTS \
        "\"$source\" does not exist under PATCH_DIR" "every source is a file or folder under PATCH_DIR"
    done
  fi
  if [ -z "${_C_BAD[PROD_CONTAINER]+set}${_C_BAD[CONTAINER_PREFIX]+set}" ] && [[ ${_C_VAL[PROD_CONTAINER]} == "${_C_VAL[CONTAINER_PREFIX]}"* ]]; then
    _cfg_error "$(_cfg_where PROD_CONTAINER)" "${_C_LINE[PROD_CONTAINER]-}" PROD_CONTAINER \
      "\"${_C_VAL[PROD_CONTAINER]}\" starts with the container prefix \"${_C_VAL[CONTAINER_PREFIX]}\"" \
      "PROD_CONTAINER must not start with CONTAINER_PREFIX (the toolkit stops every container with that prefix)"
  fi
  if [ -z "${_C_BAD[CLEANUP_BUDGET_S]+set}${_C_BAD[READY_TIMEOUT_S]+set}" ] \
    && ((_C_VAL[CLEANUP_BUDGET_S] < _C_VAL[READY_TIMEOUT_S] + 120)); then
    _cfg_error "$(_cfg_where CLEANUP_BUDGET_S)" "${_C_LINE[CLEANUP_BUDGET_S]-}" CLEANUP_BUDGET_S \
      "${_C_VAL[CLEANUP_BUDGET_S]} is less than READY_TIMEOUT_S ${_C_VAL[READY_TIMEOUT_S]} + 120" "at least READY_TIMEOUT_S + 120"
  fi
}

config_load() {
  local key
  _cfg_reset
  _cfg_parse_file machine "${1:-}"
  _cfg_parse_file model "${2:-}"
  _cfg_fill_and_check
  _cfg_cross
  if [ "${#_C_ERRORS[@]}" -gt 0 ]; then
    _cfg_flush
    return 2
  fi
  for key in "${_F_ORDER[@]}"; do
    printf -v "R9700_$key" '%s' "${_C_VAL[$key]}"
    export "R9700_$key"
  done
  return 0
}

config_keys() {
  local key default
  for key in "${_F_ORDER[@]}"; do
    default="${_F_DEF[$key]}"
    printf '%s %s %s %s\n' "${_F_SCOPE[$key]}" "$key" "${_F_TYPE[$key]}" "${default:-\"\"}"
  done
}

config_descriptions() { # "<KEY> <description>" per field, for generated docs and comments
  local key
  for key in "${_F_ORDER[@]}"; do printf '%s %s\n' "$key" "${_F_DESC[$key]}"; done
}

config_resolved() {
  local key var
  if [ -z "${R9700_IMAGE:-}" ]; then
    echo "config: config_resolved needs a successful config_load first" >&2
    return 2
  fi
  for key in "${_F_ORDER[@]}"; do
    var="R9700_$key"
    printf '%s=%s\n' "$var" "${!var-}"
  done | LC_ALL=C sort
}

# ---------- the arm table ----------
declare -ga _A_ORDER=()
declare -gA _A_ARGS=() _A_ENV=() _A_MOUNTS=() _A_LINE=()
_A_FILE=""

_trim() { # <text>: result in _T
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  _T="$s"
}

# _arm_row_problem <name> <args> <env> <mounts>: sets _PE and returns 1 for the first thing wrong with a row.
_arm_row_problem() {
  local word
  local -a words
  _PE=""
  [[ $1 =~ $_RE_ARM ]] || { _PE="arm names are lower-case letters and digits only"; return 1; }
  case $2$3 in *'"'* | *"'"* | *'$'* | *'`'*) _PE="arguments and environment must not contain quotes, \"\$\" or \"\`\""; return 1 ;; esac
  _cfg_args_problem "$2" || return 1
  read -r -a words <<< "$3"
  for word in "${words[@]}"; do
    [[ $word =~ $_RE_ENVWORD ]] || { _PE="\"$word\" is not an environment word KEY=VALUE"; return 1; }
  done
  case $4 in *'"'* | *"'"* | *'$'* | *'`'*) _PE="mounts must not contain quotes, \"\$\" or \"\`\""; return 1 ;; esac
  _cfg_mounts_problem "$4"
}

_ARM_LEGAL='name | serve arguments | KEY=VALUE environment words | mounts <relative source>:<container path>[:ro]'

# _arms_take <file> <line number> <text>
_arms_take() {
  local file="$1" n="$2" text="$3" pipes name args env mounts rest
  pipes="${text//[^|]/}"
  if [ "${#pipes}" -ne 3 ]; then
    _cfg_error "$file" "$n" "row" "expected four fields separated by | (found $((${#pipes} + 1)))" "$_ARM_LEGAL"
    return
  fi
  rest="$text"
  _trim "${rest%%|*}"; name="$_T"; rest="${rest#*|}"
  _trim "${rest%%|*}"; args="$_T"; rest="${rest#*|}"
  _trim "${rest%%|*}"; env="$_T"; rest="${rest#*|}"
  _trim "$rest"; mounts="$_T"
  if ! _arm_row_problem "$name" "$args" "$env" "$mounts"; then
    _cfg_error "$file" "$n" "$name" "$_PE" "$_ARM_LEGAL"
  elif [ -n "${_A_LINE[$name]+set}" ]; then
    _cfg_error "$file" "$n" "$name" "defined twice (lines ${_A_LINE[$name]} and $n)" "one row per arm"
  else
    _A_ORDER+=("$name")
    _A_ARGS[$name]="$args"
    _A_ENV[$name]="$env"
    _A_MOUNTS[$name]="$mounts"
    _A_LINE[$name]="$n"
  fi
}

arms_load() {
  local file="${1:-}" line n=0
  _A_FILE="$file"
  _A_ORDER=()
  _A_ARGS=()
  _A_ENV=()
  _A_MOUNTS=()
  _A_LINE=()
  _C_ERRORS=()
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    _C_ERRORS+=("config: $file: cannot read (it is missing or not a readable file)")
  else
    while IFS= read -r line || [ -n "$line" ]; do
      n=$((n + 1))
      if [ "$n" -eq 1 ] && [[ $line == $'\xef\xbb\xbf'* ]]; then
        _cfg_error "$file" "$n" "file" "file starts with a UTF-8 byte-order mark" "UTF-8 without a byte-order mark"
        line="${line#$'\xef\xbb\xbf'}"
      fi
      [[ $line =~ ^[[:space:]]*(#.*)?$ ]] && continue
      _arms_take "$file" "$n" "$line"
    done < "$file"
  fi
  if [ "${#_C_ERRORS[@]}" -gt 0 ]; then
    _cfg_flush
    _A_ORDER=()
    return 2
  fi
}

arms_names() {
  [ "${#_A_ORDER[@]}" -gt 0 ] && printf '%s\n' "${_A_ORDER[@]}"
  return 0
}

_arm_known() { # <arm>
  [ -n "${_A_LINE[$1]+set}" ] && return 0
  echo "config: arm \"$1\" is not in ${_A_FILE#"$PWD"/}; legal: $(arms_names | tr '\n' ' ' | sed 's/ $//')" >&2
  return 2
}

_arm_words() { # <arm> <field array name>
  local -a words
  local -n field="$2"
  _arm_known "$1" || return 2
  read -r -a words <<< "${field[$1]}"
  [ "${#words[@]}" -gt 0 ] && printf '%s\n' "${words[@]}"
  return 0
}

arm_args() { _arm_words "$1" _A_ARGS; }
arm_env() { _arm_words "$1" _A_ENV; }
arm_mounts() { _arm_words "$1" _A_MOUNTS; }

arms_check() {
  local arm mount source status=0
  for arm in "$@"; do
    _arm_known "$arm" || { status=2; continue; }
    while read -r mount; do
      [ -n "$mount" ] || continue
      if [ -z "${R9700_PATCH_DIR:-}" ]; then
        echo "config: $arm: a mount needs PATCH_DIR; run config_load first" >&2
        status=2
        break
      fi
      source="${mount%%:*}"
      [ -e "$R9700_PATCH_DIR/$source" ] && continue
      echo "config: $arm: mount source \"$source\" does not exist under PATCH_DIR ($R9700_PATCH_DIR)" >&2
      status=2
    done < <(arm_mounts "$arm")
  done
  return "$status"
}
