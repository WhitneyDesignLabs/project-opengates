#!/bin/bash
# Per-Pi pairing config: set BOT_USERNAME + RULE_PURGE_URL in overnight_capture.sh.
# Usage: bash pi_pair_config.sh <bot_username> <chip_ip>
# Run on the target Pi. Script-file form to avoid nested wsl/ssh quoting.
set -euo pipefail
BOT="${1:?usage: pi_pair_config.sh <bot> <chip_ip>}"
CHIP_IP="${2:?usage: pi_pair_config.sh <bot> <chip_ip>}"
W="$HOME/wireclaw-phase31/bench/fork/lora/overnight_capture.sh"
[ -f "$W" ] || { echo "FATAL: $W missing"; exit 1; }

sed -i "s/^BOT_USERNAME=.*/BOT_USERNAME=$BOT/" "$W"
sed -i "s#^RULE_PURGE_URL=.*#RULE_PURGE_URL=\"http://$CHIP_IP/api/rules/delete\"#" "$W"

echo "host=$(hostname)"
echo "secrets_env=$(test -s "$HOME/.wireclaw-secrets.env" && echo present || echo MISSING)"
echo "TG_keys=$(grep -cE '^TG_(API_ID|API_HASH|PHONE)=' "$HOME/.wireclaw-secrets.env" 2>/dev/null || echo 0)/3"
grep -E '^BOT_USERNAME=|^RULE_PURGE_URL=|^SESSION_FILE=' "$W"
