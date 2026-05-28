#!/usr/bin/env python3
"""Spot-check v1.3.2 corrective records — 1k action-claim-trap (the most
important sub-bucket) + one 1b negative + one 3a refusal."""
import json
recs = [json.loads(l) for l in open(
    "/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/training-data/wireclaw-v1.3.2-corrective.jsonl")]
print(f"total: {len(recs)}")
print()

def show(r):
    print(f"=== {r['id']} ({r['subtype']}) — color={r.get('color', '-')} — {r['principle_exercised']} ===")
    print(f"comment: {r.get('comment', '')[:120]}")
    for i, m in enumerate(r["messages"]):
        role = m["role"]
        if role == "system":
            print(f"  [{i}] system content (SOUL-LOCAL, {len(m['content'])} chars)")
            continue
        content = (m.get("content") or "").replace("\n", " / ")
        tc = m.get("tool_calls")
        if tc:
            fn = tc[0]["function"]
            print(f"  [{i}] {role} tool_calls={fn['name']}({fn['arguments']})  content={content[:60]!r}")
        else:
            print(f"  [{i}] {role} content={content[:200]!r}")
    print()

# Show first 1k_action_claim_trap, one 1b_led_color_negative, one 3a_real_wireclaw_unrestricted
shown = {"1k_action_claim_trap": 0, "1b_led_color_negative": 0, "3a_real_wireclaw_unrestricted": 0}
limit_per = {"1k_action_claim_trap": 2, "1b_led_color_negative": 1, "3a_real_wireclaw_unrestricted": 1}
for r in recs:
    sub = r["subtype"]
    if sub in shown and shown[sub] < limit_per[sub]:
        show(r)
        shown[sub] += 1
