#!/bin/bash
set -u
timeout 60 ssh -o BatchMode=yes -o ConnectTimeout=12 \
  azza@azza.tail63f48.ts.net 'bash -s' <<'REMOTE'
set -u
echo ALIVE
ROOT=$HOME/wireclaw-corpus/ollama-raw
echo "-- one sample filename --"
ls "$ROOT/2026-05-19/" 2>/dev/null | head -n 2
echo "-- dir counts --"
for D in 2026-05-18 2026-05-19; do
  echo -n "$D total: "
  ls "$ROOT/$D" 2>/dev/null | wc -l
done
echo "-- in-window filename matches (filename ts in [20260518T191100,20260519T060300)) --"
python3 - <<'PY'
import os,glob
root=os.path.expanduser("~/wireclaw-corpus/ollama-raw")
ok={"192.168.1.15":0,"192.168.1.47":0}; bad=0
LO="20260518T191100"; HI="20260519T060300"
for D in ("2026-05-18","2026-05-19"):
    for fp in glob.glob(os.path.join(root,D,"*.json")):
        f=os.path.basename(fp)
        try:
            ip, ts, *_ = f.split("_")
        except ValueError:
            bad+=1; continue
        if ip not in ok: continue
        if LO <= ts < HI:
            ok[ip]+=1
print("matches:",ok,"  badnames:",bad,"  total:",sum(ok.values()))
PY
REMOTE
echo "EXIT=$?"
