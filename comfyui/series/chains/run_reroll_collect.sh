#!/usr/bin/env bash
# The owner 2026-11-12 ~17:25: "when all 6 new 360s are ready, put them in a separate folder and give me the path".
# Waits for "^REROLL DONE", copies (container: the output folders are root-owned) the 6 reroll videos + their 2 fps frame
# sheets -> series/all360/reroll_6/<model>_<b|c>.mp4. Copies only (cp -n), the originals stay. Log all360_reroll.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
DIR="$(dirname "$0")"; LOG="$DIR/all360_reroll.log"; R="$COMFY_HOME_WIN"
until grep -q "^REROLL DONE" "$LOG"; do sleep 30; done
pwsh.exe -NoProfile -Command "wslc run --rm --name rr-collect -v '$R\output:/data/output' --entrypoint sh comfyui-r9700:local -c 'A=/data/output/series/all360; mkdir -p \$A/reroll_6; for m in sdxl flux2k9 flux2; do for t in b c; do [ -f \$A/\$m/orbit_360_\$t.mp4 ] && cp -n \$A/\$m/orbit_360_\$t.mp4 \$A/reroll_6/\${m}_\$t.mp4; [ -f \$A/\$m/orbit_360_\${t}_frames.jpg ] && cp -n \$A/\$m/orbit_360_\${t}_frames.jpg \$A/reroll_6/\${m}_\${t}_frames.jpg; done; done; ls \$A/reroll_6'" 2>&1 | tr -d '\r' >> "$LOG"
echo "COLLECT DONE $(date +%H:%M)" >> "$LOG"
