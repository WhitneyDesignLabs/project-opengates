#!/bin/bash
# Phase 3.1.3 L3 launcher — full 7-persona rotation, DEFAULT 07:00 self-stop.
# NO NO_TIME_STOP (evening launch -> wrapper self-stops when local hour hits 07).
# Clears the stale 3.1.2 stop-flag + .final so the loop actually runs
# (overnight_capture.sh checks STOP_FLAG every iteration, never clears it).
set -u
H="${1:?usage: launch_3_1_3.sh <shortname>}"
cd ~/wireclaw-phase31/bench/fork/lora || { echo "FATAL: lora dir missing"; exit 1; }
# Guard: refuse to start a second loop if one is already running.
if pgrep -f overnight_capture.sh >/dev/null 2>&1; then
    echo "ABORT: overnight_capture.sh already running on $(hostname)"
    pgrep -af overnight_capture.sh
    exit 3
fi
rm -f ~/.stop-overnight-capture ~/.overnight-capture.status.final
PERS=persona_01_basic,persona_02_power_user,persona_03_ambiguity_tester,persona_04_memory_specialist,persona_05_automation_operator,persona_06_robotics_motion,persona_07_sensor_telemetry
PERSONAS="$PERS" setsid bash -c "bash overnight_capture.sh > ~/3.1.3-$H.log 2>&1" </dev/null >/dev/null 2>&1 &
sleep 2
echo "LAUNCHED host=$(hostname) short=$H"
echo "personas=$PERS"
echo "procs=$(pgrep -fc overnight_capture.sh)"
echo "stopflag_present=$([ -f ~/.stop-overnight-capture ] && echo Y || echo N)"
echo "log_head:"
sleep 2
head -5 ~/3.1.3-"$H".log 2>/dev/null || echo "(log not yet written)"
