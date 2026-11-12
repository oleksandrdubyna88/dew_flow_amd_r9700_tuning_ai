#!/usr/bin/env bash
# Episode 3 clips (2026-11-10, the owner approved the 23 picks): ep3_clips.py per shot, a fresh ComfyUI per clip
# (the 14B model slows down and OOMs on a reused server), RAM guard, existing clips skipped. Usage: run_ep3_clips.sh <k>...
# Each arg may be "k" or "k:label". Logs to ep3_clips.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep3_clips.log"
"$DIR/guard_ram.sh" 6000 & GUARD=$!
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  if [ -s "$DIR/.start_env" ]; then pwsh.exe -NoProfile -Command "& '$COMFY_HOME_WIN\start-comfyui.ps1' -Detach -Env $(cat "$DIR/.start_env")" > /dev/null 2>&1
  else pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1; fi
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
echo "start $* $(date +%H:%M)" >> "$LOG"
for a in "$@"; do
  k="${a%%:*}"; lab=""; [ "$a" != "$k" ] && lab="${a#*:}"
  kk=$(printf %02d "$k")
  ls "$COMFY_HOME"/output/series/ep3/clips/clip_s${kk}${lab}_0*.mp4 > /dev/null 2>&1 && { echo "s$kk$lab exists" >> "$LOG"; continue; }
  restart || break
  if [ -f "$DIR/.pre_job" ]; then j="$(cat "$DIR/.pre_job")"; rm -f "$DIR/.pre_job"; "$DIR/$j"; restart || break; fi
  pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/ep3_clips.py $k ${lab:--}'" 2>&1 | tr -d '\r' | grep -E "ep3 clip|out of memory|rror" | head -20 >> "$LOG"
  grep -q "GUARD STOP" "$DIR/guard.log" 2>/dev/null && { echo "guard stopped comfyui — ending" >> "$LOG"; break; }
done
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
touch "$DIR/.guard_off"; wait $GUARD 2>/dev/null
echo "CLIPS DONE $* $(date +%H:%M)" >> "$LOG"
