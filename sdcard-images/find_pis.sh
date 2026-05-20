#!/bin/bash
# Sweep 192.168.1.0/24, then probe each live host's SSH banner / hostname.
# Goal: locate pi02 + pi03 IPv4 after host-key/DHCP churn.
set -u
for i in $(seq 1 254); do
  ping -c1 -W1 "192.168.1.$i" >/dev/null 2>&1 &
done
wait
sleep 1
echo "=== neighbors ==="
ip neigh | grep -E '192\.168\.1\.' | awk '{print $1, $5}' | sort -V -u
echo "=== hostnames (reverse + ssh-keyscan presence) ==="
for ip in $(ip neigh | grep -E '192\.168\.1\.' | awk '{print $1}' | sort -V -u); do
  hn=$(getent hosts "$ip" 2>/dev/null | awk '{print $2}')
  banner=$(timeout 3 bash -c "exec 3<>/dev/tcp/$ip/22 && head -1 <&3" 2>/dev/null)
  [ -n "$banner" ] && echo "$ip  host=${hn:-?}  ssh=${banner}"
done
