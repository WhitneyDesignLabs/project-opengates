#!/bin/bash
# Hard-stop pi03's duplicated capture loops, snapshot final state.
echo "=== before ==="
ps -eo pid,etime,cmd | grep -E '[o]vernight_capture.sh|[p]ersona_runner.py' || echo none
pkill -f overnight_capture.sh 2>/dev/null
pkill -f persona_runner.py 2>/dev/null
sleep 3
pkill -9 -f overnight_capture.sh 2>/dev/null
pkill -9 -f persona_runner.py 2>/dev/null
touch ~/.stop-overnight-capture
sleep 8
echo "=== after (expect none) ==="
ps -eo pid,etime,cmd | grep -E '[o]vernight_capture.sh|[p]ersona_runner.py' || echo none
echo "=== status snapshot ==="
cat ~/.overnight-capture.status 2>/dev/null || echo "no .status"
echo "=== .final ==="
cat ~/.overnight-capture.status.final 2>/dev/null || echo "no .final (killed mid-loop; status snapshot above is authoritative)"
echo "=== user-side jsonl count (today) ==="
ls -1 ~/wireclaw-corpus/user-side/2026-05-16T19*.jsonl 2>/dev/null | wc -l
