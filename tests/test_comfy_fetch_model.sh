#!/usr/bin/env bash
# comfyui/fetch_model.sh against a local file server (E1.S3, scenarios FM1-FM12): a file is kept only when its own sha256 equals the pin; the published header is a pre-flight
# cross-check; the store comes first; a partial download resumes; arguments are checked before any request. The script runs on the host with the test knobs R9700_TEST_FETCH_STORE and
# R9700_TEST_FETCH_MODELS below $R9700_TEST_ROOT, and the proxy variables unset. Every test body is a function t_<guarantee>; each runs in its own subshell and writes only below
# $R9700_TEST_ROOT. The server (tests/fixtures/comfy/file_server.py) is recorded like a stub container, so the runner kills it when the test dies.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
# shellcheck source=tests/lib/assert.sh
source "$HERE/lib/assert.sh"
# shellcheck source=tests/lib/stubcase.sh
source "$HERE/lib/stubcase.sh"

FETCH="$REPO/comfyui/fetch_model.sh"
SERVER="$HERE/fixtures/comfy/file_server.py"

# fm_setup <name>: the case folder, the served folder, the store and the models folder, and the server (URL in $URL, its log in $SLOG)
fm_setup() {
  setup_case "$1"
  assert_eq "0" "$(pgrep -fc "file_server.py $R9700_TEST_ROOT/" || true)" "no file server of an earlier test of this run is still alive"
  WWW="$CASE/www" STORE_DIR="$CASE/store" MODELS_DIR="$CASE/models" SLOG="$CASE/server.log"
  mkdir -p "$WWW" "$STORE_DIR" "$MODELS_DIR" "$CASE/containers"
  : > "$SLOG"
  python3 -I "$SERVER" "$WWW" "$SLOG" "$CASE/port" > /dev/null 2>&1 &
  local pid=$! i
  record_pid "$CASE/containers/fileserver-$pid.pid" "$pid" # the runner's kill list: the server dies with the test, if this one's own end does not stop it first
  SRV_PID="$pid"
  trap 'kill "$SRV_PID" 2> /dev/null; wait "$SRV_PID" 2> /dev/null' EXIT # this test's subshell: its server is stopped when the test ends, not at the end of the file
  for i in $(seq 1 100); do [ -s "$CASE/port" ] && break; sleep 0.1; done
  URL="http://127.0.0.1:$(cat "$CASE/port")"
}

# fm_file <name> <content>: writes the served file; sets HASH to its sha256 (computed from the bytes, never typed)
fm_file() {
  printf '%s' "$2" > "$WWW/$1"
  HASH="$(sha256sum "$WWW/$1" | cut -d' ' -f1)"
}

# fm_run <store dir> <argument>...: the script with the knobs and without a proxy
fm_run() {
  local store="$1"
  shift
  env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY -u no_proxy R9700_TEST_FETCH_STORE="$store" R9700_TEST_FETCH_MODELS="$MODELS_DIR" bash "$FETCH" "$@"
}

# gets: the GET lines of the server log (a GET of the redirect and of the file are two lines)
gets() { grep -c '^GET ' "$SLOG" || true; }

# files_below <dir>: every regular file below the dir, one per line
files_below() { find "$1" -type f 2> /dev/null | LC_ALL=C sort; }

# FM1
t_a_file_the_source_publishes_with_the_pinned_sha256_goes_to_the_store_then_to_the_models_folder() {
  fm_setup "$FUNCNAME"
  fm_file x.bin "bytes of the first file"
  printf '%s' "$HASH" > "$WWW/x.bin.etag"
  assert_exit 0 "the request through /r/" -- fm_run "$STORE_DIR" vae "$URL/r/x.bin" "$HASH"
  assert_eq "bytes of the first file" "$(cat "$STORE_DIR/vae/x.bin")" "the store holds the bytes"
  assert_eq "bytes of the first file" "$(cat "$MODELS_DIR/vae/x.bin")" "the models folder holds the bytes"
  assert_eq "" "$(find "$CASE/store" "$CASE/models" -name '*.part')" "no .part is left"
  local last
  last="$(tail -n 1 <<< "$OUT")"
  if [[ $last =~ ^fetch:\ done\ vae/x.bin\ [0-9.]+[KMG]?\ sha256\ $HASH$ ]]; then assert_eq ok ok "the last line is fetch: done <file> <size> sha256 <hash>"; else assert_eq "fetch: done vae/x.bin <size> sha256 $HASH" "$last" "the last line"; fi
  assert_contains "$(cat "$SLOG")" "HEAD /r/x.bin -" "the pre-flight HEAD went to the redirect"
  assert_contains "$(cat "$SLOG")" "GET /r/x.bin -" "and the download too"
}

# FM2
t_a_source_that_publishes_no_sha256_is_accepted_when_the_bytes_match_the_pin() {
  fm_setup "$FUNCNAME"
  fm_file x.bin "bytes with no published hash"
  assert_exit 0 "no .etag file" -- fm_run "$STORE_DIR" vae "$URL/x.bin" "$HASH"
  assert_eq "1" "$(grep -c 'publishes no sha256' <<< "$OUT")" "one line says the source publishes none"
  assert_contains "$OUT" "the pin decides" "and that the pin decides"
  assert_eq "bytes with no published hash" "$(cat "$MODELS_DIR/vae/x.bin")" "the file is kept: the download's own sha256 equals the pin"
}

# FM3
t_a_source_that_publishes_another_sha256_is_refused_before_anything_is_downloaded() {
  fm_setup "$FUNCNAME"
  local other
  fm_file x.bin "bytes of a file that changed"
  other="$(printf 'f%.0s' $(seq 1 64))"
  printf '%s' "$other" > "$WWW/x.bin.etag"
  assert_exit 3 "an .etag that holds another hash" -- fm_run "$STORE_DIR" vae "$URL/x.bin" "$HASH"
  assert_eq "1" "$(grep -c 'vae/x.bin' <<< "$ERR")" "one line names vae/x.bin"
  assert_contains "$ERR" "$other" "the published hash"
  assert_contains "$ERR" "$HASH" "and the pin"
  assert_contains "$ERR" "nothing downloaded" "and says nothing was downloaded"
  assert_eq "" "$(grep -v '^HEAD ' "$SLOG")" "the server log holds only HEAD requests"
  assert_exit 0 "and some of them" -- grep -q '^HEAD ' "$SLOG"
  assert_eq "" "$(files_below "$STORE_DIR")$(files_below "$MODELS_DIR")" "no file and no .part in the store or the models folder"
}

# FM4
t_bytes_that_do_not_match_the_pin_are_not_kept() {
  fm_setup "$FUNCNAME"
  local pin
  fm_file x.bin "the pinned bytes"
  pin="$HASH"
  fm_file x.bin "other bytes than the pin"
  assert_exit 4 "the server serves other bytes and no .etag" -- fm_run "$STORE_DIR" vae "$URL/x.bin" "$pin"
  assert_eq "1" "$(grep -c 'vae/x.bin' <<< "$ERR")" "one line names the file"
  assert_contains "$ERR" "$pin" "the pin"
  assert_contains "$ERR" "$HASH" "and the hash the bytes have"
  assert_eq "" "$(files_below "$STORE_DIR")" "the .part is removed: a kept wrong .part would be resumed from its end at the next fetch"
  assert_eq "" "$(files_below "$MODELS_DIR")" "and the models folder has no file"
}

# FM5
t_a_partial_download_is_resumed() {
  fm_setup "$FUNCNAME"
  local size half
  fm_file x.bin "0123456789abcdef0123456789abcdef"
  size="$(wc -c < "$WWW/x.bin")"
  half=$((size / 2))
  mkdir -p "$STORE_DIR/vae"
  head -c "$half" "$WWW/x.bin" > "$STORE_DIR/vae/x.bin.part"
  assert_exit 0 "a .part with the first half" -- fm_run "$STORE_DIR" vae "$URL/x.bin" "$HASH"
  assert_eq "1" "$(gets)" "one GET"
  assert_contains "$(grep '^GET ' "$SLOG")" "bytes=$half-" "with the range from the half"
  assert_eq "$(cat "$WWW/x.bin")" "$(cat "$MODELS_DIR/vae/x.bin")" "the file matches"
}

# FM6
t_a_part_that_is_already_whole_is_moved_into_place_without_a_request() {
  fm_setup "$FUNCNAME"
  fm_file x.bin "the whole bytes"
  mkdir -p "$STORE_DIR/vae"
  cp "$WWW/x.bin" "$STORE_DIR/vae/x.bin.part"
  assert_exit 0 "a whole .part" -- fm_run "$STORE_DIR" vae "$URL/x.bin" "$HASH"
  assert_eq "0" "$(gets)" "no GET in the server log"
  assert_exit 0 "the store has the file" -- test -f "$STORE_DIR/vae/x.bin"
  assert_missing "$STORE_DIR/vae/x.bin.part" "and no .part"
  assert_exit 0 "the models folder has it too" -- test -f "$MODELS_DIR/vae/x.bin"
}

# FM7
t_a_file_already_right_in_the_store_is_not_downloaded_again() {
  fm_setup "$FUNCNAME"
  fm_file x.bin "a file in the store"
  mkdir -p "$STORE_DIR/vae" "$MODELS_DIR/vae"
  cp "$WWW/x.bin" "$STORE_DIR/vae/x.bin"
  assert_exit 0 "the models folder lacks the file" -- fm_run "$STORE_DIR" vae "$URL/x.bin" "$HASH"
  assert_eq "0" "$(gets)" "no GET"
  assert_eq "a file in the store" "$(cat "$MODELS_DIR/vae/x.bin")" "the models folder got a checked copy"
  assert_contains "$OUT" "fetch: store ok" "the store is said to be right"
  assert_contains "$OUT" "local <- store" "and the copy is said"
  : > "$CASE/stamp"
  assert_exit 0 "both right" -- fm_run "$STORE_DIR" vae "$URL/x.bin" "$HASH"
  assert_contains "$OUT" "fetch: local ok" "the models folder is right: nothing is copied"
  assert_not_contains "$OUT" "local <- store" "no copy"
  assert_eq "0" "$(gets)" "still no GET"
}

# FM8
t_a_right_file_in_the_models_folder_fills_a_store_that_lacks_it_without_a_download() {
  fm_setup "$FUNCNAME"
  fm_file x.bin "a file already in the models folder"
  mkdir -p "$MODELS_DIR/vae"
  cp "$WWW/x.bin" "$MODELS_DIR/vae/x.bin"
  assert_exit 0 "the store lacks the file" -- fm_run "$STORE_DIR" vae "$URL/x.bin" "$HASH"
  assert_eq "0" "$(gets)" "no GET"
  assert_eq "a file already in the models folder" "$(cat "$STORE_DIR/vae/x.bin")" "the store was filled from the right local copy"
  assert_contains "$OUT" "store <- local copy" "and says so"
}

# FM9
t_without_a_store_the_file_goes_straight_to_the_models_folder() {
  fm_setup "$FUNCNAME"
  local size half
  fm_file x.bin "0123456789abcdef0123456789abcdef"
  assert_exit 0 "a store folder that does not exist" -- fm_run "$CASE/nostore" vae "$URL/x.bin" "$HASH"
  assert_missing "$CASE/nostore" "no folder of that name is made"
  assert_eq "$(cat "$WWW/x.bin")" "$(cat "$MODELS_DIR/vae/x.bin")" "the file is in the models folder"
  assert_eq "" "$(find "$MODELS_DIR" -name '*.part')" "no .part is left"
  # the download wrote its .part IN the models folder (and moved it by one rename, not a copy): a half .part there is the one that resumes
  rm "$MODELS_DIR/vae/x.bin"
  size="$(wc -c < "$WWW/x.bin")"
  half=$((size / 2))
  head -c "$half" "$WWW/x.bin" > "$MODELS_DIR/vae/x.bin.part"
  : > "$SLOG"
  assert_exit 0 "a half .part in the models folder" -- fm_run "$CASE/nostore" vae "$URL/x.bin" "$HASH"
  assert_contains "$(grep '^GET ' "$SLOG")" "bytes=$half-" "is resumed from its end"
  assert_eq "$(cat "$WWW/x.bin")" "$(cat "$MODELS_DIR/vae/x.bin")" "and the file matches"
}

# FM10
t_bad_arguments_are_refused_before_any_request() {
  fm_setup "$FUNCNAME"
  fm_file x.bin "bytes"
  local good_url="$URL/x.bin" upper short n=0
  upper="$(printf 'A%.0s' $(seq 1 64))"
  short="${HASH:0:63}"
  local -a cases=("vae $good_url" "vae $good_url $short" "vae $good_url $upper" "../x $good_url $HASH" "a/b $good_url $HASH" "vae ftp://h/x.bin $HASH" "vae x.bin $HASH" "vae $good_url $HASH vae $good_url")
  local c
  for c in "${cases[@]}"; do
    n=$((n + 1))
    # the words are split on purpose: the case is an argument list
    # shellcheck disable=SC2086
    assert_exit 2 "[$n] $c" -- fm_run "$STORE_DIR" $c
    assert_eq "1" "$(grep -c . <<< "$ERR")" "[$n] one line"
  done
  assert_exit 2 "no argument at all" -- fm_run "$STORE_DIR"
  local hostile
  for hostile in "$URL/.." "$URL/dir/" "$URL/-x.bin" "$URL/a[1].bin" "$URL/a{1,2}.bin" "$URL/a\"b.bin" "$URL/a?x=[1]"; do
    assert_exit 2 "a hostile file name or url [$hostile]" -- fm_run "$STORE_DIR" vae "$hostile" "$HASH"
    assert_eq "1" "$(grep -c . <<< "$ERR")" "[$hostile] one line"
  done
  assert_eq "$(sed -n 's/^_COMFY_FILE_RE=//p' "$REPO/lib/comfy.sh")" "$(sed -n 's/^FILE_RE=//p' "$FETCH")" "the file-name rule is the same line in lib/comfy.sh and in the script"
  assert_eq "$(sed -n 's/^_COMFY_URL_RE=.https:\/\///p' "$REPO/lib/comfy.sh")" "$(sed -n 's/^URL_RE=.https?:\/\///p' "$FETCH")" "the url rule differs only in http (the local test server)"
  assert_contains "$(sed -n 's/^FILE_RE=//p' "$FETCH")" "A-Za-z0-9" "the scan is alive: the rule was read"
  assert_eq "2" "$(grep -vE '^[[:space:]]*#' "$FETCH" | grep -c 'curl -')" "the scan is alive: the script has two curl calls"
  assert_eq "0" "$(grep -vE '^[[:space:]]*#' "$FETCH" | grep 'curl -' | grep -vc 'curl -g ')" "and both switch globbing off first (curl -g), so a [ or { in a url is never expanded"
  assert_eq "" "$(cat "$SLOG")" "the server log is empty: no request was made"
  assert_eq "" "$(files_below "$STORE_DIR")$(files_below "$MODELS_DIR")" "and nothing was written"
}

# FM11
t_a_copy_that_fails_is_not_kept() {
  fm_setup "$FUNCNAME"
  fm_file x.bin "a file whose copy fails"
  mkdir -p "$STORE_DIR/vae" "$MODELS_DIR/vae"
  cp "$WWW/x.bin" "$STORE_DIR/vae/x.bin"
  chmod 555 "$MODELS_DIR/vae"
  if [ -w "$MODELS_DIR/vae" ]; then
    chmod 755 "$MODELS_DIR/vae"
    assert_eq ok ok "SKIPPED: this user can write into a folder with mode 555 (root in a container); the scenario needs a read-only folder"
    return 0
  fi
  assert_exit 4 "the copy target's folder is read-only" -- fm_run "$STORE_DIR" vae "$URL/x.bin" "$HASH"
  chmod 755 "$MODELS_DIR/vae"
  assert_eq "1" "$(grep -c . <<< "$ERR")" "one line"
  assert_contains "$ERR" "$MODELS_DIR/vae" "it names the folder"
  assert_eq "" "$(files_below "$MODELS_DIR")" "no .part (and no file) is left in the models folder"
}

# FM12
t_two_files_in_one_call_the_seconds_refusal_leaves_the_first_done() {
  fm_setup "$FUNCNAME"
  local first second other
  fm_file a.bin "the first file"
  first="$HASH"
  printf '%s' "$first" > "$WWW/a.bin.etag"
  fm_file b.bin "the second file"
  second="$HASH"
  other="$(printf 'e%.0s' $(seq 1 64))"
  printf '%s' "$other" > "$WWW/b.bin.etag"
  assert_exit 3 "the second file's source publishes another hash" -- fm_run "$STORE_DIR" vae "$URL/a.bin" "$first" text_encoders "$URL/b.bin" "$second"
  assert_exit 0 "the first is in the store" -- test -f "$STORE_DIR/vae/a.bin"
  assert_exit 0 "and in the models folder" -- test -f "$MODELS_DIR/vae/a.bin"
  assert_eq "" "$(files_below "$STORE_DIR" | grep b.bin)$(files_below "$MODELS_DIR" | grep b.bin)" "the second is nowhere"
}

run_all_tests
