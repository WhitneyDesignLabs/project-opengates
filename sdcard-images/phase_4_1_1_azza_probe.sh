#!/bin/bash
# Phase 4.1.1 §1.1: azza proxy-log coverage for the 4.0.4a overnight run.
# Window 2026-05-18 19:11 -> 2026-05-19 06:02 MST = 02:11 -> 13:02 UTC
# (proxy 'ts' is UTC). Verdict gate for salvage Path A vs B.
set -u
timeout 90 ssh -o ConnectTimeout=12 -o BatchMode=yes \
  -o ServerAliveInterval=5 -o ServerAliveCountMax=3 \
  azza@azza.tail63f48.ts.net 'bash -s' <<'REMOTE'
set -u
python3 - <<'PY'
import json, glob, os
from collections import Counter
from datetime import datetime
root=os.path.expanduser("~/wireclaw-corpus/ollama-raw")
# ts is MST-local compact 'YYYYMMDDThhmmss_micros'. Run window MST:
# 2026-05-18 19:11 -> 2026-05-19 06:03.
LO="20260518T191100"; HI="20260519T060300"
files=[]
for day in ("2026-05-18","2026-05-19"):
    files += glob.glob(os.path.join(root,day,"*.json"))
print(f"candidate files (05-18+05-19 dirs): {len(files)}")
inwin=0; ip=Counter(); bad=0; ts_list=[]; chat=0; perip={}
for fp in files:
    try:
        r=json.loads(open(fp).read())
    except Exception:
        bad+=1; continue
    raw=(r.get("ts") or "")
    key=raw.split("_")[0]            # YYYYMMDDThhmmss
    if LO <= key < HI:
        inwin+=1
        cip=r.get("client_ip")
        ip[cip]+=1
        ts_list.append(key)
        perip.setdefault(cip,[]).append(key)
        if "chat/completions" in (r.get("path") or ""):
            chat+=1
print(f"in-window records (MST {LO}..{HI}): {inwin}")
print(f"per client_ip: {dict(ip)}")
print(f"chat/completions records: {chat}")
print(f"malformed/unreadable: {bad}")
if ts_list:
    ts_list.sort()
    print(f"first ts: {ts_list[0]}")
    print(f"last  ts: {ts_list[-1]}")
    def p(t):
        try: return datetime.strptime(t,"%Y%m%dT%H%M%S")
        except: return None
    ds=[p(t) for t in ts_list]; ds=[d for d in ds if d]
    gaps=[(ds[i]-ds[i-1]).total_seconds() for i in range(1,len(ds))]
    if gaps:
        print(f"max inter-record gaps (s, top5): {[round(g) for g in sorted(gaps)[-5:]]}")
        print(f"gaps >300s (possible drop windows): {sum(1 for g in gaps if g>300)}")
    for cip in sorted(perip):
        s=sorted(perip[cip])
        print(f"  {cip}: n={len(s)} first={s[0]} last={s[-1]}")
PY
REMOTE
echo "PROBE-EXIT=$?"
