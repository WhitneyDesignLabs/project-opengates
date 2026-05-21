#!/usr/bin/env python3
"""Phase 4.3.0.F A/B driver. Runs ON evobot Pi (uses its phase31-venv
telethon + .telethon-evobot.session). Sends each curated prompt 5x to
wdl_c6_pilot_bot via Telegram. Between prompts: /clear (history) +
HTTP POSTs to reset rules + memory.

Reads:  ~/phase_4_3_0_ab_prompts.jsonl  (scp'd from workstation)
Writes: ~/phase_4_3_0_ab_metadata.jsonl  (one line per run: prompt_id,
        mode, run_num, ts_sent_iso, ts_first_reply_iso, reply_preview)

Mode is passed via --mode. The chip's wrap_mode must be set externally
before running (POST /api/config + reboot).
"""
from __future__ import annotations
import argparse, asyncio, datetime as dt, json, os, sys, urllib.request, urllib.parse
from pathlib import Path

CHIP_IP = "192.168.1.19"
BOT_USERNAME = "wdl_c6_pilot_bot"
SESSION = str(Path.home() / ".telethon-evobot.session")
PROMPTS_FILE = Path.home() / "phase_4_3_0_ab_prompts.jsonl"
META_OUT = Path.home() / "phase_4_3_0_ab_metadata.jsonl"

MEMORY_SEED = "favorite_color=green"
REPLY_TIMEOUT_S = 60.0    # max wait per prompt for first substantive reply
SETTLE_S = 8.0            # additional settle after first reply (chip may emit multiple msgs)
INTERPROMPT_S = 2.0       # spacing between prompts
RUNS_PER_PROMPT = 5

# Plumbing filter — drop chip's internal status messages that aren't the wrap-up.
def is_substantive(text: str) -> bool:
    if not text:
        return False
    t = text.strip()
    if not t:
        return False
    # boot banner / clear echo / agent traces
    low = t.lower()
    if "history cleared" in low and len(t) < 40:
        return False
    if t.startswith("[Agent]") or t.startswith("[TG]"):
        return False
    if "wireclaw v0." in low and "started" in low:
        return False
    return True


def http_post(url: str, body: dict | None = None, timeout: float = 10.0):
    """Best-effort POST; returns response text or '' on error."""
    data = json.dumps(body).encode() if body is not None else b""
    req = urllib.request.Request(url, data=data, method="POST",
                                  headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.read().decode(errors="replace")
    except Exception as e:
        return f"[err:{e}]"


def reset_chip_state():
    """Clear rules + seed memory. Idempotent."""
    rules_resp = http_post(f"http://{CHIP_IP}/api/rules/delete", {"id": "all"})
    mem_resp = http_post(f"http://{CHIP_IP}/api/memory", MEMORY_SEED)
    return rules_resp, mem_resp


async def main_async(mode: str):
    from telethon import TelegramClient, events

    api_id = int(os.environ["TG_API_ID"])
    api_hash = os.environ["TG_API_HASH"]
    phone = os.environ["TG_PHONE"]

    prompts = []
    with PROMPTS_FILE.open() as f:
        for line in f:
            line = line.strip()
            if line:
                prompts.append(json.loads(line))
    print(f"loaded {len(prompts)} prompts; mode={mode}")
    print(f"chip ip {CHIP_IP}, bot {BOT_USERNAME}, runs/prompt {RUNS_PER_PROMPT}")

    client = TelegramClient(SESSION, api_id, api_hash)
    await client.start(phone=phone)

    bot = await client.get_entity(BOT_USERNAME)
    print(f"connected; bot entity id={bot.id}")

    # Reply collection: per-prompt buffer
    reply_buf: list[tuple[float, str]] = []
    first_reply_evt: asyncio.Event = asyncio.Event()

    @client.on(events.NewMessage(from_users=bot.id))
    async def on_reply(event):
        text = event.raw_text or ""
        if is_substantive(text):
            reply_buf.append((asyncio.get_event_loop().time(), text))
            if not first_reply_evt.is_set():
                first_reply_evt.set()

    # Open metadata file (append) — keeps prior mode's data
    meta = META_OUT.open("a")

    for p_idx, p in enumerate(prompts):
        prompt_id = p["id"]
        bucket = p["bucket"]
        prompt = p["prompt"]
        print(f"\n[{p_idx+1}/{len(prompts)}] {prompt_id} bucket={bucket}  {prompt[:70]!r}")

        # Inter-prompt reset: /clear + rules + memory
        await client.send_message(bot, "/clear")
        await asyncio.sleep(2.0)
        rr, mr = reset_chip_state()
        print(f"  reset: rules={rr.strip()[:60]}  mem={mr.strip()[:60]}")
        await asyncio.sleep(1.5)

        for run in range(1, RUNS_PER_PROMPT + 1):
            reply_buf.clear()
            first_reply_evt.clear()
            ts_sent = dt.datetime.now(dt.timezone.utc)
            await client.send_message(bot, prompt)
            try:
                await asyncio.wait_for(first_reply_evt.wait(), timeout=REPLY_TIMEOUT_S)
            except asyncio.TimeoutError:
                print(f"    run {run}: TIMEOUT after {REPLY_TIMEOUT_S}s")
            # Settle for additional chip messages
            await asyncio.sleep(SETTLE_S)
            ts_received = (reply_buf[0][0] if reply_buf else None)
            preview = (reply_buf[-1][1][:120] if reply_buf else "")
            print(f"    run {run}: msgs={len(reply_buf)} preview={preview!r}")
            meta.write(json.dumps({
                "prompt_id": prompt_id,
                "bucket": bucket,
                "mode": mode,
                "run_num": run,
                "ts_sent_iso": ts_sent.isoformat(),
                "ts_first_reply_loop": ts_received,
                "reply_msg_count": len(reply_buf),
                "reply_preview": preview,
            }) + "\n")
            meta.flush()
            await asyncio.sleep(INTERPROMPT_S)

    meta.close()
    await client.disconnect()
    print(f"\ndone. metadata appended to {META_OUT}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", required=True, choices=["speculative", "grounded"])
    args = ap.parse_args()
    asyncio.run(main_async(args.mode))


if __name__ == "__main__":
    main()
