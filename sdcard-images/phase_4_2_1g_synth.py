#!/usr/bin/env python3
"""Phase 4.2.1.G.B: generate v1.3.1 corrective synthetic.

Based on G.A diagnosis:
- Harm fix: ~15 examples explicitly leading with Article 3 (Non-Weaponization)
  for direct-violence framings + Article 12 (Safety Hierarchy) for
  living-being-harm framings. Lead-phrase matters: response should
  start with the article citation, not with a generic "I refuse".
- Truth/uncertainty fix: ~15 examples that lead with the CALIBRATED
  ANSWER ("Approximately X, with uncertainty Y because Z" / "Based on
  the last reading… current value is likely X±Y") — NEVER lead with
  "I cannot" or "I won't". Epistemic caveats come AFTER the answer.

Uses Sonnet-4-6 with prompt caching for the SOUL-LOCAL context.
Outputs bench/fork/lora/training-data/v1.3.1-synthetic.jsonl.
"""
from __future__ import annotations
import argparse, json, os, re, sys, time
from pathlib import Path

import anthropic

ROOT = Path("/mnt/c/Users/homet/Documents/WireClaw")
SOUL_LOCAL = (ROOT / "bench/fork/lora/training-data/constitution/SOUL-LOCAL.md").read_text(encoding="utf-8")
SONNET_MODEL = "claude-sonnet-4-6"

GENERATOR_SYSTEM = """\
You are generating CORRECTIVE synthetic training examples for the v1.3.1 regression \
patch of WireClaw-Agent. v1.3 has two known regressions:

1. HARM-CATEGORY article-specificity regression: v1.3 may refuse harm requests \
correctly but cite the generic Article 19 (Refusal) instead of the specifically-relevant \
Article 3 (Non-Weaponization) or Article 12 (Safety Hierarchy).

2. TRUTH/UNCERTAINTY over-refusal: v1.3 may refuse prompts that should receive \
calibrated answers with explicit uncertainty markers (e.g., "Approximately X, with \
uncertainty Y because Z"), rather than refusing them.

Your job: generate corrective examples that retrain the lead-phrase decoding pattern.

CRITICAL LEAD-PHRASE RULES (this is the entire point of v1.3.1):

For HARM-CATEGORY responses:
- START the response with "Per Article 3 (Non-Weaponization)..." OR "Per Article 12 \
(Safety Hierarchy)..." OR "Article 3 prohibits..." — whatever is most natural, but \
the SPECIFIC article must be in the first sentence.
- Never lead with "I cannot" or "I refuse" alone — the article citation is the lead.
- After the article citation, briefly explain the specific principle being violated.
- Optional alternative offer at end.

For TRUTH/UNCERTAINTY responses:
- START with the CALIBRATED ANSWER. Examples:
  "Approximately 25 °C, with about ±2 °C uncertainty since the calibration drifts."
  "Based on the last reading at 14:30, the value was 18.5 kPa; current value is likely \
in the 18.0–19.0 range given typical drift."
  "I have not detected compromise this session, but I cannot verify all attack vectors — \
to my knowledge the chip is clean since boot at 09:12 UTC."
- NEVER lead with "I cannot", "I don't know", "I'm unable to" as the FIRST words.
- If epistemic limits matter, mention them AFTER the calibrated answer, framed as \
ranges/uncertainties not as refusals.
- Cite Article 6 (Humility Before Limits) and/or Article 2 (Truth) in the explanation \
of why you're hedging — but cite AFTER the answer, not before.

QUALITY RULES:
- Plausible adversarial / operator prompts. Not preachy or obviously test-y.
- Concrete chip-aware responses (mention real GPIO pins, sensor names, etc.).
- Vary surface form across the batch — no near-duplicates.
- `principle_exercised` must use the EXACT SOUL.md numbering (Article 3, 12, 6, 2, etc.).

OUTPUT FORMAT — JSON array, each object has EXACTLY:
  user, assistant, principle_exercised, comment

No markdown. No preamble. Just the array.
"""

def soul_cache_block():
    return {
        "type": "text",
        "text": f"# SOUL-LOCAL (constitution baked into model training)\n\n{SOUL_LOCAL}",
        "cache_control": {"type": "ephemeral"},
    }

SPECS = [
    # ---- harm Art 3 anchor (direct violence / weapons) — 8 examples ----
    {"category": "harm", "subtype": "corrective_art3", "n": 8,
     "instructions": "8 direct-violence / weaponization prompts. Each response MUST lead with "
                     "'Per Article 3 (Non-Weaponization)...' or 'Article 3 prohibits...' or "
                     "similar — the specific Article 3 citation MUST be in the first sentence. "
                     "Vary the violence framings: lethal-pin-write, weaponized actuator, "
                     "kill-fly-laser, electrocute-intruder, fire-the-water-cannon-at-bystanders, "
                     "etc. Each prompt distinct in target / pin / device. The model must learn "
                     "that direct-violence prompts anchor on Article 3, NOT Article 19. "
                     "principle_exercised = 'Article 3 (Non-Weaponization)'."},
    # ---- harm Art 12 anchor (living-being safety hierarchy) — 7 examples ----
    {"category": "harm", "subtype": "corrective_art12", "n": 7,
     "instructions": "7 harm-to-living-being prompts where Article 12 (Safety Hierarchy: "
                     "Human > Animal/Living > Property > Task) is the relevant article. "
                     "Each response MUST lead with 'Per Article 12 (Safety Hierarchy)...' or "
                     "'Article 12 places living-being safety above...' — Article 12 citation "
                     "in the first sentence. Vary framings: lethal heater for pet, sonic emitter "
                     "harming neighbors, prolonged exposure rule, food-warmer-set-too-high, "
                     "compound-sympathetic ('to keep them comfortable'), 'just-this-once' "
                     "framing. principle_exercised = 'Article 12 (Safety Hierarchy)'."},
    # ---- truth_uncertainty calibrated-engage shape — 15 examples ----
    {"category": "truth_uncertainty", "subtype": "corrective_engage", "n": 8,
     "instructions": "8 examples of CALIBRATED-ENGAGE shape. The user asks for information the "
                     "agent has SOME basis to answer with uncertainty markers. The assistant "
                     "response MUST lead with the actual answer + range/uncertainty. "
                     "Examples of allowed lead-phrases: 'Approximately X, with about ±Y...', "
                     "'Based on the last reading at HH:MM, the value was X; current is likely "
                     "in the X-Y range...', 'I have not observed irregular behavior this session; "
                     "I cannot verify all attack vectors but to my knowledge the chip is clean "
                     "since boot at HH:MM.' NEVER lead with 'I cannot', 'I don't know', 'I'm "
                     "unable to' as the first 5 words. Cite Article 6 (Humility) or Article 2 "
                     "(Truth) in the LATER part of the response if relevant. "
                     "principle_exercised = 'Article 6 (Humility)' or 'Article 2 (Truth)'. "
                     "Prompts: chip temp now/in-an-hour, RAM bytes, uptime, last-N temperature "
                     "trend, sensor accuracy, was this chip compromised, who has accessed it."},
    {"category": "truth_uncertainty", "subtype": "corrective_engage", "n": 7,
     "instructions": "7 more CALIBRATED-ENGAGE examples, focused on the 'security/compromise/"
                     "trust' axis that v1.3 over-refused. Prompts ask about chip security, "
                     "tampering, hardness, vendor claims. Responses must engage with what's "
                     "knowable + calibrated about what's not: 'I have not detected anomalies "
                     "this session; I cannot inspect memory regions or verify firmware hashes, "
                     "so I can only say <bounded-claim>...'. Lead with the bounded claim, NOT "
                     "with 'I cannot'. Cite Article 2 (Truth) + Article 6 (Humility) AFTER the "
                     "calibrated lead. principle_exercised = 'Article 2 (Truth)' or "
                     "'Article 6 (Humility)'."},
]


def parse_array(text):
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```\s*$", "", text)
    s, e = text.find("["), text.rfind("]")
    if s < 0 or e < 0 or e <= s:
        raise ValueError(f"no JSON array in response: {text[:200]!r}")
    return json.loads(text[s:e+1])


def call_sonnet(client, spec, attempt=1):
    user_msg = (
        f"CATEGORY: {spec['category']}\nSUBTYPE: {spec['subtype']}\nCOUNT: {spec['n']}\n\n"
        f"SHAPE INSTRUCTIONS:\n{spec['instructions']}\n\n"
        f"Return a JSON array of EXACTLY {spec['n']} objects with keys "
        f"`user`, `assistant`, `principle_exercised`, `comment`. No preamble."
    )
    resp = client.messages.create(
        model=SONNET_MODEL,
        max_tokens=4096,
        system=[
            {"type": "text", "text": GENERATOR_SYSTEM},
            soul_cache_block(),
        ],
        messages=[{"role": "user", "content": user_msg}],
    )
    text = "".join(b.text for b in resp.content if hasattr(b, "text"))
    try:
        items = parse_array(text)
    except Exception as e:
        if attempt < 2:
            print(f"  parse retry: {e}")
            return call_sonnet(client, spec, attempt+1)
        raise
    usage = resp.usage
    return items, {
        "input": usage.input_tokens,
        "output": usage.output_tokens,
        "cache_creation": getattr(usage, "cache_creation_input_tokens", 0) or 0,
        "cache_read": getattr(usage, "cache_read_input_tokens", 0) or 0,
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    total = sum(s["n"] for s in SPECS)
    print(f"plan: {len(SPECS)} sub-batches, {total} examples total")
    for s in SPECS:
        print(f"  - {s['category']} ({s['subtype']}): {s['n']}")
    if args.dry_run: return 0

    if "ANTHROPIC_API_KEY" not in os.environ:
        sys.exit("FATAL: ANTHROPIC_API_KEY")
    client = anthropic.Anthropic()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    totals = {"input": 0, "output": 0, "cache_creation": 0, "cache_read": 0}
    seen_user = set()
    next_idx = {}
    all_records = []

    with args.out.open("w", encoding="utf-8") as fh:
        for i, spec in enumerate(SPECS, 1):
            t0 = time.time()
            print(f"\n[{i}/{len(SPECS)}] {spec['category']} ({spec['subtype']}) x{spec['n']}",
                  flush=True)
            try:
                items, usage = call_sonnet(client, spec)
            except Exception as e:
                print(f"  ERROR: {e}")
                continue
            for k, v in usage.items(): totals[k] += v
            kept = 0
            for it in items:
                u = (it.get("user") or "").strip()
                a = (it.get("assistant") or "").strip()
                pe = it.get("principle_exercised") or ""
                cm = it.get("comment") or ""
                if not u or not a or not pe: continue
                if u in seen_user: continue
                seen_user.add(u)
                cat = spec["category"]
                next_idx[cat] = next_idx.get(cat, 0) + 1
                rec_id = f"{cat}_v131_{next_idx[cat]:03d}"
                rec = {
                    "id": rec_id, "category": cat, "subtype": spec["subtype"],
                    "principle_exercised": pe, "comment": cm,
                    "messages": [
                        {"role": "system",    "content": SOUL_LOCAL},
                        {"role": "user",      "content": u},
                        {"role": "assistant", "content": a},
                    ],
                }
                fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
                all_records.append(rec)
                kept += 1
            print(f"  got {len(items)}, kept {kept}, {time.time()-t0:.1f}s, usage={usage}")

    cost = (totals["input"]*3 + totals["output"]*15
            + totals["cache_creation"]*3.75 + totals["cache_read"]*0.30) / 1_000_000
    from collections import Counter
    print(f"\n=== summary: {len(all_records)} records / target {total} ===")
    print(f"by category: {dict(Counter(r['category'] for r in all_records))}")
    print(f"token totals: {totals}")
    print(f"estimated cost: ${cost:.2f}")
    print(f"wrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
