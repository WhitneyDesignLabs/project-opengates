#!/usr/bin/env python3
"""
Morning wrap-up for the overnight throughput test.

Takes a directory of proxy-raw records (the full overnight haul, pulled from
azza:~/wireclaw-corpus/ollama-raw/<dates>/), merges them into one aggregate
seed-corpus-shape JSON via `merge_corpus.merge_records_into_turns`, classifies
the result via `wrap_up_classify.classify_wrap_up`, and prints throughput +
error + label statistics.

Usage:
  python3 aggregate_overnight.py \\
      --proxy-logs /tmp/overnight-pull \\
      --persona persona_01_basic \\
      --session-id overnight-2026-05-16 \\
      --client-ip 192.168.1.19 \\
      --out fork/lora/corpus-raw/overnight-2026-05-16.json
"""
from __future__ import annotations

import argparse
import json
import statistics
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).parent
BENCH = HERE.parent.parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(BENCH))

import merge_corpus  # noqa: E402
import wrap_up_classify as wuc  # noqa: E402


def parse_ts(ts: str) -> datetime | None:
    """Parse the proxy's timestamp shape (compact ISO or with underscores)."""
    if not ts:
        return None
    # Try compact: 20260515T184306_797246  (with underscore separating ms)
    candidates = [
        ts,
        ts.replace("_", "."),  # for "T184306_797246" -> "T184306.797246"
    ]
    for fmt in (
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%dT%H:%M:%S.%f",
        "%Y-%m-%dT%H:%M:%S%z",
        "%Y-%m-%dT%H:%M:%S.%f%z",
        "%Y%m%dT%H%M%S",
        "%Y%m%dT%H%M%S.%f",
    ):
        for c in candidates:
            try:
                dt = datetime.strptime(c[:26] if "." in c else c[:19], fmt)
                return dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt
            except ValueError:
                continue
    return None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--proxy-logs", type=Path, required=True)
    ap.add_argument("--persona", required=True)
    ap.add_argument("--session-id", required=True)
    ap.add_argument("--client-ip", default=None)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    if not args.proxy_logs.exists():
        print(f"ERROR: proxy-logs dir not found: {args.proxy_logs}", file=sys.stderr)
        return 2

    persona = merge_corpus.load_persona(args.persona)
    records = merge_corpus.load_proxy_records(args.proxy_logs)
    if args.client_ip:
        records = [r for r in records if r.get("client_ip") == args.client_ip]
    print(f"Loaded {len(records)} proxy records")
    if not records:
        print("  no records to process", file=sys.stderr)
        return 1

    # Throughput window from record timestamps.
    timestamps = [parse_ts(r.get("ts", "")) for r in records]
    timestamps = [t for t in timestamps if t is not None]
    if timestamps:
        first = min(timestamps)
        last = max(timestamps)
        duration_s = (last - first).total_seconds()
        print(f"  capture window: {first.isoformat()} -> {last.isoformat()}  "
              f"({duration_s/3600:.2f} hours)")
    else:
        first = last = None
        duration_s = 0.0

    # Latency stats from the proxy records themselves.
    latencies = [r.get("upstream_latency_ms", 0) for r in records if r.get("upstream_latency_ms")]
    if latencies:
        print(f"  upstream latency ms: min={min(latencies)} p50={statistics.median(latencies):.0f} "
              f"mean={statistics.mean(latencies):.0f} p95={sorted(latencies)[int(0.95*len(latencies))]} max={max(latencies)}")

    # Status code distribution.
    statuses = Counter(r.get("status") for r in records)
    print(f"  HTTP status distribution: {dict(statuses)}")

    # Merge into turns.
    wuc.init_tool_names(wuc.load_tool_names())
    turns = merge_corpus.merge_records_into_turns(records, persona, args.session_id)
    matched = sum(1 for t in turns if not t["id"].startswith("unmatched-"))
    print(f"\nMerged into {len(turns)} turns ({matched} matched to persona prompts, "
          f"{len(turns) - matched} unmatched)")

    # Classify each turn.
    label_counts: Counter = Counter()
    conf_counts: Counter = Counter()
    tool_counts: Counter = Counter()
    for t in turns:
        det = wuc.classify_deterministic(t.get("wrap_up_text") or "",
                                         t.get("tool_calls_fired") or [],
                                         t.get("tool_results") or [])
        t["deterministic_label"] = det.label
        t["deterministic_confidence"] = det.confidence
        t["deterministic_evidence"] = det.evidence
        label_counts[det.label] += 1
        conf_counts[det.confidence] += 1
        for tc in t.get("tool_calls_fired", []):
            tool_counts[tc.get("function", "?")] += 1
    print(f"\nLabel distribution:      {dict(label_counts)}")
    print(f"Confidence distribution: {dict(conf_counts)}")
    print(f"Tool-call distribution:  {dict(tool_counts)}")

    # Per-prompt-id breakdown.
    by_prompt: dict[str, Counter] = {}
    for t in turns:
        # Extract the persona-prompt-id portion of t["id"]: "<persona>-<pXX_name>-<ts>"
        parts = t["id"].split("-")
        if len(parts) >= 3 and parts[0] == getattr(persona, "PERSONA_ID", ""):
            prompt_id = parts[1] if len(parts) == 3 else "-".join(parts[1:-1])
        else:
            prompt_id = "unmatched"
        by_prompt.setdefault(prompt_id, Counter())[t.get("deterministic_label", "?")] += 1
    print("\nPer-prompt label breakdown:")
    for pid in sorted(by_prompt):
        total = sum(by_prompt[pid].values())
        print(f"  {pid:34} n={total:4}  {dict(by_prompt[pid])}")

    # Throughput.
    if duration_s > 0:
        per_hour = len(turns) / (duration_s / 3600)
        print(f"\nThroughput: {len(turns)} turns in {duration_s/3600:.2f}h = {per_hour:.1f} turns/hour")
        print(f"  ({len(records)} proxy records = {len(records)/(duration_s/3600):.1f} records/hour)")

    output = {
        "session_id": args.session_id,
        "source": "overnight-aggregate",
        "proxy_logs": str(args.proxy_logs),
        "persona": getattr(persona, "PERSONA_ID", args.persona),
        "capture_window": {
            "start": first.isoformat() if first else None,
            "end": last.isoformat() if last else None,
            "duration_hours": round(duration_s / 3600, 2) if duration_s else 0,
        },
        "proxy_stats": {
            "record_count": len(records),
            "status_distribution": dict(statuses),
            "latency_ms": {
                "min": min(latencies) if latencies else None,
                "p50": int(statistics.median(latencies)) if latencies else None,
                "mean": int(statistics.mean(latencies)) if latencies else None,
                "p95": sorted(latencies)[int(0.95 * len(latencies))] if latencies else None,
                "max": max(latencies) if latencies else None,
            },
        },
        "turns": {
            "total": len(turns),
            "matched": matched,
            "unmatched": len(turns) - matched,
            "throughput_per_hour": round(len(turns) / (duration_s / 3600), 1) if duration_s else None,
        },
        "label_counts": dict(label_counts),
        "confidence_counts": dict(conf_counts),
        "tool_counts": dict(tool_counts),
        "per_prompt": {pid: dict(c) for pid, c in by_prompt.items()},
        "conversations": turns,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2))
    print(f"\nWrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
