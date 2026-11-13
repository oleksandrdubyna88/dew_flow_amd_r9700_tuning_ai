#!/usr/bin/env bash
# Episode 1 v3 sound + FILM (2026-11-10 ~22:45): Stable Audio 3 effects + music bed (ep3_audio.py ep1), FILM x2 of the
# approved clips s2 s3 s5 s6. One model per server session; own guard stop file, killed on exit.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep1_audio.log"; STOPF="$DIR/.guard_off_ep1a"
V=/data/output/series/elf_set2_arcane/v3; P=series/elf_set2_arcane/v3/film
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
job() { pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c '$1'" 2>&1 | tr -d '\r' | grep -E "ep1 audio|film |rror|out of memory" | head -20 >> "$LOG"; }
guarded() { [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; return 1; }; return 0; }
echo "ep1 audio start $(date +%H:%M)" >> "$LOG"
restart && job "python /opt/tests/ep3_audio.py ep1"; guarded || exit 0
F=""; for k in 2 3 5 6; do F="$F $V/clip_s${k}_00001_.mp4 $P/clip_s${k}_32fps"; done
restart && job "python /opt/tests/ep3_film.py file$F"; guarded || exit 0
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
echo "EP1 AUDIO+FILM DONE $(date +%H:%M)" >> "$LOG"
