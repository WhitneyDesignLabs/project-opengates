#!/bin/bash
# Definitive check from pi03 (native LAN): is evobot up? is c6-pilot up?
set -u
K="$HOME/.ssh/evobot_ed25519"
P3="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K scott@192.168.1.44"
$P3 'bash -s' <<'REMOTE' 2>&1
set -u
echo "=== from pi03 ==="
echo "-- evobot.local resolve (getent + avahi) --"
getent hosts evobot.local 2>/dev/null || echo "  getent: NO RESOLVE"
command -v avahi-resolve-host-name >/dev/null && avahi-resolve-host-name -4 evobot.local 2>/dev/null || echo "  avahi: (n/a or no resolve)"
echo "-- ping evobot.local --"
ping -c2 -W2 evobot.local 2>&1 | tail -2
echo "-- c6-pilot chip .19 --"
ping -c3 -W2 192.168.1.19 >/dev/null 2>&1 && echo "  .19 PING_UP" || echo "  .19 PING_DOWN (chip still down)"
curl -s -m6 -o /dev/null -w "  .19 HTTP=%{http_code}\n" http://192.168.1.19/api/status 2>/dev/null || echo "  .19 HTTP no-response"
echo "-- candidate Pi-OUI hosts (b8:27:eb / d8:3a:dd / dc:a6:32 / e4:5f:01 / 2c:cf:67) --"
for i in $(seq 2 254); do ping -c1 -W1 192.168.1.$i >/dev/null 2>&1 & done; wait; sleep 1
ip neigh show | grep -iE "b8:27:eb|d8:3a:dd|dc:a6:32|e4:5f:01|2c:cf:67|e4:5f:01" | awk '{print "   ",$1,$5}'
echo "-- nmap evobot hostname (if nmap present) --"
command -v nmap >/dev/null && (sudo -n nmap -sn 192.168.1.0/24 2>/dev/null | grep -i -B1 evobot || echo "   (nmap no evobot / needs root)") || echo "   (no nmap)"
echo "-- known-good fleet sanity from pi03 --"
ping -c1 -W2 192.168.1.15 >/dev/null 2>&1 && echo "  c6-02 .15 UP" || echo "  c6-02 .15 DOWN"
ping -c1 -W2 192.168.1.47 >/dev/null 2>&1 && echo "  c6-03 .47 UP" || echo "  c6-03 .47 DOWN"
REMOTE
