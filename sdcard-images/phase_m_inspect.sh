#!/bin/bash
set -u
P="$HOME/3.1.3-pull"
J="$HOME/3.1.3-jsonl"

echo "===== PROXY dir layout ====="
find "$P" -maxdepth 1 -type d | sort
echo "-- sample proxy filenames (05-16 dir) --"
ls -1 "$P/2026-05-16" 2>/dev/null | head -3
ls -1 "$P/2026-05-16" 2>/dev/null | tail -2
echo "-- sample proxy filenames (05-17 dir) --"
ls -1 "$P/2026-05-17" 2>/dev/null | head -2
ls -1 "$P/2026-05-17" 2>/dev/null | tail -2
echo "-- one proxy record ts/client_ip/status (05-17) --"
f=$(find "$P/2026-05-17" -name '*.json' | sort | head -1)
python3 -c "import json,sys; r=json.load(open('$f')); print({k:r.get(k) for k in ('ts','client_ip','path','status','upstream_latency_ms')})"

echo
echo "===== JSONL ====="
echo "-- count by run window (filename ts) --"
ls -1 "$J"/*overnight*.jsonl 2>/dev/null | xargs -n1 basename 2>/dev/null > /tmp/jl.txt
wc -l < /tmp/jl.txt
echo -n "  05-15 (3.1.1): "; grep -cE '^2026-05-15T' /tmp/jl.txt || true
echo -n "  05-16 day 07-20:06 (3.1.2): "; grep -cE '^2026-05-16T(0[7-9]|1[0-9]|200[0-9]|201[0-9]|2020|2021|2022|2023|2024|2025)' /tmp/jl.txt || true
echo -n "  05-16T2026+ -> 05-17T07 (3.1.3): "; grep -cE '^2026-05-16T20(2[6-9]|[3-9])|^2026-05-16T2[1-3]|^2026-05-17T0[0-7]' /tmp/jl.txt || true
echo "  earliest/latest jsonl:"; sort /tmp/jl.txt | sed -n '1p;$p'
echo "-- one 3.1.3 jsonl: first record keys + sample --"
f3=$(grep -E '^2026-05-17T0[0-3]' /tmp/jl.txt | head -1)
echo "  file=$f3"
python3 -c "
import json
ls=open('$J/$f3').read().splitlines()
print('  lines(records):', len(ls))
import collections
r=json.loads(ls[0]); print('  rec0 keys:', sorted(r.keys()))
for k in ('persona','persona_id','prompt_id','session','turn','prompt','ts'):
    if k in r: print('   ',k,'=',repr(r[k])[:120])
"
