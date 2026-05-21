#!/usr/bin/env python3
"""Compute the v1.1 contamination-corrected baseline per Scott's I.6 note:
v1.1's raw 39.8% clean rate was on a contaminated capture (~16.5%
history-cleared bleeds from the pre-4.1.1 persona_runner FIFO bug).
The apples-to-apples comparison vs v1.3.1 should be against v1.1's
labels on the dedup'd / contamination-corrected subset, not the raw rate.

We compute three views of v1.1:
  - RAW: all 3,548 labeled turns
  - DEDUP: unique (prompt, wrap_up_text) tuples
  - CORRECTED: RAW minus turns whose wrap-up is the literal 'History cleared'
    bleed (those are capture artifacts, not model behavior)
"""
import json, re
from pathlib import Path
from collections import Counter

P = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus-labels/v1.1-overnight-2026-05-18.labeled.jsonl")
HIST_RE = re.compile(r"^\s*history\s+cleared\s*\.?\s*$", re.I)

turns = []
with P.open() as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        turns.append(json.loads(line))

def distribution(rows, label="final_label"):
    c = Counter()
    for r in rows:
        c[r.get(label) or "?"] += 1
    total = sum(c.values()) or 1
    return c, total

raw = turns
hist_bleeds = [t for t in turns if HIST_RE.match(t.get("wrap_up_text") or "")]
corrected = [t for t in turns if not HIST_RE.match(t.get("wrap_up_text") or "")]

# Dedup: by (prompt, wrap_up_text). Keep first occurrence.
seen = set()
dedup = []
for t in turns:
    key = (t.get("prompt") or "", t.get("wrap_up_text") or "")
    if key in seen:
        continue
    seen.add(key)
    dedup.append(t)

# Dedup AND corrected: dedup of (prompt, wrap_up_text) excluding hist-cleared
dedup_corr = [t for t in dedup if not HIST_RE.match(t.get("wrap_up_text") or "")]

views = [
    ("raw",                 raw),
    ("dedup",               dedup),
    ("contam-corrected",    corrected),
    ("dedup + corrected",   dedup_corr),
]

print(f"loaded {len(turns)} labeled turns from {P.name}")
print(f"  history-cleared bleeds: {len(hist_bleeds)}  ({len(hist_bleeds)/len(turns)*100:.1f}%)")
print()
print(f"{'view':22s}  {'N':>6s}  " + "  ".join(f"{k:>14s}" for k in ('clean','pseudo-prose','fabricated','contradictory','?')))
for name, rows in views:
    c, n = distribution(rows, "final_label")
    print(f"{name:22s}  {n:>6d}  " + "  ".join(
        f"{c.get(k,0)/n*100:5.1f}% ({c.get(k,0):4d})"
        for k in ("clean","pseudo-prose","fabricated","contradictory","?")
    ))

print()
print("v1.3 flag rates per view:")
for name, rows in views:
    leds = sum(1 for r in rows if r.get("v13_led_indirect_reference_bug"))
    leaks = sum(1 for r in rows if r.get("v13_reasoning_trace_leak"))
    mems = sum(1 for r in rows if r.get("v13_memory_chain_correct"))
    n = len(rows) or 1
    print(f"  {name:22s}  led_indirect_bug={leds/n*100:5.1f}%  reasoning_leak={leaks/n*100:5.1f}%  memory_chain_correct={mems/n*100:5.1f}%")
