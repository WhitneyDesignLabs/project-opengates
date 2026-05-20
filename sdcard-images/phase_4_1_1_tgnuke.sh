#!/bin/bash
# Phase 4.1.1: hard-drop the Telegram pending-update backlog for the TWO
# fleet chip bots actually under capture — wdl_c6_02_bot (id 8467414529)
# and wdl_c6_03_bot (id 8996548050). The old phase_4_0_3_tgnuke.sh only
# flushed 8700541005 (wireclawsap_bot) — the WRONG bot for c6-02/c6-03,
# so the overnight backlog kept feeding the chips. Tokens are read from
# Secrets.txt by bot-id and never printed.
#
# deleteWebhook?drop_pending_updates=true is the reliable drop and does
# not fight the chip's own getUpdates long-poll. getWebhookInfo confirms
# pending_update_count==0. A read-only getUpdates check may show 409
# (chip is the registered poller) — that is expected, not a failure.
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

nuke_bot "wdl_c6_02_bot / C6-02" 8467414529
nuke_bot "wdl_c6_03_bot / C6-03" 8996548050
echo "done."
