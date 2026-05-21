#!/bin/bash
# Phase 4.0.5-lite: break c6-01's leftover-rules.json boot loop.
# Hammer POST /api/rules/delete {"id":"all"} to catch the ~1-2s HTTP-alive
# window before rulesEvaluate() fires the poison rule + TG1 watchdog reboot.
# Same recovery pattern Scott used on c6-03 in Phase 4.0.3.
set -u
URL="http://192.168.1.19/api/rules/delete"
echo "hammering ${URL} for up to 90s ..."
ok=0
END=$(( $(date +%s) + 90 ))
n=0
while [ "$(date +%s)" -lt "$END" ]; do
  n=$((n+1))
  R=$(curl -s -m 2 -X POST -H 'Content-Type: application/json' --data '{"id":"all"}' "${URL}" 2>/dev/null)
  if echo "${R}" | grep -q '"ok":true'; then
    echo "HIT on attempt #${n}: ${R}"
    ok=1
    # fire 3 more to be sure rulesSave persisted before next reset
    for i in 1 2 3; do
      curl -s -m 2 -X POST -H 'Content-Type: application/json' --data '{"id":"all"}' "${URL}" 2>/dev/null
      echo
      sleep 0.3
    done
    break
  fi
  sleep 0.15
done
echo "attempts=${n} ok=${ok}"
echo
echo "-- verify GET /api/rules --"
for i in 1 2 3 4 5 6 7 8 9 10; do
  G=$(curl -s -m 2 "http://192.168.1.19/api/rules" 2>/dev/null)
  [ -n "${G}" ] && { echo "rules now: ${G}"; break; }
  sleep 0.4
done
echo
echo "-- stability watch (12 polls @ 5s, expect uptime monotonic) --"
LAST=-1
for i in $(seq 1 12); do
  sleep 5
  S=$(curl -sS --max-time 3 "http://192.168.1.19/api/status" 2>/dev/null)
  U=$(echo "${S}" | grep -oE '"uptime_seconds":[0-9]+' | grep -oE '[0-9]+' || echo "-1")
  if [ -z "${S}" ]; then
    echo "  poll ${i}: NO RESPONSE"
  elif [ "${U}" -lt "${LAST}" ]; then
    echo "  poll ${i}: RESET (uptime ${U} < prev ${LAST})"
  else
    echo "  poll ${i}: uptime=${U}s"
  fi
  LAST=${U}
done
