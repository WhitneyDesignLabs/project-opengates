#!/bin/bash
# Phase 3.3.3 N2: convert HF LoRA adapter -> GGUF on azza.
set -u
A="ssh -o BatchMode=yes -o ConnectTimeout=12 azza@192.168.1.60"
$A 'bash -s' <<'REMOTE' 2>&1
set -u
cd ~/llama.cpp
echo "== adapter_config.json =="
cat ~/wireclaw-v2-brev/adapter_config.json
echo
echo "== attempt 1: plain convert =="
python3 convert_lora_to_gguf.py ~/wireclaw-v2-brev \
    --outfile ~/wireclaw-agent-v1.1.adapter.gguf --outtype f16 2>&1 | tail -25
if [ -f ~/wireclaw-agent-v1.1.adapter.gguf ]; then
  echo "RESULT: OK"; ls -lh ~/wireclaw-agent-v1.1.adapter.gguf
else
  echo "RESULT: attempt1 failed; attempt 2 with --base-model-id"
  python3 convert_lora_to_gguf.py ~/wireclaw-v2-brev \
    --outfile ~/wireclaw-agent-v1.1.adapter.gguf --outtype f16 \
    --base-model-id meta-llama/Llama-3.1-8B-Instruct 2>&1 | tail -25
  [ -f ~/wireclaw-agent-v1.1.adapter.gguf ] && { echo "RESULT: OK (attempt2)"; ls -lh ~/wireclaw-agent-v1.1.adapter.gguf; } || echo "RESULT: BOTH FAILED"
fi
REMOTE
