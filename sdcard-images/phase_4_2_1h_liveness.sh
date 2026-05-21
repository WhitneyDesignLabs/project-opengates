#!/bin/bash
# H.5 — T+N liveness check across all 3 Pis + azza proxy.
set -u
K=$HOME/.ssh/evobot_ed25519
SSH="ssh -i $K -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=8"

echo "============================================================"
echo "  Liveness check @ $(date '+%F %T %Z')"
echo "============================================================"

for spec in evobot:192.168.1.51 pi02:192.168.1.17 pi03:192.168.1.44; do
  name=${spec%%:*}; ip=${spec##*:}
  echo
  echo "=== $name $ip ==="
  $SSH "scott@$ip" "
    echo '-- processes --'
    pgrep -af '[o]vernight_capture\.sh' | head -2 || echo '  (no overnight_capture)'
    pgrep -af '[p]ersona_runner\.py'    | head -2 || echo '  (no persona_runner)'
    echo '-- status file --'
    cat ~/.overnight-capture.status 2>/dev/null || echo '  (no status yet)'
    echo
    echo '-- newest jsonl + last 2 reply previews --'
    LAST=\$(ls -t ~/wireclaw-corpus/user-side/*.jsonl 2>/dev/null | head -1)
    if [ -z \"\$LAST\" ]; then
      echo '  (no jsonl yet)'
    else
      echo \"  file: \$LAST  (\$(wc -l < \"\$LAST\") turns so far)\"
      tail -2 \"\$LAST\" 2>/dev/null | python3 -c '
import sys, json
for line in sys.stdin:
    try:
        d = json.loads(line)
        rp = (d.get(\"reply_text\") or d.get(\"reply\") or \"\")[:90].replace(chr(10), \" \")
        pr = (d.get(\"prompt_text\") or d.get(\"prompt\") or \"\")[:50].replace(chr(10), \" \")
        print(f\"  prompt: {pr!r}  reply: {rp!r}\")
    except Exception as e:
        print(f\"  parse err: {e}\")
'
    fi
  "
done

echo
echo "============================================================"
echo "  azza proxy recent activity by chip IP"
echo "============================================================"
TODAY=$(date '+%Y-%m-%d')
ssh -o BatchMode=yes -o ConnectTimeout=10 azza@azza.tail63f48.ts.net "
cd ~/wireclaw-corpus/ollama-raw/$TODAY/ 2>/dev/null || { echo '(no proxy dir for $TODAY)'; exit 0; }
echo 'last 5 minutes of activity, count by source IP:'
find . -mmin -5 -name '*.json' -printf '%f\n' | awk -F'_' '{print \$1}' | sort | uniq -c | sort -rn
echo
echo 'newest 3 files:'
ls -t *.json 2>/dev/null | head -3
"
