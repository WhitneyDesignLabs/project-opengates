#!/bin/bash
# Phase 3.2 N5: render one captured + one synthetic val example through the
# Llama 3.1 chat template (NousResearch ungated mirror).
set -u
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 -c "import transformers" 2>/dev/null || {
  echo "installing transformers..."; python3 -m pip install --quiet --user transformers 2>&1 | tail -2; }
python3 - <<'EOF'
import json
TD='fork/lora/training-data'
val=[json.loads(l) for l in open(f'{TD}/wireclaw-v1-val.jsonl',encoding='utf-8')]
meta=[json.loads(l) for l in open(f'{TD}/wireclaw-v1-val.meta.jsonl',encoding='utf-8')]
cap=next(v for v,m in zip(val,meta) if m['source']=='captured')
syn=next(v for v,m in zip(val,meta) if m['source'].startswith('synthetic'))

from transformers import AutoTokenizer
tok=None
for mid in ("meta-llama/Llama-3.1-8B-Instruct","NousResearch/Meta-Llama-3.1-8B-Instruct"):
    try:
        tok=AutoTokenizer.from_pretrained(mid); print("tokenizer:",mid); break
    except Exception as e:
        print(f"  {mid} failed: {str(e)[:120]}")
if tok is None:
    raise SystemExit("FATAL: no Llama 3.1 tokenizer available")

for tag,ex in (("CAPTURED",cap),("SYNTHETIC",syn)):
    print("\n"+"="*72+f"\n{tag} — rendered via apply_chat_template\n"+"="*72)
    try:
        r=tok.apply_chat_template(ex['messages'],tokenize=False,
                                  tools=None, add_generation_prompt=False)
    except Exception as e:
        print(f"render error (retry without tools kw): {str(e)[:160]}")
        r=tok.apply_chat_template(ex['messages'],tokenize=False)
    # show head+tail so the system block doesn't drown the assistant/tool part
    print(r[:1100])
    print("   ... [system constitution elided] ...")
    print(r[-1400:])
    ntok=len(tok.apply_chat_template(ex['messages'],tokenize=True))
    print(f"\n[{tag} token length = {ntok}]")
EOF
