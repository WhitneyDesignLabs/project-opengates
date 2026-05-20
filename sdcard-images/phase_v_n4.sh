#!/bin/bash
# Phase 3.3.1c N4: token-cap recheck (bigger SOUL-LOCAL) + manifest v2_patch.
set -u
SEC=/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt
set -a; . "$SEC" 2>/dev/null || true; set +a
[ -z "${HF_TOKEN:-}" ] && export HF_TOKEN="$(grep -oE 'hf_[A-Za-z0-9]{20,}' "$SEC" | head -1)"
export HUGGING_FACE_HUB_TOKEN="${HF_TOKEN}"
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import json, datetime, collections
from transformers import AutoTokenizer
TD='fork/lora/training-data'
tok=AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")
mx=0; o3072=0; rerr=0
for fn in ['wireclaw-v2-train.jsonl','wireclaw-v2-val.jsonl']:
    for l in open(f'{TD}/{fn}',encoding='utf-8'):
        e=json.loads(l)
        try:
            n=len(tok.encode(tok.apply_chat_template(e['messages'],tokenize=False)))
        except Exception: rerr+=1; continue
        mx=max(mx,n); o3072+=n>3072
print(f"v2 token stats: max={mx}  >3072(Brev cap)={o3072}  render_errors={rerr}")

cap=sum(1 for _ in open(f'{TD}/wireclaw-v1-captured.jsonl',encoding='utf-8'))
s1=sum(1 for _ in open(f'{TD}/wireclaw-v1-synthetic.jsonl',encoding='utf-8'))
s2=sum(1 for _ in open(f'{TD}/wireclaw-v1-synthetic-v2.jsonl',encoding='utf-8'))
tr=sum(1 for _ in open(f'{TD}/wireclaw-v2-train.jsonl',encoding='utf-8'))
va=sum(1 for _ in open(f'{TD}/wireclaw-v2-val.jsonl',encoding='utf-8'))
s2src=collections.Counter()
for l in open(f'{TD}/wireclaw-v1-synthetic-v2.meta.jsonl',encoding='utf-8'):
    s=json.loads(l)['source']
    s2src['A' if 'batchA' in s else 'B' if 'batchB' in s else 'C']+=1

p=f'{TD}/manifest.json'; m=json.load(open(p))
m['build_date']=datetime.datetime.now().astimezone().isoformat()
m['total_examples']=cap+s1+s2
m['train_examples']=tr; m['val_examples']=va
m['v2_patch']={
 "rationale":"v1.1 smoke test revealed identity drift, Article 3 citation hallucination, and memory-chain skip-read. v1.2 fixes via IDENTITY preamble in SOUL-LOCAL/SOUL-CHIP + ~90 targeted synthetic examples.",
 "constitution_change":"Added IDENTITY preamble to both SOUL-LOCAL.md (5,829 -> 6,522 bytes) and SOUL-CHIP.md (3,069 -> 3,581 bytes). All training examples re-tokenized with new SOUL-LOCAL.md as system message.",
 "synthetic_v2_batches":{"identity":15,"refusal_with_citation":40,"memory_chain_first_step":35},
 "synthetic_v2_total":s2,
 "captured_examples":cap,"synthetic_v1_examples":s1,
 "total_examples":cap+s1+s2,"train_examples":tr,"val_examples":va,
 "max_token_len":mx,"over_3072_cap":o3072,
 "brev_yaml":"updated to /home/ubuntu/... v2 paths; attn_impl set to sdpa per 3.3.1c directive (3.3.1 file had flash_attention_2 — flagged)",
}
json.dump(m,open(p,'w'),indent=2)
print("manifest v2_patch written. total",cap+s1+s2,"train",tr,"val",va,"| s2 batches",dict(s2src))
EOF
