#!/usr/bin/env bash
# Probe a clip and extract frames for a look: bash /opt/tests/peek_clip.sh <clip.mp4> <frame>...
set -euo pipefail
clip="$1"; shift
ffprobe -v error -count_frames -select_streams v:0 \
  -show_entries stream=nb_read_frames,width,height,r_frame_rate,pix_fmt -of csv=p=0 "$clip"
for n in "$@"; do
  out="${clip%.mp4}_peek_f${n}.png"
  ffmpeg -y -loglevel error -i "$clip" -vf "select=eq(n\\,${n})" -vframes 1 "$out"
  echo "$out"
done
