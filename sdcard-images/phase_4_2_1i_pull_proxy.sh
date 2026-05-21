#!/bin/bash
# Phase 4.2.1.I.2b: pull azza proxy logs covering the overnight window.
# 180 MB across both date dirs.
set -u
DEST=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus/v1.3.1-overnight-2026-05-20/proxy
mkdir -p "$DEST/2026-05-20" "$DEST/2026-05-21"

echo "=== rsync azza proxy dirs ==="
for d in 2026-05-20 2026-05-21; do
  echo "[$d]"
  rsync -a --info=stats1,progress2 \
    "azza@azza.tail63f48.ts.net:~/wireclaw-corpus/ollama-raw/$d/" \
    "$DEST/$d/" 2>&1 | tail -n 5
  echo
done

echo "=== local totals ==="
for d in 2026-05-20 2026-05-21; do
  N=$(find "$DEST/$d" -name "*.json" 2>/dev/null | wc -l)
  S=$(du -sh "$DEST/$d" | awk '{print $1}')
  echo "  $d: $N files / $S"
done
