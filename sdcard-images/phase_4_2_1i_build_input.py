#!/usr/bin/env python3
"""Phase 4.2.1.I.5 prep: convert the salvaged v1.3.1 corpus JSONL into the
`{conversations: [...]}` JSON shape that wrap_up_classify.py consumes.
Preserves all fields the labeler reads + the v1.3.1-extras for downstream
flag enrichment."""
import json
from pathlib import Path

ROOT = Path("/mnt/c/Users/homet/Documents/WireClaw")
LORA = ROOT / "bench" / "fork" / "lora"
SRC = LORA / "corpus" / "v1.3.1-overnight-2026-05-20.jsonl"
OUT = LORA / "corpus-labels" / "v1.3.1-overnight-2026-05-20.input.json"
OUT.parent.mkdir(parents=True, exist_ok=True)

convs = []
with SRC.open(encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        t = json.loads(line)
        convs.append(t)

doc = {
    "session_id": "v1.3.1-overnight-2026-05-20",
    "notes": "3-chip overnight capture, full 7-persona rotation, 0 errors, "
             "0 boot banners, 0 history-cleared bleeds. azza-proxy-re-paired "
             "via merge_corpus.merge_records_into_turns.",
    "conversations": convs,
}
OUT.write_text(json.dumps(doc, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"wrote {OUT}  ({len(convs)} conversations)")
print(f"  size: {OUT.stat().st_size:,} bytes")
