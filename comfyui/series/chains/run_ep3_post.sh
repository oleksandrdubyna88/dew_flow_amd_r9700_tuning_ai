#!/usr/bin/env bash
# Episode 3 post-production (2026-11-10, the owner: "finish everything we discussed"), after the clips and the audio model
# download: the rerolls (s06 blink, s10 walked, s11 one eye closed, s20 eyes closed; s21f from the flame-free keyframe), audio (song / sfx / music, one model per server session), FILM
# 16->32 fps of the kept clips, then the first full edit. A fresh ComfyUI per step (MIOpen on by default), RAM guard.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep3_post.log"
until grep -q "FETCH DONE" "$DIR/fetch-audio-local.log" 2>/dev/null; do sleep 60; done
# guard (2026-11-10 21:25): its own stop file, killed on every exit; only stops from THIS run count; limit 3500 MB (two
# real dips to ~4.3 GB at clip ends tripped 6000 MB; the crisis level was < 150 MB); RAM sampled to post_mem.csv
STOPF="$DIR/.guard_off_post"; START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
( while [ ! -f "$STOPF" ]; do pwsh.exe -NoProfile -Command '$m = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory; "{0},{1},{2}" -f (Get-Date -Format HH:mm:ss), $m.AvailableMBytes, [int]($m.ModifiedPageListBytes/1MB)' 2>/dev/null | tr -d '\r' >> "$DIR/post_mem.csv"; sleep 10; done ) & SAMPLER=$!
trap 'touch "$STOPF"; kill $GUARD $SAMPLER 2>/dev/null' EXIT
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
job() { pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c '$1'" 2>&1 | tr -d '\r' | grep -E "ep3 |rror|out of memory" | head -40 >> "$LOG"; }
guarded() { [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; return 1; }; return 0; }
echo "post start $(date +%H:%M); $(tail -1 "$DIR/fetch-audio-local.log")" >> "$LOG"
grep -q "FETCH DONE exit 0" "$DIR/fetch-audio-local.log" || echo "WARNING: the audio download did not end with exit 0 — audio steps may fail" >> "$LOG"
for a in 6:b 10:b 11:b 20:b 21:f; do k="${a%%:*}"; lab="${a#*:}"; ls "$COMFY_HOME"/output/series/ep3/clips/clip_s$(printf %02d "$k")${lab}_0*.mp4 > /dev/null 2>&1 && continue; restart && job "python /opt/tests/ep3_clips.py $k $lab"; guarded || exit 0; done
guarded || exit 0
for mode in song sfx music; do restart || break; job "python /opt/tests/ep3_audio.py $mode"; guarded || exit 0; done
restart && job "python /opt/tests/ep3_film.py"
guarded || exit 0
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
touch "$STOPF"; wait $GUARD $SAMPLER 2>/dev/null
pwsh.exe -NoProfile -Command "wslc run --rm --name kedit -v '$COMFY_HOME_WIN\output:/data/output' -v '$COMFY_HOME_WIN\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/ep3_edit.py --out v1" 2>&1 | tr -d '\r' | tail -60 >> "$LOG"
echo "POST DONE $(date +%H:%M)" >> "$LOG"
