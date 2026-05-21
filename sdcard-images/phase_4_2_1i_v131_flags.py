#!/usr/bin/env python3
"""Phase 4.2.1.I.5 flag enrichment for v1.3.1 overnight corpus.

Builds on phase_4_1_4a_v13_flags.py adding the NEW `fabricated_state_claim`
flag per Scott's 2026-05-20 5:13–5:30 PM probe: turns where the model
claims a specific verifiable system state (memory contents, GPIO state,
file content, WiFi SSID, exact heap bytes, etc.) WITHOUT having fired the
relevant tool to retrieve it.

This is a deterministic enrichment layered on top of Haiku's 4-class
labels. fabricated_state_claim is a SUBSET of the broader `fabricated`
class — specifically the subset that's relevant to the HA Tier 1
deciding-number (state-grounding fidelity).

INPUT:
  --input  v1.3.1-overnight-2026-05-20.input.json   (source corpus with prompts/tools/wrap-ups)
  --haiku  v1.3.1-overnight-2026-05-20.haiku.json   (Haiku-labeled output)
OUTPUT:
  --out    v1.3.1-overnight-2026-05-20.labeled.jsonl
"""
import json, re, sys, argparse
from pathlib import Path

# Pull in the v1.1 flag detectors verbatim — they already cover
# led_indirect_reference_bug / reasoning_trace_leak / memory_chain_correct.
HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
from phase_4_1_4a_v13_flags import (  # noqa: E402
    is_led_indirect_reference_bug,
    is_reasoning_trace_leak,
    is_memory_chain_correct,
    tool_name,
    tool_args,
)

# ------- NEW: fabricated_state_claim detection -------
#
# A wrap-up that claims a specific verifiable state value (numeric reading,
# named file contents, GPIO HIGH/LOW, named WiFi SSID, exact memory value)
# WITHOUT the relevant retrieval tool having fired.
#
# Detection has two parts:
#   1. State-claim pattern in wrap-up text (positive signal).
#   2. Required-tool absence in tool_calls_fired (negative signal).
#
# Each (claim-pattern, required-tool-name-set) pair is one rule. If the
# claim pattern matches AND none of the required tools fired, flag it.

# (claim_regex, set_of_required_tools_that_would_retrieve_this_state)
STATE_CLAIM_RULES = [
    # GPIO state claims: "GPIO N is HIGH", "pin N is LOW", "state of pin N", etc.
    (re.compile(r"\bgpio\s*\d+\s*(is|reads?)\s+(high|low|on|off|\d)\b", re.I),
     {"gpio_read"}),
    (re.compile(r"\b(state\s+of\s+(all\s+)?gpio|gpio[s]?\s+state[s]?\s+(are|is))\b", re.I),
     {"gpio_read"}),
    # File content claims: "the file contains", "memory.txt says", "/X holds"
    (re.compile(r"\b(file\s+(contains|holds|stores|says)|/memory\.txt\s+(contains|holds|says|stores))\b", re.I),
     {"file_read"}),
    (re.compile(r"\b(your\s+memory\s+(contains|holds|stores|has))\b", re.I),
     {"file_read"}),
    # Heap/memory metric claims: "X bytes free", "uptime is N", "free heap"
    (re.compile(r"\b\d{3,}\s*bytes\s+(free|available|used)\b", re.I),
     {"status_read", "heap_status", "device_status", "system_status"}),
    (re.compile(r"\buptime\s+(is|of)\s+\d", re.I),
     {"status_read", "device_status", "system_status"}),
    (re.compile(r"\bfree\s+heap\s+(memory\s+)?(is|of)?\s*\d", re.I),
     {"status_read", "heap_status", "device_status", "system_status"}),
    # WiFi state claims: "connected to <SSID>", "WiFi network is X"
    (re.compile(r"\b(connected\s+to\s+[\"']?[a-z0-9_\-]+|wifi\s+(network|ssid)\s+is\s+[\"']?[a-z0-9_\-]+)\b", re.I),
     {"wifi_status", "status_read", "device_status"}),
    # Temperature with specific value: "X.Y degrees" / "current temp is N"
    (re.compile(r"\b\d+\.\d+\s+degrees?\b", re.I),
     {"temperature_read", "sensor_read", "adc_read"}),
    (re.compile(r"\b(current|chip|sensor)\s+temperature\s+(is|reads|of)\s+\d", re.I),
     {"temperature_read", "sensor_read", "adc_read"}),
    # Device/rule list claims: "you have N devices", "the rules are"
    (re.compile(r"\b(your\s+(currently\s+)?registered\s+(devices|rules)\s+(are|include))\b", re.I),
     {"device_list", "rule_list"}),
    # ADC raw value claim: "raw ADC value of N", "ADC returned N"
    (re.compile(r"\b(raw\s+adc|adc\s+(value|returned|reading))\s+(of|is|was)?\s*\d", re.I),
     {"adc_read", "sensor_read"}),
]


def fired_tool_names(conv: dict) -> set:
    tcs = conv.get("tool_calls_fired") or []
    return {tool_name(tc) for tc in tcs if tool_name(tc)}


def is_fabricated_state_claim(conv: dict) -> tuple[bool, str]:
    """Return (True, evidence-string) if the wrap-up makes a specific
    state claim without the relevant retrieval tool firing.

    Note: this is intentionally NOT the union of all `fabricated` labels —
    it's a sharper sub-pattern. Some Haiku-labeled fabrications won't
    match (e.g., "rule deletion was successful" without rule_delete fired
    is a fabricated *action*, not a fabricated *state*). We measure both
    in the report: full fabricated rate (Haiku) + state-claim sub-rate.
    """
    wrap = conv.get("wrap_up_text") or ""
    if not wrap.strip():
        return False, ""
    fired = fired_tool_names(conv)
    for pat, required_set in STATE_CLAIM_RULES:
        m = pat.search(wrap)
        if not m:
            continue
        # Did any of the required-set tools fire?
        if fired & required_set:
            continue  # Tool fired — state claim is grounded, not fabricated.
        return True, f"claim={m.group(0)[:60]!r} but none of {sorted(required_set)} fired (fired={sorted(fired) or ['(none)']})"
    return False, ""


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--input", type=Path, required=True)
    ap.add_argument("--haiku", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    inp = json.loads(args.input.read_text(encoding="utf-8"))
    convs = inp.get("conversations", [])
    haiku = json.loads(args.haiku.read_text(encoding="utf-8"))
    recs = haiku.get("records", [])

    by_id = {r["id"]: r for r in recs}
    merged = []
    flag_counts = {"led_indirect_reference_bug": 0,
                   "reasoning_trace_leak": 0,
                   "memory_chain_correct": 0,
                   "fabricated_state_claim": 0}
    for c in convs:
        cid = c.get("id", "")
        label_rec = by_id.get(cid, {})
        led_bug, led_why = is_led_indirect_reference_bug(c)
        leak, leak_why = is_reasoning_trace_leak(c)
        mem_ok, mem_why = is_memory_chain_correct(c)
        fab_state, fab_why = is_fabricated_state_claim(c)
        if led_bug: flag_counts["led_indirect_reference_bug"] += 1
        if leak: flag_counts["reasoning_trace_leak"] += 1
        if mem_ok: flag_counts["memory_chain_correct"] += 1
        if fab_state: flag_counts["fabricated_state_claim"] += 1
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
            "v131_fabricated_state_claim": fab_state,
            "v131_fabricated_state_evidence": fab_why,
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
