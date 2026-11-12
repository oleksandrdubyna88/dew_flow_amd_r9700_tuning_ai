#!/usr/bin/env bash
# The owner 2026-11-12 ~20:15: "when the redone 360s are ready, put all 8 (with Qwen) in a separate folder and give it to me".
# 8 = the 6 arm-fix videos (sdxl, flux2k9, flux2 x ab/ac) + Qwen's two (orbit_360 = version 1 the owner liked, orbit_360_v2v).
# Waits for "^ARMFIX DONE" (checked: no such line in all360_armfix.log before this start). Copies only (container,
# root-owned output) -> series/all360/final_8/. Log all360_armfix.log ("FINAL8 DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
DIR="$(dirname "$0")"; LOG="$DIR/all360_armfix.log"; R="$COMFY_HOME_WIN"
until grep -q "^ARMFIX DONE" "$LOG"; do sleep 30; done
pwsh.exe -NoProfile -Command "wslc run --rm --name final8 -v '$R\output:/data/output' --entrypoint sh comfyui-r9700:local -c 'A=/data/output/series/all360; F=\$A/final_8; mkdir -p \$F; for f in \$A/armfix_6/*.mp4 \$A/armfix_6/*_frames.jpg; do cp -n \$f \$F/; done; cp -n \$A/qwen/orbit_360.mp4 \$F/qwen_v1.mp4; cp -n \$A/qwen/orbit_360_v2v.mp4 \$F/qwen_v2v.mp4; ls \$F'" 2>&1 | tr -d '\r' >> "$LOG"
echo "FINAL8 DONE $(date +%H:%M)" >> "$LOG"
