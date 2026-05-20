#!/bin/bash
# Phase 4.0.3 Step 1: install esptool on pi02 + pi03.
set -u
K="$HOME/.ssh/evobot_ed25519"
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i $K"

inst() {
  local IP=$1 NAME=$2
  echo "==== $NAME ($IP) ===="
  $SSH scott@"$IP" 'sudo -n apt-get update -qq >/dev/null 2>&1;
      sudo -n apt-get install -y esptool >/tmp/esptool-apt.log 2>&1;
      if command -v esptool >/dev/null 2>&1; then
        echo "apt-path OK"; esptool version 2>&1 | head -1;
      else
        echo "apt-path FAILED (tail of log:)"; tail -3 /tmp/esptool-apt.log;
        echo "trying venv fallback...";
        python3 -m venv ~/esptool-venv 2>&1 | tail -1;
        ~/esptool-venv/bin/pip install --quiet esptool 2>&1 | tail -1;
        ~/esptool-venv/bin/esptool version 2>&1 | head -1 && echo "venv-path OK";
      fi' 2>&1
}

inst 192.168.1.17 pi02
inst 192.168.1.44 pi03
