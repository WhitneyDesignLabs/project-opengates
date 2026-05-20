#!/bin/bash
# Phase 3.2 steps 3-5, N1+N2: build filtered clean pool + persona-balance audit.
set -u
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
mkdir -p fork/lora/training-data
python3 - <<'EOF'
import json, re, sys, glob, os
from collections import Counter, defaultdict
sys.path.insert(0,'fork/lora')
import merge_corpus as mc

RAW='fork/lora/corpus-raw'; LBL='fork/lora/corpus-labels'
OUT='fork/lora/training-data/clean-pool.jsonl'
CHIPS=['pilot','c6-02','c6-03']

def norm(s): return " ".join((s or "").split()).lower()
p2p={}
for i in range(1,8):
    f=glob.glob(f'fork/lora/personas/persona_{i:02d}_*.py')[0]
    m=mc.load_persona(os.path.basename(f)[:-3]); pid=getattr(m,'PERSONA_ID',None)
    for p in getattr(m,'PROMPTS',[]):
        t=norm(getattr(p,'text',''))
        if t: p2p.setdefault(t,pid)

TS=re.compile(r'(\d{8}T\d{6})')
def ts_of(s):
    m=TS.search(s or ''); return m.group(1) if m else None

# Per-chip max ts -> wedge cutoff (last 60 min) for c6-02 / c6-03 only.
maxts={}
for chip in CHIPS:
    raw=json.load(open(f'{RAW}/3.1.3-2026-05-16-{chip}.json'))['conversations']
    ts=[ts_of(c.get('id','')) for c in raw]; ts=[t for t in ts if t]
    maxts[chip]=max(ts) if ts else None
from datetime import datetime, timedelta
def wedge_cut(chip):
    if chip=='pilot' or not maxts.get(chip): return None
    end=datetime.strptime(maxts[chip],'%Y%m%dT%H%M%S')
    return (end - timedelta(minutes=60)).strftime('%Y%m%dT%H%M%S')
cuts={c:wedge_cut(c) for c in CHIPS}
print("per-chip capture end / wedge-cutoff (exclude ts > cutoff for c6-02/c6-03):")
for c in CHIPS: print(f"  {c}: end={maxts[c]} cutoff={cuts[c]}")

kept=[]; drop=Counter(); seen=0
for chip in CHIPS:
    R=json.load(open(f'{LBL}/3.1.3-2026-05-16-{chip}.haiku.json'))['records']
    raw=json.load(open(f'{RAW}/3.1.3-2026-05-16-{chip}.json'))['conversations']
    if len(R)!=len(raw): print(f"  WARN {chip}: {len(R)} records vs {len(raw)} convs")
    for i,r in enumerate(R):
        seen+=1
        c=raw[i] if i<len(raw) else {}
        if r.get('final_label')!='clean': drop['non_clean_label']+=1; continue
        resp=c.get('wrap_up_text')
        if not (resp and str(resp).strip()): drop['empty_response']+=1; continue
        tcs=c.get('tool_calls_fired');
        if tcs is None: tcs=c.get('tool_calls_fired_iter1')
        if tcs is None: drop['missing_tool_calls_field']+=1; continue
        cut=cuts.get(chip); t=ts_of(c.get('id',''))
        if cut and t and t>cut: drop['wedge_window']+=1; continue
        kept.append({
            "id": f"{chip}:{i}:0",
            "chip": chip,
            "persona": p2p.get(norm(c.get('prompt','')),'unknown'),
            "prompt": c.get('prompt',''),
            "response": resp,
            "tool_calls": tcs or [],
            "haiku_label": "clean",
            "source": "3.1.3-v2",
        })

with open(OUT,'w',encoding='utf-8') as f:
    for t in kept: f.write(json.dumps(t,ensure_ascii=False)+"\n")

print(f"\n=== N1: clean-pool.jsonl ===")
print(f"seen={seen}  KEPT={len(kept)}")
print("drop counts:", dict(drop))
print("ballpark check: 800-1000 expected ->", "OK" if 500<=len(kept)<=1500 else "OUT OF RANGE - STOP/ASK")

print("\n=== N2: persona-balance audit (report only, NO resampling) ===")
bp=Counter(t['persona'] for t in kept); n=len(kept)
print(f"{'persona':<20}{'count':>7}{'pct':>8}")
for p,ct in bp.most_common():
    print(f"{p:<20}{ct:>7}{100*ct/n:>7.1f}%   {'<5% FLAG' if 100*ct/n<5 else ''}")
print("\nper-persona x per-chip:")
xt=defaultdict(Counter)
for t in kept: xt[t['persona']][t['chip']]+=1
print(f"{'persona':<20}{'pilot':>7}{'c6-02':>7}{'c6-03':>7}")
for p in sorted(xt):
    print(f"{p:<20}{xt[p]['pilot']:>7}{xt[p]['c6-02']:>7}{xt[p]['c6-03']:>7}")
print("\nchip distribution:", dict(Counter(t['chip'] for t in kept)))
EOF
