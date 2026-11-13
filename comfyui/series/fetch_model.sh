#!/usr/bin/env bash
# Download Hugging Face files to the model store on the NAS first, then copy them into the local volume ComfyUI reads.
#   /store  = the master copy of the models, a Windows folder (COMFY_STORE_WIN in machine.env; the owner's choice 2026-11-07)
#   /models = volume comfy-models (local copy; loading 20 GB over the network at every start would be slow)
# Every copy is checked against the sha256 Hugging Face publishes (X-Linked-ETag). A file already correct in a place is
# not copied again; a partial download (.part) is resumed. Run it in a one-off container (ComfyUI may keep running):
#   wslc run --rm -v <COMFY_STORE_WIN>:/store -v comfy-models:/models -v <COMFY_HOME_WIN>\tests:/opt/tests:ro `
#     --entrypoint bash comfyui-r9700:local /opt/tests/fetch_model.sh <dir> <url> [<dir> <url> ...]
set -euo pipefail
[ -d /store ] || { echo "fetch: /store is not mounted (COMFY_STORE_WIN)" >&2; exit 2; }

ok_hash() { [ -f "$1" ] && [ "$(sha256sum "$1" | cut -d' ' -f1)" = "$2" ]; }

copy_checked() {  # copy_checked <src> <dest> <sha256>
  cp "$1" "$2.part"
  ok_hash "$2.part" "$3" || { echo "fetch: HASH MISMATCH after copy to $2 (kept as $2.part)" >&2; exit 4; }
  mv "$2.part" "$2"
}

while [ $# -ge 2 ]; do
  dir="$1"; url="$2"; shift 2
  name="$(basename "${url%%\?*}")"
  store="/store/$dir/$name"; local="/models/$dir/$name"
  mkdir -p "/store/$dir" "/models/$dir"
  want="$(curl -sIL "$url" | tr -d '\r' | sed -n 's/^x-linked-etag: *"\{0,1\}\([0-9a-f]\{64\}\)"\{0,1\}$/\1/Ip' | tail -1)"
  [ -n "$want" ] || { echo "fetch: no sha256 published for $url" >&2; exit 3; }

  if ok_hash "$store" "$want"; then
    echo "fetch: store ok   $dir/$name"
  elif ok_hash "$local" "$want"; then
    echo "fetch: store <- local copy   $dir/$name"
    copy_checked "$local" "$store" "$want"
  else
    echo "fetch: downloading to store   $dir/$name"
    curl -sSfL -C - -o "$store.part" "$url"
    ok_hash "$store.part" "$want" || { echo "fetch: HASH MISMATCH $dir/$name (kept as $store.part)" >&2; exit 4; }
    mv "$store.part" "$store"
  fi

  if ok_hash "$local" "$want"; then
    echo "fetch: local ok   $dir/$name"
  else
    echo "fetch: local <- store   $dir/$name"
    copy_checked "$store" "$local" "$want"
  fi
  echo "fetch: done $dir/$name $(du -h "$local" | cut -f1) sha256 $want"
done
