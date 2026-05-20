#!/bin/bash
set -u
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $HOME/.ssh/evobot_ed25519"
$S scott@192.168.1.22 'echo -n "c6-pilot .19 ping: "; ping -c2 -W2 192.168.1.19 >/dev/null 2>&1 && echo UP || echo DOWN
echo -n "/api/status HTTP: "; curl -s -o /tmp/p.txt -w "%{http_code}" -m6 http://192.168.1.19/api/status 2>/dev/null; echo
echo "body:"; head -c 300 /tmp/p.txt 2>/dev/null; echo
echo -n "root HTTP: "; curl -s -o /dev/null -w "%{http_code}" -m6 http://192.168.1.19/ 2>/dev/null; echo' 2>&1
