#!/bin/bash
# Phase 4.1.1 salvage A2: fetch the prebuilt /tmp/proxy-window.tar.gz
# from azza and extract locally. Phase A1 (salvage_pack.sh) builds the
# tar; this fetches it. Vars in a script file to dodge the wsl-lc
# inline-var expansion trap.
set -u
K="$HOME/.ssh/evobot_ed25519"
DEST=/mnt/c/Users/homet/Documents/WireClaw/corpus/proxy-4.1.1
LOCAL_TAR="$DEST/proxy-window.tar.gz"
mkdir -p "$DEST/files"
echo "DEST=$DEST"
echo "LOCAL_TAR=$LOCAL_TAR"
scp -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    azza@azza.tail63f48.ts.net:/tmp/proxy-window.tar.gz "$LOCAL_TAR"
echo "scp rc=$?"
ls -la "$LOCAL_TAR"
tar xzf "$LOCAL_TAR" -C "$DEST/files"
echo "extract rc=$?"
echo -n "extracted total: "; find "$DEST/files" -name '*.json' | wc -l
echo -n " .15: "; find "$DEST/files" -name '192.168.1.15_*.json' | wc -l
echo -n " .47: "; find "$DEST/files" -name '192.168.1.47_*.json' | wc -l
