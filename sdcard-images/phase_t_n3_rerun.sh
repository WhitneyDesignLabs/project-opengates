#!/bin/bash
# Phase 3.3.1 N3 (re-run): load HF_TOKEN, validate format with the REAL
# tool-aware meta-llama Llama 3.1 tokenizer. 4 example types.
set -u
SEC=/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt
# Scott's method (tolerate non-shell lines in the secrets file):
set -a; . "$SEC" 2>/dev/null || true; set +a
# Fallback: grep the token if sourcing didn't set it.
if [ -z "${HF_TOKEN:-}" ]; then
  HF_TOKEN="$(grep -oE 'hf_[A-Za-z0-9]{20,}' "$SEC" | head -1)"
  export HF_TOKEN
fi
export HUGGING_FACE_HUB_TOKEN="${HF_TOKEN:-}"
echo "HF_TOKEN: ${HF_TOKEN:0:6}… (len ${#HF_TOKEN})"
[ -z "${HF_TOKEN:-}" ] && { echo "FATAL: HF_TOKEN still empty"; exit 2; }
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2

python3 - <<'EOF'
import json
from transformers import AutoTokenizer
TD='fork/lora/training-data'
tok=AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")
print("TOKENIZER: meta-llama/Llama-3.1-8B-Instruct (gated, authed OK)")
ct=tok.chat_template or ""
print("chat_template tool-aware? tool_calls=%s python_tag=%s ipython=%s"
      % ('tool_calls' in ct, 'python_tag' in ct, 'ipython' in ct))

val=[json.loads(l) for l in open(f'{TD}/wireclaw-v1-val.jsonl',encoding='utf-8')]
meta=[json.loads(l) for l in open(f'{TD}/wireclaw-v1-val.meta.jsonl',encoding='utf-8')]
def pick(is_syn_want, tools_want):
    for e,mt in zip(val,meta):
        is_syn=mt['source'].startswith('synthetic')
        has=bool(e['messages'][-1].get('tool_calls'))
        if is_syn==is_syn_want and has==tools_want: return e,mt
    return None,None
cases=[("CAPTURED + tools",False,True),
       ("CAPTURED - no tools",False,False),
       ("SYNTHETIC + tools",True,True),
       ("SYNTHETIC - no tools",True,False)]
allok=True
for name,sy,tl in cases:
    e,mt=pick(sy,tl)
    if e is None:
        print(f"\n#### {name}: no matching val example"); continue
    r=tok.apply_chat_template(e['messages'],tokenize=False)
    ids=tok.apply_chat_template(e['messages'],tokenize=True)
    am=e['messages'][-1]
    tcn=[c['function']['name'] for c in am.get('tool_calls',[])]
    print(f"\n################ {name}  (src={mt['source']})  tokens={len(ids)} ################")
    if tcn:
        names_in=all(t in r for t in tcn)
        pt='<|python_tag|>' in r
        print(f"expected tool_calls={tcn} | names_in_render={names_in} | python_tag={pt}")
        if not names_in: allok=False
    print("---- HEAD 380 ----"); print(r[:380])
    print("---- TAIL 900 ----"); print(r[-900:])
print("\n==== VERDICT:", "tool_calls RENDER OK (names present)" if allok
      else "TOOL_CALLS PROBLEM — see above", "====")
EOF
