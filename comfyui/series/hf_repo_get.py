"""Download a whole open Hugging Face repo (no token) into a folder, file by file with curl resume (-C -); skips files
that are already complete. Used for diffusers-format models that diffusion-pipe needs (2026-11-12: HiDream-I1-Full).
Run in a container:  python3 /opt/tests/hf_repo_get.py <repo> <dest dir> [skip-substring ...]"""
import json
import os
import subprocess
import sys
import urllib.request

repo, dest, skip = sys.argv[1], sys.argv[2], sys.argv[3:]
files = json.load(urllib.request.urlopen(f"https://huggingface.co/api/models/{repo}/tree/main?recursive=true"))
files = [f for f in files if f["type"] == "file" and not any(s in f["path"] for s in skip)]
ok = 0
for f in files:
    size = f.get("lfs", {}).get("size", f.get("size", 0))
    out = os.path.join(dest, f["path"])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    if os.path.exists(out) and os.path.getsize(out) == size:
        ok += 1
        continue
    r = subprocess.run(["curl", "-fL", "-C", "-", "--retry", "20", "--retry-delay", "15", "--retry-all-errors", "--speed-limit", "100000", "--speed-time", "90", "-sS", "-o", out + ".part",
                        f"https://huggingface.co/{repo}/resolve/main/{f['path']}"])
    if r.returncode == 0 and os.path.getsize(out + ".part") == size:
        os.replace(out + ".part", out)
        ok += 1
        print(f"got {f['path']} {size / 1e9:.1f}G", flush=True)
    else:
        print(f"FAIL {f['path']} rc={r.returncode}", flush=True)
print(f"repo {repo}: {ok}/{len(files)} files", flush=True)
print("REPO OK" if ok == len(files) else "REPO INCOMPLETE", flush=True)
