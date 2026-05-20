#!/bin/bash
set -u
cd /mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus-labels || exit 2
for c in pilot c6-02 c6-03; do
  s="3.1.3-2026-05-16-$c.haiku.json"
  d="3.1.3-2026-05-16-$c.haiku.INVALID-no-credit.json"
  [ -f "$s" ] && mv -v "$s" "$d" || echo "(missing $s)"
done
echo "--- corpus-labels now ---"
ls -la
