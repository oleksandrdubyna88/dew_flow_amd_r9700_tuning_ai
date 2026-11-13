#!/usr/bin/env bash
# Dataset blocks for the trainer tomls (2026-11-12, LoRA v5: repeats balance by subfolder, consultant advice).
#   lora_datasets_toml.sh <data dir> <cache dir> musubi|kohya
# If <data dir> has subfolders r<N>_<name> (e.g. r2_gemini, r5_full), one block per subfolder with num_repeats N
# (musubi: its own cache folder <cache dir>/<subfolder>); otherwise one block for the folder with num_repeats 4 (as before).
set -eu
DATA="$1"; CACHE="$2"; KIND="$3"
block() {  # $1 dir, $2 repeats, $3 cache
  if [ "$KIND" = musubi ]; then
    printf '\n[[datasets]]\nimage_directory = "%s"\ncache_directory = "%s"\nnum_repeats = %s\n' "$1" "$3" "$2"
  else
    printf '\n  [[datasets.subsets]]\n  image_dir = "%s"\n  num_repeats = %s\n' "$1" "$2"
  fi
}
subs=$(find "$DATA" -mindepth 1 -maxdepth 1 -type d -name 'r[0-9]*_*' | sort)
if [ -n "$subs" ]; then
  for d in $subs; do b=$(basename "$d"); n=${b#r}; n=${n%%_*}; block "$d" "$n" "$CACHE/$b"; done
else
  block "$DATA" 4 "$CACHE"
fi
