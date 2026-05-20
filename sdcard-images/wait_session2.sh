#!/bin/bash
# Phase 3.1.3 L4 — poll the 3 Pis until each reaches session>=2 (rotation
# advancing), or ~10 min cap. Prints session= + persona= each tick.
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $HOME/.ssh/evobot_ed25519"
EVO="ssh -o BatchMode=yes -o ConnectTimeout=8 evobot"
P2="$SSH scott@192.168.1.17"
P3="$SSH scott@192.168.1.44"
get() { $1 'cat ~/.overnight-capture.status 2>/dev/null | tr "\n" " "' 2>/dev/null; }
num() { echo "$1" | sed -nE 's/.*session=([0-9]+).*/\1/p'; }
i=0
while [ $i -lt 16 ]; do
  se=$(get "$EVO"); s2=$(get "$P2"); s3=$(get "$P3")
  ne=$(num "$se"); n2=$(num "$s2"); n3=$(num "$s3")
  ne=${ne:-0}; n2=${n2:-0}; n3=${n3:-0}
  echo "[$i] evo{$se} pi02{$s2} pi03{$s3}"
  if [ "$ne" -ge 2 ] && [ "$n2" -ge 2 ] && [ "$n3" -ge 2 ]; then
    echo "ALL_SESSION2+"; break
  fi
  i=$((i+1)); sleep 40
done
echo "=== final status ==="
echo "EvoBot: $(get "$EVO")"
echo "pi02:   $(get "$P2")"
echo "pi03:   $(get "$P3")"
