#!/bin/bash
# Phase 3.3.3b N1+N2: rebuild Modelfile (drop only `# SOUL-CHIP` line),
# re-ollama create wireclaw-agent:v1.1 (clean overwrite).
set -u
A="ssh -o BatchMode=yes -o ConnectTimeout=12 azza@192.168.1.60"
$A 'bash -s' <<'REMOTE' 2>&1
set -u
python3 - <<'PY'
soul=open('/home/azza/SOUL-CHIP.md').read()
clean='\n'.join(l for l in soul.split('\n') if not l.startswith('# SOUL-CHIP')).strip()
mf=f'''# wireclaw-agent v1.1 — first LoRA-tuned generation (3.3.3b OPERATIONAL fix)
# Base: meta-llama/Llama-3.1-8B-Instruct (via Ollama llama3.1:8b)
# Adapter: /home/azza/wireclaw-agent-v1.1.adapter.gguf (v2 training, Brev H100)
# Training: 845 ex (665 captured + 90 v1 + 90 v2 synthetic)
# Built: 2026-05-17
# Constitution: SOUL-CHIP.md (IDENTITY + OPERATIONAL + 15 articles, <4095B)

FROM llama3.1:8b
ADAPTER /home/azza/wireclaw-agent-v1.1.adapter.gguf

PARAMETER temperature 0.5
PARAMETER num_ctx 12288
PARAMETER stop <|eot_id|>

SYSTEM """
{clean}
"""
'''
open('/home/azza/wireclaw-agent-v1.1.Modelfile','w').write(mf)
print("Modelfile bytes:",len(mf))
PY
echo "== SYSTEM section markers in Modelfile =="
grep -nE '^# (IDENTITY|OPERATIONAL|CONSTITUTION)' ~/wireclaw-agent-v1.1.Modelfile
echo -n "article lines: "; grep -cE '^[0-9]+ ' ~/wireclaw-agent-v1.1.Modelfile
echo "== ollama create (clean overwrite) =="
ollama create wireclaw-agent:v1.1 -f ~/wireclaw-agent-v1.1.Modelfile 2>&1 | tail -4
echo "== ollama show — system (OPERATIONAL must appear) =="
ollama show wireclaw-agent:v1.1 2>&1 | grep -A2 -iE 'OPERATIONAL|Memory:|IDENTITY' | head -20
echo "== ollama list wireclaw =="
ollama list | grep -E '^NAME|wireclaw'
REMOTE
