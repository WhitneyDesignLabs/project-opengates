#!/bin/bash
# Phase 4.0.3: c6-03 post-power-cycle validation (pi03 / .47).
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $K"
LOG=${1:?logfile}
$SSH scott@192.168.1.44 "bash -s" <<REMOTE
set -u
echo "=== status (.47) ==="
curl -s -m6 http://192.168.1.47/api/status | grep -oE '"version":"[^"]*"|"uptime":"[^"]*"|"uptime_seconds":[0-9]+|"wifi_ip":"[^"]*"|"heap_free":[0-9]+'
ping -c1 -W2 192.168.1.47 >/dev/null 2>&1 && echo "PING-OK" || echo "PING-FAIL"
echo "=== reset/crash sigs in log (want 0) ==="
grep -cE 'rst:0x8|rst:0xc' "$LOG" 2>/dev/null | sed 's/^/  rst_count=/'
grep -cE 'ESP-ROM' "$LOG" 2>/dev/null | sed 's/^/  esp_rom_count=/'
echo "=== boot banner / reserved-guard / persona pins ==="
grep -nE 'WireClaw v0|Ready! Free heap|is reserved|rst:0x|WiFi: IP' "$LOG" 2>/dev/null | tail -14
echo "=== last 6 ==="
tail -n 6 "$LOG"
REMOTE
