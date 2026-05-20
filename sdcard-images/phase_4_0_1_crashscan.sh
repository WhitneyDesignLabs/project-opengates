#!/bin/bash
# Phase 4.0.1 Step 2b: per chip, find the transition from genuine model
# replies -> boot-loop banner ("WireClaw vX started") / timeouts.
# That transition timestamp IS the crash time.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
P2="$SSH scott@192.168.1.17"
P3="$SSH scott@192.168.1.44"

PY='
import glob,json,os,sys
fs=sorted(glob.glob(os.path.expanduser("~/wireclaw-corpus/user-side/*.jsonl")))
rows=[]
for f in fs:
    try:
        for ln in open(f):
            ln=ln.strip()
            if not ln: continue
            try: d=json.loads(ln)
            except: continue
            d["_f"]=os.path.basename(f); rows.append(d)
    except: pass
rows.sort(key=lambda r: r.get("ts_sent") or "")
def banner(t): return (t is not None) and ("started" in t) and ("Config:" in t or "mDNS:" in t)
def good(r):
    t=r.get("reply_text")
    return (not r.get("reply_timed_out")) and (t is not None) and (not banner(t)) and len(t.strip())>0
last_good=None; first_bad=None
for r in rows:
    if good(r):
        last_good=r; first_bad=None
    else:
        if first_bad is None and last_good is not None: first_bad=r
print("total_turns=%d  first_ts=%s  last_ts=%s"%(len(rows), rows[0].get("ts_sent") if rows else "-", rows[-1].get("ts_sent") if rows else "-"))
if last_good:
    print("LAST_GOOD ts_recv=%s  prompt=%s  file=%s"%(last_good.get("ts_received"), last_good.get("prompt_id"), last_good["_f"]))
    rt=(last_good.get("reply_text") or "")[:160].replace(chr(10)," ")
    print("LAST_GOOD reply: %s"%rt)
else:
    print("LAST_GOOD: NONE FOUND (no genuine model reply in entire corpus)")
if first_bad:
    print("FIRST_BAD ts_sent=%s  prompt=%s  timed_out=%s  file=%s"%(first_bad.get("ts_sent"), first_bad.get("prompt_id"), first_bad.get("reply_timed_out"), first_bad["_f"]))
    bt=(first_bad.get("reply_text") or "<null/timeout>")[:120].replace(chr(10)," ")
    print("FIRST_BAD reply: %s"%bt)
g=sum(1 for r in rows if good(r)); print("good_turns=%d  bad_turns=%d"%(g,len(rows)-g))
'

scan() { $1 "python3 -c '$PY'" 2>&1; }

echo "==== pi02 (c6-02 / .15) ===="; scan "$P2"
echo "==== pi03 (c6-03 / .47) ===="; scan "$P3"
