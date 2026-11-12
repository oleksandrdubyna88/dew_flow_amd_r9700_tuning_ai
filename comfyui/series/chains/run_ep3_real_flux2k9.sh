#!/usr/bin/env bash
# Realistic ep3 with the Flux klein 9B LoRA v3 (the owner 2026-11-13 ~00:20: "sNN_c1 I like, with it you can draw ep3";
# "the small second dragon (s05 c1) is no problem, let it be"). Picks = c1 of every shot. Waits for the queued GPU jobs
# ("^COMFYTRAIN DONE", checked absent before start) and for all 46 flux2k9 keys. Then per shot a fresh server + one Wan
# 2.2 14B clip (rule: restart per clip), FILM 32 fps (one server), the ep3 edit + sound (EP3_DIR, no painted CHOICE
# labels) -> series/ep3_real/flux2k9/ep3_castle_real_v1.mp4. Own RAM guard. Log ep3_real.log ("EP3REAL FLUX2K9 DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/ep3_real.log"; STOPF="$DIR/.guard_off_ep3real"; R="$COMFY_HOME_WIN"
M=flux2k9; O="$COMFY_HOME"/output/series/ep3_real/$M
echo "$M clips waiting $(date +%H:%M)" >> "$LOG"
until grep -q "^COMFYTRAIN DONE" "$DIR/comfytrain.log" 2>/dev/null; do sleep 30; done
until [ "$(ls $O/keys/*.png 2>/dev/null | wc -l)" -ge 46 ]; do sleep 30; done
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
guarded() { [ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; return 1; }; return 0; }
echo "$M clips start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name e3r-picks -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/ep3_real.py picks $M c1" 2>&1 | tr -d '\r' | tail -2 >> "$LOG"
for k in $(seq 1 23); do
  kk=$(printf %02d $k)
  ls $O/clips/clip_s${kk}_0*.mp4 > /dev/null 2>&1 && continue
  restart && pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/ep3_real.py clip $M $k'" 2>&1 | tr -d '\r' | grep -E "ep3real|rror|out of memory|Trace" | head -5 >> "$LOG"
  guarded || exit 0
done
restart && pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'python /opt/tests/ep3_real.py film $M'" 2>&1 | tr -d '\r' | grep -E "film|rror|Trace" | tail -3 >> "$LOG"
guarded || exit 0
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name e3r-edit -e EP3_DIR=/data/output/series/ep3_real/$M -e EP3_NO_CHOICE=1 -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/ep3_edit.py --out real_v1" 2>&1 | tr -d '\r' | tail -4 >> "$LOG"
echo "EP3REAL FLUX2K9 DONE $(date +%H:%M)" >> "$LOG"
