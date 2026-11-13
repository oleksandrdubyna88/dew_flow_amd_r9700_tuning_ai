#!/usr/bin/env bash
# The other 20 ep3 clips, chained after the 3 test clips (the owner, 2026-11-10: "finish everything we discussed").
# Stop file: touch .clips_stop (checked between clips by splitting the list).
set -u
DIR="$(dirname "$0")"
until grep -q "CLIPS DONE 6 17 16" "$DIR/ep3_clips.log" 2>/dev/null; do sleep 30; done
for k in 1 2 3 4 5 7 8 9 10 11 12 13 14 15 18 19 20 21 22 23; do
  [ -f "$DIR/.clips_stop" ] && { echo "stop file — ending before s$k $(date +%H:%M)" >> "$DIR/ep3_clips.log"; break; }
  "$DIR/run_ep3_clips.sh" "$k"
done
echo "REST DONE $(date +%H:%M)" >> "$DIR/ep3_clips.log"
