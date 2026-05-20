#!/bin/bash
# Per-Pi clone customization. Operates on the loop-mounted clone rootfs.
# Usage: bash clone_customize.sh <TARGET_HOSTNAME>
# Run as root. Executed as a FILE (not via `wsl -lc '...'`) to avoid the
# nested-quote/var-expansion mangling seen with inline wsl bash -lc.
set -euo pipefail

TARGET="${1:?usage: clone_customize.sh <hostname>}"
R=/mnt/clone-rootfs

[ -d "$R" ] || { echo "FATAL: $R not a dir"; exit 1; }
[ -f "$R/etc/hostname" ] || { echo "FATAL: $R/etc/hostname missing - not mounted?"; exit 1; }
SRC_HOST="$(cat "$R/etc/hostname")"
[ "$SRC_HOST" = "evobot" ] || { echo "FATAL: clone hostname is '$SRC_HOST', expected 'evobot' - wrong fs mounted, ABORT"; exit 1; }

echo "[1] hostname evobot -> $TARGET"
echo "$TARGET" > "$R/etc/hostname"
sed -i "s/\bevobot\b/$TARGET/g" "$R/etc/hosts"
# The EvoBot baseline's 127.0.1.1 line is 'pitest' (an old name), NOT 'evobot',
# so the sed above misses it -> system can't resolve its own hostname (cosmetic
# sudo warnings + possible service hiccups). Force the loopback line to $TARGET.
if grep -qE '^127\.0\.1\.1[[:space:]]' "$R/etc/hosts"; then
  sed -i "s/^127\.0\.1\.1[[:space:]].*/127.0.1.1\t$TARGET/" "$R/etc/hosts"
else
  printf '127.0.1.1\t%s\n' "$TARGET" >> "$R/etc/hosts"
fi

echo "[2] SSH host keys: GENERATE fresh per-host (do NOT rely on first-boot regen)"
# CRITICAL: the baseline's regenerate_ssh_host_keys.service is the RPi run-once
# type that already self-disabled on EvoBot years ago. Removing the keys and
# hoping for first-boot regen leaves the clone with NO host keys -> sshd's
# ExecStartPre 'sshd -t' fails -> ssh.service never starts -> no SSH, no console
# = unrecoverable without a card pull (this bit pi02 hard). Generate unique keys
# now, deterministically, with literal paths.
rm -f "$R"/etc/ssh/ssh_host_*
ssh-keygen -q -t rsa     -b 3072 -N "" -C "$TARGET" -f "$R/etc/ssh/ssh_host_rsa_key"
ssh-keygen -q -t ecdsa          -N "" -C "$TARGET" -f "$R/etc/ssh/ssh_host_ecdsa_key"
ssh-keygen -q -t ed25519        -N "" -C "$TARGET" -f "$R/etc/ssh/ssh_host_ed25519_key"
chmod 600 "$R"/etc/ssh/ssh_host_*_key
chmod 644 "$R"/etc/ssh/ssh_host_*_key.pub
chown 0:0 "$R"/etc/ssh/ssh_host_*
[ "$(ls "$R"/etc/ssh/ssh_host_*_key 2>/dev/null | wc -l)" -eq 3 ] || { echo "FATAL: host-key generation failed (check ssh-keygen + that \$R resolved)"; exit 1; }

echo "[3] machine-id: empty file (NOT absent) so systemd regenerates uniquely"
# 'rm -f' (absent) did NOT trigger first-boot regen on this image (pi02 booted
# with no machine-id). An EMPTY /etc/machine-id is the documented systemd
# first-boot-provisioning trigger and IS reliable.
: > "$R/etc/machine-id"
chmod 444 "$R/etc/machine-id"
rm -f "$R/var/lib/dbus/machine-id"   # usually a symlink to /etc/machine-id; regenerated

echo "[4] eth0 NetworkManager -> DHCP"
NM="$R/etc/NetworkManager/system-connections/Wired connection 1.nmconnection"
if [ -f "$NM" ]; then
  sed -i 's/^method=manual/method=auto/' "$NM"
  sed -i '/^address1=/d' "$NM"
  sed -i '/^dns=/d' "$NM"
  echo "    patched: Wired connection 1.nmconnection -> $(grep -E '^method=' "$NM" | head -1 | tr -d '\n') (address1/dns removed)"
else
  echo "    WARN: 'Wired connection 1.nmconnection' not found; clone will rely on default DHCP" >&2
fi

echo "[5] strip per-host runtime state (keep .wireclaw-secrets.env - fleet-shared)"
rm -f "$R"/home/scott/.telethon-evobot.session*
rm -f "$R"/home/scott/.overnight-capture.status*
rm -f "$R"/home/scott/overnight-capture.log
rm -f "$R"/home/scott/j4-stdout.log "$R"/home/scott/overnight-stdout.log

echo "[6] provenance breadcrumb"
cat > "$R/home/scott/SDCARD_PROVENANCE.md" <<EOF
# SD card provenance

Source:     evobot SD captured 2026-05-16 (byte-perfect dd of /dev/sde, 63864569856 B)
Shrunk:     on azza (e2fsprogs 1.47) 60G -> 3.7G + first-boot auto-expand
Cloned to:  $TARGET
Cloned at:  $(date -u +%Y-%m-%dT%H:%M:%SZ)
Procedure:  bench/fork/lora/SDCARD_PROVISIONING.md (Path C: shrink-on-azza)

Cleanup performed at clone time:
  - hostname set to $TARGET; /etc/hosts evobot->$TARGET AND 127.0.1.1 line
    forced to $TARGET (baseline had stale '127.0.1.1 pitest')
  - /etc/ssh/ssh_host_* REGENERATED unique to $TARGET at clone time
    (NOT left to first-boot regen - that service self-disabled on EvoBot)
  - /etc/machine-id emptied (0 bytes, not removed) -> systemd makes a
    unique id on first boot; dbus machine-id removed
  - 'Wired connection 1.nmconnection' eth0: method manual->auto,
    address1=192.168.1.51/24 + dns removed (was: static; now DHCP)
  - ~/.telethon-evobot.session* removed (re-auth on first run)
  - ~/.overnight-capture.status*, overnight/j4 logs removed (stale)

Carries over from EvoBot baseline:
  - Raspbian Bookworm 12, Python 3.11.2, WiFi creds, scott uid 1000, NOPASSWD sudo
  - ~/phase31-venv (telethon + requests + pyyaml)
  - ~/wireclaw-phase31 (persona_runner, personas, overnight_capture.sh w/ rule-purge)
  - ~/.wireclaw-secrets.env (TG_API_* shared across fleet - intentionally kept)
  - workstation SSH key in ~/.ssh/authorized_keys

First boot: mDNS $TARGET.local, DHCP IP (eth0 + wlan0). SSH host keys are
pre-generated (sshd starts first boot). If the workstation has a stale key
for this host's IP: ssh-keygen -R <ip>  (DHCP may recycle IPs across the fleet).
EOF
chown 1000:1000 "$R/home/scott/SDCARD_PROVENANCE.md"

echo "RESULT $TARGET: hostname=$(cat "$R/etc/hostname") loopback=$(grep -E '^127\.0\.1\.1' "$R/etc/hosts" | tr -s '[:space:]' ' ') hostkeys=$(ls "$R"/etc/ssh/ssh_host_*_key 2>/dev/null | wc -l)/3 machineid_bytes=$(stat -c %s "$R/etc/machine-id" 2>/dev/null) telethon=$(ls "$R"/home/scott/.telethon-evobot.session* 2>/dev/null | wc -l) secrets_kept=$(ls "$R"/home/scott/.wireclaw-secrets.env 2>/dev/null | wc -l) nm_method=$(grep -hE '^method=' "$NM" 2>/dev/null | head -1)"
