#!/bin/bash
# Disambiguate: is the swapped EvoBot really absent, or is WSL sweep flaky?
# 1) Prove tooling works: directly reach pi02/.17, pi03/.44, chips .15/.47.
# 2) Targeted EvoBot hunt: mDNS, then ssh-probe every live ARP/ping host.
set -u
K="$HOME/.ssh/evobot_ed25519"
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=6 -i $K"

echo "== (1) known fleet still reachable? (tooling sanity) =="
for ipl in "pi02:192.168.1.17" "pi03:192.168.1.44"; do
  l=${ipl%%:*}; ip=${ipl##*:}
  hn=$($S scott@$ip 'hostname' 2>/dev/null </dev/null)
  echo "  $l @ $ip : ssh-hostname='${hn:-NO-RESPONSE}'"
done
for ip in 192.168.1.15 192.168.1.47 192.168.1.19; do
  printf "  chip %s : " $ip; ping -c2 -W2 $ip >/dev/null 2>&1 && echo PING_UP || echo PING_DOWN
done

echo "== (2) evobot.local mDNS (3 tries) =="
for t in 1 2 3; do
  r=$(timeout 6 getent ahostsv4 evobot.local 2>/dev/null | awk 'NR==1{print $1}')
  echo "  try$t: ${r:-none}"; [ -n "$r" ] && break; sleep 3
done

echo "== (3) full ping sweep, then dump ARP table (reliable host list) =="
for i in $(seq 2 254); do ping -c1 -W1 192.168.1.$i >/dev/null 2>&1 & done; wait; sleep 2
echo "  arp/neigh hosts:"; ip neigh show 2>/dev/null | grep -E '192\.168\.1\.' | awk '{print "   ",$1,$5,$NF}' | sort -t. -k4 -n -u

echo "== (4) ssh-probe each live host for hostname=evobot =="
for cand in $(ip neigh show 2>/dev/null | awk '/192\.168\.1\./{print $1}' | sort -t. -k4 -n -u); do
  hn=$(timeout 6 $S scott@$cand 'hostname' 2>/dev/null </dev/null)
  [ -n "$hn" ] && echo "   $cand -> $hn"
  [ "$hn" = evobot ] && echo "   *** EVOBOT FOUND at $cand ***"
done
