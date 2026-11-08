#!/usr/bin/env bash
# lib/comfy_bench_evidence.sh — what proves a ComfyUI arm took effect (E2.S2): the evidence table, the checks of one arm-round's own record, the load and recompile flags of a measured
# run. SOURCED by lib/comfy_bench.sh in both faces (the supervisor's and the worker's); defines functions and runs nothing. Bash >= 4.4, `set -u` safe, no `set -e`. Needs
# lib/config.sh (_RE_ARM and _trim).
#
#   comfy_evidence_load <file>        parses comfyui/arm_evidence.conf: 0 and the arrays _CE_ACT[<arm>], _CE_INERT[<arm>] (each the field as written, `-` and nothing as ""), _CE_ORDER (file
#                                     order); 2 with `r9700: comfy: <file>:<line>: <problem>` for every bad row, in one pass
#   comfy_evidence_checks <field>     the checks of a field, one `<kind>=<argument>` per line
#   comfy_evidence_argv_alone <arm>   0 when the arm's activation field holds checks and every one is `argv=` (a passed flag is never proof that it acted)
#   _cb_check_one <kind> <argument> <part> <stop>   one check against the record in <part>: 0 true, 1 false; prints the detail `present (...)` / `absent (...)` / `missing (...)`
#   _cb_flags_line <cut file>         `load <n>, recompile <m>`: the model loads and unloads and the recompiles in one measured run's cut of the log
#
# The row grammar: `arm | activation | inertness`, exactly two `|`; a field is `-` or checks joined by `;` (a `;` never appears inside a check), ALL required. A check is `<kind>=<argument>`;
# the kinds: log (a line of the whole server log matches the extended regular expression), nolog (no line does), coldlog (a line of the COLD run's cut does), node (every measured run's
# node list holds a node of that class: executed or reused from ComfyUI's execution cache), cache (the cold run left a file under /cache/<folder>), tunable (the copied TunableOp files `<name>*.csv` have a Validator line and a result row),
# argv (ComfyUI's argv holds the word). The files read are the record's own: server.log, runs/cold.log, runs/<k>.json, tunableop_results.csv.

_CB_KINDS="log nolog coldlog node cache tunable argv"
_CB_LOAD_RE='Requested to load|loaded completely|loaded partially|Unloading|models unloaded'
_CB_RECOMPILE_RE='[Rr]ecompil'

declare -ga _CE_ORDER=()
declare -gA _CE_ACT=() _CE_INERT=() _CE_LINE=()

_ce_err() { printf 'r9700: comfy: %s:%s: %s\n' "$1" "$2" "$3" >&2; }

# _ce_field_problems <file> <line> <field>: the problems of one field (already trimmed); prints one stderr line each and returns 1 when there is one
_ce_field_problems() {
  local file="$1" n="$2" field="$3" check kind arg bad=0 legal
  [ "$field" != - ] || return 0
  legal="${_CB_KINDS// /, }"
  if [ -z "$field" ]; then _ce_err "$file" "$n" "a field is - or checks joined by ;, this one is empty"; return 1; fi
  while IFS= read -r check; do
    check="${check#"${check%%[![:space:]]*}"}"
    check="${check%"${check##*[![:space:]]}"}"
    if [[ $check != *=* ]]; then _ce_err "$file" "$n" "the check \"$check\" is not <kind>=<argument>; legal kinds: $legal"; bad=1; continue; fi
    kind="${check%%=*}" arg="${check#*=}"
    if [[ " $_CB_KINDS " != *" $kind "* ]]; then _ce_err "$file" "$n" "unknown check kind \"$kind\"; legal: $legal"; bad=1; continue; fi
    if [ -z "$arg" ]; then _ce_err "$file" "$n" "the check \"$check\" has no argument"; bad=1; continue; fi
    case $kind in
      log | nolog | coldlog)
        grep -E -- "$arg" < /dev/null > /dev/null 2>&1
        [ "$?" -le 1 ] || { _ce_err "$file" "$n" "the check \"$check\" holds a regular expression grep -E refuses"; bad=1; }
        ;;
      node) [[ $arg =~ ^[A-Za-z0-9_]+$ ]] || { _ce_err "$file" "$n" "the check \"$check\": a node class is letters, digits and _"; bad=1; } ;;
      cache) [[ $arg =~ ^[a-z0-9_]+$ ]] || { _ce_err "$file" "$n" "the check \"$check\": a cache folder is lower-case letters, digits and _"; bad=1; } ;;
      tunable) [[ $arg =~ ^[A-Za-z0-9._-]+$ ]] || { _ce_err "$file" "$n" "the check \"$check\": a file name is letters, digits, . _ -"; bad=1; } ;;
      argv) [[ $arg =~ ^[^[:space:]]+$ ]] || { _ce_err "$file" "$n" "the check \"$check\": an argv word has no blank"; bad=1; } ;;
    esac
  done < <(tr ';' '\n' <<< "$field")
  return "$bad"
}

comfy_evidence_load() {
  local file="${1:-}" line n=0 bad=0 pipes rest arm act inert
  _CE_ORDER=() _CE_ACT=() _CE_INERT=() _CE_LINE=()
  if [ ! -r "$file" ]; then
    printf 'r9700: comfy: %s: cannot be read\n' "$file" >&2
    return 2
  fi
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
    pipes="${line//[^|]/}"
    if [ "${#pipes}" -ne 2 ]; then
      _ce_err "$file" "$n" "a row has three fields (arm, activation, inertness), this one has $((${#pipes} + 1))"
      bad=1
      continue
    fi
    rest="$line"
    _trim "${rest%%|*}"; arm="$_T"; rest="${rest#*|}"
    _trim "${rest%%|*}"; act="$_T"; rest="${rest#*|}"
    _trim "$rest"; inert="$_T"
    [[ $arm =~ $_RE_ARM ]] || { _ce_err "$file" "$n" "the arm \"$arm\" is not lower-case letters and digits"; bad=1; }
    if [ -n "${_CE_LINE[$arm]+set}" ]; then _ce_err "$file" "$n" "the arm \"$arm\" is defined twice (lines ${_CE_LINE[$arm]} and $n)"; bad=1; continue; fi
    _ce_field_problems "$file" "$n" "$act" || bad=1
    _ce_field_problems "$file" "$n" "$inert" || bad=1
    _CE_LINE[$arm]="$n"
    _CE_ORDER+=("$arm")
    [ "$act" = - ] && act=""
    [ "$inert" = - ] && inert=""
    _CE_ACT[$arm]="$act"
    _CE_INERT[$arm]="$inert"
  done < "$file"
  [ "$bad" -eq 0 ] || return 2
  if [ "${#_CE_ORDER[@]}" -eq 0 ]; then printf 'r9700: comfy: %s: holds no row\n' "$file" >&2; return 2; fi
}

comfy_evidence_checks() {
  local check
  [ -n "${1:-}" ] || return 0
  while IFS= read -r check; do
    check="${check#"${check%%[![:space:]]*}"}"
    check="${check%"${check##*[![:space:]]}"}"
    [ -z "$check" ] || printf '%s\n' "$check"
  done < <(tr ';' '\n' <<< "$1")
}

comfy_evidence_argv_alone() {
  local check any=no
  while IFS= read -r check; do
    any=yes
    [ "${check%%=*}" = argv ] || return 1
  done < <(comfy_evidence_checks "${_CE_ACT[$1]:-}")
  [ "$any" = yes ]
}

# _cb_json_q <file> <node|cache|argv> <argument>: node and argv print yes|no, cache prints the number of files; 1 when the file is not the JSON of a run
_cb_json_q() {
  python3 -c 'import json, sys
doc = json.load(open(sys.argv[1]))
query, arg = sys.argv[2], sys.argv[3]
if query == "node":
    # the nodes of the run: executed, or reused from the execution cache of ComfyUI (the loaders and the compile node are cached in a measured run: the message executing never names them)
    print("yes" if arg in (doc.get("nodes") or []) or arg in (doc.get("cached_types") or []) else "no")
elif query == "argv":
    print("yes" if arg in (doc.get("server_argv") or []) else "no")
else:
    print(int(((doc.get("cache_after") or {}).get(arg) or {}).get("files", 0)))' "$1" "$2" "$3" 2> /dev/null
}

# _cb_tunable_state <file name>: the state of the results of the arm-round in <part>: TunableOp writes <name without .csv><device number>.csv (PYTORCH_TUNABLEOP_FILENAME=x/tunableop_results.csv
# is written as x/tunableop_results0.csv, observed on the card 2026-11-08), so every file <stem>*.csv of the record is read, never the exact name. `empty` (no file, or nothing in them),
# `no validator`, `no result row`, or `ok <rows>` (a result row: not a Validator line, at least four comma-separated fields)
_cb_tunable_state() {
  local part="$1" stem="${2%.csv}" rows all
  all="$(cat "$part/$stem"*.csv 2> /dev/null)"
  [ -n "$all" ] || { echo empty; return 0; }
  grep -q '^Validator' <<< "$all" || { echo "no validator"; return 0; }
  rows="$(grep -v '^Validator' <<< "$all" | awk -F, 'NF >= 4 { n++ } END { print n + 0 }')"
  [ "$rows" -ge 1 ] || { echo "no result row"; return 0; }
  echo "ok $rows"
}

_cb_check_one() {
  local kind="$1" arg="$2" part="$3" stop="${4:-clean}" n k files state rows
  case $kind in
    log | nolog)
      n="$(grep -nE -m1 -- "$arg" "$part/server.log" 2> /dev/null | cut -d: -f1)"
      if [ "$kind" = log ]; then
        [ -n "$n" ] && { echo "present (server.log:$n)"; return 0; }
        echo "missing (server.log)"
        return 1
      fi
      [ -z "$n" ] && { echo "absent (server.log)"; return 0; }
      echo "present (server.log:$n)"
      return 1
      ;;
    coldlog)
      n="$(grep -nE -m1 -- "$arg" "$part/runs/cold.log" 2> /dev/null | cut -d: -f1)"
      [ -n "$n" ] && { echo "present (runs/cold.log:$n)"; return 0; }
      echo "missing (runs/cold.log)"
      return 1
      ;;
    node)
      for k in 1 2 3; do
        [ "$(_cb_json_q "$part/runs/$k.json" node "$arg")" = yes ] || { echo "missing (runs/$k.json)"; return 1; }
      done
      echo "present (runs 1-3)"
      ;;
    cache)
      files="$(_cb_json_q "$part/runs/cold.json" cache "$arg")" || files=""
      [[ $files =~ ^[0-9]+$ ]] || { echo "missing (runs/cold.json is not readable)"; return 1; }
      [ "$files" -ge 1 ] || { echo "missing (runs/cold.json: $files files)"; return 1; }
      echo "present ($files files)"
      ;;
    tunable)
      state="$(_cb_tunable_state "$part" "$arg")"
      case $state in
        ok*) rows="${state#ok }"; echo "present ($rows row$([ "$rows" = 1 ] || echo s))"; return 0 ;;
        empty) [ "$stop" = forced ] && { echo "missing (the stop was forced: the file is written at the server's exit)"; return 1; } ;;
      esac
      echo "missing ($state)"
      return 1
      ;;
    argv)
      [ "$(_cb_json_q "$part/runs/cold.json" argv "$arg")" = yes ] && { echo "present (runs/cold.json)"; return 0; }
      echo "missing (runs/cold.json)"
      return 1
      ;;
  esac
}

# _cb_flags_line <cut file>: the counts of one measured run's cut
_cb_flags_line() {
  printf 'load %s, recompile %s\n' "$(grep -cE -- "$_CB_LOAD_RE" "$1" 2> /dev/null)" "$(grep -cE -- "$_CB_RECOMPILE_RE" "$1" 2> /dev/null)"
}
