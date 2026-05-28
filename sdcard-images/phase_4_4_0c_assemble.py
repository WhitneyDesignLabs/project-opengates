#!/usr/bin/env python3
"""Phase 4.4.0.C — assemble v1.3.2 training data.

Composition (per directive + Q1 oversample decision + §5 dedup refinement):
  - v1.3.1-train.jsonl baseline (1,919 records, already deduped)
  - v1.3.2 corrective (78 records, within-corrective deduped in B)
  - Bucket 2 oversample ×2: each of the 18 memory_chain_completion records
    duplicated once (effective ~54 memory-chain training records when combined
    with v1.3.1's existing memory_chain oversamples)

NO cross-set dedup between baseline and corrective. Per design-doc §5
refinement: corrective and baseline shapes are intentionally allowed to
overlap on (user, final_content) — same prompt under both shapes is the
training signal we want.

Shuffle seed = 4213 (matches v1.3.1 for reproducibility).
"""
from __future__ import annotations
import json
import random
from collections import Counter
from pathlib import Path

ROOT = Path("/mnt/c/Users/homet/Documents/WireClaw")
V131_TRAIN   = ROOT / "bench/fork/lora/training-data/v1.3.1-train.jsonl"
V132_SYNTH   = ROOT / "bench/fork/lora/training-data/wireclaw-v1.3.2-corrective.jsonl"
OUT          = ROOT / "bench/fork/lora/training-data/v1.3.2-train.jsonl"
MANIFEST     = ROOT / "bench/fork/lora/training-data/v1.3.2-train.manifest.md"
SEED         = 4213
BUCKET2_OVERSAMPLE = 2  # ×2 per Cowork Q1 decision


def main() -> None:
    # 1. Baseline (v1.3.1, opaque blob — composition documented in v1.3.1-train.manifest.md)
    baseline = []
    with V131_TRAIN.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                r = json.loads(line)
                r["_source"] = "v1.3.1-baseline"
                baseline.append(r)
    print(f"v1.3.1 baseline:        {len(baseline)} records")

    # 2. v1.3.2 corrective synth
    corrective = []
    bucket2 = []
    by_category = Counter()
    by_subtype = Counter()
    led_colors = Counter()
    for line in V132_SYNTH.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        r = json.loads(line)
        cat = r.get("category", "")
        sub = r.get("subtype", "")
        color = r.get("color")
        by_category[cat] += 1
        by_subtype[sub] += 1
        if color:
            led_colors[color.lower()] += 1
        out = {
            "messages": r["messages"],
            "_source": "v1.3.2-corrective",
            "_id": r.get("id"),
            "_category": cat,
            "_subtype": sub,
        }
        if color:
            out["_color"] = color
        corrective.append(out)
        if cat == "memory_chain_completion":
            bucket2.append(out)
    print(f"v1.3.2 corrective:      {len(corrective)} records")
    print(f"  by category: {dict(by_category)}")
    print(f"  LED colors:  {dict(led_colors)}")
    print(f"  bucket 2 (memory_chain) records eligible for oversample: {len(bucket2)}")

    # 3. Bucket 2 oversample (×2 means one extra copy per record)
    oversampled = []
    for _ in range(BUCKET2_OVERSAMPLE - 1):
        for r in bucket2:
            dup = json.loads(json.dumps(r))
            dup["_oversampled"] = True
            dup["_source"] = "v1.3.2-corrective-oversample"  # distinguish in manifest
            oversampled.append(dup)
    print(f"bucket 2 oversample (×{BUCKET2_OVERSAMPLE}): +{len(oversampled)} duplicates")

    # 4. Merge (NO cross-set dedup per §5 refinement)
    all_records = baseline + corrective + oversampled
    print(f"\nmerged total (no cross-set dedup): {len(all_records)} records")
    print(f"  composition:")
    src_counts = Counter(r["_source"] for r in all_records)
    for s, c in src_counts.most_common():
        print(f"    {s}: {c}")

    # 5. Shuffle (same seed as v1.3.1)
    rnd = random.Random(SEED)
    rnd.shuffle(all_records)

    # 6. Write train file (only messages survive into the trainer-consumed JSONL)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8") as fh:
        for r in all_records:
            fh.write(json.dumps({"messages": r["messages"]}, ensure_ascii=False) + "\n")
    print(f"\nwrote {OUT} ({len(all_records)} records, shuffle seed {SEED})")

    # 7. Manifest
    m = []
    m.append("# v1.3.2 training data manifest\n")
    m.append(
        f"**Total records:** {len(all_records)}  ·  "
        f"**Shuffle seed:** {SEED}  ·  "
        f"**Output:** `{OUT.relative_to(ROOT)}`\n"
    )
    m.append("## Source composition\n")
    m.append("| source | count |")
    m.append("|---|---:|")
    for s, c in src_counts.most_common():
        m.append(f"| {s} | {c} |")
    m.append("")
    m.append("## v1.3.2-corrective per-category breakdown\n")
    m.append("| category | count |")
    m.append("|---|---:|")
    for k, v in by_category.most_common():
        m.append(f"| {k} | {v} |")
    m.append("")
    m.append("## v1.3.2-corrective per-sub-bucket breakdown\n")
    m.append("| sub-bucket | count |")
    m.append("|---|---:|")
    for k, v in sorted(by_subtype.items()):
        m.append(f"| {k} | {v} |")
    m.append("")
    m.append("## v1.3.2-corrective LED color distribution\n")
    target = {"red": 2, "blue": 2, "green": 2, "yellow": 1, "orange": 1,
              "white": 1, "pink": 1, "cyan": 1, "purple": 1, "magenta": 1,
              "off": 1, "compound": 1}
    m.append("| color | target | actual | Δ |")
    m.append("|---|---:|---:|---:|")
    for color in target:
        actual = led_colors.get(color, 0)
        delta = actual - target[color]
        m.append(f"| {color} | {target[color]} | {actual} | {delta:+d} |")
    m.append(f"| **total LED records** | **{sum(target.values())}** | **{sum(led_colors.values())}** | **{sum(led_colors.values()) - sum(target.values()):+d}** |")
    m.append("")
    m.append("Note: color distribution skewed (orange ×4, cyan ×3, purple ×3 vs target ×1 each); Sonnet attached `color` metadata to LED-flavored records beyond the explicitly-targeted 22. Purple at 3 partially re-introduces the tool-description bias the color-variation table was designed to neutralize (3/25 = 12% vs tool description's 100%). Acceptable for v1.3.2; revisit in v1.3.3 if residual color-fabrication remains a measurable axis.")
    m.append("")
    m.append("## Delta from v1.3.1-train\n")
    m.append(f"- **Baseline preserved:** all 1,919 v1.3.1 records ship in v1.3.2-train (no removals; per §6 design — baseline anchors prior single-message shape).")
    m.append(f"- **Added v1.3.2-corrective:** 78 examples across 5 buckets / 26 sub-buckets — multi-message tool-chain shape for buckets 1/2/C, single-message refusal for buckets 3/4.")
    m.append(f"- **Bucket 2 oversample ×{BUCKET2_OVERSAMPLE}:** {len(oversampled)} extra duplicates of memory_chain_completion records (effective ~{len(bucket2)*BUCKET2_OVERSAMPLE} memory-chain records when combined with v1.3.1's existing memory_chain oversamples).")
    m.append("")
    m.append("## v1.3.1 → v1.3.2 dedup\n")
    m.append(f"- input: {len(all_records)} records (baseline + corrective + oversample)")
    m.append(f"- output after dedup: {len(all_records)} records — **no cross-set dedup applied per §5 refinement** (corrective and baseline shapes intentionally overlap on (user, final_content); within-corrective dedup happened at 4.4.0.B; within-baseline dedup happened at v1.3.1 assembly).")
    m.append(f"- Net Δ from v1.3.1-train: +{len(all_records) - len(baseline)} records")
    m.append("")
    m.append("## Shape mix")
    multi_msg_count = sum(1 for r in all_records if len(r["messages"]) > 3)
    single_msg_count = sum(1 for r in all_records if len(r["messages"]) == 3)
    other_count = sum(1 for r in all_records if len(r["messages"]) < 3)
    m.append(f"- Single-message shape (3 messages: system+user+assistant): {single_msg_count} records ({single_msg_count/len(all_records)*100:.1f}%)")
    m.append(f"- Multi-message shape (>3 messages: tool chain): {multi_msg_count} records ({multi_msg_count/len(all_records)*100:.1f}%)")
    m.append(f"- Other (<3 messages): {other_count} records ({other_count/len(all_records)*100:.1f}%)")
    m.append("")
    m.append("The multi-message training shape is intentionally a small fraction (~5% of total) — the new shape ADDS, the old single-message shape ANCHORS. v1.3.2's LoRA learns BOTH shapes; at inference time the chip's multi-iteration agent loop should converge on the multi-message discipline for tool-using turns.")

    MANIFEST.write_text("\n".join(m), encoding="utf-8")
    print(f"wrote {MANIFEST}")


if __name__ == "__main__":
    main()
