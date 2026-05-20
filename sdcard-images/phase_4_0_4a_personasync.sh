#!/bin/bash
# Phase 4.0.4a Step 2: sync revised personas to pi02 + pi03, verify.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $K"
SCP="scp -q -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $K"
SRC=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/personas
for ip in 192.168.1.17 192.168.1.44; do
  echo "==== $ip ===="
  $SCP "$SRC"/persona_*.py scott@"$ip":'~/wireclaw-phase31/bench/fork/lora/personas/' \
    && echo "scp OK"
  $SSH scott@"$ip" 'cd ~/wireclaw-phase31/bench/fork/lora/personas 2>/dev/null && \
    echo -n "files: "; ls persona_*.py | wc -l; \
    echo -n "reserved-pin matches (want 0): "; \
    grep -onE "GPIO[ _]?(1[23]|2[4-9]|30)\b|pin[ =:]*(1[23]|2[4-9]|30)\b" persona_*.py | wc -l; \
    echo "spot-check p06 lines:"; \
    grep -nE "park sequence|Emergency stop|spindle on GPIO" persona_06_robotics_motion.py' 2>&1
done
