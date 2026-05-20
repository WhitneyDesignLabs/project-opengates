#!/bin/bash
# Phase 3.3.1b N3: re-validate 4 example types via real meta-llama template.
# Expect ZERO TemplateError (no multi-tool left). Real token counts via
# tok.encode(rendered_string) vs config caps (Brev 3072 / kscale 2048).
set -u
SEC=/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt
set -a; . "$SEC" 2>/dev/null || true; set +a
[ -z "${HF_TOKEN:-}" ] && export HF_TOKEN="$(grep -oE 'hf_[A-Za-z0-9]{20,}' "$SEC" | head -1)"
export HUGGING_FACE_HUB_TOKEN="${HF_TOKEN}"
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import json
from transformers import AutoTokenizer
TD='fork/lora/training-data'
tok=AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")
print("tokenizer: meta-llama/Llama-3.1-8B-Instruct (authed)  is_fast=",tok.is_fast)

val=[json.loads(l) for l in open(f'{TD}/wireclaw-v1-val.jsonl',encoding='utf-8')]
meta=[json.loads(l) for l in open(f'{TD}/wireclaw-v1-val.meta.jsonl',encoding='utf-8')]
def pick(sy,tl):
    for e,mt in zip(val,meta):
        s=mt['source'].startswith('synthetic'); h=bool(e['messages'][-1].get('tool_calls'))
        if s==sy and h==tl: return e,mt
    return None,None
cases=[("CAPTURED + tool",False,True),("CAPTURED - no tool",False,False),
       ("SYNTHETIC + tool",True,True),("SYNTHETIC - no tool",True,False)]
allok=True; maxtok=0
for name,sy,tl in cases:
    e,mt=pick(sy,tl)
    if e is None: print(f"\n#### {name}: none"); continue
    try:
        r=tok.apply_chat_template(e['messages'],tokenize=False)
    except Exception as ex:
        allok=False; print(f"\n#### {name}: RENDER ERROR {str(ex)[:140]}"); continue
    ntok=len(tok.encode(r))
    maxtok=max(maxtok,ntok)
    tcs=[c['function']['name'] for c in e['messages'][-1].get('tool_calls',[])]
    print(f"\n################ {name} (src={mt['source']}) tokens={ntok} tool_calls={tcs} ################")
    print(r[-560:])
# also: max token length across the FULL train+val (cap check)
mx=0; over3072=0; over2048=0
for fn in ['wireclaw-v1-train.jsonl','wireclaw-v1-val.jsonl']:
    for l in open(f'{TD}/{fn}',encoding='utf-8'):
        e=json.loads(l)
        n=len(tok.encode(tok.apply_chat_template(e['messages'],tokenize=False)))
        mx=max(mx,n); over3072+=n>3072; over2048+=n>2048
print(f"\n=== full-set token stats: max={mx}  >3072(Brev)={over3072}  >2048(kscale)={over2048} ===")
print("VERDICT:", "ALL RENDER OK, no TemplateError" if allok else "RENDER FAILURE - see above")
EOF
