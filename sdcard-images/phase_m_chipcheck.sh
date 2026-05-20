#!/bin/bash
# Authoritative chip reachability: probe each chip FROM its paired Pi (same LAN),
# not from WSL. Distinguishes real chip death vs WSL->LAN routing.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
EVO="ssh -o BatchMode=yes -o ConnectTimeout=8 evobot"
P2="$SSH scott@192.168.1.17"
P3="$SSH scott@192.168.1.44"

probe() {  # $1=ssh-cmd  $2=chip-ip  $3=label
  echo "--- $3 -> chip $2 (from its Pi) ---"
  $1 "ping -c2 -W2 $2 >/dev/null 2>&1 && echo 'ping: UP' || echo 'ping: DOWN';
      code=\$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 http://$2/api/status 2>/dev/null);
      echo \"/api/status HTTP=\${code:-none}\";
      curl -s --max-time 6 http://$2/api/status 2>/dev/null | head -c 300; echo;
      echo -n 'arp: '; ip neigh 2>/dev/null | grep '$2 ' || echo '(no arp entry)'" 2>&1
}
probe "$EVO" 192.168.1.19 EvoBot
probe "$P2"  192.168.1.15 pi02
probe "$P3"  192.168.1.47 pi03

echo
echo "--- EvoBot: any chip on a different IP? (arp scan .1.0/24 for esp/espressif) ---"
$EVO 'for i in $(seq 2 60); do ping -c1 -W1 192.168.1.$i >/dev/null 2>&1 & done; wait; ip neigh | grep -E "192.168.1.(19|15|47) " || echo "(none of .19/.15/.47 in arp)"' 2>&1
