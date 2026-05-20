#!/bin/bash
# Phase 3.1.3 M4-prep: window-filter proxy dir to the 3.1.3 run, and compute
# jsonl-truth counts (turns/persona/timeouts) independent of the aggregator.
set -u
P="$HOME/3.1.3-pull"
J="$HOME/3.1.3-jsonl"
F="$HOME/3.1.3-proxy-window"   # filtered proxy dir for the aggregator
LO="20260516T202600"           # relaunch lower bound (EvoBot 20:26:03)
HI="20260517T071500"           # upper bound (post-drain, pre M7 health curls)

rm -rf "$F"; mkdir -p "$F"
# Proxy filenames: <client_ip>_<YYYYMMDDTHHMMSS>_<us>.json  -> window by embedded ts
python3 - "$P" "$F" "$LO" "$HI" <<'PY'
import sys, re, shutil, os
src, dst, lo, hi = sys.argv[1:5]
rx = re.compile(r'_(\d{8}T\d{6})_')
n=tot=0
for root,_,files in os.walk(src):
    for fn in files:
        if not fn.endswith('.json'): continue
        tot+=1
        m=rx.search(fn)
        if not m: continue
        ts=m.group(1)
        if lo<=ts<=hi:
            shutil.copy2(os.path.join(root,fn), os.path.join(dst,fn))
            n+=1
print(f"proxy: scanned={tot} in-window(3.1.3)={n} -> {dst}")
PY

echo
echo "===== JSONL TRUTH (3.1.3 window, filename-derived) ====="
python3 - "$J" <<'PY'
import sys, os, re, json, collections
jdir=sys.argv[1]
# 3.1.3 window by filename leading ISO ts
def in313(fn):
    m=re.match(r'(\d{4}-\d{2}-\d{2}T\d{6})_', fn)
    if not m: return False
    t=m.group(1)
    return "2026-05-16T202600" <= t <= "2026-05-17T071500"
files=[f for f in os.listdir(jdir) if f.endswith('.jsonl') and 'overnight' in f and in313(f)]
per_persona_sessions=collections.Counter()
per_persona_turns=collections.Counter()
total_turns=0; timeouts=0; empty=0; sessions=len(files)
seen=collections.Counter()
for f in files:
    seen[f]+=1
    mp=re.search(r'_(persona_\d{2}_[a-z_]+)\.jsonl$', f)
    pers = mp.group(1) if mp else 'UNKNOWN'
    per_persona_sessions[pers]+=1
    try:
        lines=[l for l in open(os.path.join(jdir,f)).read().splitlines() if l.strip()]
    except Exception as e:
        print("ERR",f,e); continue
    if not lines: empty+=1
    for l in lines:
        total_turns+=1
        per_persona_turns[pers]+=1
        try:
            r=json.loads(l)
            if r.get('reply_timed_out'): timeouts+=1
        except: pass
print(f"3.1.3 sessions(jsonl files)={sessions}  total_turns={total_turns}  "
      f"timeouts={timeouts}  empty_sessions={empty}")
dups=[k for k,v in seen.items() if v>1]
print(f"filename collisions across Pis: {len(dups)} (merged dir; per-Pi truth = .status.final)")
print("\nPer-persona SESSIONS / TURNS (aggregate across 3 Pis):")
for p in sorted(per_persona_sessions):
    print(f"  {p:34} sessions={per_persona_sessions[p]:4}  turns={per_persona_turns[p]:5}")
PY

echo
echo "===== OVERNIGHT LOG anomaly grep (3.1.3 per-run logs) ====="
for L in evobot pi02 pi03; do
  echo "--- $L : 3.1.3 log FAIL/TIMEOUT/Traceback/persona-not-found ---"
  grep -nE 'FAIL|TIMEOUT|Traceback|persona not found|max-consecutive' "$J/$L.3.1.3.log" 2>/dev/null | tail -8 || echo "(no $L.3.1.3.log or clean)"
  echo "--- $L : .status.final ---"
  cat "$J/$L.status.final" 2>/dev/null || echo "(missing)"
done
