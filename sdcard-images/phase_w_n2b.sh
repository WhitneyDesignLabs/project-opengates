#!/bin/bash
# Phase 3.3.3 N2 (retry): convert with HF_TOKEN so the gated Llama-3.1 base
# config can be fetched. Token passed inline to the single remote command,
# NOT written to azza disk, NOT echoed.
set -u
SEC=/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt
HFT="$(grep -oE 'hf_[A-Za-z0-9]{20,}' "$SEC" | head -1)"
[ -z "$HFT" ] && { echo "FATAL: no HF token in Secrets.txt"; exit 2; }
A="ssh -o BatchMode=yes -o ConnectTimeout=12 azza@192.168.1.60"
# Pass token via the remote command's env; suppress it from any echo.
$A "HF_TOKEN='$HFT' HUGGING_FACE_HUB_TOKEN='$HFT' bash -s" <<'REMOTE' 2>&1
set -u
cd ~/llama.cpp
echo "HF auth present in remote env: ${HF_TOKEN:0:5}… (len ${#HF_TOKEN})"
rm -f ~/wireclaw-agent-v1.1.adapter.gguf
python3 convert_lora_to_gguf.py ~/wireclaw-v2-brev \
  --outfile ~/wireclaw-agent-v1.1.adapter.gguf --outtype f16 2>&1 | tail -20
if [ -f ~/wireclaw-agent-v1.1.adapter.gguf ]; then
  echo "RESULT: OK"; ls -lh ~/wireclaw-agent-v1.1.adapter.gguf
  python3 -c "import gguf,sys; r=gguf.GGUFReader('$HOME/wireclaw-agent-v1.1.adapter.gguf'); print('gguf tensors:',len(r.tensors),'| arch field present')" 2>&1 | tail -1
else
  echo "RESULT: FAILED"
fi
REMOTE
