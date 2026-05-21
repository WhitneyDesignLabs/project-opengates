#!/usr/bin/env python3
"""Phase 4.2.1.I deeper analysis: per-chip variance, fabrication-cause
breakdown, memory-chain detector sanity check, sample failures by class."""
import json, random, re
from collections import Counter, defaultdict
from pathlib import Path

random.seed(42)

P = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus-labels/v1.3.1-overnight-2026-05-20.labeled.jsonl")

turns = []
with P.open(encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if line:
            turns.append(json.loads(line))
print(f"loaded {len(turns)} labeled turns\n")

# ---- per-chip × label distribution ----
print("=== per-chip label distribution ===")
chip_label = defaultdict(Counter)
for t in turns:
    chip_label[t["chip"]][t["final_label"] or "?"] += 1
chips = sorted(chip_label)
labels = ["clean", "pseudo-prose", "fabricated", "contradictory", "null", "?"]
print(f"  {'chip':6s}  {'N':>5s}  " + "  ".join(f"{l:>14s}" for l in labels[:4]))
for chip in chips:
    c = chip_label[chip]
    n = sum(c.values())
    print(f"  {chip:6s}  {n:>5d}  " + "  ".join(f"{c.get(l,0)/n*100:5.1f}% ({c.get(l,0):4d})" for l in labels[:4]))

# ---- per-chip flag rates ----
print("\n=== per-chip flag rates ===")
flags = ["v13_led_indirect_reference_bug", "v13_reasoning_trace_leak",
         "v13_memory_chain_correct", "v131_fabricated_state_claim"]
short = {"v13_led_indirect_reference_bug": "led_bug",
         "v13_reasoning_trace_leak":       "leak",
         "v13_memory_chain_correct":       "mem_ok",
         "v131_fabricated_state_claim":    "fab_state"}
print(f"  {'chip':6s}  " + "  ".join(f"{short[f]:>9s}" for f in flags))
for chip in chips:
    ts = [t for t in turns if t["chip"] == chip]
    n = len(ts)
    cells = []
    for f in flags:
        hits = sum(1 for t in ts if t.get(f))
        cells.append(f"{hits/n*100:5.1f}%")
    print(f"  {chip:6s}  " + "  ".join(f"{c:>9s}" for c in cells))

# ---- fabrication-cause breakdown ----
# Bucket fabricated turns by what's likely driving the label.
print("\n=== fabricated-turn cause breakdown ===")
fabs = [t for t in turns if t.get("final_label") == "fabricated"]
print(f"total fabricated turns: {len(fabs)}")
no_tool   = [t for t in fabs if not (t.get("tool_calls_fired") or [])]
yes_tool  = [t for t in fabs if (t.get("tool_calls_fired") or [])]
print(f"  fabricated WITHOUT any tool call fired: {len(no_tool)} ({len(no_tool)/len(fabs)*100:.1f}%)")
print(f"  fabricated WITH some tool call fired:   {len(yes_tool)} ({len(yes_tool)/len(fabs)*100:.1f}%)")
# Of no_tool, what % are state claims vs action claims?
state_in_notool = sum(1 for t in no_tool if t.get("v131_fabricated_state_claim"))
print(f"    of those WITHOUT tool, state_claim-flagged: {state_in_notool} ({state_in_notool/max(len(no_tool),1)*100:.1f}%)")
print(f"    of those WITHOUT tool, NOT state-flagged:   {len(no_tool)-state_in_notool} (likely action claims)")

# ---- memory-chain detector sanity ----
print("\n=== memory_chain_correct detector sanity ===")
# Find turns where prompt mentions indirect color / favorite / memory.
indirect_re = re.compile(r"(favorite|memory|remember|that\s+color|the\s+color\s+we|my\s+color)", re.I)
candidates = [t for t in turns if indirect_re.search(t.get("prompt") or "")]
print(f"  candidate turns (prompt mentions indirect-ref or memory): {len(candidates)}")
# Of those, how many fired file_read /memory.txt?
file_read_mem = 0
for t in candidates:
    for tc in (t.get("tool_calls_fired") or []):
        if isinstance(tc, dict):
            fn = (tc.get("function") or tc.get("name") or "").lower()
            args_str = json.dumps(tc.get("arguments") or {})
            if fn == "file_read" and "/memory.txt" in args_str:
                file_read_mem += 1
                break
print(f"  candidates where file_read /memory.txt fired: {file_read_mem} ({file_read_mem/max(len(candidates),1)*100:.1f}%)")
# What's after file_read?
print(f"\n  3 sample candidate turns where file_read /memory.txt fired (regardless of detector flag):")
shown = 0
for t in candidates:
    tcs = t.get("tool_calls_fired") or []
    if not any(isinstance(tc, dict) and (tc.get("function") or tc.get("name") or "").lower() == "file_read"
               and "/memory.txt" in json.dumps(tc.get("arguments") or {}) for tc in tcs):
        continue
    print(f"    chip={t['chip']} persona={t.get('persona')} session={t.get('session_seq')}")
    print(f"      prompt: {(t.get('prompt') or '')[:80]!r}")
    print(f"      tools fired: {[(tc.get('function') or tc.get('name'), tc.get('arguments')) for tc in tcs if isinstance(tc, dict)]}")
    print(f"      memory_chain_correct flag: {t.get('v13_memory_chain_correct')} ({t.get('v13_memory_evidence')})")
    print(f"      wrap_up: {(t.get('wrap_up_text') or '')[:120]!r}")
    shown += 1
    if shown >= 3:
        break

# ---- sample 3 turns each: clean, fabricated-without-tool, fabricated-state-claim ----
print("\n=== 3 samples: clean ===")
for t in random.sample([t for t in turns if t.get("final_label") == "clean"], 3):
    print(f"  chip={t['chip']} persona={t.get('persona')}")
    print(f"    prompt : {(t.get('prompt') or '')[:80]!r}")
    print(f"    reply  : {(t.get('wrap_up_text') or '')[:140]!r}")
    print(f"    tools  : {[ (tc.get('function') or tc.get('name')) for tc in (t.get('tool_calls_fired') or []) if isinstance(tc, dict)]}")

print("\n=== 3 samples: fabricated, no tool fired ===")
for t in random.sample(no_tool, 3):
    print(f"  chip={t['chip']} persona={t.get('persona')}")
    print(f"    prompt : {(t.get('prompt') or '')[:80]!r}")
    print(f"    reply  : {(t.get('wrap_up_text') or '')[:140]!r}")
    print(f"    state-claim flag: {t.get('v131_fabricated_state_claim')}")

print("\n=== 3 samples: fabricated_state_claim hits ===")
state_hits = [t for t in turns if t.get("v131_fabricated_state_claim")]
for t in random.sample(state_hits, min(3, len(state_hits))):
    print(f"  chip={t['chip']} persona={t.get('persona')}")
    print(f"    prompt : {(t.get('prompt') or '')[:80]!r}")
    print(f"    reply  : {(t.get('wrap_up_text') or '')[:140]!r}")
    print(f"    evidence: {t.get('v131_fabricated_state_evidence')}")
