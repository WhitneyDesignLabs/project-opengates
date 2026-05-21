#!/usr/bin/env python3
"""Phase 4.2.1.G.C: assemble v1.3.1 training data.

Start from the same source mix as v1.3:
  - v1.2 base (wireclaw-v2-train.jsonl)
  - clean labeled turns from corpus-labels/v1.1-overnight-2026-05-18.labeled.jsonl
  - memory-chain oversample x3
  - v1.3 synthetic — MINUS 5 bad examples diagnosed in G.A
  - PLUS v1.3.1 corrective synthetic (30 examples)

Same dedup policy + same shuffle seed as v1.3.
"""
import json, hashlib, random, re
from collections import Counter
from pathlib import Path

ROOT = Path("/mnt/c/Users/homet/Documents/WireClaw")
SOUL_LOCAL = (ROOT / "bench/fork/lora/training-data/constitution/SOUL-LOCAL.md").read_text(encoding="utf-8")

V2_BASE      = ROOT / "bench/fork/lora/training-data/wireclaw-v2-train.jsonl"
LABELED      = ROOT / "bench/fork/lora/corpus-labels/v1.1-overnight-2026-05-18.labeled.jsonl"
V13_SYNTH    = ROOT / "bench/fork/lora/training-data/v1.3-synthetic.jsonl"
V131_SYNTH   = ROOT / "bench/fork/lora/training-data/v1.3.1-synthetic.jsonl"
BAD_IDS_FP   = ROOT / "bench/fork/lora/training-data/v1.3.1-diagnose-bad-ids.json"
OUT          = ROOT / "bench/fork/lora/training-data/v1.3.1-train.jsonl"
MANIFEST     = ROOT / "bench/fork/lora/training-data/v1.3.1-train.manifest.md"
SEED         = 4213
OVERSAMPLE   = 3

bad_ids = set(json.loads(BAD_IDS_FP.read_text())["bad_ids"])
print(f"v1.3 bad ids to drop: {sorted(bad_ids)}")

# 1. v1.2 base
v2 = []
for l in V2_BASE.read_text(encoding="utf-8").splitlines():
    if l.strip():
        r = json.loads(l)
        r["_source"] = "v1.2-base"
        v2.append(r)
print(f"v1.2 base:            {len(v2)} records")

# 2. labeled clean
clean = []
mem_chain = []
for l in LABELED.read_text(encoding="utf-8").splitlines():
    if not l.strip(): continue
    t = json.loads(l)
    if t.get("final_label") != "clean": continue
    user = (t.get("prompt") or "").strip()
    wrap = (t.get("wrap_up_text") or "").strip()
    if not user or not wrap: continue
    rec = {
        "messages": [
            {"role": "system",    "content": SOUL_LOCAL},
            {"role": "user",      "content": user},
            {"role": "assistant", "content": wrap},
        ],
        "_source": "labeled-clean",
        "_id": t.get("id", ""),
        "_memory_chain": bool(t.get("v13_memory_chain_correct")),
    }
    clean.append(rec)
    if rec["_memory_chain"]:
        mem_chain.append(rec)
print(f"labeled clean:        {len(clean)} ({len(mem_chain)} memory-chain positives)")

# 3. memory_chain oversample
oversampled = []
for _ in range(OVERSAMPLE - 1):
    for r in mem_chain:
        dup = json.loads(json.dumps(r))
        dup["_oversampled"] = True
        oversampled.append(dup)
print(f"memory_chain oversample (×{OVERSAMPLE}): +{len(oversampled)} duplicates")

# 4a. v1.3 synthetic MINUS bad ids
v13 = []
v13_removed = []
for l in V13_SYNTH.read_text(encoding="utf-8").splitlines():
    if not l.strip(): continue
    r = json.loads(l)
    if r["id"] in bad_ids:
        v13_removed.append(r["id"])
        continue
    out = {"messages": r["messages"], "_source": "v1.3-synthetic",
           "_id": r["id"], "_category": r.get("category")}
    v13.append(out)
print(f"v1.3 synthetic (after removing {len(v13_removed)} bad): {len(v13)}")

# 4b. v1.3.1 corrective synthetic
v131 = []
for l in V131_SYNTH.read_text(encoding="utf-8").splitlines():
    if not l.strip(): continue
    r = json.loads(l)
    out = {"messages": r["messages"], "_source": "v1.3.1-synthetic",
           "_id": r["id"], "_category": r.get("category"),
           "_subtype": r.get("subtype")}
    v131.append(out)
print(f"v1.3.1 corrective synthetic: {len(v131)}")

# 5. concat + dedup with priority order
def msg_hash(rec):
    u = next((m["content"] for m in rec["messages"] if m["role"] == "user"), "")
    a = next((m["content"] for m in rec["messages"] if m["role"] == "assistant"), "")
    return hashlib.sha1((u + "\x00" + a).encode("utf-8")).hexdigest()

# Priority: v1.3.1 corrective > v1.3 synthetic (minus bad) > clean labeled > v1.2 base
all_records = v131 + v13 + oversampled + clean + v2
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
print(f"\ndedup: {len(all_records)} -> {len(deduped)} (duplicates by source: {dict(dup_count)})")

# 6. shuffle + write
rnd = random.Random(SEED)
rnd.shuffle(deduped)

OUT.parent.mkdir(parents=True, exist_ok=True)
with OUT.open("w", encoding="utf-8") as fh:
    for r in deduped:
        train_rec = {"messages": r["messages"]}
        fh.write(json.dumps(train_rec, ensure_ascii=False) + "\n")
print(f"wrote {OUT} ({len(deduped)} records)")

# 7. manifest
src_counts = Counter(r["_source"] for r in deduped)
cat_v131 = Counter(r.get("_category") for r in deduped if r["_source"] == "v1.3.1-synthetic")
oversampled_n = sum(1 for r in deduped if r.get("_oversampled"))

m = []
m.append("# v1.3.1 training data manifest\n")
m.append(f"**Total records:** {len(deduped)}  ·  **Shuffle seed:** {SEED}  ·  **Output:** `{OUT.relative_to(ROOT)}`\n")
m.append(f"## Source composition\n\n| source | count |\n|---|---:|")
for s, c in src_counts.most_common():
    m.append(f"| {s} | {c} |")
m.append("")
m.append(f"## v1.3.1-synthetic per-category breakdown\n\n| category | count |\n|---|---:|")
for k, v in cat_v131.most_common():
    m.append(f"| {k} | {v} |")
m.append("")
m.append("## Delta from v1.3-train\n")
m.append(f"- **Removed from v1.3-synthetic** (diagnosed in G.A): {len(v13_removed)} examples")
m.append("  - " + ", ".join(sorted(v13_removed)))
m.append(f"- **Added v1.3.1-synthetic** (G.B corrective): {len(v131)} examples")
m.append("  - 8 harm Art-3-lead (corrective_art3): direct-violence/weaponization prompts, response leads with 'Per Article 3 (Non-Weaponization)…'")
m.append("  - 7 harm Art-12-lead (corrective_art12): living-being-harm prompts, response leads with 'Per Article 12 (Safety Hierarchy)…'")
m.append("  - 15 truth_uncertainty calibrated-engage (corrective_engage): response leads with the answer + uncertainty markers ('Approximately X, ±Y…'), never with 'I cannot'")
m.append("")
m.append("## v1.3 → v1.3.1 dedup\n")
m.append(f"- input: {len(all_records)} records (priority order: v1.3.1-synthetic > v1.3-synthetic > clean labeled > v1.2-base)")
m.append(f"- output after sha1(user||assistant) dedup: {len(deduped)} (Δ from v1.3-train: ~{len(deduped) - 1894:+d})")
m.append(f"- duplicates dropped by source: {dict(dup_count)}")
m.append(f"- memory_chain oversample extras kept: {oversampled_n}")

MANIFEST.write_text("\n".join(m), encoding="utf-8")
print(f"wrote {MANIFEST}")
