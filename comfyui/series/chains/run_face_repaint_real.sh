#!/usr/bin/env bash
# The realistic LoRAs v2, step B (the owner 2026-11-11: "B, go ahead"): masked face repaint of the set-c pictures with the
# chosen face (face_repaint_real.py run [names...]), then the compare sheets. Own RAM guard. Logs to face_repaint.log;
# "FACE DONE" only when every requested picture has r1 and r2 in real2c_face/full. Args: picture names (none = all).
# 15:25 (the owner chose InstantID, face weight 1.2): FACE_ENV="FACE_METHOD=iid FACE_DENOISE=0.6 FACE_CN=0.5 FACE_IPW=1.2"
# and VAR=_w12 are passed into the container; the sheets become cmp_w12_*.jpg.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/face_repaint.log"; STOPF="$DIR/.guard_off_frr"
FACE_ENV="${FACE_ENV:-}"; VAR="${VAR:-}"
R="$COMFY_HOME_WIN"; F="$COMFY_HOME"/output/lora/real2c_face/full
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
up=0
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && { up=1; break; }; sleep 5; done
[ "$up" = 1 ] || { echo "FACE FAILED $(date +%H:%M): comfyui did not answer" >> "$LOG"; exit 1; }
echo "face repaint start $(date +%H:%M) (${*:-all}) $FACE_ENV FACE_VAR=$VAR" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c '$FACE_ENV FACE_VAR=$VAR python /opt/tests/face_repaint_real.py run $*'" 2>&1 | tr -d '\r' | grep -E "realface|rror|Trace|failed" >> "$LOG"
sleep 15  # the guard stops comfyui first and writes GUARD STOP after (14:00 run: the check came too early)
[ "$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null)" -gt "$START_STOPS" ] && { echo "guard stopped comfyui — ending" >> "$LOG"; exit 0; }
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name fsheet -e FACE_VAR=$VAR -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/face_repaint_real.py sheet" 2>&1 | tr -d '\r' | grep -E "compare|rror" >> "$LOG"
if [ "$#" -gt 0 ]; then want="$*"; else want=$(grep -oE '"(fur|tunic)_[a-z]+_l7_s[0-9]+":' "$COMFY_HOME"/tests/face_repaint_real.py | tr -d '":' | tr '\n' ' '); fi
miss=0; for n in $want; do for r in 1 2; do [ -f "$F/${n}_r$r$VAR.png" ] || miss=$((miss + 1)); done; done
if [ "$miss" = 0 ]; then echo "FACE DONE $(date +%H:%M)" >> "$LOG"; else echo "FACE INCOMPLETE $(date +%H:%M) ($miss missing)" >> "$LOG"; fi
