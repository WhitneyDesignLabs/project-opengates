#!/bin/bash
# Phase 4.0.5-lite: drop the Telegram pending-update backlog for c6-01's
# bot wdl_c6_pilot_bot (id 8728314129). Same pattern as the 4.1.1 nuke
# for c6-02/c6-03 — deleteWebhook?drop_pending_updates=true is the
# reliable drop; getWebhookInfo confirms pending=0; getUpdates poll
# may show 409 (the chip itself holds the long-poll), which is expected
# and not a failure.
set -u
SB=/mnt/c/Users/homet/Documents/WireClaw/Secrets.txt

nuke_bot() {
  local label="$1" botid="$2"
  local tok
  tok=$(grep -oE "${botid}:[A-Za-z0-9_-]+" "$SB" | head -1)
  if [ -z "$tok" ]; then echo "[$label] FATAL: token for $botid not found"; return 2; fi
  local B="https://api.telegram.org/bot${tok}"
  echo "=== $label (bot id $botid) ==="
  echo "1) deleteWebhook?drop_pending_updates=true"
  curl -s -m 20 "${B}/deleteWebhook?drop_pending_updates=true"; echo
  echo "2) getWebhookInfo (expect pending_update_count 0)"
  curl -s -m 20 "${B}/getWebhookInfo" \
    | grep -oE '"pending_update_count":[0-9]+|"url":"[^"]*"'; echo
  echo "3) read-only getUpdates check (409=chip is polling, expected)"
  local i V CNT
  for i in 1 2 3; do
    V=$(curl -s -m 20 "${B}/getUpdates?timeout=0")
    if echo "$V" | grep -q '"error_code":409'; then
      echo "   poll $i: 409 Conflict (chip holds the poll — backlog already dropped by step 1)"
      break
    fi
    CNT=$(echo "$V" | grep -o '"update_id"' | wc -l)
    echo "   poll $i: pending=$CNT"
    [ "$CNT" -eq 0 ] && break
    sleep 2
  done
  echo
}

nuke_bot "wdl_c6_pilot_bot / C6-01" 8728314129
echo "done."
