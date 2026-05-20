#!/bin/bash
# Wait 5 min from c6-pilot power-cycle, then ONE probe of its HTTP API
# from EvoBot (.22, the paired Pi — authoritative path). Emit a clear
# verdict line for the B-vs-A branch.
set -u
sleep 300
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $HOME/.ssh/evobot_ed25519"
$S scott@192.168.1.22 'echo -n "ping .19: "; ping -c2 -W2 192.168.1.19 >/dev/null 2>&1 && echo UP || echo DOWN
code=$(curl -s -o /tmp/ps.txt -w "%{http_code}" -m 8 http://192.168.1.19/api/status 2>/dev/null); echo "/api/status HTTP=$code"
echo "body:"; head -c 400 /tmp/ps.txt 2>/dev/null; echo
root=$(curl -s -o /dev/null -w "%{http_code}" -m 8 http://192.168.1.19/ 2>/dev/null); echo "root HTTP=$root"
if [ "$code" = "200" ]; then echo "VERDICT: PILOT_OK -> full 3-pair (Path B)"; else echo "VERDICT: PILOT_WEDGED -> auto-fall Path A (2-pair)"; fi' 2>&1
