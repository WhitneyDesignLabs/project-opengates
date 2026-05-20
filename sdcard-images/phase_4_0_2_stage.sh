#!/bin/bash
# Phase 4.0.2: stage built firmware onto pi02 (c6-02's paired Pi).
# Staging only — NO flash, chip is powered off. Flash gated on Scott.
set -eu
K="$HOME/.ssh/evobot_ed25519"
S="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K scott@192.168.1.17"
SCP="scp -q -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -i $K"
B=/mnt/c/Users/homet/Documents/WireClaw-fork/.pio/build/esp32-c6

$S 'mkdir -p ~/fw-4.0.2'
$SCP "$B/firmware.factory.bin" "$B/firmware.bin" "$B/bootloader.bin" "$B/partitions.bin" scott@192.168.1.17:'~/fw-4.0.2/'
echo "--- local sha256 ---"
sha256sum "$B/firmware.factory.bin" "$B/firmware.bin"
echo "--- pi02 sha256 + listing ---"
$S 'cd ~/fw-4.0.2 && sha256sum firmware.factory.bin firmware.bin && ls -la'
