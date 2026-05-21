#!/bin/bash
DEST=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus/v1.3.1-overnight-2026-05-20/proxy
for d in 2026-05-20 2026-05-21; do
  N=$(find "$DEST/$d" -name '*.json' 2>/dev/null | wc -l)
  S=$(du -sh "$DEST/$d" 2>/dev/null | cut -f1)
  echo "$d: $N files / $S"
done
