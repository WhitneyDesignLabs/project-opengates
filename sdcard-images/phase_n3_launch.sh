#!/bin/bash
# Phase 3.2 step 1b N3: preserve v1 outputs, then launch the 3 v2 corpora
# (demoted-deterministic + Haiku-every-turn) in parallel, uncached (Path A).
set -u
SECRETS="/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt"
val=$(grep -oE 'sk-ant-[A-Za-z0-9_-]+' "$SECRETS" | head -1)
export ANTHROPIC_API_KEY="$val"
BENCH="/mnt/c/Users/homet/Documents/WireClaw/bench"
CL="$BENCH/fork/lora/corpus-labels"
cd "$BENCH" || exit 2

echo "== preserve v1 (rename, do not delete) =="
for chip in pilot c6-02 c6-03; do
  s="$CL/3.1.3-2026-05-16-$chip.haiku.json"
  d="$CL/3.1.3-2026-05-16-$chip.haiku.v1.json"
  if [ -f "$s" ]; then mv -v "$s" "$d"; else echo "(no v1 $s — already moved?)"; fi
done

echo "== launch 3 v2 runs (uncached) =="
rm -f /tmp/haiku-v2-pilot.log /tmp/haiku-v2-c6-02.log /tmp/haiku-v2-c6-03.log
rm -f /tmp/haiku-pilot.done /tmp/haiku-c6-02.done /tmp/haiku-c6-03.done
for chip in pilot c6-02 c6-03; do
  setsid bash -c "
    export ANTHROPIC_API_KEY='$val'
    cd '$BENCH'
    python3 wrap_up_classify.py --use-haiku \
      --corpus fork/lora/corpus-raw/3.1.3-2026-05-16-${chip}.json \
      --out fork/lora/corpus-labels/3.1.3-2026-05-16-${chip}.haiku.json \
      > /tmp/haiku-v2-${chip}.log 2>&1
    echo \$? > /tmp/haiku-${chip}.done
  " </dev/null >/dev/null 2>&1 &
  echo "launched $chip (pid $!) -> /tmp/haiku-v2-${chip}.log"
done
echo "all 3 v2 launched $(date '+%F %T %Z'); ~50-60 min ETA"
