#!/usr/bin/env bash
# The static checks. No arguments: every check over the repository's files (`git ls-files` plus untracked files that are not
# ignored, so the check also works before the first commit; in CI the second set is empty). One check over given files:
#
#   bash tests/check_static.sh --scan <files>      personal paths (a profile path, a home directory) in any text file
#   bash tests/check_static.sh --bash <files>      `bash -n` on each file
#   bash tests/check_static.sh --python <files>    compile each file (syntax only; writes no __pycache__)
#   bash tests/check_static.sh --vendored [<copy dir> <mount dir>]   tools/lib's leftovers helper equals the mounted one
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
      *.sh | "$ROOT"/bin/*) sh+=("$file") ;;
      *.py) py+=("$file") ;;
    esac
  done
  count="${#sh[@]}"
  if [ "$count" -gt 0 ]; then check_bash "${sh[@]}" && echo "bash: $count files ok" || status=1; fi
  count="${#py[@]}"
  if [ "$count" -gt 0 ]; then check_python "${py[@]}" && echo "python: $count files ok" || status=1; fi
  if scan_paths "${all[@]}"; then echo "personal paths: ${#all[@]} files ok"; else status=1; fi
  check_vendored || status=1
  return "$status"
}

case "${1:-}" in
  "") run_all ;;
  --scan) shift; scan_paths "$@" ;;
  --bash) shift; check_bash "$@" ;;
  --python) shift; check_python "$@" ;;
  --vendored) shift; check_vendored "$@" ;;
  *) echo "check_static: unknown argument $1 (use --scan, --bash, --python or --vendored)" >&2; exit 2 ;;
esac
