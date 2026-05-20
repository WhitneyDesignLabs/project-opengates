#!/bin/bash
set -u
cd /mnt/c/Users/homet/Documents/WireClaw-fork
echo "=== diff --stat ==="
git diff --stat
echo
echo "=== last commit per file ==="
for f in data/system_prompt.txt include/llm_client.h src/llm_client.cpp src/main.cpp src/tools.cpp; do
  printf "%-30s " "$f"
  git log -1 --format='%h  %ar  %s' -- "$f"
done
echo
echo "=== diffs (head 60 lines each) ==="
for f in data/system_prompt.txt include/llm_client.h src/llm_client.cpp src/main.cpp src/tools.cpp; do
  echo
  echo "--------- $f ---------"
  git diff --no-color -- "$f" | head -n 60
done
