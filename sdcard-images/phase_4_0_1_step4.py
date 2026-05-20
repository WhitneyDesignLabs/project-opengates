#!/usr/bin/env python3
# Phase 4.0.1 Step 4 (analysis-only): dump the boundary region per chip
# -- the last good turns before crash + first bad turns -- to identify
# the trigger pattern. No chip contact; pure corpus analysis.
import glob, json, os

RAW = "/mnt/c/Users/homet/Documents/WireClaw/corpus/raw/2026-05-17"
PI2CHIP = {"pi02": "c6-02", "pi03": "c6-03"}
LAUNCH = {"c6-02": "2026-05-18T02:39:56", "c6-03": "2026-05-18T02:40:08"}


def banner(t):
    return t is not None and "started" in t and ("Config:" in t or "mDNS:" in t)


def good(r):
    t = r.get("reply_text")
    return (not r.get("reply_timed_out")) and t is not None and not banner(t) and len(t.strip()) > 0


for pi, chip in PI2CHIP.items():
    rows = []
    for f in sorted(glob.glob(os.path.join(RAW, pi, "*.jsonl"))):
        try:
            lines = open(f, encoding="utf-8", errors="replace").read().splitlines()
        except Exception:
            continue
        for ln in lines:
            ln = ln.strip()
            if not ln:
                continue
            try:
                d = json.loads(ln)
            except Exception:
                continue
            if (d.get("ts_sent") or "") < LAUNCH[chip]:
                continue  # v1.1 window only
            d["_f"] = os.path.basename(f)
            rows.append(d)
    rows.sort(key=lambda r: r.get("ts_sent") or "")
    # find crash index = first bad turn after at least one good turn
    idx = None
    seen_good = False
    for i, r in enumerate(rows):
        if good(r):
            seen_good = True
        elif seen_good:
            idx = i
            break
    print("\n================ %s (%s) ================" % (chip, pi))
    print("v1.1 turns total=%d  crash_index=%s" % (len(rows), idx))
    if idx is None:
        continue
    lo = max(0, idx - 12)
    for i in range(lo, min(len(rows), idx + 4)):
        r = rows[i]
        tag = "GOOD" if good(r) else ("TIMEOUT" if r.get("reply_timed_out") else "BANNER")
        rt = (r.get("reply_text") or "<null>").replace("\n", " ")
        if len(rt) > 200:
            rt = rt[:200] + "..."
        mark = "  <<< CRASH ONSET" if i == idx else ""
        # surface any tool-call structure if the capture recorded it
        extra = ""
        for k in ("tool_calls", "tools", "n_tool_calls", "tool_chain", "raw"):
            if k in r and r[k]:
                extra += " %s=%s" % (k, str(r[k])[:120])
        print("[%02d|%s|%s] ts=%s id=%s%s" % (i, tag, r.get("_f", "")[:34], r.get("ts_sent"), r.get("prompt_id"), mark))
        print("     Q: %s" % ((r.get("prompt_text") or "")[:130]))
        print("     A: %s%s" % (rt, extra))
