#!/bin/bash
# Phase 4.1.1 salvage A1: build the in-window tar on azza only. Phase 2
# is a separate scp. Splitting to isolate any failure surface.
set -u
ssh -o BatchMode=yes -o ConnectTimeout=15 -o ServerAliveInterval=5 \
    azza@azza.tail63f48.ts.net 'bash -s' <<'REMOTE'
set -u
python3 - <<'PY'
import os, glob, subprocess, sys
root = os.path.expanduser("~/wireclaw-corpus/ollama-raw")
LO, HI = "20260518T191100", "20260519T060300"
keep = []
for D in ("2026-05-18", "2026-05-19"):
    for fp in glob.glob(os.path.join(root, D, "*.json")):
        f = os.path.basename(fp)
        parts = f.split("_", 2)
        if len(parts) < 2: continue
        ip, ts = parts[0], parts[1]
        if ip in ("192.168.1.15", "192.168.1.47") and LO <= ts < HI:
            keep.append(os.path.join(D, f))
keep.sort()
listfp = "/tmp/proxy-window-list.txt"
with open(listfp, "w") as fh:
    fh.write("\n".join(keep) + "\n")
print(f"selected: {len(keep)} files; list -> {listfp}")
out = "/tmp/proxy-window.tar.gz"
r = subprocess.run(["tar", "czf", out, "-C", root, "-T", listfp],
                   capture_output=True, text=True)
print(f"tar rc={r.returncode}  out={out}  size={os.path.getsize(out) if os.path.exists(out) else 'MISSING'}")
if r.stderr.strip():
    print("tar stderr:", r.stderr[:600])
PY
echo "REMOTE-EXIT=$?"
REMOTE
echo "SSH-EXIT=$?"
