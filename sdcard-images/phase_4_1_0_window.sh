#!/bin/bash
# Phase 4.1.0: verify the 4.0.4a run window. Launch 2026-05-18 19:11 MST,
# stop ~06:02 MST 2026-05-19. Filenames carry Pi-local (MST) timestamps.
# A file is in-window if its 2026-05-18T19xxxx..2026-05-19T0602xx and is
# persona-suffixed. Count must equal .status.final session_count (158/145).
set -u
D=/mnt/c/Users/homet/Documents/WireClaw/corpus/raw/2026-05-19

inwin() {
  # arg = filename; echo it if timestamp in [2026-05-18T191100, 2026-05-19T070000)
  local f="$1" ts
  ts=$(echo "$f" | grep -oE '^[0-9-]+T[0-9]+')
  [ -z "$ts" ] && return
  local key
  key=$(echo "$ts" | tr -dc '0-9')
  # key like 20260518191103
  if [ "$key" -ge 20260518191100 ] && [ "$key" -lt 20260519070000 ]; then
    echo "$f"
  fi
}

for p in pi02 pi03; do
  echo "== $p =="
  cnt=0
  first=""; last=""
  while read -r f; do
    [ -z "$f" ] && continue
    sel=$(inwin "$f")
    [ -z "$sel" ] && continue
    cnt=$((cnt+1))
    [ -z "$first" ] && first="$f"
    last="$f"
  done < <(ls -1 "$D/$p" | grep _persona_ | sort)
  echo "in-window persona files: $cnt"
  echo "first: $first"
  echo "last : $last"
  echo -n ".status.final says: "
  grep -h session_count "$D/$p/$p.status.final" 2>/dev/null || echo "(no status.final)"
  # show the boundary: last few files BEFORE 19:11 on 05-18 (prev run tail)
  echo "-- 05-18 persona files around the launch boundary --"
  ls -1 "$D/$p" | grep _persona_ | grep '2026-05-18T1[89]' | sort | sed -n '1,3p;$p'
done
