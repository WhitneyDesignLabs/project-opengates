#!/bin/bash
# Phase 4.2.1.H.1 pre-flight verification — chips + Pis + azza.
set -u
K=$HOME/.ssh/evobot_ed25519
SSH="ssh -i $K -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=8"

echo "=== H.1a chip liveness (HTTP /api/status) ==="
for ip in 192.168.1.15 192.168.1.47 192.168.1.19; do
  printf "chip %-13s  " "$ip"
  R=$(curl -sS --max-time 5 "http://$ip/api/status" 2>/dev/null)
  if [ -z "$R" ]; then
    echo "DOWN"
  else
    echo "$R" | python3 -c 'import sys,json;d=json.loads(sys.stdin.read());print(f"v{d.get(\"version\")} | model={d.get(\"model\")} | uptime={d.get(\"uptime\")} | heap_free={d.get(\"heap_free\")} | rssi={d.get(\"wifi_rssi\")}")'
  fi
done

echo
echo "=== H.1b Pi reachability + capture script presence ==="
for spec in evobot:192.168.1.51 pi02:192.168.1.17 pi03:192.168.1.44; do
  name=${spec%%:*}; ip=${spec##*:}
  echo "--- $name ($ip) ---"
  $SSH "scott@$ip" "hostname; ls -la ~/wireclaw-phase31/bench/fork/lora/overnight_capture.sh 2>&1 | head -1; ls ~/.telethon-*.session 2>&1 | head -1; date '+now: %F %T %Z'; date -d 'tomorrow 06:00' '+stop target: %F %T %Z'"
  echo
done

echo "=== H.1c azza Ollama tags ==="
ssh -o BatchMode=yes -o ConnectTimeout=10 azza@azza.tail63f48.ts.net "ollama list | grep -E '(NAME|wireclaw)'"
