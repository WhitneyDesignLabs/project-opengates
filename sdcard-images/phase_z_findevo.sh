#!/bin/bash
# Find the swapped EvoBot Pi 3B (new MAC -> new DHCP IP, still hostname 'evobot').
# Retry up to ~4 min (first boot after SD swap can be slow), via mDNS + sweep+ssh.
set -u
K="$HOME/.ssh/evobot_ed25519"
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -i $K"
KNOWN="192.168.1.17 192.168.1.44"   # pi02, pi03 (skip during evobot hunt)

found=""
for round in $(seq 1 12); do   # 12 * ~20s = ~4 min cap
  # 1) mDNS
  ip=$(timeout 6 getent ahostsv4 evobot.local 2>/dev/null | awk 'NR==1{print $1}')
  if [ -n "$ip" ]; then
    hn=$($S scott@$ip 'hostname' 2>/dev/null </dev/null)
    [ "$hn" = evobot ] && { found=$ip; break; }
  fi
  # 2) sweep + ssh-hostname probe
  for i in $(seq 2 254); do ping -c1 -W1 192.168.1.$i >/dev/null 2>&1 & done; wait
  for cand in $(ip neigh | awk '/192\.168\.1\./{print $1}' | sort -t. -k4 -n -u); do
    case " $KNOWN " in *" $cand "*) continue;; esac
    hn=$(timeout 6 $S scott@$cand 'hostname' 2>/dev/null </dev/null)
    if [ "$hn" = evobot ]; then found=$cand; break; fi
  done
  [ -n "$found" ] && break
  echo "[round $round] evobot not found yet; waiting…"
  sleep 18
done

if [ -z "$found" ]; then
  echo "RESULT: EvoBot (swapped Pi) NOT FOUND after ~4 min."
  echo "live LAN hosts (.x):"; ip neigh | awk '/192\.168\.1\./{print $1}' | sort -t. -k4 -n -u | tr '\n' ' '; echo
  echo "-> swapped Pi likely still booting / no DHCP lease / SD issue. Scott: check Pi LEDs + monitor."
  exit 1
fi
echo "RESULT: EvoBot FOUND at $found"
$S scott@$found 'echo "hostname=$(hostname)  ip=$(hostname -I | awk "{print \$1}")  uptime=$(uptime -p)  kernel=$(uname -r)"
  echo -n "throttle="; vcgencmd get_throttled 2>/dev/null
  echo -n "volts=";    vcgencmd measure_volts core 2>/dev/null
  echo -n "temp=";     vcgencmd measure_temp 2>/dev/null
  echo "cpuinfo model:"; grep -m1 Model /proc/cpuinfo 2>/dev/null
  echo "telethon:"; ls ~/.telethon-evobot.session 2>/dev/null || echo "(missing)"' 2>&1 </dev/null
echo "$found" > /tmp/evobot_ip.txt
