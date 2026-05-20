#!/bin/bash
# Phase 4.0.3 Step 3: JTAG-flash a chip via its paired Pi.
# Resolves the ESP32-C6 native USB-JTAG by its STABLE by-id symlink
# (immune to ttyACMn enumeration flips). Stops the serial-capture loop
# first (esptool needs exclusive port access), flashes, prints verbatim.
# Args: <pi_ip>
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=12 -i $K"
IP=${1:?pi ip}

$SSH scott@"$IP" "bash -s" <<'REMOTE'
set -u
echo "[1] stopping serial-capture loop (esptool needs exclusive port)"
pkill -f jtag-serial-capture-loop 2>/dev/null
sleep 2
BYID=$(ls /dev/serial/by-id/usb-Espressif_USB_JTAG_serial_debug_unit_*-if00 2>/dev/null | head -1)
PORT=$(readlink -f "$BYID" 2>/dev/null)
echo "[2] BYID=$BYID"
echo "    PORT=$PORT"
if [ -z "$PORT" ] || [ ! -e "$PORT" ]; then echo "FATAL: Espressif USB-JTAG device not found"; exit 2; fi
echo "[3] sha256 of staged image:"
sha256sum ~/fw-4.0.2/firmware.factory.bin
echo "[4] flashing firmware.factory.bin @ 0x0 (--no-stub ROM loader, no --baud) ..."
~/esptool-venv/bin/esptool --chip esp32c6 --port "$PORT" --no-stub \
  --before default-reset --after hard-reset write-flash 0x0 ~/fw-4.0.2/firmware.factory.bin 2>&1
echo "[5] esptool exit=$?"
REMOTE
