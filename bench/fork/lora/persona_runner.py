#!/usr/bin/env python3
"""
Telethon-based synthetic-user driver for the WireClaw capture fleet.

Drives the prompts from a persona module against a target chip bot over
Telegram, awaiting each reply before sending the next. Writes a JSONL
session log (one line per prompt/reply pair) for cross-check + debugging.

The CANONICAL Phase 3 corpus source is the Ollama-side proxy on azza
(stream 3 per CORPUS_CAPTURE.md). This driver is stream 1 -- the
user-side record of what was sent and what the Telegram client saw come
back. The two streams are joined later (or just spot-checked against
each other) to verify capture fidelity.

Operating principles:
  - One persona module per run (start simple; multi-persona orchestration
    is later infra).
  - `/clear` is sent to the bot at session start AND end, so the chip's
    /history.json is clean both sides of the capture.
  - Telethon's persistent session file means first-run-only requires an
    SMS code; subsequent runs are non-interactive.
  - Auth credentials come from environment variables, NOT command-line
    arguments (avoid leaking into shell history).

Required env vars (see Secrets.txt at the workspace root):
  TG_API_ID    integer, from https://my.telegram.org/apps
  TG_API_HASH  string,  from https://my.telegram.org/apps
  TG_PHONE     E.164 phone number registered with Telegram (e.g. +15551234)

Usage (first run, interactive for SMS code):
  TG_API_ID=$(grep TG_API_ID Secrets.txt | cut -d= -f2) \\
  TG_API_HASH=$(grep TG_API_HASH Secrets.txt | cut -d= -f2) \\
  TG_PHONE=$(grep TG_PHONE Secrets.txt | cut -d= -f2) \\
  python3 persona_runner.py \\
      --persona persona_01_basic \\
      --bot-username wdl_c6_pilot_bot \\
      --session-file ~/.telethon-evobot.session \\
      --out ~/wireclaw-corpus/user-side/$(date +%F-%H%M)_persona_01.jsonl

Usage (subsequent runs, non-interactive -- session file already authed):
  Same command; Telethon picks up the existing session.

Dry-run (no Telegram traffic; prints what would be sent):
  python3 persona_runner.py --persona persona_01_basic --bot-username x --dry-run

Output JSONL shape (one record per prompt/reply pair):
  {"ts_sent": "...", "ts_received": "...", "prompt_id": "p01_chip_temp",
   "prompt_text": "What is the chip temperature?",
   "reply_text": "<verbatim text from the chip bot>",
   "reply_timed_out": false, "elapsed_s": 12.3}
"""
from __future__ import annotations

import argparse
import asyncio
import datetime as dt
import importlib.util
import json
import os
import sys
from pathlib import Path
from typing import Any

HERE = Path(__file__).parent
PERSONAS_DIR = HERE / "personas"

# Hard cap on how long we wait for the bot to reply to one prompt.
# llama3.1:8b inference + tool execution + Telegram polling is typically
# 8-25s per turn; 120s gives ample headroom without hanging forever.
REPLY_TIMEOUT_S = 120.0

# Default inter-prompt delay if the persona module doesn't set one.
DEFAULT_INTERACTION_DELAY_S = 6.0

# Quiescence window. The WireClaw chip emits MULTIPLE Telegram messages
# per prompt (intermediate "[Agent] N tool call(s)" traces, then the
# wrap-up) plus unsolicited self-firing-rule messages and /clear echoes.
# The old pop-first FIFO matched prompt N to whichever stray message
# surfaced first -> scrambled corpus (Phase 4.1.1). We now collect ALL
# bot messages after a send and consider the turn complete once the bot
# has been silent for SETTLE_S; the reply is the last *substantive*
# message. SETTLE_S must exceed the chip's inter-message gap within one
# agentic turn (~1-3s observed) but stay well under typical turn spacing.
SETTLE_S = 5.0

# Plumbing / noise messages that are NOT the model's answer. Matched
# case-insensitively; a message is dropped if it equals or starts with
# one of these (after strip). The chosen reply is the last message that
# survives this filter.
_PLUMBING_EXACT = {"history cleared", "ok", "done"}
_PLUMBING_PREFIX = (
    "wireclaw v",          # boot banner
    "config: http",        # boot banner line 2
    "mdns:",               # boot banner line 3
    "[agent]",             # intermediate agentic-loop trace
    "[tg]",                # chip-side telegram debug echo
)


def _is_substantive(text: str | None) -> bool:
    """True if `text` looks like a real model answer, not chip plumbing."""
    if not text:
        return False
    t = text.strip().lower()
    if t in _PLUMBING_EXACT:
        return False
    for pre in _PLUMBING_PREFIX:
        if t.startswith(pre):
            return False
    return True


# ----------------------------------------------------------------------------
# Persona loading (mirrors merge_corpus.py)
# ----------------------------------------------------------------------------

def load_persona(name: str):
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


# ----------------------------------------------------------------------------
# Dry-run path (no Telegram)
# ----------------------------------------------------------------------------

def dry_run(persona, bot_username: str, out_path: Path | None) -> int:
    delay = getattr(persona, "INTERACTION_DELAY_S", DEFAULT_INTERACTION_DELAY_S)
    print(f"[dry-run] persona={getattr(persona, 'PERSONA_ID', '?')} bot={bot_username} delay={delay}s")
    print(f"[dry-run] would send /clear")
    records = []
    for p in getattr(persona, "PROMPTS", []) or []:
        print(f"[dry-run] would send to @{bot_username}: {p.text!r}")
        records.append({
            "ts_sent": "<dry-run>",
            "ts_received": "<dry-run>",
            "prompt_id": p.id,
            "prompt_text": p.text,
            "reply_text": None,
            "reply_timed_out": True,
            "elapsed_s": 0.0,
            "msgs_collected": 0,
            "msgs_substantive": 0,
        })
    print(f"[dry-run] would send /clear")
    if out_path:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w") as f:
            for r in records:
                f.write(json.dumps(r) + "\n")
        print(f"[dry-run] wrote {out_path} ({len(records)} placeholder records)")
    return 0


# ----------------------------------------------------------------------------
# Live (Telethon) path
# ----------------------------------------------------------------------------

async def run_live(
    persona,
    bot_username: str,
    api_id: int,
    api_hash: str,
    phone: str,
    session_file: Path,
    out_path: Path,
    bookend_clear: bool = True,
) -> int:
    # Lazy import so --dry-run works on machines without telethon installed.
    try:
        from telethon import TelegramClient, events
    except ImportError as e:
        print(f"ERROR: telethon not installed ({e}). pip install telethon.", file=sys.stderr)
        return 2

    delay = getattr(persona, "INTERACTION_DELAY_S", DEFAULT_INTERACTION_DELAY_S)
    prompts = getattr(persona, "PROMPTS", []) or []
    if not prompts:
        print("ERROR: persona has no PROMPTS list.", file=sys.stderr)
        return 2

    out_path.parent.mkdir(parents=True, exist_ok=True)
    session_file.parent.mkdir(parents=True, exist_ok=True)

    client = TelegramClient(str(session_file), api_id, api_hash)
    await client.start(phone=phone)

    bot = await client.get_entity(bot_username)

    # Reply queue per prompt -- the next reply from this bot lands here.
    reply_queue: asyncio.Queue = asyncio.Queue()

    @client.on(events.NewMessage(from_users=bot))
    async def _on_reply(event):
        await reply_queue.put(event.message)

    async def send_and_await(
        text: str, *, timeout: float, settle: float = SETTLE_S
    ) -> tuple[Any, dt.datetime, dt.datetime, bool, dict]:
        """Send `text`, then collect every bot message until the bot has
        been silent for `settle` seconds (quiescence) or `timeout` is hit.

        Returns the LAST substantive message (the model wrap-up), not the
        first arrival. This is the Phase 4.1.1 fix: the chip is a
        multi-message async source, so pop-first mispairs at scale.
        """
        # Drain stale messages from the prior turn before sending.
        while not reply_queue.empty():
            try:
                reply_queue.get_nowait()
            except asyncio.QueueEmpty:
                break
        ts_sent = dt.datetime.now(dt.timezone.utc)
        await client.send_message(bot, text)

        loop = asyncio.get_running_loop()
        deadline = loop.time() + timeout
        collected: list[Any] = []
        while True:
            remaining = deadline - loop.time()
            if remaining <= 0:
                break
            try:
                msg = await asyncio.wait_for(
                    reply_queue.get(), timeout=min(settle, remaining)
                )
                collected.append(msg)
            except asyncio.TimeoutError:
                # `settle` seconds with no new bot message.
                if collected:
                    break          # bot quiesced after replying -> turn done
                # else: nothing yet, keep waiting until the hard timeout
        ts_received = dt.datetime.now(dt.timezone.utc)

        substantive = [m for m in collected if _is_substantive(getattr(m, "message", None))]
        stats = {
            "msgs_collected": len(collected),
            "msgs_substantive": len(substantive),
        }
        if not collected:
            return None, ts_sent, ts_received, True, stats
        chosen = substantive[-1] if substantive else collected[-1]
        return chosen, ts_sent, ts_received, False, stats

    # Open the session log incrementally so a crash mid-run still leaves
    # the prompts driven up to that point on disk.
    with out_path.open("w") as f:
        # /clear at start (not logged as a corpus turn -- it's plumbing).
        if bookend_clear:
            print(f"[{persona.PERSONA_ID}] sending /clear (session start)")
            await send_and_await("/clear", timeout=30.0)
            await asyncio.sleep(2.0)

        for i, p in enumerate(prompts, 1):
            print(f"[{persona.PERSONA_ID}] {i}/{len(prompts)}  sending: {p.text!r}")
            msg, ts_sent, ts_received, timed_out, stats = await send_and_await(
                p.text, timeout=REPLY_TIMEOUT_S
            )
            elapsed = (ts_received - ts_sent).total_seconds()
            reply_text = msg.message if msg else None
            print(
                f"  -> {'TIMEOUT' if timed_out else 'OK'}  {elapsed:.1f}s  "
                f"msgs={stats['msgs_collected']}(sub={stats['msgs_substantive']})  "
                f"reply: {(reply_text or '')[:70]!r}"
            )
            record = {
                "ts_sent": ts_sent.isoformat(),
                "ts_received": ts_received.isoformat() if not timed_out else None,
                "prompt_id": p.id,
                "prompt_text": p.text,
                "reply_text": reply_text,
                "reply_timed_out": timed_out,
                "elapsed_s": round(elapsed, 2),
                "msgs_collected": stats["msgs_collected"],
                "msgs_substantive": stats["msgs_substantive"],
            }
            f.write(json.dumps(record) + "\n")
            f.flush()
            if i < len(prompts):
                await asyncio.sleep(delay)

        if bookend_clear:
            print(f"[{persona.PERSONA_ID}] sending /clear (session end)")
            await send_and_await("/clear", timeout=30.0)

    await client.disconnect()
    print(f"\nWrote {out_path}")
    return 0


# ----------------------------------------------------------------------------
# CLI
# ----------------------------------------------------------------------------

def _require_env(var: str) -> str:
    v = os.environ.get(var)
    if v is None or v == "":
        raise SystemExit(
            f"ERROR: env var {var} not set. See module docstring for required "
            f"env vars (TG_API_ID, TG_API_HASH, TG_PHONE)."
        )
    return v


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--persona", required=True,
                    help="Persona module name under personas/ (no .py).")
    ap.add_argument("--bot-username", required=True,
                    help="Target chip bot username (no @).")
    ap.add_argument("--session-file", type=Path,
                    default=Path.home() / ".telethon-wireclaw.session",
                    help="Telethon session file (default: ~/.telethon-wireclaw.session).")
    ap.add_argument("--out", type=Path,
                    help="Output JSONL session log path. Required unless --dry-run.")
    ap.add_argument("--no-bookend-clear", action="store_true",
                    help="Skip the /clear bookends at session start and end. Default: send them.")
    ap.add_argument("--dry-run", action="store_true",
                    help="Print what would be sent without contacting Telegram.")
    args = ap.parse_args()

    persona = load_persona(args.persona)

    if args.dry_run:
        return dry_run(persona, args.bot_username, args.out)

    if args.out is None:
        print("ERROR: --out is required for live runs (use --dry-run to skip).", file=sys.stderr)
        return 2

    api_id_str = _require_env("TG_API_ID")
    try:
        api_id = int(api_id_str)
    except ValueError:
        raise SystemExit(f"ERROR: TG_API_ID must be an integer; got {api_id_str!r}")
    api_hash = _require_env("TG_API_HASH")
    phone = _require_env("TG_PHONE")

    return asyncio.run(run_live(
        persona=persona,
        bot_username=args.bot_username,
        api_id=api_id,
        api_hash=api_hash,
        phone=phone,
        session_file=args.session_file,
        out_path=args.out,
        bookend_clear=not args.no_bookend_clear,
    ))


if __name__ == "__main__":
    sys.exit(main())
