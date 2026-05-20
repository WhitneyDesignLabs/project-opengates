#!/bin/bash
# Phase 3.2 step 1b N4: v2 label dist + V1->V2 delta + per-persona x label cross-tab.
# Persona recovered by matching each turn's prompt text (from corpus-raw, joined
# positionally to the .haiku.json records) against all 7 personas' PROMPTS.
set -u
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import json, sys
from collections import Counter, defaultdict
sys.path.insert(0, 'fork/lora')
import merge_corpus as mc

RAW='fork/lora/corpus-raw'
LBL='fork/lora/corpus-labels'
CHIPS=['pilot','c6-02','c6-03']

def norm(s): return " ".join((s or "").split()).lower()

# Build normalized-prompt -> persona_id map across all 7 personas.
prompt2persona={}
ambig=set()
for i in range(1,8):
    import glob, os
    f=glob.glob(f'fork/lora/personas/persona_{i:02d}_*.py')[0]
    n=os.path.basename(f)[:-3]
    m=mc.load_persona(n)
    pid=getattr(m,'PERSONA_ID',n)
    for p in getattr(m,'PROMPTS',[]):
        t=norm(getattr(p,'text',''))
        if not t: continue
        if t in prompt2persona and prompt2persona[t]!=pid:
            ambig.add(t)
        prompt2persona[t]=pid
print(f"persona prompt map: {len(prompt2persona)} unique texts, {len(ambig)} ambiguous (shared across personas)")

print("="*72)
print("V2 LABEL DISTRIBUTION (demoted deterministic + Haiku-trusted clean)")
print("="*72)
print(f"{'chip':<8}{'turns':>7}{'clean':>8}{'pp':>8}{'fab':>8}{'contr':>7}{'null':>6}{'det=win':>9}{'haiku=win':>10}{'h_err':>7}")
agg=Counter(); all_rec=[]
for chip in CHIPS:
    d=json.load(open(f'{LBL}/3.1.3-2026-05-16-{chip}.haiku.json'))
    R=d['records']
    raw=json.load(open(f'{RAW}/3.1.3-2026-05-16-{chip}.json'))['conversations']
    if len(R)!=len(raw):
        print(f"  WARN {chip}: records {len(R)} != conversations {len(raw)} (positional join unsafe)")
    for i,r in enumerate(R):
        r['_chip']=chip
        r['_prompt']= raw[i].get('prompt','') if i<len(raw) else ''
    all_rec+=R
    fin=Counter(r.get('final_label') for r in R)
    detwin=sum(1 for r in R if r.get('deterministic_label') in ('pseudo-prose','fabricated'))
    haikuwin=sum(1 for r in R if r.get('deterministic_label')=='null')
    herr=sum(1 for r in R if r.get('haiku_label') is None)
    for k,v in fin.items(): agg[k]+=v
    print(f"{chip:<8}{len(R):>7}{fin.get('clean',0):>8}{fin.get('pseudo-prose',0):>8}"
          f"{fin.get('fabricated',0):>8}{fin.get('contradictory',0):>7}{fin.get('null',0):>6}"
          f"{detwin:>9}{haikuwin:>10}{herr:>7}")
tot=sum(agg.values())
print(f"{'TOTAL':<8}{tot:>7}{agg.get('clean',0):>8}{agg.get('pseudo-prose',0):>8}"
      f"{agg.get('fabricated',0):>8}{agg.get('contradictory',0):>7}{agg.get('null',0):>6}")

print("\n"+"="*72)
print("V1 -> V2 DELTA (final_label, per chip)")
print("="*72)
for chip in CHIPS:
    v1=json.load(open(f'{LBL}/3.1.3-2026-05-16-{chip}.haiku.v1.json'))
    v2=json.load(open(f'{LBL}/3.1.3-2026-05-16-{chip}.haiku.json'))
    a=Counter(r.get('final_label') for r in v1['records'])
    b=Counter(r.get('final_label') for r in v2['records'])
    print(f"  {chip}:")
    for L in ['clean','pseudo-prose','fabricated','contradictory','uncertain','null']:
        if a.get(L,0) or b.get(L,0):
            print(f"    {L:<15}{a.get(L,0):>5} -> {b.get(L,0):>5}  ({b.get(L,0)-a.get(L,0):+d})")

print("\n"+"="*72)
print("PER-PERSONA x FINAL-LABEL CROSS-TAB (combined; persona via prompt-text match)")
print("="*72)
byp=defaultdict(Counter)
for r in all_rec:
    pid=prompt2persona.get(norm(r.get('_prompt','')),'UNMATCHED')
    byp[pid][r.get('final_label')]+=1
print(f"{'persona':<20}{'total':>7}{'clean':>8}{'pp':>7}{'fab':>8}{'contr':>7}{'null':>6}{'%clean':>8}")
for pid in sorted(byp):
    c=byp[pid]; t=sum(c.values()); pc=100*c.get('clean',0)/t if t else 0
    print(f"{pid:<20}{t:>7}{c.get('clean',0):>8}{c.get('pseudo-prose',0):>7}"
          f"{c.get('fabricated',0):>8}{c.get('contradictory',0):>7}{c.get('null',0):>6}{pc:>7.1f}%")
print("\n(UNMATCHED = follow-up/multi-turn prompts or ambiguity-tester reuse not "
      "verbatim in any persona PROMPTS list; expected to be large since most "
      "session turns are not the seed prompt.)")
EOF
