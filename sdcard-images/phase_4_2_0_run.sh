#!/bin/bash
# Phase 4.2.0 Step 2: run constitutional eval against wireclaw-agent:v1.1
# on azza Ollama proxy. Loads ANTHROPIC_API_KEY via Python regex
# extraction (never cat'd to terminal).
set -u
export ANTHROPIC_API_KEY=$(python3 -c '
import re, sys
with open("/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt") as f:
    m = re.search(r"sk-ant-api[0-9]{2}-[A-Za-z0-9_-]{30,}", f.read())
print(m.group(0) if m else "")
')
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "FATAL: no ANTHROPIC_API_KEY"
  exit 2
fi
echo "key loaded (len=${#ANTHROPIC_API_KEY})"
cd /mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/eval/constitutional_eval
python3 -u runner.py --tag v1.1-baseline
