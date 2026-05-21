#!/bin/bash
# Phase 4.3.0.E: flash c6-01 with the 4.3.0 wrap-policy firmware
# (sha 3f15cc15...). Same proven JTAG recipe as phase_4_0_5_flash01.sh,
# just pointed at fw-4.3.0/ instead of fw-4.0.3/. c6-02 and c6-03 are
# NOT touched.
set -u
K=$HOME/.ssh/evobot_ed25519
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=12 -i $K"
SCP="scp -q -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=12 -i $K"

WK=/mnt/c/Users/homet/Documents/WireClaw-fork/.pio/build/esp32-c6
BA=/mnt/c/Users/homet/.platformio/packages/framework-arduinoespressif32/tools/partitions/boot_app0.bin

echo "[stage] local firmware sha256:"
sha256sum "$WK/firmware.bin"
echo

echo "[stage] -> evobot:~/fw-4.3.0/"
$S scott@192.168.1.51 'mkdir -p ~/fw-4.3.0'
$SCP "$WK/bootloader.bin" "$WK/partitions.bin" "$WK/firmware.bin" "$BA" scott@192.168.1.51:'~/fw-4.3.0/'

$S scott@192.168.1.51 "bash -s" <<'REMOTE'
set -u
echo "[evobot] $(hostname)  $(date -Iseconds)"
echo "[stage] evobot:~/fw-4.3.0/ contents:"
ls -la ~/fw-4.3.0/
echo
echo "[verify] firmware sha256:"
sha256sum ~/fw-4.3.0/firmware.bin
echo
echo "[serial] killing any stale capture procs (bracket-pattern)"
pkill -f '[u]art-c6-01-cap' 2>/dev/null
pkill -f '[j]tag-serial-capture-loop' 2>/dev/null
sleep 1

BYID=$(ls /dev/serial/by-id/usb-Espressif_USB_JTAG_serial_debug_unit_E8:F6:0A:FB:E3:C0-if00 2>/dev/null | head -1)
PORT=$(readlink -f "$BYID" 2>/dev/null)
echo "[flash] BYID=$BYID  PORT=$PORT"
if [ -z "$PORT" ]; then
  echo "FATAL: c6-01 Espressif USB-JTAG not enumerated on evobot"
  exit 2
fi

echo "[flash] running esptool ..."
~/phase31-venv/bin/esptool --chip esp32c6 --port "$PORT" --no-stub \
  --before default-reset --after hard-reset write-flash --flash-size detect \
  0x0     ~/fw-4.3.0/bootloader.bin \
  0x8000  ~/fw-4.3.0/partitions.bin \
  0xe000  ~/fw-4.3.0/boot_app0.bin \
  0x10000 ~/fw-4.3.0/firmware.bin 2>&1 | \
  grep -E 'Wrote|Hash of data verified|Hard reset|Staying|error|Error|Flash will be erased|Detecting' | tail -25
echo "[flash] done."
REMOTE
