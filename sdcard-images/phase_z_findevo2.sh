#!/bin/bash
# Post real-SD-swap: locate evobot from pi03 (native LAN). Retry ~5 min for
# first boot (SD may fsck/resize). Identify by mDNS, else ssh-from-pi03 using
# the fleet key if pi03 has it, else report candidate Pi-OUI hosts.
set -u
K="$HOME/.ssh/evobot_ed25519"
P3="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K scott@192.168.1.44"

$P3 'bash -s' <<'REMOTE' 2>&1
set -u
found=""
for r in $(seq 1 15); do   # ~5 min
  ip=$(getent hosts evobot.local 2>/dev/null | awk 'NR==1{print $1}')
  [ -z "$ip" ] && command -v avahi-resolve-host-name >/dev/null && \
     ip=$(avahi-resolve-host-name -4 evobot.local 2>/dev/null | awk '{print $2}')
  if [ -n "$ip" ] && ping -c1 -W2 "$ip" >/dev/null 2>&1; then found="$ip"; break; fi
  echo "[r$r] evobot.local not up yet…"; sleep 18
done
if [ -z "$found" ]; then
  echo "RESULT: evobot.local STILL not resolving after ~5 min."
  echo "Live Pi-OUI hosts (b8:27:eb/d8:3a:dd/dc:a6:32/e4:5f:01/2c:cf:67), for Scott to eyeball:"
  for i in $(seq 2 254); do ping -c1 -W1 192.168.1.$i >/dev/null 2>&1 & done; wait; sleep 1
  ip neigh show | grep -iE 'b8:27:eb|d8:3a:dd|dc:a6:32|e4:5f:01|2c:cf:67' | awk '{print "  ",$1,$5}'
  exit 1
fi
echo "RESULT: evobot.local -> $found"
echo "$found"
REMOTE
