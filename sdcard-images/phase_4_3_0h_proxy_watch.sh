#!/bin/bash
# Phase 4.3.0.H.3 proxy sanity-check watcher.
# Runs on azza. Watches today's ollama-raw capture dir for new JSON files;
# when one appears, extracts the model field from the request body and prints
# it. 5-minute timeout.
set -u
TODAY=$(date -u +%Y-%m-%d)
DIR="$HOME/wireclaw-corpus/ollama-raw/$TODAY"
mkdir -p "$DIR"
echo "watching $DIR (UTC date $TODAY) for next capture..."

# track existing files so we only report on NEW ones
BEFORE=$(ls -1 "$DIR"/*.json 2>/dev/null | sort)
START_COUNT=$(echo "$BEFORE" | grep -c . || true)
echo "files present at start: $START_COUNT"

for i in $(seq 1 60); do
  AFTER=$(ls -1 "$DIR"/*.json 2>/dev/null | sort)
  NEW=$(comm -13 <(echo "$BEFORE") <(echo "$AFTER") | head -1)
  if [ -n "$NEW" ] && [ -f "$NEW" ]; then
    echo "new capture: $NEW"
    echo
    python3 - "$NEW" <<'PY'
import json, sys
path = sys.argv[1]
d = json.load(open(path))
# proxy captures both request and response; the request body lives under
# "request" or top-level depending on proxy version
req = d.get("request", d)
model = req.get("model", "<no model field>")
print("MODEL FIELD IN REQUEST BODY:", model)
print()
# count messages, print first user message
msgs = req.get("messages", [])
print(f"messages: {len(msgs)} (roles: {[m.get('role') for m in msgs]})")
for m in msgs:
    if m.get("role") == "user":
        print(f"first user content: {m.get('content','')[:200]!r}")
        break
PY
    exit 0
  fi
  sleep 5
done
echo "TIMEOUT after 5 minutes — no new capture file in $DIR"
echo "files now present:"
ls -1t "$DIR"/*.json 2>/dev/null | head -3
exit 1
