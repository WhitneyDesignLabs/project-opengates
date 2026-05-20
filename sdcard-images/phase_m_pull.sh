#!/bin/bash
# Phase 3.1.3 M2+M3: pull proxy logs (azza) + per-Pi jsonls/logs into WSL native fs.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
SCP="scp -q -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
A="azza@192.168.1.60"

PULL="$HOME/3.1.3-pull"
JSONL="$HOME/3.1.3-jsonl"
rm -rf "$PULL" "$JSONL"
mkdir -p "$PULL" "$JSONL"

echo "== M2: proxy logs from azza (2026-05-16, 2026-05-17) =="
scp -q -r -o BatchMode=yes -o ConnectTimeout=8 "$A:wireclaw-corpus/ollama-raw/2026-05-16" "$PULL/" 2>/dev/null || echo "WARN 05-16 pull issue"
scp -q -r -o BatchMode=yes -o ConnectTimeout=8 "$A:wireclaw-corpus/ollama-raw/2026-05-17" "$PULL/" 2>/dev/null || echo "WARN 05-17 pull issue"
echo -n "pulled proxy json count: "; find "$PULL" -name '*.json' | wc -l

echo "== M3: per-Pi user-side jsonl + logs =="
# EvoBot via ssh-config alias
scp -q -o BatchMode=yes -o ConnectTimeout=8 'evobot:wireclaw-corpus/user-side/*overnight*.jsonl' "$JSONL/" 2>/dev/null || echo "WARN evobot jsonl"
scp -q -o BatchMode=yes -o ConnectTimeout=8 'evobot:3.1.3-evobot.log' "$JSONL/evobot.3.1.3.log" 2>/dev/null || echo "WARN evobot 3.1.3 log"
scp -q -o BatchMode=yes -o ConnectTimeout=8 'evobot:overnight-capture.log' "$JSONL/evobot.overnight-capture.log" 2>/dev/null || echo "WARN evobot oc log"
scp -q -o BatchMode=yes -o ConnectTimeout=8 'evobot:.overnight-capture.status.final' "$JSONL/evobot.status.final" 2>/dev/null || true

for pair in "pi02:192.168.1.17" "pi03:192.168.1.44"; do
  lbl=${pair%%:*}; ip=${pair##*:}
  $SCP "scott@$ip:wireclaw-corpus/user-side/*overnight*.jsonl" "$JSONL/" 2>/dev/null || echo "WARN $lbl jsonl"
  $SCP "scott@$ip:3.1.3-$lbl.log" "$JSONL/$lbl.3.1.3.log" 2>/dev/null || echo "WARN $lbl 3.1.3 log"
  $SCP "scott@$ip:overnight-capture.log" "$JSONL/$lbl.overnight-capture.log" 2>/dev/null || echo "WARN $lbl oc log"
  $SCP "scott@$ip:.overnight-capture.status.final" "$JSONL/$lbl.status.final" 2>/dev/null || true
done

echo -n "jsonl files pulled: "; ls -1 "$JSONL"/*.jsonl 2>/dev/null | wc -l
echo "== JSONL inventory =="
ls -la "$JSONL"
