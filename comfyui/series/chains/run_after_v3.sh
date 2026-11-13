#!/usr/bin/env bash
# After the female ep1 narration (the last CPU job; owner 2026-11-09: no more heavy CPU jobs): the memory-flag A/B on the
# GPU (run_memab.sh), then ep2 v3 with the VoxCPM narration and the moving ending (a short ffmpeg step, 2 threads).
# No CPU 60 fps step: interpolation waits for a GPU method. Logs to after-v3.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/after-v3.log"; R="$COMFY_HOME_WIN"; D=/data/output/series/ep2
until grep -q "all done" "$DIR/woman-ep1.log" 2>/dev/null; do sleep 30; done
echo "start $(date +%H:%M)" >> "$LOG"
"$DIR/run_memab.sh"
echo "memab done $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name comfyui-mix -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/voiceover.py $D/ep2_arcane_14b_v3.mp4 ep2/vox --shot 5.0625 --end slowmo" 2>&1 | tr -d '\r' | grep -E "ending|audio ok|written|bad|rror" >> "$LOG"
echo "all done $(date +%H:%M)" >> "$LOG"
