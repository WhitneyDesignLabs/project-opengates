#!/bin/bash
# Phase 4.3.0.H.2 — flip c6-01 chip's `/api/config` model field to point at
# wireclaw-agent:v1.3.1-grounded (the new Modelfile-side wrap-policy tag).
#
# Idempotent, with verification + 60s post-reboot stability watch.
# Mirrors phase_4_2_1g_promote_chip.sh shape; targets c6-01 specifically
# since H.4 is single-chip scope (c6-02 / c6-03 stay on :v1.3.1 production).
#
# Usage: phase_4_3_0h_promote_chip.sh
set -u
LABEL="c6-01"
IP="192.168.1.19"
NEW_MODEL="wireclaw-agent:v1.3.1-grounded"
OLD_MODEL="wireclaw-agent:v1.3.1"

echo "=== promote ${LABEL} @ ${IP}: ${OLD_MODEL} -> ${NEW_MODEL} ==="
echo
echo "-- pre-state"
PRE_STATUS=$(curl -sS --max-time 10 "http://${IP}/api/status")
PRE_CFG=$(curl -sS --max-time 10 "http://${IP}/api/config")
echo "status : ${PRE_STATUS}"
echo "config : ${PRE_CFG}"
PRE_MODEL=$(echo "${PRE_CFG}" | python3 -c 'import sys,json; print(json.loads(sys.stdin.read()).get("model",""))')
PRE_WRAP=$(echo "${PRE_CFG}"  | python3 -c 'import sys,json; print(json.loads(sys.stdin.read()).get("wrap_mode",""))')
if [ "${PRE_MODEL}" != "${OLD_MODEL}" ]; then
  echo "WARN: pre-state model is '${PRE_MODEL}' (expected '${OLD_MODEL}') — proceeding but flagging"
fi
if [ "${PRE_WRAP}" != "speculative" ]; then
  echo "WARN: pre-state wrap_mode is '${PRE_WRAP}' (expected 'speculative' — H.4.1 should run first)"
fi
echo

echo "-- POST /api/config {\"model\":\"${NEW_MODEL}\"}"
CFG_RESP=$(curl -sS --max-time 10 -X POST "http://${IP}/api/config" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${NEW_MODEL}\"}")
echo "resp: ${CFG_RESP}"
if ! echo "${CFG_RESP}" | grep -q '"ok":true'; then
  echo "FATAL: POST /api/config did not return ok:true. Aborting."
  exit 2
fi
echo

echo "-- POST /api/reboot"
curl -sS --max-time 10 -X POST "http://${IP}/api/reboot" || true
echo

echo "-- waiting 75s for reboot + WiFi reassoc..."
sleep 75

echo "-- post-reboot poll (up to 30s extra wakeup retry)"
ATTEMPT=0
POST_STATUS=""
while [ $ATTEMPT -lt 6 ]; do
  POST_STATUS=$(curl -sS --max-time 5 "http://${IP}/api/status" || true)
  if [ -n "${POST_STATUS}" ] && echo "${POST_STATUS}" | grep -q "uptime_seconds"; then
    break
  fi
  ATTEMPT=$((ATTEMPT+1))
  echo "  not ready yet (attempt ${ATTEMPT}), sleeping 5s"
  sleep 5
done
if [ -z "${POST_STATUS}" ] || ! echo "${POST_STATUS}" | grep -q "uptime_seconds"; then
  echo "FATAL: chip not responsive after reboot + retries. Manual intervention needed."
  exit 3
fi

POST_CFG=$(curl -sS --max-time 10 "http://${IP}/api/config")
echo "post status : ${POST_STATUS}"
echo "post config : ${POST_CFG}"
POST_MODEL=$(echo "${POST_CFG}"  | python3 -c 'import sys,json; print(json.loads(sys.stdin.read()).get("model",""))')
POST_WRAP=$(echo "${POST_CFG}"   | python3 -c 'import sys,json; print(json.loads(sys.stdin.read()).get("wrap_mode",""))')
POST_UPTIME=$(echo "${POST_STATUS}" | python3 -c 'import sys,json; print(json.loads(sys.stdin.read()).get("uptime_seconds",-1))')
POST_HEAP=$(echo "${POST_STATUS}"   | python3 -c 'import sys,json; print(json.loads(sys.stdin.read()).get("heap_free",-1))')
echo "post model field   : ${POST_MODEL}"
echo "post wrap_mode     : ${POST_WRAP}"
echo "post uptime_seconds: ${POST_UPTIME}   (low = recent reboot, expected)"
echo "post heap_free     : ${POST_HEAP}"
echo
if [ "${POST_MODEL}" != "${NEW_MODEL}" ]; then
  echo "FATAL: post-reboot model is '${POST_MODEL}' (expected '${NEW_MODEL}')"
  exit 4
fi
if [ "${POST_WRAP}" != "speculative" ]; then
  echo "FATAL: post-reboot wrap_mode is '${POST_WRAP}' (expected 'speculative')"
  exit 6
fi
if [ "${POST_HEAP}" -lt 50000 ]; then
  echo "WARN: post-reboot heap_free ${POST_HEAP} is below 50000 threshold"
fi
echo

echo "-- 60s stability watch (12 polls @ 5s, expect uptime monotonic + no resets)"
LAST_UPTIME=${POST_UPTIME}
RESETS=0
for i in $(seq 1 12); do
  sleep 5
  S=$(curl -sS --max-time 5 "http://${IP}/api/status" 2>/dev/null || echo "")
  if [ -z "${S}" ]; then
    echo "  poll ${i}: NO RESPONSE"
    RESETS=$((RESETS+1))
    continue
  fi
  U=$(echo "${S}" | python3 -c 'import sys,json; print(json.loads(sys.stdin.read()).get("uptime_seconds",-1))' 2>/dev/null || echo "-1")
  H=$(echo "${S}" | python3 -c 'import sys,json; print(json.loads(sys.stdin.read()).get("heap_free",-1))' 2>/dev/null || echo "-1")
  if [ "${U}" -lt "${LAST_UPTIME}" ]; then
    echo "  poll ${i}: RESET DETECTED (uptime ${U} < prev ${LAST_UPTIME})"
    RESETS=$((RESETS+1))
  else
    echo "  poll ${i}: uptime=${U}s heap_free=${H}"
  fi
  LAST_UPTIME=${U}
done
echo
if [ ${RESETS} -gt 0 ]; then
  echo "FAIL: ${RESETS} reset/no-response events in 60s — chip is not stable on ${NEW_MODEL}"
  exit 5
fi
echo "=== ${LABEL}: STABLE on ${NEW_MODEL} (wrap_mode=speculative), uptime climbing, heap healthy, 0 resets in 60s ==="
