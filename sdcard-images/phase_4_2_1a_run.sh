#!/bin/bash
# Phase 4.2.1.A: fire Sonnet synthetic-data generator.
set -u
export ANTHROPIC_API_KEY=$(python3 -c '
import re
with open("/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt") as f:
    m = re.search(r"sk-ant-api[0-9]{2}-[A-Za-z0-9_-]{30,}", f.read())
print(m.group(0) if m else "")
')
[ -z "${ANTHROPIC_API_KEY:-}" ] && { echo "FATAL: no key"; exit 2; }
echo "key loaded (len=${#ANTHROPIC_API_KEY})"
OUT=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training-data/v1.3-synthetic.jsonl
mkdir -p "$(dirname "$OUT")"
python3 -u /mnt/c/Users/homet/Documents/WireClaw/sdcard-images/phase_4_2_1a_synth.py --out "$OUT"
