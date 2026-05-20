#!/bin/bash
# Phase 3.3.4 NPRE re-run post SD-swap. evobot=192.168.1.22(new Pi3B),
# pi02=.17, pi03=.44, azza=.60. Chips probed from paired Pis.
set -u
K="$HOME/.ssh/evobot_ed25519"
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
EVO="$S scott@192.168.1.22"
P2="$S scott@192.168.1.17"
P3="$S scott@192.168.1.44"
A="ssh -o BatchMode=yes -o ConnectTimeout=8 azza@192.168.1.60"

pi() { echo "===== $2 ====="; $1 'echo "host=$(hostname) ip=$(hostname -I|awk "{print \$1}") model=$(grep -m1 Model /proc/cpuinfo|cut -d: -f2)"
  echo -n "uptime: "; uptime -p
  echo "last reboot:"; last reboot 2>/dev/null|head -2
  echo -n "THROTTLE: "; vcgencmd get_throttled 2>/dev/null
  echo -n "volts: "; vcgencmd measure_volts core 2>/dev/null
  echo -n "temp: "; vcgencmd measure_temp 2>/dev/null
  free -h|awk "/Mem:/{print \"mem free=\"\$4\"/\"\$2}"
  df -h /|tail -1|awk "{print \"disk free=\"\$4}"
  echo -n "telethon: "; ls ~/.telethon-*.session 2>/dev/null|tr "\n" " "; echo
  echo -n "overnight_capture.sh: "; ls ~/wireclaw-phase31/bench/fork/lora/overnight_capture.sh 2>/dev/null||echo MISSING
  dmesg 2>/dev/null|grep -iE "under-voltage|undervoltage|panic|oom"|tail -3||echo "dmesg: (clean/restricted)"' 2>&1; }

echo "############ PRE.1 driver Pis ############"
pi "$EVO" "EvoBot (NEW Pi3B @192.168.1.22, c6-pilot driver)"
pi "$P2"  "pi02 @192.168.1.17 (c6-02 driver)"
pi "$P3"  "pi03 @192.168.1.44 (c6-03 driver)"

echo
echo "############ PRE.2 chips (from paired Pi) ############"
cp() { echo "===== $3 ($2) via $4 ====="; $1 "ping -c2 -W2 $2 >/dev/null 2>&1 && echo PING_UP || echo PING_DOWN
  curl -s -m6 http://$2/api/status 2>/dev/null | head -c 400; echo
  curl -s -o /dev/null -w 'root HTTP=%{http_code}\n' -m6 http://$2/ 2>/dev/null" 2>&1; }
cp "$EVO" 192.168.1.19 c6-pilot EvoBot
cp "$P2"  192.168.1.15 c6-02   pi02
cp "$P3"  192.168.1.47 c6-03   pi03

echo
echo "############ PRE.3 azza ############"
$A 'uptime -p; systemctl is-active ollama; ollama list 2>&1|grep -E "wireclaw|llama3.1:8b"; nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader; systemctl --user is-active wireclaw-ollama-proxy.service 2>/dev/null; df -h /home|tail -1|awk "{print \"disk=\"\$4\" free\"}"' 2>&1

echo
echo "############ PRE.4 c6-pilot reboot diag (from EvoBot) ############"
$EVO 'echo "serial devs:"; ls /dev/ttyACM* /dev/ttyUSB* 2>/dev/null||echo "(none)"
  echo "crash/reset endpoints:"; curl -s -m6 http://192.168.1.19/api/crash_history 2>/dev/null|head -c300; echo
  curl -s -m6 http://192.168.1.19/api/reset_reason 2>/dev/null|head -c200; echo
  echo "full status:"; curl -s -m6 http://192.168.1.19/api/status 2>/dev/null|python3 -m json.tool 2>/dev/null|head -20' 2>&1
