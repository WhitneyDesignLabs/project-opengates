#!/bin/bash
# Phase 3.3.4 N4: after ~5min settle, verify pi02/pi03 capture is producing
# turns, the azza proxy sees v1.1 requests, and first replies show
# WireClaw-Agent v1.1 identity (folds in the no-/api/chat sanity).
set -u
sleep 300
K="$HOME/.ssh/evobot_ed25519"
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
P2="$S scott@192.168.1.17"
P3="$S scott@192.168.1.44"
A="ssh -o BatchMode=yes -o ConnectTimeout=8 azza@192.168.1.60"

pi() {  # $1 pi-ssh  $2 label
  echo "===== $2 ====="
  $1 'H=$(hostname)
    echo -n "realprocs="; pgrep -fc "bash overnight_capture.sh";
    echo "status: $(cat ~/.overnight-capture.status 2>/dev/null | tr "\n" " ")"
    echo "final? $([ -f ~/.overnight-capture.status.final ] && echo YES-stopped || echo no-running)"
    echo -n "user-side jsonl count: "; ls ~/wireclaw-corpus/user-side/2026-05-17T19*overnight*.jsonl 2>/dev/null | wc -l
    echo "log tail (5):"; tail -5 ~/v1.1-$H.log 2>/dev/null
    newest=$(ls -t ~/wireclaw-corpus/user-side/2026-05-17T19*overnight*.jsonl 2>/dev/null | head -1)
    echo "newest jsonl: $newest"
    [ -n "$newest" ] && echo "first turn reply (identity check):" && python3 -c "
import json,sys
ls=[l for l in open(\"$newest\").read().splitlines() if l.strip()]
for l in ls[:3]:
    r=json.loads(l); print(\"  prompt=\",(r.get(\"prompt_text\") or \"\")[:60]); print(\"  reply=\",(r.get(\"reply_text\") or \"\")[:240])
" 2>/dev/null || echo "  (no turns yet / parse skip)"' 2>&1
}
pi "$P2" "pi02 -> c6-02"
pi "$P3" "pi03 -> c6-03"

echo
echo "===== azza proxy: recent requests + model name ====="
$A 'D=$(date +%F); LOGDIR=~/wireclaw-corpus/ollama-raw/$D
    echo "today raw dir: $LOGDIR  files=$(ls -1 $LOGDIR 2>/dev/null | wc -l)"
    newest=$(ls -t $LOGDIR/*.json 2>/dev/null | head -1)
    echo "newest proxy record: $newest"
    [ -n "$newest" ] && python3 -c "
import json,sys
r=json.load(open(\"$newest\"))
print(\"  client_ip=\",r.get(\"client_ip\"),\" model=\",(r.get(\"request\") or {}).get(\"model\"),\" status=\",r.get(\"status\"))
" 2>/dev/null
    echo "model names seen in last 20 records:"
    ls -t $LOGDIR/*.json 2>/dev/null | head -20 | xargs -r grep -ho "\"model\"[^,]*" 2>/dev/null | sort -u' 2>&1
