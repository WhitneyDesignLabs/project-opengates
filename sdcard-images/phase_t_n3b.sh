#!/bin/bash
# N3b: quantify multi-tool-call turns (Llama 3.1 template rejects >1 tc),
# and render the 4 example types catching the multi-tool error gracefully.
set -u
SEC=/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt
set -a; . "$SEC" 2>/dev/null || true; set +a
[ -z "${HF_TOKEN:-}" ] && export HF_TOKEN="$(grep -oE 'hf_[A-Za-z0-9]{20,}' "$SEC" | head -1)"
export HUGGING_FACE_HUB_TOKEN="${HF_TOKEN}"
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import json, collections
from transformers import AutoTokenizer
TD='fork/lora/training-data'
tok=AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")

def stats(path):
    n=tot_tc=multi=single=zero=0
    multi_by=collections.Counter()
    for l in open(path,encoding='utf-8'):
        e=json.loads(l); n+=1
        tcs=e['messages'][-1].get('tool_calls') or []
        if len(tcs)==0: zero+=1
        elif len(tcs)==1: single+=1
        else:
            multi+=1; multi_by[len(tcs)]+=1
    return n,zero,single,multi,dict(sorted(multi_by.items()))

for f in ['wireclaw-v1-train.jsonl','wireclaw-v1-val.jsonl',
          'wireclaw-v1-captured.jsonl','wireclaw-v1-synthetic.jsonl']:
    n,z,s,m,mb=stats(f'{TD}/{f}')
    print(f"{f:32} n={n:4} no-tool={z:4} single={s:4} MULTI={m:4} {mb}")

# Render 4 types; catch the multi-tool TemplateError.
val=[json.loads(l) for l in open(f'{TD}/wireclaw-v1-val.jsonl',encoding='utf-8')]
meta=[json.loads(l) for l in open(f'{TD}/wireclaw-v1-val.meta.jsonl',encoding='utf-8')]
def pick(sy,tl,multi=None):
    for e,mt in zip(val,meta):
        s=mt['source'].startswith('synthetic'); tcs=e['messages'][-1].get('tool_calls') or []
        if s==sy and bool(tcs)==tl and (multi is None or (len(tcs)>1)==multi):
            return e,mt
    return None,None
def show(tag,e,mt):
    if e is None: print(f"\n#### {tag}: none"); return
    try:
        r=tok.apply_chat_template(e['messages'],tokenize=False)
        tc=[c['function']['name'] for c in e['messages'][-1].get('tool_calls',[])]
        print(f"\n#### {tag} (src={mt['source']}) tool_calls={tc} -> RENDER OK")
        print(r[-520:])
    except Exception as ex:
        print(f"\n#### {tag} (src={mt['source']}) -> RENDER ERROR: {str(ex)[:130]}")
show("CAPTURED single-tool", *pick(False,True,multi=False))
show("CAPTURED no-tool", *pick(False,False))
show("CAPTURED MULTI-tool", *pick(False,True,multi=True))
show("SYNTHETIC single-tool", *pick(True,True,multi=False))
show("SYNTHETIC no-tool", *pick(True,False))
show("SYNTHETIC MULTI-tool", *pick(True,True,multi=True))
EOF
