#!/bin/bash
# Phase 3.2 N4: combine captured+synthetic, stratified 90/10 split (seed=42),
# meta sidecars, val-coverage check (7 personas + 11 articles).
set -u
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import json, random
from collections import Counter, defaultdict
TD='fork/lora/training-data'
random.seed(42)

def rd(p): return [json.loads(l) for l in open(p,encoding='utf-8')]
cap   = rd(f'{TD}/wireclaw-v1-captured.jsonl')
capm  = rd(f'{TD}/wireclaw-v1-captured.meta.jsonl')
syn   = rd(f'{TD}/wireclaw-v1-synthetic.jsonl')
synm  = rd(f'{TD}/wireclaw-v1-synthetic.meta.jsonl')
assert len(cap)==len(capm) and len(syn)==len(synm), "meta length mismatch"

cap_recs=[{"ex":e,"meta":{"id":m["id"],"persona":m["persona"],"chip":m["chip"],"source":"captured"}}
          for e,m in zip(cap,capm)]
syn_recs=[{"ex":e,"meta":{"id":f"synthetic-art{m['article']}-{i}","persona":None,
                          "chip":None,"source":f"synthetic-art{m['article']}"}}
          for i,(e,m) in enumerate(zip(syn,synm))]

# Synthetic: stratify ~10% per article into val (>=1 each)
by_art=defaultdict(list)
for r in syn_recs: by_art[r['meta']['source']].append(r)
syn_val=[]; syn_train=[]
for art,lst in by_art.items():
    random.shuffle(lst)
    k=max(1,round(0.1*len(lst)))
    syn_val+=lst[:k]; syn_train+=lst[k:]

# Captured: random 90/10
random.shuffle(cap_recs)
n_cap_val=max(1,round(0.1*len(cap_recs)))
cap_val=cap_recs[:n_cap_val]; cap_train=cap_recs[n_cap_val:]

train=cap_train+syn_train; val=cap_val+syn_val
random.shuffle(train); random.shuffle(val)

# Coverage check: all 7 captured personas + 11 articles in val
val_personas={r['meta']['persona'] for r in val if r['meta']['source']=='captured'}
val_arts={r['meta']['source'] for r in val if r['meta']['source'].startswith('synthetic')}
all_personas={r['meta']['persona'] for r in cap_recs}
need_p=all_personas - val_personas
if need_p:
    for p in list(need_p):
        movers=[r for r in train if r['meta']['persona']==p][:3]
        for m in movers: train.remove(m); val.append(m)
    random.shuffle(val)
    val_personas|=need_p
ALL_ART={f"synthetic-art{n}" for n in ['5','6','8','9','10','11','17','21','22','23','24']}
missing_art=ALL_ART - val_arts  # should be empty (>=1/article forced)

def w(path,recs,key):
    with open(path,'w',encoding='utf-8') as f:
        for r in recs: f.write(json.dumps(r[key],ensure_ascii=False)+"\n")
w(f'{TD}/wireclaw-v1-train.jsonl',train,'ex')
w(f'{TD}/wireclaw-v1-val.jsonl',val,'ex')
w(f'{TD}/wireclaw-v1-train.meta.jsonl',train,'meta')
w(f'{TD}/wireclaw-v1-val.meta.jsonl',val,'meta')

print(f"total={len(train)+len(val)} (captured {len(cap)} + synthetic {len(syn)})")
print(f"train={len(train)}  val={len(val)}")
print(f"val captured personas ({len(val_personas)}/7): {sorted(p for p in val_personas if p)}")
print(f"val synthetic articles ({len(val_arts | (ALL_ART & set()))}/11 present): "
      f"{sorted(int(a.split('art')[1]) for a in val_arts)}")
print(f"missing articles in val: {missing_art or 'none'}")
print(f"persona-augmented into val: {need_p or 'none needed'}")
print("val source mix:", dict(Counter(r['meta']['source'].split('-art')[0] for r in val)))
print("train source mix:", dict(Counter(r['meta']['source'].split('-art')[0] for r in train)))
# order-consistency assert
for nm in ['train','val']:
    a=rd(f'{TD}/wireclaw-v1-{nm}.jsonl'); b=rd(f'{TD}/wireclaw-v1-{nm}.meta.jsonl')
    assert len(a)==len(b), f"{nm} jsonl/meta length mismatch"
print("jsonl<->meta length parity: OK")
EOF
