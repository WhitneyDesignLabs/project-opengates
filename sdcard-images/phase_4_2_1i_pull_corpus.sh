#!/bin/bash
# Phase 4.2.1.I.2: pull user-side jsonls from all 3 Pis to workstation.
# Window: launched 2026-05-20 17:56 MST, stopped 2026-05-21 06:02 MST.
# Filter by filename timestamp prefix (jsonls are named 2026-05-20T<HHMMSS>_...
# and 2026-05-21T<HHMMSS>_...).
set -u
K=$HOME/.ssh/evobot_ed25519
SCP="scp -i $K -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=15"

DEST=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus/v1.3.1-overnight-2026-05-20
mkdir -p "$DEST/user-side/evobot" "$DEST/user-side/pi02" "$DEST/user-side/pi03"

echo "=== pull user-side jsonls ==="
for spec in evobot:192.168.1.51 pi02:192.168.1.17 pi03:192.168.1.44; do
  name=${spec%%:*}; ip=${spec##*:}
  echo "[$name $ip]"
  # Grab all jsonls with 2026-05-20T or 2026-05-21T prefix (covers full run window).
  $SCP "scott@$ip:~/wireclaw-corpus/user-side/2026-05-2[01]T*.jsonl" "$DEST/user-side/$name/" 2>&1 | tail -n 3
  N=$(ls "$DEST/user-side/$name/" | wc -l)
  echo "  $name pulled: $N files"
  echo
done

echo
echo "=== totals on workstation ==="
for d in evobot pi02 pi03; do
  N=$(ls "$DEST/user-side/$d/" | wc -l)
  L=$(cat "$DEST/user-side/$d"/*.jsonl 2>/dev/null | wc -l)
  echo "$d: $N files, $L total lines (Telegram-paired turns)"
done

echo
echo "=== verify azza proxy still has both date dirs ==="
ssh -o BatchMode=yes -o ConnectTimeout=10 azza@azza.tail63f48.ts.net "
for d in 2026-05-20 2026-05-21; do
  if [ -d ~/wireclaw-corpus/ollama-raw/\$d ]; then
    N=\$(ls ~/wireclaw-corpus/ollama-raw/\$d/*.json 2>/dev/null | wc -l)
    echo \"  azza \$d: \$N records\"
  else
    echo \"  azza \$d: (missing)\"
  fi
done
"
