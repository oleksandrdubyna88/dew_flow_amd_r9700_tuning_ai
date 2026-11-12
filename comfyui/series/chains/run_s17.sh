#!/usr/bin/env bash
# s17 again (2026-11-10, the owner: the automaton holds a sword and a shield; a drone above records): set 5 = a new pose
# from the new text + the edit (c9/c10), and touchup.py 17:robot on the current pick (t3/t4). Two phases, RAM guard.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/s17.log"
"$DIR/guard_ram.sh" 6000 & GUARD=$!
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
job() { pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c '$1'" 2>&1 | tr -d '\r' | grep -E "ep3 key|ep3 pose|ep3 touch|out of memory|Error" | head -40 >> "$LOG"; }
for phase in text edit; do
  echo "phase $phase $(date +%H:%M)" >> "$LOG"
  restart || break
  job "EP3_PHASE=$phase EP3_SET=5 python /opt/tests/ep3_keys.py 17"
  [ "$phase" = edit ] && job "python /opt/tests/touchup.py 17:robot"
  grep -q "GUARD STOP" "$DIR/guard.log" 2>/dev/null && { echo "guard stopped comfyui — ending" >> "$LOG"; break; }
done
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
touch "$DIR/.guard_off"; wait $GUARD 2>/dev/null
echo "S17 DONE $(date +%H:%M)" >> "$LOG"
