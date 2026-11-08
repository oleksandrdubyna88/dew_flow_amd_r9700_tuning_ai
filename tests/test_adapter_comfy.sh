#!/usr/bin/env bash
# The adapter calls of the ComfyUI verb (E1.S2): wslc_remove, wslc_inspect and the readiness probe of the operator's ComfyUI (scenarios AW1, AW2, AW5; AW3 and AW4 extend the
# ceiling and carriage-return tests of tests/test_adapter.sh); and the three image calls of E1.S3: wslc_tag, wslc_rmi, wslc_image_list (AI1-AI3; AI4 and AI5 extend the same two tests). A separate file because tests/test_adapter.sh would pass the file-size limit. Every test body is a function
# t_<guarantee>; each runs in its own subshell and writes only below $R9700_TEST_ROOT.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"

# AW1
t_wslc_remove_removes_exactly_the_named_container_and_keeps_the_name_check() {
  setup_case "$FUNCNAME"
  mkdir -p "$STUB/stopped"
  : > "$STUB/stopped/comfyui"
  assert_exit 0 "wslc_remove comfyui" -- wslc_remove comfyui
  argv_of wslc
  assert_eq "remove|comfyui" "$(IFS='|'; echo "${ARGV[*]}")" "the argv is remove <name>"
  assert_eq "comfyui" "$OUT" "the child's line, printed without a CR"
  assert_exit 1 "the code is the child's (a name that is not there)" -- wslc_remove comfyui
  assert_contains "$OUT" "stub: no such container: comfyui" "and its line is printed"
  assert_not_contains "$OUT" "$CR" "without a CR"
  rm -f "$STUB/calls.log" "$STUB/calls.argv"
  local bad
  for bad in -x '' 'a b'; do
    assert_exit 2 "wslc_remove \"$bad\" is refused" -- wslc_remove "$bad"
    assert_contains "$ERR" "wslc_remove" "naming the function"
    assert_contains "$ERR" "container name" "and the noun"
  done
  assert_missing "$STUB/calls.log" "no call was made"
}

# AW2
t_wslc_inspect_takes_an_image_or_container_reference() {
  setup_case "$FUNCNAME"
  assert_exit 0 "wslc_inspect of an image reference" -- wslc_inspect comfyui-r9700:local
  argv_of wslc
  assert_eq "inspect|comfyui-r9700:local" "$(IFS='|'; echo "${ARGV[*]}")" "the argv is inspect <reference>"
  assert_contains "$OUT" '"Created": "2026-11-07T10:00:00.000000000Z"' "the JSON is printed"
  assert_not_contains "$OUT" "$CR" "without a CR"
  assert_exit 0 "a reference with a slash" -- wslc_inspect rocm/vllm:rocm10.1.0
  rm -f "$STUB/calls.log" "$STUB/calls.argv"
  local bad
  for bad in -x '' 'a b'; do
    assert_exit 2 "wslc_inspect \"$bad\" is refused" -- wslc_inspect "$bad"
    assert_contains "$ERR" "wslc_inspect" "naming the function"
    assert_contains "$ERR" "reference" "and the noun"
  done
  assert_missing "$STUB/calls.log" "no call was made"
  printf '1\n' > "$STUB/answers/inspect_rc"
  assert_exit 1 "the stub's code is the function's code" -- wslc_inspect comfyui-r9700:local
}

# comfy_probe_run <mode>: the adapter's ComfyUI probe program under python with urllib.request.urlopen replaced by a fake that answers by <mode>; prints what the program
# printed; the request (method, url, timeout) goes to stderr as JSON.
comfy_probe_run() {
  python3 -I -c '
import json, sys, urllib.error, urllib.request
mode, seen = sys.argv[2], []
class Reply:
    def __init__(self, status, body): self.status, self.body = status, body
    def __enter__(self): return self
    def __exit__(self, *a): return False
    def read(self): return self.body
def fake(req, timeout=None):
    seen.append([req.get_method(), req.full_url, timeout, req.data is None])
    if mode == "down": raise urllib.error.URLError("refused")
    if mode == "http500": raise urllib.error.HTTPError(req.full_url, 500, "x", {}, None)
    if mode == "http204": return Reply(204, b"")
    if mode == "badjson": return Reply(200, b"nope")
    if mode == "nokey": return Reply(200, b"{}")
    if mode == "nodevice": return Reply(200, b"{\"devices\": []}")
    return Reply(200, json.dumps({"devices": [{"name": "cuda:0 X : native"}]}).encode())
urllib.request.urlopen = fake
try:
    exec(compile(sys.argv[1], "probe", "exec"))
finally:
    print(json.dumps(seen), file=sys.stderr)
' "$(comfy_probe_program)" "$1"
}

# AW5
t_the_comfyui_probe_program_names_the_device_or_the_failing_step() {
  setup_case "$FUNCNAME"
  assert_exit 0 "a 200 with a device" -- comfy_probe_run ok
  assert_eq "device cuda:0 X : native|ready" "$(echo "$OUT" | tr '\n' '|' | sed 's/|$//')" "the device line, then ready"
  assert_contains "$ERR" '["GET", "http://127.0.0.1:8188/system_stats", 5, true]' "the request: GET /system_stats, 5 s, no body"
  assert_exit 1 "an HTTPError 500" -- comfy_probe_run http500
  assert_eq "system_stats: HTTP 500" "$OUT" "the status is named"
  assert_exit 1 "a 204" -- comfy_probe_run http204
  assert_eq "system_stats: HTTP 204" "$OUT" "a status other than 200 is a failure"
  assert_exit 1 "a URLError" -- comfy_probe_run down
  assert_eq "system_stats: URLError" "$OUT" "the exception class"
  assert_exit 1 "a 200 with nope" -- comfy_probe_run badjson
  assert_eq "system_stats: JSONDecodeError" "$OUT" "the exception class"
  assert_exit 1 "a 200 with {}" -- comfy_probe_run nokey
  assert_eq "system_stats: KeyError" "$OUT" "the exception class"
  assert_exit 1 "a 200 with no device" -- comfy_probe_run nodevice
  assert_eq "system_stats: IndexError" "$OUT" "the exception class"
}

t_comfy_probe_runs_the_program_through_exec_and_keeps_the_name_check() {
  setup_case "$FUNCNAME"
  printf 'ok\n' > "$STUB/answers/comfy_ready"
  wslc_run comfyui img > /dev/null
  assert_exit 0 "comfy_probe comfyui" -- comfy_probe comfyui
  assert_eq "device cuda:0 AMD Radeon AI PRO R9700 : native|ready" "$(echo "$OUT" | tr '\n' '|' | sed 's/|$//')" "the stub's device line, then ready"
  assert_not_contains "$OUT" "$CR" "no CR"
  argv_of wslc
  assert_eq "exec|comfyui|python3|-c" "$(IFS='|'; echo "${ARGV[*]:0:4}")" "it runs the program through exec <name> python3 -c"
  assert_contains "${ARGV[4]}" "/system_stats" "the program names the route"
  assert_exit 2 "an option for a name" -- comfy_probe -x
  assert_contains "$ERR" "comfy_probe" "names the function"
  kill_recorded_pids "$CASE"
}

# AI1
t_wslc_tag_hands_on_two_references_and_refuses_anything_else_before_a_call() {
  setup_case "$FUNCNAME"
  printf 'comfyui-r9700 20261107T120000Z sha256:%064d\n' 1 > "$STUB/images"
  assert_exit 0 "wslc_tag of two references" -- wslc_tag comfyui-r9700:20261107T120000Z comfyui-r9700:local
  argv_of wslc
  assert_eq "tag|comfyui-r9700:20261107T120000Z|comfyui-r9700:local" "$(IFS='|'; echo "${ARGV[*]}")" "the argv is tag <source> <target>"
  assert_not_contains "$OUT" "$CR" "no CR in what it prints"
  rm -f "$STUB/calls.log" "$STUB/calls.argv"
  local -a bad
  local i
  for i in 1 2 3 4; do
    case $i in
      1) bad=(-x a:b) ;;
      2) bad=(a:b '') ;;
      3) bad=('a b' c:d) ;;
      4) bad=(a:b) ;;
    esac
    assert_exit 2 "wslc_tag with ${#bad[@]} words, the first [${bad[0]}]" -- wslc_tag "${bad[@]}"
    assert_eq "1" "$(grep -c . <<< "$ERR")" "[$i] one line"
    assert_contains "$ERR" "wslc_tag" "[$i] names the function"
    assert_contains "$ERR" "reference" "[$i] and the noun"
  done
  assert_missing "$STUB/calls.log" "no call was made"
  printf '1\n' > "$STUB/answers/tag_rc"
  assert_exit 1 "the child's code is the function's code" -- wslc_tag a:b c:d
}

# AI2
t_wslc_rmi_removes_one_exact_tag_and_nothing_that_could_mean_more() {
  setup_case "$FUNCNAME"
  printf 'comfyui-r9700 20261107T120000Z sha256:%064d\n' 1 > "$STUB/images"
  assert_exit 0 "wslc_rmi of an exact tag" -- wslc_rmi comfyui-r9700:20261107T120000Z
  argv_of wslc
  assert_eq "rmi|comfyui-r9700:20261107T120000Z" "$(IFS='|'; echo "${ARGV[*]}")" "the argv is rmi <tag>"
  rm -f "$STUB/calls.log" "$STUB/calls.argv"
  local bad
  for bad in comfyui-r9700 sha256:5662f4cbd417 5662f4cbd417 -f 'comfyui-r9700:*' ''; do
    assert_exit 2 "wslc_rmi [$bad] is refused" -- wslc_rmi "$bad"
    assert_eq "1" "$(grep -c . <<< "$ERR")" "[$bad] one line"
    assert_contains "$ERR" "wslc_rmi: \"$bad\" is not an exact image tag (<repository>:<tag>; never an id, a pattern or an option)" "[$bad] the line"
  done
  assert_exit 2 "wslc_rmi with two words" -- wslc_rmi a:b c:d
  assert_contains "$ERR" "wslc_rmi" "names the function"
  assert_exit 2 "wslc_rmi with no word" -- wslc_rmi
  assert_missing "$STUB/calls.log" "no call was made for any of them"
}

# AI3
t_wslc_image_list_prints_repository_tag_and_id_one_image_per_line() {
  setup_case "$FUNCNAME"
  local fixture="$HERE/fixtures/comfy/image_list.txt" want="" repository tag id _rest
  cp "$fixture" "$STUB/answers/image_list"
  # the expected words are cut from the fixture's own rows (the header is the first line): the parse under test is not used to make them
  while read -r repository tag id _rest; do want+="$repository $tag $id"$'\n'; done < <(tail -n +2 "$fixture")
  assert_exit 0 "wslc_image_list" -- wslc_image_list
  assert_eq "${want%$'\n'}" "$OUT" "exactly the three rows' first three columns, whole ids"
  assert_eq "3" "$(grep -c . <<< "$OUT")" "three lines, no header"
  assert_not_contains "$OUT" "$CR" "no CR"
  assert_not_contains "$OUT" "hours" "no CREATED word"
  assert_not_contains "$OUT" "GB" "no SIZE word"
  assert_contains "$OUT" "comfyui-r9700 local sha256:5662f4cbd4173b5a2b276b1c58a47a1309f4e632e3dab2e5a84bdd0d02c0d1e1" "the first row's whole id"
  argv_of wslc
  assert_eq "image|list|--no-trunc" "$(IFS='|'; echo "${ARGV[*]}")" "the argv is image list --no-trunc"
  printf '1\n' > "$STUB/fail-image-list"
  assert_exit 1 "a failing list returns non-zero" -- wslc_image_list
  assert_eq "" "$OUT" "and prints nothing on stdout"
}

run_all_tests
