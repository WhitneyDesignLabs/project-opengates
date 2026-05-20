#!/bin/bash
# Runs ON a driver Pi. Guard is accurate here because this file's own argv
# is "bash /tmp/v11_launch_remote.sh" (no 'overnight_capture.sh' substring).
set -u
PERS="persona_01_basic,persona_02_power_user,persona_03_ambiguity_tester,persona_04_memory_specialist,persona_05_automation_operator,persona_06_robotics_motion,persona_07_sensor_telemetry"
cd ~/wireclaw-phase31/bench/fork/lora || { echo "FATAL: lora dir missing"; exit 1; }

# Real-loop guard: a live loop runs `bash overnight_capture.sh` AND keeps
# ~/.overnight-capture.status fresh with no .final. Both checks must agree.
if pgrep -f 'bash overnight_capture.sh' >/dev/null 2>&1; then
  echo "ABORT: overnight_capture.sh process already running:"; pgrep -af 'bash overnight_capture.sh'; exit 3
fi
if [ -f ~/.overnight-capture.status ] && [ ! -f ~/.overnight-capture.status.final ]; then
  echo "ABORT: live .status present without .final (loop may be running)"; cat ~/.overnight-capture.status; exit 3
fi

rm -f ~/.stop-overnight-capture ~/.overnight-capture.status.final
H=$(hostname)
PERSONAS="$PERS" setsid bash -c "bash overnight_capture.sh > ~/v1.1-$H.log 2>&1" </dev/null >/dev/null 2>&1 &
sleep 5
echo "host=$H"
echo "realprocs(bash overnight_capture.sh)=$(pgrep -fc 'bash overnight_capture.sh')"
echo "persona_runner=$(pgrep -fc persona_runner.py)"
echo "stopflag=$([ -f ~/.stop-overnight-capture ] && echo Y || echo N)  final=$([ -f ~/.overnight-capture.status.final ] && echo Y || echo N)"
echo "status: $(cat ~/.overnight-capture.status 2>/dev/null | tr '\n' ' ')"
echo "-- v1.1-$H.log head --"
sleep 4
head -10 ~/v1.1-$H.log 2>/dev/null || echo "(log not written yet)"
