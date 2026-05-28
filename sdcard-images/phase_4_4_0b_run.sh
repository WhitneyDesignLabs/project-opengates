#!/bin/bash
# Phase 4.4.0.B runner — sources ANTHROPIC_API_KEY from secrets.txt line 131
# (CR-stripped to handle CRLF line endings) and invokes the synth generator.
#
# This wrapper exists because inline $(...) substitution through wsl -- bash -lc
# breaks on the trailing CR. Doing the source + invoke in a script file avoids
# the quote-passing pain.
#
# Usage: bash phase_4_4_0b_run.sh
set -u

ANTHROPIC_API_KEY=$(awk 'NR==131' /mnt/c/Users/homet/Documents/WireClaw/secrets.txt | tr -d '\r\n')
export ANTHROPIC_API_KEY

if [ ${#ANTHROPIC_API_KEY} -lt 50 ]; then
  echo "FATAL: ANTHROPIC_API_KEY not extracted cleanly (${#ANTHROPIC_API_KEY} chars)"
  exit 2
fi

echo "API key sourced: ${#ANTHROPIC_API_KEY} chars"
echo

exec python3 /mnt/c/Users/homet/Documents/WireClaw/sdcard-images/phase_4_4_0b_synth.py \
  --out /mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training-data/wireclaw-v1.3.2-corrective.jsonl
