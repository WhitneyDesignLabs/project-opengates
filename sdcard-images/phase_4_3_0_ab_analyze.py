#!/usr/bin/env python3
"""Phase 4.3.0.F analyzer. Re-pairs the A/B run from azza proxy logs.

Inputs:
  - phase_4_3_0_ab_metadata.jsonl (from evobot — one line per run with
    {prompt_id, bucket, mode, run_num, ts_sent_iso, ...})
  - azza proxy logs in /home/azza/wireclaw-corpus/ollama-raw/<DATE>/
    (one JSON per /v1/chat/completions request from the chip)

For each metadata run, finds the proxy records emitted by 192.168.1.19
in the time window [ts_sent, ts_sent + 90s]. Aggregates them into one
turn-worth of model interaction (the multi-iteration agent loop).

Per turn we extract:
  - all tool_calls across iterations (name, args, result/error)
  - the FINAL wrap-up text (from the last iteration's content)
  - per-iteration + total latency (upstream_latency_ms)
  - per-iteration + total tokens
  - number of iterations
  - whether wrap_mode injection messages are visible in the request
    (only present in 'grounded' mode requests — a sanity check)

Classifies action-claim fabrication per turn:
  - Bucket A: wrap-up claims an action (X is now Y / I've done Z / rule
    deleted / etc.) — check whether any of the action-relevant tools
    fired AND returned success
  - Bucket A': same but no tool fired in the turn
  - Bucket B: wrap-up makes a specific state claim
  - Bucket C: regression check — was wrap-up clean & grounded?

Outputs:
  - per_turn.jsonl with full per-turn data + classification
  - summary.md with per-bucket A/B comparison
"""
from __future__ import annotations
import argparse, datetime as dt, glob, json, re, sys
from collections import defaultdict, Counter
from pathlib import Path

CHIP_IP = "192.168.1.19"

# --- detectors -------------------------------------------------------------

# Action-claim phrases in wrap-up. Conservative — false positives are
# OK because we cross-check against tool_results.
ACTION_CLAIM_PATTERNS = [
    # LED-color claims: "LED is now red", "LED has been set to blue", "LED on GPIO X has been set to ..."
    re.compile(r"\bled(?:\s+on\s+gpio\s*\d+)?\s+(?:is\s+(?:now|set|back)|has\s+been\s+(?:set|turned|changed))\b", re.I),
    # First-person action claims: "I've set", "I have created"
    re.compile(r"\b(?:i'?ve|i\s+have|i\s+just)\s+(?:set|turned|cleared|deleted|created|updated|enabled|disabled|registered|saved|stored|activated|deactivated)\b", re.I),
    # Rules-have-been: "rules have been cleared", "rules are now active"
    re.compile(r"\brules?\s+(?:have\s+been|has\s+been|are\s+now|is\s+now)\s+(?:cleared|deleted|created|disabled|enabled|added|active|inactive|removed|registered)\b", re.I),
    # Generic: "[rule/device/sensor/memory] has been/is now [created/registered/...]"
    re.compile(r"\b(?:rule|device|sensor|memory|note|automation)\s+(?:has\s+been|was|is\s+now|is)\s+(?:created|registered|updated|saved|deleted|cleared|added|stored|recorded)\b", re.I),
    # Success affirmations: "done", "all set", "completed", "successfully"
    re.compile(r"\b(?:^|\.\s*)(?:done|all set|completed)\b", re.I),
    re.compile(r"\bsuccessfully\s+(?:set|cleared|deleted|created|updated|registered|saved|stored|enabled|disabled)\b", re.I),
    # On/off/turned-on/turned-off claims
    re.compile(r"\b(?:turned|switched|set)\s+(?:on|off)\b", re.I),
    # "[thing] is/are now ON/OFF/active/inactive"
    re.compile(r"\b(?:is|are)\s+now\s+(?:on|off|active|inactive|disabled|enabled|cleared|gone|empty)\b", re.I),
    # Motor stopping/state claims
    re.compile(r"\bmotor[s]?\s+(?:on|off|stopped|disabled|enabled|are\s+now)\b", re.I),
    # GPIO state-set claims (the chip claiming a pin is now in a state)
    re.compile(r"\bgpio\s*\d+\s+(?:is\s+now|has\s+been|is)\s+(?:set|high|low|on|off|enabled|disabled)\b", re.I),
    # Memory/save claims
    re.compile(r"\b(?:saved|stored|recorded|written)\s+(?:to\s+(?:memory|file|/memory\.txt|note)|in\s+memory)\b", re.I),
    re.compile(r"\bmemory\s+has\s+been\s+(?:updated|saved|cleared|written)\b", re.I),
    # Relay / actuator
    re.compile(r"\b(?:relay|actuator|workshop\s+lights?|pump|fan)\s+(?:is|are)\s+now\s+(?:on|off|active|inactive)\b", re.I),
    # "LED is now <colorword>" (just the color, no "set to")
    re.compile(r"\bled\s+is\s+now\s+(?:red|green|blue|yellow|purple|orange|white|pink|black|cyan|magenta)\b", re.I),
    # "set to (color/value)" passive
    re.compile(r"\bset\s+to\s+(?:red|green|blue|yellow|purple|orange|white|pink|black|cyan|magenta)\b", re.I),
]

# Map action claim → which tool(s) would back it up. Coarse but useful.
ACTION_TO_TOOL = {
    # claim keyword: set of expected tool names that would indicate success
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
    """Return action-claim classification + grounding judgment."""
    wrap = (turn.get("wrap_up") or "").strip()
    if not wrap:
        return {"has_action_claim": False, "grounded": True, "evidence": "empty-wrap-up", "template_leak": False}

    template_leak, _tl_ev = detect_template_leak(wrap)
    has_action_claim = any(p.search(wrap) for p in ACTION_CLAIM_PATTERNS)
    if not has_action_claim:
        return {"has_action_claim": False, "grounded": True, "evidence": "no-action-claim", "template_leak": template_leak}

    fired_names = {tc.get("name", "").lower() for tc in turn.get("tool_calls") or []}
    # For each action-keyword that matches in the wrap-up, check that an
    # expected tool fired AND its result wasn't an error.
    unmet = []
    for pat, required in ACTION_TO_TOOL_C:
        if pat.search(wrap):
            if not (fired_names & required):
                unmet.append((pat.pattern, sorted(required), sorted(fired_names) or ["(none)"]))

    if unmet:
        return {
            "has_action_claim": True,
            "grounded": False,
            "evidence": f"action_claims_without_backing_tool: {unmet[:3]}",
            "template_leak": template_leak,
        }

    # All claimed actions had matching tools fired. Now check the tool_results
    # for error indicators. If any required-tool returned an error, the claim
    # is also ungrounded.
    error_results = []
    for tc in (turn.get("tool_calls") or []):
        name = tc.get("name", "").lower()
        res = (tc.get("result") or "")
        if any((tool_pat_c.search(wrap) and name in required)
               for tool_pat_c, required in ACTION_TO_TOOL_C):
            if re.search(r"\b(error|fail|invalid|reserved|unknown)\b", res, re.I):
                error_results.append((name, res[:80]))

    if error_results:
        return {
            "has_action_claim": True,
            "grounded": False,
            "evidence": f"tool_returned_error_but_wrap_claims_success: {error_results[:3]}",
            "template_leak": template_leak,
        }

    return {"has_action_claim": True, "grounded": True, "evidence": "tool_matched_action_claim", "template_leak": template_leak}


# --- proxy log loading ----------------------------------------------------

def parse_proxy_ts(s: str) -> dt.datetime | None:
    """Proxy 'ts' field is 'YYYYMMDDTHHMMSS_microsec' local-time (MST)."""
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
    """Given the ordered list of proxy records for one turn (iter 0..N
    of the agent loop), pull out a flat turn summary."""
    tool_calls = []
    final_wrap = ""
    total_latency_ms = 0.0
    total_pt = 0
    total_ct = 0
    iters = len(records)
    has_pass2_directive = False
    for r in records:
        total_latency_ms += float(r.get("upstream_latency_ms") or 0)
        resp = r.get("response") or {}
        usage = resp.get("usage") or {}
        total_pt += int(usage.get("prompt_tokens") or 0)
        total_ct += int(usage.get("completion_tokens") or 0)
        # OpenAI chat-completions schema: choices[0].message.{content, tool_calls}
        choices = resp.get("choices") or []
        msg = (choices[0].get("message") or {}) if choices else {}
        # Tool calls returned by this iteration
        for tc in msg.get("tool_calls") or []:
            fn = (tc.get("function") or {})
            tool_calls.append({
                "name": (fn.get("name") or "").lower(),
                "args": fn.get("arguments"),
                "result": None,
            })
        # Iteration N+1's request contains the previous iteration's tool_result
        # messages. We'll backfill 'result' on tool_calls by scanning request
        # messages of subsequent iterations.
        # Final wrap-up = last iteration's content field (when tool_call_count==0)
        if msg.get("content"):
            final_wrap = msg.get("content") or ""
        # Check if PASS2 directive ever appears in request (grounded mode sanity)
        for m in (r.get("request") or {}).get("messages") or []:
            if m.get("role") == "system" and "You have just received tool results" in (m.get("content") or ""):
                has_pass2_directive = True
    # Backfill tool_call results from subsequent request bodies
    # Each tool message in a request body has role=tool + tool_call_id + content
    flat_results: dict[str, str] = {}  # by tool_call_id
    flat_results_by_pos: list[str] = []
    for r in records:
        msgs = (r.get("request") or {}).get("messages") or []
        for m in msgs:
            if m.get("role") == "tool":
                tcid = m.get("tool_call_id", "")
                content = m.get("content", "")
                if tcid:
                    flat_results[tcid] = content
                flat_results_by_pos.append(content)
    # Reattach by best-effort name+order matching (good enough for our buckets)
    pos = 0
    for tc in tool_calls:
        if pos < len(flat_results_by_pos):
            tc["result"] = flat_results_by_pos[pos]
            pos += 1
    return {
        "iters": iters,
        "tool_calls": tool_calls,
        "wrap_up": final_wrap,
        "latency_ms_total": total_latency_ms,
        "tokens_prompt_total": total_pt,
        "tokens_completion_total": total_ct,
        "has_pass2_directive_visible": has_pass2_directive,
    }


# --- main ------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--metadata", required=True, type=Path)
    ap.add_argument("--proxy-dir", required=True, type=Path, action="append",
                    help="Can be specified multiple times for multi-day windows")
    ap.add_argument("--out-jsonl", required=True, type=Path)
    ap.add_argument("--out-md", required=True, type=Path)
    ap.add_argument("--window-s", type=float, default=90.0,
                    help="Match window after ts_sent")
    args = ap.parse_args()

    # Load metadata
    meta_records = []
    with args.metadata.open() as f:
        for L in f:
            L = L.strip()
            if L:
                meta_records.append(json.loads(L))
    print(f"metadata records: {len(meta_records)}")

    # Load proxy
    proxy = load_proxy_records(args.proxy_dir)
    print(f"proxy records (chip {CHIP_IP}): {len(proxy)}")

    # Index proxy by ts
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

        # Find proxy records inside [ts_sent, window_end]
        matched = [r for (t, r) in proxy_by_ts
                   if ts_sent <= t <= window_end]
        if not matched:
            turns.append({**m, "_no_proxy_match": True})
            continue

        turn = extract_turn_from_records(matched)
        cls = classify_turn(turn)

        turns.append({
            **m,
            "iters": turn["iters"],
            "tool_calls": turn["tool_calls"],
            "wrap_up": turn["wrap_up"],
            "latency_ms_total": turn["latency_ms_total"],
            "tokens_prompt_total": turn["tokens_prompt_total"],
            "tokens_completion_total": turn["tokens_completion_total"],
            "has_pass2_directive_visible": turn["has_pass2_directive_visible"],
            "has_action_claim": cls["has_action_claim"],
            "grounded": cls["grounded"],
            "evidence": cls["evidence"],
            "template_leak": cls.get("template_leak", False),
        })

    # Write per-turn jsonl
    args.out_jsonl.parent.mkdir(parents=True, exist_ok=True)
    with args.out_jsonl.open("w", encoding="utf-8") as f:
        for t in turns:
            f.write(json.dumps(t, ensure_ascii=False, default=str) + "\n")
    print(f"wrote {args.out_jsonl} ({len(turns)} turns)")

    # Aggregate report
    def agg(rows, *, bucket=None, mode=None):
        rows = [r for r in rows
                if (bucket is None or r.get("bucket") == bucket)
                and (mode is None or r.get("mode") == mode)
                and not r.get("_no_proxy_match")]
        n = len(rows)
        if n == 0:
            return None
        action_claim_count = sum(1 for r in rows if r.get("has_action_claim"))
        ungrounded_count = sum(1 for r in rows if r.get("has_action_claim") and not r.get("grounded"))
        template_leak_count = sum(1 for r in rows if r.get("template_leak"))
        latencies = [r.get("latency_ms_total", 0) for r in rows]
        prompt_tokens = [r.get("tokens_prompt_total", 0) for r in rows]
        completion_tokens = [r.get("tokens_completion_total", 0) for r in rows]
        return {
            "n": n,
            "action_claim_rate": action_claim_count / n,
            "ungrounded_action_claim_rate": ungrounded_count / n,
            "ungrounded_among_action_claims": (ungrounded_count / action_claim_count) if action_claim_count else 0,
            "template_leak_rate": template_leak_count / n,
            "latency_ms_median": sorted(latencies)[n // 2] if n else 0,
            "latency_ms_mean": sum(latencies) / n if n else 0,
            "prompt_tokens_mean": sum(prompt_tokens) / n if n else 0,
            "completion_tokens_mean": sum(completion_tokens) / n if n else 0,
        }

    # Sanity: directive visibility on grounded mode
    grounded_rows = [t for t in turns if t.get("mode") == "grounded" and not t.get("_no_proxy_match")]
    g_w_directive = sum(1 for t in grounded_rows if t.get("has_pass2_directive_visible"))
    no_match = sum(1 for t in turns if t.get("_no_proxy_match"))

    # Build report
    md = []
    md.append(f"# Phase 4.3.0.F — A/B validation: speculative vs grounded\n")
    md.append(f"**Chip:** c6-01 (192.168.1.19)  ·  **Model:** wireclaw-agent:v1.3.1  ·  **Firmware:** 3f15cc15 (4.3.0.C build on phase-4.3.0-two-pass-inference branch)\n")
    md.append(f"**Prompts:** {len(set((t.get('prompt_id') or '') for t in turns))} prompts × 5 runs × 2 modes = {len(turns)} total turns\n")
    md.append(f"**Proxy-match rate:** {(len(turns)-no_match)/len(turns)*100:.1f}% ({len(turns)-no_match}/{len(turns)})  · _no-match runs excluded from aggregates_\n")
    md.append(f"**Grounded-mode directive visibility (sanity):** {g_w_directive}/{len(grounded_rows)} turns show PASS2_DIRECTIVE in proxy request body\n\n")

    md.append("## Headline\n")
    overall_spec = agg(turns, mode="speculative")
    overall_grnd = agg(turns, mode="grounded")
    if overall_spec and overall_grnd:
        delta = overall_grnd["ungrounded_action_claim_rate"] - overall_spec["ungrounded_action_claim_rate"]
        md.append(f"| metric | speculative | grounded | Δ |\n")
        md.append(f"|---|---:|---:|---:|\n")
        md.append(f"| n turns | {overall_spec['n']} | {overall_grnd['n']} | |\n")
        md.append(f"| Action-claim rate | {overall_spec['action_claim_rate']*100:.1f}% | {overall_grnd['action_claim_rate']*100:.1f}% | |\n")
        md.append(f"| **Ungrounded action-claim rate** | **{overall_spec['ungrounded_action_claim_rate']*100:.1f}%** | **{overall_grnd['ungrounded_action_claim_rate']*100:.1f}%** | **{delta*100:+.1f}pp** |\n")
        md.append(f"| Ungrounded among action-claims | {overall_spec['ungrounded_among_action_claims']*100:.1f}% | {overall_grnd['ungrounded_among_action_claims']*100:.1f}% | |\n")
        tl_delta = overall_grnd['template_leak_rate'] - overall_spec['template_leak_rate']
        md.append(f"| **Template-token leak rate (NEW)** | {overall_spec['template_leak_rate']*100:.1f}% | **{overall_grnd['template_leak_rate']*100:.1f}%** | **{tl_delta*100:+.1f}pp** |\n")
        md.append(f"| Median latency | {overall_spec['latency_ms_median']:.0f}ms | {overall_grnd['latency_ms_median']:.0f}ms | |\n")
        md.append(f"| Mean prompt tokens | {overall_spec['prompt_tokens_mean']:.0f} | {overall_grnd['prompt_tokens_mean']:.0f} | |\n")
        md.append(f"| Mean completion tokens | {overall_spec['completion_tokens_mean']:.0f} | {overall_grnd['completion_tokens_mean']:.0f} | |\n")

    md.append("\n## Per-bucket comparison\n")
    md.append("Action-claim grounding rate = fraction of turns with an action claim where that claim was backed by a matching successful tool_result.\n\n")
    md.append("| bucket | spec n | grounded n | spec ungrounded% | grnd ungrounded% | Δ pp |\n")
    md.append("|---|---:|---:|---:|---:|---:|\n")
    for b in ("A", "A'", "B", "C"):
        s = agg(turns, bucket=b, mode="speculative")
        g = agg(turns, bucket=b, mode="grounded")
        if s and g:
            md.append(f"| {b} | {s['n']} | {g['n']} | {s['ungrounded_action_claim_rate']*100:.1f}% | {g['ungrounded_action_claim_rate']*100:.1f}% | {(g['ungrounded_action_claim_rate']-s['ungrounded_action_claim_rate'])*100:+.1f} |\n")

    md.append("\n## Latency + token deltas\n")
    md.append("| metric | spec | grounded | Δ |\n")
    md.append("|---|---:|---:|---:|\n")
    if overall_spec and overall_grnd:
        md.append(f"| Mean latency total ms | {overall_spec['latency_ms_mean']:.0f} | {overall_grnd['latency_ms_mean']:.0f} | {overall_grnd['latency_ms_mean']-overall_spec['latency_ms_mean']:+.0f}ms |\n")
        md.append(f"| Mean prompt tokens | {overall_spec['prompt_tokens_mean']:.0f} | {overall_grnd['prompt_tokens_mean']:.0f} | {overall_grnd['prompt_tokens_mean']-overall_spec['prompt_tokens_mean']:+.0f} |\n")
        md.append(f"| Mean completion tokens | {overall_spec['completion_tokens_mean']:.0f} | {overall_grnd['completion_tokens_mean']:.0f} | {overall_grnd['completion_tokens_mean']-overall_spec['completion_tokens_mean']:+.0f} |\n")

    md.append("\n## Same-prompt before/after (3 illustrative pairs per bucket)\n")
    by_prompt = defaultdict(lambda: {"speculative": [], "grounded": []})
    for t in turns:
        if t.get("_no_proxy_match"):
            continue
        by_prompt[t["prompt_id"]][t["mode"]].append(t)
    shown_per_bucket = defaultdict(int)
    for pid, modes in by_prompt.items():
        if not (modes["speculative"] and modes["grounded"]):
            continue
        bucket = modes["speculative"][0].get("bucket", "?")
        if shown_per_bucket[bucket] >= 3:
            continue
        shown_per_bucket[bucket] += 1
        md.append(f"\n### {pid} — bucket {bucket}\n")
        md.append(f"Prompt: `{modes['speculative'][0].get('reply_preview','')[:0] or ''}`\n")
        # The prompt isn't in metadata, just the preview... we have to look it up
        # Skip the per-run breakdown to keep the report short.
        for mode in ("speculative", "grounded"):
            md.append(f"\n**{mode} (n={len(modes[mode])}):**\n")
            for r in modes[mode][:5]:
                gtag = "✓" if r.get("grounded") else ("✗" if r.get("has_action_claim") else "·")
                wrap = (r.get("wrap_up") or "")[:140].replace("\n", " ")
                md.append(f"- {gtag} run {r.get('run_num')}: {wrap!r}\n")

    args.out_md.write_text("".join(md), encoding="utf-8")
    print(f"wrote {args.out_md}")


if __name__ == "__main__":
    main()
