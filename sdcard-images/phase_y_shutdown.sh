#!/bin/bash
# Graceful poweroff of all 3 driver Pis before Scott's rack/PSU work.
# Sync first to protect the SD cards (esp. EvoBot's, which is being moved).
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
EVO="ssh -o BatchMode=yes -o ConnectTimeout=8 evobot"
P2="$SSH scott@192.168.1.17"
P3="$SSH scott@192.168.1.44"

echo "== capture EvoBot current IP (for accurate down-check) =="
EVOIP=$($EVO 'hostname -I 2>/dev/null | awk "{print \$1}"' 2>/dev/null | tr -d "\r\n ")
echo "  EvoBot current IP: ${EVOIP:-UNKNOWN}"

echo "== pre-shutdown: sync + issue poweroff =="
$EVO 'sync; sync; echo "evobot: synced, powering off"; sudo poweroff' 2>&1 || echo "evobot poweroff cmd sent (link drop expected)"
$P2  'sync; sync; echo "pi02: synced, powering off";   sudo poweroff' 2>&1 || echo "pi02 poweroff cmd sent (link drop expected)"
$P3  'sync; sync; echo "pi03: synced, powering off";   sudo poweroff' 2>&1 || echo "pi03 poweroff cmd sent (link drop expected)"

echo
echo "== waiting 25s, then confirming all 3 are down (ping should fail) =="
sleep 25
for spec in "evobot:${EVOIP:-192.168.1.51}" "pi02:192.168.1.17" "pi03:192.168.1.44"; do
  L=${spec%%:*}; IP=${spec##*:}
  if ping -c1 -W2 "$IP" >/dev/null 2>&1; then echo "  $L ($IP): STILL PINGING (may still be flushing — recheck in a moment)"; else echo "  $L ($IP): down (no ping) OK"; fi
done
echo "(Down = no ping on current IP + ssh refused. Scott: confirm Pi LEDs off before cutting PSU.)"
