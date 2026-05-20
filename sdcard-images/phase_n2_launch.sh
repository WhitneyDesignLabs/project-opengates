#!/bin/bash
# Phase 3.2 N2: launch all 3 corpora through the Haiku judge in parallel.
# Backgrounds via setsid so they survive the parent shell exiting; returns fast.
set -u
SECRETS="/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt"
val=$(grep -oE 'sk-ant-[A-Za-z0-9_-]+' "$SECRETS" | head -1)
export ANTHROPIC_API_KEY="$val"
BENCH="/mnt/c/Users/homet/Documents/WireClaw/bench"
cd "$BENCH" || exit 2
mkdir -p fork/lora/corpus-labels
rm -f /tmp/haiku-pilot.log /tmp/haiku-c6-02.log /tmp/haiku-c6-03.log
rm -f /tmp/haiku-pilot.done /tmp/haiku-c6-02.done /tmp/haiku-c6-03.done

for chip in pilot c6-02 c6-03; do
  setsid bash -c "
    export ANTHROPIC_API_KEY='$val'
    cd '$BENCH'
    python3 wrap_up_classify.py --use-haiku \
      --corpus fork/lora/corpus-raw/3.1.3-2026-05-16-${chip}.json \
      --out fork/lora/corpus-labels/3.1.3-2026-05-16-${chip}.haiku.json \
      > /tmp/haiku-${chip}.log 2>&1
    echo \$? > /tmp/haiku-${chip}.done
  " </dev/null >/dev/null 2>&1 &
  echo "launched $chip (pid $!) -> /tmp/haiku-${chip}.log"
done
echo "all 3 launched $(date '+%F %T %Z'); ~90 min parallel ETA"
