#!/bin/bash
# Phase 4.1.4a Step 3: run wrap_up_classify.py with Haiku layer on the
# v1.1 corpus. Loads ANTHROPIC_API_KEY from Secrets.txt via Python
# extraction (never cat'd to terminal/log). Output: standard
# {summary, records} JSON the 3.1.3 baseline files share.
set -u
SRC=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus-labels/v1.1-overnight-2026-05-18.input.json
OUT=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus-labels/v1.1-overnight-2026-05-18.haiku.json
CLASSIFIER=/mnt/c/Users/homet/Documents/WireClaw/bench/wrap_up_classify.py

# Extract key into env, never print it.
export ANTHROPIC_API_KEY=$(python3 -c '
import re, sys
with open("/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt") as f:
    m = re.search(r"sk-ant-api[0-9]{2}-[A-Za-z0-9_-]{30,}", f.read())
if not m:
    sys.exit(2)
print(m.group(0))
')
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  echo "FATAL: could not extract ANTHROPIC_API_KEY from Secrets.txt" >&2
  exit 2
fi
echo "key loaded into env (len=${#ANTHROPIC_API_KEY})"

cd /mnt/c/Users/homet/Documents/WireClaw
python3 -u "$CLASSIFIER" --corpus "$SRC" --out "$OUT" --use-haiku
echo "DONE: $OUT"
ls -la "$OUT"
