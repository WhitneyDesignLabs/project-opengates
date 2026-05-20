#!/usr/bin/env python3
"""Phase 4.1.4a Step 3 prep: convert the v1.1 REPAIRED JSONL into the
shape wrap_up_classify.py expects (a single JSON file with a
`conversations` list), and print a cost-estimate sanity check.
"""
import json
import sys
from pathlib import Path

SRC = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus/v1.1-overnight-2026-05-18.REPAIRED.jsonl")
DST = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus-labels/v1.1-overnight-2026-05-18.input.json")

conversations = []
for ln in SRC.read_text(encoding="utf-8").splitlines():
    if not ln.strip():
        continue
    conversations.append(json.loads(ln))

DST.parent.mkdir(parents=True, exist_ok=True)
DST.write_text(json.dumps({
    "source": str(SRC),
    "phase": "4.1.4a",
    "conversations": conversations,
}, indent=2))

# Cost-estimate: rough per-turn token sum (prompt + tool calls + tool results + wrap_up)
# Haiku 4.5 pricing 2026: input ~ $1/M tokens, output ~ $5/M tokens.
total_in = total_out_est = 0
for c in conversations:
    text = (c.get("prompt") or "") + (c.get("wrap_up_text") or "")
    for tc in c.get("tool_calls_fired") or []:
        text += json.dumps(tc, default=str)
    for tr in c.get("tool_results") or []:
        text += str(tr)
    # crude chars→tokens approximation: 4 chars/token
    total_in += len(text) // 4 + 400  # +400 for the judge system prompt overhead
    total_out_est += 80               # rough output token budget per call
print(f"converted {len(conversations)} conversations -> {DST}")
print(f"crude input token est: {total_in:,}")
print(f"crude output token est: {total_out_est:,}")
print(f"crude Haiku 4.5 cost est (input $1/M + output $5/M): "
      f"${total_in/1_000_000 + total_out_est*5/1_000_000:.2f}")
print("(this is an upper-bound order-of-magnitude — Haiku pricing 2026, recheck w/ actuals)")
