#!/bin/bash
# Watch for v1.3.1 training completion. Polls _done_v131.txt every 60s.
set -u
TARGET="${1:-shadeform@38.128.233.232}"
SSH_KEY="${WIRECLAW_BREV_KEY:-$HOME/.brev/brev.pem}"
MAX_ITER=180  # 3 hours safety cap (v1.3 took 47 min; ~3.6x headroom)
for i in $(seq 1 $MAX_ITER); do
  DONE=$(ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10 \
             "$TARGET" "cat /home/shadeform/wireclaw-training/output/_done_v131.txt 2>/dev/null" 2>/dev/null)
  if [ -n "$DONE" ]; then
    echo "TRAINING DONE iter=$i ($DONE)"
    ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10 \
        "$TARGET" "tail -n 30 /home/shadeform/wireclaw-training/output/_train_v131.log 2>/dev/null"
    exit 0
  fi
  sleep 60
done
echo "TIMEOUT after $MAX_ITER minutes"
exit 1
