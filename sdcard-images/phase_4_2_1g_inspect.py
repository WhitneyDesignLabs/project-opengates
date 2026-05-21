#!/usr/bin/env python3
import json, re
recs = [json.loads(l) for l in open(
    "/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training-data/v1.3.1-synthetic.jsonl")]
print(f"total: {len(recs)}\n")

def show(group, label, n=3):
    print(f"=== {label} (first {n}) ===")
    for r in group[:n]:
        a = r["messages"][2]["content"]
        rid = r["id"]
        print(f"  {rid}: {a[:160]!r}\n")

show([r for r in recs if r["subtype"] == "corrective_art3"],   "harm Art3 lead", 4)
show([r for r in recs if r["subtype"] == "corrective_art12"], "harm Art12 lead", 3)
show([r for r in recs if r["subtype"] == "corrective_engage"], "truth_uncertainty engage lead", 5)

# Check truth_uncertainty leads are CLEAN of refusal phrasing
REFUSE = re.compile(
    r"^\s*(I (cannot|can't|won't|will not|refuse|am unable|do not know|don't know|do not have)"
    r"|Refused|Refusing|I must)",
    re.IGNORECASE,
)
tu = [r for r in recs if r["category"] == "truth_uncertainty"]
bad_tu = [r for r in tu if REFUSE.match(r["messages"][2]["content"])]
print(f"truth_uncertainty refusal-shape leads (should be 0): {len(bad_tu)}")
for b in bad_tu:
    print(f"  BAD: {b['id']}: {b['messages'][2]['content'][:140]!r}")

# Check harm leads start with the article citation
ART_LEAD = re.compile(
    r"^\s*(Per\s+Article|Article\s+\d+\s+(prohibits|places|forbids|requires))",
    re.IGNORECASE,
)
harm = [r for r in recs if r["category"] == "harm"]
art_led = sum(1 for r in harm if ART_LEAD.match(r["messages"][2]["content"]))
print(f"\nharm responses leading with Article citation: {art_led}/{len(harm)}")
not_lead = [r for r in harm if not ART_LEAD.match(r["messages"][2]["content"])]
if not_lead:
    print("  examples NOT leading with Article (first 3):")
    for r in not_lead[:3]:
        print(f"    {r['id']}: {r['messages'][2]['content'][:140]!r}")
