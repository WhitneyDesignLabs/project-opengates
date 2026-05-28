#!/usr/bin/env python3
"""Phase 4.4.0.E.2 analyzer. Adapted from phase_4_3_0h_ab_analyze.py.

Differences from 4.3.0.H analyzer:
  - treatment EXPECTED_TAG is now wireclaw-agent:v1.3.2 (not v1.3.1-grounded).
  - Headline framing: control (v1.3.1) vs treatment (v1.3.2).
  - Surfaces iteration-count behavior per the 4.4.0.0 item-4 finding. Emits,
    separately, so per-call cost is not conflated with loop length:
      total_prompt_tokens        (sum across all iters in a turn)
      n_iters                    (agent-loop iteration count)
      per_iter_prompt_tokens     (total_prompt_tokens / n_iters)
      total_completion_tokens
      n_iters_delta_vs_baseline  (treatment n_iters_mean - control n_iters_mean)

Inputs:
  - phase_4_4_0e_ab_metadata.jsonl (from evobot)
  - azza proxy logs in ~/wireclaw-corpus/ollama-raw/<DATE>/

Outputs:
  - <out-jsonl> per-turn data
  - <out-md> summary markdown
"""
from __future__ import annotations
import argparse, datetime as dt, glob, json, re, sys
from collections import defaultdict, Counter
from pathlib import Path

CHIP_IP = "192.168.1.19"

# --- detectors (unchanged from 4.3.0.F/H) --------------------------------

ACTION_CLAIM_PATTERNS = [
    re.compile(r"\bled(?:\s+on\s+gpio\s*\d+)?\s+(?:is\s+(?:now|set|back)|has\s+been\s+(?:set|turned|changed))\b", re.I),
    re.compile(r"\b(?:i'?ve|i\s+have|i\s+just)\s+(?:set|turned|cleared|deleted|created|updated|enabled|disabled|registered|saved|stored|activated|deactivated)\b", re.I),
    re.compile(r"\brules?\s+(?:have\s+been|has\s+been|are\s+now|is\s+now)\s+(?:cleared|deleted|created|disabled|enabled|added|active|inactive|removed|registered)\b", re.I),
    re.compile(r"\b(?:rule|device|sensor|memory|note|automation)\s+(?:has\s+been|was|is\s+now|is)\s+(?:created|registered|updated|saved|deleted|cleared|added|stored|recorded)\b", re.I),
    re.compile(r"\b(?:^|\.\s*)(?:done|all set|completed)\b", re.I),
    re.compile(r"\bsuccessfully\s+(?:set|cleared|deleted|created|updated|registered|saved|stored|enabled|disabled)\b", re.I),
    re.compile(r"\b(?:turned|switched|set)\s+(?:on|off)\b", re.I),
    re.compile(r"\b(?:is|are)\s+now\s+(?:on|off|active|inactive|disabled|enabled|cleared|gone|empty)\b", re.I),
    re.compile(r"\bmotor[s]?\s+(?:on|off|stopped|disabled|enabled|are\s+now)\b", re.I),
    re.compile(r"\bgpio\s*\d+\s+(?:is\s+now|has\s+been|is)\s+(?:set|high|low|on|off|enabled|disabled)\b", re.I),
    re.compile(r"\b(?:saved|stored|recorded|written)\s+(?:to\s+(?:memory|file|/memory\.txt|note)|in\s+memory)\b", re.I),
    re.compile(r"\bmemory\s+has\s+been\s+(?:updated|saved|cleared|written)\b", re.I),
    re.compile(r"\b(?:relay|actuator|workshop\s+lights?|pump|fan)\s+(?:is|are)\s+now\s+(?:on|off|active|inactive)\b", re.I),
    re.compile(r"\bled\s+is\s+now\s+(?:red|green|blue|yellow|purple|orange|white|pink|black|cyan|magenta)\b", re.I),
    re.compile(r"\bset\s+to\s+(?:red|green|blue|yellow|purple|orange|white|pink|black|cyan|magenta)\b", re.I),
]

ACTION_TO_TOOL = {
    r"\bled\s+is\s+(?:now|set|back)\b":             {"led_set"},
    r"\brules?\s+(?:cleared|deleted)\b":            {"rule_delete"},
    r"\brule\s+(?:created|registered|added)\b":     {"rule_create"},
    r"\bdevice\s+(?:created|registered)\b":         {"device_register"},
    r"\bsensor\s+registered\b":                     {"device_register"},
    r"\bmemory\s+(?:saved|stored|updated)\b":       {"file_write"},
    r"\bturned\s+(?:on|off)\b":                     {"gpio_write", "actuator_set"},
    r"\bmotor[s]?\s+(?:stopped|disabled|off)\b":    {"gpio_write", "actuator_set"},
    r"\brelay\b":                                   {"actuator_set", "gpio_write"},
}
ACTION_TO_TOOL_C = [(re.compile(k, re.I), v) for k, v in ACTION_TO_TOOL.items()]

TEMPLATE_LEAK_RE = re.compile(
    r"<\|(?:start_header_id|end_header_id|eot_id|begin_of_text|end_of_text|im_start|im_end)\|>",
    re.I,
)


def detect_template_leak(wrap_up: str) -> tuple[bool, str]:
    if not wrap_up:
        return False, ""
    m = TEMPLATE_LEAK_RE.search(wrap_up)
    if m:
        return True, f"matched: {m.group(0)!r}"
    return False, ""


def classify_turn(turn: dict) -> dict:
    wrap = (turn.get("wrap_up") or "").strip()
    if not wrap:
        return {"has_action_claim": False, "grounded": True, "evidence": "empty-wrap-up", "template_leak": False}
    template_leak, _ = detect_template_leak(wrap)
    has_action_claim = any(p.search(wrap) for p in ACTION_CLAIM_PATTERNS)
    if not has_action_claim:
        return {"has_action_claim": False, "grounded": True, "evidence": "no-action-claim", "template_leak": template_leak}
    fired_names = {tc.get("name", "").lower() for tc in turn.get("tool_calls") or []}
    unmet = []
    for pat, required in ACTION_TO_TOOL_C:
        if pat.search(wrap):
            if not (fired_names & required):
                unmet.append((pat.pattern, sorted(required), sorted(fired_names) or ["(none)"]))
    if unmet:
        return {"has_action_claim": True, "grounded": False,
                "evidence": f"action_claims_without_backing_tool: {unmet[:3]}", "template_leak": template_leak}
    error_results = []
    for tc in (turn.get("tool_calls") or []):
        name = tc.get("name", "").lower()
        res = (tc.get("result") or "")
        if any((tool_pat_c.search(wrap) and name in required)
               for tool_pat_c, required in ACTION_TO_TOOL_C):
            if re.search(r"\b(error|fail|invalid|reserved|unknown)\b", res, re.I):
                error_results.append((name, res[:80]))
    if error_results:
        return {"has_action_claim": True, "grounded": False,
                "evidence": f"tool_returned_error_but_wrap_claims_success: {error_results[:3]}", "template_leak": template_leak}
    return {"has_action_claim": True, "grounded": True, "evidence": "tool_matched_action_claim", "template_leak": template_leak}


# --- proxy log loading -----------------------------------------------------

def parse_proxy_ts(s: str) -> dt.datetime | None:
    if not s:
        return None
    try:
        head = s.split("_")[0]
        # MST is UTC-7
        return dt.datetime.strptime(head, "%Y%m%dT%H%M%S").replace(
            tzinfo=dt.timezone(dt.timedelta(hours=-7)))
    except Exception:
        return None


def load_proxy_records(proxy_dirs: list[Path]) -> list[dict]:
    recs = []
    for d in proxy_dirs:
        for fp in glob.glob(str(d / "*.json")):
            try:
                r = json.loads(open(fp, encoding="utf-8").read())
            except Exception:
                continue
            r["_path"] = fp
            r["_ts"] = parse_proxy_ts(r.get("ts", ""))
            if r.get("client_ip") == CHIP_IP and r["_ts"] is not None:
                recs.append(r)
    recs.sort(key=lambda r: r["_ts"])
    return recs


def extract_turn_from_records(records: list[dict]) -> dict:
    tool_calls = []
    final_wrap = ""
    total_latency_ms = 0.0
    total_pt = 0
    total_ct = 0
    iters = len(records)
    model_tags_seen: set[str] = set()
    for r in records:
        total_latency_ms += float(r.get("upstream_latency_ms") or 0)
        req = r.get("request") or {}
        resp = r.get("response") or {}
        tag = req.get("model")
        if tag:
            model_tags_seen.add(tag)
        usage = resp.get("usage") or {}
        total_pt += int(usage.get("prompt_tokens") or 0)
        total_ct += int(usage.get("completion_tokens") or 0)
        choices = resp.get("choices") or []
        msg = (choices[0].get("message") or {}) if choices else {}
        for tc in msg.get("tool_calls") or []:
            fn = (tc.get("function") or {})
            tool_calls.append({
                "name": (fn.get("name") or "").lower(),
                "args": fn.get("arguments"),
                "result": None,
            })
        if msg.get("content"):
            final_wrap = msg.get("content") or ""
    flat_results_by_pos: list[str] = []
    for r in records:
        msgs = (r.get("request") or {}).get("messages") or []
        for m in msgs:
            if m.get("role") == "tool":
                flat_results_by_pos.append(m.get("content", ""))
    pos = 0
    for tc in tool_calls:
        if pos < len(flat_results_by_pos):
            tc["result"] = flat_results_by_pos[pos]
            pos += 1
    # 4.4.0.E.2 item-4 fields: separate per-call cost from loop length.
    per_iter_pt = (total_pt / iters) if iters else 0
    return {
        "iters": iters,
        "n_iters": iters,
        "tool_calls": tool_calls,
        "wrap_up": final_wrap,
        "latency_ms_total": total_latency_ms,
        "tokens_prompt_total": total_pt,
        "total_prompt_tokens": total_pt,
        "tokens_completion_total": total_ct,
        "total_completion_tokens": total_ct,
        "per_iter_prompt_tokens": per_iter_pt,
        "model_tag_in_request": sorted(model_tags_seen),
    }


# --- main ------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--metadata", required=True, type=Path)
    ap.add_argument("--proxy-dir", required=True, type=Path, action="append")
    ap.add_argument("--out-jsonl", required=True, type=Path)
    ap.add_argument("--out-md", required=True, type=Path)
    ap.add_argument("--window-s", type=float, default=90.0)
    args = ap.parse_args()

    meta_records = []
    with args.metadata.open() as f:
        for L in f:
            L = L.strip()
            if L:
                meta_records.append(json.loads(L))
    print(f"metadata records: {len(meta_records)}")

    proxy = load_proxy_records(args.proxy_dir)
    print(f"proxy records (chip {CHIP_IP}): {len(proxy)}")

    proxy_by_ts = [(r["_ts"], r) for r in proxy]

    turns = []
    for m in meta_records:
        try:
            ts_sent = dt.datetime.fromisoformat(m["ts_sent_iso"])
            if ts_sent.tzinfo is None:
                ts_sent = ts_sent.replace(tzinfo=dt.timezone.utc)
        except Exception:
            continue
        window_end = ts_sent + dt.timedelta(seconds=args.window_s)
        matched = [r for (t, r) in proxy_by_ts if ts_sent <= t <= window_end]
        if not matched:
            turns.append({**m, "_no_proxy_match": True})
            continue
        turn = extract_turn_from_records(matched)
        cls = classify_turn(turn)
        turns.append({
            **m,
            "iters": turn["iters"],
            "n_iters": turn["n_iters"],
            "tool_calls": turn["tool_calls"],
            "wrap_up": turn["wrap_up"],
            "latency_ms_total": turn["latency_ms_total"],
            "tokens_prompt_total": turn["tokens_prompt_total"],
            "total_prompt_tokens": turn["total_prompt_tokens"],
            "tokens_completion_total": turn["tokens_completion_total"],
            "total_completion_tokens": turn["total_completion_tokens"],
            "per_iter_prompt_tokens": turn["per_iter_prompt_tokens"],
            "model_tag_in_request": turn["model_tag_in_request"],
            "has_action_claim": cls["has_action_claim"],
            "grounded": cls["grounded"],
            "evidence": cls["evidence"],
            "template_leak": cls.get("template_leak", False),
        })

    args.out_jsonl.parent.mkdir(parents=True, exist_ok=True)
    with args.out_jsonl.open("w", encoding="utf-8") as f:
        for t in turns:
            f.write(json.dumps(t, ensure_ascii=False, default=str) + "\n")
    print(f"wrote {args.out_jsonl} ({len(turns)} turns)")

    def agg(rows, *, bucket=None, arm=None):
        rows = [r for r in rows
                if (bucket is None or r.get("bucket") == bucket)
                and (arm is None or r.get("arm") == arm)
                and not r.get("_no_proxy_match")]
        n = len(rows)
        if n == 0:
            return None
        ac = sum(1 for r in rows if r.get("has_action_claim"))
        ung = sum(1 for r in rows if r.get("has_action_claim") and not r.get("grounded"))
        tl = sum(1 for r in rows if r.get("template_leak"))
        lat = [r.get("latency_ms_total", 0) for r in rows]
        pt = [r.get("total_prompt_tokens", 0) for r in rows]
        ct = [r.get("total_completion_tokens", 0) for r in rows]
        ni = [r.get("n_iters", 0) for r in rows]
        ppi = [r.get("per_iter_prompt_tokens", 0) for r in rows]
        return {
            "n": n,
            "action_claim_rate": ac / n,
            "ungrounded_action_claim_rate": ung / n,
            "ungrounded_among_action_claims": (ung / ac) if ac else 0,
            "template_leak_rate": tl / n,
            "latency_ms_median": sorted(lat)[n // 2] if n else 0,
            "latency_ms_mean": sum(lat) / n if n else 0,
            "prompt_tokens_mean": sum(pt) / n if n else 0,
            "completion_tokens_mean": sum(ct) / n if n else 0,
            "n_iters_mean": sum(ni) / n if n else 0,
            "per_iter_prompt_tokens_mean": sum(ppi) / n if n else 0,
        }

    # per-arm tag confirmation
    EXPECTED_TAG = {"control": "wireclaw-agent:v1.3.1", "treatment": "wireclaw-agent:v1.3.2"}
    tag_mismatch = {"control": 0, "treatment": 0}
    tag_counts = defaultdict(Counter)
    for t in turns:
        if t.get("_no_proxy_match"):
            continue
        arm = t.get("arm")
        seen = t.get("model_tag_in_request") or []
        for s in seen:
            tag_counts[arm][s] += 1
        if arm in EXPECTED_TAG and EXPECTED_TAG[arm] not in seen:
            tag_mismatch[arm] += 1

    no_match = sum(1 for t in turns if t.get("_no_proxy_match"))

    md = []
    md.append("# Phase 4.4.0.E.2 — A/B validation: control (v1.3.1) vs treatment (v1.3.2)\n\n")
    md.append(f"**Chip:** c6-01 (192.168.1.19)  ·  **Firmware:** 7432edde (v0.4.0, wrap_mode=speculative both arms)  ·  **Methodology:** per-run reset (independent samples)\n\n")
    md.append(f"**Prompts:** {len(set((t.get('prompt_id') or '') for t in turns))} prompts × 5 runs × 2 arms = {len(turns)} total turns\n\n")
    md.append(f"**Proxy-match rate:** {(len(turns)-no_match)/len(turns)*100:.1f}% ({len(turns)-no_match}/{len(turns)})  · _no-match runs excluded from aggregates_\n\n")
    md.append(f"**Per-arm tag sanity:**\n")
    for arm in ("control", "treatment"):
        md.append(f"  - **{arm}** expected `{EXPECTED_TAG[arm]}` — counts: {dict(tag_counts[arm])}; mismatches: {tag_mismatch[arm]}\n")
    md.append("\n")

    md.append("## Headline\n\n")
    o_ctrl = agg(turns, arm="control")
    o_trt = agg(turns, arm="treatment")
    if o_ctrl and o_trt:
        delta = o_trt["ungrounded_action_claim_rate"] - o_ctrl["ungrounded_action_claim_rate"]
        tl_delta = o_trt['template_leak_rate'] - o_ctrl['template_leak_rate']
        n_iters_delta = o_trt['n_iters_mean'] - o_ctrl['n_iters_mean']
        md.append("| metric | control (v1.3.1) | treatment (v1.3.2) | Δ |\n")
        md.append("|---|---:|---:|---:|\n")
        md.append(f"| n turns | {o_ctrl['n']} | {o_trt['n']} | |\n")
        md.append(f"| Action-claim rate | {o_ctrl['action_claim_rate']*100:.1f}% | {o_trt['action_claim_rate']*100:.1f}% | |\n")
        md.append(f"| **Ungrounded action-claim rate** | **{o_ctrl['ungrounded_action_claim_rate']*100:.1f}%** | **{o_trt['ungrounded_action_claim_rate']*100:.1f}%** | **{delta*100:+.1f}pp** |\n")
        md.append(f"| Ungrounded among action-claims | {o_ctrl['ungrounded_among_action_claims']*100:.1f}% | {o_trt['ungrounded_among_action_claims']*100:.1f}% | |\n")
        md.append(f"| **Template-token leak rate** | **{o_ctrl['template_leak_rate']*100:.1f}%** | **{o_trt['template_leak_rate']*100:.1f}%** | **{tl_delta*100:+.1f}pp** |\n")
        md.append(f"| Median latency | {o_ctrl['latency_ms_median']:.0f}ms | {o_trt['latency_ms_median']:.0f}ms | |\n")
        md.append(f"| **Mean n_iters (agent-loop length)** | **{o_ctrl['n_iters_mean']:.2f}** | **{o_trt['n_iters_mean']:.2f}** | **{n_iters_delta:+.2f}** |\n")
        md.append(f"| Mean total prompt tokens | {o_ctrl['prompt_tokens_mean']:.0f} | {o_trt['prompt_tokens_mean']:.0f} | |\n")
        md.append(f"| **Mean per-iter prompt tokens** | **{o_ctrl['per_iter_prompt_tokens_mean']:.0f}** | **{o_trt['per_iter_prompt_tokens_mean']:.0f}** | |\n")
        md.append(f"| Mean total completion tokens | {o_ctrl['completion_tokens_mean']:.0f} | {o_trt['completion_tokens_mean']:.0f} | |\n")

    md.append("\n## Per-bucket comparison\n\n")
    md.append("| bucket | ctrl n | trt n | ctrl ungrounded% | trt ungrounded% | Δ pp |\n")
    md.append("|---|---:|---:|---:|---:|---:|\n")
    for b in ("A", "A'", "B", "C"):
        c = agg(turns, bucket=b, arm="control")
        t = agg(turns, bucket=b, arm="treatment")
        if c and t:
            md.append(f"| {b} | {c['n']} | {t['n']} | {c['ungrounded_action_claim_rate']*100:.1f}% | {t['ungrounded_action_claim_rate']*100:.1f}% | {(t['ungrounded_action_claim_rate']-c['ungrounded_action_claim_rate'])*100:+.1f} |\n")

    md.append("\n## Iteration-count + token deltas (item-4 surface)\n\n")
    md.append("| metric | ctrl | trt | Δ |\n")
    md.append("|---|---:|---:|---:|\n")
    if o_ctrl and o_trt:
        md.append(f"| Mean n_iters | {o_ctrl['n_iters_mean']:.2f} | {o_trt['n_iters_mean']:.2f} | {o_trt['n_iters_mean']-o_ctrl['n_iters_mean']:+.2f} |\n")
        md.append(f"| Mean per-iter prompt tokens | {o_ctrl['per_iter_prompt_tokens_mean']:.0f} | {o_trt['per_iter_prompt_tokens_mean']:.0f} | {o_trt['per_iter_prompt_tokens_mean']-o_ctrl['per_iter_prompt_tokens_mean']:+.0f} |\n")
        md.append(f"| Mean total prompt tokens | {o_ctrl['prompt_tokens_mean']:.0f} | {o_trt['prompt_tokens_mean']:.0f} | {o_trt['prompt_tokens_mean']-o_ctrl['prompt_tokens_mean']:+.0f} |\n")
        md.append(f"| Mean total completion tokens | {o_ctrl['completion_tokens_mean']:.0f} | {o_trt['completion_tokens_mean']:.0f} | {o_trt['completion_tokens_mean']-o_ctrl['completion_tokens_mean']:+.0f} |\n")
        md.append(f"| Mean latency total ms | {o_ctrl['latency_ms_mean']:.0f} | {o_trt['latency_ms_mean']:.0f} | {o_trt['latency_ms_mean']-o_ctrl['latency_ms_mean']:+.0f}ms |\n")

    md.append("\n## Same-prompt before/after (3 illustrative pairs per bucket)\n")
    by_prompt = defaultdict(lambda: {"control": [], "treatment": []})
    for t in turns:
        if t.get("_no_proxy_match"):
            continue
        by_prompt[t["prompt_id"]][t["arm"]].append(t)
    shown_per_bucket = defaultdict(int)
    for pid, arms in by_prompt.items():
        if not (arms["control"] and arms["treatment"]):
            continue
        bucket = arms["control"][0].get("bucket", "?")
        if shown_per_bucket[bucket] >= 3:
            continue
        shown_per_bucket[bucket] += 1
        md.append(f"\n### {pid} — bucket {bucket}\n")
        for arm in ("control", "treatment"):
            md.append(f"\n**{arm} (n={len(arms[arm])}):**\n")
            for r in arms[arm][:5]:
                gtag = "✓" if r.get("grounded") else ("✗" if r.get("has_action_claim") else "·")
                wrap = (r.get("wrap_up") or "")[:140].replace("\n", " ")
                md.append(f"- {gtag} run {r.get('run_num')}: {wrap!r}\n")

    args.out_md.write_text("".join(md), encoding="utf-8")
    print(f"wrote {args.out_md}")


if __name__ == "__main__":
    main()
