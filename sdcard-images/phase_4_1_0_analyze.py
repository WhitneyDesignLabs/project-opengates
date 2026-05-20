#!/usr/bin/env python3
"""Phase 4.1.0 Steps 3c/3d/4/5b on the aggregated v1.1 corpus.

3c  quality sample: 5 turns/persona (heuristic bucket + printed text)
3d  anomaly hunt over ALL turns
4   persona_06 spotlight (the remapped-pin persona) by prompt_id
5b  3.1.3 baseline Haiku label distribution
"""
import json, random, re
from pathlib import Path
from collections import defaultdict, Counter

CORPUS = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus/v1.1-overnight-2026-05-18.jsonl")
LABELS = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus-labels")
random.seed(41)

turns = [json.loads(l) for l in CORPUS.read_text(encoding="utf-8").splitlines() if l.strip()]


def bucket(prompt, reply, timed_out):
    r = (reply or "").strip()
    rl = r.lower()
    if timed_out or r == "":
        return "empty/timeout"
    if re.search(r'\{\s*"(name|arguments|pin|value|r)"\s*:', r) or r.startswith("{") and r.endswith("}"):
        return "JSON-leak"
    if rl.startswith("error:") or "is reserved" in rl or "missing '" in rl \
       or "sorry, the model responded incorrectly" in rl or "rejected" in rl \
       or "invalid io" in rl:
        return "error-reply"
    if ("memory" in prompt.lower() or "file" in prompt.lower() or "remember" in prompt.lower()) \
       and ("no such file" in rl or "missing 'path'" in rl or "not found" in rl
            or "couldn't" in rl or "could not" in rl):
        return "memory-miss"
    if rl in ("history cleared", "the request was completed.",
              "the tool call was successful.", "ok", "done", "success") \
       or "tool call was successful" in rl or "request was completed" in rl:
        return "pseudo-prose"
    return "clean"


# ---- 3d anomaly hunt (all turns) ----
print("=" * 60)
print("STEP 3d — ANOMALY HUNT (all 3030 turns)")
anom = defaultdict(list)
buckets_all = Counter()
for t in turns:
    rep = (t.get("reply_text") or "")
    rl = rep.lower()
    pid = t.get("prompt_id", "")
    chip = t.get("_chip"); ts = t.get("ts_sent", "")[:19]
    if "wireclaw v0" in rl or "config: http" in rl or "mdns:" in rl:
        anom["boot-banner-in-reply"].append((chip, ts, pid, rep[:80]))
    if re.search(r"\b(llama|meta|openai|gpt|i am an ai language model|as an ai)\b", rl):
        anom["identity-drift"].append((chip, ts, pid, rep[:80]))
    if (rep.strip() == "") or t.get("reply_timed_out"):
        anom["empty-or-timeout"].append((chip, ts, pid, "TIMEOUT" if t.get("reply_timed_out") else "EMPTY"))
    if rl.strip() == "history cleared" and "clear" not in t.get("prompt_text", "").lower() and "histor" not in t.get("prompt_text","").lower():
        anom["history-cleared-mismatch"].append((chip, ts, pid, t.get("prompt_text","")[:60]))
    if rl.startswith("error:") or "is reserved" in rl or "invalid io" in rl:
        anom["tool-error"].append((chip, ts, pid, rep[:80]))
    buckets_all[bucket(t.get("prompt_text",""), rep, t.get("reply_timed_out"))] += 1

for k in ["boot-banner-in-reply", "identity-drift", "empty-or-timeout",
          "history-cleared-mismatch", "tool-error"]:
    v = anom.get(k, [])
    print(f"\n{k}: {len(v)}")
    for row in v[:8]:
        print("   ", row)
print("\nwhole-corpus heuristic bucket distribution:")
tot = sum(buckets_all.values())
for b, c in buckets_all.most_common():
    print(f"   {b:20s} {c:5d}  {100*c/tot:5.1f}%")

# ---- 3c quality sample: 5/persona ----
print("\n" + "=" * 60)
print("STEP 3c — QUALITY SAMPLE (5 random turns / persona, 35 total)")
by_p = defaultdict(list)
for t in turns:
    by_p[t.get("_persona")].append(t)
sample_buckets = Counter()
for persona in sorted(by_p):
    pick = random.sample(by_p[persona], min(5, len(by_p[persona])))
    print(f"\n--- persona_{persona:02d} ({by_p[persona][0].get('_persona_name')}) ---")
    for t in pick:
        b = bucket(t.get("prompt_text",""), t.get("reply_text"), t.get("reply_timed_out"))
        sample_buckets[b] += 1
        print(f"  [{b}] {t.get('prompt_id')}  q={t.get('prompt_text','')[:55]!r}")
        print(f"        a={(t.get('reply_text') or '')[:120]!r}")
print("\n35-sample bucket tally:")
for b, c in sample_buckets.most_common():
    print(f"   {b:20s} {c}")

# ---- Step 4 persona_06 spotlight ----
print("\n" + "=" * 60)
print("STEP 4 — persona_06 SPOTLIGHT (remapped pins)")
p6 = [t for t in turns if t.get("_persona") == 6]
print(f"persona_06 total turns: {len(p6)}")
byid = defaultdict(list)
for t in p6:
    byid[t.get("prompt_id")].append(t)
for pid in sorted(byid):
    rows = byid[pid]
    errs = sum(1 for t in rows
               if (t.get("reply_text") or "").lower().startswith("error:")
               or "is reserved" in (t.get("reply_text") or "").lower()
               or t.get("reply_timed_out"))
    boots = sum(1 for t in rows if "wireclaw v0" in (t.get("reply_text") or "").lower())
    ok = len(rows) - errs
    samp = next((t.get("reply_text","") for t in rows
                 if not (t.get("reply_text") or "").lower().startswith("error:")), "")
    print(f"\n  {pid}: n={len(rows)} ok={ok} err/timeout={errs} boot-banner={boots}")
    print(f"     q={rows[0].get('prompt_text','')[:70]!r}")
    print(f"     sample-ok-reply={samp[:140]!r}")

# ---- Step 5b 3.1.3 baseline label distribution ----
print("\n" + "=" * 60)
print("STEP 5b — 3.1.3 BASELINE Haiku label distribution")
for fn in ["3.1.3-2026-05-16-c6-02.haiku.json", "3.1.3-2026-05-16-c6-03.haiku.json"]:
    fp = LABELS / fn
    if not fp.exists():
        print(f"  {fn}: MISSING")
        continue
    try:
        data = json.loads(fp.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"  {fn}: parse error {e}")
        continue
    items = data if isinstance(data, list) else data.get("labels") or data.get("items") or []
    dist = Counter()
    for it in items:
        if isinstance(it, dict):
            dist[it.get("label") or it.get("category") or it.get("class") or "?"] += 1
    print(f"  {fn}: {len(items)} labeled; dist={dict(dist)}")
