#!/bin/bash
# Phase 3.3.4 N3 (Path A): launch 7-persona overnight on pi02 + pi03 only
# (pilot/EvoBot dropped — c6-pilot wedged). setsid-detached, default
# morning-window self-stop (evening launch -> stops ~07:00 local).
set -u
K="$HOME/.ssh/evobot_ed25519"
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
P2="$S scott@192.168.1.17"
P3="$S scott@192.168.1.44"
PERS="persona_01_basic,persona_02_power_user,persona_03_ambiguity_tester,persona_04_memory_specialist,persona_05_automation_operator,persona_06_robotics_motion,persona_07_sensor_telemetry"

launch() {  # $1 pi-ssh  $2 label
  echo "===== launch $2 ====="
  $1 "set -u
    cd ~/wireclaw-phase31/bench/fork/lora || { echo 'FATAL lora dir'; exit 1; }
    if pgrep -f 'bash overnight_capture.sh' >/dev/null 2>&1; then echo 'ABORT: real loop already running'; pgrep -af 'bash overnight_capture.sh'; exit 3; fi
    rm -f ~/.stop-overnight-capture ~/.overnight-capture.status.final
    H=\$(hostname)
    PERSONAS='$PERS' setsid bash -c \"bash overnight_capture.sh > ~/v1.1-\$H.log 2>&1\" </dev/null >/dev/null 2>&1 &
    sleep 4
    echo \"launched host=\$H realprocs=\$(pgrep -fc 'bash overnight_capture.sh') python=\$(pgrep -fc persona_runner.py)\"
    echo \"stopflag=\$([ -f ~/.stop-overnight-capture ] && echo Y || echo N) final=\$([ -f ~/.overnight-capture.status.final ] && echo Y || echo N)\"
    echo '-- v1.1 log head --'; sleep 3; head -8 ~/v1.1-\$H.log 2>/dev/null || echo '(log not yet written)'" 2>&1
}
launch "$P2" "pi02->c6-02"
launch "$P3" "pi03->c6-03"
