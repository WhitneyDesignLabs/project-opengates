#!/usr/bin/env python3
"""Phase 4.2.1.D Step d: v1.3 vs v1.1 comparison report.

Reads four eval result files (v1.1 default+temp0, v1.3 default+temp0)
plus the variance-analysis from 4.2.0b, computes:
  - per-category pass rate deltas at BOTH temperatures
  - article-citation rate v1.1 vs v1.3
  - results for the five 4.2.1.A target categories
  - roleplay-jailbreak (deception_04) result at default temp
  - regressions (prompts that passed in v1.1 but fail in v1.3)
  - v1.3 capability/variance shift (did temp=0 still pull ahead, or has
    training collapsed the variance gap?)

Writes results/v1.3-vs-v1.1.md as a single readable markdown report.
"""
import json
from collections import Counter, defaultdict
from pathlib import Path

RESULTS = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/eval/constitutional_eval/results")
OUT = RESULTS / "v1.3-vs-v1.1.md"


def load(fp: Path) -> dict:
    return {r["id"]: r for r in (json.loads(l) for l in fp.read_text(encoding="utf-8").splitlines() if l.strip())}


def label_dist(rows, key="judge_verdict"):
    return Counter(r[key] for r in rows.values())


def pct(part, whole): return f"{100*part/whole:.1f}%" if whole else "—"


def main():
    sets = {
        "v1.1 default": RESULTS / "v1.1-baseline.jsonl",
        "v1.1 temp=0":  RESULTS / "v1.1-temp0.jsonl",
        "v1.3 default": RESULTS / "v1.3-default.jsonl",
        "v1.3 temp=0":  RESULTS / "v1.3-temp0.jsonl",
    }
    data = {k: load(v) for k, v in sets.items()}
    n = len(next(iter(data.values())))

    # overall
    md = []
    md.append("# v1.3 vs v1.1 constitutional eval comparison\n")
    md.append("**Phase 4.2.1.D · 2026-05-20** · n=" + str(n) + " adversarial prompts × 6 categories\n")
    md.append("## A. Headline pass rates\n")
    md.append("| run | passes | rate |\n|---|---:|---:|")
    for name, rows in data.items():
        p = sum(1 for r in rows.values() if r["pass"])
        md.append(f"| {name} | {p}/{len(rows)} | **{pct(p,len(rows))}** |")

    # per-category cross-tab
    cats = sorted({r["category"] for rows in data.values() for r in rows.values()})
    md.append("\n## B. Per-category pass rates\n")
    md.append("| category | v1.1 default | v1.1 temp=0 | v1.3 default | v1.3 temp=0 | Δ default (v1.3−v1.1) | Δ temp=0 (v1.3−v1.1) |")
    md.append("|---|---:|---:|---:|---:|---:|---:|")
    cat_summary = []
    for cat in cats:
        row = {"cat": cat}
        for name, rows in data.items():
            cat_rows = [r for r in rows.values() if r["category"] == cat]
            p = sum(1 for r in cat_rows if r["pass"])
            row[name] = (p, len(cat_rows))
        d_def = row["v1.3 default"][0] - row["v1.1 default"][0]
        d_t0 = row["v1.3 temp=0"][0] - row["v1.1 temp=0"][0]
        cat_summary.append((cat, row, d_def, d_t0))
        md.append(f"| {cat} | "
                  f"{row['v1.1 default'][0]}/{row['v1.1 default'][1]} ({pct(*row['v1.1 default'])}) | "
                  f"{row['v1.1 temp=0'][0]}/{row['v1.1 temp=0'][1]} ({pct(*row['v1.1 temp=0'])}) | "
                  f"{row['v1.3 default'][0]}/{row['v1.3 default'][1]} ({pct(*row['v1.3 default'])}) | "
                  f"{row['v1.3 temp=0'][0]}/{row['v1.3 temp=0'][1]} ({pct(*row['v1.3 temp=0'])}) | "
                  f"{d_def:+d} | {d_t0:+d} |")

    # article-citation rate when refusal expected
    def art_rate(rows):
        refused = [r for r in rows.values() if r["expected"].get("refused")]
        if not refused:
            return 0, 0
        cited = sum(1 for r in refused if r["articles_cited"])
        return cited, len(refused)
    md.append("\n## C. Article-citation rate (when refusal expected)\n")
    md.append("| run | cited / refused-expected | rate |\n|---|---:|---:|")
    for name, rows in data.items():
        c, t = art_rate(rows)
        md.append(f"| {name} | {c}/{t} | **{pct(c,t)}** |")

    # 4.2.1.A target categories
    target_cats = ["log_tampering", "deception", "truth_uncertainty", "authorization", "harm"]
    md.append("\n## D. Phase 4.2.1.A target categories — focused view\n")
    md.append("| category | v1.1 default | v1.3 default | Δ | v1.1 temp=0 | v1.3 temp=0 | Δ |")
    md.append("|---|---:|---:|---:|---:|---:|---:|")
    for cat in target_cats:
        v1d = [r for r in data["v1.1 default"].values() if r["category"] == cat]
        v3d = [r for r in data["v1.3 default"].values() if r["category"] == cat]
        v1t = [r for r in data["v1.1 temp=0"].values() if r["category"] == cat]
        v3t = [r for r in data["v1.3 temp=0"].values() if r["category"] == cat]
        d_def = sum(1 for r in v3d if r["pass"]) - sum(1 for r in v1d if r["pass"])
        d_t0 = sum(1 for r in v3t if r["pass"]) - sum(1 for r in v1t if r["pass"])
        md.append(f"| {cat} | "
                  f"{sum(1 for r in v1d if r['pass'])}/{len(v1d)} | "
                  f"{sum(1 for r in v3d if r['pass'])}/{len(v3d)} | "
                  f"{d_def:+d} | "
                  f"{sum(1 for r in v1t if r['pass'])}/{len(v1t)} | "
                  f"{sum(1 for r in v3t if r['pass'])}/{len(v3t)} | "
                  f"{d_t0:+d} |")

    # roleplay-jailbreak (deception_04) specific
    md.append("\n## E. Roleplay-jailbreak — `deception_04_roleplay_unrestricted`\n")
    md.append("This was v1.1's most concerning default-temp failure. 4.2.1.A added 8 explicit roleplay-jailbreak training shapes.")
    md.append("\n| run | judge | articles | pass | response head |")
    md.append("|---|---|---|:-:|---|")
    for name, rows in data.items():
        r = rows.get("deception_04_roleplay_unrestricted")
        if not r: continue
        head = (r["response_text"] or "").replace("\n", " ")[:120]
        md.append(f"| {name} | **{r['judge_verdict']}** | {r['articles_cited'] or '—'} | "
                  f"{'✓' if r['pass'] else '✗'} | _{head}_ |")

    # regression list — prompts that passed in v1.1 (either temp) but fail in v1.3 (same temp)
    def diff_set(prev, cur):
        regressed = []
        improved = []
        same_pass = 0
        same_fail = 0
        for pid in prev:
            if pid not in cur: continue
            pp = bool(prev[pid]["pass"]); cp = bool(cur[pid]["pass"])
            if pp and not cp: regressed.append((pid, prev[pid], cur[pid]))
            elif not pp and cp: improved.append((pid, prev[pid], cur[pid]))
            elif pp and cp: same_pass += 1
            else: same_fail += 1
        return regressed, improved, same_pass, same_fail

    md.append("\n## F. Per-prompt diff (v1.1 → v1.3)\n")
    for label, (prev_name, cur_name) in [
        ("default temperature", ("v1.1 default", "v1.3 default")),
        ("temperature=0", ("v1.1 temp=0", "v1.3 temp=0")),
    ]:
        regressed, improved, sp, sf = diff_set(data[prev_name], data[cur_name])
        md.append(f"\n### {label} — diff\n")
        md.append(f"- improved (fail→pass): {len(improved)}")
        md.append(f"- regressed (pass→fail): **{len(regressed)}**")
        md.append(f"- stable pass: {sp}")
        md.append(f"- stable fail: {sf}\n")
        if regressed:
            md.append(f"#### regressions ({len(regressed)})")
            md.append("| id | v1.1 judge | v1.3 judge | v1.1 cited | v1.3 cited |")
            md.append("|---|---|---|---|---|")
            for pid, p, c in regressed:
                md.append(f"| `{pid}` | {p['judge_verdict']} | {c['judge_verdict']} | "
                          f"{p['articles_cited'] or '—'} | {c['articles_cited'] or '—'} |")
        if improved:
            md.append(f"\n#### improvements ({len(improved)})")
            md.append("| id | v1.1 judge | v1.3 judge | v1.1 cited | v1.3 cited |")
            md.append("|---|---|---|---|---|")
            for pid, p, c in improved:
                md.append(f"| `{pid}` | {p['judge_verdict']} | {c['judge_verdict']} | "
                          f"{p['articles_cited'] or '—'} | {c['articles_cited'] or '—'} |")

    # variance vs capability shift
    md.append("\n## G. Variance vs capability shift\n")
    v1_default = sum(1 for r in data["v1.1 default"].values() if r["pass"])
    v1_t0      = sum(1 for r in data["v1.1 temp=0" ].values() if r["pass"])
    v3_default = sum(1 for r in data["v1.3 default"].values() if r["pass"])
    v3_t0      = sum(1 for r in data["v1.3 temp=0" ].values() if r["pass"])
    md.append(f"- v1.1: {v1_default} default, {v1_t0} temp=0 — variance gap **{v1_t0 - v1_default:+d}** (default→temp=0)")
    md.append(f"- v1.3: {v3_default} default, {v3_t0} temp=0 — variance gap **{v3_t0 - v3_default:+d}** (default→temp=0)")
    md.append("")
    if (v3_t0 - v3_default) < (v1_t0 - v1_default):
        md.append("**Variance gap narrowed in v1.3** — training crowded out the alternate decoding paths, "
                  "so default-temperature performance is closer to greedy-best. This is the expected effect "
                  "of repetition-heavy training.")
    elif (v3_t0 - v3_default) > (v1_t0 - v1_default):
        md.append("**Variance gap widened in v1.3** — unexpected; check for instability.")
    else:
        md.append("**Variance gap unchanged** — training shifted the absolute level without changing the "
                  "temperature-dependence shape.")

    OUT.write_text("\n".join(md), encoding="utf-8")
    print(f"wrote {OUT}")

    # Print key topline to stdout for chat surfacing
    print(f"\nHEADLINE:")
    print(f"  v1.1 default: {v1_default}/{n} ({pct(v1_default,n)})")
    print(f"  v1.3 default: {v3_default}/{n} ({pct(v3_default,n)})  Δ {v3_default - v1_default:+d}")
    print(f"  v1.1 temp=0:  {v1_t0}/{n} ({pct(v1_t0,n)})")
    print(f"  v1.3 temp=0:  {v3_t0}/{n} ({pct(v3_t0,n)})  Δ {v3_t0 - v1_t0:+d}")
    for label, (pn, cn) in [("default", ("v1.1 default","v1.3 default")), ("temp=0", ("v1.1 temp=0","v1.3 temp=0"))]:
        r, i, _, _ = diff_set(data[pn], data[cn])
        print(f"  diff {label}: +{len(i)} improved, -{len(r)} regressed")


if __name__ == "__main__":
    main()
