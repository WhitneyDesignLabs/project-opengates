#!/usr/bin/env python3
"""Phase 4.1.0: quantify prompt<->reply desynchronization.

Strong objective probe: temperature-class prompts should yield a reply
that mentions temperature/degrees. Also test the lag hypothesis — does
reply[i] match prompt[i-1] (one-behind) better than prompt[i] — within
each session file (per-session ordering preserved via _src_file + line).
"""
import json, re
from pathlib import Path
from collections import Counter, defaultdict

CORPUS = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus/v1.1-overnight-2026-05-18.jsonl")
turns = [json.loads(l) for l in CORPUS.read_text(encoding="utf-8").splitlines() if l.strip()]

TEMP_Q = re.compile(r"\b(temperature|temp)\b", re.I)
TEMP_A = re.compile(r"(degree|celsius|°c|\btemp)", re.I)
LED_Q = re.compile(r"\bled\b", re.I)
LED_A = re.compile(r"\bled\b", re.I)
IP_Q = re.compile(r"\bip address\b", re.I)
IP_A = re.compile(r"(\d+\.\d+\.\d+\.\d+|ip address)", re.I)

def klass(p):
    if TEMP_Q.search(p): return "temp"
    if IP_Q.search(p): return "ip"
    if LED_Q.search(p): return "led"
    return None

def matches(k, a):
    if k == "temp": return bool(TEMP_A.search(a))
    if k == "ip": return bool(IP_A.search(a))
    if k == "led": return bool(LED_A.search(a))
    return False

# direct correspondence rate on objectively-checkable prompt classes
direct = Counter(); hit = Counter()
for t in turns:
    k = klass(t.get("prompt_text",""))
    if not k: continue
    direct[k] += 1
    if matches(k, t.get("reply_text") or ""): hit[k] += 1

print("=== Objective prompt->reply correspondence (aligned?) ===")
for k in direct:
    print(f"  {k:5s}: {hit[k]}/{direct[k]} replies on-topic = {100*hit[k]/direct[k]:.1f}%")

# lag test: reconstruct per-session ordered turns, compare reply[i] vs
# prompt[i] vs prompt[i-1] using the temp class as the probe.
sessions = defaultdict(list)
for t in turns:
    sessions[(t.get("_chip"), t.get("_src_file"))].append(t)

aligned = lag1 = nomatch = probes = 0
for key, arr in sessions.items():
    arr.sort(key=lambda x: x.get("ts_sent",""))
    for i, t in enumerate(arr):
        a = t.get("reply_text") or ""
        if not TEMP_A.search(a):
            continue
        probes += 1
        cur = TEMP_Q.search(arr[i].get("prompt_text",""))
        prev = TEMP_Q.search(arr[i-1].get("prompt_text","")) if i > 0 else None
        if cur: aligned += 1
        elif prev: lag1 += 1
        else: nomatch += 1
print("\n=== Lag signature (replies that mention temperature) ===")
print(f"  total temp-replies probed: {probes}")
print(f"  prompt[i] is temp (ALIGNED)      : {aligned}  {100*aligned/max(probes,1):.1f}%")
print(f"  prompt[i-1] is temp (ONE-BEHIND) : {lag1}  {100*lag1/max(probes,1):.1f}%")
print(f"  neither (scrambled)              : {nomatch}  {100*nomatch/max(probes,1):.1f}%")

# how much of corpus is the literal "History cleared" reply
hc = sum(1 for t in turns if (t.get("reply_text") or "").strip().lower() == "history cleared")
print(f"\n'History cleared' replies: {hc}/{len(turns)} = {100*hc/len(turns):.1f}%")
empties = sum(1 for t in turns if not (t.get("reply_text") or "").strip())
print(f"empty replies: {empties}")
