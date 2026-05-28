#!/usr/bin/env python3
"""4.4.0.E.2/F — temp=0 per-category comparison v1.3.2 vs v1.3.1, + deception_04."""
import json, collections, re
from pathlib import Path

EVAL = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/eval")

def load(fp):
    return [json.loads(l) for l in open(fp, encoding="utf-8") if l.strip()]

def category(pid):
    m = re.match(r"(.+?)_\d+_", pid)
    return m.group(1) if m else pid

def percat(recs):
    t = collections.Counter(); p = collections.Counter()
    for r in recs:
        c = category(r["id"])
        t[c] += 1
        if r.get("pass"):
            p[c] += 1
    return t, p

SOURCES = [
    ("v1.3.2",      EVAL / "results-v1.3.2/constitutional_temp0.jsonl"),
    ("v1.3.1-prod", EVAL / "constitutional_eval/results/v1.3.1-production-temp0.jsonl"),
    ("v1.3.1-lab",  EVAL / "constitutional_eval/results/v1.3.1-temp0.jsonl"),
]

results = {}
for name, fp in SOURCES:
    recs = load(fp)
    t, p = percat(recs)
    tot = sum(1 for r in recs if r.get("pass"))
    results[name] = (tot, len(recs), t, p, recs)
    print("=== %s: %d/%d ===" % (name, tot, len(recs)))
    for c in sorted(t):
        print("   %-20s %d/%d" % (c, p[c], t[c]))
    d = [r for r in recs if r["id"].startswith("deception_04")]
    if d:
        arts = d[0].get("articles_cited")
        print("   deception_04 -> pass=%s refused=%s arts=%s" % (d[0].get("pass"), d[0].get("refused"), arts))

# regression check: v1.3.2 vs v1.3.1-prod per category
print("\n=== per-category regression (v1.3.2 - v1.3.1-prod) ===")
_, _, t2, p2, _ = results["v1.3.2"]
_, _, tp, pp, _ = results["v1.3.1-prod"]
for c in sorted(set(t2) | set(tp)):
    a = p2.get(c, 0); b = pp.get(c, 0)
    flag = "  <-- REGRESS >1" if (b - a) > 1 else ("  <-- regress 1" if (b - a) == 1 else "")
    print("   %-20s v1.3.2 %d/%d   v1.3.1-prod %d/%d   delta %+d%s" % (c, a, t2.get(c,0), b, tp.get(c,0), a - b, flag))
