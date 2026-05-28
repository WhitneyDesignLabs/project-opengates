#!/bin/bash
# Wait for an A/B arm driver to finish. Args: <log> <metadata> <label> <max_iters>
LOG="$1"; META="$2"; LABEL="$3"; MAX="${4:-110}"
for i in $(seq 1 "$MAX"); do
  if grep -q DRIVER-EXIT "$LOG" 2>/dev/null; then
    echo "${LABEL}-DONE runs=$(wc -l < "$META" 2>/dev/null)"
    exit 0
  fi
  sleep 30
done
echo "${LABEL}-TIMEOUT runs=$(wc -l < "$META" 2>/dev/null)"
