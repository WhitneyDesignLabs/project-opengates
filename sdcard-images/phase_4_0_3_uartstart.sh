#!/bin/bash
# Phase 4.0.3 (pivot): start a backgrounded 300s CH343/UART0 capture on
# pi02 for c6-02 (stable bridge, survives chip resets). Prints log path.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $K"

$SSH scott@192.168.1.17 "bash -s" <<'REMOTE'
set -u
pkill -f 'uart-c6-02-cap' 2>/dev/null
TS=$(date -u +%Y-%m-%dT%H-%M-%SZ)
LOG="$HOME/uart-c6-02-$TS.log"
cat > /tmp/uart-c6-02-cap.sh <<'EOS'
#!/bin/bash
LOG="$1"
BY=$(ls /dev/serial/by-id/usb-1a86_USB_Single_Serial_5B91079021-if00 2>/dev/null)
D=$(readlink -f "$BY" 2>/dev/null)
[ -z "$D" ] && { echo "[no CH343]" >> "$LOG"; exit 1; }
sudo -n stty -F "$D" 115200 raw -echo 2>/dev/null
echo "[cap-start $(date -u +%FT%TZ) dev=$D]" >> "$LOG"
sudo -n timeout 300 cat "$D" 2>/dev/null | tr -d '\r' | while IFS= read -r l; do echo "$(date -u +%H:%M:%S) | $l"; done >> "$LOG"
echo "[cap-end $(date -u +%FT%TZ)]" >> "$LOG"
EOS
chmod +x /tmp/uart-c6-02-cap.sh
setsid nohup /tmp/uart-c6-02-cap.sh "$LOG" >/dev/null 2>&1 &
sleep 1
echo "LOG=$LOG"
echo "PID=$(pgrep -f uart-c6-02-cap | head -1)"
REMOTE
