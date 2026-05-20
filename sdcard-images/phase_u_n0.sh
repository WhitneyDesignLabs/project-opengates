#!/bin/bash
# Phase 3.3.1b N0: drop captured examples whose assistant msg has >=2
# tool_calls. Filter captured.jsonl AND captured.meta.jsonl in lockstep
# (parallel order must stay aligned for the N2 split meta sidecars).
set -u
cd /mnt/c/Users/homet/Documents/WireClaw/bench || exit 2
python3 - <<'EOF'
import json
TD='fork/lora/training-data'
J=f'{TD}/wireclaw-v1-captured.jsonl'
M=f'{TD}/wireclaw-v1-captured.meta.jsonl'
ex=[json.loads(l) for l in open(J,encoding='utf-8')]
mt=[json.loads(l) for l in open(M,encoding='utf-8')]
assert len(ex)==len(mt), f"len mismatch {len(ex)} vs {len(mt)}"

def keep(e):
    a=e['messages'][-1]
    return a.get('role')=='assistant' and len(a.get('tool_calls',[]) or [])<=1

before=len(ex)
pairs=[(e,m) for e,m in zip(ex,mt) if keep(e)]
after=len(pairs)
with open(J,'w',encoding='utf-8') as f:
    for e,_ in pairs: f.write(json.dumps(e,ensure_ascii=False)+"\n")
with open(M,'w',encoding='utf-8') as f:
    for _,m in pairs: f.write(json.dumps(m,ensure_ascii=False)+"\n")
# verify zero multi-tool remain
mt_left=sum(1 for e,_ in pairs if len(e['messages'][-1].get('tool_calls',[]) or [])>1)
print(f"Captured: {before} -> {after} (dropped {before-after} multi-tool)")
print(f"multi-tool remaining in captured: {mt_left} (must be 0)")
EOF
