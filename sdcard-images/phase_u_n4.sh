#!/bin/bash
set -u
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import json,datetime,collections
TD='fork/lora/training-data'; p=f'{TD}/manifest.json'; m=json.load(open(p))
cap=sum(1 for _ in open(f'{TD}/wireclaw-v1-captured.jsonl',encoding='utf-8'))
syn=sum(1 for _ in open(f'{TD}/wireclaw-v1-synthetic.jsonl',encoding='utf-8'))
tr =sum(1 for _ in open(f'{TD}/wireclaw-v1-train.jsonl',encoding='utf-8'))
va =sum(1 for _ in open(f'{TD}/wireclaw-v1-val.jsonl',encoding='utf-8'))
capm=[json.loads(l) for l in open(f'{TD}/wireclaw-v1-captured.meta.jsonl',encoding='utf-8')]
pers=collections.Counter(x['persona'] for x in capm); chip=collections.Counter(x['chip'] for x in capm); n=cap
m['build_date']=datetime.datetime.now().astimezone().isoformat()
m['total_examples']=cap+syn; m['captured_examples']=cap; m['synthetic_examples']=syn
m['train_examples']=tr; m['val_examples']=va
m['persona_distribution']={k:f"{v} ({100*v/n:.1f}%)" for k,v in pers.most_common()}
m['chip_distribution']={k:f"{v} ({100*v/n:.1f}%)" for k,v in chip.most_common()}
m['multi_tool_fix']={
 "captured_dropped":16,
 "synthetic_constraint":"at most one tool_call per assistant message",
 "synthetic_regenerated_count":syn,
 "rationale":("Llama 3.1 chat template rejects multi-tool assistant messages. "
   "Captured multi-tool records are merge_corpus.py artifacts of sequential "
   "chip-side tool-loop; LLM doesn't actually emit multi-tool single-shot. "
   "Single-tool training preserves multi-tool inference behavior via Ollama "
   "tool-loop chaining.")}
m['tool_render_validation']={
 "tokenizer":"meta-llama/Llama-3.1-8B-Instruct (authed)",
 "all_4_types":"render OK, zero TemplateError (post multi-tool fix)",
 "rendered_tool_shape":'{"name": <tool>, "parameters": "<json-string of args>"}',
 "max_tokens_full_set":1321,"over_3072_brev":0,"over_2048_kscale":0}
# refresh caveats: drop the prior BLOCKER line, add resolved note
m['methodology_caveats']=[c for c in m['methodology_caveats']
    if not c.startswith("BLOCKER (Phase 3.3.1 N3")]
m['methodology_caveats'].append(
 "RESOLVED (Phase 3.3.1b): multi-tool blocker fixed — 16 captured multi-tool "
 "turns dropped, synthetic regenerated with <=1 tool_call. All 4 render types "
 "validated via real meta-llama template, 0 TemplateError, max 1321 tok "
 "(under both 3072/2048 caps).")
json.dump(m,open(p,'w'),indent=2)
print(f"manifest: total={cap+syn} cap={cap} syn={syn} train={tr} val={va}")
print("multi_tool_fix + tool_render_validation written; caveats:",len(m['methodology_caveats']))
EOF
