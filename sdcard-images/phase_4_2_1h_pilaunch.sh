#!/bin/bash
# Phase 4.2.1.H.4: per-Pi launch script.
# Runs ON the Pi. Sources secrets, launches setsid overnight_capture.sh
# with full 7-persona rotation, and starts a detached 06:00-tomorrow-local
# STOP_FLAG watchdog. Reports both PIDs.
set -u

cd ~/wireclaw-phase31/bench/fork/lora || { echo "FATAL: no runner dir"; exit 2; }

# Source Telegram credentials.
if [ ! -f ~/.wireclaw-secrets.env ]; then
  echo "FATAL: ~/.wireclaw-secrets.env missing"
  exit 2
fi
set -a
. ~/.wireclaw-secrets.env
set +a

# Full 7-persona rotation (overnight_capture.sh round-robins through the list).
export PERSONAS="persona_01_basic,persona_02_power_user,persona_03_ambiguity_tester,persona_04_memory_specialist,persona_05_automation_operator,persona_06_robotics_motion,persona_07_sensor_telemetry"

TS=$(date +%s)
LOG="$HOME/overnight-capture-$TS.log"
echo "[host] $(hostname) | $(date '+%F %T %Z')"
echo "[log]  $LOG"
echo "[PERSONAS] $PERSONAS"

# Launch capture detached.
setsid bash -c "exec bash overnight_capture.sh > '$LOG' 2>&1" </dev/null >/dev/null 2>&1 &
CAP_PID=$!
echo "[capture-pid] $CAP_PID"

# 06:00 tomorrow local-time STOP_FLAG watchdog (Pi is already on MST per
# H.1 verification). Compute sleep seconds on this host, then setsid.
TARGET=$(date -d 'tomorrow 06:00' +%s)
NOW=$(date +%s)
SLEEP=$((TARGET - NOW))
echo "[watchdog] target=$(date -d "@$TARGET" '+%F %T %Z') sleep=${SLEEP}s"
if [ "$SLEEP" -lt 60 ] || [ "$SLEEP" -gt 86400 ]; then
  echo "WARN: sleep $SLEEP out of sane bounds; aborting watchdog (capture wrapper's own 7AM check is backstop)"
else
  setsid bash -c "sleep $SLEEP && touch ~/STOP_FLAG && touch ~/.stop-overnight-capture" </dev/null >/dev/null 2>&1 &
  WD_PID=$!
  echo "[watchdog-pid] $WD_PID"
fi

# Give the launch a beat then confirm capture proc is alive (post-fork).
sleep 3
echo "[verify t+3s] pgrep:"
pgrep -af '[o]vernight_capture\.sh' | head -3 || echo '  no overnight_capture process'
pgrep -af '[p]ersona_runner\.py' | head -3 || echo '  no persona_runner process (may not have spawned yet)'
echo "[verify t+3s] log tail:"
tail -3 "$LOG" 2>/dev/null || echo '  (log empty)'
