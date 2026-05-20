#!/bin/bash
# Phase 4.0.1 Step 2: find the last clean turn before each chip's crash.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
P2="$SSH scott@192.168.1.17"
P3="$SSH scott@192.168.1.44"

probe() {
  $1 'echo "--- jsonl inventory (newest 6) ---";
      ls -lt --time-style=+%Y-%m-%dT%H:%M:%S ~/wireclaw-corpus/user-side/*.jsonl 2>/dev/null | head -6;
      echo "--- newest jsonl: first+last line ---";
      LAST=$(ls -t ~/wireclaw-corpus/user-side/*.jsonl 2>/dev/null | head -1);
      if [ -n "$LAST" ]; then echo "FILE=$LAST"; echo "HEAD:"; head -1 "$LAST"; echo "TAIL:"; tail -1 "$LAST";
      else echo "no jsonl found"; fi;
      echo "--- overnight-capture.log signal tail ---";
      tail -40 ~/overnight-capture.log 2>/dev/null | grep -E "response|timeout|error|started|stopped|HTTP|000|refused" | tail -12' 2>&1
}

echo "==== pi02 (c6-02 / .15) ===="; probe "$P2"
echo "==== pi03 (c6-03 / .47) ===="; probe "$P3"
