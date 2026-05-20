#!/bin/bash
set -u
C=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus
SRC="$C/v1.1-overnight-2026-05-18.jsonl"
DST="$C/quarantine/v1.1-overnight-2026-05-18.SCRAMBLED.jsonl"
mkdir -p "$C/quarantine"
if [ -f "$SRC" ]; then
  mv "$SRC" "$DST"
  echo "MOVED -> $DST"
elif [ -f "$DST" ]; then
  echo "already quarantined at $DST"
else
  echo "FATAL: neither src nor dst exists"
  exit 2
fi
ls -la "$C/quarantine/"
echo -n "lines: "; wc -l < "$DST"
echo -n "canonical path clear: "; [ -f "$SRC" ] && echo "NO (src still present)" || echo "YES (src absent)"
