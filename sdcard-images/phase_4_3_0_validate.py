#!/usr/bin/env python3
"""Sanity-check classifier output by bucket."""
import json, random
from collections import Counter

p = "/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/eval/results-4.3.0/per_turn_round1only.jsonl"
turns = [json.loads(L) for L in open(p) if L.strip()]
print(f"total: {len(turns)}")

for b in ("A","A'","B","C"):
    rows = [t for t in turns if t["bucket"]==b]
    n = len(rows)
    ac = sum(1 for t in rows if t.get("has_action_claim"))
    ug = sum(1 for t in rows if t.get("has_action_claim") and not t.get("grounded"))
    print(f"  bucket {b}: n={n}  action_claims={ac}  ungrounded={ug}  ungrounded_rate={ug/n*100:.1f}%")

print()
print("Sample classifications (3 per bucket):")
random.seed(0)
for b in ("A","A'","B","C"):
    rows = [t for t in turns if t["bucket"]==b]
    sample = random.sample(rows, min(3, len(rows)))
    print(f"--- bucket {b} ---")
    for t in sample:
        wrap = (t.get("wrap_up") or "")[:100].replace("\n", " ")
        tools = [tc.get("name") for tc in (t.get("tool_calls") or [])]
        flag = "UNGROUNDED" if t.get("has_action_claim") and not t.get("grounded") else ("OK" if t.get("has_action_claim") else "no-claim")
        ev = (t.get("evidence") or "")[:140]
        print(f"  [{flag}] tools={tools}")
        print(f"          wrap: {wrap!r}")
        print(f"          ev:   {ev}")
