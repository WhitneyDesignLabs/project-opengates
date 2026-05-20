#!/bin/bash
# Phase 3.3.4 PRE.1: health-probe all 3 driver Pis.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
EVO="ssh -o BatchMode=yes -o ConnectTimeout=8 evobot"
P2="$SSH scott@192.168.1.17"
P3="$SSH scott@192.168.1.44"

probe() {  # $1 = ssh-cmd  $2 = label
  echo "===================== $2 ====================="
  $1 'echo "-- uptime --"; uptime
      echo "-- last reboot (5) --"; last reboot 2>/dev/null | head -5
      echo "-- throttle --"; vcgencmd get_throttled 2>/dev/null || echo "(vcgencmd n/a)"
      echo "-- core volts --"; vcgencmd measure_volts core 2>/dev/null
      echo "-- CPU temp --"; vcgencmd measure_temp 2>/dev/null
      echo "-- mem --"; free -h | head -2
      echo "-- disk / --"; df -h / | tail -1
      echo "-- telethon sessions --"; ls -la ~/.telethon-*.session 2>/dev/null || echo "(none in ~)"
      echo "-- overnight status files --"; ls -la ~/.overnight-capture.status* 2>/dev/null || echo "(none)"
      echo "-- capture/overnight logs --"; ls -lt ~/overnight-capture.log ~/3.1.*-*.log /tmp/capture-*.log 2>/dev/null | head -4 || echo "(none)"
      echo "-- overnight_capture.sh present --"; ls -la ~/wireclaw-phase31/bench/fork/lora/overnight_capture.sh 2>/dev/null || echo "(not at expected path)"
      echo "-- recent dmesg err/warn --"; (dmesg 2>/dev/null | grep -iE "panic|oom|under-voltage|undervoltage|brownout|hung task" | tail -5) || echo "(dmesg restricted or clean)"' 2>&1
}
probe "$EVO" "EvoBot (c6-pilot driver)"
probe "$P2"  "pi02 (c6-02 driver)"
probe "$P3"  "pi03 (c6-03 driver)"
