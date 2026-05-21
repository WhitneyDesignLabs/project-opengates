#!/bin/bash
# Phase 4.3.0.F: pull today's azza proxy logs for the A/B analysis.
set -u
DEST=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus/4_3_0_ab/proxy_2026-05-21
mkdir -p "$DEST"
rsync -a --no-perms --no-owner --no-group \
    azza@azza.tail63f48.ts.net:wireclaw-corpus/ollama-raw/2026-05-21/ "$DEST/" 2>&1 | tail -n 3
echo ---
TOTAL=$(find "$DEST" -name "*.json" | wc -l)
echo "  total: $TOTAL files"
echo "  by source IP (top 5):"
find "$DEST" -name "*.json" -printf '%f\n' | awk -F'_' '{print $1}' | sort | uniq -c | sort -rn | head -5
