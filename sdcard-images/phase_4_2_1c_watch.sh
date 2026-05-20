#!/bin/bash
# Watch for v1.3 training completion. Polls ~/wireclaw-training/output/_done.txt
# on the Brev instance every 60s. Exits 0 when the done flag appears.
set -u
TARGET="${1:-shadeform@185.216.22.114}"
SSH_KEY="${WIRECLAW_BREV_KEY:-$HOME/.ssh/id_ed25519}"

# Poll up to 3 hours (~180 minutes) — safety cap. Training ETA ~50 min, so this
# is ~3.6× headroom for slowdowns or unexpected pauses.
MAX_ITER=180
for i in $(seq 1 $MAX_ITER); do
  DONE=$(ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10 \
             "$TARGET" "cat /home/shadeform/wireclaw-training/output/_done.txt 2>/dev/null" 2>/dev/null)
  if [ -n "$DONE" ]; then
    echo "TRAINING DONE iter=$i ($DONE)"
    # capture last few lines for the notification
    ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10 \
        "$TARGET" "tail -n 25 /home/shadeform/wireclaw-training/output/_train.log 2>/dev/null"
    exit 0
  fi
  sleep 60
done
echo "TIMEOUT after $MAX_ITER minutes — training still going or stuck"
exit 1
