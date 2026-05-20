#!/bin/bash
# Phase 3.1.3 M5: cross-pair sanity + raw client_ip census of the windowed proxy dir.
set -u
BENCH="/mnt/c/Users/homet/Documents/WireClaw/bench"
F="$HOME/3.1.3-proxy-window"
OUT="$BENCH/fork/lora/corpus-raw"

echo "===== M5a: per-corpus client_ip set (should be exactly one each) ====="
for label in pilot c6-02 c6-03; do
python3 -c "
import json
d=json.load(open('$OUT/3.1.3-2026-05-16-${label}.json'))
ips=set()
for c in d['conversations']:
    v=c.get('client_ip')
    if v: ips.add(v)
print(f'${label}: turns={len(d[\"conversations\"])} client_ips={sorted(ips)}')
"
done

echo
echo "===== M5b: RAW client_ip census across windowed proxy dir ====="
python3 - "$F" <<'PY'
import sys, os, json, collections
F=sys.argv[1]
c=collections.Counter()
bad=0
for root,_,files in os.walk(F):
    for fn in files:
        if not fn.endswith('.json'): continue
        try:
            r=json.load(open(os.path.join(root,fn)))
        except Exception:
            bad+=1; continue
        c[r.get('client_ip')]+=1
print("records per client_ip (windowed 3.1.3):")
for ip,n in c.most_common():
    print(f"  {ip!s:18} {n}")
print("malformed:",bad,"total:",sum(c.values()))
PY

echo
echo "===== M5c: what does 192.168.1.51 (EvoBot Pi IP) traffic look like? ====="
python3 - "$F" <<'PY'
import sys, os, json, collections
F=sys.argv[1]
paths=collections.Counter(); models=collections.Counter(); n=0; samp=None
for root,_,files in os.walk(F):
    for fn in files:
        if not fn.endswith('.json') or not fn.startswith('192.168.1.51_'): continue
        try: r=json.load(open(os.path.join(root,fn)))
        except: continue
        n+=1
        paths[r.get('path')]+=1
        models[(r.get('request') or {}).get('model')]+=1
        if samp is None:
            msgs=(r.get('request') or {}).get('messages') or []
            samp=(r.get('ts'), r.get('path'), [m.get('role') for m in msgs],
                  (msgs[-1].get('content') if msgs else '')[:160])
print(f".51 record count={n}")
print(" paths:",dict(paths))
print(" models:",dict(models))
print(" sample (ts,path,roles,last_content[:160]):"); print("  ",samp)
PY
