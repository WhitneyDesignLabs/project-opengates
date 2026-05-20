#!/usr/bin/env python3
"""
Merge azza-proxy raw logs into a seed-corpus-shape JSON file.

The Ollama-side logging proxy (`bench/fork/lora/ollama_logging_proxy.py`, deployed
to azza) writes one JSON record per /v1/chat/completions request that the chip
fleet sends through it. Each WireClaw user turn produces 1-2 such records:

  - Call 1 (always): request.messages ends with a `user` message; response
    contains `tool_calls` (or `content` if no tools fire).
  - Call 2 (if tools fired): request.messages now includes the original user
    message + the assistant's tool_call + the tool result message(s);
    response contains `content` (the user-facing wrap-up text).
  - Call 3+ (rare): when the model emits sequential rather than parallel
    tool_calls; same shape as call 2 but with another tool_call → result cycle
    before the wrap-up.

This script groups raw records into conversation turns, extracts the
seed-corpus fields (prompt, messages_sent_to_llm_iter1, tool_calls_fired,
tool_results, wrap_up_text), matches each turn to its persona prompt, and
emits a `{session_id, conversations: [...]}` JSON file ready for
`bench/wrap_up_classify.py --corpus`.

Usage:
  python3 merge_corpus.py \\
      --proxy-logs /tmp/proxy-pull/2026-05-15 \\
      --persona persona_01_basic \\
      --session-id pilot-3.1.0-2026-05-15 \\
      --out fork/lora/corpus-raw/pilot-3.1.0-2026-05-15.json

The `--persona` argument is a Python module name relative to
`bench/fork/lora/personas/` (without the `.py` extension). The script imports
it and uses its `PROMPTS` list to match captured user prompts to persona
prompt IDs.

Raw record shape produced by the proxy (per `CORPUS_CAPTURE.md`):
  {
    "ts":                 "ISO-8601 timestamp",
    "client_ip":          "192.168.1.x (chip IP)",
    "path":               "/v1/chat/completions",
    "upstream_latency_ms": int,
    "status":              200,
    "request":             { /* full request body, OpenAI shape */ },
    "response":            { /* full response body */ }
  }
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any, Iterable

HERE = Path(__file__).parent
PERSONAS_DIR = HERE / "personas"


# ----------------------------------------------------------------------------
# Proxy record helpers
# ----------------------------------------------------------------------------

def _last_message(record: dict) -> dict:
    msgs = record.get("request", {}).get("messages") or []
    return msgs[-1] if msgs else {}


def _response_message(record: dict) -> dict:
    choices = record.get("response", {}).get("choices") or []
    if not choices:
        return {}
    return choices[0].get("message", {}) or {}


def _flatten_tool_call(tc: dict) -> dict:
    """OpenAI tool_call shape -> {function, arguments} flat shape."""
    fn = tc.get("function") or {}
    args_field = fn.get("arguments")
    args: Any
    if isinstance(args_field, dict):
        args = args_field
    elif isinstance(args_field, str):
        try:
            args = json.loads(args_field)
        except json.JSONDecodeError:
            args = {"_raw": args_field}
    else:
        args = {}
    return {"function": fn.get("name"), "arguments": args}


def _extract_tool_results(messages: list[dict], already_seen: set[str]) -> list[str]:
    """Pull NEW tool-role message contents from the messages array."""
    new = []
    for m in messages or []:
        if m.get("role") == "tool":
            content = m.get("content")
            if isinstance(content, str) and content not in already_seen:
                new.append(content)
                already_seen.add(content)
    return new


def _is_call_1(record: dict) -> bool:
    """
    Does this record begin a new turn? True iff its request.messages ENDS with
    a `user`-role message -- meaning the chip just sent a fresh user prompt to
    the model (call 1 of an agentic loop). Continuation calls (call 2, 3, ...)
    end with a `tool`-role message instead and accumulate into the current turn.

    Robust to WireClaw's 4-turn `/history.json` truncation: the user-message
    COUNT in messages plateaus once history fills, so a count-based heuristic
    silently collapses all post-turn-4 records into one mega-turn (the
    2026-05-15 Phase 3.1.0 bug). The last-message-role check is unaffected
    by truncation -- /history.json never carries tool-role messages, so the
    last message is always either the current turn's fresh user prompt or the
    current turn's most recent tool result.
    """
    msgs = record.get("request", {}).get("messages") or []
    if not msgs:
        return False
    return msgs[-1].get("role") == "user"


# ----------------------------------------------------------------------------
# Persona loading + prompt matching
# ----------------------------------------------------------------------------

def load_persona(name: str):
    """Import a persona module by name (no .py)."""
    if name.endswith(".py"):
        name = name[:-3]
    path = PERSONAS_DIR / f"{name}.py"
    if not path.exists():
        raise SystemExit(f"persona not found: {path}")
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def _normalize(text: str) -> str:
    return " ".join((text or "").split()).lower()


def match_prompt_to_persona(prompt_text: str, persona) -> dict | None:
    """
    Fuzzy-match a captured prompt to one of the persona's PROMPTS entries.

    The match is forgiving: substring either direction after lowercase +
    whitespace normalisation. Persona prompt text and captured text may differ
    in punctuation or minor edits (e.g. the operator typed "chip temp" vs the
    persona's "chip temperature"); the substring check accepts both.
    """
    if not prompt_text:
        return None
    norm = _normalize(prompt_text)
    best = None
    best_score = 0
    for p in getattr(persona, "PROMPTS", []) or []:
        pnorm = _normalize(p.text)
        if not pnorm:
            continue
        if pnorm in norm or norm in pnorm:
            score = min(len(pnorm), len(norm)) / max(len(pnorm), len(norm))
            if score > best_score:
                best_score = score
                best = p
    return {"id": best.id, "expected_tool": best.expected_tool} if best else None


# ----------------------------------------------------------------------------
# Core merge logic
# ----------------------------------------------------------------------------

def load_proxy_records(proxy_logs_dir: Path) -> list[dict]:
    """Read all .json files in proxy_logs_dir (recursive)."""
    records = []
    for path in sorted(proxy_logs_dir.rglob("*.json")):
        try:
            records.append(json.loads(path.read_text()))
        except json.JSONDecodeError as e:
            print(f"WARN: skipping malformed {path}: {e}", file=sys.stderr)
    records.sort(key=lambda r: r.get("ts", ""))
    return records


def merge_records_into_turns(
    records: Iterable[dict],
    persona,
    session_id: str,
) -> list[dict]:
    """
    Walk timestamp-ordered records and emit one turn per fresh user prompt.

    A new turn starts whenever a record's request.messages ENDS with a
    `user`-role message (call 1 of an agentic loop). Continuation records
    -- those ending with a `tool`-role message -- accumulate into the
    current turn. The wrap-up is whichever record's
    response.choices[0].message.content lands last for that turn.

    The previous user-message-count heuristic collapsed sessions of >4 turns
    into one mega-turn once WireClaw's 4-turn `/history.json` started
    evicting old user messages (Phase 3.1.0 bug, fixed 2026-05-15). The
    last-message-role check is unaffected by history truncation.
    """
    turns: list[dict] = []
    current: dict | None = None
    tool_results_seen: set[str] = set()

    for rec in records:
        is_new = _is_call_1(rec)

        if is_new:
            if current:
                turns.append(current)
            tool_results_seen = set()
            user_msg = _last_message(rec)
            prompt_text = user_msg.get("content", "")
            match = match_prompt_to_persona(prompt_text, persona)
            current = {
                "id": (
                    f"{getattr(persona, 'PERSONA_ID', 'unknown')}-{match['id']}-{rec.get('ts', '')}"
                    if match else f"unmatched-{rec.get('ts', '')}"
                ),
                "session": session_id,
                "ts": rec.get("ts"),
                "client_ip": rec.get("client_ip"),
                "prompt": prompt_text,
                "expected_tool": match["expected_tool"] if match else None,
                "messages_sent_to_llm_iter1": rec.get("request", {}).get("messages", []),
                "tool_calls_fired": [],
                "tool_results": [],
                "wrap_up_text": None,
                "human_label": None,
                "proxy_calls": 1,
            }
            # Tool calls fired on call 1 (if any)
            resp_msg = _response_message(rec)
            for tc in resp_msg.get("tool_calls") or []:
                current["tool_calls_fired"].append(_flatten_tool_call(tc))
            # If call 1 returned content (no tools fired), that IS the wrap-up
            if resp_msg.get("content") and not resp_msg.get("tool_calls"):
                current["wrap_up_text"] = resp_msg["content"]
            continue

        # Not a new turn -- accumulate into the current one.
        if current is None:
            continue
        current["proxy_calls"] += 1
        # Tool results: any new tool-role messages in this record's request.
        new_results = _extract_tool_results(
            rec.get("request", {}).get("messages", []), tool_results_seen
        )
        current["tool_results"].extend(new_results)
        # Additional tool_calls (sequential model output).
        resp_msg = _response_message(rec)
        for tc in resp_msg.get("tool_calls") or []:
            current["tool_calls_fired"].append(_flatten_tool_call(tc))
        # Wrap-up text: the latest record's content wins (when no more tools fire).
        content = resp_msg.get("content")
        if content:
            current["wrap_up_text"] = content

    if current:
        turns.append(current)
    return turns


# ----------------------------------------------------------------------------
# CLI
# ----------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--proxy-logs", type=Path, required=True,
                    help="Directory containing proxy raw .json files (recursive).")
    ap.add_argument("--persona", required=True,
                    help="Persona module name under bench/fork/lora/personas/ (no .py).")
    ap.add_argument("--session-id", required=True,
                    help="Session identifier embedded in the output.")
    ap.add_argument("--out", type=Path, required=True,
                    help="Output JSON path.")
    ap.add_argument("--client-ip", default=None,
                    help="Filter records by client_ip (chip IP). If unset, include all.")
    args = ap.parse_args()

    if not args.proxy_logs.exists():
        print(f"ERROR: proxy-logs dir not found: {args.proxy_logs}", file=sys.stderr)
        return 2

    persona = load_persona(args.persona)
    records = load_proxy_records(args.proxy_logs)
    if args.client_ip:
        records = [r for r in records if r.get("client_ip") == args.client_ip]

    print(f"Loaded {len(records)} proxy records from {args.proxy_logs}")
    if args.client_ip:
        print(f"  filtered to client_ip={args.client_ip}")

    turns = merge_records_into_turns(records, persona, args.session_id)
    matched = sum(1 for t in turns if not t["id"].startswith("unmatched-"))
    print(f"Emitted {len(turns)} turns ({matched} matched to persona prompts)")
    for t in turns:
        status = "MATCH" if not t["id"].startswith("unmatched-") else "UNMATCHED"
        wrap = (t["wrap_up_text"] or "")[:50].replace("\n", " ")
        print(f"  [{status}] {t['id'][:60]:60}  tools={[c['function'] for c in t['tool_calls_fired']]}  wrap=\"{wrap}...\"")

    output = {
        "session_id": args.session_id,
        "model_hint": "wireclaw-agent:v1",
        "source": "proxy-merge",
        "proxy_logs": str(args.proxy_logs),
        "persona": getattr(persona, "PERSONA_ID", args.persona),
        "conversations": turns,
        "summary": {
            "total_turns": len(turns),
            "matched_to_persona": matched,
            "unmatched": len(turns) - matched,
        },
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2))
    print(f"\nWrote {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
