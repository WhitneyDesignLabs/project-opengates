#!/bin/bash
# scp v11_launch_remote.sh to pi02 + pi03, run it there (argv = /tmp path,
# so the internal real-loop guard is accurate). Path A: NOT evobot/pilot.
set -u
K="$HOME/.ssh/evobot_ed25519"
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
SC="scp -q -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
SRC=/mnt/c/Users/homet/Documents/WireClaw/sdcard-images/v11_launch_remote.sh

for ipl in "pi02:192.168.1.17" "pi03:192.168.1.44"; do
  l=${ipl%%:*}; ip=${ipl##*:}
  echo "================= launch $l ($ip) ================="
  tr -d '\r' < "$SRC" > /tmp/v11lr.sh
  $SC /tmp/v11lr.sh scott@$ip:/tmp/v11_launch_remote.sh 2>&1 && echo "(scp ok)" || echo "(scp FAIL)"
  $S scott@$ip 'bash /tmp/v11_launch_remote.sh' 2>&1
done
