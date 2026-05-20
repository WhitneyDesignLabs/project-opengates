#!/bin/bash
# Phase 4.0.3 Step 2: start a long-lived, reset-surviving USB-JTAG serial
# capture on a Pi, detached, streaming to a timestamped log on the Pi.
# Reopens the stable by-id symlink so it survives chip resets/reflash.
# Args: <pi_ip> <chip_name>
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $K"
IP=${1:?pi ip}
NAME=${2:?chip name}

# Remote: kill any prior capture, launch a 1800s reopen-loop, print log path + pid.
$SSH scott@"$IP" "bash -s" <<'REMOTE'
set -u
pkill -f 'jtag-serial-capture-loop' 2>/dev/null
TS=$(date -u +%Y-%m-%dT%H-%M-%SZ)
LOG="$HOME/serial-flash-$TS.log"
cat > /tmp/jtag-serial-capture-loop.sh <<'EOS'
#!/bin/bash
LOG="$1"
END=$(( $(date +%s) + 1800 ))
echo "[capture-start $(date -u +%FT%TZ)]" >> "$LOG"
while [ "$(date +%s)" -lt "$END" ]; do
  BYID=$(ls /dev/serial/by-id/usb-Espressif_USB_JTAG_serial_debug_unit_*-if00 2>/dev/null | head -1)
  D=$(readlink -f "$BYID" 2>/dev/null)
  if [ -n "$D" ] && [ -e "$D" ]; then
    sudo -n stty -F "$D" 115200 raw -echo 2>/dev/null
    sudo -n timeout 8 cat "$D" 2>/dev/null \
      | stdbuf -oL tr -d '\r' \
      | while IFS= read -r line; do echo "$(date -u +%H:%M:%S) | $line"; done >> "$LOG"
  else
    echo "$(date -u +%H:%M:%S) | [no-usb-device window]" >> "$LOG"
    sleep 0.4
  fi
done
echo "[capture-end $(date -u +%FT%TZ)]" >> "$LOG"
EOS
chmod +x /tmp/jtag-serial-capture-loop.sh
setsid nohup /tmp/jtag-serial-capture-loop.sh "$LOG" >/dev/null 2>&1 &
sleep 1
echo "LOG=$LOG"
echo "PID=$(pgrep -f jtag-serial-capture-loop | head -1)"
REMOTE
