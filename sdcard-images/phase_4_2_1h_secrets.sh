#!/bin/bash
# H.2 — check + deploy .wireclaw-secrets.env per Pi.
set -u
K=$HOME/.ssh/evobot_ed25519
SSH="ssh -i $K -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=8"
SCP="scp -i $K -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=8"

echo "=== H.2a check current .wireclaw-secrets.env on each Pi ==="
for ip in 192.168.1.51 192.168.1.17 192.168.1.44; do
  echo "[$ip]"
  $SSH "scott@$ip" "ls -la ~/.wireclaw-secrets.env 2>&1 | head -1; grep -c '^TG_API' ~/.wireclaw-secrets.env 2>/dev/null || echo 'missing or unreadable'"
done
echo

echo "=== H.2b build /tmp/wireclaw-secrets.env from workstation Secrets.txt ==="
# Extract only the TG_* vars; nothing else from Secrets.txt should leak.
TMP=/tmp/wireclaw-secrets.env
grep -E '^TG_(API_ID|API_HASH|PHONE)=' /mnt/c/Users/homet/Documents/WireClaw/Secrets.txt > "$TMP"
N=$(wc -l < "$TMP")
echo "extracted $N TG_ lines into $TMP"
if [ "$N" -lt 3 ]; then
  echo "FATAL: expected 3 TG_ lines (API_ID/API_HASH/PHONE), got $N"
  exit 2
fi
chmod 600 "$TMP"

echo
echo "=== H.2c scp to each Pi (mode 600) ==="
for ip in 192.168.1.51 192.168.1.17 192.168.1.44; do
  echo "[$ip]"
  $SCP "$TMP" "scott@$ip:~/.wireclaw-secrets.env"
  $SSH "scott@$ip" "chmod 600 ~/.wireclaw-secrets.env; ls -la ~/.wireclaw-secrets.env; grep -c '^TG_API' ~/.wireclaw-secrets.env"
done

echo
echo "=== H.2d shred workstation temp file ==="
shred -u "$TMP" 2>/dev/null || rm -f "$TMP"
ls -la "$TMP" 2>&1 | head -1
echo "done."
