#!/bin/bash
set -u
export ANTHROPIC_API_KEY=$(python3 -c '
import re
with open("/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt") as f:
    m = re.search(r"sk-ant-api[0-9]{2}-[A-Za-z0-9_-]{30,}", f.read())
print(m.group(0) if m else "")
')
[ -z "${ANTHROPIC_API_KEY:-}" ] && { echo "FATAL: no key"; exit 2; }
cd /mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/eval/constitutional_eval
echo "== v1.3 default temp =="
python3 -u runner.py --model wireclaw-agent:v1.3 --tag v1.3-default
echo
echo "== v1.3 temp=0 =="
python3 -u runner.py --model wireclaw-agent:v1.3 --temperature 0 --tag v1.3-temp0
