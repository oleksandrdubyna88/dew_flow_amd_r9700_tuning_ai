#!/usr/bin/env bash
# tests/test_vendor.sh: vendor/benchmark_moe.py is upstream vLLM plus three marked local changes, and nothing else (E2.S1, V1-V5 and the README).
# No vLLM is needed: upstream is never in this repository, only its hash (vendor/UPSTREAM); `patch -R` turns the vendored file back into upstream.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
VENDORED="$REPO/vendor/benchmark_moe.py"
DIFF="$REPO/vendor/hooks.diff"
UPSTREAM="$REPO/vendor/UPSTREAM"
README="$REPO/vendor/README.md"
SPDX_1='# SPDX-License-Identifier: Apache-2.0'
SPDX_2='# SPDX-FileCopyrightText: Copyright contributors to the vLLM project'

upstream_value() { sed -n "s/^$1=//p" "$UPSTREAM"; }                   # the value of one line of vendor/UPSTREAM
# reversed <vendored file> <diff>: the file with the diff taken out, on stdout; patch's own temp files go to the test root
reversed() { TMPDIR="$R9700_TEST_ROOT" patch -R -r /dev/null -o - "$1" "$2" 2> /dev/null; }
hash_of() { sha256sum | cut -d' ' -f1; }

t_upstream_file_is_the_vendored_one_with_the_hooks_taken_out() {
  local want got
  want="$(upstream_value sha256)"
  assert_eq 64 "${#want}" "vendor/UPSTREAM names a 64-hex hash (the comparison is not against nothing)"
  got="$(reversed "$VENDORED" "$DIFF" | hash_of)"
  assert_eq "$want" "$got" "patch -R of the diff over the vendored file is upstream, by its hash"
  assert_exit 0 "the diff applies in reverse (dry run)" -- env TMPDIR="$R9700_TEST_ROOT" patch --dry-run -R -r /dev/null "$VENDORED" "$DIFF"
}

t_the_upstream_check_has_teeth_an_edit_outside_the_hooks_changes_the_hash() {
  local edited="$R9700_TEST_ROOT/edited.py" want got
  want="$(upstream_value sha256)"
  printf '# a stray edit outside the hooks\n' | cat - "$VENDORED" > "$edited"
  got="$(reversed "$edited" "$DIFF" | hash_of)"
  if [ "$got" = "$want" ]; then assert_eq "not the upstream hash" "$got" "an edited copy must not reach upstream's hash"; else assert_eq 1 1 "an edited copy no longer reaches upstream's hash"; fi
}

t_vendor_upstream_names_the_commit_the_path_and_the_hash() {
  assert_eq 3 "$(wc -l < "$UPSTREAM" | tr -d ' ')" "three lines"
  assert_eq 40 "$(upstream_value commit | tr -d '\n' | wc -c | tr -d ' ')" "a full commit id"
  assert_eq "benchmarks/kernels/benchmark_moe.py" "$(upstream_value path)" "the upstream path"
}

t_the_diff_is_alive_three_hunks_each_a_marked_local_change() {
  assert_eq 3 "$(grep -c '^@@' "$DIFF")" "three hunks"
  assert_eq 3 "$(grep -c '^+.*LOCAL CHANGE' "$DIFF")" "three added lines marked LOCAL CHANGE"
  local name
  for name in MOE_TUNE_CANDIDATES MOE_TUNE_ACT_DTYPE HIP_VISIBLE_DEVICES; do
    assert_eq 1 "$(grep -c "^+.*$name" "$DIFF" | awk '{ print ($1 >= 1) }')" "$name appears in an added line"
  done
}

t_the_licence_header_is_kept() {
  assert_eq "$SPDX_1" "$(sed -n 1p "$VENDORED")" "line 1 is the SPDX licence line"
  assert_eq "$SPDX_2" "$(sed -n 2p "$VENDORED")" "line 2 is the SPDX copyright line"
}

t_the_vendored_file_compiles() {
  assert_exit 0 "the static check's Python pass accepts it" -- bash "$HERE/check_static.sh" --python "$VENDORED"
}

t_the_readme_embeds_the_diff_verbatim() {
  local embedded="$R9700_TEST_ROOT/embedded.diff"
  awk '/^## The diff$/ { heading = 1; next } heading && /^```diff$/ { inside = 1; next } inside && /^```$/ { exit } inside { print }' "$README" > "$embedded"
  assert_eq 1 "$([ -s "$embedded" ] && echo 1 || echo 0)" "the fenced block after '## The diff' is not empty (the extraction is alive)"
  assert_exit 0 "the embedded block equals vendor/hooks.diff byte for byte" -- cmp "$embedded" "$DIFF"
}

t_the_readme_names_the_hash_of_the_vendored_file_and_of_upstream() {
  local text
  text="$(cat "$README")"
  assert_contains "$text" "$(sha256sum "$VENDORED" | cut -d' ' -f1)" "the sha256 of vendor/benchmark_moe.py is in the README"
  assert_contains "$text" "$(upstream_value sha256)" "the sha256 of upstream is in the README"
  assert_contains "$text" "$(upstream_value commit)" "the upstream commit is in the README"
}

run_all_tests
