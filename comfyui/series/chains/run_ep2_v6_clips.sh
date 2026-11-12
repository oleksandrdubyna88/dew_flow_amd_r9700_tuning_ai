#!/usr/bin/env bash
# Episode 2 v6 clips (2026-11-11 night, the owner: "redo e2 in the same spirit"): the 9 picks (v6/pick_s1..s9) -> one
# clip each (a fresh server per clip, MIOpen on), FILM x2 of all 9, then ep2_upgrade.py v6 (the approved narrator timing,
# effects + ducked music from audio/ep2). Own guard stop file, killed on exit. Logs to ep2_v6_clips.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep2_v6_clips.log"; STOPF="$DIR/.guard_off_ep2c"
O="$COMFY_HOME"/output/series/ep2/v6; V=/data/output/series/ep2/v6
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
job() { pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c '$1'" 2>&1 | tr -d '\r' | grep -E "ep2 v6|film |rror|out of memory" | head -20 >> "$LOG"; }
guarded() { [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; return 1; }; return 0; }
echo "ep2 v6 clips start $(date +%H:%M)" >> "$LOG"
for k in 1 2 3 4 5 6 7 8 9; do
  ls $O/clip_s${k}_0*.mp4 > /dev/null 2>&1 && continue
  restart && job "python /opt/tests/ep2_v6.py shot $k"; guarded || exit 0
done
F=""; for k in 1 2 3 4 5 6 7 8 9; do F="$F $V/clip_s${k}_00001_.mp4 series/ep2/v6/film/s${k}_32fps"; done
restart && job "python /opt/tests/ep3_film.py file$F"; guarded || exit 0
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
for k in 1 2 3 4 5 6 7 8 9; do echo "file '$V/clip_s${k}_00001_.mp4'"; done > $O/concat.txt
pwsh.exe -NoProfile -Command "wslc run --rm --name kep2v6 -v '$COMFY_HOME_WIN\output:/data/output' -v '$COMFY_HOME_WIN\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/ep2_upgrade.py v6" 2>&1 | tr -d '\r' | grep -E "picture|done|missing|rror|Trace" >> "$LOG"
echo "EP2 V6 DONE $(date +%H:%M)" >> "$LOG"
