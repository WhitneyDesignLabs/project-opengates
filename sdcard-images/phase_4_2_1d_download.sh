#!/bin/bash
# Phase 4.2.1.D download: scp the v1.3-brev adapter + GGUF off Brev.
set -u
TARGET="shadeform@185.216.22.114"
SSH_KEY="$HOME/.ssh/id_ed25519"
LOCAL_PARENT=/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training/output
LOCAL_OUT="$LOCAL_PARENT/wireclaw-v1.3-brev"
rm -rf "$LOCAL_OUT"
mkdir -p "$LOCAL_PARENT"
scp -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -r \
    "$TARGET:/home/shadeform/wireclaw-training/output/wireclaw-v1.3-brev" \
    "$LOCAL_PARENT/"
echo "== local content =="
ls -la "$LOCAL_OUT/"
