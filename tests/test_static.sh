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

# ---- the adapter seam (E1.S2 decision 11, scenario A6): expansions of the three variables, and the executables used as commands

# seam_code <name> <file> <line>: a fake tree whose <file> (lib/other.sh or bin/tool) holds the one line
seam_code() {
  local root
  root="$(seam_tree "$1")"
  printf '%s\n' "$3" > "$root/$2"
  echo "$root"
}

t_the_seam_check_finds_an_executable_used_as_a_command_outside_the_adapter() {
  local root form n=0
  for form in 'wslc list' 'x;wslc list' 'x&&pwsh.exe -File y' 'x|powershell.exe y' 'a&wslc list' 'x; wslc list' 'x && pwsh.exe -File y' 'x | powershell.exe -Command y' '(wslc list)' 'x=$(wslc list)' 'a & wslc list' 'echo hi; powershell.exe' 'v=`pwsh.exe -x`' "	wslc stop z" 'timeout 60 "wslc" stop a' 'wslc.exe list' "'pwsh.exe' -File a" 'w=wslc; $w list' 'w="pwsh.exe";$w x' 'x=powershell $y' "w='wslc.exe' \$w" 'timeout 5 pwsh -File q'; do
    n=$((n + 1))
    root="$(seam_code "cmd$n" lib/other.sh "$form")"
    assert_exit 1 "[$form] in lib/other.sh" -- bash "$CHECK" --seam "$root"
    assert_contains "$OUT" "lib/other.sh" "[$form]: names the file"
  done
  root="$(seam_code cmdbin bin/r9700 'wslc list')"
  assert_exit 1 "a command in bin/r9700" -- bash "$CHECK" --seam "$root"
  assert_contains "$OUT" "bin/r9700" "names the file"
}

t_the_seam_check_ignores_command_words_in_comments_and_longer_names() {
  local root form n=0
  for form in '# wslc list' '   # then call pwsh.exe -File x' 'wslc_run a b' 'my_wslc list' 'wslc.exes list' 'echo powershell.exe.bak' 'wslcx list' 'x=$R9700_WSLC_NOT_A_THING' 'x=wslcx' 'x=mywslc' 'x=pwshell'; do
    n=$((n + 1))
    root="$(seam_code "ok$n" lib/other.sh "$form")"
    assert_exit 0 "[$form] passes" -- bash "$CHECK" --seam "$root"
    assert_eq "lib/adapter.sh" "$OUT" "[$form]: still exactly the adapter"
  done
}

# config_tree <name> <extra line>: a fake tree whose lib/config.sh holds the three default declarations of the real field table and the extra line
CONFIG_DECLARATIONS=('_field machine WSLC cmd "wslc" "the command for wslc, a bare name looked up on PATH, or an absolute path"'
  '_field machine POWERSHELL cmd "powershell.exe" "Windows PowerShell, for the RAM and disk probes"'
  '_field machine RESTORE_SHELL cmd "pwsh.exe" "the shell that runs the start script"')
config_tree() {
  local root
  root="$(seam_tree "$1")"
  printf '%s\n' "${CONFIG_DECLARATIONS[@]}" > "$root/lib/config.sh"
  [ -n "${2:-}" ] && printf '%s\n' "$2" >> "$root/lib/config.sh"
  echo "$root"
}

t_the_named_exception_for_the_default_declarations_of_config_sh_is_exact() {
  local root form n=0
  root="$(config_tree cfgok)"
  assert_exit 0 "the three default declarations of the field table pass" -- bash "$CHECK" --seam "$root"
  assert_eq "lib/adapter.sh" "$OUT" "nothing but the adapter is named"
  for form in 'wslc list' 'x() { timeout 5 wslc list; }' '_field machine WSLC cmd "wslc" "x"; wslc list' '_field machine WSLC cmd "wslc" "x" && pwsh.exe -File y' '_field machine OTHER cmd "wslc" "x"' '_field machine WSLC cmd "wslc list" "x"' '_field machine WSLC cmd "wslc" "$(wslc list)"' 'w=pwsh.exe; $w x'; do
    n=$((n + 1))
    root="$(config_tree "cfgbad$n" "$form")"
    assert_exit 1 "[$form] next to the declarations is still caught" -- bash "$CHECK" --seam "$root"
    assert_contains "$OUT" "lib/config.sh" "[$form]: names lib/config.sh"
  done
  root="$(seam_tree cfgother)"
  printf '%s\n' "${CONFIG_DECLARATIONS[@]}" > "$root/lib/other.sh"
  assert_exit 1 "the same declarations in another file are not excused" -- bash "$CHECK" --seam "$root"
  assert_contains "$OUT" "lib/other.sh" "names lib/other.sh"
  root="$(config_tree cfgreal)"
  cp "$REPO/lib/config.sh" "$root/lib/config.sh"
  assert_exit 0 "the real lib/config.sh passes" -- bash "$CHECK" --seam "$root"
  printf '%s\n' 'planted() { wslc list; }' >> "$root/lib/config.sh"
  assert_exit 1 "the real lib/config.sh with one planted call is caught" -- bash "$CHECK" --seam "$root"
}

t_the_adapter_itself_may_use_the_command_words() {
  local root
  root="$(seam_tree adapterwords)"
  printf '%s\n' 'x() { timeout 5 wslc list; }' >> "$root/lib/adapter.sh"
  assert_exit 0 "command words in lib/adapter.sh are its job" -- bash "$CHECK" --seam "$root"
}

t_the_command_word_scan_is_alive_over_a_copy_of_the_real_files() {
  local root="$R9700_TEST_ROOT/seam-realcopy"
  mkdir -p "$root"
  cp -r "$REPO/lib" "$root/lib"
  [ -d "$REPO/bin" ] && cp -r "$REPO/bin" "$root/bin"
  assert_exit 0 "a copy of the real lib/ and bin/ passes" -- bash "$CHECK" --seam "$root"
  printf '%s\n' 'planted() { wslc list; }' >> "$root/lib/serve.sh"
  assert_exit 1 "the same copy with one planted command is caught" -- bash "$CHECK" --seam "$root"
  assert_contains "$OUT" "lib/serve.sh" "names the file"
  assert_exit 0 "the real tree passes" -- bash "$CHECK" --seam
}

t_the_expansion_scan_counts_only_code_lines_of_the_adapter() {
  local root
  root="$(seam_tree commentonly)"
  printf '%s\n' '# "$R9700_WSLC" x' '# "${R9700_POWERSHELL}" x' '# "$R9700_RESTORE_SHELL" x' 'a() { :; }' > "$root/lib/adapter.sh"
  assert_exit 2 "three expansions in comments are a dead scan" -- bash "$CHECK" --seam "$root"
}

t_only_the_adapter_expands_the_executable_names() {
  assert_exit 0 "check_static.sh --seam passes on the repository" -- bash "$CHECK" --seam
  assert_eq "lib/adapter.sh" "$OUT" "it prints exactly lib/adapter.sh"
  assert_exit 0 "the same scan over lib/adapter.sh alone is alive" -- test "$(grep -cE '\$\{?R9700_(WSLC|POWERSHELL|RESTORE_SHELL)' "$REPO/lib/adapter.sh")" -ge 3
}

# tree <name>: a fake repository root with an adapter that expands all three names, lib/ and bin/
seam_tree() {
  local root="$R9700_TEST_ROOT/seam-$1"
  mkdir -p "$root/lib" "$root/bin"
  printf '%s\n' 'a() { "$R9700_WSLC" x; }' 'b() { "${R9700_POWERSHELL}" x; }' 'c() { "$R9700_RESTORE_SHELL" x; }' > "$root/lib/adapter.sh"
  echo "$root"
}

t_the_seam_check_names_a_second_file_that_expands_an_executable() {
  local root
  root="$(seam_tree lib)"
  printf '%s\n' 'x() { "${R9700_WSLC}" list; }' > "$root/lib/other.sh"
  assert_exit 1 "a second lib file" -- bash "$CHECK" --seam "$root"
  assert_contains "$OUT" "lib/other.sh" "names it"
  root="$(seam_tree bin)"
  printf '%s\n' '#!/usr/bin/env bash' '"$R9700_POWERSHELL" -x' > "$root/bin/r9700"
  assert_exit 1 "a bin file" -- bash "$CHECK" --seam "$root"
  assert_contains "$OUT" "bin/r9700" "names it"
  root="$(seam_tree shell)"
  printf '%s\n' 'x() { "$R9700_RESTORE_SHELL" -x; }' > "$root/lib/other.sh"
  assert_exit 1 "the restore shell" -- bash "$CHECK" --seam "$root"
}

t_the_seam_check_ignores_names_that_are_not_expansions() {
  local root
  root="$(seam_tree comment)"
  printf '%s\n' '# R9700_WSLC is read by lib/adapter.sh only' 'echo "R9700_POWERSHELL"' 'x() { printf %s "$R9700_RESTORE_SCRIPT_WIN"; }' > "$root/lib/other.sh"
  assert_exit 0 "comments and other variables pass" -- bash "$CHECK" --seam "$root"
  assert_eq "lib/adapter.sh" "$OUT" "still exactly the adapter"
}

t_a_seam_scan_that_finds_nothing_is_an_error_not_a_pass() {
  local root
  root="$(seam_tree dead)"
  printf '%s\n' '# the adapter lost its expansions' > "$root/lib/adapter.sh"
  assert_exit 2 "an adapter with no expansion: the scan is dead" -- bash "$CHECK" --seam "$root"
  rm "$root/lib/adapter.sh"
  assert_exit 2 "no adapter at all" -- bash "$CHECK" --seam "$root"
}

run_all_tests
