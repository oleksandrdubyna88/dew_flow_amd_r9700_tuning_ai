#!/usr/bin/env bash
# Windows memory every 10 s: available, committed, GPU shared and dedicated usage (all adapters summed), vmmem working sets.
# The consultants (2026-11-09) asked for these to tell WDDM GPU-memory demotion from VM paging at job end. Usage: gpumem.sh <csv>
CSV="$1"; T0=$(date +%s); echo "t_s,avail_mb,committed_mb,gpu_shared_mb,gpu_dedicated_mb,vmmemwslc_ws_mb,vmmemwsl_ws_mb" > "$CSV"
while true; do
  row="$(pwsh.exe -NoProfile -Command '$m = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory; $g = Get-Counter "\GPU Adapter Memory(*)\Shared Usage","\GPU Adapter Memory(*)\Dedicated Usage" -ErrorAction SilentlyContinue; $sh = ($g.CounterSamples | ? Path -like "*shared usage" | Measure-Object CookedValue -Sum).Sum; $de = ($g.CounterSamples | ? Path -like "*dedicated usage" | Measure-Object CookedValue -Sum).Sum; $w1 = (Get-Process vmmemwslc* -ErrorAction SilentlyContinue | Measure-Object WorkingSet64 -Sum).Sum; $w2 = (Get-Process vmmemWSL -ErrorAction SilentlyContinue | Measure-Object WorkingSet64 -Sum).Sum; "{0},{1},{2},{3},{4},{5}" -f $m.AvailableMBytes, [int]($m.CommittedBytes/1MB), [int]($sh/1MB), [int]($de/1MB), [int]($w1/1MB), [int]($w2/1MB)' 2>/dev/null | tr -d '\r')"
  echo "$(( $(date +%s) - T0 )),$row" >> "$CSV"; sleep 10
done
