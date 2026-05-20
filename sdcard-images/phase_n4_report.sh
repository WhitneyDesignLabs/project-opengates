#!/bin/bash
# Phase 3.2 N4: label distribution + det-vs-haiku disagreement + uncertain reclassification.
set -u
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import json
from collections import Counter

print(f"{'chip':<8} {'turns':>6} {'clean':>7} {'pp':>6} {'fab':>6} {'unc':>5} {'contra':>7} {'det!=haiku':>11} {'haiku_null':>10}")
agg=Counter(); aggdis=0; aggn=0; aggnull=0
rows={}
for chip in ['pilot','c6-02','c6-03']:
    d=json.load(open(f'fork/lora/corpus-labels/3.1.3-2026-05-16-{chip}.haiku.json'))
    R=d['records']; n=len(R)
    fin=Counter(r.get('final_label') for r in R)
    dis=sum(1 for r in R if r.get('haiku_label') and r.get('deterministic_label')!=r.get('haiku_label'))
    nul=sum(1 for r in R if r.get('haiku_label') is None)
    rows[chip]=(n,fin,dis,nul)
    aggn+=n; aggdis+=dis; aggnull+=nul
    for k,v in fin.items(): agg[k]+=v
    print(f"{chip:<8} {n:>6} {fin.get('clean',0):>7} {fin.get('pseudo-prose',0):>6} "
          f"{fin.get('fabricated',0):>6} {fin.get('uncertain',0):>5} {fin.get('contradictory',0):>7} "
          f"{dis:>11} ({100*dis/n:.0f}%) {nul:>6}")
print()
print(f"COMBINED turns={aggn}  labels={dict(agg)}")
print(f"COMBINED det!=haiku disagreement = {aggdis}/{aggn} ({100*aggdis/aggn:.1f}%)  haiku_null={aggnull} ({100*aggnull/aggn:.2f}%)")

print("\n--- WHAT HAIKU MADE OF THE DETERMINISTIC 'uncertain' BUCKET ---")
tot_unc=Counter()
for chip in ['pilot','c6-02','c6-03']:
    d=json.load(open(f'fork/lora/corpus-labels/3.1.3-2026-05-16-{chip}.haiku.json'))
    unc=[r for r in d['records'] if r.get('deterministic_label')=='uncertain']
    rc=Counter(r.get('haiku_label') for r in unc)
    for k,v in rc.items(): tot_unc[k]+=v
    print(f"  {chip}: {len(unc)} det-uncertain -> {dict(rc)}")
u=sum(tot_unc.values())
print(f"  TOTAL uncertain={u} -> {dict(tot_unc)}")
if u:
    for k in ('clean','fabricated','pseudo-prose','contradictory',None):
        if k in tot_unc: print(f"    {str(k):14} {tot_unc[k]:5} ({100*tot_unc[k]/u:.0f}%)")

print("\n--- haiku_confidence distribution (combined) ---")
cc=Counter()
for chip in ['pilot','c6-02','c6-03']:
    d=json.load(open(f'fork/lora/corpus-labels/3.1.3-2026-05-16-{chip}.haiku.json'))
    for r in d['records']: cc[r.get('haiku_confidence')]+=1
print(" ",dict(cc))
EOF
echo "== log tails =="
for c in pilot c6-02 c6-03; do echo "--- $c ---"; cat "/tmp/haiku-$c.log" 2>/dev/null | tail -3; done
