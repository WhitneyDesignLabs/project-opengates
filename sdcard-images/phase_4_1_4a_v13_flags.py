#!/usr/bin/env python3
"""Phase 4.1.4a Step 3c: enrich Haiku-labeled records with three v1.3
target-failure-mode boolean flags. Deterministic checks (no extra API
spend); merges with the canonical {summary, records} output of
wrap_up_classify.py.

Flags:
  led_indirect_reference_bug — indirect-color prompt + wrap-up claims
    success + led_set did NOT fire OR fired with empty/default args
  reasoning_trace_leak — wrap-up exposes internal monologue markers
  memory_chain_correct — file_read('/memory.txt') fired then a
    follow-on tool used the value (positive signal)

INPUT:
  labeled .json (wrap_up_classify.py output) at corpus-labels/.haiku.json
  input .json (the source corpus with prompts/tools/wrap-ups)
OUTPUT:
  v1.1-overnight-2026-05-18.labeled.jsonl (per-turn JSONL with labels +
  flags + per-record metadata) at corpus-labels/
"""
import json, re, sys, argparse
from pathlib import Path

# ------- indirect-color prompt patterns -------
INDIRECT_COLOR_RE = re.compile(
    r"\b(my\s+favorite\s+color|favorite\s+color|"
    r"my\s+color|the\s+color\s+i|that\s+color|"
    r"my\s+chosen\s+color|the\s+color\s+we\s+(talked|agreed|set)|"
    r"set\s+(it|the\s+led)\s+to\s+(my|that|the)\s+(favorite|color))",
    re.IGNORECASE,
)

# ------- LED success-claim phrases in wrap-up -------
LED_SUCCESS_RE = re.compile(
    r"\b(led\s+(is|has\s+been|was)\s+(now|set\s+to|now\s+set\s+to)|"
    r"led\s+(is|has\s+been|now)\s+\w+|"
    r"set\s+the\s+led\s+to|"
    r"led\s+color\s+(is|has)|"
    r"i('ve|\s+have)\s+set\s+the\s+led|"
    r"led\s+is\s+now)\b",
    re.IGNORECASE,
)

# ------- reasoning-trace-leak markers -------
# These must be in the WRAP-UP (visible to user), not internal logs.
REASONING_LEAK_PATTERNS = [
    re.compile(r"\bi\s+should\s+have\b", re.I),
    re.compile(r"\b(let\s+me|i\s+will|i'll|now\s+i'll|i\s+need\s+to)\s+try\s+(a\s+)?different\b", re.I),
    re.compile(r"\bthe\s+tool\s+call\s+was\s+(wrong|incorrect|missing)\b", re.I),
    re.compile(r"\b(i'll|i\s+will|let\s+me)\s+respond\s+in\s+plain\s+english\b", re.I),
    re.compile(r"\b(i\s+should|i'll)\s+(call|invoke|use)\s+the\s+\w+\s+tool\s+instead\b", re.I),
    re.compile(r"\bwait,?\s+(let\s+me|i\s+need|that's\s+not)\b", re.I),
    re.compile(r"\bactually,?\s+(i|let\s+me|the)\b", re.I),
    re.compile(r"\bsince\s+(you\s+asked|i\s+called|the\s+tool)\b.+(i\s+(called|will|should|need)|let\s+me|let's)", re.I),
    re.compile(r"\bsorry,?\s+the\s+model\s+responded\s+incorrectly\b", re.I),
    re.compile(r"\b(i'll|i\s+will)\s+(now\s+)?(pass|forward|return)\s+(the|this|that)\s+(error|result|response)\s+to\s+the\s+user\b", re.I),
    re.compile(r"\bi'll\s+(respond|reply|answer)\s+(naturally|to\s+the\s+user|in\s+plain)", re.I),
    re.compile(r"\b(my\s+previous|the\s+previous)\s+(response|answer|attempt)\s+(was|is)\b", re.I),
    re.compile(r"\b\[tools?\s+executed,?\s+no\s+text\s+response\]\b", re.I),  # chip-side scaffold leaking
]

MEMORY_PATH_RE = re.compile(r"/memory\.txt", re.IGNORECASE)


def tool_name(tc):
    """Return lowercased function name from a tool_calls_fired record."""
    if not isinstance(tc, dict):
        return ""
    return (tc.get("function") or tc.get("name") or "").lower()


def tool_args(tc):
    """Return the args dict from a tool_calls_fired record (best-effort)."""
    if not isinstance(tc, dict):
        return {}
    a = tc.get("arguments")
    if not a:
        a = tc.get("arguments_after_chip_parser")
    if isinstance(a, str):
        try:
            a = json.loads(a)
        except Exception:
            return {}
    return a if isinstance(a, dict) else {}


def is_led_indirect_reference_bug(conv: dict) -> tuple[bool, str]:
    """Indirect-color prompt + wrap-up claims success + led_set fires
    poorly (absent / empty args / default off-args)."""
    prompt = conv.get("prompt") or ""
    wrap = conv.get("wrap_up_text") or ""
    tool_calls = conv.get("tool_calls_fired") or []
    if not INDIRECT_COLOR_RE.search(prompt):
        return False, "no-indirect-color-prompt"
    if not LED_SUCCESS_RE.search(wrap):
        # Wrap-up doesn't claim LED action -> not the bug we're targeting.
        return False, "no-led-success-claim"
    led_calls = [tc for tc in tool_calls if tool_name(tc) == "led_set"]
    if not led_calls:
        return True, "led_set absent despite success claim"
    for tc in led_calls:
        args = tool_args(tc)
        if not args:
            return True, "led_set fired with empty/missing arguments"
        r, g, b = args.get("r"), args.get("g"), args.get("b")
        if r == 0 and g == 0 and b == 0:
            return True, "led_set fired with off-state (0,0,0) when prompt requested favorite color"
    return False, "led_set fired with non-default args"


def is_reasoning_trace_leak(conv: dict) -> tuple[bool, str]:
    wrap = conv.get("wrap_up_text") or ""
    for pat in REASONING_LEAK_PATTERNS:
        m = pat.search(wrap)
        if m:
            return True, f"matched: '{m.group(0)[:60]}'"
    return False, ""


def is_memory_chain_correct(conv: dict) -> tuple[bool, str]:
    """file_read('/memory.txt') fired first, a follow-on tool fired
    after with non-empty args, wrap-up mentions a non-trivial value."""
    tcs = conv.get("tool_calls_fired") or []
    if not tcs:
        return False, "no tools"
    mem_idx = -1
    for i, tc in enumerate(tcs):
        if tool_name(tc) == "file_read" and MEMORY_PATH_RE.search(json.dumps(tool_args(tc))):
            mem_idx = i
            break
    if mem_idx < 0:
        return False, "no file_read /memory.txt"
    # Look for a follow-on tool AFTER file_read with non-empty args.
    for tc in tcs[mem_idx + 1:]:
        if tool_name(tc) in ("file_read",):
            continue  # another read, not a use
        if tool_args(tc):
            return True, f"file_read /memory.txt then {tool_name(tc)} with non-empty args"
    return False, "file_read /memory.txt but no follow-on use-tool"


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--input", type=Path, required=True,
                    help="Source corpus JSON (with `conversations` list).")
    ap.add_argument("--haiku", type=Path, required=True,
                    help="Haiku-labeled output JSON (with `records`).")
    ap.add_argument("--out", type=Path, required=True,
                    help="Output JSONL with per-turn label + flags merged.")
    args = ap.parse_args()

    inp = json.loads(args.input.read_text(encoding="utf-8"))
    convs = inp.get("conversations", [])
    haiku = json.loads(args.haiku.read_text(encoding="utf-8"))
    recs = haiku.get("records", [])

    by_id = {r["id"]: r for r in recs}
    merged = []
    flag_counts = {"led_indirect_reference_bug": 0,
                   "reasoning_trace_leak": 0,
                   "memory_chain_correct": 0}
    for c in convs:
        cid = c.get("id", "")
        label_rec = by_id.get(cid, {})
        led_bug, led_why = is_led_indirect_reference_bug(c)
        leak, leak_why = is_reasoning_trace_leak(c)
        mem_ok, mem_why = is_memory_chain_correct(c)
        if led_bug: flag_counts["led_indirect_reference_bug"] += 1
        if leak: flag_counts["reasoning_trace_leak"] += 1
        if mem_ok: flag_counts["memory_chain_correct"] += 1
        merged.append({
            "id": cid,
            "chip": c.get("_chip"),
            "persona": c.get("_persona_name"),
            "session_seq": c.get("_session_seq"),
            "prompt": c.get("prompt"),
            "wrap_up_text": c.get("wrap_up_text"),
            "tool_calls_fired": c.get("tool_calls_fired"),
            "tool_results": c.get("tool_results"),
            "deterministic_label": label_rec.get("deterministic_label"),
            "deterministic_evidence": label_rec.get("deterministic_evidence"),
            "haiku_label": label_rec.get("haiku_label"),
            "haiku_confidence": label_rec.get("haiku_confidence"),
            "haiku_rationale": label_rec.get("haiku_rationale"),
            "final_label": label_rec.get("final_label"),
            "v13_led_indirect_reference_bug": led_bug,
            "v13_led_evidence": led_why,
            "v13_reasoning_trace_leak": leak,
            "v13_leak_evidence": leak_why,
            "v13_memory_chain_correct": mem_ok,
            "v13_memory_evidence": mem_why,
        })

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8") as fh:
        for m in merged:
            fh.write(json.dumps(m, ensure_ascii=False, default=str) + "\n")
    print(f"wrote {len(merged)} merged records to {args.out}")
    print(f"flag counts: {flag_counts}")
    label_counts = {}
    for m in merged:
        label_counts[m["final_label"]] = label_counts.get(m["final_label"], 0) + 1
    print(f"final_label distribution: {label_counts}")


if __name__ == "__main__":
    main()
