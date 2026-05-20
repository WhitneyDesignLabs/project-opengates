#!/bin/bash
# Phase 3.1.3 M1 one-shot: stop status + proc state for all 3 Pis.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
EVO="ssh -o BatchMode=yes -o ConnectTimeout=8 evobot"
P2="$SSH scott@192.168.1.17"
P3="$SSH scott@192.168.1.44"

probe() {
  $1 'echo -n "final: "; cat ~/.overnight-capture.status.final 2>/dev/null | tr "\n" "; " || echo -n "STILL-RUNNING";
      echo; echo -n "status: "; cat ~/.overnight-capture.status 2>/dev/null | tr "\n" "; ";
      echo; echo -n "proc: "; pgrep -af overnight_capture.sh 2>/dev/null | head -1 || echo "none";
      echo -n "now: "; date "+%F %T %Z"' 2>&1
}

echo "==== EvoBot ===="; probe "$EVO"
echo "==== pi02 ===="; probe "$P2"
echo "==== pi03 ===="; probe "$P3"
