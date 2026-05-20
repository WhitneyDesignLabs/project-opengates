#!/bin/bash
# Decision-critical: where deterministic fired pseudo-prose (now final=pp,
# overriding Haiku), what did Haiku-alone actually say? Tests the directive's
# "deterministic pp is high-precision" assumption that justifies det-wins.
set -u
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import json
from collections import Counter
LBL='fork/lora/corpus-labels'
CH=['pilot','c6-02','c6-03']

det_pp_vs_haiku=Counter()
det_fab_vs_haiku=Counter()
examples_pp_clean=[]
for chip in CH:
    R=json.load(open(f'{LBL}/3.1.3-2026-05-16-{chip}.haiku.json'))['records']
    for r in R:
        d=r.get('deterministic_label'); h=r.get('haiku_label')
        if d=='pseudo-prose':
            det_pp_vs_haiku[h]+=1
            if h=='clean' and len(examples_pp_clean)<6:
                examples_pp_clean.append((chip, r.get('id','')[:48],
                    r.get('deterministic_evidence','')[:140],
                    str(r.get('haiku_rationale',''))[:200]))
        elif d=='fabricated':
            det_fab_vs_haiku[h]+=1

def pct(c):
    t=sum(c.values()) or 1
    return {k:f"{v} ({100*v/t:.0f}%)" for k,v in c.most_common()}

print("=== det=PSEUDO-PROSE (now wins final) vs Haiku-alone ===")
print("  total:",sum(det_pp_vs_haiku.values()))
print(" ",pct(det_pp_vs_haiku))
print("  -> if Haiku mostly AGREES (pp), det-pp catch is high-precision (good).")
print("  -> if Haiku says CLEAN a lot, det-pp is suppressing good turns (bad for training pool).")
print()
print("=== det=FABRICATED (now wins final) vs Haiku-alone ===")
print("  total:",sum(det_fab_vs_haiku.values()))
print(" ",pct(det_fab_vs_haiku))
print()
print("=== samples: det=pp but Haiku=clean (potential suppressed-good) ===")
for chip,i,ev,hr in examples_pp_clean:
    print(f"- [{chip}] {i}")
    print(f"    det_evidence: {ev}")
    print(f"    haiku(clean): {hr}")
EOF
