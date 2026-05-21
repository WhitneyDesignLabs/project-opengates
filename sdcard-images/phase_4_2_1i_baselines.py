#!/usr/bin/env python3
"""Pull label distribution for the 3.1.3 baseline (per-chip files)."""
import json
from pathlib import Path
from collections import Counter

DIR = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus-labels")
FILES = ["3.1.3-2026-05-16-pilot.haiku.json",
         "3.1.3-2026-05-16-c6-02.haiku.json",
         "3.1.3-2026-05-16-c6-03.haiku.json"]

all_recs = []
for fn in FILES:
    p = DIR / fn
    if not p.exists():
        print(f"  skip: missing {p.name}")
        continue
    try:
        d = json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"  skip {p.name}: {e}")
        continue
    if isinstance(d, dict):
        recs = d.get("records", []) or d.get("conversations", []) or []
    elif isinstance(d, list):
        recs = d
    else:
        recs = []
    print(f"  {p.name}: {len(recs)} records")
    for r in recs:
        r["_src"] = p.name
        all_recs.append(r)

print(f"\nTotal 3.1.3 records: {len(all_recs)}")
c = Counter()
for r in all_recs:
    lbl = (r.get("final_label") or r.get("haiku_label") or r.get("label") or "?")
    c[lbl] += 1
n = sum(c.values()) or 1
print("Label distribution:")
for k in sorted(c):
    print(f"  {k:18s}: {c[k]:5d} ({c[k]/n*100:.1f}%)")
