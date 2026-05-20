#!/bin/bash
# Locate c6-03's two USB interfaces (by stable by-id) wherever they
# enumerated, and check c6-03 network. c6-03 IDs:
#   CH343/UART0 : usb-1a86_USB_Single_Serial_5C37197442-if00
#   nativeJTAG  : usb-Espressif_USB_JTAG_serial_debug_unit_98:A3:16:97:DB:4C-if00
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
look() {
  local IP=$1 NAME=$2
  echo "==== $NAME ($IP) ===="
  $SSH scott@"$IP" '
    ls -l /dev/serial/by-id/ 2>/dev/null | grep -E "1a86_USB_Single_Serial_5C37197442|Espressif_USB_JTAG.*98:A3:16:97:DB:4C" || echo "  (c6-03 devices not here)";
    JT=$(ls /dev/serial/by-id/usb-Espressif_USB_JTAG_serial_debug_unit_98:A3:16:97:DB:4C-if00 2>/dev/null);
    CH=$(ls /dev/serial/by-id/usb-1a86_USB_Single_Serial_5C37197442-if00 2>/dev/null);
    [ -n "$JT" ] && echo "nativeJTAG -> $(readlink -f "$JT")";
    [ -n "$CH" ] && echo "CH343/UART0 -> $(readlink -f "$CH")";
    ping -c1 -W2 192.168.1.47 >/dev/null 2>&1 && echo "c6-03 .47 PING-OK" || echo "c6-03 .47 PING-FAIL";
    curl -s -m5 -o /dev/null -w "c6-03 HTTP=%{http_code}\n" http://192.168.1.47/api/status' 2>&1
}
look 192.168.1.44 pi03
look 192.168.1.17 pi02
