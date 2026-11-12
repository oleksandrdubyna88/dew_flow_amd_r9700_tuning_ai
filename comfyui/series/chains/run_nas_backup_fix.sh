#!/usr/bin/env bash
# Fix of run_nas_backup.sh (2026-11-12 20:24 run): (1) 35 files in output/lora/out are root-only on C: (written by the
# trainer container) -> "Permission denied" for rsync as a normal user; copy them in a container (root) to the output folder of NAS_BACKUP_WIN.
# (2) the verify step hashed 0 files (relative ./ log path after cd) -> verify now: sha256 of all 1586 + 35 copied files,
# source (the ComfyUI folder) vs the NAS mirror, inside one container (root can read every source file). Never deletes. Log nas_backup.log.
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN NAS_BACKUP_WIN || exit 2
DIR="$(dirname "$0")"; LOG="$DIR/nas_backup.log"
echo "nas backup fix start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name nas-fix -v '$COMFY_HOME_WIN:/src:ro' -v '$NAS_BACKUP_WIN:/dst' --entrypoint sh comfyui-r9700:local -c 'n=0; while read f; do mkdir -p \"/dst/\$(dirname \"\$f\")\"; [ -f \"/dst/\$f\" ] || { nice -n 19 cp \"/src/\$f\" \"/dst/\$f.part\" && mv \"/dst/\$f.part\" \"/dst/\$f\" && n=\$((n+1)); }; done < /src/tests/nas_denied_20261112.txt; echo \"copied denied files: \$n\"; ok=0; bad=0; cat /src/tests/nas_copied_20261112.txt /src/tests/nas_denied_20261112.txt | while read f; do a=\$(nice -n 19 sha256sum \"/src/\$f\" | cut -c1-64); b=\$(nice -n 19 sha256sum \"/dst/\$f\" 2>/dev/null | cut -c1-64); [ \"\$a\" = \"\$b\" ] && echo OK || echo \"MISMATCH \$f\"; done | sort | uniq -c | sort -rn | head -20'" 2>&1 | tr -d '\r' >> "$LOG"
echo "NAS BACKUP FIX DONE $(date +%H:%M)" >> "$LOG"
