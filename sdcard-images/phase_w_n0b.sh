#!/bin/bash
set -u
A="ssh -o BatchMode=yes -o ConnectTimeout=10 azza@192.168.1.60"
DIR=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training/output/bench/fork/lora/training/output/wireclaw-v2-brev
$A 'mkdir -p ~/wireclaw-v2-brev' 2>&1
echo "scp adapter files (incl 84MB safetensors)..."
scp -q -o BatchMode=yes -o ConnectTimeout=10 "$DIR"/adapter_model.safetensors "$DIR"/adapter_config.json "$DIR"/tokenizer.json "$DIR"/tokenizer_config.json "$DIR"/training-config.yaml "$DIR"/training-log.json "$DIR"/chat_template.jinja "$DIR"/README.md azza@192.168.1.60:~/wireclaw-v2-brev/ 2>&1 && echo "adapter scp OK" || echo "adapter scp FAIL"
echo "== azza ~/wireclaw-v2-brev =="
$A 'ls -la ~/wireclaw-v2-brev/; echo "safetensors sha (first 12):"; sha256sum ~/wireclaw-v2-brev/adapter_model.safetensors | cut -c1-12' 2>&1
