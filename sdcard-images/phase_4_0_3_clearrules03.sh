#!/bin/bash
# Break c6-03's leftover-/rules.json boot loop: hammer POST
# /api/rules/delete {"id":"all"} from pi03 to catch the brief HTTP
# window each reboot. handleDeleteRule does ruleDelete("all")+rulesSave()
# -> persists "[]" -> next boot loads 0 rules -> loop() no longer hangs.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $K"
$SSH scott@192.168.1.44 'bash -s' <<'REMOTE'
set -u
URL="http://192.168.1.47/api/rules/delete"
echo "hammering $URL up to 120s ..."
ok=0; END=$(( $(date +%s) + 120 )); n=0
while [ "$(date +%s)" -lt "$END" ]; do
  n=$((n+1))
  R=$(curl -s -m 2 -X POST -H 'Content-Type: application/json' --data '{"id":"all"}' "$URL" 2>/dev/null)
  if echo "$R" | grep -q '"ok":true'; then
    echo "HIT #$n: $R"; ok=1
    for i in 1 2 3 4; do curl -s -m2 -X POST -H 'Content-Type: application/json' --data '{"id":"all"}' "$URL" 2>/dev/null; echo; sleep 0.25; done
    break
  fi
  sleep 0.12
done
echo "attempts=$n ok=$ok"
for i in 1 2 3 4 5 6 7 8; do
  G=$(curl -s -m2 "http://192.168.1.47/api/rules" 2>/dev/null)
  [ -n "$G" ] && { echo "rules now: $G"; break; }
  sleep 0.4
done
REMOTE
