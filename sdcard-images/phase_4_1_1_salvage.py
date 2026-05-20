#!/usr/bin/env python3
"""Phase 4.1.1 salvage driver (Path A).

Re-pairs the 4.0.4a overnight run from the azza proxy log: imports
`merge_corpus`'s pairing logic, walks each of the 303 user-side
sessions, filters proxy records to that session's client_ip + ts
window, and emits one REPAIRED corpus JSONL where prompt<->reply is
request/response-anchored (not Telegram-stream-ordered).
"""
import json, re, sys, os, glob
from pathlib import Path
from collections import Counter, defaultdict

ROOT       = Path("/mnt/c/Users/homet/Documents/WireClaw")
LORA       = ROOT / "bench" / "fork" / "lora"
SESS_DIRS  = {"c6-02": ROOT / "corpus/raw/2026-05-19/pi02",
              "c6-03": ROOT / "corpus/raw/2026-05-19/pi03"}
CHIP_IP    = {"c6-02": "192.168.1.15", "c6-03": "192.168.1.47"}
PROXY_FILES_DIR = ROOT / "corpus/proxy-4.1.1/files"
OUT        = LORA / "corpus" / "v1.1-overnight-2026-05-18.REPAIRED.jsonl"
WIN_LO     = "20260518T191100"
WIN_HI     = "20260519T070000"

sys.path.insert(0, str(LORA))
import merge_corpus  # noqa: E402

FN_RE = re.compile(
    r"^(\d{4}-\d{2}-\d{2})T(\d{6})_overnight_(\d+)_(persona_\d+_[A-Za-z_]+)\.jsonl$")


def session_meta(p: Path):
    """Parse session filename -> {ts_key, seq, persona_name}."""
    m = FN_RE.match(p.name)
    if not m:
        return None
    return {"ts_key": m.group(1).replace("-", "") + "T" + m.group(2),
            "seq": int(m.group(3)),
            "persona": m.group(4)}


def build_sessions(chip: str):
    """Sorted list of {chip,ip,seq,persona,ts_start,ts_end} for one chip.
    ts_end = next session's ts_start; last session uses WIN_HI."""
    metas = []
    for p in sorted(SESS_DIRS[chip].iterdir()):
        m = session_meta(p)
        if not m: continue
        if not (WIN_LO <= m["ts_key"] < WIN_HI):
            continue
        metas.append(m)
    metas.sort(key=lambda m: m["seq"])
    out = []
    for i, m in enumerate(metas):
        nxt = metas[i + 1]["ts_key"] if i + 1 < len(metas) else WIN_HI
        out.append({**m, "chip": chip, "ip": CHIP_IP[chip],
                    "ts_start": m["ts_key"], "ts_end": nxt})
    return out


def load_all_proxy_records():
    """Read all 8544 proxy json files into memory once."""
    recs = []
    for fp in glob.glob(str(PROXY_FILES_DIR / "**" / "*.json"), recursive=True):
        try:
            r = json.loads(open(fp, encoding="utf-8").read())
        except Exception:
            continue
        # normalise ts to YYYYMMDDThhmmss for window compare
        raw = r.get("ts") or ""
        r["_ts_key"] = raw.split("_")[0]
        recs.append(r)
    recs.sort(key=lambda r: r.get("ts", ""))
    return recs


def main():
    print("loading proxy records ...")
    all_recs = load_all_proxy_records()
    print(f"  total records: {len(all_recs)}")
    by_ip = defaultdict(list)
    for r in all_recs:
        by_ip[r.get("client_ip")].append(r)
    for ip, lst in by_ip.items():
        print(f"  {ip}: {len(lst)}")

    sessions = build_sessions("c6-02") + build_sessions("c6-03")
    print(f"sessions to repair: {len(sessions)}")

    repaired_turns = []
    persona_cache = {}
    summary = Counter()

    for s in sessions:
        # In-window records for this chip & session
        recs = [r for r in by_ip.get(s["ip"], [])
                if s["ts_start"] <= r["_ts_key"] < s["ts_end"]]
        if not recs:
            summary["empty-session"] += 1
            continue
        if s["persona"] not in persona_cache:
            persona_cache[s["persona"]] = merge_corpus.load_persona(s["persona"])
        persona = persona_cache[s["persona"]]
        session_id = f"{s['chip']}-overnight-{s['seq']:03d}"
        turns = merge_corpus.merge_records_into_turns(recs, persona, session_id)
        summary["proxy_recs"] += len(recs)
        summary["turns"] += len(turns)
        for t in turns:
            t["_chip"] = s["chip"]
            t["_session_seq"] = s["seq"]
            t["_persona_name"] = s["persona"]
            t["_ts_window"] = [s["ts_start"], s["ts_end"]]
            repaired_turns.append(t)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8") as f:
        for t in repaired_turns:
            f.write(json.dumps(t, ensure_ascii=False) + "\n")
    print(f"\nwrote {OUT}")
    print(f"  proxy records consumed: {summary['proxy_recs']}")
    print(f"  repaired turns: {summary['turns']}")
    print(f"  empty sessions skipped: {summary['empty-session']}")

    # ---- objective on-topic probe (same as the scrambled-corpus probe) ----
    TEMPQ = re.compile(r"\b(temperature|temp)\b", re.I)
    TEMPA = re.compile(r"(degree|celsius|°c|\btemp)", re.I)
    LEDQ  = re.compile(r"\bled\b", re.I)
    LEDA  = re.compile(r"\bled\b", re.I)
    IPQ   = re.compile(r"\bip address\b", re.I)
    IPA   = re.compile(r"(\d+\.\d+\.\d+\.\d+|ip address)", re.I)
    cls = {"temp": (TEMPQ, TEMPA), "led": (LEDQ, LEDA), "ip": (IPQ, IPA)}
    tot, hit = Counter(), Counter()
    for t in repaired_turns:
        p = t.get("prompt", "") or ""
        a = t.get("wrap_up_text", "") or ""
        for k, (q, ans) in cls.items():
            if q.search(p):
                tot[k] += 1
                if ans.search(a): hit[k] += 1
                break
    print("\nobjective on-topic (target >>14% scrambled baseline):")
    for k in tot:
        print(f"  {k}: {hit[k]}/{tot[k]} = {100*hit[k]/tot[k]:.1f}%")
    print(f"\nturns w/ matched-to-persona id: "
          f"{sum(1 for t in repaired_turns if not t['id'].startswith('unmatched-'))}/{len(repaired_turns)}")
    print(f"turns w/ non-empty wrap_up_text: "
          f"{sum(1 for t in repaired_turns if (t.get('wrap_up_text') or '').strip())}/{len(repaired_turns)}")


if __name__ == "__main__":
    main()
