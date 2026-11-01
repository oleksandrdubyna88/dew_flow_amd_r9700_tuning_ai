#!/usr/bin/env bash
# tests/check_static.sh: the static checks (scenarios 41-45). The planted personal paths are BUILT here from two parts, so no
# tracked file — this one included — holds a match.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
CHECK="$HERE/check_static.sh"

# plant <name> <part one> <part two>: a file with one line made of the two parts and a leading word
plant() {
  local file="$R9700_TEST_ROOT/$FUNCNAME-$1.txt"
  printf 'see %s%s here\n' "$2" "$3" > "$file"
  echo "$file"
}

t_the_tracked_tree_is_clean() {
  assert_exit 0 "check_static.sh exits 0 on the tree" -- bash "$CHECK"
  assert_contains "$OUT" "bash:" "it ran the bash check"
  assert_contains "$OUT" "python:" "it ran the python check"
  assert_contains "$OUT" "personal paths:" "it ran the personal-path check"
  assert_contains "$OUT" "vendored:" "it ran the vendored-copy check"
}

t_the_scan_finds_a_planted_windows_profile_path() {
  local file; file="$(plant win 'C:\Us' 'ers\someone\x')"
  assert_exit 1 "found" -- bash "$CHECK" --scan "$file"
  assert_contains "$OUT" "$(basename "$file"):1:" "names the file and the line"
}

t_the_scan_finds_a_planted_lowercase_windows_profile_path() {
  local file; file="$(plant lowerwin 'c:\us' 'ers\someone\x')"
  assert_exit 1 "found" -- bash "$CHECK" --scan "$file"
  assert_contains "$OUT" "$(basename "$file"):1:" "names the file and the line"
  file="$(plant lowermnt '/mnt/c/us' 'ers/someone')"
  assert_exit 1 "the /mnt/c form in lower case is found too" -- bash "$CHECK" --scan "$file"
}

t_the_scan_finds_a_planted_mnt_profile_path() {
  local file; file="$(plant mnt '/mnt/c/Us' 'ers/someone')"
  assert_exit 1 "found" -- bash "$CHECK" --scan "$file"
  assert_contains "$OUT" "$(basename "$file"):1:" "names the file and the line"
}

t_the_scan_finds_a_planted_linux_home_directory() {
  local file; file="$(plant linux '/ho' 'me/someone/x')"
  assert_exit 1 "found" -- bash "$CHECK" --scan "$file"
  assert_contains "$OUT" "$(basename "$file"):1:" "names the file and the line"
}

t_the_scan_finds_a_planted_macos_home_directory() {
  local file; file="$(plant mac '/Us' 'ers/someone/x')"
  assert_exit 1 "found" -- bash "$CHECK" --scan "$file"
  assert_contains "$OUT" "$(basename "$file"):1:" "names the file and the line"
}

t_the_scan_passes_the_documented_placeholders() {
  local file="$R9700_TEST_ROOT/placeholders.txt"
  printf '%s\n' 'WORK_DIR_WIN=C:\r9700\work' "RESULTS=/mnt/c/r9700/results" > "$file"
  printf 'profile %s%s\n' 'C:\Us' 'ers\<you>\x' >> "$file"
  printf 'profile %s%s\n' '/ho' 'me/<you>/x' >> "$file"
  assert_exit 0 "placeholders pass" -- bash "$CHECK" --scan "$file"
}

t_the_scan_of_nothing_is_an_error_not_a_pass() {
  assert_exit 2 "no files given" -- bash "$CHECK" --scan
  assert_exit 2 "a file that does not exist" -- bash "$CHECK" --scan "$R9700_TEST_ROOT/nosuch.txt"
}

t_a_syntax_error_is_caught() {
  local bad="$R9700_TEST_ROOT/bad.sh" good="$R9700_TEST_ROOT/good.sh" badpy="$R9700_TEST_ROOT/bad.py" goodpy="$R9700_TEST_ROOT/good.py"
  printf 'if then\n' > "$bad"
  printf 'echo fine\n' > "$good"
  printf 'def (\n' > "$badpy"
  printf 'x = 1\n' > "$goodpy"
  assert_exit 1 "bad bash is refused" -- bash "$CHECK" --bash "$bad"
  assert_contains "$OUT$ERR" "bad.sh" "names the bash file"
  assert_exit 0 "good bash passes" -- bash "$CHECK" --bash "$good"
  assert_exit 1 "bad python is refused" -- bash "$CHECK" --python "$badpy"
  assert_contains "$OUT$ERR" "bad.py" "names the python file"
  assert_exit 0 "good python passes" -- bash "$CHECK" --python "$goodpy"
  assert_missing "$R9700_TEST_ROOT/__pycache__" "the python check writes no bytecode"
}

t_machine_env_cannot_be_committed_by_accident() {
  assert_exit 0 "git check-ignore -q machine.env" -- git -C "$REPO" check-ignore -q machine.env
  assert_exit 0 ".venv is ignored too" -- git -C "$REPO" check-ignore -q .venv/x
}

t_the_vendored_leftovers_helper_equals_the_mounted_one() {
  assert_exit 0 "the copies equal the mounted files" -- bash "$CHECK" --vendored
  local copy="$R9700_TEST_ROOT/copy" mount="$HERE/../.agents/conventions/tools/lib" name
  mkdir -p "$copy"
  for name in owned.mjs git.mjs leftovers-sweep.mjs; do cp "$REPO/tools/lib/$name" "$copy/$name"; done
  assert_exit 0 "an identical copy passes" -- bash "$CHECK" --vendored "$copy" "$mount"
  printf '// changed\n' >> "$copy/git.mjs"
  assert_exit 1 "a changed copy fails" -- bash "$CHECK" --vendored "$copy" "$mount"
  assert_contains "$OUT$ERR" "git.mjs" "names the file"
  assert_exit 0 "an absent mount is skipped, said once" -- bash "$CHECK" --vendored "$copy" "$R9700_TEST_ROOT/no-mount"
  assert_contains "$OUT" "skipped" "says it skipped"
}

run_all_tests
