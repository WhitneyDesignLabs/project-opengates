#!/usr/bin/env python3
# Phase 4.0.1 Step 3: aggregate the v1.1 corpus, strictly windowed per
# chip (launch -> that chip's last genuine reply), boot-banner + timeout
# turns discarded, dedup by (prompt_text, reply_text).
import glob, json, os, hashlib, sys

RAW = "/mnt/c/Users/homet/Documents/WireClaw/corpus/raw/2026-05-17"
OUTDIR = "/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus"
OUT = os.path.join(OUTDIR, "v1.1-overnight-2026-05-17.jsonl")
os.makedirs(OUTDIR, exist_ok=True)

# per-chip window: (launch ts_sent floor, last-good ts_received ceiling)
WIN = {
    "c6-02": ("2026-05-18T02:39:56", "2026-05-18T03:01:03.999999+00:00"),
    "c6-03": ("2026-05-18T02:40:08", "2026-05-18T04:00:43.999999+00:00"),
}
PI2CHIP = {"pi02": "c6-02", "pi03": "c6-03"}


def banner(t):
    return t is not None and "started" in t and ("Config:" in t or "mDNS:" in t)


def good(r):
    t = r.get("reply_text")
    return (not r.get("reply_timed_out")) and t is not None and not banner(t) and len(t.strip()) > 0


summary = {}
seen = set()
out_f = open(OUT, "w", encoding="utf-8")
combined = 0
samples = {}

for pi, chip in PI2CHIP.items():
    lo, hi = WIN[chip]
    files = sorted(glob.glob(os.path.join(RAW, pi, "*.jsonl")))
    raw_in_window = 0
    kept = 0
    samples[chip] = []
    for f in files:
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
            ts_s = d.get("ts_sent") or ""
            ts_r = d.get("ts_received") or ""
            if ts_s < lo:
                continue  # pre-v1.1 (05-16 3.1.x traffic) or before launch
            if not good(d):
                continue
            if not ts_r or ts_r > hi:
                continue  # past this chip's crash boundary
            raw_in_window += 1
            key = hashlib.sha1(
                ((d.get("prompt_text") or "") + "\x00" + (d.get("reply_text") or "")).encode("utf-8")
            ).hexdigest()
            if key in seen:
                continue
            seen.add(key)
            rec = {
                "chip": chip,
                "pi": pi,
                "ts_sent": ts_s,
                "ts_received": ts_r,
                "prompt_id": d.get("prompt_id"),
                "prompt_text": d.get("prompt_text"),
                "reply_text": d.get("reply_text"),
                "elapsed_s": d.get("elapsed_s"),
            }
            out_f.write(json.dumps(rec, ensure_ascii=False) + "\n")
            kept += 1
            combined += 1
            if len(samples[chip]) < 3:
                samples[chip].append(rec)
    summary[chip] = (raw_in_window, kept)

out_f.close()

print("OUTPUT: %s" % OUT)
for chip in ("c6-02", "c6-03"):
    rin, kept = summary[chip]
    print("%s  raw_in_window=%d  after_dedup=%d  (dropped_dups=%d)" % (chip, rin, kept, rin - kept))
print("COMBINED corpus turns = %d" % combined)
print("OUTPUT size bytes = %d" % os.path.getsize(OUT))
for chip in ("c6-02", "c6-03"):
    print("\n--- 3 sample turns: %s ---" % chip)
    for s in samples[chip]:
        rt = (s["reply_text"] or "").replace("\n", " ")
        if len(rt) > 240:
            rt = rt[:240] + "..."
        print("[%s] %s | Q: %s | A: %s" % (s["ts_received"], s["prompt_id"], (s["prompt_text"] or "")[:80], rt))
