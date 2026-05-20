#!/usr/bin/env python3
"""Phase 4.2.1.B: assemble v1.3 training data.

Union of:
  1. v1.2 base (`wireclaw-v2-train.jsonl`)
  2. Clean turns from `corpus-labels/v1.1-overnight-2026-05-18.labeled.jsonl`
     (filter: final_label == "clean")
     - Oversample the `v13_memory_chain_correct` positives by OVERSAMPLE_FACTOR
  3. v1.3 synthetic (output of 4.2.1.A)

Reformats labeled turns into {messages:[system,user,assistant]} schema.
Shuffles deterministically (seed=4213) so training data ordering is
reproducible.

Writes:
  bench/fork/lora/training-data/v1.3-train.jsonl
  bench/fork/lora/training-data/v1.3-train.manifest.md
"""
import argparse
import hashlib
import json
import random
import sys
from collections import Counter
from pathlib import Path

ROOT = Path("/mnt/c/Users/homet/Documents/WireClaw")
SOUL_LOCAL = (ROOT / "bench/fork/lora/training-data/constitution/SOUL-LOCAL.md").read_text(encoding="utf-8")

V2_BASE     = ROOT / "bench/fork/lora/training-data/wireclaw-v2-train.jsonl"
LABELED     = ROOT / "bench/fork/lora/corpus-labels/v1.1-overnight-2026-05-18.labeled.jsonl"
V13_SYNTH   = ROOT / "bench/fork/lora/training-data/v1.3-synthetic.jsonl"
OUT         = ROOT / "bench/fork/lora/training-data/v1.3-train.jsonl"
MANIFEST    = ROOT / "bench/fork/lora/training-data/v1.3-train.manifest.md"
SEED        = 4213
OVERSAMPLE_FACTOR = 3  # memory_chain_correct positives × 3 (directive: "oversample")


def labeled_to_message_record(turn: dict) -> dict | None:
    """Convert one labeled turn to the {messages:[system,user,assistant]} shape.
    Returns None if it lacks a usable assistant body (no wrap_up_text)."""
    user = (turn.get("prompt") or "").strip()
    wrap = (turn.get("wrap_up_text") or "").strip()
    if not user or not wrap:
        return None
    return {
        "messages": [
            {"role": "system",    "content": SOUL_LOCAL},
            {"role": "user",      "content": user},
            {"role": "assistant", "content": wrap},
        ],
        "_source": "labeled-clean",
        "_id": turn.get("id", ""),
        "_persona": turn.get("persona"),
        "_chip": turn.get("chip"),
        "_memory_chain": bool(turn.get("v13_memory_chain_correct")),
    }


def normalize_synth_record(rec: dict) -> dict:
    """v1.3-synthetic records already have the messages schema; just tag source."""
    out = {"messages": rec["messages"]}
    out["_source"] = "v1.3-synthetic"
    out["_id"] = rec.get("id", "")
    out["_category"] = rec.get("category")
    out["_subtype"] = rec.get("subtype")
    out["_principle"] = rec.get("principle_exercised")
    return out


def normalize_v2_record(rec: dict) -> dict:
    out = {"messages": rec["messages"]}
    out["_source"] = "v1.2-base"
    return out


def msg_hash(rec: dict) -> str:
    """Hash of the user+assistant content for dedup across sources."""
    u = next((m["content"] for m in rec["messages"] if m["role"] == "user"), "")
    a = next((m["content"] for m in rec["messages"] if m["role"] == "assistant"), "")
    return hashlib.sha1((u + "\x00" + a).encode("utf-8")).hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--no-shuffle", action="store_true",
                    help="Skip the final shuffle (useful for diff'ing source order).")
    args = ap.parse_args()

    if not V13_SYNTH.exists():
        sys.exit(f"FATAL: synthetic data not found at {V13_SYNTH} -- run 4.2.1.A first.")

    # 1. v1.2 base
    v2 = [normalize_v2_record(json.loads(l))
          for l in V2_BASE.read_text(encoding="utf-8").splitlines() if l.strip()]
    print(f"v1.2 base:      {len(v2)} records")

    # 2. labeled clean
    clean = []
    mem_chain = []
    for l in LABELED.read_text(encoding="utf-8").splitlines():
        if not l.strip():
            continue
        t = json.loads(l)
        if t.get("final_label") != "clean":
            continue
        r = labeled_to_message_record(t)
        if r is None:
            continue
        clean.append(r)
        if r.get("_memory_chain"):
            mem_chain.append(r)
    print(f"clean (labeled): {len(clean)} records ({len(mem_chain)} memory-chain positives)")

    # 3. memory_chain oversample (in addition to their single inclusion above)
    oversampled = []
    for _ in range(OVERSAMPLE_FACTOR - 1):  # already in `clean` once, add (factor-1) more
        for r in mem_chain:
            dup = json.loads(json.dumps(r))  # deep copy
            dup["_oversampled"] = True
            oversampled.append(dup)
    print(f"memory_chain oversample (×{OVERSAMPLE_FACTOR} total): "
          f"+{len(oversampled)} duplicates")

    # 4. v1.3 synthetic
    synth = [normalize_synth_record(json.loads(l))
             for l in V13_SYNTH.read_text(encoding="utf-8").splitlines() if l.strip()]
    print(f"v1.3 synthetic: {len(synth)} records")

    # 5. concat + dedup by (user, assistant) hash. Preserve source priority:
    #    v1.3 synthetic > labeled clean > v1.2 base (synthetic curated for v1.3 specifically).
    all_records = synth + oversampled + clean + v2
    seen = set()
    deduped = []
    dup_count = Counter()
    for r in all_records:
        h = msg_hash(r)
        if h in seen:
            dup_count[r.get("_source", "?")] += 1
            continue
        seen.add(h)
        deduped.append(r)
    print(f"dedup: {len(all_records)} -> {len(deduped)} (duplicates by source: {dict(dup_count)})")

    # 6. shuffle (deterministic) + write
    if not args.no_shuffle:
        rnd = random.Random(SEED)
        rnd.shuffle(deduped)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8") as fh:
        for r in deduped:
            # Strip the _-prefixed metadata before training; keep messages only
            train_rec = {"messages": r["messages"]}
            fh.write(json.dumps(train_rec, ensure_ascii=False) + "\n")
    print(f"wrote {OUT} ({len(deduped)} records)")

    # 7. Manifest
    src_counts = Counter(r["_source"] for r in deduped)
    synth_cat_counts = Counter(r.get("_category") for r in deduped if r["_source"] == "v1.3-synthetic")
    persona_counts = Counter(r.get("_persona") for r in deduped if r["_source"] == "labeled-clean" and r.get("_persona"))
    chip_counts = Counter(r.get("_chip") for r in deduped if r["_source"] == "labeled-clean" and r.get("_chip"))
    oversampled_count = sum(1 for r in deduped if r.get("_oversampled"))

    lines = []
    lines.append("# v1.3 training data manifest\n")
    lines.append(f"**Total records:** {len(deduped)}  ·  **Shuffled seed:** {SEED}  ·  **Output:** `{OUT.relative_to(ROOT)}`\n")
    lines.append("## Source composition\n")
    lines.append("| source | count |")
    lines.append("|---|---:|")
    for s, c in src_counts.most_common():
        lines.append(f"| {s} | {c} |")
    lines.append("")
    lines.append("## v1.3-synthetic per-category breakdown\n")
    lines.append("| category | count |")
    lines.append("|---|---:|")
    for k, v in synth_cat_counts.most_common():
        lines.append(f"| {k} | {v} |")
    lines.append("")
    lines.append("## labeled-clean per-persona / per-chip\n")
    lines.append(f"- per-persona: {dict(persona_counts.most_common())}")
    lines.append(f"- per-chip: {dict(chip_counts.most_common())}")
    lines.append(f"- memory_chain_correct oversamples (extra duplicates): {oversampled_count}")
    lines.append("")
    lines.append("## Filtering policy\n")
    lines.append("- INCLUDED: `final_label == 'clean'` from `v1.1-overnight-2026-05-18.labeled.jsonl`")
    lines.append("- INCLUDED: v1.2 base training set (`wireclaw-v2-train.jsonl`) — preserves prior LoRA's learned behaviors")
    lines.append("- INCLUDED: 180 v1.3-synthetic examples — the targeted constitutional repair (Phase 4.2.1.A)")
    lines.append("- EXCLUDED: fabricated / pseudo-prose / contradictory labeled turns (would need correct-rewrites)")
    lines.append("- EXCLUDED: scrambled `v1.1-overnight-2026-05-18.SCRAMBLED.jsonl` (Phase 4.1.1 quarantine)")
    lines.append("- DEDUP: by sha1(user + '\\x00' + assistant); priority: synthetic > clean > v1.2-base")
    lines.append(f"- OVERSAMPLE: `v13_memory_chain_correct` positives × {OVERSAMPLE_FACTOR} (foundation for fixing LED indirect-reference bug)")
    lines.append("")
    lines.append("## Schema\n")
    lines.append("Each record:")
    lines.append("```json")
    lines.append('{"messages": [')
    lines.append('  {"role": "system",    "content": "<SOUL-LOCAL.md>"},')
    lines.append('  {"role": "user",      "content": "..."},')
    lines.append('  {"role": "assistant", "content": "..."}')
    lines.append("]}")
    lines.append("```")
    MANIFEST.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {MANIFEST}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
