#!/bin/bash
# Phase 4.0.2: locate the actual chip serial device node on each Pi.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
P2="$SSH scott@192.168.1.17"
P3="$SSH scott@192.168.1.44"

find_tty() {
  $1 'echo "-- /dev tty candidates --";
      ls -l /dev/ttyUSB* /dev/ttyACM* /dev/ttyCH343USB* /dev/serial/by-id/* 2>/dev/null || echo "none of the usual nodes";
      echo "-- lsusb --"; lsusb 2>/dev/null | grep -iE "ch34|cp210|ftdi|serial|qinheng|wch|1a86|silicon" || lsusb 2>/dev/null;
      echo "-- dmesg usb-serial tail --";
      (dmesg 2>/dev/null || sudo -n dmesg 2>/dev/null) | grep -iE "ch34|cp210|ttyUSB|ttyACM|usb .*serial|disconnect|brown" | tail -8' 2>&1
}

echo "==== pi02 / c6-02 ===="; find_tty "$P2"
echo "==== pi03 / c6-03 ===="; find_tty "$P3"
