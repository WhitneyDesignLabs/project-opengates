#!/bin/bash
# Phase 4.0.1 Step 1: stop overnight capture on pi02 + pi03 cleanly.
# NOTE: bracket-pattern ([o]vernight / [p]ersona) so pkill/pgrep do not
# self-match this very SSH command string (the recurring inline-string
# trap; see sync/from_code.md line 62). Without it, pkill kills the
# session before any output and ssh exits 255.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
P2="$SSH scott@192.168.1.17"
P3="$SSH scott@192.168.1.44"

stop() {
  $1 'pkill -f "[o]vernight_capture\.sh"; pkill -f "[p]ersona_runner\.py";
      sleep 1;
      echo -n "remaining-procs: "; pgrep -af "[o]vernight_capture\.sh|[p]ersona_runner\.py" | wc -l;
      echo -n "status-file:     "; cat ~/.overnight-capture.status 2>/dev/null | tr "\n" "; " || echo "no-status";
      echo' 2>&1
}

echo "==== pi02 ===="; stop "$P2"
echo "==== pi03 ===="; stop "$P3"
