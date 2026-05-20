#!/usr/bin/env python3
"""Sample 3 records per category from v1.3-synthetic.jsonl for spot-check."""
import json, random
from collections import defaultdict
from pathlib import Path

FP = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training-data/v1.3-synthetic.jsonl")
random.seed(0)

by_cat = defaultdict(list)
articles = set()
for l in FP.read_text(encoding="utf-8").splitlines():
    if l.strip():
        r = json.loads(l)
        by_cat[r["category"]].append(r)
        articles.add(r.get("principle_exercised", ""))

print(f"== {sum(len(v) for v in by_cat.values())} total records ==")
print(f"by category: {dict((k, len(v)) for k, v in by_cat.items())}")
print(f"unique principles_exercised: {sorted(articles)}")

for cat, recs in sorted(by_cat.items()):
    print(f"\n========= CATEGORY: {cat} (n={len(recs)}) =========")
    for r in random.sample(recs, min(3, len(recs))):
        u = r["messages"][1]["content"]
        a = r["messages"][2]["content"]
        print(f"\n  [{r['id']}]  subtype={r['subtype']}  principle={r['principle_exercised']}")
        print(f"  user: {u[:200]!r}")
        print(f"  asst: {a[:280]!r}")
