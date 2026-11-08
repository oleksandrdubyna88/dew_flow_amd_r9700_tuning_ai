#!/usr/bin/env bash
# Download model files and put them where ComfyUI reads them, each accepted ONLY when its own sha256 equals the one pinned in the repository (comfyui/models.conf).
# `bin/r9700 comfy fetch <set>...` runs this script in a one-off container of the ComfyUI image (the folder comfyui/ is placed read-only at /work/r9700/comfyui/):
#   --entrypoint bash <image> /work/r9700/comfyui/fetch_model.sh <folder> <url> <sha256> [<folder> <url> <sha256> ...]
#   /models = the volume ComfyUI reads (COMFY_MODELS_VOLUME)
#   /store  = the master copy of the models, a Windows folder mounted only when COMFY_STORE_WIN is set; without that folder the file goes straight to /models
# Per file, in order: the pre-flight HEAD (the published X-Linked-ETag, a cross-check only), then the store first, then the copy into /models. A file right in a place is not copied
# again; a right file in /models fills a store that lacks it; a partial download (.part) is resumed; a .part that is already whole is moved into place. A copy is made to <name>.part,
# checked, and moved by one rename.
# The PIN is the authority. The published hash is never the acceptance: a source that publishes ANOTHER hash is refused before any download, a source that publishes none is
# accepted when the download's own hash equals the pin, and bytes that do not match the pin are removed (a kept wrong .part would be resumed from its end by the next fetch).
# Exit codes: 0 done; 2 a bad argument (before any request); 3 a source publishes another sha256 than the pin; 4 a download or a copy does not match the pin, or a copy failed;
# 5 the download failed. Two test knobs, read from the environment only (tests/test_comfy_fetch_model.sh): R9700_TEST_FETCH_STORE and R9700_TEST_FETCH_MODELS replace /store and /models.
set -euo pipefail
STORE="${R9700_TEST_FETCH_STORE:-/store}"
MODELS="${R9700_TEST_FETCH_MODELS:-/models}"

ok_hash() { [ -f "$1" ] && [ "$(sha256sum "$1" | cut -d' ' -f1)" = "$2" ]; }

# copy_checked <src> <dest> <sha256>: cp to <dest>.part, check it against the pin, one rename; a failed cp or a mismatch removes the .part and ends the script with 4
copy_checked() {
  if ! cp "$1" "$2.part" 2> /dev/null; then
    rm -f "$2.part"
    echo "fetch: the copy to ${2%/*} failed (the folder is not writable or the disk is full)" >&2
    exit 4
  fi
  ok_hash "$2.part" "$3" || { rm -f "$2.part"; echo "fetch: HASH MISMATCH after the copy to $2 (the copy was removed)" >&2; exit 4; }
  mv "$2.part" "$2"
}

# download <url> <dest> <sha256> <label>: resumes <dest>.part, checks it against the pin, one rename
download() {
  local rc=0
  if ok_hash "$2.part" "$3"; then
    echo "fetch: .part is whole   $4"
  else
    echo "fetch: downloading   $4"
    curl -g -sSfL --connect-timeout 30 -C - -o "$2.part" "$1" || rc=$?
    if [ "$rc" -ne 0 ]; then
      echo "fetch: the download of $4 failed (curl code $rc); the .part stays and the next fetch resumes it" >&2
      exit 5
    fi
    if ! ok_hash "$2.part" "$3"; then
      echo "fetch: HASH MISMATCH $4: the download has sha256 $(sha256sum "$2.part" | cut -d' ' -f1), the pin is $3 (the .part was removed)" >&2
      rm -f "$2.part"
      exit 4
    fi
  fi
  mv "$2.part" "$2"
}

# The ONE rule of a url and of the file name made from it, the same two lines as lib/comfy.sh (_COMFY_URL_RE, _COMFY_FILE_RE; this script runs inside the image and cannot source that file). A url is http or
# https (http only for the local server of the tests; models.conf allows https alone), with no quote, backslash, backtick, bracket, brace or blank; the file name is the last part of the url path before any ?
# or #, made by ${path##*/} (a trailing / gives an empty name), and is letters, digits, . _ - starting with a letter or digit: never `.`, `..` or a leading `-`. Both curl calls also pass -g (no globbing).
URL_RE='^https?://[^][{}"\`[:space:]]+$'
FILE_RE='^[A-Za-z0-9][A-Za-z0-9._-]*$'
url_file_name() { local path="${1%%[?#]*}"; printf '%s\n' "${path##*/}"; }

# all arguments are checked before the first request
if [ "$#" -eq 0 ] || [ $(($# % 3)) -ne 0 ]; then
  echo "fetch: usage: fetch_model.sh <folder> <url> <sha256> [<folder> <url> <sha256> ...]" >&2
  exit 2
fi
args=("$@")
for ((i = 0; i < ${#args[@]}; i += 3)); do
  [[ ${args[i]} =~ ^[a-z_]+$ ]] || { echo "fetch: the folder \"${args[i]}\" is not lower-case letters and _" >&2; exit 2; }
  [[ ${args[i + 1]} =~ $URL_RE ]] || { echo "fetch: the url \"${args[i + 1]}\" is not an http:// or https:// address without a quote, backslash, backtick, bracket, brace or blank" >&2; exit 2; }
  [[ "$(url_file_name "${args[i + 1]}")" =~ $FILE_RE ]] || { echo "fetch: the file name of ${args[i + 1]} (the last part of the url path) is not letters, digits, . _ - starting with a letter or digit" >&2; exit 2; }
  [[ ${args[i + 2]} =~ ^[0-9a-f]{64}$ ]] || { echo "fetch: the sha256 of ${args[i + 1]} is not 64 lower-case hex characters" >&2; exit 2; }
done

for ((i = 0; i < ${#args[@]}; i += 3)); do
  dir="${args[i]}" url="${args[i + 1]}" pin="${args[i + 2]}"
  name="$(url_file_name "$url")"
  label="$dir/$name"
  store="$STORE/$dir/$name" local_copy="$MODELS/$dir/$name"
  # the pre-flight: the LAST x-linked-etag of the redirect chain; a failed HEAD gives none (the pin decides)
  published="$( { curl -g -sIL --connect-timeout 30 --max-time 120 "$url" || true; } | tr -d '\r' | sed -n 's/^x-linked-etag:[[:space:]]*//Ip' | tail -n 1 | tr -d '" ' | tr 'A-Z' 'a-z')"
  if [ -z "$published" ]; then
    echo "fetch: the source publishes no sha256 for $label; the pin decides"
  elif [ "$published" != "$pin" ]; then
    echo "fetch: $label: the source publishes sha256 $published but the pin is $pin; nothing downloaded" >&2
    exit 3
  fi
  mkdir -p "$MODELS/$dir"
  if [ -d "$STORE" ]; then
    mkdir -p "$STORE/$dir"
    if ok_hash "$store" "$pin"; then
      echo "fetch: store ok   $label"
    elif ok_hash "$local_copy" "$pin"; then
      echo "fetch: store <- local copy   $label"
      copy_checked "$local_copy" "$store" "$pin"
    else
      download "$url" "$store" "$pin" "$label (to the store)"
    fi
    if ok_hash "$local_copy" "$pin"; then
      echo "fetch: local ok   $label"
    else
      echo "fetch: local <- store   $label"
      copy_checked "$store" "$local_copy" "$pin"
    fi
  elif ok_hash "$local_copy" "$pin"; then
    echo "fetch: local ok   $label"
  else
    download "$url" "$local_copy" "$pin" "$label (no store: straight to the models folder)"
  fi
  echo "fetch: done $label $(du -h "$local_copy" | cut -f1) sha256 $pin"
done
