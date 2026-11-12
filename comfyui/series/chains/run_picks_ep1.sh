#!/usr/bin/env bash
# My by-eye picks of the ep1 round-7 keyframes (young/sheet_ep1_r7.png), written only after the ep2 fixes (FIX6 DONE) so
# run_young.sh does not start the ep1 clips on a GPU that is still busy. Logs to young_run.log.
set -u
DIR="$(dirname "$0")"; LOG="$DIR/young_run.log"
until grep -q "FIX6 DONE" "$LOG" 2>/dev/null; do sleep 30; done
for kn in "1 51" "2 51" "3 52" "4 52" "5 52" "6 51"; do
  pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/young_face.py pick ep1 $kn" 2>&1 | tr -d '\r' >> "$LOG"
done
