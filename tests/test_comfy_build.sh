#!/usr/bin/env bash
# `bin/r9700 comfy build` (E1.S3, scenarios BU1-BU16): the placement of comfyui/, the build to a STAMPED tag, the check of that tag by a throwaway container on the card, the promotion of
# COMFY_IMAGE only after the check, the retention of four stamped tags, the refusal beside either owner of the card. The stub keeps its images as records (tests/stubs/wslc). Every
# build scenario sets R9700_TEST_COMFY_STAMP, 20261107T120000Z unless it says otherwise. Every test body is a function t_<guarantee>; each runs in its own subshell and writes only below
# $R9700_TEST_ROOT. Waits are bounded polls on a call-log line or a file.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"
# shellcheck source=tests/lib/lifecycle.sh
source "$HERE/lib/lifecycle.sh"
# shellcheck source=tests/lib/comfycase.sh
source "$HERE/lib/comfycase.sh"

STAMP=20261107T120000Z
REPO_NAME=comfyui-r9700
STAMPED="$REPO_NAME:$STAMP"
CUR="$REPO_NAME:local"

# bu_setup <name>: the stub world of a build and its stamp
bu_setup() {
  comfy_setup "$1"
  export R9700_TEST_COMFY_STAMP="$STAMP"
  PLACED="$R9700_WORK_DIR/r9700/comfyui"
}

# id_of <k>: the id of the planted image k (900 + k: far from the counter-made ids of builds)
id_of() { printf 'sha256:%064d' "$((900 + $1))"; }

# plant <n>: n stamped tags comfyui-r9700:2026110<k>T100000Z (k = 1..9), each with an id of its own, and `local` on the id of k = n: the state n passed builds leave
plant() {
  local k
  mkdir -p "$STUB"
  : > "$STUB/images"
  for k in $(seq 1 "$1"); do printf '%s 2026110%sT100000Z %s\n' "$REPO_NAME" "$k" "$(id_of "$k")" >> "$STUB/images"; done
  printf '%s local %s\n' "$REPO_NAME" "$(id_of "$1")" >> "$STUB/images"
}

images_text() { cat "$STUB/images" 2> /dev/null; }

# stamp_tags: the stamped tags of the repository, one per line, sorted
stamp_tags() { awk -v r="$REPO_NAME" '$1 == r && $2 ~ /^[0-9]{8}T[0-9]{6}Z$/ { print $2 }' "$STUB/images" | LC_ALL=C sort; }

# engine_calls <verb>...: how many calls of the named verbs the call log holds, summed
engine_calls() {
  local total=0 verb
  for verb in "$@"; do total=$((total + $(calls_of_verb "$verb"))); done
  echo "$total"
}

# rmi_words: every `rmi` call of the call log, one line each: its words after rmi joined by a space
rmi_words() { awk '$3 == "wslc" && $4 == "rmi" { $1 = $2 = $3 = $4 = ""; sub(/^ +/, ""); print }' "$STUB/calls.log" 2> /dev/null; }

# rmi_shapes_ok: 0 when every rmi call is two words, rmi and ONE comfyui-r9700:<stamp>: never an id, a pattern or -f
rmi_shapes_ok() {
  local line bad=0
  while IFS= read -r line; do
    [[ $line =~ ^$REPO_NAME:[0-9]{8}T[0-9]{6}Z$ ]] || bad=1
  done < <(rmi_words)
  return "$bad"
}

line_count() { grep -c . <<< "$1"; }

placed_sums() { (cd "$PLACED" 2> /dev/null && sha256sum Containerfile entrypoint.sh fetch_model.sh 2> /dev/null); }
repo_sums() { (cd "$REPO/comfyui" && sha256sum Containerfile entrypoint.sh fetch_model.sh); }

# BU1
t_the_build_places_its_files_hash_checked_before_it_builds() {
  bu_setup "$FUNCNAME"
  assert_exit 0 "comfy build with no placed copy" -- comfy build
  assert_eq "$(repo_sums)" "$(placed_sums)" "the placed Containerfile, entrypoint.sh and fetch_model.sh equal the repository's by sha256"
  bu_setup "$FUNCNAME-stale"
  mkdir -p "$PLACED"
  printf 'stale\n' > "$PLACED/Containerfile"
  printf '5\n' > "$STUB/answers/build_seconds"
  comfy_bg build
  wait_call ' wslc build ' 100
  assert_eq "$(repo_sums)" "$(placed_sums)" "with a stale placed copy: it was rewritten by the time the build call is in the log"
  comfy_end 30
  assert_eq "0" "$SRC" "the build ended 0"
}

# BU2
t_the_build_argv_is_the_configs_one_word_each_and_names_the_stamped_tag_never_comfy_image() {
  bu_setup "$FUNCNAME"
  local win="$R9700_WORK_DIR_WIN\\r9700\\comfyui" repo="${R9700_COMFY_IMAGE%:*}"
  assert_exit 0 "comfy build" -- comfy build
  argv_of_verb build
  assert_eq "build|-t|$repo:$STAMP|-f|$win\\Containerfile|--build-arg|BASE=$R9700_COMFY_BASE_IMAGE|--build-arg|COMFYUI_REF=$R9700_COMFY_REF|$win" "$(IFS='|'; echo "${ARGV[*]}")" "the argv is the config's, one word each, the stamped tag"
  assert_eq "1" "$(engine_calls build)" "one build call"
  assert_not_contains "${ARGV[*]}" "--no-cache" "no --no-cache without the option"
  assert_not_contains "$(IFS='|'; echo "${ARGV[*]}")" "|$R9700_COMFY_IMAGE|" "COMFY_IMAGE is not a word of the build"
  bu_setup "$FUNCNAME-nocache"
  assert_exit 0 "comfy build --no-cache" -- comfy build --no-cache
  argv_of_verb build
  assert_eq "--no-cache" "$(printf '%s\n' "${ARGV[@]}" | grep -x -- '--no-cache')" "--no-cache is a word of the build"
  assert_eq "$win" "${ARGV[-1]}" "and the context stays the last word"
  bu_setup "$FUNCNAME-x"
  sed -i 's|^WORK_DIR_WIN=.*|WORK_DIR_WIN=X:\\|' "$CASE/machine.env"
  assert_exit 0 "WORK_DIR_WIN ends in a backslash" -- comfy build
  argv_of_verb build
  assert_eq 'X:\r9700\comfyui' "${ARGV[-1]}" "the context is X:\\r9700\\comfyui, never a doubled backslash"
  assert_eq 'X:\r9700\comfyui\Containerfile' "${ARGV[4]}" "and so is the file"
  bu_setup "$FUNCNAME-clock"
  unset R9700_TEST_COMFY_STAMP
  assert_exit 0 "without the knob" -- comfy build
  argv_of_verb build
  if [[ ${ARGV[2]} =~ ^$repo:[0-9]{8}T[0-9]{6}Z$ ]]; then assert_eq ok ok "the stamp is the UTC clock's"; else assert_eq "$repo:<YYYYMMDDTHHMMSSZ>" "${ARGV[2]}" "the stamp is the UTC clock's"; fi
}

# BU3
t_the_stamped_image_is_checked_by_a_throwaway_container_on_the_card() {
  bu_setup "$FUNCNAME"
  assert_exit 0 "comfy build" -- comfy build
  assert_contains "$OUT" "comfy: build: device AMD Radeon AI PRO R9700" "stdout names the device"
  argv_of_verb run
  assert_eq "run|--rm|--name|${R9700_CONTAINER_PREFIX}comfy-check|--gpus|all|--entrypoint|python3|$STAMPED|-c" "$(IFS='|'; echo "${ARGV[*]:0:10}")" "one foreground run on the card of the STAMPED tag, never COMFY_IMAGE"
  assert_eq "11" "${#ARGV[@]}" "and the program is the last word"
  assert_contains "${ARGV[10]}" "torch.version.hip" "the program reads the hip version"
  assert_eq "1" "$(engine_calls run)" "exactly one run call"
}

# BU4
t_a_built_image_without_a_rocm_device_is_refused_and_nothing_it_was_about_to_replace_moves() {
  local variant answer why planted
  for variant in hip device matmul rc; do
    bu_setup "$FUNCNAME-$variant"
    plant 4
    planted="$(images_text)"
    case $variant in
      hip) answer=$'torch 2.13.0+rocm10.1.0\nhip None\ndevice AMD Radeon AI PRO R9700\nmatmul ok' why="hip None" ;;
      device) answer=$'torch 2.13.0+rocm10.1.0\nhip 10.1.0\ndevice none\nmatmul nan' why="device none" ;;
      matmul) answer=$'torch 2.13.0+rocm10.1.0\nhip 10.1.0\ndevice AMD Radeon AI PRO R9700\nmatmul nan' why="matmul nan" ;;
      rc) answer=$'torch 2.13.0+rocm10.1.0\nhip 10.1.0\ndevice AMD Radeon AI PRO R9700\nmatmul ok' why="the check exited with code 1: matmul ok" ;;
    esac
    printf '%s\n' "$answer" > "$STUB/answers/comfy_check"
    [ "$variant" != rc ] || printf '1\n' > "$STUB/answers/comfy_check_rc"
    assert_exit 1 "[$variant] the check fails" -- comfy build
    assert_eq "r9700: comfy: build: the built image $STAMPED is not usable on the card: $why; $CUR was not moved" "$ERR" "[$variant] one line, the check's line and the promise"
    assert_eq "0" "$(calls_of_verb tag)" "[$variant] no tag call"
    assert_eq "1" "$(calls_of_verb rmi)" "[$variant] exactly one rmi"
    argv_of_verb rmi
    assert_eq "rmi|$STAMPED" "$(IFS='|'; echo "${ARGV[*]}")" "[$variant] its argv is the rejected stamped tag, by its exact name"
    assert_eq "$planted" "$(images_text)" "[$variant] the stub's records are the planted ones, record by record"
  done
}

# scaled_build: `comfy build` with the adapter's ceilings divided by 50 (COMFY_BUILD_MAX_S 600 is then a 12 s ceiling). 50 and not 100: at 100 every other adapter call of the verb (the
# list calls, 60 s) would get a 0.6 s ceiling, and a stub call takes up to 227 ms under load, so a call that only waited for the CPU could be cut and the test would fail for that reason
scaled_build() { R9700_CEILING_SCALE=50 comfy build; }

# BU5
t_a_failed_build_starts_no_check_container_and_moves_nothing() {
  local planted
  bu_setup "$FUNCNAME-rc"
  plant 4
  planted="$(images_text)"
  printf '1\n' > "$STUB/answers/build_rc"
  assert_exit 1 "answers/build_rc 1" -- comfy build
  assert_eq "1" "$(line_count "$ERR")" "one stderr line"
  assert_contains "$ERR" "the build failed (code 1)" "it names the build's code"
  assert_eq "0" "$(engine_calls run tag rmi)" "no run, tag or rmi call"
  assert_eq "$planted" "$(images_text)" "the records are unchanged (the stub records no tag for a failed build)"
  bu_setup "$FUNCNAME-tagged"
  plant 4
  planted="$(images_text)"
  printf '1\n' > "$STUB/answers/build_rc"
  printf '1\n' > "$STUB/answers/build_tags_on_failure"
  assert_exit 1 "a failed build the engine tagged before it failed" -- comfy build
  assert_eq "1" "$(calls_of_verb rmi)" "one rmi"
  argv_of_verb rmi
  assert_eq "rmi|$STAMPED" "$(IFS='|'; echo "${ARGV[*]}")" "its argv is the stamped tag, by its exact name"
  assert_eq "$planted" "$(images_text)" "the records are the planted ones again"
  bu_setup "$FUNCNAME-ceiling"
  plant 4
  planted="$(images_text)"
  printf '100\n' > "$STUB/answers/build_seconds"
  step_cfg COMFY_BUILD_MAX_S=600
  assert_exit 1 "a build cut by its ceiling (a 12 s ceiling: COMFY_BUILD_MAX_S 600 at scale 50)" -- scaled_build
  assert_contains "$ERR" "ceiling ended it" "the line says the ceiling ended it"
  assert_eq "0" "$(engine_calls run tag)" "no check container, no tag call"
  assert_eq "$planted" "$(images_text)" "the records are unchanged"
}

# BU6
t_a_placement_that_cannot_be_written_is_refused_before_any_engine_call_after_the_admission() {
  bu_setup "$FUNCNAME"
  : > "$R9700_WORK_DIR/r9700"
  assert_exit 2 "\$WORK_DIR/r9700 is a file" -- comfy build
  assert_contains "$ERR" "cannot be placed" "the placement's line"
  assert_exit 0 "the entry's container list came first" -- test "$(calls_of_verb list)" -ge 1
  assert_eq "0" "$(engine_calls image build run tag rmi)" "no image, build, run, tag or rmi call"
}

# hold_lock <file>: a process that holds <state dir>/<file> (exec'd sleep); sets HOLDER
hold_lock() {
  ( lock_take step "$1" || exit 1; : > "$CASE/held"; exec sleep 30 ) &
  HOLDER=$!
  disown "$HOLDER"
  guard_pid "$HOLDER" "holder-$HOLDER"
  local i
  for i in $(seq 1 100); do [ -e "$CASE/held" ] && return 0; sleep 0.1; done
  return 1
}

# later_build: a build with another stamp
later_build() { R9700_TEST_COMFY_STAMP=20261107T120001Z comfy build; }

# BU7
t_build_takes_the_lock() {
  bu_setup "$FUNCNAME"
  hold_lock lock
  assert_exit 4 "another holder of the lock" -- comfy build
  assert_contains "$ERR" "another run holds" "the lock's line"
  assert_missing "$STUB/calls.log" "no wslc call"
  kill -KILL "$HOLDER"
  gone "$HOLDER"
  assert_exit 0 "the holder is gone: a build" -- comfy build
  assert_exit 0 "after a successful build the lock is free" -- lock_free
  assert_exit 0 "a second build with another stamp takes it" -- later_build
}

# BU8
t_the_grammar_is_checked_before_the_lock() {
  bu_setup "$FUNCNAME"
  local args
  for args in "--frob" "extra"; do
    assert_exit 2 "comfy build $args" -- comfy build $args
    assert_eq "r9700: comfy: build: unknown argument \"$args\"; legal: --no-cache" "$ERR" "[$args] one line with the legal option"
  done
  assert_missing "$R9700_STATE_DIR/lock" "no lock file"
  assert_missing "$STUB/calls.log" "no call"
  assert_eq "2" "$(ls "$REPO/models"/*.env | wc -l | tr -d ' ')" "the repository has two model files: no --model is needed (the machine config alone)"
}

# BU9
t_a_build_is_refused_while_the_operators_comfyui_is_listed_before_the_placement_and_the_build() {
  bu_setup "$FUNCNAME"
  comfy_listed
  assert_exit 2 "comfyui is listed" -- comfy build
  assert_eq "$(comfy_owner_line)" "$ERR" "exactly one stderr line, the owner line"
  assert_contains "$ERR" "bin/r9700 comfy stop" "it names the remedy"
  assert_missing "$PLACED" "no placed copy"
  assert_eq "0" "$(engine_calls image build tag rmi)" "no image, build, tag or rmi call"
  assert_eq "1" "$(calls_of_verb run)" "no run call (the one is the test's own)"
  assert_eq "0" "$(stop_lines)" "no stop"
  assert_exit 0 "comfyui is still listed" -- alive comfyui
  assert_exit 0 "the lock is free afterwards" -- lock_free
  kill_recorded_pids "$CASE"
  bu_setup "$FUNCNAME-whole"
  comfy_listed comfyuix
  assert_exit 0 "a container named comfyuix is listed: a whole name" -- comfy build
  kill_recorded_pids "$CASE"
}

# BU10
t_a_build_is_refused_while_the_operators_vllm_is_listed_naming_it_and_a_standing_marker_restores_first() {
  bu_setup "$FUNCNAME-a"
  prod_running
  assert_exit 2 "vllm is listed" -- comfy build
  assert_eq "$(comfy_server_line)" "$ERR" "exactly one stderr line, the server line"
  assert_missing "$PLACED" "no placement"
  assert_eq "0" "$(engine_calls image build tag rmi)" "no image, build, tag or rmi call"
  assert_eq "1" "$(calls_of_verb run)" "no run call (the one is the test's own)"
  assert_eq "0" "$(stop_lines)" "no stop"
  assert_eq "0" "$(log_count pwsh.exe -Detach)" "no pwsh.exe start"
  assert_exit 0 "vllm is still listed" -- alive vllm
  kill_recorded_pids "$CASE"
  bu_setup "$FUNCNAME-b"
  write_marker
  assert_exit 2 "a standing marker, nothing listed" -- comfy build
  local refusal="$ERR"
  assert_eq "1" "$(log_count pwsh.exe -Detach)" "the restore ran first: one start"
  assert_exit 0 "vllm is listed" -- alive vllm
  assert_missing "$MARKER_FILE" "the marker is gone"
  assert_eq "$(comfy_server_line)" "$refusal" "and then the server line"
  assert_eq "0" "$(engine_calls build image)" "no build: it never starts beside the server the restore just brought back"
  kill_recorded_pids "$CASE"
  bu_setup "$FUNCNAME-c"
  comfy_listed
  prod_running
  assert_exit 2 "both comfyui and vllm are listed" -- comfy build
  assert_eq "$(comfy_owner_line)" "$ERR" "the owner line (ComfyUI's), one line only"
  kill_recorded_pids "$CASE"
}

# BU11
t_a_good_build_is_promoted_only_after_its_check_and_the_image_it_replaces_keeps_its_stamped_tag() {
  bu_setup "$FUNCNAME"
  local new old
  plant 4
  new="sha256:$(printf '%064d' 77)"
  old="$(id_of 4)"
  printf '%s\n' "$new" > "$STUB/answers/build_id"
  assert_exit 0 "four planted stamped tags" -- comfy build
  local built="$OUT"
  assert_exit 0 "the order is build < the check's run < tag" -- call_order ' wslc build ' ' wslc run --rm ' ' wslc tag '
  argv_of_verb tag
  assert_eq "tag|$STAMPED|$CUR" "$(IFS='|'; echo "${ARGV[*]}")" "the tag argv is exactly the stamped tag and COMFY_IMAGE"
  assert_contains "$(images_text)" "$REPO_NAME local $new" "comfyui-r9700:local is on the new id"
  assert_contains "$(images_text)" "$REPO_NAME 20261104T100000Z $old" "comfyui-r9700:20261104T100000Z is still on the id local had before: the replaced image is not left untagged"
  assert_contains "$built" "comfy: build: $CUR now names $STAMPED" "stdout says what COMFY_IMAGE names now"
  bu_setup "$FUNCNAME-first"
  assert_exit 0 "the first build on a PC (no planted record)" -- comfy build
  assert_eq "2" "$(images_text | wc -l | tr -d ' ')" "two records"
  assert_eq "$(awk -v t="$STAMP" '$2 == t { print $3 }' "$STUB/images")" "$(awk '$2 == "local" { print $3 }' "$STUB/images")" "the stamped tag and local are on one id"
  assert_eq "0" "$(calls_of_verb rmi)" "no rmi"
}

# BU12
t_a_fifth_passed_build_removes_exactly_the_oldest_stamped_tag_by_its_exact_name_after_the_promotion() {
  bu_setup "$FUNCNAME"
  local rocm_id
  plant 4
  rocm_id="sha256:$(printf '%064d' 5)"
  printf 'rocm/pytorch rocm10.1.0_ubuntu24.04 %s\n<none> <none> %s\n%s old-build %s\n' "$rocm_id" "$rocm_id" "$REPO_NAME" "$rocm_id" >> "$STUB/images"
  assert_exit 0 "four planted stamped tags and three records that are not ours" -- comfy build
  local built="$OUT"
  assert_eq "1" "$(calls_of_verb rmi)" "exactly one rmi"
  argv_of_verb rmi
  assert_eq "rmi|$REPO_NAME:20261101T100000Z" "$(IFS='|'; echo "${ARGV[*]}")" "its argv is exactly the oldest stamped tag"
  assert_exit 0 "after the tag call" -- call_order ' wslc tag ' ' wslc rmi '
  assert_contains "$built" "comfy: build: removed $REPO_NAME:20261101T100000Z" "stdout says it"
  assert_eq "20261102T100000Z 20261103T100000Z 20261104T100000Z $STAMP" "$(stamp_tags | tr '\n' ' ' | sed 's/ $//')" "afterwards four stamped tags: k = 2..4 and the new one"
  assert_contains "$(images_text)" "rocm/pytorch rocm10.1.0_ubuntu24.04 $rocm_id" "rocm/pytorch is untouched"
  assert_contains "$(images_text)" "<none> <none> $rocm_id" "the untagged record is untouched"
  assert_contains "$(images_text)" "$REPO_NAME old-build $rocm_id" "a tag that is not stamp-shaped is never removed"
  assert_exit 0 "every rmi argv is two words, rmi and one stamped tag" -- rmi_shapes_ok
  bu_setup "$FUNCNAME-five"
  plant 5
  assert_exit 0 "five planted stamped tags (six with the new one: two are beyond the newest four)" -- comfy build
  assert_eq "$REPO_NAME:20261101T100000Z|$REPO_NAME:20261102T100000Z" "$(rmi_words | LC_ALL=C sort | tr '\n' '|' | sed 's/|$//')" "two rmi calls, k = 1 and k = 2, each one exact tag"
  assert_exit 0 "and every rmi argv is two words" -- rmi_shapes_ok
}

# BU13
t_a_stamped_tag_whose_image_is_the_one_comfy_image_names_is_never_removed() {
  bu_setup "$FUNCNAME"
  plant 5
  printf '%s\n' "$(id_of 1)" > "$STUB/answers/build_id"
  assert_exit 0 "five planted stamped tags, the new build has the id of the oldest" -- comfy build
  local built="$OUT"
  assert_contains "$(images_text)" "$REPO_NAME local $(id_of 1)" "local is on that id"
  assert_contains "$(images_text)" "$REPO_NAME 20261101T100000Z $(id_of 1)" "and the oldest tag is still there"
  assert_eq "$REPO_NAME:20261102T100000Z" "$(rmi_words)" "no rmi of it: only the next oldest past the four is removed"
  assert_contains "$built" "comfy: build: kept $REPO_NAME:20261101T100000Z: it is the image $CUR names" "stdout says it was kept"
  bu_setup "$FUNCNAME-reject"
  plant 4
  printf '%s\n' "$(id_of 4)" > "$STUB/answers/build_id"
  printf '%s\n' $'torch 2.13.0\nhip None\ndevice none\nmatmul nan' > "$STUB/answers/comfy_check"
  assert_exit 1 "the rejected build has the id local names" -- comfy build
  assert_eq "0" "$(calls_of_verb rmi)" "no rmi at all"
  assert_contains "$ERR" "$STAMPED is the image $CUR already names; kept" "the line says the rejected tag is the image local already names"
}

# BU14
t_the_retention_runs_only_on_a_view_it_can_trust() {
  bu_setup "$FUNCNAME-failed"
  plant 4
  printf '1 3\n' > "$STUB/fail-image-list"
  assert_exit 0 "the list before the build answers, the three after the promotion fail" -- comfy build
  assert_eq "1" "$(line_count "$ERR")" "one stderr line"
  assert_eq "r9700: comfy: build: warning: the image list failed 3 times (code 1); no old image was removed" "$ERR" "the warning"
  assert_eq "0" "$(calls_of_verb rmi)" "no rmi"
  assert_contains "$(images_text)" "$REPO_NAME local " "the image passed and is promoted"
  bu_setup "$FUNCNAME-lacks"
  plant 5
  # a scripted list (it answers every list call, the one before the build too): five older stamped tags and local, WITHOUT the new stamped tag: with the guard gone the oldest would be removed
  { printf 'REPOSITORY TAG IMAGE ID CREATED SIZE\n'; for k in 1 2 3 4 5; do printf '%s 2026110%sT100000Z %s 6 hours ago 27.3GB\n' "$REPO_NAME" "$k" "$(id_of "$k")"; done; printf '%s local %s 6 hours ago 27.3GB\n' "$REPO_NAME" "$(id_of 5)"; } > "$STUB/answers/image_list"
  assert_exit 0 "a scripted list that lacks the new stamped tag after the promotion" -- comfy build
  assert_eq "r9700: comfy: build: warning: the image list does not show $STAMPED; no old image was removed" "$ERR" "one warning line"
  assert_eq "0" "$(calls_of_verb rmi)" "no rmi"
  bu_setup "$FUNCNAME-nolocal"
  plant 5
  # the new stamped tag is listed with five older ones but the COMFY_IMAGE row is not: the guard that spares COMFY_IMAGE's target would be off, and the just-promoted tag could go
  { printf 'REPOSITORY TAG IMAGE ID CREATED SIZE\n'; for k in 1 2 3 4 5; do printf '%s 2026110%sT100000Z %s 6 hours ago 27.3GB\n' "$REPO_NAME" "$k" "$(id_of "$k")"; done; printf '%s %s %s 6 hours ago 27.3GB\n' "$REPO_NAME" "$STAMP" "sha256:$(printf '%064d' 77)"; } > "$STUB/answers/image_list"
  # the pre-build list of a whole build would already hold the new tag (refused): the retention is called on its own, as the build calls it after the promotion
  assert_exit 0 "a scripted list with the new tag and five older ones but no row for COMFY_IMAGE" -- comfy_images_prune "$REPO_NAME" "$STAMPED"
  assert_eq "r9700: comfy: build: warning: the image list does not show $CUR on $STAMPED; no old image was removed" "$ERR" "one warning line"
  assert_eq "0" "$(calls_of_verb rmi)" "no rmi"
  bu_setup "$FUNCNAME-elsewhere"
  plant 5
  { printf 'REPOSITORY TAG IMAGE ID CREATED SIZE\n'; for k in 1 2 3 4 5; do printf '%s 2026110%sT100000Z %s 6 hours ago 27.3GB\n' "$REPO_NAME" "$k" "$(id_of "$k")"; done; printf '%s %s %s 6 hours ago 27.3GB\n%s local %s 6 hours ago 27.3GB\n' "$REPO_NAME" "$STAMP" "sha256:$(printf '%064d' 77)" "$REPO_NAME" "$(id_of 5)"; } > "$STUB/answers/image_list"
  assert_exit 0 "COMFY_IMAGE is listed on another id than the new stamped tag" -- comfy_images_prune "$REPO_NAME" "$STAMPED"
  assert_eq "r9700: comfy: build: warning: the image list does not show $CUR on $STAMPED; no old image was removed" "$ERR" "the same warning"
  assert_eq "0" "$(calls_of_verb rmi)" "no rmi"
  bu_setup "$FUNCNAME-rmi"
  plant 4
  printf '1\n' > "$STUB/answers/rmi_rc"
  assert_exit 0 "an rmi that fails" -- comfy build
  assert_eq "r9700: comfy: build: warning: $REPO_NAME:20261101T100000Z could not be removed (code 1): stub: rmi failed (scripted)" "$ERR" "one warning line naming the tag and the code"
  bu_setup "$FUNCNAME-rmi-two"
  plant 5
  printf '1\n' > "$STUB/answers/rmi_rc"
  assert_exit 0 "two removals, both failing" -- comfy build
  assert_eq "2" "$(calls_of_verb rmi)" "the other removal is still made (tried)"
  assert_eq "2" "$(grep -c 'could not be removed' <<< "$ERR")" "one warning each"
}

# BU15
t_the_stamp_is_checked_before_anything_is_built() {
  bu_setup "$FUNCNAME-shape"
  step_cfg COMFY_IMAGE=comfyui-r9700:20261101T100000Z
  assert_exit 2 "COMFY_IMAGE has a stamp-shaped tag" -- comfy build
  assert_eq "r9700: comfy: build: COMFY_IMAGE's tag \"20261101T100000Z\" has the shape of a build stamp; give it another tag" "$ERR" "the line"
  assert_missing "$PLACED" "no placement"
  assert_eq "0" "$(engine_calls image build)" "no image or build call"
  bu_setup "$FUNCNAME-knob"
  export R9700_TEST_COMFY_STAMP=bad
  assert_exit 2 "a bad stamp knob" -- comfy build
  assert_contains "$ERR" "R9700_TEST_COMFY_STAMP" "names the knob"
  assert_eq "0" "$(engine_calls build)" "no build call"
  bu_setup "$FUNCNAME-exists"
  plant 2
  printf '%s %s %s\n' "$REPO_NAME" "$STAMP" "$(id_of 8)" >> "$STUB/images"
  assert_exit 1 "the stamped tag is already listed" -- comfy build
  assert_eq "r9700: comfy: build: the tag $STAMPED exists already; nothing was built" "$ERR" "the line"
  assert_eq "0" "$(engine_calls build)" "no build call"
  bu_setup "$FUNCNAME-list"
  printf '3\n' > "$STUB/fail-image-list"
  assert_exit 1 "a pre-build image list that fails 3 times" -- comfy build
  assert_contains "$ERR" "the image list failed 3 times (code 1); nothing was built" "the line names the list"
  assert_eq "0" "$(engine_calls build)" "no build call"
}

# BU16
t_a_promotion_that_fails_leaves_the_passed_image_to_tag_by_hand() {
  bu_setup "$FUNCNAME"
  local planted
  plant 4
  planted="$(images_text)"
  printf '1\n' > "$STUB/answers/tag_rc"
  assert_exit 1 "answers/tag_rc 1" -- comfy build
  assert_eq "r9700: comfy: build: $STAMPED passed its check but $CUR was not moved (code 1): stub: tag failed (scripted); tag it by hand (README, ComfyUI)" "$ERR" "one line"
  assert_eq "0" "$(calls_of_verb rmi)" "no rmi: neither the passed tag nor an old one"
  assert_eq "$planted"$'\n'"$REPO_NAME $STAMP $(awk -v t="$STAMP" '$2 == t { print $3 }' "$STUB/images")" "$(images_text)" "the records are the planted ones plus the passed stamped tag"
}

run_all_tests
