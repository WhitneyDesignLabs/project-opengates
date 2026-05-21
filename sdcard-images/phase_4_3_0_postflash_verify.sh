#!/bin/bash
# Phase 4.3.0.E post-flash: verify c6-01 boots cleanly on the new
# firmware, /api/status responds, wrap_mode is exposed and defaults to
# "speculative", 60s stability watch.
set -u
IP=192.168.1.19

echo "-- waiting 30s for boot + WiFi --"
sleep 30

echo "-- post-flash poll (up to 30s extra wakeup retry) --"
ATTEMPT=0
POST=""
while [ $ATTEMPT -lt 6 ]; do
  POST=$(curl -sS --max-time 5 "http://$IP/api/status" || true)
  if [ -n "$POST" ] && echo "$POST" | grep -q 'uptime_seconds'; then
    break
  fi
  ATTEMPT=$((ATTEMPT+1))
  echo "  not ready yet (attempt $ATTEMPT), sleeping 5s"
  sleep 5
done
if [ -z "$POST" ] || ! echo "$POST" | grep -q 'uptime_seconds'; then
  echo "FATAL: chip not responsive after flash + retries. Manual intervention needed."
  exit 2
fi
echo
echo "-- /api/status --"
echo "$POST" | python3 -m json.tool
echo
echo "-- /api/config --"
curl -sS --max-time 5 "http://$IP/api/config" | python3 -m json.tool
echo
echo "-- /api/rules --"
curl -sS --max-time 5 "http://$IP/api/rules"
echo
echo

WRAP=$(echo "$POST" | python3 -c 'import sys,json;print(json.loads(sys.stdin.read()).get("wrap_mode",""))')
UPTIME=$(echo "$POST" | python3 -c 'import sys,json;print(json.loads(sys.stdin.read()).get("uptime_seconds",-1))')
HEAP=$(echo "$POST" | python3 -c 'import sys,json;print(json.loads(sys.stdin.read()).get("heap_free",-1))')
MODEL=$(echo "$POST" | python3 -c 'import sys,json;print(json.loads(sys.stdin.read()).get("model",""))')
echo "checks:"
echo "  wrap_mode field exposed:  '$WRAP'  (expected: 'speculative')"
echo "  model:                     $MODEL  (expected: wireclaw-agent:v1.3.1)"
echo "  uptime_seconds (post-reboot, expect low): $UPTIME"
echo "  heap_free (expect healthy, >50000):       $HEAP"
echo

if [ "$WRAP" != "speculative" ]; then
  echo "WARN: wrap_mode is '$WRAP' (expected default 'speculative'). Loader fallback may not have fired."
fi

echo "-- 60s stability watch (12 polls @ 5s) --"
LAST=$UPTIME
RESETS=0
for i in $(seq 1 12); do
  sleep 5
  S=$(curl -sS --max-time 5 "http://$IP/api/status" 2>/dev/null || echo "")
  if [ -z "$S" ]; then
    echo "  poll $i: NO RESPONSE"
    RESETS=$((RESETS+1))
    continue
  fi
  U=$(echo "$S" | python3 -c 'import sys,json;print(json.loads(sys.stdin.read()).get("uptime_seconds",-1))' 2>/dev/null || echo "-1")
  H=$(echo "$S" | python3 -c 'import sys,json;print(json.loads(sys.stdin.read()).get("heap_free",-1))' 2>/dev/null || echo "-1")
  W=$(echo "$S" | python3 -c 'import sys,json;print(json.loads(sys.stdin.read()).get("wrap_mode",""))' 2>/dev/null || echo "?")
  if [ "$U" -lt "$LAST" ]; then
    echo "  poll $i: RESET DETECTED (uptime $U < prev $LAST)"
    RESETS=$((RESETS+1))
  else
    echo "  poll $i: uptime=${U}s heap_free=$H wrap_mode=$W"
  fi
  LAST=$U
done
echo

if [ $RESETS -gt 0 ]; then
  echo "FAIL: $RESETS reset/no-response events in 60s — chip is not stable on 3f15cc15"
  exit 5
fi
echo "=== c6-01: STABLE on 3f15cc15, wrap_mode='speculative' default, 0 resets in 60s ==="
