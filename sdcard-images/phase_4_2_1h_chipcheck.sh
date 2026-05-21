#!/bin/bash
# H.1a chip liveness check (variable-eating-safe).
for ip in 192.168.1.15 192.168.1.47 192.168.1.19; do
  printf "chip %s: " "$ip"
  curl -sS --max-time 5 "http://$ip/api/status" 2>/dev/null | \
    grep -oE '"(version|model|uptime|heap_free|wifi_rssi)":[^,}]+' | tr '\n' ' '
  echo
done

echo
echo "--- pi02 + pi03 overnight_capture.sh key vars ---"
K=$HOME/.ssh/evobot_ed25519
SSH="ssh -i $K -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=8"
for spec in pi02:192.168.1.17 pi03:192.168.1.44; do
  name=${spec%%:*}; ip=${spec##*:}
  echo "[$name]"
  $SSH "scott@$ip" "grep -E '^(BOT_USERNAME|SESSION_FILE|RULE_PURGE_URL|PERSONAS|RUNNER|PYTHON)=' ~/wireclaw-phase31/bench/fork/lora/overnight_capture.sh"
  echo
done
