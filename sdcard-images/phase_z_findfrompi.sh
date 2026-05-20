#!/bin/bash
# Discover the swapped EvoBot from pi03 (native LAN host — WSL can't ARP-sweep).
# pi03 does: mDNS resolve, ARP sweep, nmap-ish ssh probe for hostname=evobot,
# and checks c6-pilot (.19) reachability from the LAN.
set -u
K="$HOME/.ssh/evobot_ed25519"
P3="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K scott@192.168.1.44"

$P3 'bash -s' <<'REMOTE' 2>&1
set -u
echo "== from pi03 ($(hostname)) =="
echo "-- mDNS evobot.local --"
getent ahostsv4 evobot.local 2>/dev/null | awk "NR==1{print \$1}" || echo "(no mDNS)"
echo "-- ARP sweep /24 --"
for i in $(seq 2 254); do ping -c1 -W1 192.168.1.$i >/dev/null 2>&1 & done; wait; sleep 1
ip neigh show | grep -E "192\.168\.1\." | awk "{print \$1, \$5}" | sort -t. -k4 -n -u
echo "-- ssh-probe live hosts for hostname=evobot --"
KEY=~/.ssh/evobot_ed25519
[ -f "$KEY" ] || KEY=~/.ssh/id_ed25519
for cand in $(ip neigh show | awk "/192\.168\.1\./{print \$1}" | sort -t. -k4 -n -u); do
  hn=$(timeout 6 ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -i "$KEY" scott@$cand hostname 2>/dev/null </dev/null)
  [ -n "$hn" ] && echo "   $cand -> $hn"
  [ "$hn" = evobot ] && echo "   *** EVOBOT at $cand ***"
done
echo "-- c6-pilot chip .19 from LAN --"
ping -c2 -W2 192.168.1.19 >/dev/null 2>&1 && echo "  .19 PING_UP" || echo "  .19 PING_DOWN"
curl -s -m6 -o /dev/null -w "  .19 /api/status HTTP %{http_code}\n" http://192.168.1.19/api/status 2>/dev/null || echo "  .19 HTTP no-response"
REMOTE
