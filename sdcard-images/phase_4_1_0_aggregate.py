#!/usr/bin/env python3
"""Phase 4.1.0 Step 2/3a: aggregate the 4.0.4a overnight v1.1 corpus.

Selects per-session JSONL files from the pulled raw tree that are
(a) persona-suffixed and (b) in the run window
    [2026-05-18T19:11:00, 2026-05-19T07:00:00) MST (filename-local time).
Concatenates every turn line into one corpus file, tagging each turn with
chip + persona + session, reports raw vs dedup'd counts per chip and a
per-persona breakdown, and prints the line-1 schema for sanity.
"""
import json, re, sys, hashlib
from pathlib import Path

RAW = Path("/mnt/c/Users/homet/Documents/WireClaw/corpus/raw/2026-05-19")
OUT = Path("/mnt/c/Users/homet/Documents/WireClaw/bench/fork/lora/corpus/v1.1-overnight-2026-05-18.jsonl")
WIN_LO, WIN_HI = 20260518191100, 20260519070000
CHIPS = {"pi02": "c6-02", "pi03": "c6-03"}
FN_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})T(\d+)_overnight_(\d+)_persona_(\d+)_(.+)\.jsonl$")


def in_window(fname: str):
    m = FN_RE.match(fname)
    if not m:
        return None
    key = int(m.group(1).replace("-", "") + m.group(2))
    if not (WIN_LO <= key < WIN_HI):
        return None
    return {"seq": int(m.group(3)), "persona": int(m.group(4)),
            "persona_name": m.group(5), "ts": m.group(1) + "T" + m.group(2)}


def main() -> int:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    schema_printed = False
    raw_counts = {c: 0 for c in CHIPS.values()}
    dedup_counts = {c: 0 for c in CHIPS.values()}
    persona_counts = {}        # (chip,persona) -> turns
    file_counts = {c: 0 for c in CHIPS.values()}
    seen = set()               # global dedup on turn content hash
    bad_files = []
    out_f = OUT.open("w", encoding="utf-8")
    total_written = 0

    for pi, chip in CHIPS.items():
        d = RAW / pi
        files = sorted(p for p in d.iterdir() if in_window(p.name))
        for p in files:
            meta = in_window(p.name)
            file_counts[chip] += 1
            try:
                lines = p.read_text(encoding="utf-8").splitlines()
            except Exception as e:
                bad_files.append((p.name, f"read:{e}"))
                continue
            for ln in lines:
                ln = ln.strip()
                if not ln:
                    continue
                try:
                    turn = json.loads(ln)
                except Exception as e:
                    bad_files.append((p.name, f"json:{e}"))
                    continue
                if not schema_printed:
                    print("line-1 schema keys:", sorted(turn.keys()))
                    print("line-1 sample:", json.dumps(turn)[:900])
                    schema_printed = True
                raw_counts[chip] += 1
                pk = (chip, meta["persona"])
                persona_counts[pk] = persona_counts.get(pk, 0) + 1
                h = hashlib.sha1(
                    json.dumps(turn, sort_keys=True).encode()).hexdigest()
                if h in seen:
                    continue
                seen.add(h)
                dedup_counts[chip] += 1
                turn["_chip"] = chip
                turn["_persona"] = meta["persona"]
                turn["_persona_name"] = meta["persona_name"]
                turn["_session_seq"] = meta["seq"]
                turn["_src_file"] = p.name
                out_f.write(json.dumps(turn, ensure_ascii=False) + "\n")
                total_written += 1

    out_f.close()

    print("\n=== Step 2/3a aggregation ===")
    print(f"output: {OUT}")
    for chip in CHIPS.values():
        print(f"{chip}: {file_counts[chip]} session files, "
              f"{raw_counts[chip]} raw turns, "
              f"{dedup_counts[chip]} after global dedup")
    print(f"COMBINED raw turns : {sum(raw_counts.values())}")
    print(f"COMBINED dedup'd   : {total_written} (written to corpus)")
    print(f"duplicate turns dropped: {sum(raw_counts.values()) - total_written}")
    print("\n-- per-persona turn counts (chip / persona# / turns) --")
    for (chip, persona) in sorted(persona_counts):
        print(f"  {chip}  p{persona:02d}  {persona_counts[(chip, persona)]}")
    if bad_files:
        print(f"\n-- {len(bad_files)} parse/read issues (first 10) --")
        for n, e in bad_files[:10]:
            print(f"  {n}: {e}")
    else:
        print("\nno parse/read issues.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
