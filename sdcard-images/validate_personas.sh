#!/bin/bash
# Dry-run each listed persona (no Telegram) to confirm the module loads.
# Args: bot-username, then persona names.
BOT="$1"; shift
PY=~/phase31-venv/bin/python
R=~/wireclaw-phase31/bench/fork/lora/persona_runner.py
fail=0
for p in "$@"; do
  if "$PY" "$R" --persona "$p" --bot-username "$BOT" --dry-run >/tmp/dr.out 2>&1; then
    echo "OK    $p ($(grep -c . /tmp/dr.out) lines)"
  else
    echo "FAIL  $p rc=$? -- $(tail -1 /tmp/dr.out)"
    fail=1
  fi
done
echo "VALIDATE_RESULT=$([ $fail -eq 0 ] && echo PASS || echo FAIL)"
