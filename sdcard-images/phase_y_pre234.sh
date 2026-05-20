#!/bin/bash
# Phase 3.3.4 PRE.2 (chips via paired Pis), PRE.3 (azza), PRE.4 (c6-pilot reboot).
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
EVO="ssh -o BatchMode=yes -o ConnectTimeout=8 evobot"
P2="$SSH scott@192.168.1.17"
P3="$SSH scott@192.168.1.44"
A="ssh -o BatchMode=yes -o ConnectTimeout=8 azza@192.168.1.60"

echo "############ PRE.2 — chips probed FROM their paired Pi ############"
chipprobe() {  # $1 ssh-cmd  $2 chip-ip  $3 label
  echo "===== $3 ($2) — via its Pi ====="
  $1 "echo -n 'ping: '; ping -c1 -W2 $2 >/dev/null 2>&1 && echo UP || echo DOWN
      echo -n '/api/status HTTP: '; curl -s -o /tmp/cs.txt -w '%{http_code}' -m 6 http://$2/api/status 2>/dev/null || echo 000; echo
      echo '/api/status body:'; cat /tmp/cs.txt 2>/dev/null | head -c 500; echo
      echo -n '/ root HTTP: '; curl -s -o /dev/null -w '%{http_code}' -m 6 http://$2/ 2>/dev/null || echo 000; echo" 2>&1
}
chipprobe "$EVO" 192.168.1.19 c6-pilot
chipprobe "$P2"  192.168.1.15 c6-02
chipprobe "$P3"  192.168.1.47 c6-03

echo
echo "############ PRE.3 — azza (Ollama + GPU) ############"
$A 'echo "-- uptime --"; uptime
    echo "-- ollama service --"; systemctl status ollama --no-pager 2>/dev/null | head -6 || (ps aux | grep -i "[o]llama" | head -3)
    echo "-- ollama list --"; ollama list 2>&1 | grep -E "^NAME|wireclaw|llama3.1:8b"
    echo "-- GPU --"; nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv 2>&1 | head -3
    echo "-- proxy svc --"; systemctl --user status wireclaw-ollama-proxy.service 2>/dev/null | grep -E "Active:|Main PID:" || echo "(proxy svc state unknown)"
    echo "-- disk /home --"; df -h /home | tail -1' 2>&1

echo
echo "############ PRE.4 — c6-pilot 3.1.3 reboot diagnosis ############"
$EVO 'echo "-- crash/reset endpoints --"
      curl -s -m 6 http://192.168.1.19/api/crash_history 2>/dev/null | head -c 400; echo
      curl -s -m 6 http://192.168.1.19/api/reset_reason 2>/dev/null | head -c 200; echo
      echo "-- full /api/status (uptime/heap/reset) --"
      curl -s -m 6 http://192.168.1.19/api/status 2>/dev/null | python3 -m json.tool 2>/dev/null | head -30
      echo "-- any serial device on EvoBot Pi --"
      ls -la /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "(no serial device attached)"' 2>&1
echo "-- 3.1.3 closeout reference: EvoBot .status.final --"
$EVO 'cat ~/.overnight-capture.status.final 2>/dev/null' 2>&1
