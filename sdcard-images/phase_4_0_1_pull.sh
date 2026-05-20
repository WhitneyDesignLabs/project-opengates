#!/bin/bash
# Phase 4.0.1 Step 3a: pull all user-side JSONL from pi02 + pi03.
set -u
K="$HOME/.ssh/evobot_ed25519"
SCP="scp -q -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
DEST=/mnt/c/Users/homet/Documents/WireClaw/corpus/raw/2026-05-17
mkdir -p "$DEST/pi02" "$DEST/pi03"

$SCP scott@192.168.1.17:'~/wireclaw-corpus/user-side/*.jsonl' "$DEST/pi02/"
echo "pi02: $(ls "$DEST"/pi02/*.jsonl 2>/dev/null | wc -l) files"
$SCP scott@192.168.1.44:'~/wireclaw-corpus/user-side/*.jsonl' "$DEST/pi03/"
echo "pi03: $(ls "$DEST"/pi03/*.jsonl 2>/dev/null | wc -l) files"
