#!/bin/bash
# Phase 4.0.3 (pivot): validation check — uptime growth + reserved-pin
# guard + crash signatures in the c6-02 UART log.
# Args: <logfile>
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $K"
LOG=${1:?logfile}
$SSH scott@192.168.1.17 "bash -s" <<REMOTE
set -u
echo "=== status ==="
curl -s -m6 http://192.168.1.15/api/status | grep -oE '"uptime":"[^"]*"|"uptime_seconds":[0-9]+'
echo "=== reset/crash signatures (should be NONE) ==="
grep -cE 'rst:0x8|rst:0xc|ESP-ROM' "$LOG" 2>/dev/null | sed 's/^/  count=/'
echo "=== reserved-pin guard hits (graceful errors) ==="
grep -nE 'is reserved|reserved \(SPI|GPIO 2[4-9]|GPIO 30' "$LOG" 2>/dev/null | tail -12
echo "=== robotics persona prompts seen ==="
grep -nE 'spindle|park sequence|emergency stop|motor on GPIO|GPIO 25|GPIO 26|GPIO 27' "$LOG" 2>/dev/null | tail -10
echo "=== last 6 lines ==="
tail -n 6 "$LOG"
REMOTE
