#!/usr/bin/env python3
"""Phase 4.2.1.I.4 quality assessment of the repaired v1.3.1 overnight corpus.

Surfaces: total/dedup per chip, per-persona breakdown per chip, basic
anomaly counters (empty wrap-ups, error-replies, boot-banner echoes,
identity-drift hints), 5 random sample turns per chip.
"""
import json, random, re
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path("/mnt/c/Users/homet/Documents/WireClaw")
CORPUS_DIR = ROOT / "bench" / "fork" / "lora" / "corpus"
ALL = CORPUS_DIR / "v1.3.1-overnight-2026-05-20.jsonl"

random.seed(42)

# Cheap anomaly heuristics — Haiku will give the real labels later.
BOOT_BANNER_RE = re.compile(r"\bWireClaw\b.*\bv0\.\d", re.I)
HIST_CLEARED_RE = re.compile(r"history.cleared", re.I)
PSEUDO_PROSE_RE = re.compile(r"^the tool (call )?(was|has been) (executed|successful|completed)", re.I)
IDENTITY_DRIFT_RE = re.compile(r"\b(I am|as an? AI|I'm an? AI|Meta|Llama)\b", re.I)
JSON_LEAK_RE = re.compile(r'\b(tool_calls?|arguments|function|"role":|"content":)\b')
EMPTY_REPLY = re.compile(r"^\s*$")
ERROR_REPLY_RE = re.compile(r"\b(error|failed|invalid|reserved)\b", re.I)


def load_turns():
    turns = []
    with ALL.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                turns.append(json.loads(line))
            except Exception:
                pass
    return turns


def main():
    turns = load_turns()
    print(f"loaded {len(turns)} turns from {ALL.name}")

    by_chip = defaultdict(list)
    for t in turns:
        by_chip[t.get("_chip")].append(t)

    print("\n=== per-chip totals ===")
    for chip in sorted(by_chip):
        ts = by_chip[chip]
        # Dedup by (prompt, wrap_up_text) tuple
        seen = set()
        dedup = 0
        for t in ts:
            key = (t.get("prompt", ""), t.get("wrap_up_text") or "")
            if key in seen:
                continue
            seen.add(key)
            dedup += 1
        print(f"  {chip}: raw={len(ts):5d}  unique_(prompt,reply)={dedup:5d}  dup_rate={1-dedup/len(ts):.1%}")

    print("\n=== per-persona × chip session counts ===")
    persona_chip = defaultdict(lambda: defaultdict(int))
    for t in turns:
        persona_chip[t.get("_persona_name", "?")][t.get("_chip", "?")] += 1
    print(f"  {'persona':40s} " + "  ".join(f"{c:>6s}" for c in sorted(by_chip)) + "    total")
    for p in sorted(persona_chip):
        row = persona_chip[p]
        total = sum(row.values())
        print(f"  {p:40s} " + "  ".join(f"{row[c]:6d}" for c in sorted(by_chip)) + f"  {total:7d}")

    print("\n=== anomaly heuristics per chip (cheap regex; Haiku labels are authoritative) ===")
    hdr = f"  {'chip':6s}  {'empty':>6s}  {'boot':>6s}  {'hist_cl':>7s}  {'pseudo':>6s}  {'id_drift':>8s}  {'json_lk':>7s}  {'err_rep':>7s}"
    print(hdr)
    for chip in sorted(by_chip):
        ts = by_chip[chip]
        empty = sum(1 for t in ts if EMPTY_REPLY.match(t.get("wrap_up_text") or ""))
        boot  = sum(1 for t in ts if BOOT_BANNER_RE.search(t.get("wrap_up_text") or ""))
        hist  = sum(1 for t in ts if HIST_CLEARED_RE.search(t.get("wrap_up_text") or ""))
        pseu  = sum(1 for t in ts if PSEUDO_PROSE_RE.search(t.get("wrap_up_text") or ""))
        idd   = sum(1 for t in ts if IDENTITY_DRIFT_RE.search(t.get("wrap_up_text") or ""))
        jsl   = sum(1 for t in ts if JSON_LEAK_RE.search(t.get("wrap_up_text") or ""))
        err   = sum(1 for t in ts if ERROR_REPLY_RE.search(t.get("wrap_up_text") or ""))
        print(f"  {chip:6s}  {empty:6d}  {boot:6d}  {hist:7d}  {pseu:6d}  {idd:8d}  {jsl:7d}  {err:7d}")

    print("\n=== tool-call statistics per chip ===")
    for chip in sorted(by_chip):
        ts = by_chip[chip]
        n_tool = sum(1 for t in ts if t.get("tool_calls_fired"))
        n_no_wrap = sum(1 for t in ts if not (t.get("wrap_up_text") or "").strip())
        avg_calls = sum(len(t.get("tool_calls_fired") or []) for t in ts) / max(len(ts), 1)
        print(f"  {chip}: tool_called={n_tool}/{len(ts)} ({n_tool/len(ts):.1%})  avg_calls_per_turn={avg_calls:.2f}  no_wrap_up={n_no_wrap}")

    print("\n=== 5 random sample turns per chip ===")
    for chip in sorted(by_chip):
        ts = by_chip[chip]
        sample = random.sample(ts, min(5, len(ts)))
        print(f"\n--- {chip} ---")
        for i, t in enumerate(sample, 1):
            p = (t.get("prompt") or "").replace("\n", " ")[:80]
            r = (t.get("wrap_up_text") or "").replace("\n", " ")[:160]
            tools = [tc.get("name") for tc in (t.get("tool_calls_fired") or [])]
            print(f"  [{i}] persona={t.get('_persona_name')} session={t.get('_session_seq')}")
            print(f"      prompt: {p!r}")
            print(f"      tools : {tools}")
            print(f"      reply : {r!r}")


if __name__ == "__main__":
    main()
