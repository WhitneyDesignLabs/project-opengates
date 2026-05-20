#!/bin/bash
# Phase 4.0.3 Step 5a: break the reboot loop by clearing the leftover
# /rules.json. Hammer POST /api/rules/delete {"id":"all"} from pi02 to
# catch the ~1-2s HTTP-alive window each reboot cycle. handleDeleteRule
# calls ruleDelete("all") + rulesSave() -> persists "[]" -> next boot
# loads 0 rules -> loop() no longer hangs.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $K"

$SSH scott@192.168.1.17 'bash -s' <<'REMOTE'
set -u
URL="http://192.168.1.15/api/rules/delete"
echo "hammering $URL for up to 90s ..."
ok=0
END=$(( $(date +%s) + 90 ))
n=0
while [ "$(date +%s)" -lt "$END" ]; do
  n=$((n+1))
  R=$(curl -s -m 2 -X POST -H 'Content-Type: application/json' --data '{"id":"all"}' "$URL" 2>/dev/null)
  if echo "$R" | grep -q '"ok":true'; then
    echo "HIT on attempt #$n: $R"
    ok=1
    # fire a couple more to be sure rulesSave persisted before next reset
    for i in 1 2 3; do curl -s -m 2 -X POST -H 'Content-Type: application/json' --data '{"id":"all"}' "$URL" 2>/dev/null; echo; sleep 0.3; done
    break
  fi
  sleep 0.15
done
echo "attempts=$n ok=$ok"
echo "-- verify GET /api/rules --"
for i in 1 2 3 4 5 6 7 8 9 10; do
  G=$(curl -s -m 2 "http://192.168.1.15/api/rules" 2>/dev/null)
  [ -n "$G" ] && { echo "rules now: $G"; break; }
  sleep 0.4
done
REMOTE
