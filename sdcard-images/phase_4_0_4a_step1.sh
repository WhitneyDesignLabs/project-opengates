#!/bin/bash
# Phase 4.0.4a Step 1: hunt the mystery Telegram sender.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $K"
AZ="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 azza@azza.tail63f48.ts.net"

echo "########## (a) capture runners on Pis ##########"
for ip in 192.168.1.17 192.168.1.44; do
  echo "=== $ip ==="
  $SSH scott@"$ip" 'pgrep -af "[o]vernight_capture.sh" || echo "no overnight_capture"; pgrep -af "[p]ersona_runner.py" || echo "no persona_runner"; pgrep -af "[t]elethon\|[s]end_persona\|[d]river" || echo "no telethon/driver procs"' 2>&1
done

echo "########## (b) stale telethon session files (pi02/pi03) ##########"
for ip in 192.168.1.17 192.168.1.44; do
  echo "=== $ip ==="
  $SSH scott@"$ip" 'ls -la ~/.telethon-*.session* 2>/dev/null; ls -la ~/wireclaw-phase31/.telethon-*.session* 2>/dev/null; find ~ -maxdepth 4 -name "*.session" 2>/dev/null | head; echo "(end)"' 2>&1
done

echo "########## (b2) telethon sessions on azza ##########"
$AZ 'find ~ -maxdepth 5 -name "*.session*" 2>/dev/null | head; echo "(end azza)"' 2>&1 || echo "azza unreachable"

echo "########## (c) azza proxy log — recent client IPs ##########"
$AZ 'D=$(date -u +%Y-%m-%d); DIR=~/wireclaw-corpus/ollama-raw/$D; echo "dir=$DIR"; ls -lt "$DIR" 2>/dev/null | head -8; for f in $(ls -t "$DIR"/*.json 2>/dev/null | head -12); do python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d.get(\"ts\"),d.get(\"client_ip\"),d.get(\"path\"))" "$f" 2>/dev/null; done' 2>&1 || echo "azza unreachable"

echo "########## (d) per-chip telegram endpoint ##########"
for ipc in "192.168.1.15:c6-02:192.168.1.17" "192.168.1.47:c6-03:192.168.1.44"; do
  CHIP_IP="${ipc%%:*}"; rest="${ipc#*:}"; NAME="${rest%%:*}"; PI="${ipc##*:}"
  echo "=== $NAME ($CHIP_IP) ==="
  $SSH scott@"$PI" "curl -sS -m5 http://$CHIP_IP/api/telegram 2>/dev/null || echo 'no /api/telegram'; echo; curl -sS -m5 http://$CHIP_IP/api/status 2>/dev/null | grep -oE '\"uptime\":\"[^\"]*\"|\"telegram\":\"[^\"]*\"'" 2>&1
done
