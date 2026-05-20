#!/bin/bash
# Phase 3.3.4 post-swap re-resolve: locate evobot (new Pi 3B = new MAC/IP),
# pi02, pi03, and confirm chip pingability. Robust: ssh-alias, mDNS, /24 sweep.
set -u
K="$HOME/.ssh/evobot_ed25519"
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=6 -i $K"

echo "== mDNS resolve =="
timeout 8 getent ahostsv4 evobot.local pi02.local pi03.local 2>/dev/null | awk '{print $1, $NF}' | sort -u

echo "== /24 sweep then identify Pi-class hosts via SSH hostname =="
for i in $(seq 2 254); do ping -c1 -W1 192.168.1.$i >/dev/null 2>&1 & done; wait; sleep 1
LIVE=$(ip neigh | awk '/192\.168\.1\./{print $1}' | sort -t. -k4 -n -u)
for ip in $LIVE; do
  hn=$($S scott@$ip 'hostname' 2>/dev/null </dev/null)
  [ -z "$hn" ] && hn=$(ssh -o BatchMode=yes -o ConnectTimeout=5 evobot 'hostname' 2>/dev/null </dev/null && echo "(via evobot-alias)")
  case "$hn" in evobot|pi02|pi03) echo "  PI  $ip -> $hn" ;; esac
done

echo "== ssh evobot alias still works? =="
ssh -o BatchMode=yes -o ConnectTimeout=6 evobot 'echo ALIAS_OK hostname=$(hostname) ip=$(hostname -I | awk "{print \$1}")' 2>&1 </dev/null

echo "== chip ICMP from workstation (best-effort) =="
for ip in 192.168.1.19 192.168.1.15 192.168.1.47; do
  printf "  %s " $ip; ping -c1 -W2 $ip >/dev/null 2>&1 && echo UP || echo "DOWN(ws — will re-test from paired Pi)"
done
