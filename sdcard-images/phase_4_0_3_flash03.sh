#!/bin/bash
# Phase 4.0.3 (pivot): stage + component-flash c6-03 via pi03 over its
# native USB-JTAG. Same validated recipe as c6-02:
#   esptool venv v5, --no-stub --flash-size detect, NO --baud,
#   port resolved from the stable Espressif by-id (c6-03 MAC 98:A3:16:97:DB:4C).
set -eu
K="$HOME/.ssh/evobot_ed25519"
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=12 -i $K"
SCP="scp -q -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=12 -i $K"
B=/mnt/c/Users/homet/Documents/WireClaw-fork/.pio/build/esp32-c6
BA=/mnt/c/Users/homet/.platformio/packages/framework-arduinoespressif32/tools/partitions/boot_app0.bin

echo "[stage] -> pi03:~/fw-4.0.3/"
$S scott@192.168.1.44 'mkdir -p ~/fw-4.0.3'
$SCP "$B/bootloader.bin" "$B/partitions.bin" "$B/firmware.bin" "$BA" scott@192.168.1.44:'~/fw-4.0.3/'
echo "[stage] local firmware.bin sha256:"; sha256sum "$B/firmware.bin"

$S scott@192.168.1.44 "bash -s" <<'REMOTE'
set -u
echo "[flash] pi03 sha256:"; sha256sum ~/fw-4.0.3/firmware.bin
pkill -f 'uart-c6-03-cap' 2>/dev/null; pkill -f jtag-serial-capture-loop 2>/dev/null; sleep 2
BYID=$(ls /dev/serial/by-id/usb-Espressif_USB_JTAG_serial_debug_unit_98:A3:16:97:DB:4C-if00 2>/dev/null | head -1)
PORT=$(readlink -f "$BYID" 2>/dev/null)
echo "[flash] BYID=$BYID  PORT=$PORT"
[ -z "$PORT" ] && { echo "FATAL: c6-03 Espressif USB-JTAG not found on pi03"; exit 2; }
~/esptool-venv/bin/esptool --chip esp32c6 --port "$PORT" --no-stub \
  --before default-reset --after hard-reset write-flash --flash-size detect \
  0x0 ~/fw-4.0.3/bootloader.bin \
  0x8000 ~/fw-4.0.3/partitions.bin \
  0xe000 ~/fw-4.0.3/boot_app0.bin \
  0x10000 ~/fw-4.0.3/firmware.bin 2>&1 | \
  grep -E 'Wrote|Hash of data verified|Hard reset|Staying|error|Error|Flash will be erased' | tail -20
echo "[flash] done"
REMOTE
