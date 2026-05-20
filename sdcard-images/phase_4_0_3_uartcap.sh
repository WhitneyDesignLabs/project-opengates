#!/bin/bash
# Phase 4.0.3: capture c6-02 CH343/UART0 console on pi02 (the reliable
# port). CH343 is an external bridge -> does NOT drop on chip reset, so
# a single timed cat is sufficient. Resolves the stable by-id symlink.
# Arg: <seconds> (default 45)
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $K"
SECS=${1:-45}

$SSH scott@192.168.1.17 "bash -s" <<REMOTE
set -u
BY=\$(ls /dev/serial/by-id/usb-1a86_USB_Single_Serial_5B91079021-if00 2>/dev/null)
D=\$(readlink -f "\$BY" 2>/dev/null)
echo "CH343 by-id=\$BY -> \$D"
if [ -z "\$D" ] || [ ! -e "\$D" ]; then echo "FATAL: c6-02 CH343 not found on pi02"; exit 2; fi
sudo -n stty -F "\$D" 115200 raw -echo 2>/dev/null
echo "--- ${SECS}s UART0 capture ---"
sudo -n timeout ${SECS} cat "\$D" 2>/dev/null | tr -d '\r'
echo "--- end capture ---"
echo "-- net after capture --"
ping -c1 -W2 192.168.1.15 >/dev/null 2>&1 && echo "PING-OK" || echo "PING-FAIL"
curl -s -m5 -o /dev/null -w "HTTP=%{http_code}\n" http://192.168.1.15/api/status
REMOTE
