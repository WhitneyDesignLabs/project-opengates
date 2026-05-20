#!/bin/bash
# Phase 4.0.2: reset-surviving capture of the ESP32-C6 USB-Serial-JTAG
# console. The native USB device re-enumerates on every chip reset, so a
# single cat dies after one fragment. Loop-reopen the STABLE by-id
# symlink (udev recreates the same name each enumeration) for ~40s,
# concatenating every window -> catches the panic/backtrace + reset
# reason that prints just before each reboot.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
SCP="scp -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
P2="$SSH scott@192.168.1.17"
P3="$SSH scott@192.168.1.44"
TS=$(date -u +%Y-%m-%dT%H-%M-%SZ)
OUT=/mnt/c/Users/homet/Documents/WireClaw/corpus/serial-captures/$TS
mkdir -p "$OUT"

REMOTE='
BYID=$(ls /dev/serial/by-id/usb-Espressif_USB_JTAG_serial_debug_unit_*-if00 2>/dev/null | head -1);
echo "BYID=$BYID";
: > /tmp/jtag-loop.log;
END=$((SECONDS+40));
while [ $SECONDS -lt $END ]; do
  D=$(readlink -f "$BYID" 2>/dev/null);
  if [ -n "$D" ] && [ -e "$D" ]; then
    sudo -n stty -F "$D" 115200 raw -echo 2>/dev/null;
    sudo -n timeout 6 cat "$D" >> /tmp/jtag-loop.log 2>/dev/null;
  else
    sleep 0.3;
  fi;
done;
echo "captured bytes=$(wc -c < /tmp/jtag-loop.log)"'

grab() {
  local NAME=$1 SSH_CMD=$2 IP=$3
  echo "==== $NAME (40s reopen-loop) ===="
  $SSH_CMD "$REMOTE" 2>&1
  $SCP "scott@${IP}:/tmp/jtag-loop.log" "$OUT/${NAME}.jtagloop.log" 2>&1 | tail -1
}

grab "c6-02" "$P2" "192.168.1.17"
grab "c6-03" "$P3" "192.168.1.44"
echo "=== files ==="; ls -la "$OUT"; echo "OUT=$OUT"
