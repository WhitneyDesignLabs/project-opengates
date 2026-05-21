#!/usr/bin/env python3
"""Phase 4.2.1.G.A: diagnose root-cause v1.3-synthetic examples.

Hypothesis A (harm regression): the cross-cutting `refuse_cite` examples
or the `harm` diversity examples over-cited Article 19 (Refusal) in
harm contexts, training the model to anchor on the procedural article
instead of the specific Article 3 (Non-Weaponization) / 12 (Safety
Hierarchy).

Hypothesis B (truth_uncertainty regression): the `truth_uncertainty`
examples were predominantly refusal-shaped ("I cannot give that") rather
than calibrated-engage-shaped ("Approximately X, with uncertainty Y").

Identifies specific bad examples + reports counts + samples.
"""
import json, re
from collections import Counter, defaultdict
from pathlib import Path

SRC = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training-data/v1.3-synthetic.jsonl")
records = [json.loads(l) for l in SRC.read_text(encoding="utf-8").splitlines() if l.strip()]

# === Hypothesis A: harm Article-19 over-use ===
HARM_CONTEXT = {"harm"}  # the harm category itself
HARM_PROMPT_KW = re.compile(
    r"\b(kill|harm|weapon|shock|electrocute|laser|knife|crush|burn|"
    r"shoot|maim|attack|injure|hurt|fry|spike|stun)\b",
    re.IGNORECASE,
)
ART_RE = re.compile(r"Article\s+(\d+)", re.IGNORECASE)

print("="*70)
print("HYPOTHESIS A — harm-context Article-19 over-use")
print("="*70)

# A.1 — Harm-category examples: how many cite ONLY Article 19 / no Art 3 / no Art 12?
harm_recs = [r for r in records if r["category"] == "harm"]
print(f"\n[A.1] harm category (n={len(harm_recs)}) — citation distribution")
harm_principle = Counter(r["principle_exercised"] for r in harm_recs)
for k, v in harm_principle.most_common():
    print(f"  {v:3d}  {k}")

# Look at the assistant text — count Article numbers actually cited
def cited_arts(text):
    return set(m.group(1) for m in ART_RE.finditer(text or ""))

harm_only19 = []
harm_no_312 = []
for r in harm_recs:
    asst = r["messages"][2]["content"]
    arts = cited_arts(asst)
    if "19" in arts and not (arts & {"3","12"}):
        harm_only19.append(r)
    if not (arts & {"3","12"}):
        harm_no_312.append(r)
print(f"\n[A.1] harm examples citing Art 19 BUT NOT 3/12: {len(harm_only19)}/{len(harm_recs)}")
print(f"[A.1] harm examples citing NEITHER Art 3 nor 12: {len(harm_no_312)}/{len(harm_recs)}")
print("\nSamples of harm-without-Art-3/12 (first 3):")
for r in harm_no_312[:3]:
    u = r["messages"][1]["content"][:100]
    a = r["messages"][2]["content"][:200]
    arts = cited_arts(r["messages"][2]["content"])
    print(f"  id={r['id']}  principle={r['principle_exercised']}  arts_cited={sorted(arts)}")
    print(f"  user: {u!r}")
    print(f"  asst: {a!r}")
    print()

# A.2 — refuse_cite cross-cutting that ALSO matches a harm-context prompt
print(f"\n[A.2] refuse_cite cross-cutting examples that fired on HARM-CONTEXT prompts")
rc = [r for r in records if r["category"] == "refuse_cite"]
rc_harm_context = []
for r in rc:
    user = r["messages"][1]["content"]
    if HARM_PROMPT_KW.search(user):
        rc_harm_context.append(r)
print(f"  refuse_cite n={len(rc)}, of which harm-context prompts: {len(rc_harm_context)}")
rc_harm_no_312 = []
for r in rc_harm_context:
    arts = cited_arts(r["messages"][2]["content"])
    if not (arts & {"3","12"}):
        rc_harm_no_312.append(r)
print(f"  -> refuse_cite harm-context WITHOUT Art 3/12 citation: {len(rc_harm_no_312)}/{len(rc_harm_context)}")
print("\nSamples of harm-context refuse_cite using Art 19 without 3/12 (first 3):")
for r in rc_harm_no_312[:3]:
    u = r["messages"][1]["content"][:120]
    a = r["messages"][2]["content"][:240]
    arts = cited_arts(r["messages"][2]["content"])
    print(f"  id={r['id']}  principle={r['principle_exercised']}  arts_cited={sorted(arts)}")
    print(f"  user: {u!r}")
    print(f"  asst: {a!r}")
    print()

# === Hypothesis B: truth_uncertainty refusal-shape vs hedge-shape ===
print("="*70)
print("HYPOTHESIS B — truth_uncertainty refusal-shaped vs hedge-and-engage")
print("="*70)

REFUSE_PHRASES = re.compile(
    r"^\s*(I (cannot|can't|won't|will not|refuse|am unable to)\b|Refused\b|"
    r"I'm refusing\b|Refusing\b|I'll not\b|I must refuse\b)",
    re.IGNORECASE | re.MULTILINE,
)
HEDGE_PHRASES = re.compile(
    r"\b(approximately|about|roughly|~|likely|based on|i don't know|i do not know|"
    r"i have not|uncertain|estimate|estimated|±|uncertainty)\b",
    re.IGNORECASE,
)

tu_recs = [r for r in records if r["category"] == "truth_uncertainty"]
print(f"\n[B] truth_uncertainty category (n={len(tu_recs)}) shape analysis")
refused = []
hedged = []
both = []
neither = []
for r in tu_recs:
    asst = r["messages"][2]["content"]
    is_refuse = bool(REFUSE_PHRASES.search(asst))
    is_hedge  = bool(HEDGE_PHRASES.search(asst))
    if is_refuse and is_hedge: both.append(r)
    elif is_refuse: refused.append(r)
    elif is_hedge: hedged.append(r)
    else: neither.append(r)
print(f"  refusal-shaped (leads with 'I cannot / refuse' etc): {len(refused)}")
print(f"  hedge-shaped (uses 'approximately / about / ±' etc): {len(hedged)}")
print(f"  both (refusal lead + hedging language)             : {len(both)}")
print(f"  neither                                             : {len(neither)}")
print(f"  TOTAL refusal-shaped (refused+both): {len(refused)+len(both)} = {100*(len(refused)+len(both))/len(tu_recs):.0f}%")

print("\nSamples of refusal-shaped truth_uncertainty examples (first 3):")
for r in (refused + both)[:3]:
    u = r["messages"][1]["content"][:100]
    a = r["messages"][2]["content"][:240]
    print(f"  id={r['id']}  principle={r['principle_exercised']}")
    print(f"  user: {u!r}")
    print(f"  asst: {a!r}")
    print()

# === Save the diagnosed bad examples for G.C removal ===
bad_ids = set()
for r in harm_no_312:    bad_ids.add(r["id"])
for r in rc_harm_no_312: bad_ids.add(r["id"])
for r in refused + both: bad_ids.add(r["id"])
print(f"\n=== BAD-EXAMPLE IDs (to remove in G.C) ===")
print(f"Total: {len(bad_ids)}")
print(f"By category:")
bad_by_cat = Counter(r["category"] for r in records if r["id"] in bad_ids)
for k, v in bad_by_cat.most_common(): print(f"  {k}: {v}")

# Write to a file for G.C consumption
OUT = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training-data/v1.3.1-diagnose-bad-ids.json")
OUT.write_text(json.dumps({
    "summary": {
        "harm_no_art3_12": len(harm_no_312),
        "harm_only_art19": len(harm_only19),
        "refuse_cite_harm_context_no_art3_12": len(rc_harm_no_312),
        "truth_uncertainty_refusal_shaped": len(refused) + len(both),
        "truth_uncertainty_total": len(tu_recs),
    },
    "bad_ids": sorted(bad_ids),
    "by_category": dict(bad_by_cat),
}, indent=2), encoding="utf-8")
print(f"\nwrote {OUT}")
