#!/usr/bin/env bash
# HiDream base test, 2nd rest (2026-11-12 21:30): the 20:11 rest made only "laugh" (2 of 5 now); angry, castle, campfire
# are missing with no error in the filtered log. Waits for "^ARMFIX DONE" (checked: no such line before this start), a
# fresh server, run() skips the done pictures, FULL output kept in hidream_rest2.out, then the sheet. Log newmodel.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
DIR="$(dirname "$0")"; R="$COMFY_HOME_WIN"
until grep -q "^ARMFIX DONE" "$DIR/all360_armfix.log"; do sleep 30; done
echo "hidream rest2 start $(date +%H:%M)" >> "$DIR/newmodel.log"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && break; sleep 5; done
pwsh.exe -NoProfile -Command "wslc exec -e SHE3_STRENGTHS=0.0 comfyui sh -c 'python /opt/tests/newmodel_check.py run hidream'" > "$DIR/hidream_rest2.out" 2>&1
grep -E "newmodel|rror|Trace|imeout|Killed" "$DIR/hidream_rest2.out" | tr -d '\r' | head -20 >> "$DIR/newmodel.log"
pwsh.exe -NoProfile -Command "wslc logs comfyui" 2>&1 | tr -d '\r' | tail -n 40 > "$DIR/hidream_rest2_comfy.log"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name nm-sheet3 -v '$R\output:/data/output' -v '$R\tests:/opt/tests:ro' --entrypoint python3 comfyui-r9700:local /opt/tests/newmodel_check.py sheet hidream" 2>&1 | tr -d '\r' | tail -3 >> "$DIR/newmodel.log"
echo "HIDREAM REST2 DONE $(date +%H:%M)" >> "$DIR/newmodel.log"
