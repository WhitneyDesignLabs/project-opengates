#!/bin/bash
# Trim metadata to speculative-only on evobot.
set -u
F=$HOME/phase_4_3_0_ab_metadata.jsonl
if [ ! -f "$F" ]; then
  echo "FATAL: $F not found"
  exit 1
fi
B=$(wc -l < "$F")
head -n 140 "$F" > "$F.tmp"
mv "$F.tmp" "$F"
A=$(wc -l < "$F")
echo "trimmed: $B -> $A lines"
tail -n 1 "$F" | python3 -c 'import sys,json
d=json.loads(sys.stdin.read())
print(" last:", d["prompt_id"], "run", d["run_num"], "mode", d["mode"])'
