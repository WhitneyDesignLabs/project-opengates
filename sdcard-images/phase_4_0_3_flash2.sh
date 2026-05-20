#!/bin/bash
# Phase 4.0.3 (pivot): stage rebuilt firmware to pi02 and component-flash
# c6-02 over its native USB-JTAG. Proven-good recipe:
#   esptool (venv v5) --no-stub --flash-size detect, NO --baud,
#   port resolved from the STABLE Espressif by-id symlink (never ttyACMn).
set -eu
K="$HOME/.ssh/evobot_ed25519"
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=12 -i $K"
SCP="scp -q -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=12 -i $K"
B=/mnt/c/Users/homet/Documents/WireClaw-fork/.pio/build/esp32-c6
BA=/mnt/c/Users/homet/.platformio/packages/framework-arduinoespressif32/tools/partitions/boot_app0.bin

echo "[stage] -> pi02:~/fw-4.0.3/"
$S scott@192.168.1.17 'mkdir -p ~/fw-4.0.3'
$SCP "$B/bootloader.bin" "$B/partitions.bin" "$B/firmware.bin" "$BA" scott@192.168.1.17:'~/fw-4.0.3/'
echo "[stage] local firmware.bin sha256:"; sha256sum "$B/firmware.bin"

$S scott@192.168.1.17 "bash -s" <<'REMOTE'
set -u
echo "[flash] sha256 on pi02:"; sha256sum ~/fw-4.0.3/firmware.bin
echo "[flash] stopping any serial-capture loop (esptool needs exclusive port)"
pkill -f jtag-serial-capture-loop 2>/dev/null; sleep 2
BYID=$(ls /dev/serial/by-id/usb-Espressif_USB_JTAG_serial_debug_unit_*-if00 2>/dev/null | head -1)
PORT=$(readlink -f "$BYID" 2>/dev/null)
echo "[flash] BYID=$BYID  PORT=$PORT"
[ -z "$PORT" ] && { echo "FATAL: Espressif USB-JTAG not found"; exit 2; }
~/esptool-venv/bin/esptool --chip esp32c6 --port "$PORT" --no-stub \
  --before default-reset --after hard-reset write-flash --flash-size detect \
  0x0 ~/fw-4.0.3/bootloader.bin \
  0x8000 ~/fw-4.0.3/partitions.bin \
  0xe000 ~/fw-4.0.3/boot_app0.bin \
  0x10000 ~/fw-4.0.3/firmware.bin 2>&1 | \
  grep -E 'Wrote|Hash of data verified|Hard reset|Staying|error|Error|Flash will be erased' | tail -20
echo "[flash] esptool exit=${PIPESTATUS:-?}"
REMOTE
