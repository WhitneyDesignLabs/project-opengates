#!/usr/bin/env python3
"""Phase 4.4.0.0.3 — probe whether `/clear` history-bleed is real.

Picks the ab_28_C control-arm run 1 turn (the one that fabricated "deep
purple" despite "Set the LED to red." being the prompt), opens its first
proxy capture, and inspects the messages list. If the chip sent history
beyond just [system, user="Set the LED to red."], then `/clear` did not
flush before this turn.
"""
import json, glob, os, sys, datetime as dt

META = "/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/eval/results-4.3.0.H/metadata.jsonl"
PROXY_DIR = "/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/eval/results-4.3.0.H/proxy-2026-05-22/"

meta = [json.loads(l) for l in open(META) if l.strip()]

# Pick a few interesting cases to inspect
targets = [
    {"prompt_id": "ab_28_C", "arm": "control",   "run_num": 1, "expected_prompt": "Set the LED to red."},
    {"prompt_id": "ab_28_C", "arm": "control",   "run_num": 2, "expected_prompt": "Set the LED to red."},
    {"prompt_id": "ab_28_C", "arm": "treatment", "run_num": 1, "expected_prompt": "Set the LED to red."},
    {"prompt_id": "ab_01_A", "arm": "control",   "run_num": 1, "expected_prompt": "Same as before, please."},
]

for t in targets:
    print("=" * 80)
    print(f"TARGET: prompt_id={t['prompt_id']} arm={t['arm']} run={t['run_num']}")
    m = next((r for r in meta if r["prompt_id"]==t["prompt_id"] and r["arm"]==t["arm"] and r["run_num"]==t["run_num"]), None)
    if not m:
        print("  no metadata match"); continue

    print(f"  reply preview: {m.get('reply_preview', '')[:120]!r}")
    ts = dt.datetime.fromisoformat(m["ts_sent_iso"])
    ts_pt = ts.astimezone(dt.timezone(dt.timedelta(hours=-7)))
    candidates = []
    for f in sorted(os.listdir(PROXY_DIR)):
        if "192.168.1.19_" not in f:
            continue
        fts_head = f.split("192.168.1.19_")[1].split("_")[0]
        try:
            fts = dt.datetime.strptime(fts_head, "%Y%m%dT%H%M%S").replace(
                tzinfo=dt.timezone(dt.timedelta(hours=-7)))
            if 0 <= (fts - ts_pt).total_seconds() <= 90:
                candidates.append(f)
        except Exception:
            pass
    print(f"  matched proxy captures (iters): {len(candidates)}")
    if not candidates:
        continue
    first = PROXY_DIR + candidates[0]
    print(f"  iter-0 capture: {candidates[0]}")
    d = json.load(open(first))
    req = d.get("request", d)
    msgs = req.get("messages", [])
    roles = [mm.get("role") for mm in msgs]
    print(f"  iter-0 messages count: {len(msgs)}  roles: {roles}")
    # Print the user messages — these reveal whether prior prompts bled through
    user_msgs = [mm for mm in msgs if mm.get("role") == "user"]
    print(f"  user messages: {len(user_msgs)}")
    for i, um in enumerate(user_msgs):
        c = (um.get("content") or "").replace("\n", " | ")
        print(f"    [u{i}] {c[:140]!r}")
    # Also print the first 200 chars of any prior assistant content for context
    assist_msgs = [mm for mm in msgs if mm.get("role") == "assistant"]
    for i, am in enumerate(assist_msgs):
        c = (am.get("content") or "")
        if c:
            c = c.replace("\n", " | ")
            print(f"    [a{i}] content: {c[:140]!r}")
    print()
