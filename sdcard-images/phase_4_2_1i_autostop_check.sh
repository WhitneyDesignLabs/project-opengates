#!/bin/bash
# Phase 4.2.1.I.1: verify overnight capture stopped cleanly.
set -u
K=$HOME/.ssh/evobot_ed25519
SSH="ssh -i $K -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=8"

echo "============================================================"
echo "  Auto-stop verification @ $(date '+%F %T %Z')"
echo "============================================================"

for spec in evobot:192.168.1.51 pi02:192.168.1.17 pi03:192.168.1.44; do
  name=${spec%%:*}; ip=${spec##*:}
  echo
  echo "=== $name $ip ==="
  $SSH "scott@$ip" "
    echo '-- running processes (bracket-pattern, expect none) --'
    pgrep -af '[o]vernight_capture\.sh' | head -3 || echo '  (none)'
    pgrep -af '[p]ersona_runner\.py'    | head -3 || echo '  (none)'
    echo
    echo '-- STOP_FLAG presence --'
    ls -la ~/STOP_FLAG ~/.stop-overnight-capture 2>&1 | grep -v 'No such' | head -3 || echo '  (none)'
    echo
    echo '-- status files --'
    if [ -f ~/.overnight-capture.status.final ]; then
      echo '[.status.final]'; cat ~/.overnight-capture.status.final
    elif [ -f ~/.overnight-capture.status ]; then
      echo '[.status (not final yet)]'; cat ~/.overnight-capture.status
    else
      echo '  no status file'
    fi
    echo
    echo '-- session jsonl count --'
    ls ~/wireclaw-corpus/user-side/2026-05-2*.jsonl 2>/dev/null | wc -l
    echo
    echo '-- newest 3 logs --'
    ls -t ~/overnight-capture-*.log 2>/dev/null | head -3
  "
done

echo
echo "============================================================"
echo "  azza proxy coverage 2026-05-20 (evening) + 2026-05-21"
echo "============================================================"
ssh -o BatchMode=yes -o ConnectTimeout=10 azza@azza.tail63f48.ts.net "
for d in 2026-05-20 2026-05-21; do
  echo '-- '\$d' --'
  if [ -d ~/wireclaw-corpus/ollama-raw/\$d ]; then
    cd ~/wireclaw-corpus/ollama-raw/\$d
    TOTAL=\$(ls *.json 2>/dev/null | wc -l)
    echo \"  total records: \$TOTAL\"
    echo '  by source IP:'
    ls *.json 2>/dev/null | awk -F'_' '{print \$1}' | sort | uniq -c | sort -rn | head -6
  else
    echo '  (no dir)'
  fi
done
"
