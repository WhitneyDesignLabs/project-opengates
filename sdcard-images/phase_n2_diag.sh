#!/bin/bash
set -u
CL="/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus-labels"
python3 - "$CL" <<'PY'
import sys, json, collections
CL=sys.argv[1]
for chip in ['pilot','c6-02','c6-03']:
    o=json.load(open(f"{CL}/3.1.3-2026-05-16-{chip}.haiku.json"))
    recs=o['records']
    hl=collections.Counter(r.get('haiku_label') for r in recs)
    none_rat=collections.Counter(r.get('haiku_rationale') for r in recs if r.get('haiku_label') is None)
    nonnull=sum(1 for r in recs if r.get('haiku_label') is not None)
    print(f"== {chip}: {len(recs)} recs, haiku_label non-null={nonnull} ==")
    print("  haiku_label dist:", dict(hl))
    print("  rationale (where haiku_label None), top3:")
    for rat,n in none_rat.most_common(3):
        print(f"    [{n}] {str(rat)[:160]}")
PY
echo "== log tails (full) =="
for c in pilot c6-02 c6-03; do echo "--- $c ---"; cat "/tmp/haiku-$c.log"; done
