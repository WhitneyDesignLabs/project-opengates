#!/bin/bash
# Phase 4.4.0.E.2 — flip c6-01's /api/config model field between arms.
# Adapted from phase_4_3_0h_flip_chip.sh: treatment is now v1.3.2 (not
# v1.3.1-grounded). Always preserves wrap_mode=speculative and verifies
# post-reboot stability. Run ON evobot (LAN-only chip).
#
# Usage: phase_4_4_0e_flip_chip.sh control|treatment
set -u
ARM="${1:?need 'control' or 'treatment'}"
IP="192.168.1.19"
case "$ARM" in
  control)   NEW_MODEL="wireclaw-agent:v1.3.1" ;;
  treatment) NEW_MODEL="wireclaw-agent:v1.3.2" ;;
  *) echo "FATAL: arm must be 'control' or 'treatment'"; exit 2 ;;
esac

echo "=== flip c6-01 @ $IP to arm=$ARM (model=$NEW_MODEL, wrap_mode=speculative) ==="
echo

echo "-- pre-state"
PRE_CFG=$(curl -sS --max-time 10 "http://${IP}/api/config")
echo "config: ${PRE_CFG}"
echo

echo "-- POST /api/config {\"model\":\"${NEW_MODEL}\"}"
CFG_RESP=$(curl -sS --max-time 10 -X POST "http://${IP}/api/config" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${NEW_MODEL}\"}")
echo "resp: ${CFG_RESP}"
echo "${CFG_RESP}" | grep -q '"ok":true' || { echo "FATAL: POST did not ok"; exit 3; }
echo

echo "-- POST /api/reboot"
curl -sS --max-time 10 -X POST "http://${IP}/api/reboot" || true
echo
echo "-- waiting 75s for reboot..."
sleep 75

ATTEMPT=0
POST_STATUS=""
while [ $ATTEMPT -lt 6 ]; do
  POST_STATUS=$(curl -sS --max-time 5 "http://${IP}/api/status" || true)
  if [ -n "${POST_STATUS}" ] && echo "${POST_STATUS}" | grep -q "uptime_seconds"; then
    break
  fi
  ATTEMPT=$((ATTEMPT+1))
  echo "  not ready yet (attempt ${ATTEMPT}), sleep 5s"
  sleep 5
done
[ -z "${POST_STATUS}" ] && { echo "FATAL: chip not responsive after reboot"; exit 4; }

POST_CFG=$(curl -sS --max-time 10 "http://${IP}/api/config")
POST_MODEL=$(echo "${POST_CFG}" | python3 -c 'import sys,json; print(json.loads(sys.stdin.read()).get("model",""))')
POST_WRAP=$(echo  "${POST_CFG}" | python3 -c 'import sys,json; print(json.loads(sys.stdin.read()).get("wrap_mode",""))')
POST_UPTIME=$(echo "${POST_STATUS}" | python3 -c 'import sys,json; print(json.loads(sys.stdin.read()).get("uptime_seconds",-1))')
POST_HEAP=$(echo   "${POST_STATUS}" | python3 -c 'import sys,json; print(json.loads(sys.stdin.read()).get("heap_free",-1))')
echo
echo "post model     : ${POST_MODEL}"
echo "post wrap_mode : ${POST_WRAP}"
echo "post uptime    : ${POST_UPTIME}s"
echo "post heap_free : ${POST_HEAP}"

[ "${POST_MODEL}" = "${NEW_MODEL}" ]      || { echo "FATAL: post model '${POST_MODEL}' != '${NEW_MODEL}'"; exit 5; }
[ "${POST_WRAP}"  = "speculative" ]       || { echo "FATAL: post wrap_mode '${POST_WRAP}' != 'speculative'"; exit 6; }

echo
echo "-- 30s stability watch (6 polls @ 5s)"
LAST=${POST_UPTIME}; RESETS=0
for i in $(seq 1 6); do
  sleep 5
  S=$(curl -sS --max-time 5 "http://${IP}/api/status" 2>/dev/null || echo "")
  [ -z "$S" ] && { echo "  poll $i: NO RESPONSE"; RESETS=$((RESETS+1)); continue; }
  U=$(echo "$S" | python3 -c 'import sys,json; print(json.loads(sys.stdin.read()).get("uptime_seconds",-1))' 2>/dev/null || echo "-1")
  if [ "$U" -lt "$LAST" ]; then
    echo "  poll $i: RESET (uptime $U < prev $LAST)"
    RESETS=$((RESETS+1))
  else
    echo "  poll $i: uptime=${U}s"
  fi
  LAST=$U
done
[ ${RESETS} -gt 0 ] && { echo "FAIL: ${RESETS} resets in 30s"; exit 7; }

echo
echo "=== c6-01: STABLE on arm=${ARM} (model=${NEW_MODEL}, wrap_mode=speculative) ==="
