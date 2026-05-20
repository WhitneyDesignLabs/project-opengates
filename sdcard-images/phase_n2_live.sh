#!/bin/bash
set -u
sleep 60
echo "alive procs (expect 3 wrap_up_classify):"
pgrep -fc 'wrap_up_classify.py --use-haiku' || echo 0
for c in pilot c6-02 c6-03; do
  d="/tmp/haiku-$c.done"
  if [ -f "$d" ]; then echo "$c: ALREADY DONE rc=$(cat "$d") (suspicious if <2min -> likely 400 again)"; else echo "$c: still running (good)"; fi
done
