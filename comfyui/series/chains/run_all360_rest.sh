#!/usr/bin/env bash
# After the first v2v run (qwen, real2, arc; flux2/sdxl/flux2k9 had no orbit yet because of the stdin bug):
# the 3 missing orbits, then their v2v, then the full compare videos (new names; the 3-of-6 compares stay).
DIR="$(dirname "$0")"
until grep -q "^V2V DONE" "$DIR/all360_v2v.log"; do sleep 30; done
ORBITS_TAG="ORBITS2 DONE" CMP_NAME=compare_360_full "$DIR/run_all360_orbits.sh"
WAIT_TAG="ORBITS2 DONE" CMP_NAME=compare_360_v2v_full V2V_TAG="V2V2 DONE" "$DIR/run_all360_v2v.sh"
echo "REST DONE $(date +%H:%M)" >> "$DIR/all360_v2v.log"
