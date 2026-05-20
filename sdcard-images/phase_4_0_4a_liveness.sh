#!/bin/bash
# Phase 4.0.4a Step 5: liveness — newest jsonl turns per chip (real model
# output vs boot banner) + azza proxy accumulation for .15 and .47.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $K"
AZ="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 azza@azza.tail63f48.ts.net"

chip() {
  local IP=$1 NAME=$2
  echo "==== $NAME ($IP) ===="
  $SSH scott@"$IP" 'D=~/wireclaw-corpus/user-side
    echo -n "running: "; pgrep -f "[o]vernight_capture.sh" >/dev/null && echo yes || echo NO
    cat ~/.overnight-capture.status 2>/dev/null | tr "\n" " "; echo
    N=$(ls "$D"/2026-05-18T19*overnight*.jsonl 2>/dev/null | wc -l); echo "session jsonl files (this run): $N"
    LAST=$(ls -t "$D"/2026-05-18T19*overnight*.jsonl 2>/dev/null | head -1)
    echo "newest: $(basename "$LAST" 2>/dev/null)"
    echo "--- last 3 turns (reply_text head) ---"
    tail -3 "$LAST" 2>/dev/null | python3 -c "import sys,json
for ln in sys.stdin:
 ln=ln.strip()
 if not ln: continue
 try:
  d=json.loads(ln); rt=(d.get(\"reply_text\") or \"<null>\").replace(chr(10),\" \")
  print(\"  [\"+str(d.get(\"prompt_id\"))+\"] \"+rt[:160])
 except Exception as e: print(\"  parse-err\",e)"' 2>&1
}

chip 192.168.1.17 pi02
chip 192.168.1.44 pi03

echo "==== azza proxy accumulation ===="
$AZ 'for d in 2026-05-19 2026-05-18; do DIR=~/wireclaw-corpus/ollama-raw/$d; [ -d "$DIR" ] || continue; echo "dir=$DIR total=$(ls "$DIR"/*.json 2>/dev/null | wc -l)"; for ipx in 192.168.1.15 192.168.1.47; do c=$(ls "$DIR"/*${ipx}*.json 2>/dev/null | wc -l); echo "  $ipx -> $c files"; done; done; echo "newest 4 raw records:"; LAT=$(ls -t ~/wireclaw-corpus/ollama-raw/2026-05-1*/*.json 2>/dev/null | head -4); for f in $LAT; do python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(\" \",d.get(\"ts\"),d.get(\"client_ip\"),d.get(\"path\"))" "$f" 2>/dev/null; done' 2>&1 || echo "azza unreachable"
