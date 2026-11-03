#!/usr/bin/env bash
# lib/run_plan.sh — the plan file of `bin/r9700 run` (E3.S2): the grammar and its refusals. SOURCED; defines functions and runs nothing. Bash >= 4.4, `set -u`
# safe, no `set -e`. It holds no list of steps: which verbs are steps is the ONE table in lib/run_verb.sh (`run_step_find`).
#
#   plan_words <line> <array name>     splits ONE line into words (decision 1: bare words, or ONE pair of double quotes around a word with spaces); the array
#                                      is empty and 1 is returned, with the reason in _PLAN_WHY, when the line holds a character the grammar refuses
#   plan_step_kind <words...>          sets _PLAN_STEP_KIND to the kind of a legal step (series, moe-chunk, moe-ab, linear-bench, prefixtest); 1 with the reason in _PLAN_WHY
#                                      for a verb that is not a step (the four with their own reason, decision 3) and for anything else
#   plan_parse <file>                  reads the whole file; fills _PLAN_LINES (the line numbers), _PLAN_TEXT (the lines, trimmed) and _PLAN_KIND; every problem
#                                      goes to stderr as `r9700: run: <file>:<line>: <reason>`, all of them in one pass; 2 after the whole file (also for a file
#                                      with no step). Sets _PLAN_SHA, the sha256 of the file as it was read.
#   run_plan_copy <file>               <run dir>/plan.txt, a byte-for-byte copy made beside the name and moved over; 2 when the copy is not the file that was read
#
# The file is never given to a shell: `$`, a backtick, a single quote, `;`, `|`, `&`, `<`, `>`, `(`, `)`, a carriage return and a tab are refused anywhere in a step
# line (a comment line is skipped before it is looked at).

_PLAN_REFUSED_CHARS='[$`'"'"';|&<>()]'

# _plan_refused_char <line>: prints how the first refused character is named, 1 when there is none
_plan_refused_char() {
  local line="$1" rest
  case $line in *$'\r'*) echo "a carriage return (the file must have LF line ends)"; return 0 ;; esac
  case $line in *$'\t'*) echo "a tab (separate the words with spaces)"; return 0 ;; esac
  [[ $line == *$_PLAN_REFUSED_CHARS* ]] || return 1
  rest="${line#"${line%%$_PLAN_REFUSED_CHARS*}"}"
  printf 'the character "%s" (a plan line is never given to a shell)\n' "${rest:0:1}"
}

plan_words() {
  local line="$1" rest word after why
  local -n _pw_out="$2"
  _pw_out=()
  _PLAN_WHY=""
  if why="$(_plan_refused_char "$line")"; then _PLAN_WHY="not allowed: $why"; return 1; fi
  rest="$line"
  while :; do
    rest="${rest#"${rest%%[![:space:]]*}"}"
    [ -n "$rest" ] || break
    if [[ $rest == \"* ]]; then
      rest="${rest#\"}"
      [[ $rest == *\"* ]] || { _PLAN_WHY="a double quote is not closed"; _pw_out=(); return 1; }
      word="${rest%%\"*}"
      after="${rest#*\"}"
      [ -n "$word" ] || { _PLAN_WHY="an empty quoted word"; _pw_out=(); return 1; }
      if [ -n "$after" ] && [[ $after != [[:space:]]* ]]; then _PLAN_WHY="text after the closing quote of \"$word\""; _pw_out=(); return 1; fi
      rest="$after"
    else
      word="${rest%%[[:space:]]*}"
      [[ $word != *\"* ]] || { _PLAN_WHY="a quote inside the word $word (wrap the whole word in one pair of double quotes)"; _pw_out=(); return 1; }
      rest="${rest#"$word"}"
    fi
    _pw_out+=("$word")
  done
}

# _plan_not_step_reason <verb> <mode>: the reason of a verb that exists and is not a step (decision 3); 1 for any other word
_plan_not_step_reason() {
  case $1:${2:-} in
    init:*) echo "init is not a step: it is the machine check a person runs before a night, and run does its own restore-first" ;;
    verdict:*) echo "verdict is not a step: it reads results; run it in the morning" ;;
    moe-tune:merge) echo "moe-tune merge is not a step: it reads chunks that a person chooses after reading them" ;;
    moe-tune:activate) echo "moe-tune activate is not a step: it changes what the operator's own server reads, and a chain at night must not decide that" ;;
    *) return 1 ;;
  esac
}

plan_step_kind() {
  local verb="${1:-}" mode="${2:-}" word
  _PLAN_WHY=""
  for word in "$@"; do
    [ "$word" != --dry-run ] || { _PLAN_WHY="--dry-run is not allowed in a plan line (run --dry-run <plan> dry-runs the whole plan; a plan line is a real step)"; return 1; }
  done
  if _PLAN_WHY="$(_plan_not_step_reason "$verb" "$mode")"; then return 1; fi
  if _PLAN_STEP_KIND="$(run_step_kind "$verb" "$mode")"; then _PLAN_WHY=""; return 0; fi
  [ "$verb" = moe-tune ] && verb="moe-tune $mode"
  _PLAN_WHY="\"$verb\" is not a step; legal: $(run_step_legal)"
  return 1
}

# plan_parse <file>
plan_parse() {
  local file="$1" line text n=0 bad=0 bytes
  local -a words=()
  _PLAN_LINES=() _PLAN_TEXT=() _PLAN_KIND=() _PLAN_SHA=""
  # the file is read ONCE: the hash and the lines are of the same bytes (a file edited between a hash and a second read would run one plan and record another)
  bytes="$(cat -- "$file" 2> /dev/null; printf x)"
  bytes="${bytes%x}"
  _PLAN_SHA="$(printf '%s' "$bytes" | sha256sum | cut -d' ' -f1)"
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    text="${line#"${line%%[![:space:]]*}"}"
    text="${text%"${text##*[![:space:]]}"}"
    case $text in '' | '#'*) continue ;; esac
    if ! plan_words "$text" words; then
      printf 'r9700: run: %s:%s: %s\n' "$file" "$n" "$_PLAN_WHY" >&2
      bad=1
      continue
    fi
    if ! plan_step_kind "${words[@]}"; then
      printf 'r9700: run: %s:%s: %s\n' "$file" "$n" "$_PLAN_WHY" >&2
      bad=1
      continue
    fi
    _PLAN_LINES+=("$n")
    _PLAN_TEXT+=("$text")
    _PLAN_KIND+=("$_PLAN_STEP_KIND")
  done <<< "$bytes"
  if [ "$bad" -eq 0 ] && [ "${#_PLAN_TEXT[@]}" -eq 0 ]; then
    printf 'r9700: run: %s: no step\n' "$file" >&2
    return 2
  fi
  [ "$bad" -eq 0 ] || return 2
}

# run_plan_copy <file>: plan.txt of the run folder; the copy must be the file that plan_parse read (a file edited in between would run one plan and record another)
run_plan_copy() {
  local copy="${RUN_DIR:?}/plan.txt" sha
  if ! { cp -- "$1" "$copy.part" && mv -f -- "$copy.part" "$copy"; } 2> /dev/null; then
    echo "r9700: run: $1: cannot be copied into the run folder" >&2
    return 2
  fi
  sha="$(sha256sum -- "$copy" | cut -d' ' -f1)"
  if [ "$sha" != "${_PLAN_SHA:-}" ]; then
    echo "r9700: run: $1 changed after it was read: run it again" >&2
    return 2
  fi
}
