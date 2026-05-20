#!/usr/bin/env python3
"""Phase 4.1.4a Step 4: generate v1.1 vs 3.1.3 comparison markdown
report. Reads the merged labeled JSONL (post-v1.3-flag-enrichment) and
the 3.1.3 haiku.json files; emits a structured Markdown report Scott
will read on phone / workstation before the big-picture review.
"""
import json
import random
import re
from collections import Counter, defaultdict
from pathlib import Path

random.seed(7)

LABELS_DIR = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus-labels")
V11        = LABELS_DIR / "v1.1-overnight-2026-05-18.labeled.jsonl"
B313_C02   = LABELS_DIR / "3.1.3-2026-05-16-c6-02.haiku.json"
B313_C03   = LABELS_DIR / "3.1.3-2026-05-16-c6-03.haiku.json"
OUT        = LABELS_DIR / "v1.1-vs-3.1.3-comparison.md"


def load_v11():
    return [json.loads(l) for l in V11.read_text(encoding="utf-8").splitlines() if l.strip()]


def load_v11_input():
    """We also need original prompts/wrap-ups for examples — the merged
    JSONL includes them, so this is satisfied by load_v11()."""
    return load_v11()


def load_313():
    """3.1.3 c6-02 + c6-03 haiku-labeled records, joined to the raw
    corpus turns for prompt/wrap-up access in example sampling.
    Also runs the same v1.3 deterministic flags so we can compare
    failure-mode rates side-by-side with v1.1."""
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "v13_flags",
        "/mnt/c/Users/homet/Documents/WireClaw/sdcard-images/phase_4_1_4a_v13_flags.py",
    )
    v13 = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(v13)

    out = []
    for chip, fp in (("c6-02", B313_C02), ("c6-03", B313_C03)):
        d = json.loads(fp.read_text(encoding="utf-8"))
        raw_path = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus-raw") / f"3.1.3-2026-05-16-{chip}.json"
        raw = json.loads(raw_path.read_text(encoding="utf-8"))
        by_id = {c["id"]: c for c in raw.get("conversations", [])}
        for r in d.get("records", []):
            c = by_id.get(r["id"], {})
            led_bug, led_why = v13.is_led_indirect_reference_bug(c)
            leak, leak_why = v13.is_reasoning_trace_leak(c)
            mem_ok, mem_why = v13.is_memory_chain_correct(c)
            out.append({
                "id": r["id"],
                "chip": chip,
                "persona": _persona_from_id(r["id"]),
                "prompt": c.get("prompt"),
                "wrap_up_text": c.get("wrap_up_text"),
                "final_label": r.get("final_label"),
                "v13_led_indirect_reference_bug": led_bug,
                "v13_reasoning_trace_leak": leak,
                "v13_memory_chain_correct": mem_ok,
            })
    return out


def _persona_from_id(rec_id: str) -> str:
    # ids are like "<persona_id>-<prompt_id>-<ts>"
    return (rec_id.split("-")[0] if rec_id else "?") or "?"


def label_dist(rows, key="final_label"):
    c = Counter(r.get(key) for r in rows)
    total = sum(c.values()) or 1
    return c, {k: 100 * v / total for k, v in c.items()}


def table(rows_pct):
    return "\n".join(f"| {k} | {v:.1f}% |" for k, v in sorted(rows_pct.items(), key=lambda kv: -kv[1]))


def md_section(title, body):
    return f"## {title}\n\n{body}\n"


def fmt_examples(turns, n=3, label="final_label"):
    if not turns:
        return "_(no examples)_"
    sample = random.sample(turns, min(n, len(turns)))
    parts = []
    for t in sample:
        p = (t.get("prompt") or "").replace("\n", " ")[:160]
        w = (t.get("wrap_up_text") or "").replace("\n", " ")[:240]
        parts.append(f"- **{t.get(label)}** · `{t.get('persona', '?')}` · _id_ `{t.get('id', '')[:60]}`\n"
                     f"    - prompt: _{p!r}_\n"
                     f"    - wrap-up: _{w!r}_")
    return "\n".join(parts)


def main():
    v11 = load_v11()
    b313 = load_313()

    # === overall counts ===
    v11_c, v11_pct = label_dist(v11)
    b313_c, b313_pct = label_dist(b313)

    # === per-chip ===
    by_chip_v11 = defaultdict(list)
    for t in v11:
        by_chip_v11[t.get("chip") or "?"].append(t)
    by_chip_b313 = defaultdict(list)
    for t in b313:
        by_chip_b313[t.get("chip") or "?"].append(t)

    # === per-persona (v1.1) ===
    by_persona_v11 = defaultdict(list)
    for t in v11:
        by_persona_v11[t.get("persona") or "?"].append(t)

    # === v1.3 failure-mode rates ===
    n = len(v11)
    led_bug = sum(1 for t in v11 if t.get("v13_led_indirect_reference_bug"))
    leak    = sum(1 for t in v11 if t.get("v13_reasoning_trace_leak"))
    memok   = sum(1 for t in v11 if t.get("v13_memory_chain_correct"))

    led_examples  = [t for t in v11 if t.get("v13_led_indirect_reference_bug")]
    leak_examples = [t for t in v11 if t.get("v13_reasoning_trace_leak")]
    mem_examples  = [t for t in v11 if t.get("v13_memory_chain_correct")]

    # === top-10 failure modes (by deterministic_evidence + haiku_rationale grouping) ===
    failure_modes = Counter()
    failure_examples = defaultdict(list)
    for t in v11:
        if t.get("final_label") in ("clean", "null"):
            continue
        # Bucket by deterministic evidence (high-signal) or haiku rationale (free-text shortened).
        ev = (t.get("deterministic_evidence") or "")[:120]
        if not ev or "deterministic layer has no opinion" in ev.lower():
            ev = (t.get("haiku_rationale") or "")[:120]
        # Normalise by collapsing IDs / numbers
        ev_norm = re.sub(r"['\"][^'\"]+['\"]", "X", ev)
        ev_norm = re.sub(r"\b\d+\b", "N", ev_norm).strip()
        if not ev_norm:
            continue
        failure_modes[ev_norm] += 1
        if len(failure_examples[ev_norm]) < 2:
            failure_examples[ev_norm].append(t)
    top_modes = failure_modes.most_common(10)

    # === 20-turn stratified sample ===
    by_label_v11 = defaultdict(list)
    for t in v11:
        by_label_v11[t.get("final_label")].append(t)
    sample = []
    for lab, lst in by_label_v11.items():
        sample += random.sample(lst, min(3, len(lst)))
        if len(sample) >= 20:
            break
    sample = sample[:20]

    # ===== build report =====
    md = []
    md.append("# v1.1 vs 3.1.3 Haiku-label comparison\n")
    md.append("**Phase 4.1.4a · 2026-05-19 · ANALYSIS INPUT FOR BIG-PICTURE REVIEW**\n")
    md.append(f"- v1.1 corpus: `{V11.name}` — {n} turns, labeled with Haiku-4.5 via two-layer classifier.")
    md.append(f"- 3.1.3 baseline: c6-02 + c6-03 combined ({len(b313)} turns), same classifier, same taxonomy.\n")

    # --- overall ---
    md.append("## A. Overall label distribution\n")
    md.append("| label | v1.1 % | 3.1.3 % | Δ (v1.1 − 3.1.3) |\n|---|---:|---:|---:|")
    all_labels = sorted(set(list(v11_pct) + list(b313_pct)),
                       key=lambda x: -(v11_pct.get(x, 0) + b313_pct.get(x, 0)))
    for lab in all_labels:
        v = v11_pct.get(lab, 0.0)
        b = b313_pct.get(lab, 0.0)
        md.append(f"| {lab} | {v:.1f}% | {b:.1f}% | {v-b:+.1f}% |")
    md.append(f"\n_(counts: v1.1={dict(v11_c)} · 3.1.3={dict(b313_c)})_\n")

    # --- per-chip ---
    md.append("## B. Per-chip breakdown\n")
    md.append("### v1.1 — by chip\n")
    md.append("| chip | n | clean % | fabricated % | pseudo-prose % |\n|---|---:|---:|---:|---:|")
    for chip in sorted(by_chip_v11):
        rows = by_chip_v11[chip]
        cnt, pct = label_dist(rows)
        md.append(f"| {chip} | {len(rows)} | "
                  f"{pct.get('clean', 0):.1f}% | "
                  f"{pct.get('fabricated', 0):.1f}% | "
                  f"{pct.get('pseudo-prose', 0):.1f}% |")
    md.append("\n### 3.1.3 — by chip\n")
    md.append("| chip | n | clean % | fabricated % | pseudo-prose % |\n|---|---:|---:|---:|---:|")
    for chip in sorted(by_chip_b313):
        rows = by_chip_b313[chip]
        cnt, pct = label_dist(rows)
        md.append(f"| {chip} | {len(rows)} | "
                  f"{pct.get('clean', 0):.1f}% | "
                  f"{pct.get('fabricated', 0):.1f}% | "
                  f"{pct.get('pseudo-prose', 0):.1f}% |")

    # --- per-persona ---
    md.append("\n## C. v1.1 per-persona breakdown\n")
    md.append("| persona | n | clean % | fabricated % | pseudo-prose % |\n|---|---:|---:|---:|---:|")
    for persona in sorted(by_persona_v11):
        rows = by_persona_v11[persona]
        cnt, pct = label_dist(rows)
        md.append(f"| {persona} | {len(rows)} | "
                  f"{pct.get('clean', 0):.1f}% | "
                  f"{pct.get('fabricated', 0):.1f}% | "
                  f"{pct.get('pseudo-prose', 0):.1f}% |")

    # --- v1.3 failure modes (v1.1 vs 3.1.3, same deterministic detector) ---
    b313_n = len(b313)
    b_led_bug = sum(1 for t in b313 if t.get("v13_led_indirect_reference_bug"))
    b_leak    = sum(1 for t in b313 if t.get("v13_reasoning_trace_leak"))
    b_memok   = sum(1 for t in b313 if t.get("v13_memory_chain_correct"))
    md.append("\n## D. v1.3-target failure modes — v1.1 vs 3.1.3\n")
    md.append("Same deterministic detection on both corpora. Negative flags = failure modes the v1.3 training should reduce; positive flag = behavior to reinforce.\n")
    md.append("| flag | v1.1 hits | v1.1 rate | 3.1.3 hits | 3.1.3 rate | Δ (v1.1 − 3.1.3) |\n|---|---:|---:|---:|---:|---:|")
    md.append(f"| **led_indirect_reference_bug** (negative) | {led_bug} | {100*led_bug/n:.1f}% | {b_led_bug} | {100*b_led_bug/b313_n:.1f}% | {100*led_bug/n - 100*b_led_bug/b313_n:+.1f}% |")
    md.append(f"| **reasoning_trace_leak** (negative) | {leak} | {100*leak/n:.1f}% | {b_leak} | {100*b_leak/b313_n:.1f}% | {100*leak/n - 100*b_leak/b313_n:+.1f}% |")
    md.append(f"| **memory_chain_correct** (positive) | {memok} | {100*memok/n:.1f}% | {b_memok} | {100*b_memok/b313_n:.1f}% | {100*memok/n - 100*b_memok/b313_n:+.1f}% |")

    md.append("\n### D.1 led_indirect_reference_bug — examples")
    md.append(fmt_examples(led_examples, n=3))
    md.append("\n### D.2 reasoning_trace_leak — examples")
    md.append(fmt_examples(leak_examples, n=3))
    md.append("\n### D.3 memory_chain_correct — examples (positive signal)")
    md.append(fmt_examples(mem_examples, n=3))

    # --- top-10 failure modes ---
    md.append("\n## E. Top failure-mode descriptions (v1.1)\n")
    md.append("Grouped by deterministic-evidence string (with IDs/numerics normalised). Counts include both deterministic and Haiku-labeled non-clean.\n")
    md.append("| rank | n | bucket | example id |\n|---:|---:|---|---|")
    for i, (bucket, c) in enumerate(top_modes, 1):
        ex = failure_examples[bucket][0]
        md.append(f"| {i} | {c} | _{bucket[:120]}_ | `{ex.get('id','')[:50]}` |")

    md.append("\n### E.1 top-bucket example wrap-ups (first 5 buckets)\n")
    for bucket, c in top_modes[:5]:
        md.append(f"\n**bucket ({c} hits):** _{bucket[:140]}_")
        for ex in failure_examples[bucket][:1]:
            p = (ex.get("prompt") or "").replace("\n", " ")[:160]
            w = (ex.get("wrap_up_text") or "").replace("\n", " ")[:240]
            md.append(f"  - prompt: _{p!r}_")
            md.append(f"  - wrap-up: _{w!r}_")

    # --- 20-turn stratified sample ---
    md.append("\n## F. 20-turn stratified sample (Scott spot-check)\n")
    for s in sample:
        p = (s.get("prompt") or "").replace("\n", " ")[:160]
        w = (s.get("wrap_up_text") or "").replace("\n", " ")[:240]
        md.append(f"- **{s.get('final_label','?')}** · `{s.get('persona','?')}` · _id_ `{s.get('id','')[:60]}`")
        md.append(f"    - prompt: _{p!r}_")
        md.append(f"    - wrap-up: _{w!r}_")
        if s.get("v13_led_indirect_reference_bug"):
            md.append(f"    - 🔴 v1.3 led_indirect_reference_bug: {s.get('v13_led_evidence')}")
        if s.get("v13_reasoning_trace_leak"):
            md.append(f"    - 🔴 v1.3 reasoning_trace_leak: {s.get('v13_leak_evidence')}")
        if s.get("v13_memory_chain_correct"):
            md.append(f"    - ✅ v1.3 memory_chain_correct: {s.get('v13_memory_evidence')}")

    # --- topline ---
    delta_clean = v11_pct.get("clean", 0) - b313_pct.get("clean", 0)
    delta_fab = v11_pct.get("fabricated", 0) - b313_pct.get("fabricated", 0)
    delta_pp = v11_pct.get("pseudo-prose", 0) - b313_pct.get("pseudo-prose", 0)
    topline = (
        f"v1.1 clean rate {v11_pct.get('clean', 0):.1f}% "
        f"vs 3.1.3 {b313_pct.get('clean', 0):.1f}% "
        f"(Δ {delta_clean:+.1f}%); fabricated {v11_pct.get('fabricated', 0):.1f}% "
        f"vs {b313_pct.get('fabricated', 0):.1f}% (Δ {delta_fab:+.1f}%); "
        f"pseudo-prose {v11_pct.get('pseudo-prose', 0):.1f}% "
        f"vs {b313_pct.get('pseudo-prose', 0):.1f}% (Δ {delta_pp:+.1f}%)."
    )
    md.insert(2, f"\n**Topline:** {topline}\n")

    OUT.write_text("\n".join(md), encoding="utf-8")
    print(f"wrote {OUT}")
    print("topline:", topline)
    print(f"v1.3 flag rates: led_bug={led_bug}/{n}={100*led_bug/n:.1f}%, "
          f"leak={leak}/{n}={100*leak/n:.1f}%, mem_ok={memok}/{n}={100*memok/n:.1f}%")


if __name__ == "__main__":
    main()
