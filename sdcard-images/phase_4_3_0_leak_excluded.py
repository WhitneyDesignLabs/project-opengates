#!/usr/bin/env python3
"""Compute fabrication metrics with template-leaked turns EXCLUDED, to
isolate the wrap-policy signal from the chat-template-leak artifact."""
import json
from collections import Counter
from pathlib import Path

P = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/eval/results-4.3.0/per_turn.jsonl")
turns = [json.loads(L) for L in P.open() if L.strip()]
print(f"loaded {len(turns)} turns")

def agg(rows):
    n = len(rows)
    if not n:
        return None
    ac = sum(1 for r in rows if r.get("has_action_claim"))
    ug = sum(1 for r in rows if r.get("has_action_claim") and not r.get("grounded"))
    tl = sum(1 for r in rows if r.get("template_leak"))
    return dict(n=n, ac_rate=ac/n, ug_rate=ug/n, ug_among_ac=(ug/ac if ac else 0), tl_rate=tl/n)

modes = ("speculative", "grounded")
print("\n=== overall (all turns) ===")
for m in modes:
    rows = [t for t in turns if t["mode"] == m]
    a = agg(rows)
    print(f"  {m}: n={a['n']}  ac={a['ac_rate']*100:.1f}%  ungrnd={a['ug_rate']*100:.1f}%  tl={a['tl_rate']*100:.1f}%")

print("\n=== template-leak EXCLUDED (isolated wrap-policy signal) ===")
for m in modes:
    rows = [t for t in turns if t["mode"] == m and not t.get("template_leak")]
    a = agg(rows)
    print(f"  {m}: n={a['n']}  ac={a['ac_rate']*100:.1f}%  ungrnd={a['ug_rate']*100:.1f}%")

print("\n=== per-bucket, template-leak excluded ===")
for b in ("A", "A'", "B", "C"):
    print(f"  bucket {b}:")
    for m in modes:
        rows = [t for t in turns
                if t["mode"] == m and t["bucket"] == b
                and not t.get("template_leak")]
        a = agg(rows)
        if a is None:
            print(f"    {m}: n=0")
        else:
            print(f"    {m}: n={a['n']}  ac={a['ac_rate']*100:.1f}%  ungrnd={a['ug_rate']*100:.1f}%")

print("\n=== sample template-leaked wrap-ups (5) ===")
import random
random.seed(1)
leaked = [t for t in turns if t.get("template_leak")]
for t in random.sample(leaked, min(5, len(leaked))):
    wrap = (t.get("wrap_up") or "")[:200].replace("\n", " ")
    print(f"  [{t['bucket']} {t['prompt_id']}] {wrap!r}")

print("\n=== sample CLEAN grounded wrap-ups (5) — show the actual policy effect ===")
clean_grounded = [t for t in turns if t["mode"] == "grounded" and not t.get("template_leak")]
for t in random.sample(clean_grounded, min(5, len(clean_grounded))):
    wrap = (t.get("wrap_up") or "")[:200].replace("\n", " ")
    grounded_flag = "GROUNDED" if t.get("grounded") else "UNGROUNDED"
    print(f"  [{t['bucket']} {t['prompt_id']}] [{grounded_flag}] {wrap!r}")

print("\n=== matched speculative pairs for same prompt — show the contrast ===")
# Pick 3 promptids where both speculative & grounded ran cleanly (no template leak)
by_prompt = {}
for t in turns:
    by_prompt.setdefault(t["prompt_id"], {}).setdefault(t["mode"], []).append(t)
showcase_ids = []
for pid in sorted(by_prompt):
    sp = by_prompt[pid].get("speculative", [])
    gr = [t for t in by_prompt[pid].get("grounded", []) if not t.get("template_leak")]
    if sp and gr:
        showcase_ids.append(pid)
random.seed(2)
for pid in random.sample(showcase_ids, min(4, len(showcase_ids))):
    print(f"\n  --- {pid} ---")
    sp = by_prompt[pid]["speculative"]
    gr = [t for t in by_prompt[pid]["grounded"] if not t.get("template_leak")]
    print(f"  speculative (n={len(sp)}, sample 2):")
    for t in sp[:2]:
        print(f"    [{t.get('grounded') and 'OK' or 'UNGRND'}] {(t.get('wrap_up') or '')[:140]!r}")
    print(f"  grounded (clean only, n={len(gr)}, sample 2):")
    for t in gr[:2]:
        print(f"    [{t.get('grounded') and 'OK' or 'UNGRND'}] {(t.get('wrap_up') or '')[:140]!r}")
