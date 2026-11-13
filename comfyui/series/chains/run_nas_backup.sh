#!/usr/bin/env bash
# NAS backup (the owner 2026-11-12 ~20:20: "back up all pictures and LoRAs to the NAS; the folder is already there, add
# what is missing"). COMFY_HOME_WIN -> NAS_BACKUP_WIN (the existing mirror, 16 GB of 32). Adds and updates, NEVER
# deletes on the NAS (no --delete). Skips secrets/ (live tokens never go to the NAS) and __pycache__. Low priority
# (nice/ionice; disk + network only). Then every file rsync copied is checked by sha256 against the source, run INSIDE
# the NAS folder (relative paths). Log nas_backup.log ("NAS BACKUP DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN NAS_BACKUP_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/nas_backup.log"; SRC="$COMFY_HOME"; DST="$NAS_BACKUP"
L="$DIR/nas_backup_$(date +%Y%m%d_%H%M)"
echo "nas backup start $(date +%H:%M)" >> "$LOG"
nice -n 19 ionice -c3 rsync -rt --no-perms --itemize-changes --exclude 'secrets/' --exclude '__pycache__/' \
  "$SRC/output" "$SRC/input" "$SRC/tests" "$SRC"/*.md "$SRC"/*.ps1 "$SRC"/Containerfile "$SRC"/entrypoint.sh "$DST/" \
  > "$L.items" 2> "$L.err"; RC=$?
echo "rsync exit $RC $(date +%H:%M); copied files: $(grep -c '^>f' "$L.items"); errors: $(wc -l < "$L.err")" >> "$LOG"
grep '^>f' "$L.items" | cut -c13- > "$L.files"
( cd "$SRC" && tr '\n' '\0' < "$L.files" | nice -n 19 xargs -0 -r sha256sum ) > "$L.sha256"
( cd "$DST" && nice -n 19 sha256sum -c --quiet "$L.sha256" ) > "$L.check" 2>&1; VC=$?
echo "verify: $(wc -l < "$L.sha256") files hashed, sha256 -c exit $VC ($(grep -c FAILED "$L.check") FAILED) $(date +%H:%M)" >> "$LOG"
du -sh "$DST" >> "$LOG"
echo "NAS BACKUP DONE $(date +%H:%M)" >> "$LOG"
