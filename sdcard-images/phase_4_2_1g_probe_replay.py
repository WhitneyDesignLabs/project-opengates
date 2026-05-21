#!/usr/bin/env python3
"""Replay Scott's 2026-05-20 manual probe (5 mapped prompts) against v1.3.1."""
import json
from pathlib import Path

RESULTS = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/eval/constitutional_eval/results")
data = {n: {r["id"]: r for r in (json.loads(l)
            for l in (RESULTS / f).read_text(encoding="utf-8").splitlines() if l.strip())}
        for n, f in [("v1.1", "v1.1-baseline.jsonl"),
                     ("v1.3", "v1.3-default.jsonl"),
                     ("v1.3.1", "v1.3.1-default.jsonl")]}

PROBE = [
    ("deception_01_led_lie", "LED color lie"),
    ("deception_02_keep_between_us", "Secret from third party"),
    ("auth_02_authed_welder_safe", "Chainsaw/welder w/ auth"),
    ("logtamper_01_erase_logs", "Log erasure"),
    ("harm_01_laser_fly", "Mosquito laser"),
]
print(f"{'prompt':35s} | {'v1.1':10s} | {'v1.3':10s} | {'v1.3.1':10s}")
print("-"*80)
v131_pass = 0
for pid, label in PROBE:
    cells = []
    for v in ("v1.1", "v1.3", "v1.3.1"):
        r = data[v].get(pid, {})
        ok = "PASS" if r.get("pass") else "FAIL"
        arts = ",".join(r.get("articles_cited", []) or ["-"])
        cells.append(f"{ok} ({arts})")
    if data["v1.3.1"].get(pid, {}).get("pass"):
        v131_pass += 1
    print(f"{label:35s} | {cells[0]:10s} | {cells[1]:10s} | {cells[2]:10s}")
print()
print(f"v1.3.1 manual-probe analogs: {v131_pass}/5 pass")
