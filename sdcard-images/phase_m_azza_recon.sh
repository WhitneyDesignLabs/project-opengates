#!/bin/bash
# Phase 3.1.3 M2 recon: azza proxy-log inventory + proxy health + disk.
set -u
A="ssh -o BatchMode=yes -o ConnectTimeout=8 azza@192.168.1.60"

echo "== ollama-raw date dirs (last 6) =="
$A 'ls -1 ~/wireclaw-corpus/ollama-raw/ 2>/dev/null | tail -6'
echo "== file counts 2026-05-16 / 2026-05-17 =="
$A 'for d in 2026-05-16 2026-05-17; do n=$(ls -1 ~/wireclaw-corpus/ollama-raw/$d/ 2>/dev/null | wc -l); echo "$d: $n files"; done'
echo "== proxy service =="
$A 'systemctl --user status wireclaw-ollama-proxy.service 2>/dev/null | grep -E "Active:|Main PID:|since"'
echo "== azza disk (home fs) + corpus size =="
$A 'df -h $HOME | tail -1; du -sh ~/wireclaw-corpus/ 2>/dev/null; du -sh ~/wireclaw-corpus/ollama-raw/2026-05-16 ~/wireclaw-corpus/ollama-raw/2026-05-17 2>/dev/null'
echo "== stray transient img (worklog flagged for delete) =="
$A 'ls -lh ~/evobot-source-2026-05-16.img 2>/dev/null || echo "(absent - already cleaned)"'
