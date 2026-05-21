#!/bin/bash
# Phase 4.2.1.I.7: re-run constitutional eval against production v1.3.1
# to detect drift between published HF model and chip-deployed.
set -u
export ANTHROPIC_API_KEY=$(python3 -c '
import re, sys
with open("/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt") as f:
    m = re.search(r"sk-ant-api[0-9]{2}-[A-Za-z0-9_-]{30,}", f.read())
print(m.group(0) if m else "")
')
[ -z "${ANTHROPIC_API_KEY:-}" ] && { echo "FATAL: no key"; exit 2; }

cd /mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/eval/constitutional_eval

echo "== v1.3.1 default temp (production re-run) =="
python3 -u runner.py --model wireclaw-agent:v1.3.1 --tag v1.3.1-production-default

echo
echo "== v1.3.1 temp=0 (production re-run) =="
python3 -u runner.py --model wireclaw-agent:v1.3.1 --temperature 0 --tag v1.3.1-production-temp0
