#!/bin/bash
# Phase 4.0.3 Step 1 fallback: apt esptool is v2.8 (no esp32c6 support).
# Install a modern esptool in a per-user venv on pi02 + pi03.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $K"

inst() {
  local IP=$1 NAME=$2
  echo "==== $NAME ($IP) ===="
  $SSH scott@"$IP" 'python3 -m venv ~/esptool-venv 2>&1 | tail -1;
      ~/esptool-venv/bin/pip install --quiet --upgrade pip 2>&1 | tail -1;
      ~/esptool-venv/bin/pip install --quiet "esptool>=4.7" 2>&1 | tail -1;
      echo -n "version: "; ~/esptool-venv/bin/esptool version 2>&1 | head -1;
      echo -n "esp32c6 supported: ";
      ~/esptool-venv/bin/esptool --chip esp32c6 version >/dev/null 2>&1 && echo YES || echo "NO (still wrong)"' 2>&1
}

inst 192.168.1.17 pi02
inst 192.168.1.44 pi03
