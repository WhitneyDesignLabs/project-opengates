#!/bin/bash
# Phase 4.1.1 salvage step A: pull the in-window /v1/chat/completions
# proxy records from azza into local /mnt/c/.../corpus/proxy-4.1.1/.
# Filter by filename (<IP>_YYYYMMDDThhmmss_micros.json) via Python on
# azza, tar archive, single scp.
set -u
K="$HOME/.ssh/evobot_ed25519"
DEST=/mnt/c/Users/homet/Documents/WireClaw/corpus/proxy-4.1.1
LOCAL_TAR="$DEST/proxy-window.tar.gz"
mkdir -p "$DEST"

ssh -o BatchMode=yes -o ConnectTimeout=15 \
    -o ServerAliveInterval=5 -o ServerAliveCountMax=4 \
    azza@azza.tail63f48.ts.net 'bash -s' <<'REMOTE'
set -u
python3 - <<'PY'
import os,glob,subprocess
root=os.path.expanduser("~/wireclaw-corpus/ollama-raw")
LO="20260518T191100"; HI="20260519T060300"
keep=[]
for D in ("2026-05-18","2026-05-19"):
    for fp in glob.glob(os.path.join(root,D,"*.json")):
        f=os.path.basename(fp)
        try: ip,ts,_=f.split("_",2)
        except ValueError: continue
        if ip in ("192.168.1.15","192.168.1.47") and LO <= ts < HI:
            keep.append(os.path.join(D,f))
keep.sort()
listfp="/tmp/proxy-window-list.txt"
open(listfp,"w").write("\n".join(keep))
print(f"selected: {len(keep)}  list={listfp}")
out="/tmp/proxy-window.tar.gz"
r=subprocess.run(["tar","czf",out,"-C",root,"-T",listfp])
print(f"tar rc={r.returncode}  out={out}  size={os.path.getsize(out)}")
PY
REMOTE
echo "=== fetching archive ==="
scp -q -o BatchMode=yes -i "$K" \
    azza@azza.tail63f48.ts.net:/tmp/proxy-window.tar.gz "$LOCAL_TAR"
SCP_RC=$?
echo "scp rc=$SCP_RC"
ls -la "$LOCAL_TAR"
mkdir -p "$DEST/files"
tar xzf "$LOCAL_TAR" -C "$DEST/files"
echo -n "extracted total: "; find "$DEST/files" -name '*.json' | wc -l
echo -n " .15: "; find "$DEST/files" -name '192.168.1.15_*.json' | wc -l
echo -n " .47: "; find "$DEST/files" -name '192.168.1.47_*.json' | wc -l
