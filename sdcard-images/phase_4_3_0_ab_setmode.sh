#!/bin/bash
# Phase 4.3.0.F: flip c6-01 wrap_mode + reboot + verify.
# Usage: phase_4_3_0_ab_setmode.sh speculative|grounded
set -u
MODE="${1:?need 'speculative' or 'grounded'}"
IP=192.168.1.19

case "$MODE" in
  speculative|grounded) ;;
  *) echo "FATAL: mode must be 'speculative' or 'grounded'"; exit 2 ;;
esac

echo "[set-mode] target: $MODE"
echo "[set-mode] POST /api/config"
R=$(curl -sS --max-time 10 -X POST "http://$IP/api/config" \
       -H 'Content-Type: application/json' \
       -d "{\"wrap_mode\":\"$MODE\"}")
echo "  resp: $R"
echo "$R" | grep -q '"ok":true' || { echo "FATAL: config POST did not ok"; exit 3; }

echo "[set-mode] POST /api/reboot"
curl -sS --max-time 10 -X POST "http://$IP/api/reboot" || true
echo

echo "[set-mode] waiting 60s for reboot..."
sleep 60

# Poll up to 30s more in case WiFi reassoc is slow
ATTEMPT=0
while [ $ATTEMPT -lt 6 ]; do
  S=$(curl -sS --max-time 5 "http://$IP/api/status" || true)
  if [ -n "$S" ] && echo "$S" | grep -q uptime_seconds; then
    break
  fi
  ATTEMPT=$((ATTEMPT+1))
  echo "  not ready (attempt $ATTEMPT), sleep 5"
  sleep 5
done
[ -z "${S:-}" ] && { echo "FATAL: chip not responsive"; exit 4; }

W=$(echo "$S" | python3 -c 'import sys,json;print(json.loads(sys.stdin.read()).get("wrap_mode",""))')
echo "[set-mode] /api/status wrap_mode = '$W'"
if [ "$W" != "$MODE" ]; then
  echo "FATAL: wrap_mode is '$W', expected '$MODE'"
  exit 5
fi
echo "[set-mode] OK — c6-01 now on wrap_mode='$MODE'"
