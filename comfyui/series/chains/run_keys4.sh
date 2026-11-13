#!/usr/bin/env bash
# Keyframes set 3/4 (2026-11-10, the owner: "the clothes differ everywhere, they must be as on s15"; s11/s19 faces):
# set 3 = new poses + edits (c5/c6) for 11 14 16-21; set 4 = the reviewed set-1 poses re-edited (c7/c8) for 14 17-21.
# guard_ram.sh stops ComfyUI if Windows' available RAM falls below 6 GB; memory sampled to keys4_mem.csv. Logs to keys4.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/keys4.log"
"$DIR/guard_ram.sh" 6000 & GUARD=$!
( while [ ! -f "$DIR/.guard_off" ]; do pwsh.exe -NoProfile -Command '$m = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory; "{0},{1},{2}" -f (Get-Date -Format HH:mm:ss), $m.AvailableMBytes, [int]($m.ModifiedPageListBytes/1MB)' 2>/dev/null | tr -d '\r' >> "$DIR/keys4_mem.csv"; sleep 10; done ) & SAMPLER=$!
restart() {
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  pwsh.exe -NoProfile -File "$COMFY_HOME_WIN\start-comfyui.ps1" -Detach > /dev/null 2>&1
  for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0; sleep 5; done
  echo "restart: not ready" >> "$LOG"; return 1
}
job() { pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c '$1'" 2>&1 | tr -d '\r' | grep -E "ep3 key|ep3 pose|ep1 v3|out of memory|Error" | head -40 >> "$LOG"; }
for phase in text edit; do
  echo "phase $phase $(date +%H:%M)" >> "$LOG"
  restart || break
  job "EP3_PHASE=$phase EP3_SET=3 python /opt/tests/ep3_keys.py 11 14 16 17 18 19 20 21"
  [ "$phase" = edit ] && job "EP3_PHASE=edit EP3_SET=4 EP3_POSE_FROM=1 python /opt/tests/ep3_keys.py 14 17 18 19 20 21"
  grep -q "GUARD STOP" "$DIR/guard.log" 2>/dev/null && { echo "guard stopped comfyui — ending" >> "$LOG"; break; }
done
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
touch "$DIR/.guard_off"; wait $GUARD $SAMPLER 2>/dev/null
awk -F, '{if(!m||$2<m){m=$2;t=$1}; if($3>x)x=$3} END {print "memory: min available " m " MB at " t ", max modified " x " MB"}' "$DIR/keys4_mem.csv" >> "$LOG"
echo "KEYS4 DONE $(date +%H:%M)" >> "$LOG"
