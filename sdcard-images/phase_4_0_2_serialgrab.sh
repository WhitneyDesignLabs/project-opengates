#!/bin/bash
# Phase 4.0.2: capture chip serial from each Pi.
# Reality vs directive: CH343 enumerates as /dev/ttyACM1 (1a86:55d3,
# = ESP32 UART0 console, survives chip resets -> PRIMARY for reset
# reason + panic). /dev/ttyACM0 = ESP32 native USB-JTAG/serial
# (303a:1001, re-enumerates each reset) -> secondary.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
SCP="scp -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
P2="$SSH scott@192.168.1.17"
P3="$SSH scott@192.168.1.44"
TS=$(date -u +%Y-%m-%dT%H-%M-%SZ)
OUT=/mnt/c/Users/homet/Documents/WireClaw/corpus/serial-captures/$TS
mkdir -p "$OUT"

grab() {
  local NAME=$1 SSH_CMD=$2 IP=$3
  echo "==== $NAME ===="
  $SSH_CMD 'sudo -n stty -F /dev/ttyACM1 115200 raw -echo 2>&1 | head -1;
            sudo -n timeout 45 cat /dev/ttyACM1 > /tmp/s-uart.log 2>/tmp/s-uart.err;
            echo "uart0(ttyACM1) rc=$? bytes=$(wc -c < /tmp/s-uart.log)";
            sudo -n timeout 20 cat /dev/ttyACM0 > /tmp/s-jtag.log 2>/tmp/s-jtag.err;
            echo "native(ttyACM0) rc=$? bytes=$(wc -c < /tmp/s-jtag.log)"' 2>&1
  $SCP "scott@${IP}:/tmp/s-uart.log" "$OUT/${NAME}.uart0.log" 2>&1 | tail -1
  $SCP "scott@${IP}:/tmp/s-jtag.log" "$OUT/${NAME}.usbjtag.log" 2>&1 | tail -1
}

grab "c6-02" "$P2" "192.168.1.17"
grab "c6-03" "$P3" "192.168.1.44"

echo "=== files ==="; ls -la "$OUT"; echo "OUT=$OUT"
