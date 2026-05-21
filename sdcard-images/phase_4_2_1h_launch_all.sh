#!/bin/bash
# H.4 driver: scp phase_4_2_1h_pilaunch.sh to each Pi then exec.
# Logs each Pi's launch output sequentially.
set -u
K=$HOME/.ssh/evobot_ed25519
SSH="ssh -i $K -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10"
SCP="scp -i $K -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10"
SCRIPT=/mnt/c/Users/homet/Documents/WireClaw/sdcard-images/phase_4_2_1h_pilaunch.sh

for ip in 192.168.1.51 192.168.1.17 192.168.1.44; do
  echo "============================================================"
  echo "  $ip  launching..."
  echo "============================================================"
  $SCP "$SCRIPT" "scott@$ip:~/phase_4_2_1h_pilaunch.sh"
  $SSH "scott@$ip" "chmod +x ~/phase_4_2_1h_pilaunch.sh && bash ~/phase_4_2_1h_pilaunch.sh"
  echo
done
echo "all launches dispatched."
