#!/bin/bash
# Phase 3.3.4 connectivity preflight: confirm SSH to evobot/pi02/pi03/azza,
# re-resolve DHCP pi IPs, confirm chip IPs reachable from their paired Pis.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
EVO="ssh -o BatchMode=yes -o ConnectTimeout=8 evobot"
A="ssh -o BatchMode=yes -o ConnectTimeout=8 azza@192.168.1.60"

echo "== resolve pi02/pi03 (DHCP) =="
timeout 10 getent ahostsv4 pi02.local pi03.local 2>/dev/null | awk '{print $1, $NF}' | sort -u
echo "== evobot =="
$EVO 'hostname; whoami' 2>&1
echo "== pi02 (192.168.1.17) =="
$SSH scott@192.168.1.17 'hostname; whoami' 2>&1
echo "== pi03 (192.168.1.44) =="
$SSH scott@192.168.1.44 'hostname; whoami' 2>&1
echo "== azza =="
$A 'hostname; whoami' 2>&1
echo "== chip reachability from evobot (c6-pilot .19) =="
$EVO 'for ip in 192.168.1.19 192.168.1.15 192.168.1.47; do printf "%s " $ip; ping -c1 -W2 $ip >/dev/null 2>&1 && echo PING_UP || echo PING_DOWN; done' 2>&1
