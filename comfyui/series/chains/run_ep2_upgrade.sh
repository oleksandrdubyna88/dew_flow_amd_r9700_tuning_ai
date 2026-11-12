#!/usr/bin/env bash
# Episode 2 upgrade (the owner, 2026-11-10: FILM + the new sound, no new clips, both versions): Stable Audio 3 effects +
# music (ep3_audio.py ep2), FILM x2 of the 9 approved clips of each version, then ep2_upgrade.py arcane / real.
# One model per server session; own guard stop file, killed on exit. Logs to ep2_upgrade.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep2_upgrade.log"; STOPF="$DIR/.guard_off_ep2"
O="$COMFY_HOME"/output
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
job() { pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c '$1'" 2>&1 | tr -d '\r' | grep -E "ep2 audio|film |rror|out of memory" | head -40 >> "$LOG"; }
guarded() { [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; return 1; }; return 0; }
echo "ep2 upgrade start $(date +%H:%M)" >> "$LOG"
restart && job "python /opt/tests/ep3_audio.py ep2"; guarded || exit 0
F=""
k=0; while read -r c; do k=$((k+1)); F="$F $c /series/ep2/film/a_s${k}_32fps"; done < <(grep -o "'[^']*'" "$O/series/ep2/concat_v4.txt" | tr -d "'")
k=0; while read -r c; do k=$((k+1)); F="$F $c /series/ep2_real/film/r_s${k}_32fps"; done < <(grep -o "'[^']*'" "$O/series/ep2_real/concat.txt" | tr -d "'")
F="${F// \/series/ series}"
restart && job "python /opt/tests/ep3_film.py file$F"; guarded || exit 0
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
for v in arcane real; do
  pwsh.exe -NoProfile -Command "wslc run --rm --name kep2$v -v '$COMFY_HOME_WIN\output:/data/output' -v '$COMFY_HOME_WIN\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/ep2_upgrade.py $v" 2>&1 | tr -d '\r' | grep -E "picture|done|missing|rror" >> "$LOG"
done
echo "EP2 UPGRADE DONE $(date +%H:%M)" >> "$LOG"
