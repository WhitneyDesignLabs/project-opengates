#!/bin/bash
set -u
K=$HOME/.ssh/evobot_ed25519
SSH="ssh -i $K -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=8"
for ip in 192.168.1.51 192.168.1.17 192.168.1.44; do
  N=$($SSH "scott@$ip" "grep -cE '^TG_(API_ID|API_HASH|PHONE)=' ~/.wireclaw-secrets.env 2>/dev/null")
  echo "$ip: $N/3 TG_ vars present"
done
