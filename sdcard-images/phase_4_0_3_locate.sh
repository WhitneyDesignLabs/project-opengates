#!/bin/bash
# Phase 4.0.3: locate c6-02's two USB interfaces by STABLE by-id name,
# wherever they enumerated. c6-02 IDs:
#   CH343/UART0 : usb-1a86_USB_Single_Serial_5B91079021-if00
#   nativeJTAG  : usb-Espressif_USB_JTAG_serial_debug_unit_E8:F6:0A:FB:FB:00-if00
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $K"

look() {
  local IP=$1 NAME=$2
  echo "==== $NAME ($IP) ===="
  $SSH scott@"$IP" '
    echo "-- by-id --"; ls -l /dev/serial/by-id/ 2>/dev/null | grep -E "1a86_USB_Single_Serial_5B91079021|Espressif_USB_JTAG.*E8:F6:0A:FB:FB:00" || echo "  (c6-02 devices not here)";
    CH=$(ls /dev/serial/by-id/usb-1a86_USB_Single_Serial_5B91079021-if00 2>/dev/null);
    JT=$(ls /dev/serial/by-id/usb-Espressif_USB_JTAG_serial_debug_unit_E8:F6:0A:FB:FB:00-if00 2>/dev/null);
    [ -n "$CH" ] && echo "CH343/UART0 -> $(readlink -f "$CH")";
    [ -n "$JT" ] && echo "nativeJTAG  -> $(readlink -f "$JT")";
    echo "-- net --";
    ping -c1 -W2 192.168.1.15 >/dev/null 2>&1 && echo "c6-02 192.168.1.15 PING-OK" || echo "c6-02 192.168.1.15 PING-FAIL";
    curl -s -m5 -o /dev/null -w "c6-02 HTTP=%{http_code}\n" http://192.168.1.15/api/status' 2>&1
}

look 192.168.1.17 pi02
look 192.168.1.44 pi03
