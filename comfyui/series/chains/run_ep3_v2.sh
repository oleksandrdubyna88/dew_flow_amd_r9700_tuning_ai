#!/usr/bin/env bash
# Episode 3 v2 (2026-11-10 ~22:10): FILM for the new choices s11b and s20b, the Act 2 music (mus_act2), then the edit v2
# (choices s06b s11b-cut s20b s21f, song 1 = Whisper CER 0.09, a fuller Act 2). Own guard stop file, killed on exit.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep3_v2.log"; STOPF="$DIR/.guard_off_v2"
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
job() { pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c '$1'" 2>&1 | tr -d '\r' | grep -E "ep3 |rror|out of memory" | head -40 >> "$LOG"; }
guarded() { [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; return 1; }; return 0; }
echo "v2 start $(date +%H:%M)" >> "$LOG"
restart && job "python /opt/tests/ep3_film.py 11 20"; guarded || exit 0
restart && job "python /opt/tests/ep3_audio.py music mus_act2"; guarded || exit 0
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name kedit -v '$COMFY_HOME_WIN\output:/data/output' -v '$COMFY_HOME_WIN\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/ep3_edit.py --out v2" 2>&1 | tr -d '\r' | tail -45 >> "$LOG"
echo "V2 DONE $(date +%H:%M)" >> "$LOG"
