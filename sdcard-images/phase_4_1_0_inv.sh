#!/bin/bash
# Phase 4.1.0: classify pulled files — this-run (persona-suffixed) vs old.
set -u
D=/mnt/c/Users/homet/Documents/WireClaw/corpus/raw/2026-05-19
for p in pi02 pi03; do
  echo "== $p persona-suffixed files by date prefix =="
  ls -1 "$D/$p" | grep _persona_ | sed -E 's/T[0-9]+_.*//' | sort | uniq -c
  echo -n "$p persona-suffixed total: "
  ls -1 "$D/$p" | grep -c _persona_ || true
  echo -n "$p non-persona overnight (old runs): "
  ls -1 "$D/$p" | grep overnight | grep -vc _persona_ || true
  echo "-- persona-suffixed window (first/last) --"
  ls -1 "$D/$p" | grep _persona_ | sort | sed -n '1p;$p'
done
