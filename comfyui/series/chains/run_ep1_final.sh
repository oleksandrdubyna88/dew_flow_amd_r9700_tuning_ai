#!/usr/bin/env bash
# Episode 1 v3 final (the owner, 2026-11-10 ~23:45: "redo e1 and e2 in the same spirit"; s1/s4 = the masked repaints):
# clips s1, s4 and the agreed shift-8 test on s4, FILM of the three, then ep1_edit.py (s4 = shift 5 until the eye check).
# A fresh server per clip (MIOpen on by default), own guard stop file, killed on exit. Logs to ep1_final.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep1_final.log"; STOPF="$DIR/.guard_off_ep1f"
V=/data/output/series/elf_set2_arcane/v3; P=series/elf_set2_arcane/v3/film; O="$COMFY_HOME"/output/series/elf_set2_arcane/v3
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
job() { pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c '$1'" 2>&1 | tr -d '\r' | grep -E "ep1 v3|film |rror|out of memory" | head -20 >> "$LOG"; }
guarded() { [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; return 1; }; return 0; }
echo "ep1 final start $(date +%H:%M)" >> "$LOG"
ls $O/clip_s1_0*.mp4 > /dev/null 2>&1 || { restart && job "python /opt/tests/ep1_v3.py shot 1"; guarded || exit 0; }
ls $O/clip_s4_0*.mp4 > /dev/null 2>&1 || { restart && job "python /opt/tests/ep1_v3.py shot 4"; guarded || exit 0; }
ls $O/clip_s4_shift8_0*.mp4 > /dev/null 2>&1 || { restart && job "python /opt/tests/ep1_v3.py shot 4 8"; guarded || exit 0; }
restart && job "python /opt/tests/ep3_film.py file $V/clip_s1_00001_.mp4 $P/clip_s1_32fps $V/clip_s4_00001_.mp4 $P/clip_s4_32fps $V/clip_s4_shift8_00001_.mp4 $P/clip_s4_shift8_32fps"; guarded || exit 0
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name kep1 -v '$COMFY_HOME_WIN\output:/data/output' -v '$COMFY_HOME_WIN\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/ep1_edit.py --out v1" 2>&1 | tr -d '\r' | grep -E "picture|done|missing|rror|Trace" >> "$LOG"
echo "EP1 FINAL DONE $(date +%H:%M)" >> "$LOG"
