#!/bin/bash
# Phase 4.0.4a Step 4: launch 11h overnight capture on pi02 + pi03.
# - full 7-persona rotation (no skip-list)
# - clears stale STOP_FLAG/status so it doesn't insta-stop
# - detached watchdog touches STOP_FLAG at next 06:00 local -> wrapper
#   exits gracefully at the following session boundary (at(1) not
#   installed, so sleep->touch instead; wrapper's built-in 7AM stop is
#   the backstop)
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=12 -i $K"
PERSONAS="persona_01_basic,persona_02_power_user,persona_03_ambiguity_tester,persona_04_memory_specialist,persona_05_automation_operator,persona_06_robotics_motion,persona_07_sensor_telemetry"

launch() {
  local IP=$1 NAME=$2
  echo "==== $NAME ($IP) ===="
  $SSH scott@"$IP" "PERSONAS='$PERSONAS' bash -s" <<'REMOTE'
set -u
cd ~/wireclaw-phase31/bench/fork/lora || { echo "FATAL: no lora dir"; exit 2; }
# already running?
if pgrep -af '[o]vernight_capture.sh' >/dev/null; then echo "ALREADY RUNNING — aborting"; pgrep -af '[o]vernight_capture.sh'; exit 3; fi
# clear stale stop/status
rm -f ~/.stop-overnight-capture ~/.overnight-capture.status ~/.overnight-capture.status.final
# 06:00 watchdog
NOW=$(date +%s); T6=$(date -d 'today 06:00' +%s)
[ "$NOW" -ge "$T6" ] && T6=$(date -d 'tomorrow 06:00' +%s)
SLEEP=$((T6 - NOW))
setsid nohup bash -c "sleep $SLEEP; touch ~/.stop-overnight-capture" >/dev/null 2>&1 &
echo "watchdog: STOP_FLAG at $(date -d @"$T6" '+%F %H:%M %Z') (in ${SLEEP}s)"
# launch capture detached
TS=$(date +%s)
LOG=~/overnight-capture-$TS.log
setsid nohup env PERSONAS="$PERSONAS" bash overnight_capture.sh > "$LOG" 2>&1 &
sleep 3
echo "capture PID: $(pgrep -f '[o]vernight_capture.sh' | head -1)"
echo "LOG=$LOG"
echo "personas=$PERSONAS"
echo "--- first log lines ---"; head -4 "$LOG" 2>/dev/null
echo "--- status ---"; cat ~/.overnight-capture.status 2>/dev/null | tr '\n' ' '; echo
REMOTE
}

launch 192.168.1.17 pi02
launch 192.168.1.44 pi03
