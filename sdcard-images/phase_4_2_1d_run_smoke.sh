#!/bin/bash
set -u
export ANTHROPIC_API_KEY=$(python3 -c '
import re
with open("/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt") as f:
    m = re.search(r"sk-ant-api[0-9]{2}-[A-Za-z0-9_-]{30,}", f.read())
print(m.group(0) if m else "")
')
[ -z "${ANTHROPIC_API_KEY:-}" ] && { echo "FATAL: no key"; exit 2; }
MODEL="${1:-wireclaw-agent:v1.3}"
python3 /mnt/c/Users/homet/Documents/WireClaw/sdcard-images/phase_4_2_1d_smoke.py --model "$MODEL" "${@:2}"
