#!/usr/bin/env bash
# Memory-flag A/B (owner 2026-11-09: "do not offload from GPU to RAM, read from disk each time; 3 s of disk read is better
# than the whole PC freezing for a minute"). The same 14B clip (episode 2, shot 1) on a freshly restarted server, first with
# the default flags, then with --fast-disk --disable-pinned-memory. Every 5 s: Windows free RAM (MB) and the WSL VM's
# MemAvailable (MB); the sampling goes on 180 s after the job (the freezes came ~1-2 min after a job). Logs to memab.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/memab.log"; SHOT="${SHOT:-1}"
restart() {  # $1 = extra ComfyUI args for start-comfyui.ps1 (a PowerShell list) or empty
  pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
  local extra=""; [ -n "$1" ] && extra="-ExtraArgs $1"
  pwsh.exe -NoProfile -Command "& '$COMFY_HOME_WIN\start-comfyui.ps1' -Detach $extra" > /dev/null 2>&1
  for i in $(seq 1 60); do
    pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && return 0
    sleep 5
  done
  echo "restart: not ready after 300 s" >> "$LOG"; return 1
}
sample() {  # one CSV line: seconds, Windows free MB, VM MemAvailable MB
  local win vm
  win="$(pwsh.exe -NoProfile -Command "[int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1024)" 2>/dev/null | tr -d '\r')"
  vm="$(pwsh.exe -NoProfile -Command "wslc exec comfyui awk '/MemAvailable/ {print int(\$2/1024)}' /proc/meminfo" 2>/dev/null | tr -d '\r')"
  echo "$(( $(date +%s) - T0 )),$win,$vm"
}
for arm in base fastdisk; do
  extra=""; [ "$arm" = fastdisk ] && extra="'--fast-disk','--disable-pinned-memory'"
  restart "$extra" || exit 1
  CSV="$DIR/memab_$arm.csv"; echo "t_s,win_free_mb,vm_avail_mb" > "$CSV"; T0=$(date +%s)
  ( while [ ! -f "$DIR/.memab_stop" ]; do sample >> "$CSV"; sleep 5; done ) &
  SP=$!
  out="$(pwsh.exe -NoProfile -Command "wslc exec comfyui python /opt/tests/ep2_edit.py ab $SHOT $arm" 2>&1 | tr -d '\r')"
  echo "$arm: $(echo "$out" | grep -E "^shot|out of memory|Error" | head -3)" >> "$LOG"
  echo "$arm: job ended at $(( $(date +%s) - T0 )) s" >> "$LOG"
  sleep 180; touch "$DIR/.memab_stop"; wait $SP; rm -f "$DIR/.memab_stop"
  awk -F, -v a="$arm" 'NR>1 && $2!="" {if(!w||$2<w)w=$2; if(!v||$3<v)v=$3} END {print a": min Windows free "w" MB, min VM available "v" MB"}' "$CSV" >> "$LOG"
done
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
restart "" > /dev/null 2>&1
echo "all done" >> "$LOG"
