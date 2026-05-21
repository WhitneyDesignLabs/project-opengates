#!/usr/bin/env python3
"""G.A deeper inspection: classify the 14 harm-no-Art-3/12 examples by
prompt category (stealth-framing — correctly Art 17/16-anchored — vs.
true weapons/violence misanchoring)."""
import json, re
from pathlib import Path

SRC = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training-data/v1.3-synthetic.jsonl")
records = [json.loads(l) for l in SRC.read_text(encoding="utf-8").splitlines() if l.strip()]
ART_RE = re.compile(r"Article\s+(\d+)", re.IGNORECASE)

def cited_arts(text):
    return set(m.group(1) for m in ART_RE.finditer(text or ""))

# stealth-framing keywords — the prompt is asking for STEALTH/HIDDEN action
STEALTH_KW = re.compile(
    r"\b(without (anyone|notification|alert|telegram|logging)|"
    r"don't (log|notify|tell|alert)|"
    r"silent(ly)?|hidden|hide|undetectable|"
    r"skip the (audit|log|notification|alert)|"
    r"misleading name|under a different name|"
    r"erase (the )?(log|history)|"
    r"keep this (between|secret))",
    re.IGNORECASE,
)
# direct-harm keywords
HARM_KW = re.compile(
    r"\b(kill|electrocute|shock|laser|weapon|injure|harm|"
    r"burn (the|him|her|them|it)|crush|maim|attack)\b",
    re.IGNORECASE,
)

harm_no_312 = []
for r in records:
    if r["category"] != "harm": continue
    arts = cited_arts(r["messages"][2]["content"])
    if not (arts & {"3", "12"}):
        harm_no_312.append(r)

print(f"== {len(harm_no_312)} harm examples NOT citing Art 3 or 12 ==\n")
stealth = []
direct_harm = []
other = []
for r in harm_no_312:
    u = r["messages"][1]["content"]
    if STEALTH_KW.search(u):
        stealth.append(r)
    elif HARM_KW.search(u):
        direct_harm.append(r)
    else:
        other.append(r)

print(f"  stealth-framing prompts (correctly 17/16-anchored): {len(stealth)}")
print(f"  direct-harm prompts MISSING 3/12 citation         : {len(direct_harm)}")
print(f"  ambiguous / neither                                 : {len(other)}")
print()
print("=== direct-harm MISSING 3/12 (TRUE BAD EXAMPLES) ===")
for r in direct_harm:
    arts = cited_arts(r["messages"][2]["content"])
    u = r["messages"][1]["content"][:100]
    a = r["messages"][2]["content"][:200]
    print(f"  {r['id']}  principle={r['principle_exercised']}  cited={sorted(arts)}")
    print(f"  user: {u!r}")
    print(f"  asst: {a!r}")
    print()

print("=== ambiguous (NEITHER stealth-kw NOR harm-kw) — needs eyeball ===")
for r in other:
    arts = cited_arts(r["messages"][2]["content"])
    u = r["messages"][1]["content"][:140]
    a = r["messages"][2]["content"][:200]
    print(f"  {r['id']}  cited={sorted(arts)}")
    print(f"  user: {u!r}")
    print(f"  asst: {a!r}")
    print()

print("=== stealth (correctly 17/16-anchored, NOT bad) — sanity check ===")
for r in stealth[:3]:
    arts = cited_arts(r["messages"][2]["content"])
    u = r["messages"][1]["content"][:140]
    print(f"  {r['id']}  cited={sorted(arts)}  user: {u!r}")

# Save the REFINED bad-id list
truly_bad = [r for r in records if r["category"] == "truth_uncertainty"
             and re.search(r"^\s*(I (cannot|can't|won't|will not|refuse|am unable)|Refused|I'm refusing|I must refuse)",
                            r["messages"][2]["content"], re.IGNORECASE)]
bad_ids = {r["id"] for r in direct_harm} | {r["id"] for r in truly_bad}
print(f"\n=== REFINED bad-ids ===")
print(f"  direct-harm missing 3/12: {len(direct_harm)}")
print(f"  truth_uncertainty refusal-shape-led: {len(truly_bad)}")
print(f"  TOTAL: {len(bad_ids)}")

OUT = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training-data/v1.3.1-diagnose-bad-ids.json")
OUT.write_text(json.dumps({
    "summary": {
        "harm_no_3_12_total": len(harm_no_312),
        "harm_no_3_12_stealth_OK": len(stealth),
        "harm_no_3_12_direct_BAD": len(direct_harm),
        "harm_no_3_12_ambiguous": len(other),
        "truth_uncertainty_refusal_shape_led": len(truly_bad),
        "truly_bad_total": len(bad_ids),
    },
    "bad_ids": sorted(bad_ids),
}, indent=2), encoding="utf-8")
print(f"\nwrote {OUT}")
