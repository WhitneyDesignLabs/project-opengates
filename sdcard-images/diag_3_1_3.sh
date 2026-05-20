#!/bin/bash
# Phase 3.1.3 health probe for ONE host. Arg1 = label.
L="${1:-host}"
echo "==== $L  ($(hostname))  now=$(date '+%F %T %Z') ===="
echo "-- procs --"
pgrep -af overnight_capture.sh || echo "NO overnight_capture.sh"
pgrep -af persona_runner.py | head -2 || echo "NO persona_runner.py"
echo "-- .overnight-capture.status --"
cat ~/.overnight-capture.status 2>/dev/null || echo "(empty/absent)"
echo "-- .overnight-capture.status.final (should NOT exist yet) --"
cat ~/.overnight-capture.status.final 2>/dev/null || echo "(absent - good, still running)"
echo "-- newest user-side jsonl --"
ls -t ~/wireclaw-corpus/user-side/*overnight*.jsonl 2>/dev/null | head -3
echo "-- session jsonl count today --"
ls -1 ~/wireclaw-corpus/user-side/2026-05-16T2*overnight*.jsonl 2>/dev/null | wc -l
echo "-- 3.1.3 log: last 12 lines --"
tail -n 12 ~/3.1.3-"$L".log 2>/dev/null || echo "(no 3.1.3-$L.log)"
echo "-- 3.1.3 log: error/timeout grep --"
grep -nE 'FAIL|TIMEOUT|Traceback|Error|error:' ~/3.1.3-"$L".log 2>/dev/null | tail -5 || echo "(none)"
