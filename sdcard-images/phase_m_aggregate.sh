#!/bin/bash
# Phase 3.1.3 M4: aggregate per-chip on the WINDOW-FILTERED proxy dir.
set -u
BENCH="/mnt/c/Users/homet/Documents/WireClaw/bench"
F="$HOME/3.1.3-proxy-window"
OUTDIR="$BENCH/fork/lora/corpus-raw"
SID_DATE="2026-05-16"   # run start date (directive: yesterday)
mkdir -p "$OUTDIR"
cd "$BENCH" || exit 2

for spec in "192.168.1.19:pilot" "192.168.1.15:c6-02" "192.168.1.47:c6-03"; do
  ip=${spec%%:*}; label=${spec##*:}
  echo "================ chip $label ($ip) ================"
  python3 fork/lora/aggregate_overnight.py \
      --proxy-logs "$F" \
      --persona persona_01_basic \
      --session-id "3.1.3-$SID_DATE-$label" \
      --client-ip "$ip" \
      --out "$OUTDIR/3.1.3-$SID_DATE-$label.json" 2>&1
  echo
done
echo "== corpus-raw 3.1.3 outputs =="
ls -la "$OUTDIR"/3.1.3-2026-05-16-*.json
