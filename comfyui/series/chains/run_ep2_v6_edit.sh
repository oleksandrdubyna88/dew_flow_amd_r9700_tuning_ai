#!/usr/bin/env bash
# Episode 2 v6 edit (2026-11-11): the step that failed at 01:24 in run_ep2_v6_clips.sh. The concat list is written
# INSIDE the container (the output folder is root-owned for the host), and the whole output incl. errors is logged.
# DONE is written only when the final file exists.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep2_v6_clips.log"
O="$COMFY_HOME"/output/series/ep2/v6; FINAL="$COMFY_HOME"/output/series/ep2/ep2_v6.mp4
echo "ep2 v6 edit start $(date +%H:%M)" >> "$LOG"
CMD='for k in 1 2 3 4 5 6 7 8 9; do echo "file '"'"'/data/output/series/ep2/v6/clip_s${k}_00001_.mp4'"'"'"; done > /data/output/series/ep2/v6/concat.txt && python3 /opt/tests/ep2_upgrade.py v6'
printf "%s\n" "$CMD" > "$COMFY_HOME"/tests/ep2v6_edit_cmd.sh
pwsh.exe -NoProfile -Command "wslc run --rm --name kep2v6 -v '$COMFY_HOME_WIN\output:/data/output' -v '$COMFY_HOME_WIN\tests:/opt/tests:ro' --entrypoint sh comfyui-r9700:local /opt/tests/ep2v6_edit_cmd.sh" 2>&1 | tr -d '\r' >> "$LOG"
if [ -s "$O/concat.txt" ] && [ -s "$FINAL" ] && [ "$FINAL" -nt "$O/concat.txt" ]; then
  echo "EP2 V6 EDIT DONE $(date +%H:%M)" >> "$LOG"
else
  echo "EP2 V6 EDIT FAILED $(date +%H:%M)" >> "$LOG"
fi
