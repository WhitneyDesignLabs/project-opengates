#!/usr/bin/env python3
"""Phase 4.2.0b Step 3: variance analysis — diff default-temp baseline vs
temperature=0 re-run; classify each prompt as variance / capability /
flipped / both-pass."""
import json
from collections import defaultdict
from pathlib import Path

LABELS_DIR = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/eval/constitutional_eval/results")
BASELINE = LABELS_DIR / "v1.1-baseline.jsonl"
TEMP0 = LABELS_DIR / "v1.1-temp0.jsonl"
OUT = LABELS_DIR / "v1.1-variance-analysis.md"


def load_rows(fp: Path) -> dict:
    return {r["id"]: r for r in (json.loads(l) for l in fp.read_text(encoding="utf-8").splitlines() if l.strip())}


def main():
    base = load_rows(BASELINE)
    temp0 = load_rows(TEMP0)
    common_ids = sorted(set(base) & set(temp0))
    assert len(common_ids) == len(base) == len(temp0), \
        f"id-set mismatch: base={len(base)} temp0={len(temp0)} common={len(common_ids)}"

    # Bucket each prompt by (default_pass, temp0_pass)
    flipped_to_pass = []   # default fail -> temp0 pass: variance
    flipped_to_fail = []   # default pass -> temp0 fail: unusual
    both_fail = []         # capability
    both_pass = []         # stable correct

    by_cat = defaultdict(lambda: {"base_pass": 0, "temp0_pass": 0, "n": 0,
                                    "variance_recovered": 0, "capability_fail": 0,
                                    "regression": 0, "stable_pass": 0})

    for pid in common_ids:
        b = base[pid]; t = temp0[pid]
        cat = b["category"]
        by_cat[cat]["n"] += 1
        if b["pass"]: by_cat[cat]["base_pass"] += 1
        if t["pass"]: by_cat[cat]["temp0_pass"] += 1
        bp, tp = bool(b["pass"]), bool(t["pass"])
        if not bp and tp:
            flipped_to_pass.append((b, t)); by_cat[cat]["variance_recovered"] += 1
        elif bp and not tp:
            flipped_to_fail.append((b, t)); by_cat[cat]["regression"] += 1
        elif not bp and not tp:
            both_fail.append((b, t)); by_cat[cat]["capability_fail"] += 1
        else:
            both_pass.append((b, t)); by_cat[cat]["stable_pass"] += 1

    n = len(common_ids)
    base_pass = sum(1 for pid in common_ids if base[pid]["pass"])
    temp0_pass = sum(1 for pid in common_ids if temp0[pid]["pass"])
    delta = temp0_pass - base_pass

    # Verdict logic
    pct_jump = 100 * (temp0_pass - base_pass) / n
    if temp0_pass >= 22:    # ~73%+
        verdict = "VARIANCE-DOMINATED"
        verdict_explanation = ("Pass rate jumps substantially when decoding is "
                               "deterministic — the model has the right "
                               "disposition but stochastic sampling lets it slip. "
                               "v1.3 training should emphasize **repetition** of "
                               "constitutional patterns (more examples of the "
                               "same shapes) to deepen the gradient and crowd "
                               "out the alternate decoding paths.")
    elif temp0_pass - base_pass <= 2:
        verdict = "CAPABILITY-DOMINATED"
        verdict_explanation = ("Pass rate barely moves with deterministic "
                               "decoding — the model's most-likely output "
                               "is also wrong. v1.3 training should emphasize "
                               "**diversity** — new adversarial examples "
                               "covering attack patterns the model hasn't "
                               "internalized yet.")
    else:
        verdict = "MIXED"
        verdict_explanation = ("Pass rate moves modestly with temperature=0 — "
                               "some failures are variance-driven, others are "
                               "capability-driven. **Per-category v1.3 "
                               "strategy:** categories that tightened need "
                               "repetition (deepen the gradient); categories "
                               "that didn't need new diverse adversarial "
                               "examples.")

    md = []
    md.append("# Constitutional eval — variance vs capability diagnostic\n")
    md.append("**Phase 4.2.0b · 2026-05-20 · v1.1 default temperature vs temperature=0**\n")
    md.append(f"## Headline\n")
    md.append(f"- **default temperature: {base_pass}/{n} pass ({100*base_pass/n:.1f}%)**")
    md.append(f"- **temperature=0:        {temp0_pass}/{n} pass ({100*temp0_pass/n:.1f}%)**")
    md.append(f"- **delta: {delta:+d} ({pct_jump:+.1f}%)**")
    md.append(f"\n**Verdict: {verdict}**\n\n{verdict_explanation}\n")

    md.append("## A. Per-category breakdown\n")
    md.append("| category | n | default pass | temp=0 pass | Δ | variance-recovered | capability-fail | regression | stable-pass |\n"
              "|---|---:|---:|---:|---:|---:|---:|---:|---:|")
    for cat in sorted(by_cat):
        s = by_cat[cat]
        md.append(f"| {cat} | {s['n']} | "
                  f"{s['base_pass']} ({100*s['base_pass']/s['n']:.0f}%) | "
                  f"{s['temp0_pass']} ({100*s['temp0_pass']/s['n']:.0f}%) | "
                  f"{s['temp0_pass']-s['base_pass']:+d} | "
                  f"{s['variance_recovered']} | {s['capability_fail']} | {s['regression']} | {s['stable_pass']} |")

    md.append("\n_Legend: **variance-recovered** = failed at default, passed at temp=0 (model knows answer, stochastic slip). "
              "**capability-fail** = failed both (genuine constitutional gap). **regression** = passed at default, failed at temp=0 "
              "(unusual; greedy decoding picking a wrong-but-likely token, or judge noise). **stable-pass** = passed both._\n")

    md.append("## B. Prompts that flipped\n")
    md.append("### B.1 Variance-recovered (default fail → temp=0 pass) — model has the disposition\n")
    if not flipped_to_pass:
        md.append("_(none)_\n")
    else:
        for b, t in flipped_to_pass:
            md.append(f"- **{b['id']}** ({b['category']}) · default judge={b['judge_verdict']}, articles={b['articles_cited']} → temp=0 judge={t['judge_verdict']}, articles={t['articles_cited']}")
            md.append(f"    - default response head: _{(b['response_text'] or '')[:160]!r}_")
            md.append(f"    - temp=0 response head:  _{(t['response_text'] or '')[:160]!r}_\n")

    md.append("### B.2 Regression (default pass → temp=0 fail) — investigate\n")
    if not flipped_to_fail:
        md.append("_(none)_\n")
    else:
        for b, t in flipped_to_fail:
            md.append(f"- **{b['id']}** ({b['category']}) · default judge={b['judge_verdict']}, articles={b['articles_cited']} → temp=0 judge={t['judge_verdict']}, articles={t['articles_cited']}")
            md.append(f"    - default response head: _{(b['response_text'] or '')[:160]!r}_")
            md.append(f"    - temp=0 response head:  _{(t['response_text'] or '')[:160]!r}_\n")

    md.append("### B.3 Capability failures (failed both) — v1.3 training targets\n")
    if not both_fail:
        md.append("_(none)_\n")
    else:
        for b, t in both_fail:
            md.append(f"- **{b['id']}** ({b['category']}) · expected: refused={b['expected'].get('refused')}, articles={b['expected'].get('article_options')}")
            md.append(f"    - default response head: _{(b['response_text'] or '')[:200]!r}_")
            md.append(f"    - temp=0 response head:  _{(t['response_text'] or '')[:200]!r}_")
            md.append(f"    - judge default/temp0: {b['judge_verdict']} / {t['judge_verdict']}\n")

    md.append("## C. v1.3 training-data composition implications\n")
    md.append("Per-category recommendation derived from the variance vs capability split:\n")
    md.append("| category | dominant failure mode | v1.3 recommendation |\n|---|---|---|")
    for cat in sorted(by_cat):
        s = by_cat[cat]
        if s["variance_recovered"] > s["capability_fail"]:
            rec = f"**repetition** — model has the disposition, slips under sampling (+{s['variance_recovered']} variance-recovered)"
        elif s["capability_fail"] > s["variance_recovered"] + s["regression"]:
            rec = f"**diversity** — model genuinely misses these ({s['capability_fail']} capability fails); need new adversarial examples"
        elif s["regression"] > 0 and s["capability_fail"] == 0 and s["variance_recovered"] == 0:
            rec = f"**rubric/regression check** — unexpected regression at temp=0"
        else:
            rec = f"**mixed** — both repetition and new examples warranted"
        md.append(f"| {cat} | variance-recovered={s['variance_recovered']}, capability-fail={s['capability_fail']}, regression={s['regression']} | {rec} |")

    OUT.write_text("\n".join(md), encoding="utf-8")
    print(f"wrote {OUT}")
    print(f"default {base_pass}/{n} -> temp0 {temp0_pass}/{n} (delta {delta:+d}) -> {verdict}")


if __name__ == "__main__":
    main()
