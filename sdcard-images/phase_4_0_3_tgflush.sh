#!/bin/bash
# Phase 4.0.3 Step 5b: flush the Telegram bot backlog so c6-02 stops
# re-fetching last night's unacked persona prompts. Confirms all pending
# updates via getUpdates offset. Token is read from SetupBasics.txt and
# never printed.
set -u
SB=/mnt/c/Users/homet/Documents/WireClaw/SetupBasics.txt
TOKEN=$(grep -oE '8700541005:[A-Za-z0-9_-]+' "$SB" | head -1)
if [ -z "$TOKEN" ]; then echo "FATAL: bot token not found in SetupBasics.txt"; exit 2; fi
API="https://api.telegram.org/bot${TOKEN}"

echo "1) peek latest update (offset=-1)"
LAST=$(curl -s -m 15 "${API}/getUpdates?offset=-1&timeout=0")
echo "   raw ok flag: $(echo "$LAST" | grep -o '"ok":[a-z]*' | head -1)"
LASTID=$(echo "$LAST" | grep -oE '"update_id":[0-9]+' | grep -oE '[0-9]+' | tail -1)
echo "   highest pending update_id: ${LASTID:-none}"

if [ -n "${LASTID:-}" ]; then
  NEXT=$((LASTID + 1))
  echo "2) confirm/forget everything up to $LASTID (offset=$NEXT)"
  R=$(curl -s -m 15 "${API}/getUpdates?offset=${NEXT}&timeout=0")
  echo "   ok flag: $(echo "$R" | grep -o '"ok":[a-z]*' | head -1)  result_count: $(echo "$R" | grep -o '"update_id"' | wc -l)"
else
  echo "2) no pending updates to confirm"
fi

echo "3) verify backlog drained (3 polls, 2s apart)"
for i in 1 2 3; do
  V=$(curl -s -m 15 "https://api.telegram.org/bot${TOKEN}/getUpdates?timeout=0")
  CNT=$(echo "$V" | grep -o '"update_id"' | wc -l)
  echo "   poll $i: pending=$CNT"
  [ "$CNT" -eq 0 ] && break
  sleep 2
done
echo "done."
