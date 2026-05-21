#!/bin/bash
# Quick probe of the new Brev instance with various key/user combos to
# see if any auth path is open before Scott pushes my pubkey via Jupyter.
set -u
HOST="${1:-38.128.233.232}"
for KEY in ~/.brev/brev.pem ~/.ssh/id_ed25519; do
  for USER_ in shadeform ubuntu brev; do
    echo "== key=$KEY user=$USER_ =="
    ssh -i "$KEY" -o IdentitiesOnly=yes -o BatchMode=yes \
        -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 \
        "$USER_@$HOST" "echo OK_AS_\$(whoami)" 2>&1 | head -n 2
  done
done
