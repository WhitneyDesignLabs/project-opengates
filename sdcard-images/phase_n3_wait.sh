#!/bin/bash
# Liveness (after 60s) then block until all 3 v2 jobs finish; summarize.
set -u
sleep 60
echo "=== liveness +60s ==="
pgrep -fc 'wrap_up_classify.py --use-haiku' >/dev/null 2>&1 && \
  echo "running procs: $(pgrep -fc 'wrap_up_classify.py --use-haiku')" || echo "running procs: 0"
for c in pilot c6-02 c6-03; do
  if [ -f "/tmp/haiku-$c.done" ]; then
    echo "$c: DONE rc=$(cat /tmp/haiku-$c.done) (if <2min suspicious)"
  else echo "$c: still running (good)"; fi
done

echo "=== blocking until all 3 done ==="
deadline=$(( $(date +%s) + 9000 ))
while :; do
  d=0
  for c in pilot c6-02 c6-03; do [ -f "/tmp/haiku-$c.done" ] && d=$((d+1)); done
  [ "$d" -eq 3 ] && break
  [ "$(date +%s)" -gt "$deadline" ] && { echo "TIMEOUT $d/3"; break; }
  sleep 60
done
echo "=== finished $(date '+%F %T %Z') ==="
CL="/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus-labels"
for c in pilot c6-02 c6-03; do
  echo "--- $c rc=$(cat /tmp/haiku-$c.done 2>/dev/null) ---"
  tail -3 "/tmp/haiku-v2-$c.log" 2>/dev/null || echo "(no log)"
  o="$CL/3.1.3-2026-05-16-$c.haiku.json"
  [ -s "$o" ] && python3 -c "import json;d=json.load(open('$o'));print('  records=%d labels=%s'%(len(d['records']),d['summary']['label_counts']))" || echo "  MISSING/EMPTY $o"
done
