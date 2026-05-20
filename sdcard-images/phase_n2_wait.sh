#!/bin/bash
# Blocks until all 3 Haiku jobs drop their .done sentinel, then prints a
# completion summary. Intended to be run in the background (single wait,
# no external polling).
set -u
deadline=$(( $(date +%s) + 9000 ))   # 2.5 h safety cap
while :; do
  d=0
  for c in pilot c6-02 c6-03; do [ -f "/tmp/haiku-$c.done" ] && d=$((d+1)); done
  [ "$d" -eq 3 ] && break
  [ "$(date +%s)" -gt "$deadline" ] && { echo "TIMEOUT after 2.5h, $d/3 done"; break; }
  sleep 60
done

echo "=== Haiku jobs finished $(date '+%F %T %Z') ==="
for c in pilot c6-02 c6-03; do
  rc=$(cat "/tmp/haiku-$c.done" 2>/dev/null || echo "?")
  echo "--- $c : exit rc=$rc ---"
  tail -4 "/tmp/haiku-$c.log" 2>/dev/null || echo "(no log)"
  out="/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus-labels/3.1.3-2026-05-16-$c.haiku.json"
  if [ -s "$out" ]; then
    python3 -c "import json;o=json.load(open('$out'));print('  records=%d summary_labels=%s'%(len(o['records']),o['summary']['label_counts']))" 2>/dev/null
  else
    echo "  OUTPUT MISSING/EMPTY: $out"
  fi
done
