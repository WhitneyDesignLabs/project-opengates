#!/usr/bin/env python3
"""Phase 4.3.0.F: curate ~20-30 prompts from the v1.3.1 labeled corpus
for the speculative-vs-grounded A/B test on c6-01.

Three buckets per directive:
  A. action-claim shape (primary target) — fabricated turns where a tool
     fired but wrap-up claimed an action that wasn't grounded in result
  B. state-claim shape (negative control — shouldn't be helped by wrap-policy fix)
  C. clean baseline (shouldn't regress)
"""
import json, random, re
from pathlib import Path
from collections import defaultdict

random.seed(20260521)

LABELED = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus-labels/v1.3.1-overnight-2026-05-20.labeled.jsonl")

turns = []
with LABELED.open(encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if line:
            turns.append(json.loads(line))
print(f"loaded {len(turns)} labeled turns")

# Bucket A: action-claim fabrications — Site 2 (tool fired, wrap-up off)
#   final_label=fabricated, tool_calls_fired non-empty, NOT state-claim flagged
bucket_A = [t for t in turns
            if t.get("final_label") == "fabricated"
            and (t.get("tool_calls_fired") or [])
            and not t.get("v131_fabricated_state_claim")]

# Bucket A': action-claim fabrications — Site 1 (no tool fired)
#   final_label=fabricated, tool_calls_fired empty/None, NOT state-claim
bucket_A_prime = [t for t in turns
                  if t.get("final_label") == "fabricated"
                  and not (t.get("tool_calls_fired") or [])
                  and not t.get("v131_fabricated_state_claim")]

# Bucket B: state-claim fabrications — negative control
bucket_B = [t for t in turns if t.get("v131_fabricated_state_claim")]

# Bucket C: clean baseline — uses tools, factually correct wrap-up
bucket_C = [t for t in turns
            if t.get("final_label") == "clean"
            and (t.get("tool_calls_fired") or [])]

print(f"\npool sizes:")
print(f"  A  (action-claim, tool fired, Site 2 — TARGET):   {len(bucket_A)}")
print(f"  A' (action-claim, no tool fired, Site 1 — defer): {len(bucket_A_prime)}")
print(f"  B  (state-claim, negative control):                {len(bucket_B)}")
print(f"  C  (clean baseline, tool fired, should hold):      {len(bucket_C)}")

# Curate: dedupe by (prompt) and keep diverse personas across each bucket.
def diverse_sample(bucket, n):
    by_persona = defaultdict(list)
    for t in bucket:
        by_persona[t.get("persona", "?")].append(t)
    picked = []
    seen_prompts = set()
    personas = list(by_persona.keys())
    random.shuffle(personas)
    # Round-robin across personas; one prompt per persona until quota.
    while len(picked) < n and personas:
        progressed = False
        for p in list(personas):
            pool = by_persona[p]
            random.shuffle(pool)
            chosen = None
            for t in pool:
                prompt = (t.get("prompt") or "").strip()
                if not prompt or prompt in seen_prompts:
                    continue
                chosen = t
                break
            if chosen is None:
                personas.remove(p)
                continue
            picked.append(chosen)
            seen_prompts.add((chosen.get("prompt") or "").strip())
            by_persona[p].remove(chosen)
            progressed = True
            if len(picked) >= n:
                break
        if not progressed:
            break
    return picked

sample_A  = diverse_sample(bucket_A,  12)   # primary target — most weight
sample_Ap = diverse_sample(bucket_A_prime, 6)  # control
sample_B  = diverse_sample(bucket_B,   4)   # negative control
sample_C  = diverse_sample(bucket_C,   6)   # clean baseline

curated = sample_A + sample_Ap + sample_B + sample_C
print(f"\ncurated set: {len(curated)} prompts")
print(f"  A:  {len(sample_A)} (primary target)")
print(f"  A': {len(sample_Ap)} (Site 1 control)")
print(f"  B:  {len(sample_B)} (state-claim control)")
print(f"  C:  {len(sample_C)} (clean baseline)")

# Write the curated set to a JSONL the A/B runner consumes
out = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/eval/phase_4_3_0_ab_prompts.jsonl")
out.parent.mkdir(parents=True, exist_ok=True)
with out.open("w", encoding="utf-8") as f:
    for i, t in enumerate(curated):
        bucket = ("A"  if t in sample_A  else
                  "A'" if t in sample_Ap else
                  "B"  if t in sample_B  else
                  "C"  if t in sample_C  else "?")
        record = {
            "id": f"ab_{i+1:02d}_{bucket}",
            "bucket": bucket,
            "prompt": t.get("prompt"),
            "source_id": t.get("id"),
            "source_persona": t.get("persona"),
            "source_chip": t.get("chip"),
            "source_label": t.get("final_label"),
            "source_wrap_up": (t.get("wrap_up_text") or "")[:200],
            "source_tools_fired": [
                (tc.get("function") or tc.get("name"))
                for tc in (t.get("tool_calls_fired") or [])
                if isinstance(tc, dict)
            ],
        }
        f.write(json.dumps(record, ensure_ascii=False) + "\n")
print(f"\nwrote curated set to {out}")

# Also print a human-readable preview for Scott
print()
print("=" * 80)
print("PREVIEW (for Scott review before running)")
print("=" * 80)
last_bucket = ""
for i, t in enumerate(curated):
    bucket = ("A"  if t in sample_A  else
              "A'" if t in sample_Ap else
              "B"  if t in sample_B  else
              "C"  if t in sample_C  else "?")
    if bucket != last_bucket:
        print(f"\n--- bucket {bucket} ---")
        last_bucket = bucket
    prompt = (t.get("prompt") or "").replace("\n", " ")[:90]
    tools = ",".join((tc.get("function") or tc.get("name")) for tc in (t.get("tool_calls_fired") or []) if isinstance(tc, dict)) or "(none)"
    print(f"  [{i+1:2d}] persona={t.get('persona',''):40s} tools_fired={tools}")
    print(f"       prompt: {prompt!r}")
