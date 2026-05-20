#!/bin/bash
# Kill any respawned capture loops on one Pi, set stop flag, snapshot.
# Stale pre-compaction "C2 launch" background tasks keep relaunching loops
# (their launch cmd does rm -f ~/.stop-overnight-capture on startup).
H="$1"
echo "=== $H before ==="
ps -eo pid,etime,cmd | grep -E '[o]vernight_capture.sh|[p]ersona_runner.py' || echo none
pkill -f overnight_capture.sh 2>/dev/null
pkill -f persona_runner.py 2>/dev/null
sleep 3
pkill -9 -f overnight_capture.sh 2>/dev/null
pkill -9 -f persona_runner.py 2>/dev/null
touch ~/.stop-overnight-capture
sleep 5
echo "=== $H after (expect none) ==="
ps -eo pid,etime,cmd | grep -E '[o]vernight_capture.sh|[p]ersona_runner.py' || echo none
echo "=== $H .final ==="
cat ~/.overnight-capture.status.final 2>/dev/null || echo "no .final"
