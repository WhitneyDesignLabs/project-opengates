#!/bin/bash
# Phase 4.0.3: snapshot the tail of the remote serial capture log.
# Args: <pi_ip> <logfile> [tail_lines] [pre_sleep]
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $K"
IP=${1:?ip}; LOG=${2:?log}; N=${3:-25}; SL=${4:-0}
$SSH scott@"$IP" "sleep $SL; echo \"bytes=\$(wc -c < '$LOG' 2>/dev/null)\"; echo '--- tail $N ---'; tail -n $N '$LOG' 2>/dev/null"
