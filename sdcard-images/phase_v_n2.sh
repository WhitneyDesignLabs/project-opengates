#!/bin/bash
# Phase 3.3.1c N2: combine captured + v1-synth + v2-synth -> v2 bundle.
# Sanity: every system msg == new SOUL-LOCAL. Stratified 90/10 (seed=42):
# val covers 7 personas + 11 v1 articles + 3 v2 batches (A/B/C).
set -u
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import json, random
from collections import Counter, defaultdict
TD='fork/lora/training-data'; random.seed(42)
SYS=("\n".join(l for l in open(f'{TD}/constitution/SOUL-LOCAL.md',encoding='utf-8').read().splitlines()
                if not l.startswith("# "))).strip()
def rd(p): return [json.loads(l) for l in open(p,encoding='utf-8')]

cap=rd(f'{TD}/wireclaw-v1-captured.jsonl');  capm=rd(f'{TD}/wireclaw-v1-captured.meta.jsonl')
s1 =rd(f'{TD}/wireclaw-v1-synthetic.jsonl'); s1m=rd(f'{TD}/wireclaw-v1-synthetic.meta.jsonl')
s2 =rd(f'{TD}/wireclaw-v1-synthetic-v2.jsonl'); s2m=rd(f'{TD}/wireclaw-v1-synthetic-v2.meta.jsonl')
assert len(cap)==len(capm) and len(s1)==len(s1m) and len(s2)==len(s2m)

def norm_v2(src):  # -> batchA / batchB / batchC
    if 'batchA' in src: return 'synthetic-v2-batchA'
    if 'batchB' in src: return 'synthetic-v2-batchB'
    return 'synthetic-v2-batchC'

recs=[]
for e,m in zip(cap,capm):
    recs.append({"ex":e,"meta":{"id":m["id"],"persona":m["persona"],"chip":m["chip"],
                                "source":"captured"},"strat":("cap",m["persona"])})
for e,m in zip(s1,s1m):
    art=str(m.get("article"))
    recs.append({"ex":e,"meta":{"id":f"synthetic-v1-art{art}-{m.get('index')}","persona":None,
                                "chip":None,"source":f"synthetic-v1-art{art}"},
                 "strat":("s1",art)})
for i,(e,m) in enumerate(zip(s2,s2m)):
    src=norm_v2(m["source"])
    recs.append({"ex":e,"meta":{"id":f"{src}-{i}","persona":None,"chip":None,
                                "source":src},"strat":("s2",src)})

# Sanity: all system messages equal new SOUL-LOCAL
bad=[r for r in recs if r["ex"]["messages"][0]["content"]!=SYS]
print(f"total={len(recs)} | system!=SOUL-LOCAL mismatches={len(bad)} (must be 0)")
if bad: raise SystemExit("ABORT: system-message mismatch")

# Stratified 90/10: for each strat-group put ~10% (>=1) into val
groups=defaultdict(list)
for r in recs: groups[r["strat"]].append(r)
val=[]; train=[]
for g,lst in groups.items():
    random.shuffle(lst)
    k=max(1,round(0.1*len(lst)))
    val+=lst[:k]; train+=lst[k:]
random.shuffle(train); random.shuffle(val)

# Coverage asserts
vp={r["meta"]["persona"] for r in val if r["meta"]["source"]=="captured"}
ap={r["meta"]["persona"] for r in recs if r["meta"]["source"]=="captured"}
v_s1={r["meta"]["source"] for r in val if r["meta"]["source"].startswith("synthetic-v1")}
a_s1={r["meta"]["source"] for r in recs if r["meta"]["source"].startswith("synthetic-v1")}
v_s2={r["meta"]["source"] for r in val if r["meta"]["source"].startswith("synthetic-v2")}
for miss_set,label in [(ap-vp,"persona")]:
    for x in list(miss_set):
        mv=[r for r in train if r["meta"]["persona"]==x][:3]
        for r in mv: train.remove(r); val.append(r)
    if miss_set: random.shuffle(val); vp|=miss_set

def w(p,rs,k):
    with open(p,'w',encoding='utf-8') as f:
        for r in rs: f.write(json.dumps(r[k],ensure_ascii=False)+"\n")
w(f'{TD}/wireclaw-v2-train.jsonl',train,'ex')
w(f'{TD}/wireclaw-v2-val.jsonl',val,'ex')
w(f'{TD}/wireclaw-v2-train.meta.jsonl',train,'meta')
w(f'{TD}/wireclaw-v2-val.meta.jsonl',val,'meta')

print(f"train={len(train)} val={len(val)} total={len(train)+len(val)}")
print(f"val captured personas {len(vp)}/7: {sorted(p for p in vp if p)}")
print(f"val v1 articles {len(v_s1)}/{len(a_s1)}: {sorted(int(s.split('art')[1]) for s in v_s1)}")
print(f"val v2 batches {len(v_s2)}/3: {sorted(v_s2)}")
print("val source mix:", dict(Counter(r['meta']['source'].split('-art')[0] for r in val)))
print("train source mix:", dict(Counter(r['meta']['source'].split('-art')[0] for r in train)))
for nm in ['train','val']:
    a=rd(f'{TD}/wireclaw-v2-{nm}.jsonl'); b=rd(f'{TD}/wireclaw-v2-{nm}.meta.jsonl')
    assert len(a)==len(b)
print("jsonl<->meta parity: OK")
miss=[]
if len(vp & ap)!=len(ap): miss.append("persona")
if v_s1!=a_s1: miss.append("v1-articles")
if len(v_s2)!=3: miss.append("v2-batches")
print("COVERAGE:", "ALL PASS" if not miss else f"MISSING {miss}")
EOF
