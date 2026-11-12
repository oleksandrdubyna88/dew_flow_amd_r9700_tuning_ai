#!/usr/bin/env bash
# Episode 1 v3 (2026-11-10 ~22:40), the agreed order after episode 3: (1) masked repaints of the picks with the episode 3
# rules — s4 pointed ear -> hair, s1 older face -> her young face (two seeds each, for the owner); (2) the clips of the
# unchanged, approved picks s2 s3 s5 s6 (a fresh server per clip; MIOpen on by default). Own guard, killed on exit.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep1_v3.log"; STOPF="$DIR/.guard_off_ep1"
V=/data/output/series/elf_set2_arcane/v3; P=series/elf_set2_arcane/v3
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
job() { pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c '$1'" 2>&1 | tr -d '\r' | grep -E "repaint|ep1 v3|rror|out of memory" | head -20 >> "$LOG"; }
guarded() { [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; return 1; }; return 0; }
echo "ep1 v3 start $(date +%H:%M)" >> "$LOG"
restart && job "python /opt/tests/inpaint_any.py run ear $V/pick_s4.png $P/fix_s4_ear 0.413,0.11,0.432,0.17 && python /opt/tests/inpaint_any.py run face $V/pick_s1.png $P/fix_s1_face 0.406,0.205,0.446,0.292"
guarded || exit 0
echo "FIXES DONE $(date +%H:%M)" >> "$LOG"
for k in 2 3 5 6; do
  ls "$COMFY_HOME"/output/series/elf_set2_arcane/v3/clip_s${k}_0*.mp4 > /dev/null 2>&1 && continue
  restart && job "python /opt/tests/ep1_v3.py shot $k"; guarded || exit 0
done
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
echo "EP1 CLIPS 2356 DONE $(date +%H:%M)" >> "$LOG"
