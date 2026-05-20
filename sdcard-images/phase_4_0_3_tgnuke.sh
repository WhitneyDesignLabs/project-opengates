#!/bin/bash
# Phase 4.0.3 (pivot): hard-drop Telegram's pending update queue so the
# crash-looping chip stops receiving the poison persona message.
# deleteWebhook?drop_pending_updates=true clears the queue regardless of
# the racing chip consumer. Token read from SetupBasics.txt, not printed.
set -u
SB=/mnt/c/Users/homet/Documents/WireClaw/SetupBasics.txt
TOKEN=$(grep -oE '8700541005:[A-Za-z0-9_-]+' "$SB" | head -1)
[ -z "$TOKEN" ] && { echo "FATAL: token not found"; exit 2; }
B="https://api.telegram.org/bot${TOKEN}"

echo "1) deleteWebhook?drop_pending_updates=true"
curl -s -m 15 "${B}/deleteWebhook?drop_pending_updates=true"; echo
echo "2) getWebhookInfo (expect pending_update_count 0)"
curl -s -m 15 "${B}/getWebhookInfo" | grep -oE '"pending_update_count":[0-9]+|"url":"[^"]*"'; echo
echo "3) confirm getUpdates drains to empty (3 polls)"
for i in 1 2 3; do
  V=$(curl -s -m 15 "${B}/getUpdates?timeout=0")
  echo "   poll $i pending=$(echo "$V" | grep -o '\"update_id\"' | wc -l)"
  sleep 2
done
echo "done"
