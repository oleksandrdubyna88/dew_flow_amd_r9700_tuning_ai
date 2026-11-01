#!/usr/bin/env bash
# The static checks. No arguments: every check over the repository's files (`git ls-files` plus untracked files that are not
# ignored, so the check also works before the first commit; in CI the second set is empty). One check over given files:
#
#   bash tests/check_static.sh --scan <files>      personal paths (a profile path, a home directory) in any text file
#   bash tests/check_static.sh --bash <files>      `bash -n` on each file
#   bash tests/check_static.sh --python <files>    compile each file (syntax only; writes no __pycache__)
#   bash tests/check_static.sh --vendored [<copy dir> <mount dir>]   tools/lib's leftovers helper equals the mounted one
#   bash tests/check_static.sh --seam [<root>]     only lib/adapter.sh expands $R9700_WSLC, $R9700_POWERSHELL, $R9700_RESTORE_SHELL or runs wslc, powershell.exe, pwsh.exe (prints the files that do)
#
# Exit 0 clean, 1 on a finding, 2 when it scanned nothing or was called wrongly (a scan of nothing is not a pass).
# The four personal-path patterns match case-insensitively (a lower-case `c:\users\<name>` is a profile path too) and are written so that their own text does not match them (after `Users\`, `Users/` and
# `home/` the next character of the pattern text is `[`), so this file is scanned like every other: no file is excluded.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDORED_FILES=(owned.mjs git.mjs leftovers-sweep.mjs)

scan_paths() { # <files...>
  local file hits
  [ "$#" -gt 0 ] || { echo "check_static: --scan needs at least one file" >&2; return 2; }
  for file in "$@"; do [ -f "$file" ] || { echo "check_static: not a file: $file" >&2; return 2; }; done
  hits="$(grep -InHiE -e '[A-Za-z]:\\Users\\[A-Za-z0-9._-]' -e '/mnt/[a-z]/Users/[A-Za-z0-9._-]' \
    -e '/home/[A-Za-z0-9._-]+/' -e '/Users/[A-Za-z0-9._-]+/' -- "$@" | sed -E 's/^([^:]+:[0-9]+:)/\1 /')"
  [ -z "$hits" ] && return 0
  printf '%s\n' "$hits"
  return 1
}

check_bash() { # <files...>
  local file status=0
  [ "$#" -gt 0 ] || { echo "check_static: --bash needs at least one file" >&2; return 2; }
  for file in "$@"; do
    [ -f "$file" ] || { echo "check_static: not a file: $file" >&2; return 2; }
    bash -n "$file" || { echo "check_static: bash syntax error in $file" >&2; status=1; }
  done
  return "$status"
}

check_python() { # <files...>
  [ "$#" -gt 0 ] || { echo "check_static: --python needs at least one file" >&2; return 2; }
  python3 -c 'import sys; [compile(open(f, encoding="utf-8").read(), f, "exec") for f in sys.argv[1:]]' "$@" \
    || { echo "check_static: python syntax error in one of: $*" >&2; return 1; }
}

# check_seam [<root>]: the adapter seam (E1.S2 decision 11). Over the CODE lines (not the comment lines) of lib/*.sh and bin/*, prints every
# file that EXPANDS one of the three executable variables ($R9700_WSLC, ${R9700_POWERSHELL}, ...) and every file other than lib/adapter.sh
# that names wslc, powershell(.exe) or pwsh(.exe) as a command word (after a line start, a space, ; & | ( or a backtick; optional single or
# double quotes around it; before a space or the line end) or assigns one of them to a variable (name=wslc, name="pwsh.exe"). Exit 0 when
# that is exactly lib/adapter.sh, 1 when it lists another file or not the adapter, 2 when the scan cannot say: no adapter, or fewer than
# three code lines in it that expand the variables (a scan that finds nothing is not a pass).
#
# The ONE named exception: in lib/config.sh, the three default declarations of the field table, which must be exactly
#   _field machine WSLC cmd "wslc" "<description>"     (likewise POWERSHELL with "powershell.exe", RESTORE_SHELL with "pwsh.exe")
# with a description free of quotes, $, backticks, ; & and |. A line of that exact shape is data, not a call; any other line of
# lib/config.sh, and the same line in any other file, is scanned like all the rest (tests/test_static.sh proves both).
SEAM_RE='\$\{?R9700_(WSLC|POWERSHELL|RESTORE_SHELL)([^A-Za-z0-9_]|$)'
SEAM_WORD_RE='(^|[;&|(`[:space:]])["'"'"']?(wslc|powershell|pwsh)(\.exe)?["'"'"']?([[:space:]]|$)'
SEAM_ASSIGN_RE='=["'"'"']?(wslc|powershell|pwsh)(\.exe)?["'"'"']?([[:space:]]|;|$)'
SEAM_ALLOW_RE='^_field machine (WSLC|POWERSHELL|RESTORE_SHELL) cmd "(wslc|powershell\.exe|pwsh\.exe)" "[^"$`;&|]*"$'
seam_code() { grep -vE '^[[:space:]]*#' "$1" || true; } # the code lines of a file
# seam_scanned <root> <file>: the code lines to scan, without the named exception's lines when the file is lib/config.sh
seam_scanned() {
  if [ "$2" = lib/config.sh ]; then seam_code "$1/$2" | { grep -vE "$SEAM_ALLOW_RE" || true; }; else seam_code "$1/$2"; fi
}
check_seam() {
  local root="${1:-$ROOT}" file hits="" adapter_hits
  if [ ! -f "$root/lib/adapter.sh" ]; then
    echo "check_static: --seam: $root/lib/adapter.sh not found" >&2
    return 2
  fi
  adapter_hits="$(seam_code "$root/lib/adapter.sh" | grep -cE "$SEAM_RE")"
  if [ "$adapter_hits" -lt 3 ]; then
    echo "check_static: --seam: lib/adapter.sh holds $adapter_hits code lines that expand the variables, at least 3 are expected (the scan is dead)" >&2
    return 2
  fi
  for file in $(cd "$root" && ls lib/*.sh bin/* 2> /dev/null); do
    [ -f "$root/$file" ] || continue
    if seam_scanned "$root" "$file" | grep -qE "$SEAM_RE"; then hits+="$file"$'\n'; continue; fi
    [ "$file" = lib/adapter.sh ] && continue
    if seam_scanned "$root" "$file" | grep -qE -e "$SEAM_WORD_RE" -e "$SEAM_ASSIGN_RE"; then hits+="$file"$'\n'; fi
  done
  hits="${hits%$'\n'}"
  printf '%s\n' "$hits"
  [ "$hits" = "lib/adapter.sh" ] && return 0
  echo "check_static: --seam: only lib/adapter.sh may expand the executable variables or run wslc, powershell.exe or pwsh.exe" >&2
  return 1
}

check_vendored() { # [<copy dir> <mount dir>]
  local copy="${1:-$ROOT/tools/lib}" mount="${2:-$ROOT/.agents/conventions/tools/lib}" name status=0
  if [ ! -f "$mount/owned.mjs" ]; then
    echo "vendored: the mount is absent ($mount), skipped"
    return 0
  fi
  for name in "${VENDORED_FILES[@]}"; do
    if [ "$(sha256sum < "$copy/$name" 2>/dev/null)" != "$(sha256sum < "$mount/$name")" ]; then
      echo "check_static: $name differs from the mounted copy (the pin moved and the copies were not refreshed)"
      status=1
    fi
  done
  [ "$status" -eq 0 ] && echo "vendored: ${#VENDORED_FILES[@]} files equal the mounted copies"
  return "$status"
}

tracked_files() { # NUL-separated paths of the regular files of the repository
  local path
  while IFS= read -r -d '' path; do
    [ -f "$ROOT/$path" ] && printf '%s\0' "$ROOT/$path"
  done < <(git -C "$ROOT" ls-files --cached --others --exclude-standard -z)
}

run_all() {
  local -a all=() sh=() py=()
  local file status=0 count
  while IFS= read -r -d '' file; do all+=("$file"); done < <(tracked_files)
  [ "${#all[@]}" -gt 0 ] || { echo "check_static: no files found (is this a git repository?)" >&2; return 2; }
  for file in "${all[@]}"; do
    case $file in
      *.sh | "$ROOT"/bin/* | "$ROOT"/tests/stubs/*) sh+=("$file") ;;
      *.py) py+=("$file") ;;
    esac
  done
  count="${#sh[@]}"
  if [ "$count" -gt 0 ]; then check_bash "${sh[@]}" && echo "bash: $count files ok" || status=1; fi
  count="${#py[@]}"
  if [ "$count" -gt 0 ]; then check_python "${py[@]}" && echo "python: $count files ok" || status=1; fi
  if scan_paths "${all[@]}"; then echo "personal paths: ${#all[@]} files ok"; else status=1; fi
  check_vendored || status=1
  if check_seam > /dev/null; then echo "seam: only lib/adapter.sh expands the executable variables or runs wslc, powershell.exe, pwsh.exe"; else check_seam >&2; status=1; fi
  return "$status"
}

case "${1:-}" in
  "") run_all ;;
  --scan) shift; scan_paths "$@" ;;
  --bash) shift; check_bash "$@" ;;
  --python) shift; check_python "$@" ;;
  --vendored) shift; check_vendored "$@" ;;
  --seam) shift; check_seam "$@" ;;
  *) echo "check_static: unknown argument $1 (use --scan, --bash, --python, --vendored or --seam)" >&2; exit 2 ;;
esac
