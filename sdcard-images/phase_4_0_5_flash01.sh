#!/bin/bash
# Phase 4.0.5-lite: flash c6-01 via evobot Pi native USB-JTAG with bf80fa9
# (pin guard + tg-offset persist + rulesSave OOB). Same proven recipe as
# the Phase 4.0.3 flashes on c6-02 and c6-03 — esptool --no-stub,
# --flash-size detect, NO --baud, port resolved from stable Espressif by-id.
# Binaries already staged in evobot:~/ from prior scp.
set -u
K="$HOME/.ssh/evobot_ed25519"
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=12 -i $K"

# Pause Telegram traffic on chip BEFORE flash so no in-flight watchdog
# crash mid-write. We toggle telegram off temporarily by clearing the
# token via /api/config... actually skip; esptool puts chip into download
# mode and overrides the running firmware. Trust the proven recipe.

$S evobot bash -s <<'REMOTE'
set -u
echo "[host] $(hostname)  $(date -Iseconds)"
echo "[stage] evobot:~/ contents:"
ls -la ~/firmware-bf80fa9.bin ~/bootloader.bin ~/partitions.bin ~/boot_app0.bin
echo
echo "[verify] firmware sha256:"; sha256sum ~/firmware-bf80fa9.bin
echo
echo "[serial] killing any stale capture procs (bracket-pattern to avoid self-match)"
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
  0x0 ~/bootloader.bin \
  0x8000 ~/partitions.bin \
  0xe000 ~/boot_app0.bin \
  0x10000 ~/firmware-bf80fa9.bin 2>&1 | \
  grep -E 'Wrote|Hash of data verified|Hard reset|Staying|error|Error|Flash will be erased|Detecting' | tail -25
echo "[flash] done."
REMOTE
