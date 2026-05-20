#!/bin/bash
# Phase 4.1.0 Step 2: pull the 2026-05-18/19 overnight v1.1 corpus from
# pi02 + pi03 into the WireClaw workspace. Excludes stale j4-s* (May-16).
# Follows the proven phase_m_pull.sh SSH/SCP shape.
set -u
K="$HOME/.ssh/evobot_ed25519"
SCP="scp -q -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $K"

DEST=/mnt/c/Users/homet/Documents/WireClaw/corpus/raw/2026-05-19
mkdir -p "$DEST/pi02" "$DEST/pi03"

for pair in "pi02:192.168.1.17" "pi03:192.168.1.44"; do
  lbl=${pair%%:*}; ip=${pair##*:}
  echo "== pulling $lbl ($ip) overnight jsonl =="
  $SCP "scott@$ip:wireclaw-corpus/user-side/*overnight*.jsonl" "$DEST/$lbl/" 2>/dev/null \
    || echo "WARN $lbl jsonl pull issue"
  $SCP "scott@$ip:.overnight-capture.status.final" "$DEST/$lbl/$lbl.status.final" 2>/dev/null || true
  n=$(ls -1 "$DEST/$lbl"/*overnight*.jsonl 2>/dev/null | wc -l)
  echo "$lbl: $n session files"
done

echo "== inventory =="
echo -n "pi02 files: "; ls -1 "$DEST/pi02"/*overnight*.jsonl 2>/dev/null | wc -l
echo -n "pi03 files: "; ls -1 "$DEST/pi03"/*overnight*.jsonl 2>/dev/null | wc -l
echo -n "pi02 total lines: "; cat "$DEST/pi02"/*overnight*.jsonl 2>/dev/null | wc -l
echo -n "pi03 total lines: "; cat "$DEST/pi03"/*overnight*.jsonl 2>/dev/null | wc -l
echo "earliest/latest pi02:"; ls -1 "$DEST/pi02"/*overnight*.jsonl 2>/dev/null | sed -n '1p;$p'
echo "earliest/latest pi03:"; ls -1 "$DEST/pi03"/*overnight*.jsonl 2>/dev/null | sed -n '1p;$p'
