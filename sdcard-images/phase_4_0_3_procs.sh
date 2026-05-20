#!/bin/bash
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
for ip in 192.168.1.17 192.168.1.44; do
  echo "==== $ip ===="
  $SSH scott@"$ip" 'pgrep -af "[p]ersona_runner|[o]vernight_capture" || echo none-running' 2>&1
done
