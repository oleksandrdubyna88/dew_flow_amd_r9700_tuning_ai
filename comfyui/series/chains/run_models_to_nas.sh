#!/usr/bin/env bash
# Model weights master copy (the owner's rule from 2026-11-07: COMFY_STORE_WIN (on the NAS) is the MASTER copy of all weights, the
# wslc volume comfy-models is the local working copy). 2026-11-12 ~20:35 the owner asked "do you download all weights
# first to the NAS store as I asked?" -> no: since 11-11 I downloaded straight into the volume (85 files, 293.9 GB
# missing on the NAS). This copies every volume file that is missing on the NAS (or has another size) -> /store/<same path>,
# through <name>.part + mv, then sha256 of the volume file and of the NAS copy must match. Never deletes, never touches
# a file already correct on the NAS. Low priority. Log models_to_nas.log ("MODELS NAS DONE").
. "$(dirname "$0")/_env.sh" COMFY_STORE_WIN || exit 2
DIR="$(dirname "$0")"; LOG="$DIR/models_to_nas.log"
echo "models to nas start $(date +%H:%M)" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc run --rm --name models-nas -v comfy-models:/models:ro -v '$COMFY_STORE_WIN:/store' --entrypoint sh comfyui-r9700:local -c 'cd /models; ok=0; bad=0; find . -type f ! -name \"*.part\" | sort | while read f; do s=\$(stat -c %s \"\$f\"); if [ -f \"/store/\$f\" ] && [ \"\$(stat -c %s \"/store/\$f\")\" = \"\$s\" ]; then continue; fi; mkdir -p \"/store/\$(dirname \"\$f\")\"; nice -n 19 cp \"\$f\" \"/store/\$f.part\" && mv \"/store/\$f.part\" \"/store/\$f\"; a=\$(nice -n 19 sha256sum \"\$f\" | cut -c1-64); b=\$(nice -n 19 sha256sum \"/store/\$f\" | cut -c1-64); if [ \"\$a\" = \"\$b\" ]; then echo \"OK \$f \$a\"; else echo \"HASH MISMATCH \$f \$a \$b\"; fi; done'" 2>&1 | tr -d '\r' >> "$LOG"
echo "copied+verified: $(grep -c '^OK ' "$LOG"), mismatches: $(grep -c '^HASH MISMATCH' "$LOG")" >> "$LOG"
echo "MODELS NAS DONE $(date +%H:%M)" >> "$LOG"
