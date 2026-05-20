#!/bin/bash
# Phase 3.2 step 1b N5: stratified hand-label sample (JSON + MD).
# Stratify by HAIKU_LABEL (Scott's calibration target, per Cowork refinement).
# clean 15 (5/chip), pseudo-prose 10 (4/3/3), fabricated 15 (5/chip),
# contradictory ALL. seed=42. Haiku label/rationale = Haiku-alone (every turn).
set -u
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import json, random, sys, glob, os
from collections import defaultdict
sys.path.insert(0,'fork/lora')
import merge_corpus as mc
random.seed(42)

RAW='fork/lora/corpus-raw'; LBL='fork/lora/corpus-labels'
OUTJ='fork/lora/corpus-labels/3.1.3-handlabel-sample-v1.json'
OUTM='fork/lora/corpus-labels/3.1.3-handlabel-sample-v1.md'
CHIPS=['pilot','c6-02','c6-03']

def norm(s): return " ".join((s or "").split()).lower()
p2p={}
for i in range(1,8):
    f=glob.glob(f'fork/lora/personas/persona_{i:02d}_*.py')[0]
    m=mc.load_persona(os.path.basename(f)[:-3]); pid=getattr(m,'PERSONA_ID',None)
    for p in getattr(m,'PROMPTS',[]):
        t=norm(getattr(p,'text',''));
        if t: p2p.setdefault(t,pid)

# Collect candidates per (chip, haiku_label)
cells=defaultdict(list)
for chip in CHIPS:
    R=json.load(open(f'{LBL}/3.1.3-2026-05-16-{chip}.haiku.json'))['records']
    raw=json.load(open(f'{RAW}/3.1.3-2026-05-16-{chip}.json'))['conversations']
    for i,r in enumerate(R):
        c=raw[i] if i<len(raw) else {}
        hl=r.get('haiku_label')
        if hl is None: continue
        tc=c.get('tool_calls_fired') or c.get('tool_calls_fired_iter1') or []
        cells[(chip,hl)].append({
            "id": f"{chip}:{i}",
            "orig_id": r.get('id',''),
            "chip": chip,
            "persona": p2p.get(norm(c.get('prompt','')),'unknown'),
            "prompt": c.get('prompt',''),
            "response": c.get('wrap_up_text',''),
            "tool_calls": tc,
            "haiku_label": hl,
            "haiku_rationale": r.get('haiku_rationale',''),
            "deterministic_label": r.get('deterministic_label'),
            "final_label": r.get('final_label'),
            "scott_label": None,
            "scott_notes": None,
        })

PLAN={'clean':{'pilot':5,'c6-02':5,'c6-03':5},
      'pseudo-prose':{'pilot':4,'c6-02':3,'c6-03':3},
      'fabricated':{'pilot':5,'c6-02':5,'c6-03':5}}
sample=[]; report=[]
for lab,per in PLAN.items():
    for chip,k in per.items():
        pool=cells.get((chip,lab),[])
        take=random.sample(pool,min(k,len(pool)))
        sample+=take
        report.append(f"{lab}/{chip}: requested {k}, pool {len(pool)}, took {len(take)}")
# contradictory: ALL across chips
for chip in CHIPS:
    pool=cells.get((chip,'contradictory'),[])
    sample+=pool
    report.append(f"contradictory/{chip}: ALL ({len(pool)})")

random.shuffle(sample)
json.dump({"source":"3.1.3-v2 (demoted-det + Haiku)","seed":42,
           "calibration_target":"haiku_label","n":len(sample),"turns":sample},
          open(OUTJ,'w'), indent=2)

with open(OUTM,'w') as f:
    f.write("# 3.1.3 Hand-Label Sample v1 (Phase 3.2 step 2 input)\n\n")
    f.write(f"{len(sample)} turns. Calibrate **scott_label** against **haiku_label**. "
            "`final_label` is the merged-stack label (posterity only).\n\n")
    f.write("Classes: clean | pseudo-prose | fabricated | contradictory\n\n---\n\n")
    for n,t in enumerate(sample,1):
        f.write(f"## {n}. `{t['id']}`  (persona: {t['persona']}, chip: {t['chip']})\n\n")
        f.write(f"**Prompt:** {t['prompt']}\n\n")
        f.write(f"**Response:** {t['response']}\n\n")
        tcs=t['tool_calls']
        if tcs:
            f.write("**Tool calls:**\n")
            for tc in tcs:
                fn=tc.get('function'); fn=fn.get('name') if isinstance(fn,dict) else fn
                f.write(f"- `{fn}({json.dumps(tc.get('arguments',{}))})`"
                        f"{' -> '+str(tc.get('result'))[:160] if tc.get('result') else ''}\n")
            f.write("\n")
        f.write(f"**Haiku said:** `{t['haiku_label']}` — {t['haiku_rationale']}\n\n")
        f.write(f"**Scott's label:** ____________  (clean / pseudo-prose / fabricated / contradictory)\n\n")
        f.write(f"**Scott's notes:** \n\n---\n\n")

print("WROTE", OUTJ, "and", OUTM)
print("sample size:", len(sample))
from collections import Counter
print("by haiku_label:", dict(Counter(t['haiku_label'] for t in sample)))
print("by chip:", dict(Counter(t['chip'] for t in sample)))
print("by persona:", dict(Counter(t['persona'] for t in sample)))
print("\nsampling report:")
for line in report: print("  ",line)
EOF
ls -la /mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus-labels/3.1.3-handlabel-sample-v1.*
