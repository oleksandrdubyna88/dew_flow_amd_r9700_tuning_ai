#!/usr/bin/env bash
# Eyes (the owner, 2026-11-09: "the eyes are the main thing, they must be flawless"). The eye test showed the SEED is the
# lever (8 steps made the iris colour flicker). After "V2 DONE": a second seed (eyetest label A = seed + 1000, 4 steps) for
# the other ep1 young shots 1 3 4 5 6 (shot 2 has A already); I then compare each with its original by eye and keep the
# steadier. Then a second robocopy pass the ComfyUI folder -> the NAS. Logs to reroll.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN NAS_BACKUP_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/reroll.log"
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do
    pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0
    sleep 5
  done
  echo "restart: not ready after 300 s" >> "$LOG"; return 1
}
until grep -q "V2 DONE" "$DIR/eyes_run.log" 2>/dev/null; do sleep 60; done
echo "start $(date +%H:%M)" >> "$LOG"
for k in 1 3 4 5 6; do
  for try in 1 2; do
    restart || break
    out="$(pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/young_face.py eyetest $k A" 2>&1 | tr -d '\r')"
    echo "$out" | grep -E "eyetest|out of memory|Error" | head -3 >> "$LOG"
    echo "$out" | grep -q "eyetest A shot $k: clip" && break
  done
done
echo "REROLL DONE $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "robocopy $COMFY_HOME_WIN $NAS_BACKUP_WIN /E /COPY:DAT /DCOPY:T /R:2 /W:5 /MT:4 /NP /NFL /NDL /LOG:$COMFY_HOME_WIN\robocopy_comfyui_2.log; exit 0" > /dev/null 2>&1
echo "COPY2 DONE $(date +%H:%M)" >> "$LOG"
