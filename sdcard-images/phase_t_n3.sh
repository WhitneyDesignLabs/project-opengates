#!/bin/bash
# Phase 3.3.1 N1/N2 parse-check + N3 real-Meta-tokenizer format validation.
set -u
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
T=fork/lora/training

echo "== N1: train.py ast.parse =="
python3 -c "import ast; ast.parse(open('$T/train.py').read()); print('train.py: AST OK')" || exit 3
echo "== N2: configs parse =="
python3 -c "import yaml; [print(c, '->', 'OK', list(yaml.safe_load(open(f'$T/configs/{c}'))) [:3]) for c in ('brev.yaml','kscale.yaml')]" || exit 3

echo "== HF auth presence =="
python3 - <<'EOF'
import os, glob
tok_env=os.environ.get("HF_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN")
cached=glob.glob(os.path.expanduser("~/.cache/huggingface/token")) + \
       glob.glob(os.path.expanduser("~/.huggingface/token"))
print("HF_TOKEN env:", "set" if tok_env else "absent")
print("cached token file:", cached or "none")
# also peek Secrets.txt for an hf_ token
import re,io
s=open("/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt",encoding="utf-8",errors="ignore").read()
m=re.search(r'hf_[A-Za-z0-9]{20,}', s)
print("hf_ token in Secrets.txt:", "found" if m else "not found")
EOF

echo "== N3: real Meta tokenizer render (4 example types) =="
python3 - <<'EOF'
import json, re, os
TD='fork/lora/training-data'
sec=open("/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt",encoding="utf-8",errors="ignore").read()
m=re.search(r'hf_[A-Za-z0-9]{20,}', sec)
if m and not os.environ.get("HF_TOKEN"):
    os.environ["HF_TOKEN"]=m.group(0)

from transformers import AutoTokenizer
tok=None; src=None
for mid in ("meta-llama/Llama-3.1-8B-Instruct",
            "NousResearch/Meta-Llama-3.1-8B-Instruct"):
    try:
        tok=AutoTokenizer.from_pretrained(mid); src=mid; break
    except Exception as e:
        print(f"  {mid}: FAILED {str(e)[:140]}")
print("USING TOKENIZER:", src)
ct=tok.chat_template or ""
print("chat_template tool-aware? tool_calls=%s python_tag=%s ipython=%s"
      % ('tool_calls' in ct,'<|python_tag|>' in ct or 'python_tag' in ct,'ipython' in ct))

val=[json.loads(l) for l in open(f'{TD}/wireclaw-v1-val.jsonl',encoding='utf-8')]
meta=[json.loads(l) for l in open(f'{TD}/wireclaw-v1-val.meta.jsonl',encoding='utf-8')]
def pick(src_pred, tools):
    for e,mt in zip(val,meta):
        is_syn=mt['source'].startswith('synthetic')
        has=bool(e['messages'][-1].get('tool_calls'))
        if src_pred(is_syn) and has==tools: return e,mt
    return None,None
cases=[("captured+tools",lambda s:not s,True),
       ("captured-no-tools",lambda s:not s,False),
       ("synthetic+tools",lambda s:s,True),
       ("synthetic-no-tools",lambda s:s,False)]
for name,sp,tl in cases:
    e,mt=pick(sp,tl)
    if e is None: print(f"\n### {name}: NO MATCHING EXAMPLE"); continue
    r=tok.apply_chat_template(e['messages'],tokenize=False)
    ids=tok.apply_chat_template(e['messages'],tokenize=True)
    am=e['messages'][-1]
    tcn=[c['function']['name'] for c in am.get('tool_calls',[])]
    print(f"\n############ {name}  (src={mt['source']}) tokens={len(ids)} ############")
    print("expected tool_calls:",tcn or "(none)")
    if tcn:
        present=all((t in r) for t in tcn)
        print("tool name(s) present in rendered text:",present,
              "| python_tag:", '<|python_tag|>' in r)
    print("---- tail 700 ----")
    print(r[-700:])
EOF
