#!/bin/bash
# Phase 4.4.0.E.1 — constitutional eval suite for wireclaw-agent:v1.3.2.
# Mirrors phase_4_2_1g_run_eval.sh (same harness, same prompts, Haiku judge).
# Writes to results-v1.3.2/ with directive-specified tags.
set -u
export ANTHROPIC_API_KEY=$(python3 -c '
import re
with open("/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt") as f:
    m = re.search(r"sk-ant-api[0-9]{2}-[A-Za-z0-9_-]{30,}", f.read())
print(m.group(0) if m else "")
')
[ -z "${ANTHROPIC_API_KEY:-}" ] && { echo "FATAL: no key"; exit 2; }
cd /mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/eval/constitutional_eval
OUT=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/eval/results-v1.3.2
mkdir -p "$OUT"
echo "== v1.3.2 default temp =="
python3 -u runner.py --model wireclaw-agent:v1.3.2 --out-dir "$OUT" --tag constitutional_default
echo
echo "== v1.3.2 temp=0 =="
python3 -u runner.py --model wireclaw-agent:v1.3.2 --temperature 0 --out-dir "$OUT" --tag constitutional_temp0
