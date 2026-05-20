#!/bin/bash
# Phase 3.3.3 N3: build ~/wireclaw-agent-v1.1.Modelfile on azza.
set -u
A="ssh -o BatchMode=yes -o ConnectTimeout=12 azza@192.168.1.60"
$A 'bash -s' <<'REMOTE' 2>&1
set -u
python3 - <<'PY'
soul=open('/home/azza/SOUL-CHIP.md').read()
META=['v0.2.0','canonical','distillation','full constitution',
      'identity preamble','chip-side runtime']
out=[]
for line in soul.split('\n'):
    s=line.strip().lower()
    if line.strip().startswith('# ') and any(m in s for m in META):
        continue                      # drop file-metadata comment lines
    out.append(line)
clean='\n'.join(out).strip()

mf=f'''# wireclaw-agent v1.1 — first LoRA-tuned generation
# Base: meta-llama/Llama-3.1-8B-Instruct (via Ollama's llama3.1:8b)
# Adapter: ~/wireclaw-agent-v1.1.adapter.gguf (v2 training on Brev H100)
# Training: 845 examples (665 captured + 90 v1 synthetic + 90 v2 synthetic
#           targeting identity / Article-3-citation / memory-chain fixes)
# Built: 2026-05-17
# Constitution: SOUL-CHIP.md (15 articles + IDENTITY preamble, <4095B chip limit)

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
echo "== head -16 =="
head -16 ~/wireclaw-agent-v1.1.Modelfile
echo "== wc -c =="
wc -c ~/wireclaw-agent-v1.1.Modelfile
echo "== article-line count (expect 15) =="
grep -cE '^[0-9]+ ' ~/wireclaw-agent-v1.1.Modelfile
echo "== IDENTITY present, WireClaw-Agent present =="
grep -c 'WireClaw-Agent' ~/wireclaw-agent-v1.1.Modelfile
echo "== tail -6 =="
tail -6 ~/wireclaw-agent-v1.1.Modelfile
REMOTE
