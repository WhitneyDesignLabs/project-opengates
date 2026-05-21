#!/usr/bin/env python3
"""Phase 4.2.1.I.3 salvage driver — adapt 4.1.1 pattern to 3-chip v1.3.1 overnight.

Re-pairs the 2026-05-20 → 2026-05-21 overnight run from the azza proxy log:
imports merge_corpus's pairing logic, walks each user-side session per chip,
filters proxy records to that session's client_ip + ts window, emits one
REPAIRED corpus JSONL where prompt<->reply is request/response-anchored.
"""
import json, re, sys, os, glob
from pathlib import Path
from collections import Counter, defaultdict

ROOT       = Path("/mnt/c/Users/homet/Documents/WireClaw")
LORA       = ROOT / "bench" / "fork" / "lora"
RUN_DIR    = LORA / "corpus" / "v1.3.1-overnight-2026-05-20"
SESS_DIRS  = {
    "c6-01": RUN_DIR / "user-side" / "evobot",
    "c6-02": RUN_DIR / "user-side" / "pi02",
    "c6-03": RUN_DIR / "user-side" / "pi03",
}
CHIP_IP    = {
    "c6-01": "192.168.1.19",
    "c6-02": "192.168.1.15",
    "c6-03": "192.168.1.47",
}
PROXY_DIR  = RUN_DIR / "proxy"
OUT_ALL    = LORA / "corpus" / "v1.3.1-overnight-2026-05-20.jsonl"
OUT_PER    = {chip: LORA / "corpus" / f"v1.3.1-overnight-2026-05-20.{chip}.jsonl"
              for chip in SESS_DIRS}

# Proxy ts is local MST (e.g. "20260520T175800_862649"). Window covers the run.
WIN_LO     = "20260520T175650"   # launch (evobot earliest)
WIN_HI     = "20260521T060500"   # stop (small slack past 06:03 final-status)

sys.path.insert(0, str(LORA))
import merge_corpus  # noqa: E402

FN_RE = re.compile(
    r"^(\d{4}-\d{2}-\d{2})T(\d{6})_overnight_(\d+)_(persona_\d+_[A-Za-z_]+)\.jsonl$"
)


def session_meta(p: Path):
    m = FN_RE.match(p.name)
    if not m:
        return None
    return {
        "ts_key": m.group(1).replace("-", "") + "T" + m.group(2),
        "seq": int(m.group(3)),
        "persona": m.group(4),
    }


def build_sessions(chip: str):
    metas = []
    for p in sorted(SESS_DIRS[chip].iterdir()):
        m = session_meta(p)
        if not m:
            continue
        if not (WIN_LO <= m["ts_key"] < WIN_HI):
            continue
        metas.append(m)
    metas.sort(key=lambda m: m["seq"])
    out = []
    for i, m in enumerate(metas):
        nxt = metas[i + 1]["ts_key"] if i + 1 < len(metas) else WIN_HI
        out.append({
            **m,
            "chip": chip,
            "ip": CHIP_IP[chip],
            "ts_start": m["ts_key"],
            "ts_end": nxt,
        })
    return out


def load_all_proxy_records():
    recs = []
    for fp in glob.glob(str(PROXY_DIR / "**" / "*.json"), recursive=True):
        try:
            r = json.loads(open(fp, encoding="utf-8").read())
        except Exception:
            continue
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
    print("  records per source IP:")
    for ip in sorted(by_ip, key=lambda k: -len(by_ip[k])):
        print(f"    {ip:20s}: {len(by_ip[ip]):6d}")

    sessions = []
    for chip in SESS_DIRS:
        s = build_sessions(chip)
        sessions.extend(s)
        print(f"  sessions {chip}: {len(s)}")
    print(f"  sessions total:  {len(sessions)}")

    all_repaired = []
    per_chip = {chip: [] for chip in SESS_DIRS}
    persona_cache = {}
    summary = Counter()

    for s in sessions:
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
        summary[f"recs_{s['chip']}"] += len(recs)
        summary[f"turns_{s['chip']}"] += len(turns)
        for t in turns:
            t["_chip"] = s["chip"]
            t["_session_seq"] = s["seq"]
            t["_persona_name"] = s["persona"]
            t["_ts_window"] = [s["ts_start"], s["ts_end"]]
            all_repaired.append(t)
            per_chip[s["chip"]].append(t)

    OUT_ALL.parent.mkdir(parents=True, exist_ok=True)
    with OUT_ALL.open("w", encoding="utf-8") as f:
        for t in all_repaired:
            f.write(json.dumps(t, ensure_ascii=False) + "\n")
    print(f"\nwrote {OUT_ALL}  ({len(all_repaired)} turns)")
    for chip, items in per_chip.items():
        with OUT_PER[chip].open("w", encoding="utf-8") as f:
            for t in items:
                f.write(json.dumps(t, ensure_ascii=False) + "\n")
        print(f"wrote {OUT_PER[chip]}  ({len(items)} turns)")

    print()
    print("summary:")
    for k in sorted(summary):
        print(f"  {k}: {summary[k]}")


if __name__ == "__main__":
    main()
