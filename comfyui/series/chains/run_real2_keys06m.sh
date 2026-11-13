#!/usr/bin/env bash
# New 360-degree start pictures (the owner 00:10: strength 0.6; orbit_key_c1 at 0.8 "is not it at all"). Waits for the
# painted s1 job (S1NEW DONE/FAILED), then REAL2_S=0.6 REAL2_KEYTAG=06m keys (4 seeds, walk-test scene words) and a
# sheet keys06m.jpg (the chosen portrait + 4). No video — the owner picks first. Logs to real2_keys06m.log ("KEYS06M DONE").
. "$(dirname "$0")/_env.sh" COMFY_HOME_WIN || exit 2
set -u
DIR="$(dirname "$0")"; LOG="$DIR/real2_keys06m.log"; STOPF="$DIR/.guard_off_k06m"; R="$COMFY_HOME_WIN"
O="$COMFY_HOME"/output/series/real2check
echo "start $(date +%H:%M)" >> "$LOG"
true
sleep 10
START_STOPS=$(grep -c "GUARD STOP" "$DIR/guard.log" 2>/dev/null || echo 0)
"$DIR/guard_ram.sh" 6000 "$STOPF" & GUARD=$!
trap 'touch "$STOPF"; kill $GUARD 2>/dev/null' EXIT
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1; sleep 3
pwsh.exe -NoProfile -File "$R\\start-comfyui.ps1" -Detach > /dev/null 2>&1
up=0; for i in $(seq 1 60); do pwsh.exe -NoProfile -Command "wslc exec comfyui curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8188/system_stats" 2>/dev/null | grep -q 200 && { up=1; break; }; sleep 5; done
[ "$up" = 1 ] || { echo "KEYS06M FAILED: comfyui did not answer" >> "$LOG"; exit 1; }
pwsh.exe -NoProfile -Command "wslc exec comfyui sh -c 'REAL2_S=0.6 REAL2_KEYTAG=06m python /opt/tests/real2_check.py keys'" 2>&1 | tr -d '\r' | grep -E "real2check|rror|Trace" >> "$LOG"
pwsh.exe -NoProfile -Command "wslc stop comfyui" > /dev/null 2>&1
pwsh.exe -NoProfile -Command "wslc run --rm --name k06msheet -v '$R\output:/data/output' --entrypoint python3 comfyui-r9700:local -c \"from PIL import Image; import glob; D='/data/output/series/real2check'; fs=['/data/output/series/lora_test/realface_slvra_v1_70_portrait_00001_.png']+[sorted(glob.glob(D+'/orbit_key06m_c%d_*.png' % n))[-1] for n in (1,2,3,4)]; o=Image.new('RGB',(5*640,352)); [o.paste(Image.open(f).convert('RGB').resize((640,352)),(640*i,0)) for i,f in enumerate(fs)]; o.save(D+'/keys06m.jpg',quality=92)\"" 2>&1 | tr -d '\r' | head -5 >> "$LOG"
n=$(ls $O/orbit_key06m_c*.png 2>/dev/null | wc -l)
[ "$n" = 4 ] && [ -f $O/keys06m.jpg ] && echo "KEYS06M DONE $(date +%H:%M)" >> "$LOG" || echo "KEYS06M INCOMPLETE $(date +%H:%M) ($n/4)" >> "$LOG"
